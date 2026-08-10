# spec 敵対的レビュー — レンズ: コード忠実性 (fidelity) / E1・E2・E4・E5 / round 01

- **対象**: `spec/behavior/{catalog,cart,account,auth}.md` ＋ `spec/backlog-map.md`（E1/E2/E4/E5 節）
- **round**: 01
- **日付**: 2026-08-10
- **方針**: 各 spec 冒頭「参照 legacy」のコードを一次情報として突き合わせ、記述がコード挙動と一致するかを検証。誤読・存在しない挙動・不正確な file 参照を file:line で反証。誤りが無ければ「無し」と正直に書く。濫造しない。

> **総括先出し**: 4 ドメインとも忠実性は**高い**。**高・中severity の誤り（存在しない挙動の記述・誤読・誤った file 参照）は 0 件**。検出は完全性/精度の [低] のみ（catalog 2・cart 1・account 1・auth 0）。order 見本の水準に達している。

---

## E1 カタログ（catalog.md）

### 検証して正確だった主な記述
- §1 全アクション未認証＝`BaseAction`：`ViewCategoryAction.java:13` / `ViewProductAction.java:13` / `ViewItemAction.java:13` / `SearchProductsAction.java:13` すべて `extends BaseAction`。✅
- §2 各フロー（categoryId→getCategory＋getProductListByCategory・4件/頁・session 保持／productId→getItemListByProduct＋getProduct／itemId→getItem→`item.getProduct()` 表示）：`ViewCategoryAction.java:16-24` / `ViewProductAction.java:16-24` / `ViewItemAction.java:15-18` と一致。✅
- §2 検索：空 keyword→「Please enter a keyword…」（`SearchProductsAction.java:18-20`）、keyword 無し＋session 切れ→「Your session has timed out…」（`:30-34`）、`searchProductList(keyword.toLowerCase())`（`:22`）。✅
- §3 「語に分割し各語 LIKE で OR」：`SqlMapProductDao.java:30-44`（`StringTokenizer` で空白分割＋`"%"+token+"%"`）＋`Product.xml:26-33`（`<iterate ... conjunction="OR">` で name/category/descn を LIKE）。✅
- §3/§5 SQL パラメタライズ（SQLi なし）：`Product.xml`(`#value#`/`#keywordList[]#`)・`Category.xml:17-23`(`#value#`)・`Item.xml`(`#value#`)。`$…$` 連結は無し。✅
- §5 SBD-10 viewItem の NPE：不正 itemId→`getItem` が null（`SqlMapItemDao.java:37-43`）→`ViewItemAction.java:18` の `item.getProduct()` で NPE。✅
- §4 データモデル（category/product/item/inventory）：schema と一致。✅

### 指摘

**[低] 完全性 ｜ SBD-10 の as-is trace 露出経路が viewItem のみで、viewCategory / viewProduct のページング経路が漏れている**
- **spec**: §5 SBD-10 as-is 列は「`viewItem` で不正 `itemId` → NPE→trace 露出」のみ列挙。
- **実際**: 同種の未捕捉例外がカタログに**あと2箇所**ある。
  - `ViewCategoryAction.java:29-31`：categoryId 無し（ページング）で session が切れていると **`throw new IllegalStateException("Cannot find pre-loaded category and product list")`** → 500/trace。
  - `ViewProductAction.java:27-31`：同経路で **null チェックが無く** `itemList.nextPage()`（`:31`）で **NPE** → 500/trace。
  - 対照的に `SearchProductsAction.java:31-34` は同状況を「Your session has timed out…」で**graceful に**処理しており、3アクションで挙動が非対称。
- **なぜ問題か**: 「as-is の穴」を列挙する表なのに info-disclosure 経路を過少列挙。SBD-10 の横断要件（不正入力→4xx 正規化・trace 非露出）でリビルドはどのみち塞がるが、回帰テストの網羅（どの as-is 経路が消えたか）を漏らす。
- **証拠**: `ViewCategoryAction.java:29-31` / `ViewProductAction.java:27-31`（対照 `SearchProductsAction.java:31-34`）
- **修正提案**: SBD-10 as-is に「viewCategory=IllegalStateException / viewProduct=NPE / viewItem=NPE（session 切れページング・不正 ID）」と3経路を明記。

**[低] 精度 ｜ 格納XSS seam の対象フィールドを特定していない（実体は `product.description`）**
- **spec**: §5 L1「`Item.jsp`/`SearchProducts.jsp` に `escapeXml="false"` 出力（…Latent）」。after 列は「商品名/説明/検索語エコーを含む」。
- **実際**: `escapeXml="false"` が付くのは **`product.description` のみ**（`Item.jsp:16` / `SearchProducts.jsp:14`）。商品**名**や検索語エコーには付いていない（該当出力は escape 既定）。加えて **`IncludeBanner.jsp:7` の `accountForm.account.bannerName`** にも `escapeXml="false"` があるが、これは account/profile 経路（カタログ scope 外）。
- **なぜ問題か**: as-is の Latent seam は「product.description」に限局。after 要件（全部エスケープ）は belt-and-suspenders として妥当だが、as-is 記述としては対象を特定した方が正確でリビルドの検証点が明確。
- **証拠**: `Item.jsp:16` / `SearchProducts.jsp:14`（＋scope外 `IncludeBanner.jsp:7`）
- **修正提案**: as-is 列を「seam は `product.description`（DB シード由来・書込経路なし＝Latent）」と限定。商品名/検索語エコーは after の予防的エスケープ対象として区別。

---

## E2 カート（cart.md）

### 検証して正確だった主な記述
- §1 全アクション `BaseAction`・カートは session（`CartActionForm` scope=session）・DB 永続なし：`Add/Update/RemoveItemFromCartAction.java:*` 各 `extends BaseAction`、`struts-config.xml:23-24,65-68,81-84` scope=session、`CartActionForm.java:13`。✅
- §2 追加：既存→数量+1／新規→`isItemInStock`＋`getItem`→`addItem(item,isInStock)`（数量1）：`AddItemToCartAction.java:18-29`。✅
- §2 数量更新：**パラメータ名＝itemId** で数量取得→`setQuantityByItemId`、`<1` は行削除、`NumberFormatException` 握りつぶし：`UpdateCartQuantitiesAction.java:18-32`。✅ 精密に一致。
- §2 削除：`removeItemById(workingItemId)`：`RemoveItemFromCartAction.java:14`。✅
- §3 小計サーバ計算・価格はマスター・クライアントは数量のみ：`Cart.java:70-81`（`getSubTotal`）＋カート系 Action に価格パラメータ無し。✅
- §3 `isInStock` は追加時評価・保持のみ・充足強制なし：`AddItemToCartAction.java:26-28`（在庫外でも add をブロックしない）。✅
- §3 未ログインで作成可・ログイン後も同一セッションのカート引継ぎ：`SignonAction.java:16-17` は `accountForm`/`workingAccountForm` のみ除去し **`cartForm` は残す**。✅

### 指摘

**[低] 完全性 ｜ 「数量0で削除」経路の itemMap デシンク（削除2経路の非対称）**
- **spec**: §2「数量 `<1` は行削除」、§6「追加・数量更新（0で削除）・削除」。
- **実際**: 削除2経路の実装が異なる。
  - `removeItemFromCart` → `Cart.removeItemById`（`Cart.java:49-58`）は **itemMap と itemList の両方**から除去（クリーン）。
  - `updateCartQuantities` の 0/負数削除は **`Iterator.remove()`**（`UpdateCartQuantitiesAction.java:26`）で、`Cart.getAllCartItems()`＝`itemList.getSource().iterator()`（`Cart.java:25`）**の itemList からしか消えず itemMap に残る**（デシンク）。以後 `containsItemId` は true を返し、同 itemId を再追加すると「消したはずの行」が increment される legacy バグ。
- **なぜ問題か**: 観測挙動（表示上は行が消える）は「行削除」と一致するので spec は誤りではないが、**as-is の隠れ不整合**を記述していない。リビルド（明示 `{itemId, quantity}` REST・0で削除）は**この desync を踏襲しない**設計にすべき、という含意を明示できる。
- **証拠**: `UpdateCartQuantitiesAction.java:26`（iterator.remove）｜対照 `Cart.java:49-58`（removeItemById）・`Cart.java:15,25`（itemMap と itemList の二重管理）
- **修正提案**: §2 or §6 に「as-is は update 経由の 0 削除で itemMap が残るデシンク有り。リビルドは単一の削除意味論に正規化」と注記。

> それ以外に cart.md のコード忠実性の誤りは **無し**（4ドメイン中もっとも高精度）。

---

## E4 アカウント（account.md）

### 検証して正確だった主な記述
- §1/§2 公開＝newAccount/newAccountForm（`NewAccountAction.java:13` `BaseAction`）、要サインオン＝editAccount/editAccountForm（`EditAccountAction.java:13` `SecureBaseAction`）。✅
- §2/§3 3表 insert：`SqlMapAccountDao.java:39-43`（insertAccount→insertProfile→insertSignon）。3表 update：`:45-51`（updateAccount＋updateProfile＋条件付き updateSignon）。✅
- §2/§3 listOption/bannerOption は**パラメータ有無**で真偽化：`NewAccountAction.java:18-19` / `EditAccountAction.java:18-19`。✅
- §5 S2：`account.username` フォーム束縛＋`update account … where userid=#username#`（`Account.xml:83-85`）＋`update signon … where username=#username#`（`Account.xml:99-101`）で他人更新。EditAccountAction は編集対象と session 本人の一致を**検証していない**（`EditAccountAction.java:16-22`）。✅
- §5 補足：newAccount で他人 username→`account` PK 衝突で insert 失敗（`Account.xml:87-89` へ最初に insert＝`SqlMapAccountDao.java:40`）＝上書き不可。✅
- §2 登録後自動ログイン（session `accountForm` セット）：`NewAccountAction.java:23-27`。✅
- §3/§4 平文（signon.password varchar(25)）・全 SQL パラメタライズ。✅

### 指摘

**[低] 精度 ｜ editAccount の signon(password) 更新は「無条件」ではなく password 入力時のみ（PWリセットの条件）**
- **spec**: §2「updateAccount(account)（account＋profile＋**signon(password)** を update）」、§5 S2「…＋`updateSignon(password)` により他人アカウントを更新＋**PWリセット**」。
- **実際**: `SqlMapAccountDao.updateAccount` は account/profile を**常に** update するが、**signon(password) は `account.getPassword()` が非空のときのみ** update（`SqlMapAccountDao.java:48-50`）。つまり S2 での「PWリセット」は攻撃者が新 password を送った場合に成立し、送らなければ既存 PW は保持される。
- **なぜ問題か**: 乗っ取りシナリオ（攻撃者が新 PW を注入）自体は正しいが、「signon を（常に）update」と読めると不正確。リビルドの allowlist/再認証 AC を作る際に条件分岐を取りこぼす恐れ。
- **証拠**: `SqlMapAccountDao.java:48-50`（`if (password != null && length>0) updateSignon`）
- **修正提案**: §2/§5 に「signon(password) の更新は **password 入力時のみ**（空なら据え置き）」と条件を明記。

> S2/S3/S6/S7/S12・PK 衝突・3表構成・listOption 設定など、その他のコード忠実性の誤りは **無し**。

---

## E5 認証（auth.md）

### 検証して正確だった主な記述
- §2 サインオン：まず `workingAccountForm`/`accountForm` 除去（`SignonAction.java:16-17`）、`signoff` 有り→`session.invalidate()`（`:18-21`）、無し→`getAccount(username,password)`→null で「Invalid username or password.  Signon failed.」（`:26-29`）。✅
- §2 成功時：新 `AccountActionForm` 生成・`setAccount`・**`account.setPassword(null)`**（`:33-36`）、`accountForm` を session へ（`:40`）。✅
- §2/§5 S8 セッション固定：成功時に **`request.getSession()` の再生成/invalidate をしない**（invalidate は signoff 経路のみ＝`:19`）。✅
- §2/§5 S9 オープンリダイレクト：`forwardAction` 空→index、非空→`response.sendRedirect(forwardAction)`（`:41-47`）＝**認証成功時のみ発火**・無検証。✅
- §3 認証＝平文比較：`Account.xml:52-77`（`account.userid=#username# and signon.password=#password#`）＝パラメタライズだが平文照合。✅
- §3 サインオフは `signon.do?signoff=...`（専用 Action 無し）：`SignonAction.java:18-21`。✅
- §3/§5 j2ee/j2ee プリフィル：`SignonForm.jsp:20,24`（`value="j2ee"`）。✅
- §5 S11 GET でも資格情報受理（`getParameter`＝メソッド非依存）／失敗一律メッセージ＝列挙不可（null は username 不在・PW 不一致の双方）。✅
- §4 認証は signon×account×profile×bannerdata 結合（`Account.xml:71-77`）。✅

### 指摘
**無し。** auth.md はコード忠実性の誤り・誤読・不正確 file 参照ともに検出されず。
（ごく些細: §2 の引用「Invalid username or password. Signon failed.」は実際には "password." の後が**半角スペース2つ**〔`SignonAction.java:28`〕。転記の空白差のみで指摘化しない。）

---

## backlog-map（E1/E2/E4/E5 節）

- F1.1–F1.3 / F2.1–F2.3 / F4.1–F4.3 / F5.1–F5.4 の Feature 分解は各 behavior spec の as-is と整合。**コード忠実性上の誤りは検出されず（無し）**。
- F4.2 否定AC「`account.username=他人` で editAccount → 他人は更新されない」は S2 の是正として妥当（as-is で `EditAccountAction.java:16-22` に本人一致チェックが無いことと対応）。✅
- F5.2 否定AC「DB に平文パスワードが存在しない」/ F5.3「GET 認証廃止・リダイレクト検証」も as-is（平文・GET 受理・無検証 sendRedirect）と正しく対応。✅

---

## ドメイン別 残指摘件数 と 収束見込み

| ドメイン | 残指摘 | 重大度 | 収束見込み |
| --- | --- | --- | --- |
| E1 カタログ | 2 | 低×2（完全性1・精度1） | round 02 で即収束（in-place 追記で足りる） |
| E2 カート | 1 | 低×1（完全性） | round 02 で即収束 |
| E4 アカウント | 1 | 低×1（精度） | round 02 で即収束 |
| E5 認証 | 0（無し） | — | **既に収束**（追加ラウンド不要） |

**総評**: 4ドメイン計 **残指摘 4 件（すべて [低]）／高・中 は 0**。いずれも「as-is の穴/挙動の取りこぼし・条件の明記漏れ」で、**behavior spec 本体の記述に誤り（存在しない挙動・誤った file:line）は無い**。最も実務価値があるのは E1 の trace 露出3経路の明記と E2 の itemMap デシンク注記（＝リビルドの error-handling / 削除意味論の設計に効く）。全件 in-place 修正で対応可能で、**次ラウンドを回すまでもなく round 02 反映＝収束と見込む**。
