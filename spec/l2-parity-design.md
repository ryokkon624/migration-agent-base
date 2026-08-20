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

legacy の全73クラス（.class 実測）のうち、**29クラス**を分母とする（うち JaCoCo が解析対象とするのは 22 クラス。残りはインタフェース等）。

| パッケージ | クラス数 | 分母 | 理由 |
| --- | --- | --- | --- |
| `domain` | 8 | **含む** | 業務ロジックの中核 |
| `domain.logic` | 6 | **含む** | 同上 |
| `dao` | 5 | **含む** | 永続化（クエリの意味を保存） |
| `dao.ibatis` | 10 | **含む** | 同上（内部クラス1を含む） |
| `web.struts` | 24 | 除外 | SPA+REST へ置換（ID-6） |
| `web.spring` | 18 | 除外 | 同上（ID-6） |
| `service` / `service.client` | 2 | 除外 | remoting 廃止（ID-5） |

→ 「**保存対象29クラス（解析22）に対してブランチ○%**」と、定義済みの分母で語れる。実測値は §7.2。

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

---

## 7. 試作（spike）で確認した事実 — 2026-08-20

設計の不確実点を潰すため、**縦切り1本（読み取り系＋W1注文）を実際に往復させた**記録。以下は推測ではなく実測。

### 7.1 往復は成立した（W1: order-single-item）

```
legacy : inventoryDelta{EST-1:-2}  ordersCreated 1  orderTotal "33.00"  lines[EST-1 x2 @16.50]
new    : inventoryDelta{EST-1:-2}  ordersCreated 1  orderTotal "33.00"  lines[EST-1 x2 @16.50]
                                                             → ★ EQUIVALENT
```

- **旧の駆動経路（実証済み）**: `signon.do` → `addItemToCart.do?workingItemId=` → `updateCartQuantities.do`（`EST-1=2`）→ `checkout.do` → `newOrderForm.do` → `newOrder.do`（`order.*` フォーム）→ `newOrder.do?confirmed=true`
- **旧DBの読み出し（実証済み）**: JDK コンテナ＋`run/hsqldb-1.8.0.7.jar` から JDBC（`jdbc:hsqldb:hsql://localhost:9002` / `sa` / 空PW）。`--network container:<legacy>` で 9002 に直結。**コンテナ内は JRE のみ・SqlTool 非同梱**のため、この方式が必要。
- **JSP からの値抽出（実証済み）**: `?productId=FI-SW-01` 等が素直に取れる。`;jsessionid=...` がパスとクエリの間に挿入される点だけ考慮する（`viewProduct\.do[^?]*\?productId=([A-Z0-9-]+)`）。

### 7.2 初期カバレッジ実測（ゲート値決定の材料）

シナリオ: 読み取り系（カテゴリ5・商品3・アイテム3・検索6パターン）＋ W1 注文1本。

| 指標 | 実測 |
| --- | --- |
| **BRANCH** | **16/42 = 38.1%** |
| LINE | 297/452 = 65.7% |
| INSTRUCTION | 1119/1765 = 63.4% |
| CLASS | 19/22 = 86.4% |

| パッケージ | branch | line | 所見 |
| --- | --- | --- | --- |
| `domain` | 42.9% | 81.4% | よく踏めている |
| `dao.ibatis` | 45.5% | 66.7% | 中程度 |
| **`domain.logic`** | **0.0%** | **25.0%** | **ほぼ未踏＝最大のギャップ** |
| `dao` | n/a | n/a | インタフェースのみ（分岐なし） |

→ **`domain.logic` の branch 0%** が「あと何本必要か」を名指ししている。次に足すべきは在庫不足（W3）・複数商品（W2）・アカウント系（W4/W5）・注文履歴照会。
→ **ゲート値は未定**。この実測を出発点に PO と合意する（§6-1）。

### 7.3 JaCoCo の注入は overlay イメージで行う（legacy リポジトリ無改変）

`run/Dockerfile`/`entrypoint.sh` を書き換えず、**既存イメージに被せる**。凍結アーティファクトの原則を保てる。

```dockerfile
FROM jpetstore-legacy
COPY jacocoagent.jar /opt/jacocoagent.jar
COPY entrypoint-jacoco.sh /entrypoint-jacoco.sh
RUN sed -i 's/\r$//' /entrypoint-jacoco.sh && chmod +x /entrypoint-jacoco.sh
ENTRYPOINT ["/entrypoint-jacoco.sh"]
```

`entrypoint-jacoco.sh` は元の entrypoint と同一処理＋`exec catalina.sh run` の直前に:

```sh
export CATALINA_OPTS="-javaagent:/opt/jacocoagent.jar=destfile=/jacoco/jacoco.exec,append=true,includes=org.springframework.samples.jpetstore.*"
```

- agent/cli は `org.jacoco:org.jacoco.agent:0.8.12:runtime` / `org.jacoco:org.jacoco.cli:0.8.12:nodeps`（backend の JaCoCo と同版）。
- 採取: `docker stop -t 30`（**graceful**）でシャットダウンフックが `jacoco.exec` を書き出す。`-v <host>:/jacoco` でホストに落とす。
- レポート: `jacococli report jacoco.exec --classfiles <分母ツリー> --html <out> --xml <out>/jacoco.xml`。**`--classfiles` に §4.1 の分母だけを置いたツリーを渡す**（WAR の `WEB-INF/classes` から `domain`/`dao` 配下のみコピー）。

### 7.4 設計に反映すべき発見（5件）

| # | 発見 | 対応 |
| --- | --- | --- |
| **F1** | **旧新でシードの絶対値が違う**（legacy `EST-1=10000`・注文2件が初期投入済／new `EST-1=100`・注文0件） | **絶対値比較は不可能＝デルタ比較が必須**。§1 の canonical（`inventoryDelta`/`ordersCreated`）が正しいことの裏付け |
| **F2** | **ポート衝突**: legacy も新 backend も 8080 | 採取用 legacy は**別ポート**で起動（試作は `-p 8081:8080 -p 9002:9002`）。ハーネスは base URL を設定可能にする |
| **F3** | **新側 CSRF が交互ローテーション**: トークン Cookie が**存在すれば削除・無ければ発行**。`/api/ping` でも `/api/categories` でも同じ | ハーネスは「**トークンが取れるまで GET を繰り返す**」規則にする（試作で安定動作）。ブラウザ SPA は都度 Cookie を読むため実害なし（SEC が「やや異例」とした挙動の正体） |
| **F4** | **シナリオ間の状態が漏れる**: 前シナリオのカート残留で数量2のはずが4で注文された | 各シナリオの**前処理でカート/注文/在庫をリセット**する。両側に必要 |
| **F5** | **ページサイズが違う**（legacy 4件/頁・new 12件/頁＝ID-20） | 読み取り系 canonical は**全ページを辿って集合で比較**する。1頁目だけ比べると偽の不一致になる |

> 参考: `keyword=_` の検索が legacy で 4 件返るのは、`_` が LIKE ワイルドカードとして全件マッチ（ID-29）した上で**1頁目のみ**返っているため。F5 と ID-29 が重なる例。

### 7.5 後始末（試作で作った状態）

- 新側: 作成した注文・カート・在庫を復元（`orders=0` / `cart=0` / `EST-1=100`）。監査ログは追記専用のため残置（SEC と同方針）。
- legacy: `jpetstore-legacy-parity` コンテナは停止。**イメージ `jpetstore-legacy` は無改変**、計測用は別タグ `jpetstore-legacy-jacoco`。
