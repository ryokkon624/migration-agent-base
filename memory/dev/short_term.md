# DEV 短期記憶

## Sprint 22 / Issue #51（[L2] パリティをアカウント系・注文履歴照会へ拡張）実装方針

- **状態**: **実装完了（2026-08-21）**。T1〜T6すべて完了・golden 8本コミット済み・`parityTest`/`test`ともgreen。
  実測はBRANCH 28/34(82.4%)・INSTRUCTION(gate-v2) 1360/1424(95.5%)。詳細は`reports/after/l2-parity-coverage.md`
  Sprint22追記・`backlog/sprint_22/planning-log.md` §6参照。**理論上限は29/34ではなく28/34**（`Cart.addItem`の
  false側も`CartItem`と同型の構造的到達不能と実装フェーズで新発見・実測裏取り済み。詳細は`memory/dev/long_term.md`
  「jpetstore-backend」§参照）。以下§0〜§13は計画フェーズの確定方針（実装はこの通り反映済み・履歴として残す）。
- **ブランチ**: `jpetstore-backend` = `feature/51-l2-parity-account-orders` ／ `migration-agent-base` = `docs/sprint-22-l2-parity-account-orders`（SM 作成済み・新規作成しない。**`main` 直コミット禁止**）
- **スコープ**: `jpetstore-backend` の **test スコープ単独**（`src/main` は1行も触らない）＋ `migration-agent-base` のレポート/spec/tool。cross-repo なし。legacy は起動のみ・無改変。

---

### 0. 一次データで見つけた訂正2件（Issue 本文／SM-2 の誤り）

**訂正A: R8b の新側は 404 ではなく 403。**
`OrderApplicationService.java:171-179` が不存在も非所有も同一の `AccessDeniedException` にし、
`GlobalExceptionHandler.java:102-109` が 403 `FORBIDDEN` へ正規化する（ID-4「not-owned/not-found を同一応答」）。
Issue スコープ表の「新側は 404」は成立しない。ID-14 の趣旨（500＋スタックトレース露出 → 露出なし）は 403 でも成立するため
**R8b は `INTENDED_DIVERGENCE(ID-14)` のまま**とし、台帳 ID-14 に「注文詳細経路は ID-4 と重畳して 403」の注記を足す。
→ **Q1 で確定（ユーザー判断）。SM も一次データで独立確認済み。**

**訂正B: 到達可能上限は 30/34 ではなく 29/34。**
`CartItem` の未踏1分岐は `getTotalPrice()` の `if (item != null)` の **false 側**。`CartItem` は `Cart.addItem()` 内でしか
生成されず必ず `setItem(非null)` されるため **HTTP 経路から構造的に到達不能**。AC4 で踏めるのは `Cart` の3のみ。
到達可能上限 = 16 + Account 4 + SqlMapAccountDao 4 + SqlMapOrderDao 2 + Cart 3 = **29/34（85.3%）**。
クラス粒度の除外機構では `CartItem`（branch 1/2 covered）を落とせないので分母34は据え置く（#50 §5-5 と同じ理由）。
AC7 暫定目標 24/34 は依然余裕あり。**数値は実測が正・ゲート値は実測後に PO と再合意（先に決めない）**。
→ **Q2 で確定（SM 判断）。「到達不能だがクラス粒度では除外できない分岐」として根拠つきでレポートに明記する。**
SM も独立確認済み（`CartItem` の `if` は `getTotalPrice()` の1箇所のみ／`new CartItem()` は `Cart.java:38` の1箇所のみで
直後 L39 が `setItem(item)`）。**`sprint_backlog.md` の SM-2（30/34）は SM が後で訂正する**。
なお `Cart` の未踏3は `removeItemById` の2アウトカム＋`addItem` の false 側で、いずれも HTTP 経路から到達可能（SM 確認済み）。

---

### 1. 台帳（`ParityScenarios.ALL`）へ追加する8行

`order-insufficient-stock`（W3・D2 特例で後始末しない）が**必ず末尾**になるよう、その直前に挿入する。

```
account-register              EQUIVALENT                      // W4
account-edit-nopw             EQUIVALENT                      // W5a
account-edit-pw               EQUIVALENT                      // W5b
account-edit-pwfield-absent   EQUIVALENT                      // W5c
orders-list                   EQUIVALENT                      // R7
order-detail-own              INTENDED_DIVERGENCE(ID-24)
                              divergentFields = ["lines[EST-1].productName"]          // R8a ★Q6で変更
order-detail-missing          INTENDED_DIVERGENCE(ID-14)
                              divergentFields = ["httpStatus", "stackTraceExposed"]   // R8b
cart-boundary                 EQUIVALENT                      // AC4（優先度は最後）
```

**★ R8a は Q6（ユーザー判断）で `EQUIVALENT` → `INTENDED_DIVERGENCE(ID-24)` に変更した。**
`productName` は平文PW vs ハッシュ（ID-2・確定2＝案A）と違い**値として比較可能**であり、canonical から
除外すると台帳 ID-24 が観測点を持たないまま残るため。DEV の当初推奨（正規化除外）とは異なる結論。
- 旧の実体（実コードで裏取り済み）: `dao/ibatis/maps/LineItem.xml:14-16` の `getLineItemsByOrderId` は
  `orderid, linenum, itemid, quantity, unitprice` しか読まず `LineItem.item` を**一切埋めない**
  （`domain/LineItem.java:14` の `item` は `LineItem(int, CartItem)` ＝注文確定時の構築経路でしか設定されない）。
  よって `ViewOrder.jsp` の description セル（`${lineItem.item.attribute1..5}` と `${lineItem.item.product.name}`）は
  **すべて空**になる。新側は `OrderDetailLineResponse.productName` が JOIN 済みの実名を返す。
- **`INTENDED_DIVERGENCE` は R8a が EQUIVALENT だという Issue スコープ表からの意図的な逸脱**。
  Sprint Review の AC 達成状況で SM が PO に明示報告する（DEV は実装とレポート記載を進める）。
- **`intended-diff-ledger.md` の ID-24 の関連Story にも #51 を追記**する（ID-14 と同じ作法）。

### 2. `ParitySnapshot` 追加フィールド（AC6 が明示的に許可した範囲）

| フィールド | 型 | 用途 | 比較 |
| --- | --- | --- | --- |
| `account` | `Map<String,String>` | 確定1 の canonical 14項目 | `account[email]` 形式でキー単位 diff（`inventoryDelta[EST-1]` の先例踏襲＝AC-neg1 のフィールド粒度維持） |
| `accountsCreated` | `Integer` | W4 のみ。`account`/`m_account` 行数の増分 | スカラ |
| `httpStatus` | `Integer` | R8a=200/200・R8b=500/403 | スカラ |
| `stackTraceExposed` | `Boolean` | 本文に例外クラス名 or `at org.springframework.samples.` フレームを含むか（**SM-3**） | スカラ |
| `Line.productName` | `String` | **Q6 追加**。R8a の ID-24 観測点（旧="" ／ 新=実名） | `lines[EST-1].productName` 粒度（既存の `lines[EST-1].quantity` と同じ形） |

- `Line` への `productName` 追加は W1/W2/W3 にも波及するが、両側とも DB（`lineitem`/`t_order_line`）から
  組むため **両側 null → 差分ゼロ**。golden JSON へのノイズは `Line.productName` にも
  `@JsonInclude(NON_NULL)` を付けて回避する。`Line.normalize()`/`equals`/`hashCode`/`toString` と
  `ParitySnapshotSpec` の更新を忘れないこと。
- `productName` を `entries` に畳まず `Line` のフィールドにする理由: `entries` にすると差分が
  `entries` という**単一の粗いフィールド**にまとまり、`divergentFields` の完全一致判定（Q4 確定）が
  他の差分を巻き込んで検知できなくなるため。
- `normalize()` に `account` の TreeMap 化を追加。`ParityComparator.diffFields()` に5種の差分生成を追加。
  **判定規則そのもの（EQUIVALENT/INTENDED_DIVERGENCE の完全一致判定）は無変更＝AC6。**
- 新フィールドは `@JsonInclude(NON_NULL/NON_EMPTY)`。既存9 golden の JSON に `null`/`{}` ノイズを持ち込まない
  （`preconditions` の先例と同じ「フィールド単位の include 指定」）。
- `account` のキー: `username, email, firstName, lastName, status, address1, address2, city, state,
  postalCode, country, phone, languagePreference, favoriteCategoryId`

R8b の例外クラス名（`java.lang.NullPointerException`）は `divergentFields` に入れず、**比較対象外の `preconditions`** に
証拠として残す（3つ目を足すと完全一致判定が脆くなるため）。

### 3. SM-3 への回答（「この前提が満たされなくなったとき parityTest は落ちるか？」）

| シナリオ | 前提 | 採取時 assert（満たさなければ golden を書き出さず fail） | parityTest で落ちるか |
| --- | --- | --- | --- |
| W4 | favoriteCategoryId が bannerdata に存在 | `SELECT COUNT(*) FROM bannerdata WHERE favcategory=?` == 1 | —（採取時のみ） |
| W4 | 3表が1行ずつ増える | account/profile/signon の COUNT 増分 == 1 each | ✅ `account[*]`・`accountsCreated` |
| W5a | `password=""` → updateSignon が走らない | 編集前後の `signon.password` が不変 | ✅ `account[*]` |
| W5b | 新PWで updateSignon が走る | 編集後 `signon.password` == 新PW（before ≠ after） | ✅ ＋ AC-neg4（新PW 200／旧PW 401）が毎回走る |
| W5c | `account.password` を送らない → null 側 | 送信 Map にキーを含めないことをコードで保証＋`signon.password` 不変 | —（カバレッジ専用） |
| R7 | 一覧の増分がちょうど2件で作った orderId と一致 | 一覧 delta の orderId 集合 == 作成2件 | ✅ `entries` |
| R8a | 参照 orderId が自分の実在注文 | ORDERS に存在し `userid == 'j2ee'` | ✅ `lines`/`orderTotal`/`httpStatus` |
| R8a | **旧の注文詳細で商品名が空**（ID-24 の前提・**Q6 で追加**） | ViewOrder.jsp の description セルから抽出した productName が**空/空白であること**。満たさなければ golden を書き出さず fail | ✅ `lines[EST-1].productName` を canonical に載せるので、新側が空を返すようになれば「INTENDED_DIVERGENCE 宣言だが実測が一致（台帳の形骸化）」で fail |
| R8b | 指定 orderId が存在しない（**両側で assert**。SM verification対応：初出時は旧側`LegacyDbReader#orderExists`のみで新側に対になる assert が無く、`GET /api/orders/{id}`が不在/非所有を同一403にする（ID-4/SBD-8）ためスナップショットだけでは前提崩壊を検知できなかった） | 旧= `SELECT COUNT(*) FROM ORDERS WHERE ORDERID=?` == 0（`LegacyDbReader#orderExists`）／新= `SELECT COUNT(*) FROM t_order WHERE order_id=?` == 0（`NewDbReader#orderExists`。`NewScenarioRunner#orderDetailMissing`冒頭でassert） | ✅ 旧新とも前提が崩れれば専用メッセージでfail（新側のfail-pathは999999999を強制的に実在させたシナリオで実証済み） |
| R8b | 旧が 500 かつ本文にスタックトレース | `status==500` かつ本文に例外クラス名／`at org.springframework.samples.` を含む | ✅ 新側が 403 から動けば fail |
| cart | 2回追加で qty=2／削除後に空／再削除でも 200 かつ空 | 各ステップの HTML 実測を assert | ✅ `entries` |

`preconditions` に残す実測値: W4=`bannerdataRows`/行数増分、W5x=`signonPasswordChanged`・`passwordParamSent`、
R8a=`orderExists`・`legacyProductNameBlank`・`legacyDescriptionCellRaw`、R8b=`orderExists`・`legacyExceptionClass`、
cart=各ステップの qty。

### 4. 両側 Runner に足すメソッド／旧側 HTTP 駆動手順

`capture/LegacyScenarioRunner`: `accountRegister()` / `accountEdit(variant)` / `ordersList()` / `orderDetailOwn()` /
`orderDetailMissing()` / `cartBoundary()` / `private long placeOneOrder(Map)`（後始末なしで orderId を返す）。
**既存 `placeOrder(items, restoreAfter)` は一切触らない**（W1/W2/W3 の golden を `capturedAt` 以外バイト不変に保つ）。

**旧側パラメータ名（JSP 実物で確認済み）**: `validate` / `account.username` / `account.password` / `repeatedPassword` /
`account.firstName` / `account.lastName` / `account.email` / `account.phone` / `account.address1` / `account.address2` /
`account.city` / `account.state` / `account.zip` / `account.country` / `account.languagePreference` /
**`account.favouriteCategoryId`（英国綴り）** / `account.listOption` / `account.bannerOption`（チェックボックスは送れば true）。

W4:
```
resetSession → GET /newAccountForm.do → POST /newAccount.do
  validate=newAccount, account.username=parity_w4, account.password=<PW>, repeatedPassword=<PW>,
  氏名/email/phone/住所一式, account.languagePreference=english, account.favouriteCategoryId=FISH
  ※ listOption / bannerOption は送らない（= Account の false 側2アウトカム）
→ 前提 assert → canonical 読取（account JOIN profile を素の SQL で）→ 3表 DELETE（affected rows 検査つき）
```

W5x（各シナリオ自己完結・毎回 `resetSession()`）:
```
resetSession
→ GET /newAccountForm.do → POST /newAccount.do   （編集対象を登録経路で作る。username=parity_w5a/b/c）
→ GET /editAccountForm.do                        （★ workingAccountForm を DB から再ロード＝account.password は null）
→ POST /editAccount.do
   validate=editAccount, account.username=<同左>, 変更後の各項目,
   account.listOption=on, account.bannerOption=on  （= Account の true 側2アウトカム）
   ├ NOPW  : account.password="" ＋ repeatedPassword=""        → 分岐1-true / 分岐2-false
   ├ PW    : account.password=<新PW> ＋ repeatedPassword=<新PW> → 分岐2-true（updateSignon 実行）
   └ ABSENT: account.password も repeatedPassword も送らない    → 分岐1-false
→ signon.password の before/after を assert → canonical 読取 → 3表 DELETE
```

**W5c の順序依存（R7 リスク）への対処**: `resetSession()` で毎回 JSESSIONID を捨てるため session scope の
`workingAccountForm` は存在しない。加えて `NewAccountFormAction` は `removeAttribute` してから新規生成、
`NewAccountAction`/`EditAccountAction` も成功時に `removeAttribute` する。`editAccountForm.do` 直後に
`editAccount.do` を撃つので `account.password` は DB 由来の null から始まる
（`Account.xml` の `getAccountByUsername` resultMap が password 列を写さないことを実物で確認済み）。

R7: `resetSession → signon.do(j2ee) → listOrders.do(baseline) → placeOneOrder(EST-1 x1) → placeOneOrder(EST-1 x2)
→ listOrders.do(after) → delta 集合 = {16.50, 33.00} → 後始末（orders/lineitem/orderstatus 削除・
ordernum/linenum 復元・EST-1 在庫復元）`
R8a: `resetSession → signon.do(j2ee) → placeOneOrder(EST-1 x2) → viewOrder.do?orderId=<自注文>
→ lines(itemId/quantity/unitPrice/**productName=""**)/orderTotal/httpStatus=200
→ productName が空であることを assert（ID-24 の前提・Q6）→ 後始末`
R8b: `resetSession → signon.do(j2ee) → 前提 assert（ORDERS に 999999999 が無い）→ viewOrder.do?orderId=999999999
→ httpStatus=500・stackTraceExposed=true を assert`
（`ViewOrderAction` が `getOrder()` の null 未チェックで `order.getUsername()` → NPE。`web.xml` に `error-page` 無し・
`struts-config.xml` に `global-exceptions` 無しを確認済み）
cart-boundary: `addItemToCart.do?workingItemId=EST-1 ×2（2回目が Cart.addItem 非null側）→ viewCart.do（qty=2）
→ removeItemFromCart.do（removeItemById 非null側）→ 空 → removeItemFromCart.do 再実行（removeItemById null側）→ 空・200`

`verify/NewScenarioRunner` は同名6メソッド。新側の要注意点（SM-4 反映）:
- W5x は `POST /api/register`（201・自動ログイン）→ **`GET /api/account`（version 取得）→ `PUT /api/account`** の2ステップ必須。
  `colorSchemePreference:"system"` を必ず入れる（`@NotBlank @Pattern` ＝未指定は 400）。
- W5b は **`PUT` を先・`POST /api/account/password` を後**（トークンローテーション後の Cookie は
  `NewHttpClient.captureCookies` が自動追従）。
- R7 は `PageResponse` を `page=1..totalPages` で全ページ走査（ID-20・F5）。
- canonical は両側とも **DB 直読み**（`m_account JOIN m_profile`）で組む＝旧側と対称。

`LegacyHtmlExtractor` へ追加: `extractOrderListRows` / `extractOrderLineRows`（**productName も抽出する**・Q6） /
`extractOrderTotal` /
`extractCartRows`（`<input name="EST-1" value="2">`）/ `extractCartSubTotal` / `containsStackTrace`。
金額は `$`・`,` を許容するトレラント parser で剥がしてから `normalizeAmount()`
（実機で `fmt:formatNumber` が効かず生値が出る既知挙動に両対応）。

### 5. Testcontainers フィクスチャ（AC-neg5）と後始末（AC-neg2）

`verify/ParityUserFixture.groovy` を新設して1箇所に集約（`OrderParitySpec` も同じものを使う最小 retrofit）。

投入（`R__` は届かないので直接 INSERT）:
`m_account(username,email,first_name,last_name,status='OK',address1,city,state,postal_code,country,phone,
create_program,update_program)` ／ `m_signon(user_id, password_hash = passwordEncoder.encode(PW), ...)` ／
**`m_profile(user_id, language_preference='english', favorite_category_id='FISH', ...)` ← 必須**
（`AccountEditCustomMapper.findByUserId` が `m_account JOIN m_profile` のため。R7/R8/cart の `demo_user` にも入れる）。

新側の後始末（削除順）:
`t_cart_item → t_cart → t_order_line → t_order → t_audit_log → t_login_attempt → t_register_attempt
→ m_profile → m_signon → m_account`
- `t_register_attempt` は **PK が client_ip**（username ではない・`V00_000_012__create_register_attempt.sql:35`。SM 確認済み）。
  `RegisterAttemptService` は **成功時リセットを持たない**（5回/15分・IP 単位）ため、`setup()` で全行 DELETE しないと
  再実行や複数シナリオで 429 になる。
- **★ Q3 付随の必須対応**: 自己完結方式では W4＋W5a/b/c で同一IPから**4回**登録し、上限5に肉薄する。
  `setup()` の全行 DELETE に加えて、**`POST /api/register` が 429 を返したら「`t_register_attempt` のレート制限に
  当たった（5回/15分・client_ip 単位・成功時リセット無し。残存行の後始末漏れを疑え）」と明示するメッセージで fail**
  させること。登録を伴う feature が増えたときに黙って落ちないようにするため（原因の切り分けを即座に可能にする）。
- `t_audit_log` は **R8b の 403 が `recordAuthzFailure` で1行書く**ため必須。

旧側の後始末: W4/W5x は `signon → profile → account` の順に該当 username 行を DELETE（affected rows 検査つき）。
R7/R8a は `lineitem/orderstatus/orders` 削除＋`ordernum`/`linenum` 復元＋`EST-1` 在庫復元。
**`j2ee` 行は編集も削除もしない**（signon.do でのサインオンのみ）。

### 6. AC-neg4（新側 PW 独立検証）の置き場所

`AccountParitySpec` の**別 feature メソッド**として置き、**golden には一切載せない**。
- 「W4 で登録した PW でログイン成功し、`m_signon.password_hash` が平文と一致しない（SBD-5／ID-2 案A）」
- 「W5b で PW 変更後、新PWでログイン 200・旧PWで 401」
実パスは **`POST /api/auth/login`**（AC-neg4 本文の `/api/login` は誤り。`AuthController` L33+L55 で SM 確認済み）。
旧PW失敗は Cookie を持たない新しい `NewHttpClient` インスタンスで撃つ。

### 7. AC5 の結論（実コードで確定・行番号は実物で検算済み）

**`OrderValidator` / `AccountValidator` はいずれも到達不能。**

| 根拠 | 内容 |
| --- | --- |
| `web.xml` L87-91 | `petstore`（Spring MVC DispatcherServlet）は `load-on-startup=2` で**宣言されている** |
| `web.xml` L134-145 | だが `servlet-mapping` は L140-142 で `petstore` が**コメントアウト**、L143 で `*.do` は `action`（Struts）に割当。**URL が到達しない** |
| `applicationContext.xml` L42 / L45 | 両バリデータは root context の bean 定義＝**インスタンス化はされる**（instruction 3 の正体） |
| `petstore-servlet.xml` L37 / L98 / L108 | 唯一の呼び出し元は Spring MVC の `AccountFormController`×2・`OrderFormController`。全リポジトリ grep で他に呼び出し元なし（`OrderFormController.java:87-95` のみ） |

→ レポート §3 の「`AccountValidator` はアカウント系シナリオ未実装のため未踏」は**誤りとして訂正**する。
W4/W5 を足しても Struts 経路（`AccountActionForm.doValidate`）を通るので踏めない。

### 8. AC-neg3（除外反証チェックの拡張）

```
STRICT_EXCLUDED="SendOrderConfirmationEmailAdvice MsSqlOrderDao OracleSequenceDao"   # ==0 を維持
BASELINE_EXCLUDED="OrderValidator:3:0 AccountValidator:3:0"                          # CLASS:INSTR_COVERED:BRANCH_COVERED
```
実測根拠（`tools/legacy-jacoco/out2/report/ac1/jacoco.csv`）:
`OrderValidator,108,3,0,0,...` ／ `AccountValidator,50,3,0,0,...` → instruction covered=3・branch covered=0。
判定は **`!=` で fail**（**Q5 確定・SM 判断**）。AC-neg3 の「超えたら fail」は部分集合として充足する。
**増と減でメッセージを書き分ける**こと:
- 増（`> baseline`）＝「呼び出し元が到達不能」という除外の前提が崩れた → ゲート分母の再定義と PO 再合意が必要
- 減（`< baseline`）＝bean 定義自体が変化した（インスタンス化されなくなった）→ ベースライン値の実測根拠が stale

### 9. 計測〜レポート更新〜AC7 再合意案（T6・**AC5 と AC7 は一体**）

```
1. docker rm -f jpetstore-legacy-jacoco-measure
2. docker build -t jpetstore-legacy-jacoco tools/legacy-jacoco   （jpetstore-legacy は無改変）
3. docker run -d --name ... -p 8081:8080 -p 9002:9002 -v .../out3:/jacoco jpetstore-legacy-jacoco  ★別ポート
4. index.do が 200 になるまでポーリング
5. ./gradlew captureGolden -Dparity.legacy.baseUrl=http://localhost:8081/... -Dparity.goldenDir=/tmp/...
   （計測用は golden を上書きしない。golden 本体の再採取は goldenDir 既定で別途1回）
6. docker stop -t 30 <container>          ★ graceful でないと exec が書かれず計測が消える
7. report.sh を 2 回流す:
     (i)  #50 の exec（tools/legacy-jacoco/out2/jacoco.exec・現存を確認済み）
     (ii) 今回の exec（out3/jacoco.exec）
   classfiles は同一コンテナから docker cp（WAR は凍結＝バイトコード同一）
8. docker rm <container>
```

`report.sh` は **3本出し**に拡張（Q4）: `ac1/`（除外なし）・`gate/`（3除外＝#50 合意分母・継続性）・
`gate-v2/`（5除外＝AC5 反映の提案分母）。これで手計算ゼロで (a)/(b) を分離できる:

|  | `gate/`（3除外・分母 34/1588） | `gate-v2/`（5除外・分母 34/1424） |
| --- | --- | --- |
| 旧シナリオ集合（#50 exec） | 16/34・1144/1588（#50 実測） | ← **(a) 除外だけの効果** |
| 新シナリオ集合（今回 exec） |  | ← (a)+(b) |

→ **(b) 追加シナリオの効果 = 同一分母（`gate-v2`）での「新 − 旧」**。レポートにこの 2×2 表をそのまま載せ、
**除外だけで上がった数値を「カバレッジが向上した」と報告しない**（AC7）。
BRANCH は絶対数を正（分母 34 据置）、INSTRUCTION は分母が動くので絶対数で再合意（%は可読形）。
あわせて明記: `Account` 4分岐と W5c は「ID-7 由来・カバレッジのみでパリティ観測点ではない」／
`CartItem` の残1分岐は構造的到達不能で上限は 29/34（訂正B）／AC-neg3 ベースライン値の実測根拠。

### 10. 変更ファイル

`jpetstore-backend`（test スコープのみ・`src/main` は1行も触らない）
- 新規: `parity/AccountParitySpec.groovy` / `parity/OrderHistoryParitySpec.groovy` / `parity/CartParitySpec.groovy` /
  `parity/verify/ParityUserFixture.groovy`
- 新規 golden 8本: `account-register` / `account-edit-nopw` / `account-edit-pw` / `account-edit-pwfield-absent` /
  `orders-list` / `order-detail-own` / `order-detail-missing` / `cart-boundary`
- 編集: `ParityScenarios` / `canonical/ParitySnapshot` / `canonical/ParityComparator` / `capture/LegacyScenarioRunner` /
  `capture/LegacyDbReader` / `capture/LegacyHtmlExtractor` / `verify/NewScenarioRunner` / `verify/NewDbReader` /
  `OrderParitySpec`（fixture 共通化・`m_profile` 追加の最小 retrofit）
- 編集（テスト・TDD で先に RED）: `ParitySnapshotSpec` / `ParityComparatorSpec` / `LegacyHtmlExtractorSpec`

`migration-agent-base`（`docs/sprint-22-l2-parity-account-orders`）
- `tools/legacy-jacoco/report.sh`（3本出し＋ベースライン方式）／`tools/legacy-jacoco/README.md`
- `reports/after/l2-parity-coverage.md`（§3 訂正・§4 更新・§5 再合意・2×2表・AC-neg3 根拠）
- `spec/intended-diff-ledger.md` — **1回の編集で3件まとめて**（Q1・Q6 確定）:
  1. **ID-14** の関連Story に `#51` 追記
  2. **ID-14** の「新の振る舞い」欄に「注文詳細経路は ID-4 と重畳して 403（404 ではない）」の注記
  3. **ID-24** の関連Story に `#51` 追記（R8a が ID-24 の観測点になるため）
- （**Q7 確定・含める**）`spec/l2-parity-design.md` §2 台帳に8行追加・§6 未決事項2（アカウント系は次イテレーション）を
  解決済みに更新。本Storyがまさにその「次イテレーション」のため、更新しないと spec が stale になる。

### 11. TDD の進め方

1. **RED**: `ParitySnapshotSpec`（`account` の TreeMap 正規化）・`ParityComparatorSpec`（`account[email]` 粒度の diff／
   R8b の完全一致判定）・`LegacyHtmlExtractorSpec`（固定 HTML 断片からの抽出・`containsStackTrace`）
2. **GREEN**: `ParitySnapshot` / `ParityComparator` / `LegacyHtmlExtractor`
3. Runner・Spec 実装 → legacy 起動 → `captureGolden` → golden コミット →
   **legacy を停止して `./gradlew parityTest` が green**（AC8・DoD-1）
4. 計測 → レポート → AC7 再合意案の提示

---

### 12. ユーザーへの確認事項（**Q1〜Q7・2026-08-21 に全件決着**）

> ⚠️ 本節は SM が確定回答で更新した（旧版は全行「未回答」のスナップショットだった）。
> **実装フェーズはここを再質問せず、下記の確定回答どおりに進めること。**

| # | 論点 | 確定回答 | 判断者 |
| --- | --- | --- | --- |
| Q1 | R8b の新側は 403（404 ではない・訂正A）。期待は `INTENDED_DIVERGENCE(ID-14)` のままでよいか。台帳 ID-14 に注記を足すか | ✅ **ID-14 のまま＋台帳 ID-14 に「注文詳細経路は ID-4 と重畳して 403」の注記**。関連Story に #51 も追記（1回の編集でまとめて） | ユーザー |
| Q2 | 到達可能上限は 29/34（`CartItem` の残1は構造的到達不能・訂正B）。§3 と同じ作法でレポートに明記してよいか | ✅ **明記する。分母 34 は動かさない**（手計算での分母縮小は #50 §5-5 の drift を再導入するため） | SM |
| Q3 | W5 の編集対象を自己完結方式（`parity_w5a/b/c` を各自登録・各自削除）にしてよいか。AC2「W4 が作ったアカウント」は「登録経路で作られた＝`j2ee` ではない」の意と解釈 | ✅ **自己完結方式**（`j2ee` は不変のまま）。W4 の実行結果を跨ぐと Spock のイテレーション独立性が壊れるため | ユーザー |
| Q4 | `report.sh` を3本出し（`ac1`/`gate`=3除外/`gate-v2`=5除外）に拡張し、#50 exec と今回 exec の両方に流して (a)/(b) を手計算ゼロで分離してよいか | ✅ **3本出し**。DoD の「2本」は部分集合として充足 | SM |
| Q5 | AC-neg3 のベースライン判定を「超えたら fail」ではなく `!=` で fail にしてよいか | ✅ **`!=` で fail**。AC の文言は部分集合として充足。**増（前提崩壊）と減（bean 定義の変化）でメッセージを書き分ける** | SM |
| Q6 | AC-neg4 の `POST /api/login` は実パス `/api/auth/login`。R8a の canonical から `productName`（ID-24）と `orderDate` を正規化除外にしてよいか | ⚠️ **分割回答。`orderDate` は除外で可**（時刻依存＝WHO 列と同類）。**`productName` は除外せず、R8a を `INTENDED_DIVERGENCE(ID-24)` の観測点にする**（値として比較可能なため。§1 L43-58 に反映済み）。`/api/auth/login` の訂正はそのまま採用 | orderDate=SM<br>productName=ユーザー |
| Q7 | `spec/l2-parity-design.md` §2 台帳への8行追加・§6-2 未決事項2 の解決反映を本スプリントに含めてよいか | ✅ **含める**。本Storyがまさに §6-2 の言う「次イテレーション」のため、更新しないと spec が stale になる | SM |

**Q6 に伴う派生タスク（忘れないこと）**

- `intended-diff-ledger.md` の **ID-24 の関連Story にも #51 を追記**する（ID-14 と同じ作法）。
- **SM-3（検証資産の耐久性）を R8a にも適用**: 「旧の注文詳細で `productName` が空」という前提を**採取時に assert し、満たさなければ golden を書き出さず fail** させる（W4 の bannerdata 前提・W5c の null 側到達と同じ扱い）。
- R8a が `EQUIVALENT` だという **Issue スコープ表からの意図的な逸脱**である点は、Sprint Review の AC 達成状況で **SM が PO へ明示報告**する（DEV 側の対応は不要）。

**Q3 に伴う注意（必ず反映）**

- `t_register_attempt` は **client_ip 単位・5回/15分・成功時リセット無し**。自己完結方式では W4＋W5a/b/c で同一IPから **4回**登録するため上限 5 に肉薄する。
- `setup()` での全行 DELETE に加え、**429 を受けたら「レート制限に当たった（`t_register_attempt` の残存を疑え）」と分かるメッセージで fail** させる。黙って 429 で落ちると原因の切り分けに時間を取られる。

### 13. 実装フェーズ着手時の申し送り

- **§12 の Q1〜Q7 は全件決着済み。再質問せず確定回答どおりに進める。**
- **最も見落としやすいのは Q6**: R8a は `EQUIVALENT` ではなく **`INTENDED_DIVERGENCE(ID-24)`**。
  `ParitySnapshot.Line` に `productName` を足し、`divergentFields = ["lines[EST-1].productName"]` を宣言する。
  Issue スコープ表（R8a=EQUIVALENT）からの意図的逸脱であり、PO への報告は SM が行う。
- **AC5 と AC7 は一体**（分母が動くため）。T5 と T6 を同一タスク束として扱う。
- **ゲート値の数値を先に決めない**。SM-2 の 30/34 は見積り、しかも 29/34 が正（訂正B）。
- **JaCoCo は `docker stop -t 30` の graceful 停止**でないと exec が書かれない。
- **採取用 legacy は別ポート（8081/9002）**。`jpetstore-legacy` イメージは無改変・計測用 overlay は `jpetstore-legacy-jacoco`。
- Discord MCP は本セッション未接続。投稿予定内容は `backlog/sprint_22/planning-log.md` に記録済み。
