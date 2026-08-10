# 挙動 spec — カートドメイン（Cart）

> Phase 2 spec ドラフト（round01 未レビュー）。`legacy-jpetstore`（Struts 稼働構成）as-is。横断NFR: [`security-baseline.md`](../security-baseline.md)。
> 参照 legacy: `web/struts/{AddItemToCartAction, RemoveItemFromCartAction, UpdateCartQuantitiesAction, ViewCartAction, CartActionForm}.java` / `domain/{Cart, CartItem, Item}.java` / `jsp/struts/Cart.jsp`

## 1. 概要・認証境界

買い物カートの構築（追加/更新/削除/表示）。**未認証で到達（公開が正常）**＝いずれも `BaseAction`。カートは**セッション内のみ**（`CartActionForm` は session スコープ・DB 永続なし）。確定（注文化）は E3 で、そこから認証必須になる。

## 2. as-is 挙動

- **追加** `/shop/addItemToCart`（`AddItemToCartAction`）：`workingItemId`（`CartActionForm`）→ 既にカートにあれば数量+1、無ければ `isItemInStock` 判定＋`getItem` して `cart.addItem(item, isInStock)`（数量1）→ `Cart.jsp`。※不正 `workingItemId` → `getItem` が null → `Cart.addItem` 内 `item.getItemId()` で **NPE**（`AddItemToCartAction.java:26-28`）。after は 404/検証で正規化（SBD-10）。
- **数量更新** `/shop/updateCartQuantities`（`UpdateCartQuantitiesAction`）：カート各行について**リクエストパラメータ名＝itemId**の値を数量として読む → `setQuantityByItemId`。数量 `< 1` は行削除。数値化できない値は無視（NumberFormatException を握りつぶす）。**⚠ as-is バグ**: この 0/負数削除は `iterator.remove()` で **`itemList` からのみ**除去し **`itemMap` に CartItem が残る**（`Cart.java:15,25,49-63`。`removeItemById` を通らない）→ `containsItemId` は true のまま＝同 itemId 再追加で"幽霊行"が increment される。after は map/list 一貫削除に正規化（踏襲しない）。
- **削除** `/shop/removeItemFromCart`（`RemoveItemFromCartAction`）：`workingItemId` を `cart.removeItemById`。
- **表示** `/shop/viewCart`（`ViewCartAction`）：カート/MyList の `page` ページング（E3 の `checkout` と同一 Action）。

## 3. 業務ルール

- カートは `itemMap`（itemId→CartItem）＋ `PagedListHolder`（4件/頁）で保持（`Cart.java`）。
- **小計はサーバ計算**：`getSubTotal = Σ(item.getListPrice() × quantity)`（`Cart.java:70-81`）。**価格はマスター（`Item.listPrice`）由来でクライアントは価格を送れない**。クライアント入力は**数量のみ**。
- `isInStock` は追加時に評価し CartItem に保持（表示用）。※**カート段階では在庫充足を強制しない**（充足の実強制は無く、E3 確定でも無検証減算＝before の過剰販売に接続）。
- カートはセッション限定（未ログインで作成可、ログイン後も同一セッションのカートを引き継ぐ）。

## 4. データモデル（as-is）

**DB 永続なし**（セッションオブジェクトのみ）。参照するマスターは `item`（listprice）／`inventory`（qty、isInStock 判定）。

## 5. secure-by-default 要件

> カートは before で **clean**（価格サーバ権威・数量のみ受理）。「維持」＋横断NFR適用が主。

| before | as-is | after（secure-by-default） |
| --- | --- | --- |
| **SBD-2 マスアサインメント（clean 維持）** | 受理は**数量のみ**、価格はサーバ計算 | 価格・itemId 以外の権威値をクライアントから受理しない姿勢を維持。数量は**正の整数**として検証（as-is は `<1` で削除・非数値無視）。 |
| **SBD-3 CSRF** | カート変更（add/update/remove）＝状態変更に CSRF 対策なし | 状態変更に CSRF トークン（横断NFR）。REST 化で冪等性を整理（add/update/remove）。 |
| **在庫整合（E3 と接続）** | `isInStock` は表示のみ・充足強制なし | 在庫充足の実強制は **E3 F3.2（確定時の充足チェック付き原子引当）** で担保。カートは表示・警告まで。 |

## 6. スコープ（Factory 方針）

- **挙動等価で残す**：追加・数量更新（0で削除）・削除・表示・小計サーバ計算。
- **変える（モダン化）**：セッションカート → SPA 状態＋カート REST（数量更新は明示 API に。パラメータ名=itemId の暗黙規約は廃し、明示的な {itemId, quantity} に）。**削除は単一意味論に正規化**（as-is の itemMap desync を踏襲しない）。不正 itemId は正規化エラー。iBATIS→MyBatis。
- **PO へ送る論点**：①未ログインカートの永続化/マージ方針（as-is はセッションのみ）②在庫切れアイテムのカート内表示・追加可否 ③数量上限。
