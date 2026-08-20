# l2-parity-design — L2 特性化テスト（旧新パリティ）の設計

> [`verification-strategy.md`](./verification-strategy.md) の **L2** を実装可能な粒度まで具体化した設計書。
> **目的**: 「保存すべき業務ロジックが旧と同値であること」を、legacy を oracle として機械的に実証する。
> **前提**: legacy は改変しない凍結アーティファクト（`jpetstore-legacy` イメージ・ビルド済み）。
> **関連**: [`intended-diff-ledger.md`](./intended-diff-ledger.md)（意図差分＝分母の除外／期待される不一致）・[`architecture-conventions.md`](./architecture-conventions.md)。

## 決定サマリ

| # | 決定 |
| --- | --- |
| **P1** | 初回スコープは **読み取り系＋注文確定**（カートは注文に畳む） |
| **P2** | capture / verify とも **`jpetstore-backend` の test スコープ**に置き、canonical モデルとコンパレータを共有。golden は `src/test/resources/parity/golden/`。汎用化は2本目のレガシーが来てから（extract-on-2nd-use） |
| **P3** | **JaCoCo カバレッジゲートを初回から同時に**導入（「本数は十分か」を数値で答える） |

---

## 1. 核心：canonical（正規形）で比較する

旧（Struts `.do` / JSP / HSQLDB）と新（REST / SPA / MySQL）は**インタフェースもスキーマも別物**。HTTP 応答も DB ダンプも直接比較できない。そこで**どちらの語彙でもない第三の正規形**を定義し、両側にアダプタを置く。

```
[シナリオ台帳]（両側共有・抽象で書く）
      |
      ├─→ legacy adapter : .do にフォームPOST / HSQLDB(9002) を読む ──┐
      │                                                              ├→ canonical を比較
      └─→ new adapter    : REST を叩く / MySQL を読む ───────────────┘
```

canonical の例（＝golden の実体）:

```json
{
  "scenario": "order-single-item",
  "capturedFrom": { "legacyCommit": "<sha>", "capturedAt": "<iso8601>" },
  "expectation": "EQUIVALENT",
  "outcome": "SUCCESS",
  "inventoryDelta": { "EST-1": -2 },
  "ordersCreated": 1,
  "orderTotal": "33.00",
  "lines": [ { "itemId": "EST-1", "quantity": 2, "unitPrice": "16.50" } ]
}
```

### 1.1 スキーマ対応（アダプタが吸収する）

| canonical | legacy | new |
| --- | --- | --- |
| `inventoryDelta` | `inventory(itemid, qty)` | `t_inventory(item_id, quantity)` |
| `ordersCreated` / `orderTotal` | `orders(orderid, totalprice)` | `t_order(order_id, total_price)` |
| `lines` | `lineitem(orderid, linenum, itemid, quantity, unitprice)` | `t_order_line(order_id, item_id, quantity, unit_price)` |
| `products` / `items`（読み取り系） | `product` / `item` / `category` | `m_product` / `m_item` / `m_category` |
| 認証主体 | `signon(username='j2ee')` | `m_account(username='demo_user')` |

### 1.2 比較から除外する（正規化）

- **新側の構造列**: WHO 6列・`version`・自動採番ID・`created_at`/`updated_at`
- **旧側の廃止列**: `creditcard`/`exprdate`/`cardtype`（ID-8）・`courier`/`locale`（ID-21）・`orderstatus`（ID-22）・`linenum`（明細は itemId でキー付け）
- **識別子そのもの**: `orderid`/`order_id` は値を比較せず「**1件増えた**」で比較（採番機構が違う＝ID-23）
- 金額は `BigDecimal` 相当で比較（文字列 `"33.00"` として保持し scale を揃える）

---

## 2. シナリオ台帳（初回スコープ）

**各シナリオは期待を宣言する**: `EQUIVALENT`（旧同値）か `INTENDED_DIVERGENCE(ID-x)`（台帳どおり違う）。
→ これにより **L4（台帳照合）が機械的に検証可能**になる。台帳に無い不一致＝欠陥候補。

### A. 読み取り系（DB書き込みなし・件数を稼ぐ）

| ID | シナリオ | canonical | 期待 |
| --- | --- | --- | --- |
| R1 | カテゴリ一覧 | categoryId の集合 | EQUIVALENT |
| R2 | カテゴリ配下の商品一覧（FISH/DOGS/CATS/REPTILES/BIRDS の5本） | productId 順序つきリスト | EQUIVALENT |
| R3 | 商品配下のアイテム一覧 | itemId＋listPrice | EQUIVALENT |
| R4 | アイテム詳細 | itemId/productName/listPrice | EQUIVALENT |
| R5 | 検索（複数語・部分一致・0件） | productId 集合 | EQUIVALENT |
| R6 | 検索（`%` / `_` を含む語） | productId 集合 | **INTENDED_DIVERGENCE(ID-29)**（旧はワイルドカード扱い・新はリテラル） |

### B. 状態変更系（本命）

| ID | シナリオ | canonical | 期待 |
| --- | --- | --- | --- |
| W1 | 注文確定・単一商品・在庫十分（EST-1 ×2） | 在庫デルタ／明細／合計 | EQUIVALENT |
| W2 | 注文確定・複数商品 | 同上 | EQUIVALENT |
| W3 | 注文確定・**在庫不足** | 旧=成功して在庫がマイナス／新=失敗して在庫不変 | **INTENDED_DIVERGENCE(ID-1)** |

> カートは legacy がセッション保持で DB に落ちないため、**カート単体をシナリオにせず注文確定に畳む**。
> アカウント系は次イテレーション（W4 登録・W5 更新）。

### 2.1 識別子の対応

シナリオ台帳は抽象で書き、アダプタが実体へ写像する。

| 抽象 | legacy | new |
| --- | --- | --- |
| `USER_PRIMARY` | `j2ee` / `j2ee` | `demo_user` / `Sprint3-DemoLogin!26` |
| 商品・アイテムID | 共通（`EST-1`・`FI-SW-01` 等はシード共通） | 同左 |

---

## 3. 配置とタスク

```
jpetstore-backend/src/test/groovy/.../parity/
  canonical/ParitySnapshot.groovy     … canonical モデル＋正規化ルール（capture/verify 共有）
  canonical/ParityComparator.groovy   … 意味デルタ比較＋expectation 判定
  ParityScenarios.groovy              … シナリオ台帳（両側共有）
  capture/LegacyCaptureTool.groovy    … 旧を叩いて golden 生成（手動実行）
  capture/LegacyHttpClient.groovy     … .do へのフォームPOST＋JSESSIONID 保持
  capture/LegacyDbReader.groovy       … HSQLDB(9002) から canonical を組む
  *ParitySpec.groovy                  … 新を叩いて golden と diff
jpetstore-backend/src/test/resources/parity/golden/*.json
```

- **`@Tag("integration")` ＋ `@Tag("parity")` の dual-tag**。素の `parity` 単独タグにすると UT の `test` タスク（`excludeTags 'integration'`）に巻き込まれ Docker 無しで落ちるため。
- gradle:
  - `captureGolden` … 手動。**legacy 起動が前提**。golden を再生成しコミットする。
  - `parityTest` … `includeTags 'parity'`。**legacy 不要**（コミット済み golden と比較）。
  - 二重実行を避けるなら `integrationTest` 側に `excludeTags 'parity'` を足す。
- golden には `capturedFrom.legacyCommit` を必ず埋める（再現性・監査可能性）。

> **CI**: 現時点でどのリポジトリにも GitHub Actions は無い。当面 `parityTest` は**ローカル/手動ゲート**として運用し、Actions 導入時に品質ゲートへ昇格する。

---

## 4. JaCoCo カバレッジゲート（P3）

「テストの本数は十分か」に**数値で**答えるための仕組み。legacy 側で計測する。

### 4.1 分母（＝保存すべき業務ロジックだけに絞る）

legacy の全72クラスのうち、**28クラス**を分母とする。

| パッケージ | クラス数 | 分母 | 理由 |
| --- | --- | --- | --- |
| `domain` | 8 | **含む** | 業務ロジックの中核 |
| `domain.logic` | 6 | **含む** | 同上 |
| `dao` | 5 | **含む** | 永続化（クエリの意味を保存） |
| `dao.ibatis` | 9 | **含む** | 同上 |
| `web.struts` | 24 | 除外 | SPA+REST へ置換（ID-6） |
| `web.spring` | 18 | 除外 | 同上（ID-6） |
| `service` / `service.client` | 2 | 除外 | remoting 廃止（ID-5） |

→ 「**保存対象28クラスに対してブランチ○%**」と、定義済みの分母で語れる。

### 4.2 注入方法（legacy は改変しない＝run/ の起動設定のみ変更）

`run/entrypoint.sh` の `exec catalina.sh run` の前に agent を差す:

```sh
export CATALINA_OPTS="-javaagent:/opt/jacocoagent.jar=destfile=/jacoco/jacoco.exec,append=true,includes=org.springframework.samples.jpetstore.*"
```

- `run/Dockerfile` に `jacocoagent.jar` を `COPY` し、`/jacoco` をボリュームにする。
- **アプリのソース・WAR は無改変**（起動オプションのみ）＝凍結アーティファクトの原則を守る。

### 4.3 採取と集計の運用

legacy は軽量なので **毎回「全シナリオを1つの exec に流し直す」**のが最も単純（マージの stale 事故ゼロ）:

```
1. docker start（agent 付き）
2. captureGolden で全シナリオを実行
3. docker stop（graceful）→ シャットダウンフックで exec が書き出される
4. exec を取り出し、jacococli で report 生成（--classfiles は §4.1 の4パッケージのみ）
```

カタログが重くなったら per-run exec ＋ `jacoco:merge`（和集合）の incremental に切り替える。

### 4.4 ループとゲート

```
列挙（AC / Action / SQL / 分岐）
   → 入力技法（同値分割・境界値・デシジョンテーブル）でシナリオ化
   → legacy で採取（golden ＋ exec）
   → 新で diff
   → カバレッジ計測
   → 閾値未達の分岐＝残りのシナリオ  ─┐
   ↑─────────────────────────────────┘
```

- **初回は閾値を決め打ちせず、まず実測値を出す**（分母28クラスに対する初期ブランチ率）。その値を見てゲート値を PO と合意する。
- 到達不能な分岐（廃止機能への分岐等）は除外理由を明記する。**silent な打ち切りをしない**。

---

## 5. L4 との接続

- 各シナリオの `expectation` が `INTENDED_DIVERGENCE(ID-x)` を名指しするため、**台帳の該当 ID が「観測点つき」になる**。
- Phase 4 L4 は「実測差分 ⊆ 台帳」を確認する工程だが、L2 がその一部を**自動で**担保する。
- `EQUIVALENT` のはずが不一致 → **台帳に無い差分＝欠陥候補**として調査。

---

## 6. 未決事項

1. **カバレッジのゲート値**: 初回実測後に PO と合意（§4.4）。
2. **アカウント系シナリオ（W4/W5）**: 次イテレーション。旧 `account`/`profile`/`signon` と新 `m_account`/`m_profile`/`m_signon` の対応づけが必要。
3. **legacy の read-only 応答の取り出し方**: JSP の HTML から business value を抽出する必要がある（productId 等）。パーサの頑健性は初回実装で見極める。DB 直読みで代替できる範囲は DB を優先する。
4. **CI 昇格**: GitHub Actions 導入時に `parityTest` をゲート化。
