# 挙動 spec — カタログドメイン（Catalog）

> Phase 2 spec ドラフト（round01 未レビュー）。`legacy-jpetstore`（Struts 稼働構成）as-is。横断NFR: [`security-baseline.md`](../security-baseline.md)。
> 参照 legacy: `web/struts/{ViewCategoryAction, ViewProductAction, ViewItemAction, SearchProductsAction}.java` / `domain/{Category, Product, Item}.java` / `domain/logic/PetStoreImpl.java` / `dao/ibatis/maps/{Category,Product,Item}.xml` / `jsp/struts/{index,Category,Product,Item,SearchProducts}.jsp` / `db/hsqldb`（category, product, item, inventory）

## 1. 概要・認証境界

商品カタログの階層閲覧（カテゴリ→商品→在庫アイテム）と検索。**全アクション未認証で到達（公開が正常）**＝いずれも `BaseAction`（`SecureBaseAction` ではない）。読み取り専用（DB 更新なし）。

## 2. as-is 挙動

- **カテゴリ閲覧** `/shop/viewCategory`（`ViewCategoryAction`）：`categoryId` → `getCategory` ＋ `getProductListByCategory`（Spring `PagedListHolder`・4件/頁、session 保持）→ `Category.jsp`。`categoryId` 無し（頁送り）はセッション保持リストで `page=next/previous`。
- **商品閲覧** `/shop/viewProduct`（`ViewProductAction`）：`productId` → `getItemListByProduct`（4件/頁）＋ `getProduct` → `Product.jsp`。頁送り同上。
- **アイテム閲覧** `/shop/viewItem`（`ViewItemAction`）：`itemId` → `getItem(itemId)` → `Item.jsp`（`item.getProduct()` も表示）。在庫状況を表示。
- **検索** `/shop/searchProducts`（`SearchProductsAction`）：`keyword` → `searchProductList(keyword.toLowerCase())`（4件/頁、session 保持）→ `SearchProducts.jsp`。空 keyword → 「Please enter a keyword…」／`keyword` 無し（頁送り）でセッション切れ → 「Your session has timed out…」。
- ⚠ **stale-session ページング挙動が3アクションで不統一**：`viewCategory`＝`IllegalStateException`（未捕捉→500/trace, `ViewCategoryAction.java:29-31`）／`viewProduct`＝null ガード無し `itemList.nextPage()` で **NPE**（500, `ViewProductAction.java:27-34`）／`search` のみ graceful に「Your session has timed out…」。after は一律 404/空リストへ正規化（SBD-10）。

## 3. 業務ルール

- 検索は keyword を**語に分割し各語を LIKE で OR 検索**（name/category/descn）。SQL は全て**パラメタライズ**（`#value#` / `#keywordList[]#`、`Product.xml` / `Category.xml` / `Item.xml`）＝**SQLi なし**。
- 一覧はサーバ側ページング（`PagedListHolder`・4件/頁）、状態を**セッション保持**（頁送りはセッション依存）。
- アイテムの在庫状況（`isItemInStock` / `inventory.qty`）は表示用の「リアルタイム」プロパティ。
- 価格・商品情報は DB シード由来（マスターデータ）。

## 4. データモデル（as-is・参照のみ）

`category`（catid PK, name, descn）／`product`（productid PK, category FK, name, descn）／`item`（itemid PK, productid FK, listprice, unitcost, …）／`inventory`（itemid PK, qty＝在庫表示に参照）。カタログは**読み取りのみ**（更新は注文確定の在庫減算＝E3）。

## 5. secure-by-default 要件

> カタログは before で **clean**（SQLi 無・稼働 JSP に反射 XSS 無）。ここは「**維持**」が主。

| before | as-is | after（secure-by-default） |
| --- | --- | --- |
| **clean 維持（SQLi）** | 全 SQL パラメタライズ | **SBD-17**：パラメタライズ維持（検索も）。 |
| **L1 格納XSS の seam / SBD-18** | **`product.description` が表示用 HTML を内包**（シードに `<image src=...>` 等）し `escapeXml="false"` で描画（`Item.jsp:16` / `SearchProducts.jsp:14`。DB シード由来・書込経路なし＝Latent）。検索語の**反射は無い**（clean）。※`bannerName` も同型だが account scope（→account.md） | **description は HTML を継承せず plaintext 化**（全エスケープ）。商品画像は**新規生成（nano banana）で別アセット**として持つ（レガシーの `<image>` 埋め込みは廃止）＝意図的な非等価変更。全動的出力はエスケープ（**SBD-18**）。 |
| **SBD-10 情報漏えい** | 不正/欠落入力で trace 露出が**3経路**：`viewItem`（不正 itemId→`getItem` null→`item.getProduct()` NPE）／`viewCategory`（stale-session→IllegalStateException）／`viewProduct`（stale-session→NPE） | 不正 ID・stale は 404/空へ正規化・スタックトレース非露出。 |

## 6. スコープ（Factory 方針）

- **挙動等価で残す**：カテゴリ→商品→アイテムの階層閲覧・検索・ページング。
- **変える（モダン化）**：JSP → Vue3 SPA＋REST（一覧/検索 API）。iBATIS→MyBatis、HSQLDB→MySQL。セッション保持ページング → API のページングパラメータに。出力エスケープはフレームワーク既定で担保。**UI は Claude Design で新規デザイン、商品画像は nano banana で新規生成**（レガシーの JSP/埋め込み画像は継承しない）。
- **意図的な非等価変更（承認済 2026-08-10）**：`product.description` は HTML を継承せず **plaintext＋新規画像アセット（nano banana 生成）** に置換（as-is は HTML 埋め込み）／stale-session エラーの 404 正規化。
- **決定（2026-08-10）**：**検索UX＝ヘッダ検索バー＋結果カードグリッド＋サーバページング**。複数語の部分一致（LIKE・OR）は維持、カテゴリフィルタは任意。
- **PO へ送る論点**：①ページサイズ(4)の踏襲要否 ②在庫状況の表示仕様。
