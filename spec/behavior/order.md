# 挙動 spec — 注文ドメイン（Checkout & Orders）【見本 / round01 敵対レビュー反映済】

> Phase 2 spec ドラフトの**見本**。`legacy-jpetstore`（Struts 稼働構成）を読み解いた as-is 挙動 ＋ 業務ルール ＋ データ ＋ secure-by-default 要件。
> リビルド（`jpetstore-backend`/`frontend`）の入力。**Feature までが本書＋backlog-map、Story/AC は PO が Project #2 に。** 横断NFRは [`security-baseline.md`](../security-baseline.md)。
> round01 の 3レンズ敵対レビュー（`spec/review/*_01.md`）を反映済み。
> 参照 legacy（file 基準）: `web/struts/{ViewCartAction, NewOrderFormAction, NewOrderAction, OrderActionForm, ListOrdersAction, ViewOrderAction, SecureBaseAction, BaseAction}.java` / `domain/{Order, LineItem, Cart, CartItem, Account}.java` / `domain/logic/PetStoreImpl.java` / `dao/ibatis/{SqlMapOrderDao, SqlMapItemDao, SqlMapSequenceDao}.java` + `maps/{Order,LineItem,Item,Sequence}.xml` / `jsp/struts/{Cart,Checkout,NewOrderForm,ShippingForm,ConfirmOrder,ViewOrder,ListOrders}.jsp` / `db/hsqldb`（orders, lineitem, orderstatus, inventory, sequence）

## 1. 概要・アクター・認証境界

認証済みユーザーが、カート内容から**注文を確定**し、**自分の注文履歴・詳細**を閲覧する。

- **サインオン必須**（`SecureBaseAction`）: `newOrderForm` / `newOrder` / `listOrders` / `viewOrder`。未認証はサインオン画面へ誘導（`SecureBaseAction.java:12-28`、遷移先 URL を `signonForwardAction` に退避）。
- **未認証でも到達（設計どおり公開）**: カート表示・**チェックアウト表示**（`ViewCartAction` は `BaseAction` 継承＝`ViewCartAction.java:10`）。THREAT_MODEL 上、カート/閲覧の公開は正常。

## 2. as-is 挙動（フロー）

### 2.1 チェックアウト・ウィザード（注文確定）
1. **カート → チェックアウト**：`/shop/checkout`（`ViewCartAction`）→ `Checkout.jsp`。※`checkout` は `viewCart` と**同一 Action**で、`page=next/previous`(MyList)・`nextCart/previousCart`(カート) の**ページング分岐**を引き継ぐ（`ViewCartAction.java:12-31`）。
2. **注文フォーム初期化**：`/shop/newOrderForm`（`NewOrderFormAction`, 要サインオン）→ **DB からアカウント再取得**し `Order.initOrder(account, cart)` で注文を組み立て → `NewOrderForm.jsp`（POST 遷移）。配送/請求先はアカウントでプリフィル・上書き可、合計はカート小計、支払は**ダミー既定**（§3）。「別住所へ配送」チェックあり。session に `cartForm` が無ければ「An order could not be created because a cart could not be found.」で failure（`NewOrderFormAction.java:24-27`）。
3. **確定ウィザード**：`/shop/newOrder`（`NewOrderAction`）が状態で分岐（`NewOrderAction.java:16-34`、分岐順も一致）：
   - `shippingAddressRequired`（別住所ON）→ `ShippingForm.jsp`
   - まだ `confirmed` でない → `ConfirmOrder.jsp`
   - `confirmed` かつ order あり → **`insertOrder(order)`** → session の `workingOrderForm`/`cartForm` 破棄 → `ViewOrder.jsp`「Thank you, your order has been submitted.」
   - order が null → failure
   - **⚠ 最終確定は GET リンク**：`ConfirmOrder.jsp:76` の `<a href="/shop/newOrder.do?confirmed=true">` ＝ **状態変更（insert＋在庫減算）が GET で成立**（初回 newOrder は POST）。
4. バリデーション（`OrderActionForm.doValidate`, `:57-90`）：別住所配送でない場合、カード番号（"FAKE (!) …" ＝**ダミー扱い**）/有効期限/種別、配送先・請求先の各必須項目。エラー時は請求先を配送先で補完。

### 2.2 注文履歴一覧
- `/shop/listOrders`（`ListOrdersAction`, 要サインオン）→ `getOrdersByUsername(username)` → `ListOrders.jsp`（**ヘッダのみ＝orderId/date/totalPrice。明細なし**、`SqlMapOrderDao.java:19-21` は明細を積まない）。
- ⚠ **認可元の落とし穴**：username は**セッションの信頼値ではなく、`(AccountActionForm) form` ＝ session スコープだが Struts が毎リクエスト request パラメータで再 populate する ActionForm** から取る（`ListOrdersAction.java:13-14`, `struts-config.xml:43-46`）。よって `listOrders.do?account.username=<victim>` で**他人の注文履歴を一括取得**でき、同時にセッションの identity が汚染される（＝before **S3 identity-rebind IDOR**。詳細だけでなく一覧も対象）。

### 2.3 注文詳細閲覧
- `/shop/viewOrder`（`ViewOrderAction`, 要サインオン）→ `orderId`（パラメータ）で `getOrder(orderId)` → **所有者チェック**後 `ViewOrder.jsp`、不一致は「You may only view your own orders.」（`ViewOrderAction.java:14-25`）。
- ⚠ **所有者チェックの比較元も 2.2 と同じ再 populate される `accountForm.account.username`**（`ViewOrderAction.java:15,18`）＝S3 対象。さらにこの Web 層チェックは **remoting 経路（`OrderService.getOrder`）には介在しない**（＝before **S15/R2**、`PetStoreImpl.getOrder:152-154` に認可なし）。
- エラーパス：`orderId` 非数値 → `Integer.parseInt` で NumberFormatException（`:16`）／存在しない orderId → `getOrder` が null → `order.getUsername()` で **NPE→スタックトレース露出**（`:17-18`、before S18 と連鎖）。
- ⚠ **履歴経由の詳細は明細の商品名/説明が空**：`getLineItemsByOrderId` は明細に `Item` を join せず（`LineItem.xml`）、履歴からの `viewOrder` では `ViewOrder.jsp` の商品名/説明列が空になる。**注文直後の Thank-you 画面のみ**は cart 由来のメモリ上 order で商品名が揃う（同じ `ViewOrder.jsp` でも入口で明細の中身が違う as-is 差）。

## 3. 業務ルール

- **注文生成**（`Order.initOrder`, `Order.java:126-162`）：`username`=アカウント、`orderDate`=now、配送/請求先=アカウント住所、`totalPrice`=**カート小計** `cart.getSubTotal()`、明細=カート各行を `LineItem` に展開。**明細の `unitPrice` は Item のマスター価格 `listPrice` を initOrder 時点で取り込む**（`LineItem.java:25`。"カート単価" という独立概念はない）。
- **支払は非実装**：カード既定値 `999 9999 9999 9999`/`12/03`/Visa をハードコード、`courier=UPS`/`locale=CA`/`status="P"`（Pending）（`Order.java:150-155`）。
- **確定処理**（`PetStoreImpl.insertOrder`, `:147-150`。`@Transactional` は**クラスレベル**＝`:52`）：`orderDao.insertOrder(order)` ＋ **`itemDao.updateQuantity(order)`** を1トランザクションで。
  - ⚠ **在庫は無条件減算**（`update inventory set qty = qty - #increment#`、`Item.xml:72-74`）。**充足チェックも負数ガードも無い**（`isItemInStock` は存在するが確定パスから呼ばれない）→ **過剰販売＝在庫マイナス可**。
  - `orderstatus` に **1行のみ** insert：`values (#orderId#, #orderId#, #orderDate#, #status#)`（`Order.xml:71-73`）＝**linenum 列に orderId、timestamp 列に orderDate**（行番号ではない）。
  - `orderId` は `sequence` テーブル採番だが **select→+1→update の非アトミック**（`SqlMapSequenceDao.java:16-26`）＝並行で重複採番リスク。
- **一覧/詳細のスコープ**：§2.2/§2.3 のとおり（認可元が再 populate される form で脆弱）。
- **取得形状**：`getOrder` は `orders`×`orderstatus` を orderid で inner join（status 1件）＋ **明細を別クエリ `getLineItemsByOrderId` で取得**（`SqlMapOrderDao.java:23-30`）。orderstatus 行が無い注文は join で**取得0件になる**。

## 4. データモデル（as-is）

- `orders`（orderid PK, userid, orderdate, ship*/bill* 住所, courier, totalprice, *toFirstName/LastName, creditcard, exprdate, cardtype, locale）※`status` 列は無い
- `lineitem`（orderid+linenum PK, itemid, quantity, unitprice `decimal(10,2)`）
- `orderstatus`（orderid+linenum PK, timestamp, status）※実際は注文ごと1行・linenum=orderId・timestamp=orderDate・status 常に "P"
- `inventory`（itemid PK, qty）← **注文確定が減算する**（注文4表以外で唯一変更するテーブル）
- `sequence`（name PK, nextid）＝orderId 採番
- ⚠ 金額は DB `decimal(10,2)` だがドメインは `double`（`Order.totalPrice`/`LineItem.unitPrice`）＝丸め誤差の余地。

## 5. secure-by-default 要件（before findings → after で"消す"）

> 横断NFR（CSRF・セッション再生成・認可の実施層・監査 等）は [`security-baseline.md`](../security-baseline.md) に集約。ここは注文ドメイン固有＋接続。
> **SBD 対応**: S3→SBD-1 / S15→SBD-1・SBD-7 / S4→SBD-2 / S5→SBD-3 / S8→SBD-4 / 列挙→SBD-8 / S2波及→SBD-2＋認証(E5) / 金額→SBD-13。

| before finding | as-is の穴 | after の secure-by-default 要件（検証可能なアサーション） |
| --- | --- | --- |
| **S3 identity-rebind IDOR（一覧・詳細の双方）** | 認可元が毎リクエスト再 populate される `accountForm.account.username`（`ListOrdersAction:13-14` / `ViewOrderAction:15,18`） | **本人性は認証プリンシパルから**取得（リクエストから populate しない）。`listOrders?account.username=他人` → 自分の履歴のみ／`viewOrder`(他人ID) → 403。**一覧にも適用**。 |
| **S15/R2 remoting getOrder IDOR** | `PetStoreImpl.getOrder` に認可なし。Web 層チェックが remoting に介在せず無認証で PII 総当り | **認可はサービス/ドメイン層で、呼び出しチャネル非依存に強制**（＝一般NFRへ格上げ、security-baseline）。**remoting/WS(OrderService.getOrder) は廃止し、認証必須＋所有者スコープの REST に**（F3.5）。 |
| **S4/R4 価格・名義のマスアサインメント** | JSP に描画されない `order.totalPrice` / `order.username` / `lineItems[].unitPrice` も **Struts 自動 populate で注入パラメータから束縛**され、確定時サーバ再計算なしで永続化 | **クライアント編集可は allowlist のみ**＝配送/請求先住所・別配送フラグ・支払プレースホルダ入力。**サーバ権威（クライアント値無視）**＝`username`(認証プリンシパル)・`unitPrice`(マスター価格)・`totalPrice`(サーバ再計算)・`itemId`/`linenum`/`orderDate`/`status`。数量は E2 カート工程の入力（注文確定では受理しない）。否定AC種: `order.totalPrice=0.01` → 永続値はサーバ再計算合計。 |
| **S5 CSRF / S8 セッション固定** | 確定＝状態変更に CSRF なし・GET で成立（`ConfirmOrder.jsp:76`）／ログインでセッション再生成なし | security-baseline の横断NFR（CSRFトークン必須・状態変更は非冪等POST・ログイン時 session id 再生成）を注文確定にも適用。 |
| **（新規NFR）列挙オラクル** | `orderId` が連番（sequence）＋ not-owned/not-found で弁別メッセージ | 外部識別子は**非連番/不透明（UUID等）**、**または** not-owned と not-found を**同一 403/404 に統一**して存在推測を封じる。 |
| **（情報）支払** | 実カード列を永続化・カード欄必須なのに実処理なし | **カード列を保持しない**（DTO/API/DB から除外）・入力欄と必須バリデーションも撤去・支払は明示的プレースホルダ（意図的な非等価変更）。 |

**クロスEpic依存**：本ドメインの認可は**認証プリンシパルの完全性**に依存する。before **S2（editAccount 乗っ取り）** でアカウント自体を奪われると order 側の認可強化だけでは防げない → E4(editAccount)・E5(認証) と `security-baseline.md` が前提。

## 6. スコープ（Factory 方針）

- **挙動等価で残す**：カート→チェックアウト→（配送先）→確認→確定、注文履歴一覧、注文詳細（所有者限定）。
- **捨てる**：remoting/WS 経由の `OrderService.getOrder`（S13-15、`OrderService` は getOrder のみ宣言）＝デモ層。JSP マルチステップ postback → **Vue3 SPA ウィザード＋REST**。
- **変える（モダン化）**：iBATIS→MyBatis、HSQLDB→MySQL/Flyway、サーバ側価格再計算・**サービス層認可**・**在庫充足チェック付き原子的引当**、金額は `BigDecimal`/`decimal`、orderId は DB 原子採番、支払プレースホルダ具体化。
- **意図的な非等価変更（要ユーザー最終承認）**：過剰販売防止（在庫充足チェック＝as-is は無検証減算）／支払カード撤去（F3.6）／金額 BigDecimal 化（SBD-13）。＝Factory 方針で"あえて挙動を変える"もの。
- **PO へ送る論点（判断待ち）**：①**注文確認メール**（`SendOrderConfirmationEmailAdvice`＝legacy 同梱・現状 config 無効：明示ドロップ or 将来Feature）、②`status` 遷移運用の有無（現状 "P" 固定・1行）、③courier/locale の扱い、④一覧のページング要否、⑤**注文詳細の商品名表示**（as-is は履歴経由で空。表示する＝非等価改善 or 等価維持）。
