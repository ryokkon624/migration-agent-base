# Phase 4 verification-report — 「旧を正しく再現できた範囲」と「言えない範囲」

> **これは何か**: JPetStore レガシー刷新（Struts1 → Vue3 SPA + Spring Boot）について、**旧システムを正しく再現できたと言える範囲を、言えない範囲と一緒に**提示するステークホルダー提出物。
> **判定規範**: [`spec/verification-strategy.md`](../../spec/verification-strategy.md) §5（Phase 4 合否ゲート）。
> **分母**: [`spec/intended-diff-ledger.md`](../../spec/intended-diff-ledger.md)（意図差分台帳）。
> **担当**: SM / PO（Sprint 23・`ryokkon624/jpetstore-manage#52`）／ **日付**: 2026-08-21
> **一次データ**: `jpetstore-backend` の parity シナリオ・golden・Spock/Vitest テスト実体、`tools/legacy-jacoco/out3/report/gate-v2/jacoco.csv`、`reports/after/l3-security-regression-*.md`、`legacy-jpetstore` の実ソース。**他レポートの記述の転記ではなく、現物を開いて確認している**（#52 AC3）。

---

## 0. 立場 — この文書が答えている問い

日本的な「（中身は知らないが）**何も変わっていないと証明しろ**」という要求に対して、本プロジェクトは **1:1 再現ではなく仕様源からの作り直し（AI Factory）** を採った。よって「旧と完全一致」を品質基準に置けない／置くべきでない部分がある。

その代わりに置いたのが **意図差分台帳** と **4層の検証**である。

| レイヤ | 何を検証 | 正解の源 |
| --- | --- | --- |
| **L1 AC 準拠テスト** | 各 Story の AC を満たすか | 抽出仕様（`spec/behavior/*`・`backlog-map`） |
| **L2 特性化テスト（旧同値）** | 保存すべき業務ロジックの「入力→出力＋DB 意味デルタ」 | legacy 実測（golden fixtures） |
| **L3 セキュリティ回帰** | before の PoC が after で**失敗**すること | `reports/before` の finding / PoC |
| **L4 意図差分の確認** | 変えた振る舞いが**台帳どおり**か | 意図差分台帳 |

**本書は L4 であり、Phase 4 の締めである。** L4 の役割は新しい検証をすることではなく、**L1/L2/L3 が台帳のどの項目を実際に見ているのかを突き合わせ、見ていない項目を見ていないと言うこと**にある。

> **本書の最も重要な性質**: 「観測点がある」ことより「**観測点が無いところがどこか**」を明示することに価値がある。
> 「穴」は穴として書いてある。埋めていない穴は、埋めていないと書いてある。

---

## 1. L4 の方法

### 1.1 判定の4分類

| 判定 | 意味 |
| --- | --- |
| **観測点あり** | L2 の expectation 宣言 / L3 の回帰表 / L1 の AC テスト の**いずれかで実際に検証されている** |
| **構造的に観測不能** | 比較対象そのものが存在しない（旧側に対応概念が無い／比較単位を定義できない） |
| **観測不要** | もはや差分でない（旧新で振る舞いが一致するに至った） |
| **穴** | 観測点が無く、作るべき |

### 1.2 「観測点あり」と認めるための規則（水増し防止）

本書は次の3つを**根拠として名指しできたときだけ**「観測点あり」とした。

- **L2**: シナリオ ID ＋ `ParityScenarios.groovy` の `expectation` 宣言の**実際の文字列** ＋ golden ファイル名
- **L3**: レポート名と **S 番号** ＋ 根拠種別（`live` = 稼働環境への実リクエスト／`code` = コード位置） ＋ **その根拠が実際に何を観測しているか**
- **L1**: **実在する Spec クラスの実在するテスト名**（Groovy は `def "..."` の文字列そのまま、frontend は `it('...')` の文字列そのまま）＋ `file:line`

### 1.3 「宣言」と「観測」を混同しない

L2 の canonical モデル（`ParitySnapshot.groovy:14-18` ほか）は、**一部のフィールドを最初から比較対象から外している**。

> 比較から除外するフィールドはそもそも本モデルに持たせない（新側 WHO 6列・version・自動採番ID・created_at/updated_at ／ 旧側 creditcard/exprdate/cardtype・courier/locale・orderstatus・linenum）

これに Sprint 22 の決定（`password`/`password_hash` は案A で比較対象外・`mylistopt`/`banneropt`/`bannerdata` は ID-7 由来で除外・`color_scheme_preference` は ID-31 由来で除外）が加わる。

**正規化除外は「そこに差分があると宣言している」だけであって、「差分を観測している」ことではない。** 本書はこれを観測点として数えない。この区別を落とすと「観測点あり」が水増しになる。

### 1.4 検算の作法

本書の数値は **SM が一次データを自分でパースして再現**したものだけを載せた。派生値・他レポートの記述は根拠にしていない。
検算の全記録は [`backlog/sprint_23/sm-verification.md`](../../backlog/sprint_23/sm-verification.md)（V1〜V12）。

**この作法により、本 L4 の作業中に SM 自身の誤り（V11）も1件検出・訂正している。**

---

## 2. 台帳 × 検証手段の対応表

**台帳は L4 の作業中に 31 件 → 33 件になった。** ID-32・ID-33 は「L4 が実測して見つけた未台帳の差分」であり、本 Sprint で台帳へ追記した（§5.2）。よって対応表は **33 行**である。

### 2.1 内訳

| 判定 | 件数 | 内訳 |
| --- | --- | --- |
| **観測点あり** | **31** | L1 = 14 ／ L3 = 13 ／ **L2 = 4** |
| うち **部分観測** | （6） | ID-6・ID-14・ID-22・ID-23・ID-26・ID-32 |
| **穴** | **2** | **ID-30**（チェックアウト下書きの揮発）・**ID-33**（カート一覧のページング廃止） |
| **構造的に観測不能** | **0** | ※下記 2.2 参照 |
| **観測不要** | **0** | ※下記 2.3 参照 |

> **旧新比較（L2）が成立している台帳 ID は 33 件中 4 件（ID-1・ID-14・ID-24・ID-29）だけ**である。
> 残りは L1（新側の AC 準拠）か L3（旧の脆弱性が消えたこと）で見ている。**「旧と同じであること」を直接比較で示せている範囲は、台帳を分母に取ると狭い。** これは L2 の欠陥ではなく、AI Factory が 1:1 再現ではないことの必然的な帰結である（§0）。

### 2.2 「構造的に観測不能」が 0 件になった理由

Issue #52 AC2 は ID-6（JSP→SPA）をこの分類の例に挙げていた。実測の結果、**判定規則を次のように置いた**：

> **観測点が一つでも存在すれば「観測点あり」に置き、比較できない部分は「観測の限界」列に書く。**
> 「構造的に観測不能」は**新の振る舞いを検証する観測点すら作れない**場合に限る。

この規則の下では ID-6 も ID-31 も観測点を持つ（ID-6 = 旧 SSR 面の消滅を S1 の `live` で実測／ID-31 = `AppHeader.spec.ts` ほかの L1）。**両者とも「旧新比較としては構造的に不能」であるが、それは限界列に明記した。**
「観測点が無い」と「比較ができない」を同じ欄に混ぜると、**穴が構造的制約に見えてしまう**ため分けた。

### 2.3 「観測不要」が 0 件になった理由 — AC2 の例示（ID-27）は成立しなかった

Issue #52 AC2 は ID-27（多言語）を「もはや差分でない（#25 で実装完了）」の例に挙げていた。**一次データと突き合わせた結果、この前提は誤りだった。**

- legacy に**日本語資産が1つも存在しない**：`src/main/webapp/WEB-INF/jsp/` は `spring`/`struts` の2ディレクトリのみ、`src` 配下の `*.properties` は `jdbc`/`log4j`/`mail` の3本のみ。
- `getLanguagePreference()` を読む**描画ロジックが存在しない**：`profile.langpref` は `Account.xml` で永続化され、`jsp/struts/IncludeAccountFields.jsp:41` のセレクトで選ばせるだけ。`web/spring/AccountFormController.java:25` の `LANGUAGES = {"english","japanese"}` は選択肢の配列にすぎない。
- つまり**旧は言語を選べるが、選んでも何も起きない**。

よって「同じ言語設定値に対して描画が変わるか」という比較は**今も成立する**（旧＝変わらない／新＝変わる）。#25 の完了が閉じたのは**新側内部のスコープ差（段階的ローカライズ）**であって旧新差分ではない。
→ **ID-27 は「観測不要」ではなく「観測点あり（L1）」**。あわせて台帳 ID-27 の as-is 記述を訂正した（§5.1）。

### 2.4 対応表（33 行）

- 根拠の名指し規則は §1.2 のとおり。**実在する Spec の実在するテスト名**だけを書いている。
- 完全版（各行の全根拠）は [`backlog/sprint_23/dev-observation-points.md`](../../backlog/sprint_23/dev-observation-points.md)（DEV 実測）と [`backlog/sprint_23/po-ledger-classification.md`](../../backlog/sprint_23/po-ledger-classification.md)（PO 仕様側判定）。本表はその突き合わせ結果である。
- 観測点の探索は `jpetstore-backend` / `jpetstore-frontend` / **`jpetstore-database`** の3リポジトリを対象にした（ID-7・ID-21・ID-22・ID-23 の観測点は database の schema Spec にしか存在しないため。DEV の指摘で範囲を広げた）。

| ID | 何をどう変えたか | 検証手段 | 根拠（名指し） | 判定 | 観測の限界 |
| --- | --- | --- | --- | --- | --- |
| **ID-1** | 在庫ガード付きアトミック減算・在庫不足で注文失敗 | **L2**<br><sub>根拠の所在: `be`</sub> | シナリオ `order-insufficient-stock`／`ParityScenarios.groovy:70-72` の宣言＝`new Scenario("order-insufficient-stock", "INTENDED_DIVERGENCE(ID-1)", ["outcome", "inventoryDelta[EST-1]", "ordersCreated", "orderTotal", "lines[EST-1].quantity", "lines[EST-1].unitPrice"])`／golden `src/test/resources/parity/golden/order-insufficient-stock.json`（`divergenceId:"ID-1"`・旧 snapshot は `outcome:"SUCCESS"`, `inventoryDelta:{"EST-1":-2}`, `ordersCreated:1`, `orderTotal:"33.00"`、`preconditions:{"EST-1":{"qtyBefore":1,"qtyAfter":-1}}`＝**旧が在庫1に対し2個注文して成功し在庫を −1 へマイナス化した実測が固定されている**）／実行は `parity/OrderParitySpec.groovy:56` `def "#scenarioId: 新側がcommit済みgoldenと宣言どおりの結果になる(#48 AC9/AC12・#49 AC7)"`（`where: scenarioId << ["order-single-item", "order-multi-item", "order-insufficient-stock"]`）<br>**補強(L1)**: `infrastructure/mybatis/custom/mapper/InventoryCustomMapperSpec.groovy:65` `def "在庫不足(quantity<n)はaffected rows=0で在庫が不変のままInsufficientStockExceptionになる"`／同 `:81` `def "ちょうど在庫数と同数の減算はaffected rows=1で在庫が0になる(境界値)"`／`presentation/rest/OrderConcurrencyIntegrationSpec.groovy:101` `def "在庫qty=1の同一アイテムへ2ユーザーが同時にplaceOrderすると1件成功・1件409になり在庫は負数化しない"`<br>**補強(L3)**: `l3-security-regression-backend.md` **§2.3「堅牢と確認した領域」の「在庫減算の並行安全（D6/ID-1）」**（126行目）／根拠種別 **`code`**／観測内容: ガード付き単文アトミック減算（`quantity>=#{quantity}`）で TOCTOU/売り越しが不能であること・item_id 昇順固定順・`@Transactional` all-or-nothing・**affected-rows==0 判定**をコードで確認。**§1 の S1〜S21 回帰表には ID-1 の行は無い**（§1 の ID 列は下記「L3 §1 が ID を張っている11件」参照） | 観測点あり | — |
| **ID-2** | PW ハッシュ＋ソルト保存・照合 | **L3**<br><sub>根拠の所在: `rep` + `be` + `db`</sub> | `l3-security-regression-backend.md` §1 の **S7**／根拠種別 **`live`**／**何を観測しているか**: 稼働 DB の `information_schema` を実測し「パスワード平文列がゼロ・`m_signon.password_hash` の値が `{bcrypt}$2a$10$…` 形式である」ことを確認している（＝旧の平文保存が実際に消えたことの観測。§1 付録 (e) にも記載）。<br>**補強(L1)**: `config/PasswordEncoderConfigSpec.groovy:16` `def "encodeした結果は平文と一致しない(AC1: 平文保存しない)"`／同 `:24` `def "encodeした結果はbcrypt形式である(AC1: bcryptでハッシュ)"`／同 `:36` `def "同じ平文でも呼ぶたびに異なるハッシュになる(ソルト付与の確認)"`（＝**ソルトの観測点**）／`presentation/rest/RegistrationControllerSpec.groovy:127` `def "AC-neg1(SBD-5): 登録後のpassword_hashはbcryptプレフィックス付きで平文と一致しない"`／`parity/AccountParitySpec.groovy:75` `def "AC-neg4(W4): 登録したPWでログイン成功し、m_signon.password_hashは平文と一致しない(SBD-5/ID-2案A)"`（**parity spec 内だが golden 比較の外側＝L2 の expectation 宣言ではない**。同ファイル 26-27 行のクラス javadoc に「canonical比較の対象外の独立検証」と明記）／database `schema/AccountTablesSpec.groovy:34` `def "AC2: m_signon.password_hash は varchar(255) NOT NULL である（旧varchar(25)から拡張）"` | 観測点あり | — |
| **ID-3** | 金額 `double` → `BigDecimal` / `decimal` | **L1**<br><sub>根拠の所在: `db` + `be`</sub> | `decimal` 側: database `schema/OrderInventoryTablesSpec.groovy:23` `def "AC4: t_order.total_price は decimal(10,2) である"`（`col.DATA_TYPE == "decimal"` / `NUMERIC_PRECISION == 10` / `NUMERIC_SCALE == 2`）／同 `:33` `def "AC4: t_order_line.unit_price は decimal(10,2) である"`／`schema/CatalogTablesSpec.groovy:38` `def "AC4: m_item.#column は decimal(10,2) である"`<br>`BigDecimal` 側: `infrastructure/mybatis/custom/mapper/OrderCustomMapperSpec.groovy:140` `def "selectOrderHeaderByIdはuserIdを含む単一行を返し、存在しなければnullを返す"`（`header.totalPrice == new BigDecimal("10.00")`＝スケール込みの厳密一致）／同 `:153` `def "selectOrderLinesByOrderIdはJOINでproduct_nameを補完しline_num順に返す"`（`lines[0].unitPrice == new BigDecimal("10.00")`）／`presentation/rest/OrderControllerSpec.groovy:181` `def "AC2/AC3(arch §4.1): 注文確定後にt_order/t_order_line/t_inventoryへ正しく永続化される"`（実 MySQL から読んだ `order.total_price == new BigDecimal("30.00")`）／`application/service/OrderApplicationServiceSpec.groovy:67` `def "AC1/AC-neg1: 合計はクライアント値を無視しΣ(listPrice×quantity)でサーバ再計算される"`（`cartItem(String,int,BigDecimal)` ヘルパ経由の `BigDecimal` 合計）<br>**補強(L2・丸めの非退行)**: `order-single-item` / `order-multi-item` / `order-detail-own` の golden は `orderTotal` を**文字列**（例 `"33.00"`）で固定して `EQUIVALENT` 比較しており、`double`→`BigDecimal` 化で金額が変わっていないことを旧実測に対して観測している | 観測点あり | — |
| **ID-4** | サービス層認可（プリンシパル基準）＋ not-owned/not-found を同一応答 | **L3**<br><sub>根拠の所在: `rep` + `be`</sub> | `l3-security-regression-backend.md` §1 の **S15**／根拠種別 **`live`**／**何を観測しているか**: 稼働 backend への IDOR PoC（§1 付録 (b)）で「自分の注文=200／他人の注文=403／非存在 `/api/orders/999999999`=403（他人と**同一応答**）／`?account.username=` 注入は 403 のまま／`GET /api/orders?account.username=…` は自分の注文のみ返る」を実リクエストで実測している。<br>あわせて **S3**（根拠 `live`+`code`: 差し替え対象のセッション属性が stateless JWT で存在しない）・**S2**（根拠 `code`: `AccountEditRequest` が username/userid/status/version/WHO列を**型として持たない** allowlist）。<br>**補強(L1)**: `domain/security/OwnershipAuthorizationServiceSpec.groovy:18` `def "所有者(userId一致)なら例外を投げない"`・`:29` `def "非所有者(userId不一致)ならAccessDeniedExceptionを投げる"`・`:40` `def "未認証ならAccessDeniedExceptionを投げる(CurrentUserProvider#requireCurrentUserの既定動作を利用)"`／`presentation/rest/OwnershipAuthorizationEndToEndSpec.groovy:62` `def "非所有者(userIdが不一致)がアクセスすると403かつ監査ログに記録される(AC1/AC2)"`／`presentation/rest/OrderControllerSpec.groovy:509` `def "#10 AC-neg1(SBD-1): 他人の注文詳細は403になる"`・`:519` `def "#10 AC-neg2(SBD-8/SBD-10): 存在しない注文詳細も403(他人と同一・存在推測不可)でtrace/内部詳細を露出しない"`・`:479` `def "#9 AC-neg1(SBD-1): account.usernameクエリを他人に差し替えても自分の履歴のみ返る(identity-rebind IDOR再現せず)"`／`application/service/AccountApplicationServiceSpec.groovy:153` `def "updateAccount: CurrentUserProvider起点のuserIdをAccountUpdateへ渡す(AC1本人固定・usernameをクライアントから受けない)"` | 観測点あり | — |
| **ID-5** | remoting 面（Hessian/Burlap/HttpInvoker/Axis）の廃止 | **L3**<br><sub>根拠の所在: `rep` + `be`</sub> | `l3-security-regression-backend.md` §1 の **S13**・**S14**・**S16**（＋ S1・S15 の消滅側）／根拠種別 **`live`**／**何を観測しているか**: **認証済み**（未認証だと deny-by-default の 401 になり「ハンドラの真の不在」を確認できないため）で `GET /remoting/OrderService`・`/remoting/AccountService`・`/remoting/CatalogService`・`/axis/services/Version`・`/axis/servlet/AxisServlet`・`/services/OrderService` を叩き、すべて **404** を実測している（§1 付録 (a) にレスポンス一覧）。<br>**補強(L1)**: `presentation/rest/RemotingSurfaceAbsenceSpec.groovy:18` `def "remoting/WSエクスポータ/エンドポイントクラス(#className)はclasspathに存在しない(SBD-7)"`（`Class.forName` が `ClassNotFoundException` になることで `HessianServiceExporter`／`BurlapServiceExporter`／`HttpInvokerServiceExporter`／`RmiServiceExporter`／`RemoteExporter`／`org.apache.axis.transport.http.AxisServlet`／`jakarta.jws.WebService` の **7クラス**の classpath 不在を固定する回帰テスト） | 観測点あり | — |
| **ID-6** | JSP / サーバサイドレンダリング → Vue3 SPA＋REST | **L3**<br>（**部分観測**）<br><sub>根拠の所在: `rep`</sub> | `l3-security-regression-backend.md` §1 の **S1**／根拠種別 **`live`**／**何を観測しているか**: 認証済みで `GET /newOrder.do?confirmed=true`・`/shop/viewOrder.do`・`/editAccount.do`・`/shop/index.do` を叩き、すべて **404** を実測（§1 付録 (a)）＝**旧の JSP/Struts サーバサイドレンダリング面が実際に消えたこと**の観測。あわせて **S9**（根拠 `live`+`code`: backend src 全体に `sendRedirect`/`RedirectView`/`redirect:` が **0件**＝サーバ側画面遷移機構の不在）。<br>**⚠️ 帰属の注意**: **§1 の S1 行の「対応 SBD / ID」列は `ID-5 / SBD-7` であって ID-6 ではない**（S9 も `ID-12`）。つまり **ID-6 を名指しで判定している L3 行は存在せず**、DEV が「S1 の `live` 根拠が結果として ID-6 の旧側の消滅を観測している」と判断して割り当てたもの。<br>**⚠️ 観測できていない部分**: 「新＝Vue3 SPA＋REST である」という**肯定側**を固定している観測点は**存在しない**（frontend 267 テストと backend の REST テスト群はそれを前提にしているだけ）。backend テストに JSP/ViewResolver/Thymeleaf を検査するものも **0件**（`grep -rin "jsp\ | 観測点あり<br>（**部分**） | **旧新比較の単位が定義できない**（UI 総取替）。観測できているのは旧 SSR 面の**消滅**のみで、「新＝SPA+REST」の**肯定側**を固定する観測点は無い（S1 行の ID 列は `ID-5`） |
| **ID-7** | banner 広告 / MyList の廃止（bannerdata INNER JOIN 依存の解消） | **L1**<br><sub>根拠の所在: `db`</sub> | database `schema/AccountTablesSpec.groovy:49` `def "AC3: bannerdata テーブルは存在しない"`／同 `:54` `def "AC3: m_profile に banner/mylist 関連列は存在しない"`／`schema/AccountJoinWithoutBannerdataSpec.groovy:10` `def "bannerdata テーブルは存在しない"`・`:15` `def "AC-neg1: bannerdata無しで account+signon+profile がJOINで1件取得できる"`（＝**旧が bannerdata への INNER JOIN に依存していたアカウント取得が、bannerdata 無しで成立することの観測**）／`schema/AccountTablesSpec.groovy:63` `def "m_profile.favorite_category_id は任意設定として残る"`<br>`jpetstore-backend` / `jpetstore-frontend` に ID-7 の観測点は**無い**（backend テスト資源にあるのは `src/test/resources/flyway/sql/V00_000_004__create_account_tables.sql:12,73` の**SQLコメント**のみで、テストではない） | 観測点あり | — |
| **ID-8** | カード列/入力欄/必須検証の撤去・支払プレースホルダ | **L1**<br><sub>根拠の所在: `be` + `db`</sub> | `presentation/rest/OrderControllerSpec.groovy:327` `def "#12 AC1/AC2/AC-neg1(ID-8): creditCard/cardNumber/expiryDate等を注入しても無視され201になり、レスポンスにcard関連キーは一切含まれない"`／同 `:340` `def "#12 AC-neg1(ID-8): 注文確定レスポンスJSONにcard/creditCard関連フィールドは存在しない"`／database `schema/OrderInventoryTablesSpec.groovy:43` `def "AC5: t_order にカード関連列(creditcard/exprdate/cardtype)は存在しない"`（`creditcard`/`credit_card`/`exprdate`/`expiration_date`/`cardtype`/`card_type` の6名を `columnNamesOf("t_order")` から除外 assert） | 観測点あり | — |
| **ID-9** | 状態変更 GET・CSRF 不在 → 非冪等 POST＋CSRF トークン | **L3**<br><sub>根拠の所在: `rep` + `be` + `fe`</sub> | `l3-security-regression-backend.md` §1 の **S5**／根拠種別 **`live`**／**何を観測しているか**: `X-XSRF-TOKEN` を欠いた `POST /api/account/password`・`POST /api/auth/logout`・`POST /api/orders` がいずれも **403** になることを実リクエストで実測。§1 付録 (c) では Cookie とヘッダの**片方欠落でも 403** を実測。<br>**補強(L1)**: `presentation/rest/AuthLoginLogoutSpec.groovy:179` `def "CSRFトークン無しでPOST /api/auth/loginすると403になる(AC4)"`・`:187`（logout 同）・`:193` `def "GET /api/auth/loginは405になる(AC-neg2・GET状態変更なし)"`・`:199`（logout 同）＝**旧の「GET リンクで状態変更が成立する」経路の不在の観測**／`presentation/rest/OrderControllerSpec.groovy:286` `def "CSRFトークン無しでPOST /api/ordersすると403になる(AC4)"`／`presentation/rest/CartControllerSpec.groovy:311` `def "#6 AC-neg1: XSRF-TOKEN Cookieの値とX-XSRF-TOKENヘッダの値が不一致だと403になる(攻撃者はCookie値を読めず正しいヘッダを付与できない状況の再現・double-submitの照合失敗)"`・`:321`・`:409`／`presentation/rest/RegistrationControllerSpec.groovy:283`・`:292`／frontend `src/api/__tests__/httpClient.spec.ts:45` `it('非冪等POSTはCookieのXSRF-TOKEN生値をそのままX-XSRF-TOKENヘッダへ付与する(非XOR・マスクしない)')`・`:33` `it('GETリクエストはX-XSRF-TOKENヘッダを付与せず、credentials:includeを指定する')` | 観測点あり | — |
| **ID-10** | ログイン/登録時にセッション再生成 | **L3**<br><sub>根拠の所在: `rep` + `be`</sub> | `l3-security-regression-backend.md` §1 の **S8**／根拠種別 **`live`**／**何を観測しているか**: ログイン応答の `Set-Cookie` が `ACCESS_TOKEN`/`REFRESH_TOKEN` のみで **`JSESSIONID` を発行しない**ことを実測（＝旧の「固定化されうるセッションID」自体が存在しないことの観測）。<br>**補強(L1)**: `presentation/rest/AuthLoginLogoutSpec.groovy:205` `def "ログイン成功時に発行されるACCESS_TOKENは新規トークンであり、事前に付与されたCookieは再利用されない(AC2/AC-neg1・SBD-4固定化対策)"`（＝**攻撃者が事前に供給した資格 Cookie が引き継がれないこと**の観測）／`presentation/rest/RegistrationControllerSpec.groovy:143` `def "自動ログインで発行されたACCESS_TOKENで保護resourceにアクセスできる(セッション再生成・AC2/SBD-4)"` | 観測点あり | — |
| **ID-11** | POST body 限定・プリフィル廃止・DB-backed レート制限/ロックアウト | **L3**<br><sub>根拠の所在: `rep` + `be` + `db`</sub> | `l3-security-regression-backend.md` §1 の **S10**（根拠 `code`+`live`: `application.yml:53-58`・`LoginAttemptService`・`AuthApplicationService.java:64-84` ＋ **seed に `j2ee` が不在であることを DB 実測**）・**S11**（根拠 `live`: `GET /api/auth/login?username=..&password=..` → **405**、`GET /api/register` → **405**）・**S12**（根拠 `live`: 存在ユーザ誤PW と 非存在ユーザのログイン失敗が**バイト一致の 401**）。<br>**補強(L1)**: `presentation/rest/LoginLockoutSpec.groovy:92` `def "MAX_ATTEMPTS回連続失敗すると、その後は正しいpasswordでもログインできなくなる(AC1)"`・`:100` `def "ロック時の応答は通常の誤資格401と完全に同一(timestamp以外)(AC3・列挙不可)"`・`:115` `def "存在しないusernameもMAX_ATTEMPTS回失敗するとロックされる(SBD-6・password spray対策の対称性)"`・`:128` `def "lock_untilを過去に書き換える(ロック期間経過)と、正しいpasswordで再度ログインできる"`・`:139` `def "ログイン成功でカウンタがリセットされ、成功後はMAX_ATTEMPTS回失敗するまでロックされない(recordSuccess)"`／`presentation/rest/AuthLoginLogoutSpec.groovy:170` `def "j2ee/j2eeでログインすると401になる(#19 AC-neg1・弱資格情報は存在しない)"`（＝**プリフィル廃止側の観測**）・`:144` `def "未知のusernameでログインすると誤PWと同一の401になる(SBD-6・列挙不可)"`／`presentation/rest/RegistrationControllerSpec.groovy:251` `def "AC-neg2(SBD-6): 同一IPからの登録試行が閾値を超えると429になる(列挙/総当り対策)"`・`:269` `def "別IPからの登録試行はレート制限の影響を受けない(client_ip単位で分離)"`／**DB-backed であることの観測**は database `schema/LoginAttemptTableSpec.groovy`（6ケース・`t_login_attempt`）／`schema/RegisterAttemptTableSpec.groovy`（6ケース・`t_register_attempt`）<br>**L3 由来の回帰 spec（＝L3 findings の自動化）**: `presentation/rest/RateLimitBurstConcurrencySpec.groovy:166` `def "#41 AC1/AC-neg1(N4・L3§3残件1): 同一usernameへの20並列失敗ログインでもfailed_attempt_countが閾値で頭打ちになる"`・`:186` `def "#41 AC2/AC-neg2(N4・L3§3残件1): 同一client_ipへの20並列登録試行でもattempt_countが閾値で頭打ちになる"`・`:207` `def "S1: 同一usernameへのmaxAttempts並列の「成功」ログインは全て200を返す(誤ロックしない)"`。これは §2.1 の **N4**（`backend:auth:rate-limit-burst-toctou`・Medium・CONFIRMED(code)。§3-1 で「ライブ・バースト PoC は permission-gated で未実施」とされていた残件）を Sprint 20 #41 で修正し、**PoC の代わりに自動テストとして固定した**もの＝台帳 ID-11 の「照合前にスロットを原子確保」方式の観測点。`:207` は ID-11 が明記する受容済みトレードオフ（成功ログインも枠を消費する意味論）の境界の観測点でもある。<br>**⚠️ 残余**: `l3-security-regression-sprint20-delta.md` の **S20-1**（未認証監査 quota の窓を焼き切ると当該窓のログイン失敗が `t_audit_log` に残らない・Low）・**S20-2**（拒否経路が2接続を消費・Low）が受容されている。 | 観測点あり | — |
| **ID-12** | `forwardAction` の無検証 `sendRedirect` → allowlist/相対のみ | **L3**<br><sub>根拠の所在: `rep` + `be` + `fe`</sub> | `l3-security-regression-backend.md` §1 の **S9**／根拠種別 **`live`+`code`**／**何を観測しているか**: backend src 全体に `sendRedirect`/`RedirectView`/`redirect:` が **0件**（＝旧の無検証リダイレクト sink 自体の不在）を全数確認。frontend は `l3-security-regression-frontend.md` §1 の **項目6「オープンリダイレクト（SBD-9）— PASS（`code`）」**／`utils/redirectValidator.ts sanitizeRedirectTarget` が path-absolute のみ許可し、**復帰 URL を扱う 2 箇所とも**（`views/SignonView.vue:24`・`views/RegisterView.vue:86`）これを通すこと、`location.href`/`window.location`/`assign`/`replace(生URL)` の DOM sink が 0件であることを確認。<br>**補強(L1)**: `presentation/rest/AuthLoginLogoutSpec.groovy:240` `def "forwardActionパラメータを付与してもリダイレクトされない(#20 AC2/AC-neg2・SBD-9・sink不在の回帰)"`（＝**旧のパラメータ名 `forwardAction` を実際に投げて確認**）／frontend `src/utils/__tests__/redirectValidator.spec.ts:27` `it.each([...])('外部/プロトコル相対な復帰先(%s: %s)は拒否して既定値(/)にフォールバックする')`（`//evil.com`・`https://evil.com`・`http://evil.com`・`/\evil`・`\\evil`・` /evil`・`javascript:alert(1)`・`evil.com`・`/\t/evil.com`・`/\n//evil`・`/\r/evil`・`%2F%09%2Fevil.com` のデコード相当 の **12入力**）・`:5` `it.each([['/'],['/catalog'],['/cart/items?id=5'],['/account/profile#section']])('相対パス%sはそのまま許可する')`・`:38` `it('fallbackを明示指定した場合はそれを返す')` | 観測点あり | — |
| **ID-13** | 現在PW 未確認で PW 変更 → 現在PW 確認/再認証を必須 | **L3**<br><sub>根拠の所在: `rep` + `be`</sub> | `l3-security-regression-backend.md` §1 の **S6**／根拠種別 **`live`**／**何を観測しているか**: 誤った `currentPassword`（CSRF は正常）で `POST /api/account/password` を実行し、**422 "Current password is incorrect."** かつ **PW が未変更**であることを実測。<br>**補強(L1)**: `presentation/rest/PasswordChangeControllerSpec.groovy:110` `def "AC1/AC2: 正しい現在PWで変更すると204になりhashが更新され、新しいトークンが発行される(Q3)"`・`:133` `def "AC-neg1: 現在PWが誤りだと422になり、hashは変更されない"`・`:148` `def "AC-neg1: 現在PWが空だと400になる(@NotBlank)"`／`application/service/AccountApplicationServiceSpec.groovy:225` `def "changePassword: 現在PWがhashと一致すれば新PWをbcryptエンコードしupdatePasswordへ渡し、トークンをローテートする(AC1/AC2/Q3)"`／`parity/AccountParitySpec.groovy:111` `def "AC-neg4(W5b): PW変更後は新PWでログイン成功・旧PWでログイン失敗(401)"` | 観測点あり | — |
| **ID-14** | 500＋スタックトレース露出 → 正規化・trace 非露出（注文詳細は ID-4 重畳で 403） | **L2**<br><sub>根拠の所在: `be` + `rep`</sub> | シナリオ `order-detail-missing`／`ParityScenarios.groovy:63-64` の宣言＝`new Scenario("order-detail-missing", "INTENDED_DIVERGENCE(ID-14)", ["httpStatus", "stackTraceExposed"])`／golden `order-detail-missing.json`（`divergenceId:"ID-14"`・旧 snapshot が `httpStatus:500`・`stackTraceExposed:true`、`preconditions:{"999999999":{"orderExists":false,"legacyExceptionClass":"java.lang.NullPointerException"}}`＝**旧の 500＋トレース露出そのものが証拠として固定されている**）／実行は `parity/OrderHistoryParitySpec.groovy:54` `def "#scenarioId: 新側がcommit済みgoldenと宣言どおりの結果になる(#51 AC3/AC7)"`（`where: scenarioId << ["orders-list", "order-detail-own", "order-detail-missing"]`）／新側の前提 assert は `parity/verify/NewScenarioRunner.groovy:428-437`（403 が stale-session/不正 ID 起因であることを検査しないと「ID-14 の観測点が静かに失われる」ため明示 fail させる＝Sprint22 の R8b 是正）<br>**⚠️ 経路の粒度（水増し防止・R1）**: 台帳 ID-14 の as-is「500＋trace 露出は**3経路**」の実体は `spec/behavior/catalog.md:37` に明記されている＝`viewItem`（不正 itemId→`getItem` null→NPE）／`viewCategory`（stale-session→`IllegalStateException`）／`viewProduct`（stale-session→NPE）。**L2 が持つ観測点は `order-detail-missing`（R8b）＝`ViewOrderAction` 経路の1本だけで、この3経路は L2 では1本も観測していない。**<br>**補強(L1)＝3経路すべてを観測しているのは L1 側**: `presentation/rest/CatalogControllerSpec.groovy:154` `def "論点5: 存在しないitemIdは404に正規化される"`（← `viewItem` 経路）・`:135` `def "論点5: 存在しないcategoryIdは404に正規化される(trace非露出)"`（← `viewCategory` 経路）・`:148` `def "論点5: 存在しないproductIdは404に正規化される"`（← `viewProduct` 経路）・`:142` `def "論点5: 存在しないcategoryIdのproducts一覧も404になる(親ID存在チェック)"`・`:202` `def "#3 AC-neg1: stale頁送り相当(範囲外の有効なpage番号)はクランプされ空200を返す(500でない)"`（← stale-session 相当）／`presentation/rest/exception/GlobalExceptionHandlerSpec.groovy:99` `def "想定外の例外は500に正規化されスタックトレース情報を含まない"`・`:134` `def "#3 AC-neg1: NoResourceFoundExceptionは404に正規化される(未知パスへのアクセス)"`・`:55` `def "AccessDeniedExceptionは403に正規化され詳細理由を露出しない"`／`presentation/rest/OrderControllerSpec.groovy:519`（403 かつ trace/内部詳細 非露出）<br>**補強(L3)**: `l3-security-regression-backend.md` §1 の **S18**（`ID-14 / SBD-10`・根拠 `live`: 403/404/422 応答が `code`/`message`/`path`/`timestamp` のみの固定 JSON で trace 無し）<br>**→ 次イテレーション候補**: `item-detail-missing`（不存在 itemId で `viewItem.do`）を L2 に1本足すと、(a) ID-14 の**2本目の L2 観測点**になり、(b) legacy の未踏分岐 `SqlMapItemDao.getItem` の `item == null` 側を踏む。後述「次イテレーションの L2 シナリオ候補」参照。 | 観測点あり<br>（**部分**） | **L2 の観測点は `order-detail-missing`（注文詳細経路）の1本だけ**。台帳が挙げる3経路（`viewItem`/`viewCategory`/`viewProduct`・`spec/behavior/catalog.md:37`）は **L2 では1本も観測していない**（L1 では3経路とも観測済み） |
| **ID-15** | `product.description` の HTML 内包（`escapeXml=false`）→ plaintext 化 | **L3**<br><sub>根拠の所在: `rep` + `fe` + `db`</sub> | `l3-security-regression-frontend.md` §1 の **項目1「XSS（SBD-18 / ID-15）— PASS」**／根拠種別 **`code`+`live`**／**何を観測しているか**: (a) `code`＝`src` 全走査で `v-html`/`innerHTML`/`domPropsInnerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write`/`dangerouslySet` が実コードに **0件**、description は `views/catalog/ItemDetailView.vue:110`・`views/catalog/ItemListView.vue:61` の `{{ }}` テキスト補間のみ。(b) `live`＝§2.1 N-F0 で、DB に永続化された `<img src=x onerror=alert(1)>` を SPA が API 境界の allowlist で canonical 値へ写像し、稼働環境で **`onerror` img 注入 0・シリアライズ DOM に生ペイロード不在・alert 不発**を実測。<br>**補強(L1)**: frontend `src/views/catalog/__tests__/ItemDetailView.spec.ts:59` `it('AC-neg1(SBD-18): descriptionにHTML/scriptタグを与えても生描画されず実行されない(v-html不使用)')`／database `schema/CatalogSeedSpec.groovy:53` `def "AC5(SBD-18/ID-15): m_category.description に HTML タグが含まれない(plaintext)"`・`:61` `def "AC5(SBD-18/ID-15): m_product.description に HTML タグが含まれない(plaintext)"`（＝**データ側が plaintext 化されたことの観測**） | 観測点あり | — |
| **ID-16** | 非空＋PW一致のみ → email 形式・最大長・PW 強度を検証 | **L1**<br><sub>根拠の所在: `be` + `fe`</sub> | PW 強度: `presentation/rest/validation/StrongPasswordValidatorSpec.groovy:18` `def "isValid: 8〜72文字・4種中2種以上を満たす値はtrue(#value)"`・`:32` `def "isValid: null/空文字はfalse"`・`:40` `def "isValid: 8文字未満はfalse(#value.length()文字)"`・`:48` `def "isValid: 73文字(長さ超過)はfalse"`・`:56` `def "isValid: 文字数は72以下でもUTF-8バイト長が72を超える場合はfalse(bcrypt 72バイト上限・暗黙切り詰め防止)"`・`:66` `def "isValid: 文字種が1種類のみはfalse(#value)"`・`:79` `def "isValid: 文字種が2種類あればtrue(#value)"`<br>受理経路（email 形式・最大長）: `presentation/rest/RegistrationControllerSpec.groovy:195` `def "AC-neg1(#17 Q2): 不正なemail形式は400になり、アカウントは作成されない"`・`:214` `def "AC-neg1(#17 Q2): usernameがDBカラム幅(80)を超えると400になる"`・`:230` `def "AC-neg1(#17 Q1): 弱いパスワード(文字種1種のみ)は400になり、アカウントは作成されない"`・`:242` `def "AC-neg1(#17 Q1): パスワードが8文字未満は400になる"`・`:186` `def "必須項目が空だと400になる(AC1・バリデーション)"`／`presentation/rest/PasswordChangeControllerSpec.groovy:156` `def "#17 Q1: 弱い新PW(文字種1種のみ)は400になり、hashは変更されない"`<br>frontend: `src/utils/__tests__/accountValidation.spec.ts:8`（`isValidEmail` 正例3入力の `it.each`）・`:15`（不正 email の `it.each`）・`:30/:40/:44/:48/:52/:59/:66`（`isStrongPassword`）・`:72` `it('backendのDDL(V00_000_004__create_account_tables.sql)実測値と一致する')`（`ACCOUNT_FIELD_MAX_LENGTH`＝**最大長の観測点**） | 観測点あり | — |
| **ID-17** | カート数量 0/負の `itemMap` desync（幽霊行）→ 単一削除に正規化 | **L1**<br><sub>根拠の所在: `be` + `db` + `fe`</sub> | `application/service/CartApplicationServiceSpec.groovy:127` `def "AC2: updateItemは数量0以下でCartRepository#removeItemを呼ぶ(単一削除経路・幽霊行=ID-17を踏襲しない・#29 perf: ensureCart/findByCartIdは各1回)"`／`infrastructure/mybatis/custom/mapper/CartCustomMapperSpec.groovy:112` `def "AC2/ID-17: upsertCartItemQuantityは同一(cart_id,item_id)を重複行にせず絶対値で上書きする(幽霊行を作らない)"`／`presentation/rest/CartControllerSpec.groovy:194` `def "AC2: PUTでquantity=0にすると行削除される(単一削除経路)"`・`:285` `def "#5 AC2: PUTでquantity=0は引き続き行削除になる(確定事項②・0=削除セマンティクスの温存回帰)"`・`:250` `def "#5 AC2: PUT /api/cart/items/{itemId}でquantity=-1は400になり永続化されない(負数の明示拒否)"`・`:104` `def "AC1: 同一アイテムに2回追加すると数量が加算される(legacyの+1挙動を一般化)"`（＝**旧の「再追加で increment」の一般化側**）／database `schema/CartTablesSpec.groovy:32` `def "AC2/ID-17: t_cart_item は cart_id+item_id の複合UNIQUE制約を持つ(幽霊行の構造的排除)"`／frontend `src/stores/__tests__/cart.spec.ts:103` `it('AC2: updateItemはquantity<=0でlocalLinesから行を削除する(orderableチェック不要)')` | 観測点あり | — |
| **ID-18** | 在庫切れでも追加可・上限なし → 追加不可・上限＝在庫数 | **L1**<br><sub>根拠の所在: `be` + `fe`</sub> | `domain/cart/CartSpec.groovy:42` `def "AC5: addItemは在庫切れ(stock=0)アイテムを追加できない"`・`:54` `def "AC-neg1: addItemは既存数量+追加数量が在庫数を超えると拒否する(server強制・qty非露出)"`・`:103` `def "AC-neg1: updateItemは在庫数を超える絶対値を拒否する"`／`presentation/rest/CartControllerSpec.groovy:154` `def "AC5: 在庫切れアイテム(EST-3, stock=0)の追加は400になる"`・`:163` `def "AC-neg1: 在庫数を超える追加は400になる(EST-2, stock=1に2個要求)"`・`:431` `def "D1: orderable EPは在庫切れならorderable=false, reason=OUT_OF_STOCKを返す(EST-3)"`・`:439` `def "D1: orderable EPは数量が在庫を超えるとorderable=false, reason=EXCEEDS_STOCKを返す(EST-2, stock=1に2要求)"`／`application/service/CartApplicationServiceSpec.groovy:141` `def "AC-neg1: updateItemは在庫数を超える絶対値でCartのコマンドメソッドが例外を投げるとupsertItemを呼ばない"`／frontend `src/stores/__tests__/cart.spec.ts:92` `it('AC5: orderable=falseの場合は追加を拒否しlocalLinesを変更しない')`・`:81` `it('既存行への追加は数量を加算してからorderableチェックする(合算数量で検証)')`／`src/views/catalog/__tests__/ItemDetailView.spec.ts:115` `it('#4 AC5: 在庫切れ(OUT_STOCK)の場合、カート追加ボタンは非活性である')`・`:151` `it('#4 AC5/AC-neg1: orderable EPがfalseを返す場合、追加は拒否されエラーメッセージを表示する')` | 観測点あり | — |
| **ID-19** | 未ログインカートをクライアント保持＋ログイン時に加算マージ・在庫クランプ | **L1**<br><sub>根拠の所在: `be` + `fe`</sub> | 加算＋クランプ: `domain/cart/CartSpec.groovy:128` `def "計画②: mergeLineはclientとserverの数量を加算し在庫数でクランプする"`（server 3 + client 2 = **5**・在庫100）・`:141` `def "計画②: mergeLineは合算が在庫数を超える場合は例外にせず在庫数にクランプする"`（client 3・在庫1 → **1**）・`:154` `def "mergeLineは在庫0のアイテムはクランプ結果0となり削除シグナル(Optional.empty)を返す"`・`:166` `def "SBD-2(sec指摘): mergeLineは合算がintをオーバーフローしても例外にせず在庫数へクランプする(非拒否方針を維持)"`／`application/service/CartApplicationServiceSpec.groovy:177` `def "計画②: mergeはclientとserverの数量を加算し在庫数でクランプしてupsertItemへ渡す(#28: findStocksを1回だけ呼び、findStockは呼ばない)"`・`:266` `def "#28: 重複itemIdの合算が在庫を超える場合は在庫数にクランプする(逐次クランプと同値)"`・`:204` `def "mergeは在庫0のアイテムはクランプ結果0となりCartRepository#removeItemを呼ぶ"`／`presentation/rest/CartControllerSpec.groovy:371` `def "計画②: POST /api/cart/mergeはclient行をサーバ側に加算し在庫数でクランプする"`・`:386` `def "計画②: mergeで合算が在庫数を超える場合は拒否せず在庫数にクランプする(EST-2, stock=1)"`<br>クライアント保持側: frontend `src/utils/__tests__/cartStorage.spec.ts`（10ケース・`jps.cart` の round-trip）／`src/stores/__tests__/cart.spec.ts:268` `it('localLinesが非空ならmergeを呼び、成功時のみlocalStorageをクリアする')`・`:281` `it('mergeが失敗した場合はlocalLinesを保持しclearCartを呼ばない(次回リトライ可能)')`・`:294` `it('mergeを2回連続で呼んでも1回目成功後の2回目はmergeを再実行しない(1回だけマージ)')`・`:309` `it('true(未ログイン→ログイン)かつlocalLines非空ならmergeを実行する')`・`:62` `it('初期状態はlocalStorageのloadCart結果をlocalLinesに読み込む')`（＝**離脱しても消えないことの観測**） | 観測点あり | — |
| **ID-20** | 4件/頁・セッション保持ページング → 12件/頁・API パラメータ | **L1**<br><sub>根拠の所在: `be` + `fe`</sub> | `domain/common/PageRequestSpec.groovy:8` `def "page/size省略時は既定値(page=1, size=12)になる"`（`req.size() == 12`＝**12件/頁の観測点**）・`:17` `def "page<1やsize<1は1/既定値にクランプされる(400にしない)"`・`:26` `def "sizeが上限(100)を超えるとcapされる"`・`:34` `def "offset()は1-indexのpageから0-index換算のoffsetを返す"`／`presentation/rest/CatalogControllerSpec.groovy:58` `def "AC2/ID-20: size=2でGET /api/categories/DOGS/productsを叩くと1頁目2件・totalPages=3を返す(1-index)"`（＝**API パラメータでのページングの観測点**＝セッション保持でないこと）／`presentation/rest/OrderControllerSpec.groovy:457` `def "#9 AC1: GET /api/orders?page&sizeでサーバページングできる(3件をsize=2で2頁)"`／`infrastructure/mybatis/custom/mapper/OrderCustomMapperSpec.groovy:121` `def "selectOrdersByUserIdはLIMIT/OFFSETでページングできる(size=2で3頁)"`／frontend `src/utils/__tests__/pagination.spec.ts:14` `it('totalPages=3(size=2でDOGS6商品)でpage=1なら[1,2,3]・hasPrevious=false・hasNext=true')` ほか計7ケース | 観測点あり | — |
| **ID-21** | `courier=UPS`/`locale=CA` の保持 → 撤去（プレースホルダ） | **L1**<br><sub>根拠の所在: `db`</sub> | database `schema/OrderInventoryTablesSpec.groovy:51` `def "ID-21: t_order に courier/locale 列は存在しない"`（`columnNamesOf("t_order")*.toLowerCase()` に `courier`・`locale` が含まれないことを `information_schema` 実測で assert）<br>`jpetstore-backend` / `jpetstore-frontend` に ID-21 の観測点は**無い**（backend テスト資源にあるのは `src/test/resources/flyway/sql/V00_000_005__create_order_tables.sql:12` の**SQLコメント**のみ） | 観測点あり | — |
| **ID-22** | `status="P"` 固定1行（orderstatus 異形）→ 固定プレースホルダ＋状態変更を監査ログへ | **L1**<br><sub>根拠の所在: `db` + `be`</sub> | 撤去側: database `schema/OrderInventoryTablesSpec.groovy:60` `def "ID-22: orderstatus テーブルは存在しない（状態変更はaudit_logに記録）"`（`!tableExists("orderstatus")`）・`:17` `def "t_order.user_id は m_account を参照し、status_code(placeholder)を持つ"`（＝**固定プレースホルダ列の観測**）／`schema/AuditLogTableSpec.groovy:14` `def "認可失敗・状態変更を「誰が/何を/結果」で記録できる列が揃っている"`<br>監査記録側（成功/失敗の両方を `ORDER_CREATE` で記録）: `presentation/rest/OrderControllerSpec.groovy:357` `def "AC6: 成功時はresult=SUCCESSのORDER_CREATE監査行が残る"`・`:378` `def "AC6(計画フェーズ確定③): 在庫不足失敗時もresult=FAILUREのORDER_CREATE監査行が残る(主txロールバックに巻き込まれない)"`・`:398` `def "AC6: 空カート失敗時もresult=FAILUREのORDER_CREATE監査行が残る"`／`infrastructure/audit/AuditLogRecorderSpec.groovy:106` `def "recordStateChangeIndependentlyは呼び出し元のトランザクションがロールバックしても記録が残る(REQUIRES_NEW・#8失敗監査)"`<br>**L3 由来の回帰 spec（＝L3 findings の自動化）**: `presentation/rest/OrderFailureAuditL3RegressionSpec.groovy:96` `def "L3 N3 AC-neg3: 在庫不足以外の想定外の失敗でもORDER_CREATE/FAILURE監査行が1件残る(修正前は監査ゼロのまま伝播していた)"`。これは `l3-security-regression-backend.md` **§2.1 の N3**（`backend:audit:order-create-failure-unrecorded`・Medium・**CONFIRMED(code+live)**・「**ID-22『成功・失敗いずれも記録』に反する**」）を Sprint 20 #40 で修正し、回帰テスト化したもの（`l3-security-regression-sprint20-delta.md` §1 の spec 表にも記載）。<br>**⚠️ 残余（観測点があること ≠ 完全に守られていること）**: `l3-security-regression-sprint20-delta.md` の **S20-4**（`backend:audit:best-effort-insert-flips-success-audit-fail-open`）が「#39 AC2 の best-effort catch が private 共通経路 `insert` に置かれたため**成功系 `recordStateChange` にも波及し fail-closed → fail-open に反転**した＝**ID-22 の無言の後退**」を **Low で受容**している（`AuditLogRecorder.java:161-173`。Low 止まりの根拠＝現行 HEAD に攻撃者制御の INSERT 失敗トリガが残っていない）。**ID-22 は「観測点あり＋受容済みの残余あり」型。** | 観測点あり<br>（**部分**） | **S20-4 が「ID-22 の無言の後退」（成功系監査の fail-open 化・`AuditLogRecorder.java:161-173`）を Low で受容**＝観測点はあるが**完全には守られていない**。#47 に起票済み |
| **ID-23** | orderId 採番 select→+1→update → DB 原子採番 | **L1**<br>（**部分観測**）<br><sub>根拠の所在: `db` + `rep` + `be`</sub> | database `schema/OrderInventoryTablesSpec.groovy:65` `def "ID-23: sequence テーブルは存在しない（AUTO_INCREMENTに置換）"`（`!tableExists("sequence")`＝**旧の非アトミック採番機構が消えたことの観測**）<br>**補強(L3)**: `l3-security-regression-backend.md` **§2.3「堅牢と確認した領域」**（126行目末尾）／根拠種別 **`code`**／観測内容: 「**orderId 原子採番（AUTO_INCREMENT）**」を SEC がコードで確認している（ただし1文の記述で、`t_order` の DDL を名指ししてはいない）。<br>**⚠️ 観測できていない部分**: **「`t_order.order_id` が AUTO_INCREMENT である」ことを直接 assert している自動テストが存在しない**（`information_schema` の `EXTRA='auto_increment'` を検査しているのは `schema/AccountTablesSpec.groovy:16` `def "m_account.user_id は AUTO_INCREMENT の代理キーで username は一意である"` **のみ**。`grep -rn "AUTO_INCREMENT\ | 観測点あり<br>（**部分**） | `t_order.order_id` の **AUTO_INCREMENT を assert する自動テストが無い**（`EXTRA='auto_increment'` を検査しているのは `m_account.user_id` のみ）。採番の**原子性・一意性**を並行実行で見るテストも無い |
| **ID-24** | 注文詳細（履歴経由）の明細で商品名が空 → 商品名を表示 | **L2**<br><sub>根拠の所在: `be`</sub> | シナリオ `order-detail-own`／`ParityScenarios.groovy:58-59` の宣言＝`new Scenario("order-detail-own", "INTENDED_DIVERGENCE(ID-24)", ["lines[EST-1].productName"])`／golden `order-detail-own.json`（`divergenceId:"ID-24"`・旧 snapshot の `lines[0]` が `{"itemId":"EST-1","quantity":2,"unitPrice":"16.50","productName":""}`＝**旧の商品名が空である実測が固定されている**・`preconditions:{"1002":{"orderExists":true,"legacyProductNameBlank":"true"}}`）／実行は `parity/OrderHistoryParitySpec.groovy:54`／旧側の前提 assert は `parity/capture/LegacyScenarioRunner.groovy:509-510`（`ViewOrder.jsp` の description セルが空でなければ「台帳の INTENDED_DIVERGENCE(ID-24) 宣言が実測と食い違う」として fail）<br>**補強(L1)**: `infrastructure/mybatis/custom/mapper/OrderCustomMapperSpec.groovy:153` `def "selectOrderLinesByOrderIdはJOINでproduct_nameを補完しline_num順に返す"`（`lines[0].productName == "Angelfish"`）／`presentation/rest/OrderControllerSpec.groovy:491` `def "#10 AC1/AC2/AC4/AC5: own注文詳細は200で明細(商品名/単価×数量)・合計・注文日を返す"`／`parity/canonical/ParitySnapshotSpec.groovy:123` `def "Lineのproductnameは正規化で保持される(Q6・ID-24の観測点)"` | 観測点あり | — |
| **ID-25** | 秘密のソース平文・HTTP 平文・Cookie フラグ欠落 → シークレットストア・TLS 前提・Cookie 属性・JWT 鍵 3段 fail-fast | **L3**<br><sub>根拠の所在: `rep` + `be` + `fe`</sub> | `l3-security-regression-backend.md` §1 の **S17**（根拠 `code`+`live`: `JwtProperties.java:25-41`・`application.yml` の `${JWT_SECRET}`/`${DB_*}` に**デフォルト値が無い**こと／ソースに平文 admin PW **0件**）・**S19**（根拠 `live`: ログイン `Set-Cookie` に `Secure; HttpOnly; SameSite=Strict` を実測。`code`: `AuthCookieSupport.java:64-74`）。<br>**補強(L1)**: `infrastructure/security/AuthCookieSupportSpec.groovy:13` `def "writeAccessTokenCookieはHttpOnly/Secure/SameSite/Path付きでSet-Cookieヘッダを書く"`・`:30` `def "writeRefreshTokenCookieも同様に書く"`・`:43` `def "clearAuthCookiesは両Cookieを即時失効させる(Max-Age=0)"`／`config/SecurityConfigCsrfTokenRepositorySpec.groovy:27` `def "既定値(secure=true, same-site=Strict)でXSRF-TOKEN CookieにSecure+SameSite=Strictを付与しhttpOnlyはfalseのまま"`／`infrastructure/security/JwtSecretPolicySpec.groovy:48` `def "denylist値「#secret」は例外を投げる"`・`:78` `def ".env.example配布値(56byte)はdenylistで拒否される(L3 N1根因)"`・`:86` `def "32byte未満(denylist非該当)は鍵長不足の例外を投げる"`・`:96` `def "32byte以上でもユニーク文字数24未満なら例外を投げる(補助エントロピー検証)"`・`:106` `def "32byte以上かつユニーク文字数24以上なら例外を投げない"`・`:124` `def "例外メッセージに秘密の値そのものを含めない(AC3)"`（＝**denylist→最小鍵長→ユニーク文字数 の3段の観測点**）／`config/ApplicationBootFailFastSpec.groovy:17` `def "環境変数が一切未設定だと実アプリの起動に失敗する"`・`:39` `def "JWT_SECRETのみ設定してもDB_USERNAME/DB_PASSWORD未設定なら起動に失敗する"`／frontend `src/stores/__tests__/auth.spec.ts:177` `it('signon成功時にlocalStorageへ書き込まれるのはpreferencesキーのみで、トークン等は一切書き込まれない(AC5・トークン非JS保持)')`<br>**L3 由来の回帰 spec（＝L3 findings の自動化）**: `presentation/rest/JwtForgedTokenL3RegressionSpec.groovy:56` `def "L3 N1: .env.exampleの公開鍵で署名した偽造access tokenはGET /api/auth/meで401になる(資格情報なしのなりすまし阻止)"`・`:65` `def "L3 N1: .env.exampleの公開鍵で署名したroles=[ADMIN]偽造tokenはADMIN限定エンドポイントで401になる(垂直昇格阻止)"`。これは §2.1 の **N1**（`backend:secrets:jwt-signing-key-is-public-placeholder`・**Critical**・CONFIRMED(live)）を Sprint 20 #38 で修正し回帰テスト化したもの＝**台帳 ID-25 の「denylist に既知 placeholder を恒久収録」の直接の観測点**。<br>**⚠️ 残余**: `l3-security-regression-sprint20-delta.md` の Informational に「`.env.example` のコメントが旧ガイダンス（最小32byteのみ）のまま」（`backend:secrets:env-example-stale-guidance`）があるが、同レポートが「placeholder 値の残置自体は ID-25 で意図された仕様」と整理している。 | 観測点あり | — |
| **ID-26** | EOL/脆弱依存・版レンジ未固定 → 保守された現行版・版固定 | **L3**<br><sub>根拠の所在: `rep`</sub> | `l3-security-regression-backend.md` §1 の **S20**（根拠 `code`: `build.gradle:32-86` を読み Spring Boot 4.1.0 / Java 21 / MyBatis 4.1.0 / jjwt 0.12.6 / mysql-connector-j 9.5.0 であり **Struts/Axis/Hessian/hsqldb/xalan が不在**であることを確認）・**S21**（根拠 `code`: Spring Boot BOM ＋ exact-version 固定でレンジ指定なし）。frontend は `l3-security-regression-frontend.md` §1 の **項目4「依存 CVE（SBD-12）— PASS（残件1）」**／根拠 **`live`**＝`npm audit` の実出力 `{"info":0,"low":0,"moderate":0,"high":0,"critical":0,"total":0}`、および `package-lock.json` による正確版ロックの確認。<br>**⚠️ 観測範囲の欠落**: 台帳 ID-26 が名指ししている **`jpetstore-database` の `mysql-connector-j` `8.0.33→26.7.0` 更新を観測しているレポート行は無い**（S20 が読んでいるのは backend の `build.gradle`。`jpetstore-database/build.gradle` に対する L3 判定行は3レポートに存在しない）。 | 観測点あり<br>（**部分**） | 台帳が名指しする **`jpetstore-database` の `mysql-connector-j` 8.0.33→26.7.0 を観測している行が無い**（S20 が読むのは backend の `build.gradle`）。版乖離（9.5.0 / 26.7.0）の据え置き理由も未記録 |
| **ID-27** | english/japanese の JSP 同梱 → i18n 基盤＋日本語ローカライズ（#25 で完了） | **L1**<br><sub>根拠の所在: `fe` + `be`</sub> | frontend `src/i18n/__tests__/index.spec.ts:17` `it('ja.tsはen.tsと完全に同じキー集合を持つ(未翻訳キーを残さない・shapeドリフトを検知する)')`（＝**`ja.ts` 全キー翻訳の観測点**）・`:30` `it('既定ロケールがenであり、domain.context.key構造のキーを解決できる')`・`:44` `it('#25 AC1/AC2: localeをjaへ切り替えるとキーが日本語で解決される')`・`:53` `it('#25 AC5: jaにキーが存在しない場合はfallbackLocale(en)の値を返す(英語フォールバック)')`・`:62` `it('#25 AC3: datetimeFormats.shortがen/ja両方に定義されており、日付を整形できる(#9/#10の日付表示で使用)')`（＝**日付フォーマットの観測点**）・`:84/:92/:98`（localStorage からの初期 locale seed）／`src/components/__tests__/AppHeader.spec.ts:164` `it('未ログインでも言語ドロップダウンのトリガーを表示する(未ログインでも表示・操作可)')`・`:177` `it('日本語を選択するとi18nのlocaleがjaへ切り替わり、ヘッダー自体も日本語表示になる')`（＝**ヘッダー言語切替UIの観測点**）／`src/utils/__tests__/preferencesMapping.spec.ts:5/9/13/20/24`（`japanese`↔`ja`・`english`↔`en` の DB 値写像）／`src/stores/__tests__/preferences.spec.ts:86` `it('jaを選択するとi18nのlocaleが切り替わり、localStorageへ保存される')`・`:98` `it('DB値(pass-throughのcolorScheme・english/japaneseのlanguage)を適用しlocalStorageへseedする')`（＝**DB権威〔`m_profile.language_preference`〕での跨デバイス追従の観測点**）／backend `presentation/rest/AuthLoginLogoutSpec.groovy:114` `def "AC6(#36)/AC7(#25): m_profileにDB保存済みのテーマ/言語設定があればログイン応答へそのまま含まれる(A2・login()実行中のcurrentUserProvider不使用)"` | 観測点あり | — |
| **ID-28** | 在庫状況表示なし → 3段階バッジ表示・qty 自体は非露出 | **L1**<br><sub>根拠の所在: `be` + `fe` + `db`</sub> | 3段階の算出（閾値）: `domain/catalog/StockStatusCalculatorSpec.groovy:13` `def "of(#quantity) は #expected を返す(N=5)"`（`-1`・`0`→`OUT_OF_STOCK` ／ `1`・`3`・`5`→`LOW_STOCK` ／ `6`・`100`→`IN_STOCK` ＝ **`0<qty≤5` が残少という閾値の観測点**）・`:28` `def "LOW_STOCK_THRESHOLDはマジックナンバーではなく定数として公開されている(N=5)"`<br>qty 非露出: `presentation/rest/CatalogControllerSpec.groovy:113` `def "AC3: GET /api/items/{id}は在庫status(OUT_STOCK)を返しqty/quantityフィールドを含まない"`／`presentation/rest/CartControllerSpec.groovy:395` `def "ID-28: レスポンスJSONに在庫数そのもの(stockQuantity)フィールドは含まれない"`・`:453` `def "D1/ID-28: orderable EPのレスポンスに在庫数そのものは含まれない"`／`domain/cart/CartItemSpec.groovy:33` `def "stockStatusは内部保持したstockQuantityから算出する(在庫qty自体は非露出)"`<br>バッジ表示: frontend `src/utils/__tests__/stockBadge.spec.ts:7` `it('IN_STOCKはbadge-jps-stock-inとcatalog.stockStatus.inStockに写像される')`・`:13`（`LOW_STOCK`）・`:19`（`OUT_STOCK`）・`:25`（未知値のフォールバック）／`src/views/catalog/__tests__/ItemDetailView.spec.ts:42` `it('AC1: 商品名・価格・在庫バッジを表示する')`<br>データ側: database `schema/StockStatusCodeSpec.groovy:12` `def "m_code に code_type=0003(StockStatus)が3件登録されている"`・`:27` `def "m_code(0003)の表示名(日英)が在庫あり/残少/在庫切れに対応している"`／`schema/CatalogSeedSpec.groovy:69` `def "AC3: t_inventory が28件投入され在庫3状態(在庫あり/残少/在庫切れ)が作り分けられている(N=5)"`（＝**旧の「全アイテム qty=10000 固定」が消えたことの観測**） | 観測点あり | — |
| **ID-29** | 検索語の `%`/`_` がワイルドカード → リテラル一致（ESCAPE 併用） | **L2**<br><sub>根拠の所在: `be` + `rep`</sub> | シナリオ `search-wildcard`／`ParityScenarios.groovy:45` の宣言＝`new Scenario("search-wildcard", "INTENDED_DIVERGENCE(ID-29)", ["entries"])`／golden `search-wildcard.json`（`divergenceId:"ID-29"`・旧 snapshot の `entries` に `query:"%"` と `query:"_"` それぞれで `AV-CB-01`・`AV-SB-02`・`FI-FW-01`… と**全商品がマッチした実測**が並ぶ＝旧のワイルドカード挙動そのもの）／実行は `parity/CatalogParitySpec.groovy:33` `def "#scenarioId: 新側がcommit済みgoldenと宣言どおりの結果になる(#49 AC1〜AC3/AC7)"`（`where` に `search-wildcard` を含む・クラス javadoc 19行目に「R6（`search-wildcard`）はID-29の`INTENDED_DIVERGENCE`」と明記）<br>**補強(L1)**: `domain/catalog/ProductSearchTermsSpec.groovy:33` `def "ID-29: LIKEメタ文字%/_/\\はバックスラッシュでエスケープされリテラル化される"`（`"100%"`→`"%100\\%%"`／`"a_b"`→`"%a\\_b%"`／`"a\\b"`→`"%a\\\\b%"`）／`infrastructure/mybatis/custom/mapper/CatalogCustomMapperSpec.groovy:113` `def "ID-29: LIKEメタ文字はエスケープ済みならリテラル一致し、seedにアンダースコアを含む語が無いため0件になる"`（＝**ESCAPE 併用が実 SQL で効いていることの観測**）／`presentation/rest/CatalogControllerSpec.groovy:275` `def "#2 ID-29: LIKEメタ文字'_'はエスケープされリテラル一致するため0件になる(意図せぬ全件マッチ防止)"`<br>**補強(L3)**: `l3-security-regression-backend.md` **§2.3「堅牢と確認した領域」の「SQLi/動的SQL（SBD-17 維持）」**（124行目）／根拠種別 **`live`**／観測内容: 稼働 backend の商品検索に `%`・`_`・`' OR '1'='1`・`; DROP TABLE m_product;--` を投入し、**いずれも注入不成立（0件へ正規化）・`m_product` は 16 行のまま無傷**を実測（§1 付録 (f) と対）。**§1 の S1〜S21 回帰表には ID-29 の行は無い**（SBD-17 は「維持項目」で before findings の S 番号を持たないため） | 観測点あり | — |
| **ID-30** | 下書きを HTTP セッションの `workingOrderForm` に保持 → Pinia（メモリのみ）・リロードで消失 | **なし**<br><sub>根拠の所在: なし</sub> | **観測点は見つからなかった。**<br>最も近い候補は frontend `src/stores/__tests__/checkout.spec.ts:182` `it('入力済みの下書き・ステップ・別配送フラグを初期状態へ戻す')` だが、これは `reset()` を**明示的に呼んだ**ときの挙動の観測であり、「**永続化していない＝ブラウザリロードで消える**」という ID-30 の主張は観測していない。`checkout.spec.ts` 全16ケースに `localStorage`/`sessionStorage` への言及は **0件**（`grep -n "localStorage\ | **穴** | —（穴。§4.1 参照） |
| **ID-31** | テーマ/配色の切替機能なし → ライト/ダーク/システム連動の切替UI・DB権威で追従 | **L1**<br><sub>根拠の所在: `fe` + `db` + `be`</sub> | UI（ヘッダー・即時切替）: frontend `src/components/__tests__/AppHeader.spec.ts:69` `it('未ログインでもテーマドロップダウンのトリガーを表示する(AC1・未ログインでも表示・操作可)')`・`:77` `it('既定値はSystemとして表示される(AC3)')`・`:83` `it('トリガーをクリックするとLight/Dark/Systemの3択が開く(AC1)')`・`:94` `it('Darkを選択すると即座に全画面へ反映され(<html>にdarkクラス付与)、ドロップダウンは閉じる(AC1)')`・`:109` `it('Systemを選択すると<html>からdark/lightクラスが除去される(AC2・OS追従)')`<br>store/localStorage: `src/stores/__tests__/preferences.spec.ts:53` `it('darkを選択すると<html>にdarkクラスが付き、localStorageへ保存される')`・`:64` `it('lightを選択すると<html>にlightクラスが付く')`・`:73` `it('systemを選択すると<html>からdark/lightクラスが両方除去される(AC2・OS追従)')`・`:98` `it('DB値(pass-throughのcolorScheme・english/japaneseのlanguage)を適用しlocalStorageへseedする')`（＝**DB権威での跨デバイス追従の観測点**）・`:111` `it('AC-neg1: DBに不正な値が入っていてもSystem/enへフォールバックし例外を投げない')`／`src/utils/__tests__/preferencesStorage.spec.ts:20` `it('saveColorScheme→loadColorSchemeでラウンドトリップできる(AC4)')`・`:28` `it('不正な値が保存されている場合、loadColorSchemeはSystemにフォールバックする(AC-neg1)')`<br>DB 永続化列: database `schema/ColorSchemePreferenceSpec.groovy:11` `def "AC8: m_profile.color_scheme_preference が VARCHAR(20) NOT NULL で追加されている"`・`:22` `def "AC8: color_scheme_preference の既定値は system である"`／backend `presentation/rest/AuthLoginLogoutSpec.groovy:114`（ログイン応答へ DB 値がそのまま載る） | 観測点あり | **旧に比較対象概念が存在しない**（台帳自身が「legacy に比較対象概念自体が無い」と宣言）。観測しているのは**新側の AC のみ**で、L2 化は構造的に不能 |
| **ID-32** | 認証状態の保持方式: サーバサイド HTTP セッション → 完全ステートレス（JWT httpOnly Cookie）<br>（**L4 で新規に台帳追記**） | **L3**<br><sub>根拠の所在: `rep`</sub> | `l3-security-regression-backend.md` §1 の **S8**／根拠種別 **`live`**／**何を観測しているか**: ログイン応答の `Set-Cookie` が `ACCESS_TOKEN`/`REFRESH_TOKEN` のみで **`JSESSIONID` を一切発行しない**ことを実測（＝サーバサイドセッションが張られていないことの直接観測）。あわせて **S3**／根拠 **`code`**＝`SecurityConfig.java:87`（DEV も現物確認: `.sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))`）。frontend 側は `l3-security-regression-frontend.md` §1 の **項目2「トークン保管（SBD-15）」**／根拠 `live`＝ログイン後の `document.cookie` が空・`localStorage`/`sessionStorage` に JWT 無し・JS が保持するのは `user{username,roles}` のみ（メモリ）を実測。<br>旧側: `legacy-jpetstore/src/main/java/.../web/struts/SignonAction.java` の `request.getSession().setAttribute("accountForm", acctForm)`／`request.getSession().invalidate()`（DEV 現物確認）。<br>**⚠️ 帰属の注意**: §1 の S8 行の ID 列は `ID-10 / SBD-4`、S3 行は `ID-4 / SBD-1`。**ID-32 は L4 で新設された台帳項目なので、それを名指しで判定している L3 行は存在しない**（レポート執筆時点で台帳に無かった）。<br>**⚠️ 観測できていない部分（L1 の穴）**: **`SessionCreationPolicy.STATELESS` / `JSESSIONID` 不発行 を assert している自動テストは 0件**（`grep -rn "JSESSIONID\ | 観測点あり<br>（**部分**） | **`SessionCreationPolicy.STATELESS` を assert する自動テストが 0件**（test 配下のヒットは parity の `LegacyHttpClient.groovy` のみ）＝**設定を戻しても赤くならない**。観測は L3 の `live` 実測と `code` 参照のみで、**退行検知器になっていない** |
| **ID-33** | カート一覧のページング廃止（旧 4件/頁・セッション保持 → 新 全件表示）<br>（**L4 で新規に台帳追記**） | **なし**<br><sub>根拠の所在: なし</sub> | **観測点は見つからなかった（穴）。**<br>実測（すべて DEV が現物で確認）:<br>・backend `src/main/java/.../presentation/rest/CartController.java` に `page`/`size`/`Page` の出現 **0件**（＝API にページングパラメータが無いのは事実）。<br>・`presentation/rest/CartControllerSpec.groovy` に `page`/`Page` の出現 **0件** ＝ **「ページングされない／全件返る」ことを assert しているテストは存在しない**。同 spec の最大ケースは 2 行（`:222` `def "[L2]: 小計はΣ(listPrice×quantity)のサーバ計算になる(EST-1×2+EST-22×1=16.50*2+135.50*1=168.50)"`）で、**旧の閾値 4 件を超える行数を1レスポンスで返す観測をしているケースが無い**。<br>・frontend `src/views/CartView.vue` に `Pagination`/`page`/`buildPageWindow` の出現 **0件**、`src/stores/__tests__/cart.spec.ts` にも `page`/`Pagination` の出現 **0件**。<br>・L2 の `cart-boundary` シナリオ（golden `cart-boundary.json`）は境界値の検証であって、カート行数と表示件数の関係は canonical に含まれない。<br>旧側の根拠: `legacy-jpetstore/src/main/java/.../domain/Cart.java:21-23` の `public Cart() { this.itemList.setPageSize(4); }`（DEV 現物確認。`PagedListHolder` をセッション上の `Cart` が保持）。<br>**→ 「誰も台帳に載せていなかった＝誰も観測点を作っていない」という因果がそのまま出た形。**5件以上のカート行が1レスポンスで返ることを assert するテストを足すのが最小の埋め方（後述「次イテレーションの L2/L1 シナリオ候補」）。 | **穴** | —（穴。§4.1 参照） |

---

## 3. 合否ゲート判定（`verification-strategy.md` §5）

| ゲート | 判定基準 | 結果 |
| --- | --- | --- |
| **L1** | 全 AC テストが green | **PASS** |
| **L2** | 保存ロジックの特性化テストが旧同値（台帳の意図差分を除く）＋ BRANCH 28/34 非退行 | **PASS** |
| **L3** | before の PoC が**すべて** after で失敗 | **PASS** |
| **L4** | 実測された差分が**すべて**台帳に載っている | **是正後 PASS**（下記 3.4） |

**PASS が何を意味しないか**は §6 に書いた。**4本 PASS ＝「何も変わっていない」ではない。**

### 3.1 L1 — PASS

`--rerun-tasks` を付けて強制再実行した結果（DEV 実測。`:test` と `:parityTest` が最初 `UP-TO-DATE` でスキップされたため）。

| 対象 | タスク | tests | failures | errors | skipped |
| --- | --- | --- | --- | --- | --- |
| `jpetstore-backend` | `test`（UT） | **362** | 0 | 0 | 0 |
| `jpetstore-backend` | `integrationTest`（Testcontainers MySQL） | **225** | 0 | 0 | 0 |
| `jpetstore-backend` | `parityTest`（＝L2） | **23** | 0 | 0 | 0 |
| `jpetstore-frontend` | `npm run test`（`vitest run`・26 files） | **267** | 0 | 0 | 0 |
| `jpetstore-database` | `test`（schema Spec） | **97** | 0 | 0 | 0 |
| **合計** | | **951** | **0** | **0** | **0** |

- `./gradlew test integrationTest parityTest --rerun-tasks` → `BUILD SUCCESSFUL in 3m 57s / 8 actionable tasks: 8 executed`
- `integrationTest` の 225 は `l3-security-regression-sprint20-delta.md` §1 の記録と一致した。
- **注記**: Issue #52 AC4 が指定した `npm run test:unit` は `package.json` に**存在しない**（実体は `"test": "vitest run"`）。DEV が `npm run test` で実行した。

### 3.2 L2 — PASS

- **`parityTest` = 23 テスト・0 failure。** うち golden 比較を行う 5 Spec の合計は **19**（`AccountParitySpec` 6・`OrderHistoryParitySpec` 3・`CartParitySpec` 1・`OrderParitySpec` 3・`CatalogParitySpec` 6）＝ `l2-parity-coverage.md` §S9 の「計19件」と実測一致。
- **ゲート値（非退行フロア）**: `tools/legacy-jacoco/out3/report/gate-v2/jacoco.csv` の全17行を **DEV と SM が別々に合算**して、いずれも **BRANCH 28/34 = 82.4%**・**INSTRUCTION 1360/1424 = 95.5%** を得た（レポート記述の転記ではない）。
- 残存未踏 BRANCH 6 の内訳も両者一致: `SqlMapItemDao` 3・`SqlMapSequenceDao` 1・`CartItem` 1・`Cart` 1（28 + 6 = 34）。
- **ゲート値は据え置いた**（#52 AC-neg1）。理由は「上限に達したから上げようがない」ではなく、**非退行フロア＝シナリオを壊したら気づくための検知器**として機能させるため。

> ⚠️ **「残り6分岐はすべて構造的に到達不能」は言い過ぎである。** SM が `out3/report/gate-v2/jacoco.xml` をメソッド粒度でパースし `legacy-jpetstore` の実ソースを読んで分類したところ、**4種類**に分かれた：
>
> | 分岐 | 性質 |
> | --- | --- |
> | `Cart.addItem` の `cartItem != null` 側 | 構造的に到達不能（呼び出し元2箇所とも `containsItemId` で事前排他） |
> | `CartItem.getTotalPrice` の `item != null` false 側 | 構造的に到達不能（唯一の生成箇所 `Cart.java:38` の直後が必ず `setItem(非null)`） |
> | `SqlMapSequenceDao.getNextId` の `sequence == null` 側 | **seed 前提で到達不能**（`SEQUENCE` 表を壊さないと踏めない＝レガシー無改変の原則により不能） |
> | `SqlMapItemDao.getItem` の `item == null` 側 | **到達可能（スコープ外）** — 不存在 itemId で `viewItem.do` |
> | `SqlMapItemDao.isItemInStock` の未踏2アウトカム | **到達可能（スコープ外）** — `i == null`（不存在 itemId）／`i <= 0`（在庫0への `addItemToCart.do`） |
>
> 正確な言い方は「**28/34 は現行シナリオ集合のスコープ内での上限**」であって「理論上限」ではない。
> これはゲート値を上げる根拠ではなく、**言い過ぎを直すという一点**で記録する（§4.2 で次の一手に繋がる）。

### 3.3 L3 — PASS

- `l3-security-regression-backend.md` §1 の回帰表を **DEV と SM が別々に1行ずつ数えて、いずれも S1〜S21 の 21 行**（欠番・重複なし）。
- 判定の内訳: **消滅/設計変更 9・是正 12**（S15 は消滅側と是正側の両方）。**「未対応（脆弱性が残っている）」「不明」は 0 行。**
- → **before の PoC は 21/21 すべて after で失敗する**＝ゲート充足。

> **L3 ゲートの分母は before の findings（S1〜S21）である。after 側の残件はゲート基準の外にある**ので分けて書く：
> `l3-security-regression-sprint20-delta.md` は「残存脆弱性 0」とは言っていない。**Low 4件が残り**、同レポート自身が「完全な clean とは書けない」と明記している。これらは `#42`〜`#47` として起票済みで、**本ゲートの合否には影響しないが、after が clean であることの主張には影響する**。

> **【drift 注記】** `l3-security-regression-backend.md` の全体結論にある「うち **10件**をライブ実測で確証」は数え方が曖昧である。DEV と SM が別々に §1 表の根拠列を機械パースしたところ、**`live` を含む行は 17**（`live` のみ 7 ＋ `live`+`code` 併記 10）、**`code` のみは 4**（S2・S4・S20・S21）。「10」は**併記行の数**と一致する。ゲート判定（未対応 0 件）には影響しない。

### 3.4 L4 — 是正後 PASS

L4 の判定基準は「**実測された差分がすべて台帳に載っている**」（台帳に無い差分＝要調査）。

| 時点 | 状態 |
| --- | --- |
| **L4 実施前** | **FAIL** — 台帳に載っていない差分が **2件**存在した（認証保持方式・カート一覧のページング廃止。§5.2） |
| **L4 実施後** | **PASS** — 2件を **ID-32 / ID-33** として台帳へ追記し解消（ユーザー承認 2026-08-21） |

**この PASS は「最初から台帳が完全だった」ことを意味しない。L4 が2件見つけて直した結果である。**
そして **L4 の探索が網羅的である保証は無い**（§6-1）。

保留中の候補が **1件**ある：

| 候補 | 状態 |
| --- | --- |
| **注文の二重送信**（冪等キー無しで同一カートの並行 POST が注文2件を生む。`l3-security-regression-backend.md` §3-6 が「台帳に記載が無い」と明記） | **条件付き保留**。PO 判定＝旧 `PetStoreImpl.java:147-150` の `insertOrder` にも冪等制御・一意制約は無く、旧は注文確定が GET リンク（ID-9）＋在庫ガード無し（ID-1）なので**二重送信はより起きやすく被害も大きい**＝**新のほうが厳しい**ため旧新差分ではない公算。**実測で「旧は二重送信で1件しか作らない」等の反証が出たら台帳行へ切り替える** |


---

## 4. 穴と、次の一手

### 4.1 穴（観測点が無く、作るべきもの）— 2件

**埋めていない。埋めるのは次イテレーションである**（#52 AC-neg2 ＝起票までがスコープ）。

| ID | 何が観測されていないか | 最も近い候補と、それを採らなかった理由 |
| --- | --- | --- |
| **ID-30** | 「チェックアウトの下書きが**ブラウザリロードで消える**」こと。`checkout.spec.ts` の全16ケースに `localStorage`/`sessionStorage` の言及が **0件** | `checkout.spec.ts:182` `it('入力済みの下書き・ステップ・別配送フラグを初期状態へ戻す')` は `reset()` を**明示的に呼んだ**ときの挙動であって、リロードによる揮発ではない。L3 frontend §1-2 の「`localStorage.setItem` は2用途のみ」という全数確認は **JWT 非保持（SBD-15）を見ているのであって ID-30 を名指ししていない**。目的が違うものを観測点に数えると水増しになるため採らなかった |
| **ID-33** | 「カート一覧が**全件表示**である（ページングが無い）」こと | `CartController.java` / `CartControllerSpec.groovy` / `CartView.vue` / `cart.spec.ts` の**すべてで `page`/`Pagination` の出現が 0件**。`CartControllerSpec` の最大ケースは **2行**（`:222`）で、**旧の閾値である4件を超える行数が1レスポンスで返ることを観測しているケースが無い**。ページングを再導入しても赤くならない |

> **ID-33 が穴なのは偶然ではない。** ID-33 は L4 が今回はじめて台帳に載せた差分である。**台帳に載っていなかったものに観測点が作られているはずがない**——「台帳に載せる」と「観測点を作る」が同じ駆動から出ている以上、これは自然な因果である。**逆に言えば、台帳の抜けは観測点の抜けとして必ず現れる。**

### 4.2 部分観測（観測点はあるが、見ている範囲が宣言より狭い）— 6件

| ID | 観測できていない部分 |
| --- | --- |
| **ID-6** | 「新＝SPA+REST」の**肯定側**を固定する観測点が無い（観測しているのは旧 SSR 面の消滅だけ） |
| **ID-14** | **L2 の観測点は `order-detail-missing` の1本だけ**。台帳が挙げる3経路（`viewItem`/`viewCategory`/`viewProduct`）は L2 で1本も観測していない（L1 では3経路とも観測済み） |
| **ID-22** | S20-4 が「ID-22 の無言の後退」（成功系監査の fail-open 化）を Low で受容＝**観測点はあるが完全には守られていない**（#47 に起票済み） |
| **ID-23** | `t_order.order_id` の **AUTO_INCREMENT を assert する自動テストが無い**（検査しているのは `m_account.user_id` のみ）。採番の原子性を並行実行で見るテストも無い |
| **ID-26** | 台帳が名指しする `jpetstore-database` の `mysql-connector-j` 更新を観測している行が無い（S20 が読むのは backend の `build.gradle`） |
| **ID-32** | **`SessionCreationPolicy.STATELESS` を assert する自動テストが 0件**＝設定を戻しても赤くならない。観測は L3 の `live` 実測のみで**退行検知器になっていない** |

### 4.3 L2 の次の一手を、L4 の結果から導出する

Sprint 22 Retro C2（「観測点の質へ軸を移す」）の実行結果として、**次の L2 シナリオはカバレッジからではなく台帳から導かれた**。

**最も価値が高い1本は `item-detail-missing`（不存在 itemId で `viewItem.do`）である。** 理由は、これが**2つの穴を同時に塞ぐ**から：

| 塞がる穴 | 内容 |
| --- | --- |
| **L4 側** | **ID-14 の2本目の L2 観測点**になる（台帳が挙げる3経路のうち `viewItem` 経路。現在は `order-detail-missing` の1本のみ） |
| **L2 側** | `SqlMapItemDao.getItem` の `item == null` 側＝**§3.2 で「到達可能（スコープ外）」と判定した未踏分岐**をちょうど踏む |

**L2 のカバレッジの穴と、L4 の観測点の穴が同一だった。**
これは「カバレッジが低いから足す」ではなく「**台帳 ID に観測点が無いから足す**」という駆動が、結果としてカバレッジも動かすことを示している。**駆動を入れ替えても失うものが無い**——これが Retro C2 の提起に対する、実測での回答である。

なお `item-detail-missing` は、新側が `CatalogControllerSpec.groovy:154` で 404 を既に固定しているため、**旧側 golden を採るだけで宣言が書ける**状態にある。

### 4.4 起票（#52 AC5）

「穴」と部分観測から、次イテレーションの Story を起票した。**いずれも「台帳 ID に観測点が無いから足す」という順序で導出しており、未踏分岐を踏むのは副次効果である。**

| Issue | 内容 | 由来 |
| --- | --- | --- |
| **[#54](https://github.com/ryokkon624/jpetstore-manage/issues/54)** | 観測点の「穴」を埋める（**ID-30** 下書きの揮発 / **ID-33** カート全件表示） | §4.1（穴 2件） |
| **[#55](https://github.com/ryokkon624/jpetstore-manage/issues/55)** | 部分観測の補強と退行検知器の追加（`item-detail-missing` = **ID-14** の2本目＋未踏分岐／`item-out-of-stock-add` = **ID-18**＋未踏2分岐／**ID-32** の `STATELESS` assert／**ID-23** の AUTO_INCREMENT assert） | §4.2（部分観測 6件）・§4.3 |

- **#54 は「観測点が無いから作る」**、**#55 は「観測点はあるが見ている範囲が宣言より狭いから広げる」**。どちらも**カバレッジ数値を駆動にしていない**（#55 の AC-neg1 に明記）。
- **#55 AC5 でゲート値を再合意する。** シナリオ集合が変わるため（`l2-parity-coverage.md` §5-4 の運用ルール）。到達可能な3分岐をすべて踏めれば 31/34 になる見込みだが、**実測が正**。
- **本 Sprint ではどちらも実装しない**（#52 AC-neg2 ＝起票までがスコープ）。

---

## 5. 台帳そのものに対する L4 の発見

**L4 は「台帳どおりか」を確認する工程だが、その過程で台帳自身の誤りが見つかった。** 台帳が判定の分母である以上、これは L4 の一次成果である。

### 5.1 as-is 記述の事実誤認 — 3件を訂正（ユーザー承認 2026-08-21）

| 対象 | 旧記述 | 実測 | 根拠 |
| --- | --- | --- | --- |
| **ID-27** as-is | 多言語＝english/japanese（**日英 JSP 同梱**） | **日本語資産は1つも存在しない。** `langpref` は保存されるだけで描画に一切影響しない | `WEB-INF/jsp/` は `spring`/`struts` の2本のみ・`src` 配下の `*.properties` は3本のみ・`AccountFormController.java:25`・`IncludeAccountFields.jsp:41` |
| **ID-28** as-is | アイテム詳細に**在庫状況表示なし** | **生の在庫数をそのまま表示している**（`quantity<=0` → `Back ordered.` ／ それ以外 → `<数値> in stock.`） | `jsp/struts/Item.jsp:37-43`・`jsp/spring/Item.jsp:37-42` |
| **ID-10** after | ログイン/登録時に**セッション再生成** | 新側は `SessionCreationPolicy.STATELESS` で**セッション自体を作らない**。実体は新規 JWT 発行。**趣旨（固定化が成立しない）は不変**だが、字義どおりの観測点を作ると空振りする | `SecurityConfig.java:87` |

訂正履歴は台帳末尾の `## 訂正履歴` 節に残した（旧記述・訂正後の要点・根拠 `file:line`・訂正日・発見経緯）。

> **ID-28 の誤認は特に重要である。** 「旧は在庫を表示していなかった」という前提のままだと、新の3段階バッジは**純粋な新規 UX の追加**に見える。実際には**旧は生の在庫数を露出していた**ので、ID-28 は新規 UX であると同時に「**在庫数の露出をやめた**」という**防御寄りの差分**でもある。差分は「表示の有無」ではなく「**生の在庫数の露出 → status のみ**」であり、**as-is が誤っていると差分の性格そのものを読み違える。**

### 5.2 未台帳の差分 — 2件を追記（ユーザー承認 2026-08-21）

| 新 ID | 内容 | なぜ抜けていたか |
| --- | --- | --- |
| **ID-32** | 認証状態の保持方式: 旧 = サーバサイド HTTP セッション（`SignonAction.java:19,40`）→ 新 = **完全ステートレス**（`SecurityConfig.java:87` ＋ httpOnly JWT/refresh Cookie） | セッションに**同居していた個別状態**は ID-19（カート）・ID-30（下書き）・ID-20（ページング）で各々宣言されていたが、**方式そのものが宣言されていなかった** |
| **ID-33** | カート一覧のページング廃止: 旧 = 4件/頁・セッション保持（`Cart.java:22`・`Cart.jsp:22,57-61`）→ 新 = 全件表示（`CartView.vue` にページング要素なし） | **ID-20 が「カタログ一覧」限定**でカートを対象外としていたため、カート側が**どの ID の担当でもなくなっていた** |

いずれも**決定自体は実装時に済んでおり、記録だけが抜けていた**。台帳の運用ルール「振る舞いを変えると判断したら必ず追記」の運用漏れである。

### 5.3 行内に追記した2件

| 対象 | 追記内容 |
| --- | --- |
| **ID-1** | **denial-of-inventory の受容記録**。在庫ガード導入（ID-1）の帰結として、在庫0が他顧客の注文をブロックしうる。**旧に対する退行ではない**（旧はガードが無く在庫マイナスでも注文が通り続けたため、枯渇が他顧客をブロックしない）。現時点で受容し、本番基盤の整備決定時に `#45`・`#43`・`#46` と束ねて再評価 |
| **ID-26** | **`mysql-connector-j` の版乖離**（backend `9.5.0` / database `26.7.0`）。各リポジトリ単位では「版固定」を満たすが**ライブラリ単位で版が割れている**。**据え置き理由は未記録・要確認**と正直に記載 |

> **`l3-security-regression-backend.md` §3-5 の「ID-8 の帰結として受容される可能性があり PO 判断を仰ぐ」は、本 L4 で決着した。** PO の判定は「**ID-8 の帰結ではない**」。旧のカード必須検証は `OrderValidator.java:25-27` の `rejectIfEmpty` 3本で、エラーメッセージが文字どおり `"FAKE (!) credit card number required."`＝**任意の1文字で通るダミー欄**であり、旧にも決済ゲートは無い。さらに `OrderValidator` は**稼働 legacy（Struts 経路）では構造的に到達不能**（`web.xml` L140-142 で Spring MVC の servlet-mapping がコメントアウトされ `*.do` は Struts へ配送される）なので、**旧ではこの1文字チェックすら走っていない**。よって ID-8 は「在庫を枯渇させられる能力」を新たに作っていない。記録先は **ID-1**（在庫ガードの帰結）が正しい。

### 5.4 SM 自身の誤りも1件検出・訂正した

SM は当初「台帳 ID-26 が挙げる CVE-2023-22102 は L3 §2.2 が『非該当』としており食い違う」と報告したが、**PO が反証し、SM が検算して取り下げた**。台帳が言っているのは `jpetstore-database` の **8.0.33 → 26.7.0**（`jpetstore-database/build.gradle:30,38`）、L3 §2.2 が言っているのは `jpetstore-backend` の runtime **9.5.0**（`jpetstore-backend/build.gradle:65,68`）で、**対象アーティファクトが別**だった。§2.2 自身が「CVE-2023-22102 は 8.2.0 で修正済」と書いているので **8.0.33 は該当**であり、台帳の更新根拠は成立している。

> **教訓**: 「レポートの記述どうしを突き合わせる」段階でも誤りは入る。**座標（どのリポジトリの、どの依存か）まで一次データで確認してから「食い違い」と呼ぶこと。**「一次データで検算する」は、SM 自身の指摘にも等しく適用される。

### 5.5 引用元レポートの数え誤りを1件訂正した

`reports/after/l2-parity-coverage.md` の Sprint 22 追記部は「全**18**シナリオ」と 7 箇所で書いていたが、**17 が正**（off-by-one）。一次データ3系統がすべて 17：`ParityScenarios.groovy` の `ALL` 要素数 = 17／`src/test/resources/parity/golden/*.json` = 17 ファイル／内訳の足し算 = #48+#49 の 9 ＋ #51 の 8 = 17。
**ゲート値そのもの（BRANCH 28/34・INSTRUCTION 1360/1424）は実 exec に対する `report.sh` の機構出力なので影響しない。** 同 §S9 の「計19件」は**シナリオ数ではなく Spock のテストケース数**なので正しく、触っていない（`parityTest` 実測 6+3+1+3+6 = 19 で再確認）。

---

## 6. この報告書が「言えないこと」

**4本のゲートが PASS したことは、「何も変わっていない」ことを意味しない。** 以下は本書が主張**しない**ことである。

1. **台帳の網羅性は保証されていない。** 台帳が 31 → 33 件になったのは L4 が2件見つけたからであり、**L4 の探索が全数走査だった訳ではない**（PO と DEV が legacy と新側の主要面を読んだ結果である）。**3件目が無いとは言えない。**

2. **「観測点あり 31件」のうち 6件は部分観測である**（§4.2）。宣言の全体を見ているわけではない。

3. **穴が2件残っている**（ID-30・ID-33）。本 Sprint では**埋めていない**。起票しただけである。

4. **旧新の直接比較（L2）が成立している台帳 ID は 33 件中 4 件だけ**（ID-1・ID-14・ID-24・ID-29）。「旧と同じ結果になること」を旧の実測値と突き合わせて示せている範囲は、台帳を分母に取ると**狭い**。残りは L1（新側の AC 準拠）と L3（旧の脆弱性が消えたこと）で見ている。**これは L2 の欠陥ではなく、AI Factory が 1:1 再現ではないことの帰結である**（§0）。

5. **L2 が踏んでいる legacy の分岐は 28/34 であり、これは「理論上限」ではない**（§3.2）。`SqlMapItemDao` の3分岐は**シナリオを足せば踏める**。「上限に達したので伸ばせない」ではなく「**現行シナリオ集合のスコープでは踏んでいない**」が正確である。

6. **L2 の canonical モデルは一部のフィールドを最初から比較対象から外している**（§1.3）。`creditcard`/`exprdate`/`cardtype`（ID-8）・`courier`/`locale`（ID-21）・`orderstatus`/`linenum`（ID-22）・自動採番ID（ID-23）・`password`（ID-2）・`mylistopt`/`banneropt`（ID-7）・`color_scheme_preference`（ID-31）。**除外は「そこに差分がある」という宣言であって、差分の観測ではない。**

7. **L3 の PASS は before の findings（S1〜S21）に対するものである。** after 側には **Low 4件が残っており**（`sprint20-delta`・`#42`〜`#47` で起票済み）、同レポート自身が「完全な clean とは書けない」と書いている。

8. **L1 の 951 テストは AC 準拠を見ているのであって旧同値を見ていない。** 「仕様どおりに動く」ことと「旧と同じに動く」ことは別である。

9. **注文の二重送信は未決着である**（§3.4）。旧新差分でない公算が高いという PO 判定に基づく条件付き保留であり、**実測していない**。DEV の確認でも、同一ユーザー・同一カートの並行 POST を観測しているテストは **0件**だった（`OrderConcurrencyIntegrationSpec.groovy:101` は 2ユーザー別カートを競合させる設計）。**「起きない」証拠も「起きる」反証も、テスト資産に存在しない。**

10. **本書は静的な検証の突き合わせであり、稼働環境での通しシナリオ（受入テスト）ではない。** L3 のライブ PoC 以外に、旧新を同時に動かして人が比べた記録は本書に含まれない。

---

## 7. まとめ — Phase 4 の結論

**「旧を正しく再現できた」と言える範囲**

- 保存すべき業務ロジックのうち、L2 が旧の実測値と直接突き合わせている **17 シナリオ**（golden 17本）は**宣言どおり**である。宣言外の差分があれば `ParityComparator` が fail する設計で、**`parityTest` 23/23 green**。
- before で確定した脆弱性 **S1〜S21 は 21/21 すべて after で失敗する**（消滅 9・是正 12）。未対応 0 件。
- 台帳 **33 件中 31 件に観測点がある**（L1 14・L3 13・L2 4）。
- **951 テスト・failures 0**（backend 587・frontend 267・database 97）。

**「言えない範囲」**

- **穴 2 件**（ID-30・ID-33）、**部分観測 6 件**。
- 旧新の**直接比較が成立しているのは 33 件中 4 件**。
- L2 が踏んでいる legacy 分岐は **28/34**（残 6 のうち **3 は到達可能・スコープ外**）。
- after 側の Low 残件 4 件はゲート外。
- 台帳の網羅性そのものは保証されない。

> **Phase 4 は完走した。ただし「完走」とは、検証4層をすべて実施し、その結果として「どこまで言えて、どこから言えないか」を確定させたということであって、「すべてが検証された」ということではない。**
> 本書の価値は前者にある。**「何も変わっていないと証明しろ」に対する誠実な回答は、「ここまでは同じだと言える／ここから先は言えない」という境界線を引くことである。**

---

## 付録: 一次データと検算の記録

| 種別 | 場所 |
| --- | --- |
| SM の独立検算（V1〜V12） | [`backlog/sprint_23/sm-verification.md`](../../backlog/sprint_23/sm-verification.md) |
| DEV の観測点実測（33行・全根拠） | [`backlog/sprint_23/dev-observation-points.md`](../../backlog/sprint_23/dev-observation-points.md) |
| DEV のゲート実行結果（生出力つき） | [`backlog/sprint_23/dev-gate-results.md`](../../backlog/sprint_23/dev-gate-results.md) |
| PO の仕様側判定（33行・全根拠） | [`backlog/sprint_23/po-ledger-classification.md`](../../backlog/sprint_23/po-ledger-classification.md) |
| 意図差分台帳（訂正履歴つき） | [`spec/intended-diff-ledger.md`](../../spec/intended-diff-ledger.md) |
| L2 カバレッジ実測 | [`reports/after/l2-parity-coverage.md`](./l2-parity-coverage.md) |
| L3 セキュリティ回帰 | [`l3-security-regression-backend.md`](./l3-security-regression-backend.md)／[`-frontend.md`](./l3-security-regression-frontend.md)／[`-sprint20-delta.md`](./l3-security-regression-sprint20-delta.md) |
| L2 の jacoco 実測（機構出力） | `tools/legacy-jacoco/out3/report/{ac1,gate,gate-v2}/jacoco.csv` — **削除しないこと**（ゲート値の唯一の裏取り経路。gitignore 済みでコミットされていない） |

> **検算の二重化**: ゲート値（BRANCH 28/34・INSTRUCTION 1360/1424）と残存未踏分岐の内訳は、**DEV と SM が互いの結果を見ずに `jacoco.csv` を合算し、同じ値に着地した**。レポートの記述を経由しない経路が2本とも一致している。
