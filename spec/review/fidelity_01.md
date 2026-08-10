# spec 敵対的レビュー — レンズ: コード忠実性 (fidelity)

- **対象**: `spec/behavior/order.md` ＋ `spec/backlog-map.md`（E3 注文）
- **round**: 01
- **日付**: 2026-08-10
- **レビュアー方針**: 追認しない。spec の各記述を legacy コード（Struts 稼働構成）と突き合わせ、誤読・思い込み・不正確な参照を file:line 付きで反証する。誤りが無ければ「無し」と書く。

---

## 検証して正確だった主な記述（＝反証できなかった点）

濫造回避のため、精査対象のうち **コードと一致していた** 記述を先に列挙する（ここは指摘ではない）。

- `Order.initOrder` の既定値：`totalPrice=cart.getSubTotal()`（`Order.java:148`）、支払ダミー `999 9999 9999 9999` / `12/03` / `Visa`（`Order.java:150-152`）、`courier=UPS` / `locale=CA` / `status="P"`（`Order.java:153-155`）、username=アカウント・orderDate=now・ship/bill=アカウント住所（`Order.java:127-146`）、明細はカート各行を展開（`Order.java:157-161`）。**すべて正確。**
- `NewOrderAction` の3分岐（shippingAddressRequired→shipping / !confirmed→confirm / order!=null→insert / else→failure）は `NewOrderAction.java:16-34` と**分岐順序も含めて一致**。forward 先も struts-config（`shipping/confirm/success`=`struts-config.xml:57-59`）と一致。
- `NewOrderFormAction` が **DB からアカウント再取得**して initOrder する点は `NewOrderFormAction.java:20-21` と一致。
- `OrderActionForm.doValidate`：別住所配送でない場合のみカード/配送/請求先を必須チェック（`OrderActionForm.java:59-79`）、エラー時に請求先を配送先で補完（`OrderActionForm.java:81-90`）。**正確。**
- `PetStoreImpl.insertOrder` = `orderDao.insertOrder` ＋ `itemDao.updateQuantity`（在庫減算）（`PetStoreImpl.java:147-150`）。`getOrder` に認可なし（`PetStoreImpl.java:152-154`）。**正確**（トランザクション注釈の粒度のみ後述の指摘）。
- `orderId` は sequence 採番（`SqlMapOrderDao.java:33` `getNextId("ordernum")`）。**正確。**
- `getOrder` は `orders`×`orderstatus` を orderid で結合し status を1件取得（`Order.xml:35-44`）。**正確。**
- データモデル（orders/lineitem/orderstatus/sequence の PK・列）は `jpetstore-hsqldb-schema.sql:69-166` と一致。`orders` に `status` 列が無く status は orderstatus 由来、という含意も正しい。
- 在庫減算が実際に減算であること（`Item.xml:72-74` `qty = qty - #increment#`）。**正確。**

以下、コードと食い違う／不正確な記述を指摘する。

---

## 指摘リスト

### [中] 認可・identity の出所 ｜ 「セッションのユーザー名」という記述が実際の読み取り元（リクエストで再populateされる session-scoped ActionForm）と食い違い、spec 内部でも矛盾

- **spec の記述**:
  - 2.2「`/shop/listOrders` → **セッションのユーザー名**で `getOrdersByUsername(username)`」
  - 2.3「所有者チェック（**`session.account.username`** == order.username）」
- **実際**: どちらの Action も username/所有者を **`form`（＝そのマッピングの ActionForm）から読む**：
  - `ListOrdersAction.java:13-14` … `AccountActionForm acctForm = (AccountActionForm) form; String username = acctForm.getAccount().getUsername();`
  - `ViewOrderAction.java:15,18` … `AccountActionForm acctForm = (AccountActionForm) form;` → `acctForm.getAccount().getUsername().equals(order.getUsername())`
  - この `form` は struts-config で `name="accountForm" scope="session"`（`struts-config.xml:43-44`, `97-98`）。**session-scoped だが、Struts の RequestProcessor は Action 実行前に毎リクエスト当該フォームを request パラメータで populate する**（両マッピングは `validate="false"` だが、populate は validate と無関係に走る）。よって `account.username` は同一リクエストの `account.username=...` パラメータで **上書き可能** = これが before の S3 identity-rebind IDOR そのもの。
- **なぜ問題か**: 2.2/2.3 は identity を「信頼できるセッション状態」として描いているが、実体は「リクエストで再束縛され得る session-scoped ActionForm」。しかも **同じ spec の 5 章 S3 行は正しく「所有者判定の元がフォーム束縛可能な `accountForm.account.username`」と書いており、2.2/2.3 と矛盾**している。as-is 挙動の記述としてここは不正確。
- **証拠**: `ListOrdersAction.java:13-14` / `ViewOrderAction.java:15,18` / `struts-config.xml:43-44,97-98`（対比: `spec/behavior/order.md` 2.2・2.3 と 5章 S3 行）
- **修正提案**: 2.2/2.3 の「セッションのユーザー名」「session.account.username」を、**「`accountForm`（session スコープだがリクエストで再 populate される ActionForm）の `account.username`」** と正確化し、5章 S3 と表現を一致させる。「信頼された identity ではない」ことを as-is 挙動の側にも明記する。

### [中] 認証境界 ｜ 「未認証は全操作でサインオン画面へ誘導＝SecureBaseAction」は注文ドメイン内でも成り立たない（checkout/カート表示は公開）

- **spec の記述**: 1章「前提はサインオン済み（**未認証は全操作でサインオン画面へ誘導**＝`SecureBaseAction`）」。2.1 step1 は `/shop/checkout`（`ViewCartAction`）を注文フローの起点として列挙。
- **実際**: `ViewCartAction` は **`BaseAction` を継承（`ViewCartAction.java:10`）で `SecureBaseAction` ではない** → 未認証でも到達する。`/shop/checkout`→`Checkout.jsp`（`struts-config.xml:27-30`）も同様に無認証で表示可能。サインオン誘導が効くのは `NewOrderFormAction`/`NewOrderAction`/`ListOrdersAction`/`ViewOrderAction`（いずれも `SecureBaseAction` 継承、gate は `SecureBaseAction.java:12-28`）のみ。
- **なぜ問題か**: 本 spec が列挙する注文フロー 5 アクションのうち 1 つ（checkout=ViewCartAction）が「全操作サインオン」に該当しない。THREAT_MODEL 上「カート操作の公開は設計どおり」なので**脆弱性ではない**が、**as-is の認証境界の記述としては不正確**で、リビルドの認可設計（どのエンドポイントを認証必須にするか）を誤らせ得る。
- **証拠**: `ViewCartAction.java:10`（`extends BaseAction`）/ `struts-config.xml:27-30` / `SecureBaseAction.java:12-28`
- **修正提案**: 1章を「注文確定（newOrderForm/newOrder）と注文履歴/詳細（listOrders/viewOrder）はサインオン必須（`SecureBaseAction`）。**カート/チェックアウト表示（ViewCartAction）は未認証でも到達（設計どおり公開）**」と限定して記述する。

### [低] データ精度 ｜ 明細の unitPrice は「カート単価」ではなく Item のマスター価格（listPrice）を initOrder 時点で取り込む

- **spec の記述**: 3章「明細=カート各行を `LineItem`(linenum, itemId, quantity, **unitPrice=カート単価**) に展開」。
- **実際**: `LineItem(int, CartItem)` は `unitPrice = cartItem.getItem().getListPrice()` を設定（`LineItem.java:25`）。「カート単価」という独立概念は無く、単価は**その時点の Item.listPrice（マスター価格）**。
- **なぜ問題か**: 5章の secure 要件「単価はサーバがマスター価格から再計算」と対で読むと、**as-is でも initOrder 時点の単価は既にサーバ側マスター価格**であり、S4 の穴は「initOrder 後にフォームが `lineItems[].unitPrice` を上書きできる（永続化時に再計算しない）」点にある、という因果が正確になる。
- **証拠**: `LineItem.java:21-27`（unitPrice=`LineItem.java:25`）
- **修正提案**: 「unitPrice=**Item のマスター価格 listPrice（initOrder 時点で取得）**」と書き換え、S4 の穴は「その後フォームで上書き可能・確定時に再計算しない」ことである、と因果を明示。

### [低] データ精度 ｜ orderstatus の 1 行は linenum に「行番号」ではなく orderId を、timestamp に orderDate を入れる（1注文=1行）

- **spec の記述**: 3章「`orderstatus` に (orderId, linenum, timestamp, status) を1件」／4章「`orderstatus`（orderid+linenum PK, timestamp, status）」。
- **実際**: `insertOrderStatus` の値は `values (#orderId#, #orderId#, #orderDate#, #status#)`（`Order.xml:71-73`）。つまり **linenum 列に orderId を格納**（実際の明細行番号ではない）、**timestamp 列に orderDate を格納**。明細が何行でも orderstatus は 1 行（`SqlMapOrderDao.java:35` で 1 回だけ insert）。
- **なぜ問題か**: 「(orderId, linenum, ...)」という並記は linenum を通常の行番号と誤読させる。リビルドがこの奇習（linenum=orderId）を忠実に写すと無意味な設計を継承する恐れ。
- **証拠**: `Order.xml:71-73` / `SqlMapOrderDao.java:35`
- **修正提案**: 「orderstatus は **1 注文につき 1 行**。linenum 列には（行番号ではなく）**orderId** を、timestamp 列には **orderDate** を格納する legacy 実装」と明記。リビルドでは status を注文単位で持つ設計に正規化する旨を補足。

### [低] トランザクション記述の粒度 ｜ `@Transactional` はメソッドではなくクラスレベル

- **spec の記述**: 3章「確定処理（`PetStoreImpl.insertOrder`, **`@Transactional`**）」。
- **実際**: `@Transactional` は **クラス `PetStoreImpl` に付与**（`PetStoreImpl.java:52`）で全 public メソッドに既定適用。`insertOrder` 個別注釈ではない。
- **なぜ問題か**: 原子性の主張（1トランザクション）自体は正しいが、注釈粒度を誤ると「メソッド固有の伝播/隔離設定がある」と読まれ得る。
- **証拠**: `PetStoreImpl.java:52`（class-level）, `147-150`（insertOrder 本体）
- **修正提案**: 「クラスレベル `@Transactional`（既定伝播）により insertOrder も 1 トランザクション」と正確化。

### [低] 在庫引当の意味 ｜ 「引き当て」に在庫充足チェック・在庫過少防止は無い（無条件減算）

- **spec の記述**: 1章「確定時に在庫を引き当てる」／3章「在庫引当＝減算」。
- **実際**: `updateInventoryQuantity` は `update inventory set qty = qty - #increment#`（`Item.xml:72-74`）で、**在庫充足の検証も負数ガードも無い**（`SqlMapItemDao.java:16-25` は各明細を無条件に減算）。`isItemInStock` は存在するが確定パスからは呼ばれない。
- **なぜ問題か**: 「引き当て（allocate/reserve）」は充足確認を含意しがちだが、as-is は**無条件減算で在庫がマイナスになり得る**。リビルド F3.2 が overselling 防止を要件化するかの判断に直結する as-is 事実。
- **証拠**: `Item.xml:72-74` / `SqlMapItemDao.java:16-26`（充足チェック無し）
- **修正提案**: 3章に「as-is は在庫充足チェック無しの無条件減算（負数許容）」と注記。overselling 防止の要否を PO 論点に追加（現状の論点リストに無い）。

### [低] 記述の裏付け（S4 の束縛対象）｜ `order.totalPrice` / `lineItems[].unitPrice` / `order.username` は JSP に描画されず、Struts の自動 populate で束縛される

- **spec の記述**: 5章 S4/R4 行「**フォームが** `order.totalPrice` / `lineItems[].unitPrice` / `order.username` を束縛」。
- **実際**: `NewOrderForm.jsp` が描画するのは `order.cardType/creditCard/expiryDate` と `order.bill*`、`shippingAddressRequired` のみ（`NewOrderForm.jsp:11-51`）。`totalPrice` / `username` / `lineItems[].unitPrice` の入力欄は**無い**。これらは **Struts の `RequestUtils.populate`→BeanUtils が session-scoped `workingOrderForm.order` に対し、任意の一致パラメータを注入束縛できる**ことで成立する（描画欄の有無と無関係）。
- **なぜ問題か**: 記述自体は真（束縛可能）だが、「フォームが束縛」だけだと「JSP にそれらの hidden 欄がある」と誤読され得る。**攻撃はパラメータ注入**である点を明示した方が正確で、リビルドの対策（allowlist バインド）の根拠も明確になる。
- **証拠**: `NewOrderForm.jsp:11-51`（描画欄）/ 対比: OrderActionForm の session 保持 order（`OrderActionForm.java:20,36,47-48`）
- **修正提案**: S4 行を「JSP に描画されない `order.totalPrice`/`order.username`/`lineItems[].unitPrice` も、**Struts 自動 populate で注入パラメータから束縛される**」と補足。

### [低] as-is 挙動の欠落 ｜ 注文確定（最終 submit）は GET リクエスト

- **spec の記述**: 2.1 は確定ウィザードを記すが、確定 submit の HTTP メソッドに言及なし。5章 S5 は「注文確定＝状態変更に CSRF 対策なし」とする。
- **実際**: 最終確定は `ConfirmOrder.jsp:76` の `<a href="/shop/newOrder.do?confirmed=true">`＝**GET リンク**で `insertOrder` に到達する（初回 newOrder は POST=`NewOrderForm.jsp:4`、確定のみ GET）。
- **なぜ問題か**: 状態変更が GET で起きる事実は S5（CSRF）の深刻度を上げ（GET はリンク/プリフェッチで駆動可）、リビルドの「確定は非冪等 POST + CSRF トークン」要件の直接的根拠になる。as-is 記述として押さえておく価値がある。
- **証拠**: `ConfirmOrder.jsp:76`（GET 確定リンク）/ `NewOrderForm.jsp:4`（初回 POST）
- **修正提案**: 2.1 step3 に「確定 submit は GET（`newOrder.do?confirmed=true`）」と注記し、S5 行で「状態変更が GET で成立」を明示。

### [低] 4章の網羅性 ｜ getOrder は join だけでなく明細を別クエリで取得する

- **spec の記述**: 4章「※ `getOrder` は `orders`×`orderstatus` を orderid で結合（status を1件取得）」。
- **実際**: `SqlMapOrderDao.getOrder` は上記 join に加え、**明細を別クエリ `getLineItemsByOrderId` で取得して order にセット**する（`SqlMapOrderDao.java:23-30`、明細取得=`27`）。
- **なぜ問題か**: 4章は getOrder のデータ取得形を説明する注記なのに明細取得を落としている。誤りというより網羅漏れ。
- **証拠**: `SqlMapOrderDao.java:23-30`（明細取得=`27`）/ `LineItem.xml:14-16`
- **修正提案**: 「status は join で 1 件、**明細は別途 `getLineItemsByOrderId` で取得**」と補足。

---

## 総評

- **指摘 9 件（中 2 / 低 7）。高（重大な誤読・存在しない挙動の記述）は無し。** order.md の中核（initOrder 既定値、確定ウィザードの分岐、insertOrder の在庫減算・sequence 採番、getOrder の join、データモデル）は**コードと高精度で一致**しており、忠実性は総じて良好。
- 一方で **認可・identity の出所（指摘1）** が最重要。as-is 挙動セクション（2.2/2.3）が identity を「セッションの信頼値」と描く一方、同 spec の 5 章 S3 は「フォーム束縛可能値」と正しく書いており、**spec 内部で矛盾**している。実体は「session スコープだがリクエストで再 populate される ActionForm」であり、これは before の看板脆弱性（S3 identity-rebind IDOR）の核。リビルド spec が「何を信頼して認可するか」を正しく設計するため、ここは表現統一（＝as-is 側も「信頼できない form 由来」と明記）が必須。
- **認証境界（指摘2）** も要修正。「全操作サインオン」は checkout/カート表示（`ViewCartAction=BaseAction`）に当てはまらず、注文ドメイン内でも不正確。脆弱性ではない（公開は設計どおり）が、認可設計への波及があるため中とした。
- 残りの低指摘（unitPrice の出所・orderstatus の linenum=orderId・@Transactional 粒度・無条件在庫減算・S4 の populate 経路・確定 GET・getOrder 明細取得）は、いずれも「誤りではないが不正確／因果や網羅が甘い」もの。特に **無条件在庫減算（指摘6）と確定 GET（指摘8）** は as-is 事実として PO 論点・リビルド NFR に直結するので取り込みを推奨。
- backlog-map（E3）は order.md の要約として整合しており、Feature 分解（F3.1–F3.6）に忠実性上の誤りは検出できなかった（「無し」）。ただし F3.2 の在庫引当に **overselling 防止の要否** を PO 論点として追加すべき（現状の補足論点に無い）。
