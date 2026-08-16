## #4: [E2] カートの追加/数量更新/削除/表示ができるようにする

### 仕様外の判断・変更・妥協点

- **backend: `t_cart_item`の書き込みは「Java側でSELECT→絶対値を計算→単文UPSERT」に統一した**（短期記憶の設計スケッチでは
  `upsertCartItem`（DB側のアトミック加算・`quantity = quantity + VALUES(quantity)`）と`updateCartItemQuantity`（絶対値SET）を
  分けて書く想定だったが、実装ではどちらも同一の`upsertCartItemQuantity`（絶対値upsert・`CartCustomMapper`）に統一した）。
  理由: 在庫上限チェック（`selectItemForCart`でstockQuantity/currentQuantityを事前取得）が必須のため、どのみち書き込み前にSELECTが
  発生する。SELECT結果を使って最終的な絶対数量をJava側で計算してから単文UPSERTする方が、DB側の生の加算式（クランプ不可）より
  一貫していてテストしやすい。書き込みそのものは単文UPSERTのため原子性は保たれる（D3の「last-write-win・単文アトミック更新」の
  意図は維持）。
- **backend: PUT `/api/cart/items/{itemId}`は、対象アイテムがまだカートに無くても新規追加として扱う（upsert）**。ACには
  「カート内に無い行へのPUT」の挙動は明記されていなかったため、`selectItemForCart`が返す`currentQuantity=0`を起点に
  同じ絶対値ロジックを適用する設計にした（POSTと同じ検証パス・不要な404を避ける・冪等なPUT本来の意味論に近い）。
- **backend: `POST /api/cart/merge`の未知itemId（クライアント側の古いlocalStorageデータ等）は例外にせず無視して他の行を継続処理する**。
  ACに未知itemId混在時のmerge挙動は明記が無かったため、ログイン成功フロー全体を1件の不正データで失敗させない防御的な設計を選んだ
  （`CartApplicationService#merge`）。
- **backend: orderable EP（`GET /api/items/{itemId}/orderable`）の理由コードは`OUT_OF_STOCK`/`EXCEEDS_STOCK`/`INVALID_QUANTITY`の
  3種に統一した**（`quantity`パラメータは省略時デフォルト1）。ACには具体的なreasonコード列挙が無かったため、cart側の400理由と
  対称になるよう実装時に定めた。
- **frontend: 未ログイン時のCartView表示は、localStorageの`{itemId, quantity}`だけでは商品名/価格が分からないため、
  `catalogApi.fetchItem`（公開EP）で各itemIdを個別に解決してから表示する設計にした**（`cartStore.refreshLocalItemDetails`）。
  カートの行数は通常少数（数件〜十数件）である前提のもと、N回の個別GETをそのまま許容した（サーバー側の複数ID一括取得APIは
  このスプリントでは新設しない。カート行数が多くなるドメインではないため許容範囲と判断）。
- **frontend: 未ログイン時のadd/update操作は必ず`cartApi.checkOrderable`（D1の公開EP）を呼んでからlocalStorageへ反映する**。
  未ログインでもAC5/AC-neg1（在庫切れ追加不可・数量上限=在庫数のserver強制）を満たすための実装上の要点であり、`cartStore`の
  `addItem`/`updateItem`/`applyLocalQuantity`に集約した。
- **frontend: ログイン時マージ（`mergeOnLogin`）は明示的な1回だけフラグを持たず、「localLinesが空になったら以後はmergeを
  呼ばずfetchCartのみ行う」という自然な冪等性で「1回だけ実行・失敗時リトライ」を実現した**。成功時のみ`clearCart()`と
  `localLines=[]`を行うため、フラグ管理より単純かつフェイルセーフ（失敗時は次回`syncOnAuthChange(true)`呼び出しで自動的に
  再試行される）。
- **frontend: `App.vue`に`authStore.isAuthenticated`を監視する`watch`（`immediate: true`）を追加した**（ACに明記は無いが、
  マージのトリガー元をどこに置くかは実装レベルの判断が必要だったため）。`immediate: true`により、既にログイン済み状態で
  リロードされた場合（前回セッションでマージが失敗し`localLines`が残っている場合）にも再試行される。
- **既存テストの更新**: `ItemDetailView.spec.ts`の「カート追加ボタンは非活性プレースホルダである」テストは、本Storyでボタンを
  実装したため実際の挙動（在庫状況に応じた活性/非活性・クリックでの追加）を検証するテストに置き換えた。

### レビュー指摘対応（sec 1件・CONFIRMED）

- **指摘**: `CartApplicationService.addItem` が数量の**下限**バリデーション（`requestedQuantity<=0`）と**int
  オーバーフロー**を検査しておらず、`POST /api/cart/items {quantity:-1}`（または`0`・巨大な正数との加算オーバーフロー）で
  負の数量が永続化されうる（SBD-2違反。`GET /api/cart`のlineTotal/subtotalが負値化）。
- **対応**:
  1. `CartController.AddCartItemRequest.quantity`に`@Min(1)`を付与（`Integer`のnullは検証対象外のため省略時=既定1は影響なし）。
  2. `CartApplicationService.addItem`冒頭で`requestedQuantity<=0`を`IllegalArgumentException`（→400）で拒否（DTO検証をバイパスする直接呼び出し経路への多層防御）。
  3. `addItem`の`currentQuantity + requestedQuantity`を`Math.addExact`に変更し、`ArithmeticException`を`IllegalArgumentException`（→400）へ変換。オーバーフロー時にintがラップして負の巨大な値になり、既存の`newQuantity > stockQuantity`チェックを迂回して負の数量が永続化される不具合を防ぐ。
  4. `merge`の`currentQuantity + line.quantity()`も同様に`Math.addExact`化。mergeは非拒否方針（クランプのみ）のため、オーバーフロー時は例外にせず`stockQuantity`へ直接クランプする（他行の処理は継続）。
  5. テスト追加: `CartApplicationServiceSpec`（quantity<=0の`where`網羅・addItem/mergeのオーバーフロー各1件）・`CartControllerSpec`（E2Eでquantity=0/-1/-100が400になり非永続化・2段階リクエストでのintオーバーフローが400になり既存数量が汚染されないことを確認）。
  6. `./gradlew check`（unit 22件/E2E 25件を含む全体）green・`spotlessApply`済み。
- DB側`CHECK (quantity > 0)`制約の追加は見送った（任意対応・アプリ層修正で十分と判断。SMの完了条件でも「優先はアプリ層修正＋テスト」と明記）。
