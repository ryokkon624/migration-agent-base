# Sprint 21 バックログ

## スプリントゴール

**Phase 4 の L2（特性化テスト＝旧新パリティ）の検証基盤を確立し、「移植した業務ロジックが旧と同値であること」を機械的に判定できる状態にする。**

機能追加ではなく**検証基盤の構築**。legacy を oracle として、canonical（正規形）でのデルタ比較・シナリオ台帳・golden の版管理・カバレッジ計測までを一気通貫で資産化する。

## 対象 Issue（依存が一直線・この順で実施）

| Issue | タイトル | SP | ラベル | 依存 |
| --- | --- | --- | --- | --- |
| [#48](https://github.com/ryokkon624/jpetstore-manage/issues/48) | [L2] 旧新パリティの検証基盤を確立し、縦切り1本（W1 注文確定）を通す | 5 | foundation | — |
| [#49](https://github.com/ryokkon624/jpetstore-manage/issues/49) | [L2] シナリオ台帳を読み取り系＋W2/W3 へ広げ、意図差分の宣言を実測で固定する | 3 | foundation | #48 |
| [#50](https://github.com/ryokkon624/jpetstore-manage/issues/50) | [L2] legacy のカバレッジを overlay イメージで計測し、ゲート値を PO と合意する | 3 | foundation | #48, #49 |

合計 **11SP**。

- **山は #48**。canonical モデル・コンパレータ・シナリオ台帳の書式・golden スキーマ・`captureGolden`/`parityTest` タスクという**先例規約**をここで確立する。
- **#49 は横展開**（#29→#30 と同型の関係）。**新しい仕組みは作らない**。
- **#50 は手順が spike で確定済み**。ただし**意味のある数値は #49 完了後**（全シナリオが揃ってから）でないと出ない。

## ブランチ

- `feature/48-l2-parity-foundation`（**単一ブランチに3 Issue のコミットを積む**／Sprint 55 確立方針）
- リポジトリ: **`jpetstore-backend` 単独**（test スコープ）＋ **`migration-agent-base`**（#50 の overlay ビルド定義とレポート）
- **cross-repo なし**。`legacy-jpetstore` は**起動のみ・無改変**。

---

## 必読ドキュメント（実装前に必ず読むこと）

| ドキュメント | 何のために |
| --- | --- |
| `spec/l2-parity-design.md` | 設計の本体。**特に §7「試作(spike)で確認した事実」は実際に動かして得た実測。推測で上書きしないこと**。旧の駆動経路・HSQLDB への JDBC 接続方法・JSP 抽出の正規表現・JaCoCo 注入手順まで、そのまま使える粒度で書いてある |
| `spec/verification-strategy.md` | L2 の位置づけ（L1〜L4 の4レイヤ）・L4 との接続・§5 Phase 4 合否ゲート |
| `spec/intended-diff-ledger.md` | **ID-1**（在庫ガード）／**ID-20**（ページサイズ）／**ID-29**（LIKE メタ文字）がシナリオの expectation に直結する |

---

## 計画フェーズで確定した論点（ユーザー承認済み・2026-08-20）

| # | 論点 | 確定 |
| --- | --- | --- |
| **D1** | 新側 verify の基盤（#48 AC9） | **parity 専用の基底を新設**する（`ParityIntegrationTestBase` 等・RANDOM_PORT＋実HTTPクライアント）。**既存 `IntegrationTestBase` は無変更**（既存 IT 約25本の起動方式・実行時間に影響を出さない）。Testcontainers MySQL 8.4＋Flyway の共有は継承して再利用する |
| **D2** | legacy 側のリセット/復元方式（#48 AC10・#49 AC5） | **W3（在庫不足＝在庫マイナス化）のみコンテナ再作成**で初期シードへ戻す。**読み取り系はリセット不要**、**W1/W2 は JDBC の SQL で在庫・カート・注文を既知状態へ復元**する |
| **D3** | 新側 `USER_PRIMARY` の用意（#48 AC5） | **parity spec のフィクスチャで `INSERT INTO m_account`／`m_signon`** して demo_user 相当を作る（既存 IT の慣行どおり）。**`R__test_user.sql` の test resources 同期はしない**（他 IT の前提に影響を出さない） |

### 既に Refinement で確定済み（#48 備考・再確認不要）

1. 新側 verify の駆動方式 → **実 HTTP（RANDOM_PORT）＋ F3 ヘルパ**（MockMvc 案は不採用）
2. 読み取り系の順序 → **canonical キー昇順ソート後に比較・並び順は比較対象外**（ID-20 の帰結）
3. 採取時の legacy DB データ操作 → **可**（無改変原則の対象はソース/WAR/`run/` 設定。後始末必須）
4. `parityTest` の `check` 搭載 → **しない**。DoD で `parityTest` の実行と green を明示的に要求する

### 意図的に未決のまま残すもの

- **#50 のカバレッジゲート値**: **AC5 のとおり、実測を見てから PO と合意する**。**先に数値を決めない**（先に決めると帳尻合わせになる）。

---

## 計画前調査の実測（SM・2026-08-20）

DEV はこの前提を実コードで裏取りしてから実装すること（誤りがあれば計画フェーズで訂正・報告する）。

| 調査項目 | 実測 |
| --- | --- |
| `IntegrationTestBase` | `C:\work\java-migration\jpetstore-backend\src\test\groovy\com\example\jpetstore\backend\support\IntegrationTestBase.groovy`。`@SpringBootTest`（**webEnvironment 未指定＝MOCK**）＋ Singleton `MySQLContainer("mysql:8.4.0")`＋`@DynamicPropertySource`（datasource/flyway/jwt.secret） |
| RANDOM_PORT の使用実績 | **コードベース全体でゼロ**（`RANDOM_PORT`／`TestRestTemplate`／`WebTestClient` の grep がいずれも 0 件）＝ #48 AC9 は**完全な新規** |
| gradle タスク構成 | `build.gradle:89` `test`＝`excludeTags 'integration'`／`:97` `integrationTest`＝`includeTags 'integration'`／`:106` `check dependsOn integrationTest`。**`parityTest` の新設と `integrationTest` への `excludeTags 'parity'` 追加が必要**（#48 AC11） |
| test DB のカタログシード | **既達**。`src/test/resources/flyway/sql/V00_000_008__insert_catalog_master.sql`（191行）に `m_supplier`/`m_category`/`m_product`/`m_item`/**`t_inventory`** の INSERT あり。`EST-1`（`FI-SW-01`・listPrice 16.50）も存在 |
| test DB の `demo_user` | **存在しない**。`R__test_user.sql` は `jpetstore-database/flyway/sql-test` 側にあり、`syncTestSchema` は `flyway/sql`（V__ のみ）をコピーする＝ repeatable seed は test resources に来ない（Sprint 19 で判明済みの構造）→ **D3 のフィクスチャ方式**で解決 |
| legacy イメージ | `jpetstore-legacy`（**無改変**・2週間前）と `jpetstore-legacy-jacoco`（spike で作成・約1時間前）が**イメージとして既に存在**。コンテナ `jpetstore-legacy-parity`（jacoco イメージ）は Exited |
| overlay のビルド定義 | **`migration-agent-base` に未コミット**（イメージだけが存在する状態）。#50 AC2 のために**ビルド定義を repo に置き直す**必要がある |
| `legacy-jpetstore` repo | working tree クリーン＝**無改変が維持されている**（HEAD `9bdb187`） |
| legacy の起動構成 | `run/entrypoint.sh` は HSQLDB(9002) をバックグラウンド起動 → `sleep 6` → `exec catalina.sh run`。**#50 の `entrypoint-jacoco.sh` はこれと同一処理＋`exec catalina.sh run` 直前の `CATALINA_OPTS` 差し込み** |

---

## DEV への注意喚起（spike で実際に踏んだ落とし穴・4件）

推測ではなく**試作で踏んだ実績**。ここを雑にやると原因の分かりにくい失敗に嵌まる。

1. **新側 CSRF の交互ローテーション**（#48 AC9 / 設計 F3）
   トークン Cookie は「**あれば削除・無ければ発行**」の交互ローテーション（`/api/ping` でも `/api/categories` でも同じ）。
   → **「トークンが取れるまで GET を繰り返す」ヘルパを最初に作ること**。ここを雑にやると原因の分かりにくい 403 に延々ハマる（**spike で4回踏んだ**）。

2. **W3 の後始末**（#49 AC5 × #48 AC-neg2）
   W3（在庫不足）は**旧DBの在庫を注文数未満に書き換える必要**があり、かつ**旧では在庫がマイナスになる**（それが ID-1 の実証）。
   HSQLDB はファイル永続なので、**復元はコンテナを作り直すのが最も確実**（＝ D2 の確定内容）。

3. **JaCoCo の graceful stop**（#50 AC3）
   **`docker stop -t 30` でないと exec が書かれず、計測結果が丸ごと消える**。強制停止しないこと。

4. **ポート衝突**（設計 F2）
   legacy と新 backend が**両方 8080**。採取用 legacy は**別ポートで起動**する（spike は `-p 8081:8080 -p 9002:9002`）。

### その他の spike 発見（設計 §7.4）

| # | 発見 | 対応 |
| --- | --- | --- |
| **F1** | 旧新でシードの絶対値が違う（legacy `EST-1=10000`・注文2件が初期投入済／new `EST-1=100`・注文0件） | **絶対値比較は不可能＝デルタ比較が必須**（#48 AC2） |
| **F4** | シナリオ間の状態が漏れる（前シナリオのカート残留で数量2のはずが4で注文された） | **各シナリオの前処理で両側をリセット**（#48 AC10・D2） |
| **F5** | ページサイズが違う（legacy 4件/頁・new 12件/頁＝ID-20） | 読み取り系 canonical は**全ページを辿って集合で比較**（#49 AC2）。1頁目だけ比べると偽の不一致になる |

---

## 環境メモ

- **legacy イメージ `jpetstore-legacy` はビルド済み。無改変で維持すること**。計測用の overlay は**別タグ `jpetstore-legacy-jacoco`**。
- **新 backend の起動には `.env` の読み込みが必要**（未設定だと `JWT_SECRET` で fail-fast＝#38）。**シェルの環境変数はセッションに残るので、`.env` を変えたら読み直すこと**。
- 開発資格情報: legacy `j2ee`/`j2ee`、new `demo_user`/`Sprint3-DemoLogin!26`。
- legacy への JDBC: `jdbc:hsqldb:hsql://<host>:9002` / `sa` / 空PW。**コンテナ内は JRE のみ・SqlTool 非同梱**のため、JDK コンテナ＋`run/hsqldb-1.8.0.7.jar` から `--network container:<legacy>` で 9002 に直結する（設計 §7.1）。

---

## 完了条件（DoD 補足）

- `parityTest` は **`check` に載せない**方針のため、**`parityTest` を明示実行して green であること**を完了条件に含める（#48 AC11/AC12・#49 AC7）。
- **legacy を停止した状態で `parityTest` が green**（コミット済み golden とのみ比較）。
- golden はすべて `capturedFrom.legacyCommit` と `capturedAt` が埋まっていること。
- 採取後、**`jpetstore-legacy` イメージが無改変**・採取用コンテナは停止・HSQLDB のデータは復元済み。

---
---

# Issue 本文（全文転記）

## #48 [L2] 旧新パリティの検証基盤を確立し、縦切り1本（W1 注文確定）を通す

**ラベル**: foundation ／ **SP**: 5 ／ **Sprint**: 21 ／ **Ready**: Ready

### ユーザーストーリー

**As a** JPetStore 移行のステークホルダー（および PO/SM）
**I want to** 「移植した業務ロジックが本当に旧と同じ結果になるのか」を、legacy を oracle として機械的に判定できる仕組みがほしい
**So that** 現場で必ず問われる「①テスト本数の根拠 ②網羅性の担保」に、実測と台帳で答えられる

### トレース

- **Phase 4 検証レイヤ L2（特性化テスト＝旧同値）**: `spec/verification-strategy.md` §1・§3・§5（合否ゲート）
- **設計**: `spec/l2-parity-design.md`（決定 P1/P2/P3・§1〜§4）
- **試作(spike)の実測**: 同 §7。**実際に動かして得た事実であり、推測で上書きしないこと**
- **意図差分台帳**: `spec/intended-diff-ledger.md`（ID-20 ページサイズ／ID-23 採番／ID-1・ID-29 は横展開 Story で使用）

本Storyは spike で1本通した縦切り（W1 注文確定）の **再実装・資産化**であり、後続の横展開 Story が踏襲する**先例規約**（canonical モデル・シナリオ台帳の書式・golden スキーマ・タスク/タグ構成）を確立する。

### 配置（`spec/l2-parity-design.md` §3）

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

### Acceptance Criteria

- [ ] **AC1（canonical モデル）**: `ParitySnapshot` を新設し、旧新どちらの語彙でもない正規形で比較する。比較に**含める**のは `inventoryDelta` / `ordersCreated` / `orderTotal` / `lines(itemId, quantity, unitPrice)`。比較から**除外**するのは設計 §1.2 のとおり（新側＝WHO 6列・`version`・自動採番ID・`created_at`/`updated_at` ／ 旧側＝`creditcard`/`exprdate`/`cardtype`（ID-8）・`courier`/`locale`（ID-21）・`orderstatus`（ID-22）・`linenum`）。金額は scale を揃えた文字列で保持し `BigDecimal` 相当で比較する（誤差 0）。
- [ ] **AC2（デルタ比較・F1）**: 在庫と注文件数は**絶対値ではなくシナリオ実行前後のデルタ**で比較する。旧 `EST-1=10000`・注文2件が初期投入済／新 `EST-1=100`・注文0件という**シードの絶対値差があっても判定が成立する**こと。`orderid`/`order_id` は値を比較せず「1件増えた」で比較する（採番機構が違う＝ID-23）。
- [ ] **AC3（順序の正規化・Q2 決定）**: 集合性を持つ canonical（商品ID・アイテムID等のリスト）は、比較前に**canonical キーで昇順ソートして正規化**する。**表示順そのものは比較対象にしない**（ページング仕様を ID-20 で変えている以上、並び順は「保存すべき業務ロジック」に含めない）。
- [ ] **AC4（expectation の宣言と一致判定）**: 各シナリオは `EQUIVALENT` か `INTENDED_DIVERGENCE(ID-x)` を**宣言**し、コンパレータは**宣言と実測が一致すること**を判定する。`EQUIVALENT` 宣言で不一致 → **失敗**。`INTENDED_DIVERGENCE(ID-x)` 宣言なのに一致してしまった場合も → **失敗**（台帳の形骸化を検知する）。
- [ ] **AC5（シナリオ台帳）**: `ParityScenarios` を新設し、シナリオを**抽象識別子**で記述して両側アダプタが実体へ写像する（設計 §2.1。`USER_PRIMARY` → legacy `j2ee`/`j2ee`、new `demo_user`/`Sprint3-DemoLogin!26`）。本Storyでは **W1（`order-single-item`・EST-1 × 2）1本**を登録する。R1〜R6・W2・W3 は横展開 Story のスコープ。
- [ ] **AC6（旧側 capture ハーネス・§7.1 の実証済み経路を踏襲）**: `captureGolden` タスク（手動実行・legacy 起動が前提）で legacy を駆動し golden を生成する。
  - 駆動経路: `signon.do` → `addItemToCart.do?workingItemId=` → `updateCartQuantities.do`（`EST-1=2`）→ `checkout.do` → `newOrderForm.do` → `newOrder.do`（`order.*` フォーム）→ `newOrder.do?confirmed=true`
  - DB 読み出し: HSQLDB へ JDBC（`jdbc:hsqldb:hsql://<host>:9002` / `sa` / 空PW）。**コンテナ内は JRE のみ・SqlTool 非同梱**のため、コンテナ内 CLI に頼らないこと
  - JSP からの値抽出: `;jsessionid=...` がパスとクエリの間に挿入される点を考慮する（`viewProduct\.do[^?]*\?productId=([A-Z0-9-]+)`）
- [ ] **AC7（別ポート・設定可能な接続先・F2）**: legacy も新 backend も 8080 のため、**採取用 legacy は別ポートで起動**する（spike は `-p 8081:8080 -p 9002:9002`）。ハーネスの legacy base URL と HSQLDB 接続先は**設定で差し替え可能**にする（既定値をコードにハードコードしない）。
- [ ] **AC8（golden の版管理・再現性）**: golden は `src/test/resources/parity/golden/<scenario>.json` に**コミット**する。`capturedFrom.legacyCommit`（legacy リポジトリの commit sha）と `capturedFrom.capturedAt` を**必ず埋める**。sha を取得できないまま golden を書き出してはならない。
- [ ] **AC9（新側 verify の駆動・F3）**: `*ParitySpec` が新側を駆動して canonical を組み、**コミット済み golden と比較**する。
  - 駆動は **`@SpringBootTest(webEnvironment = RANDOM_PORT)` の実 HTTP**（MockMvc の `csrf()` 注入は使わない）。旧新とも「外部インタフェース経由の特性化」で土俵を揃え、フィルタチェーン実経路を通すため
  - DB は既存 IT 基盤（`support/IntegrationTestBase` の Testcontainers MySQL 8.4 + Flyway）を再利用する
  - 新側 CSRF は「トークン Cookie が**存在すれば削除・無ければ発行**」の交互ローテーションのため、**トークンが取れるまで GET を繰り返す**ヘルパを用意する（spike で安定動作を確認済み）
- [ ] **AC10（シナリオ間の状態リセット・F4）**: **各シナリオの実行前に、両側でカート／注文／在庫を既知状態へリセット**する前処理を置く。前シナリオのカート残留により数量2のはずが4で注文される（spike 実績）ことがないこと。
- [ ] **AC11（dual-tag とタスク）**: `@Tag("integration")` ＋ `@Tag("parity")` の **dual-tag** とする（素の `parity` 単独タグだと UT の `test` タスク〔`excludeTags 'integration'`〕に巻き込まれ Docker 無しで落ちるため）。`parityTest` は `includeTags 'parity'`、既存 `integrationTest` に `excludeTags 'parity'` を足して二重実行を避ける。**`check` には載せない**（当面ローカル/手動ゲート。GitHub Actions 導入時に品質ゲートへ昇格）。
- [ ] **AC12（legacy 不要で走る）**: **legacy を停止した状態で `parityTest` が green** になること（コミット済み golden とのみ比較する）。legacy 起動が要るのは `captureGolden` のみ。
- [ ] **AC-neg1（台帳に無い不一致は失敗する）**: golden の値を意図的に1フィールド書き換える（または新側の値を変える）と `parityTest` が**失敗**し、**どのシナリオのどのフィールドが食い違ったか**が出力から判別できること。＝「台帳に無い不一致＝欠陥候補」として検知できることの実証。
- [ ] **AC-neg2（legacy 無改変）**: 採取のために legacy のソース・WAR・`run/` 配下を**変更しない**（起動ポートの指定と採取用の一時コンテナのみ）。採取のために HSQLDB のデータを操作することは可とするが、**採取後は復元し、seed からの再起動が成立する状態を保つ**こと。

### 備考

- **優先順位の根拠**: Phase 4 は L1（AC準拠）・L3（セキュリティ回帰）が完了済みで、残りが **L2 と L4**。L2 は各シナリオの `expectation` が台帳 ID を名指しするため、**L4（実測差分 ⊆ 台帳）の一部を自動で担保する**（設計 §5）。本Storyはその土台。
- **依存関係**: 本Storyが**横展開 Story（R系・W2・W3）と JaCoCo 計測 Story の前提**。cross-repo は無し（`jpetstore-backend` の test スコープ単独／legacy は起動のみ・無改変）。
- **Refinement で確定した論点（2026-08-20・ユーザー承認済み）**:
  1. 新側 verify の駆動方式 → **実 HTTP（RANDOM_PORT）＋ F3 ヘルパ**（MockMvc 案は不採用）
  2. 読み取り系の順序 → **canonical キー昇順ソート後に比較・並び順は比較対象外**（ID-20 の帰結）
  3. 採取時の legacy DB データ操作 → **可**（無改変原則の対象はソース/WAR/`run/` 設定。後始末必須）
  4. `parityTest` の `check` 搭載 → **しない**。DoD で `parityTest` の実行と green を明示的に要求する
- **`spec/intended-diff-ledger.md` への追記**: **不要**（L2 は旧新の振る舞いを変えない）。ID-1／ID-20／ID-29 の「関連Story」欄への追記要否は完了後の Retro で判定する。
- **DoD 補足**: `check` に載せないため、**`parityTest` を明示的に実行し green であること**を完了条件に含める。

_Refinement: PO 2026-08-20（`spec/l2-parity-design.md` §7 の spike 実測を AC の前提として尊重）。_

---

## #49 [L2] シナリオ台帳を読み取り系＋W2/W3 へ広げ、意図差分の宣言を実測で固定する

**ラベル**: foundation ／ **SP**: 3 ／ **Sprint**: 21 ／ **Ready**: Ready

### ユーザーストーリー

**As a** JPetStore 移行のステークホルダー（および PO/SM）
**I want to** パリティのシナリオを読み取り系と注文の主要バリエーションまで広げ、**意図的に違うはずの箇所（ID-1・ID-29）が宣言どおり違うこと**まで機械的に固定したい
**So that** 「旧同値」と「意図差分」を取り違えることなく、L4（実測差分 ⊆ 台帳）の照合を自動で担保できる

### トレース

- **設計**: `spec/l2-parity-design.md` §2（シナリオ台帳・初回スコープ）・§5（L4 との接続）・§7.4（F5 ページサイズ差）
- **意図差分台帳**: `spec/intended-diff-ledger.md` **ID-1**（在庫ガード）・**ID-29**（LIKE メタ文字）・**ID-20**（ページサイズ）
- **前提 Story**: #48（canonical モデル・コンパレータ・シナリオ台帳の書式・golden スキーマ・`captureGolden`/`parityTest`）

本Storyは #48 で確立した先例規約に沿った**横展開**であり、新規の仕組みは作らない（#29 → #30 と同型の関係）。

### Acceptance Criteria

- [ ] **AC1（読み取り系6シナリオ）**: 以下を台帳へ追加し、golden を採取してコミットする（すべて `EQUIVALENT`。R6 のみ例外＝AC3）。

  | ID | シナリオ | canonical | 期待 |
  | --- | --- | --- | --- |
  | R1 | カテゴリ一覧 | categoryId の集合 | EQUIVALENT |
  | R2 | カテゴリ配下の商品一覧（FISH/DOGS/CATS/REPTILES/BIRDS の5本） | productId の集合 | EQUIVALENT |
  | R3 | 商品配下のアイテム一覧 | itemId ＋ listPrice | EQUIVALENT |
  | R4 | アイテム詳細 | itemId / productName / listPrice | EQUIVALENT |
  | R5 | 検索（複数語・部分一致・0件） | productId の集合 | EQUIVALENT |
  | R6 | 検索（`%` / `_` を含む語） | productId の集合 | **INTENDED_DIVERGENCE(ID-29)** |

- [ ] **AC2（全ページ走査・F5）**: ページサイズが旧 4件/頁・新 12件/頁（**ID-20**）と異なるため、読み取り系の canonical は**全ページを辿って**組む。**1頁目だけを比較して偽の不一致を出さないこと**。比較前に canonical キーで昇順ソートし、**並び順そのものは比較対象にしない**（#48 AC3 の規約を踏襲）。
- [ ] **AC3（R6 は ID-29 で不一致になるのが正解）**: `%` / `_` を含む検索語のシナリオは `INTENDED_DIVERGENCE(ID-29)` を宣言する（旧＝LIKE ワイルドカードとして機能／新＝ESCAPE 併用でリテラル一致）。**宣言どおり不一致になること**を判定し、一致してしまった場合は失敗とする。
  - 注意: `keyword=_` が legacy で 4 件返るのは、`_` が全件マッチしたうえで**1頁目のみ**返っているため（F5 と ID-29 が重なる例）。AC2 の全ページ走査を先に効かせること。
- [ ] **AC4（W2 注文確定・複数商品）**: 複数商品を含む注文確定を `EQUIVALENT` で追加する。canonical は在庫デルタ（複数 itemId）／明細／合計。
- [ ] **AC5（W3 注文確定・在庫不足 ＝ ID-1 で不一致になるのが正解）**: `INTENDED_DIVERGENCE(ID-1)` を宣言する。**旧＝注文が成功し在庫がマイナスになる／新＝注文が失敗し在庫が不変**。前処理で**在庫を注文数未満へセット**する（両側）。旧側の在庫操作は #48 AC-neg2 の規律（採取後に復元）に従う。
- [ ] **AC6（スコープ境界）**: **カート単体はシナリオ化しない**（legacy はセッション保持で DB に落ちないため注文確定に畳む＝設計 §2 の決定）。**アカウント系（W4 登録・W5 更新）は本Story対象外**＝次イテレーション（設計 §6-2。旧 `account`/`profile`/`signon` と新 `m_account`/`m_profile`/`m_signon` の対応づけが未確定のため）。
- [ ] **AC7（legacy 不要で走る）**: 追加した全シナリオを含めて、**legacy を停止した状態で `parityTest` が green**（`EQUIVALENT` 4系統＋`INTENDED_DIVERGENCE` 2件の宣言がすべて実測と一致）。
- [ ] **AC-neg1（宣言と実測の不一致は失敗）**: `EQUIVALENT` 宣言のシナリオが不一致 → **失敗**（＝台帳に無い差分＝欠陥候補）。`INTENDED_DIVERGENCE` 宣言のシナリオが一致 → **失敗**（＝台帳の形骸化）。両方向がテストで実証されていること。
- [ ] **AC-neg2（golden のメタ）**: 追加した golden すべてに `capturedFrom.legacyCommit` と `capturedAt` が入っていること（#48 AC8 の踏襲）。

### 備考

- **優先順位の根拠**: L2 の価値は**本数と網羅**にある。#48 は縦切り1本の仕組み実証にとどまるため、本Storyで初めて「読み取り系＋注文の主要バリエーション」という**説明可能な母集団**になる。また ID-1／ID-29 に**観測点**が付くことで、L4 の台帳照合の一部が自動化される（設計 §5）。
- **依存関係**: **#48（前提）**。cross-repo なし（`jpetstore-backend` の test スコープ単独／legacy は起動のみ・無改変）。カバレッジ計測 Story は本Story完了後に全シナリオで再計測する。
- **spike 実測との関係**: 読み取り系（カテゴリ5・商品3・アイテム3・検索6パターン）は spike で一度通っている（`spec/l2-parity-design.md` §7.2 の計測はこの構成＋W1 で採られた）。**§7 の実測を推測で上書きしないこと**。
- **`spec/intended-diff-ledger.md` への追記**: **不要**。ID-1／ID-29 は既存宣言であり、本Storyはそれに観測点を与えるだけ。関連Story欄への本Issue番号追記の要否は完了後の Retro で判定する。
- **DoD 補足**: `parityTest` は `check` に載せない方針（#48 AC11）のため、**明示実行して green であること**を完了条件に含める。

_Refinement: PO 2026-08-20（#48 と同時起票・Story 分割は「縦切り1本 → 横展開」）。_

---

## #50 [L2] legacy のカバレッジを overlay イメージで計測し、ゲート値を PO と合意する

**ラベル**: foundation ／ **SP**: 3 ／ **Sprint**: 21 ／ **Ready**: Ready

### ユーザーストーリー

**As a** JPetStore 移行のステークホルダー（および PO/SM）
**I want to** パリティのシナリオが legacy の「保存すべき業務ロジック」をどれだけ踏めているかを、**定義済みの分母に対する数値**で示したい
**So that** 「テストの本数は十分か／網羅性は担保されているか」に、印象論ではなく実測とゲート値で答えられる

### トレース

- **設計**: `spec/l2-parity-design.md` 決定 **P3**・§4（JaCoCo カバレッジゲート）・§7.2（初期実測）・§7.3（overlay での注入）
- **意図差分台帳**: `spec/intended-diff-ledger.md` **ID-5**（remoting 廃止）・**ID-6**（JSP→SPA）＝分母から除外する根拠
- **前提 Story**: #48（基盤・W1）／#49（横展開）。**全シナリオが揃ってから計測する**

### Acceptance Criteria

- [ ] **AC1（分母の固定＝保存すべき業務ロジックだけに絞る）**: 分母は legacy 全73クラスのうち **29クラス**（うち JaCoCo が解析対象とするのは 22。残りはインタフェース等）とする。

  | パッケージ | クラス数 | 分母 | 理由 |
  | --- | --- | --- | --- |
  | `domain` | 8 | **含む** | 業務ロジックの中核 |
  | `domain.logic` | 6 | **含む** | 同上 |
  | `dao` | 5 | **含む** | 永続化（クエリの意味を保存） |
  | `dao.ibatis` | 10 | **含む** | 同上（内部クラス1を含む） |
  | `web.struts` | 24 | 除外 | SPA+REST へ置換（**ID-6**） |
  | `web.spring` | 18 | 除外 | 同上（**ID-6**） |
  | `service` / `service.client` | 2 | 除外 | remoting 廃止（**ID-5**） |

  **除外理由をレポートに明記**し、「保存対象29クラス（解析22）に対してブランチ○%」と定義済みの分母で語れる状態にする。
- [ ] **AC2（overlay イメージで注入・legacy 無改変）**: `FROM jpetstore-legacy` の overlay イメージ（**別タグ** `jpetstore-legacy-jacoco`）で `jacocoagent.jar` と `entrypoint-jacoco.sh` を被せる方式とする（設計 §7.3）。
  - `run/Dockerfile`・`run/entrypoint.sh`・アプリのソース・WAR は**一切変更しない**（凍結アーティファクトの原則）
  - agent 引数は `-javaagent:/opt/jacocoagent.jar=destfile=/jacoco/jacoco.exec,append=true,includes=org.springframework.samples.jpetstore.*` を `exec catalina.sh run` の直前に `CATALINA_OPTS` で差す
  - agent / cli は `org.jacoco:org.jacoco.agent:0.8.12:runtime` / `org.jacoco:org.jacoco.cli:0.8.12:nodeps`（backend の JaCoCo と同版）
- [ ] **AC3（採取と集計の運用）**: 「**全シナリオを1つの exec に流し直す**」運用とする（マージの stale 事故ゼロ）。
  1. agent 付きで docker start（`-v <host>:/jacoco`）
  2. `captureGolden` で全シナリオを実行
  3. **`docker stop -t 30` の graceful 停止**でシャットダウンフックに `jacoco.exec` を書かせる
  4. `jacococli report jacoco.exec --classfiles <分母ツリー> --html <out> --xml <out>/jacoco.xml`。**`--classfiles` には AC1 の分母だけを置いたツリーを渡す**（WAR の `WEB-INF/classes` から `domain`/`dao` 配下のみコピー）
- [ ] **AC4（実測の提示）**: #48 + #49 の**全シナリオ**で BRANCH / LINE / INSTRUCTION / CLASS を**パッケージ別に実測**し、レポートとして提出する（`reports/after/` 配下）。spike 時点の初期実測を**出発点として併記**し、増分が分かる形にする。

  | 指標 | spike 時点の実測（読み取り系＋W1 のみ） |
  | --- | --- |
  | **BRANCH** | **16/42 = 38.1%** |
  | LINE | 297/452 = 65.7% |
  | INSTRUCTION | 1119/1765 = 63.4% |
  | CLASS | 19/22 = 86.4% |

  パッケージ別では **`domain.logic` の branch 0.0%（line 25.0%）が最大のギャップ**。W2/W3 追加後にこのギャップがどう動いたかを明示すること。
- [ ] **AC5（ゲート値の合意）**: **カバレッジのゲート値は本Storyの中で、実測を見てから PO と合意する**（AC 起票時点では決め打ちしない。先に数値を決めると帳尻合わせになるため＝設計 §4.4・§6-1）。合意した値・その根拠・**到達不能な分岐（廃止機能への分岐等）の除外理由**をレポートに明記する。**silent な打ち切りをしない**こと。
- [ ] **AC6（次に足すべきシナリオの名指し）**: 未踏の分岐から「あと何本必要か」を導き、**次イテレーションの候補**（アカウント系 W4/W5・注文履歴照会など）をレポートに列挙する（設計 §4.4 のループを回せる状態にする）。
- [ ] **AC-neg1（legacy 無改変・後始末）**: 計測後、**イメージ `jpetstore-legacy` が無改変**であること（計測用は別タグ `jpetstore-legacy-jacoco`）。採取用コンテナは停止し、採取のために操作した HSQLDB のデータは復元する（#48 AC-neg2 の規律を踏襲）。

### 備考

- **優先順位の根拠**: 決定 **P3** により「カバレッジゲートは初回から同時に導入する」＝「本数は十分か」に数値で答えるための仕組み。ただし**意味のある数値は全シナリオが揃ってから**しか出ないため、#48 → #49 の**後**に置く。
- **依存関係**: **#48・#49（前提）**。cross-repo なし（overlay イメージのビルド定義は `migration-agent-base` 側に置く。`legacy-jpetstore` リポジトリは無改変）。
- **未決事項として意図的に残しているもの**: **ゲート値**（AC5 で合意）。新側（`jpetstore-backend`）のカバレッジゲートは**本Storyのスコープ外**（既存 `jacocoTestReport` の運用を変えない）。
- **CI**: 現時点でどのリポジトリにも GitHub Actions が無いため、計測は**手動運用**とする。Actions 導入時に `parityTest` とあわせて品質ゲートへ昇格する（設計 §3・§6-4）。
- **`spec/intended-diff-ledger.md` への追記**: **不要**（計測の追加であり旧新の振る舞いを変えない）。

_Refinement: PO 2026-08-20（#48・#49 と同時起票。ゲート値は実測後に合意する運びを AC5 で明文化）。_

---

## リスク・チャレンジ

| # | 内容 | 対策 |
| --- | --- | --- |
| **R1** | **新種のスプリント**（プロダクトコードを1行も変えない「検証基盤」スプリント）。tier 分離20連続の実績はあるが、**test スコープのみ・外部プロセス（Docker legacy）依存**は初 | 計画フェーズで D1〜D3 を確定済み。spike の実測（設計 §7）を一次情報として尊重し、推測で上書きさせない |
| **R2** | **RANDOM_PORT 実 HTTP がコードベース初**。CSRF ローテーション（F3）と Cookie/セッション保持の扱いで嵌まりやすい | 「トークンが取れるまで GET を繰り返す」ヘルパを**最初に**作る（spike で4回踏んだ落とし穴） |
| **R3** | **legacy の状態汚染**（F4）。W3 は在庫をマイナスにするため復元が必須 | D2 で確定＝W3 のみコンテナ再作成。#48 AC-neg2 / #50 AC-neg1 で後始末を AC 化済み |
| **R4** | **JaCoCo の graceful stop 失敗で計測が丸ごと消える** | `docker stop -t 30` を手順として固定。強制停止しない |
| **R5** | **#50 のゲート値を先に決めてしまう**帳尻合わせのリスク | AC5 のとおり**実測 → SM が PO を起動して合意**の順を守る。スプリント途中に SM が PO を起動するステップを明示 |
| **C1（チャレンジ）** | **spike の再実装が「先例規約」として機能するか**の実効性検証（Sprint7/13/16 の C1 と同型）。#48 で確立した規約を #49 が**新しい仕組みを作らずに**横展開できたら成功 | #49 のレビューで「#48 の規約を無改造で再利用できたか」を評価軸に含める |
