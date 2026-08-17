## #30: [E6] Repository 層を全 bounded context へ展開（Catalog/Account/Order・Mapper 直呼び全廃）

### 仕様外の判断・変更・妥協点

**共通**
- **実装順は計画どおり Account（最軽）→ Catalog（中）→ Order（最重）**。各 context を「RED（Repository/Query
  未実装で参照するテストを先に書き compileTestGroovy 失敗を確認）→ GREEN（domain interface＋MyBatis実装＋Service書換）
  →REFACTOR」の順で1 contextずつ完結させ、Order着手前にAccount/Catalogのユニットテストが全green であることを確認した。
- Entity→record 変換（Catalog の `StockStatus` 射影含む）は、#29 の `CartConverter` のような独立クラスを新設せず、
  各 `MyBatisXxxRepository` 内の `private` メソッドに閉じた（Account/Catalog はいずれも単一 Entity 種別からの
  変換のみで、Cart のように複数 Entity 種別を合成する複雑さが無いため、独立 Converter クラスを起こす動機が薄いと判断）。

**Account（最軽）**
- `AccountRepository#findContactByUserId(Long): Optional<AccountContact>` とし、`Optional.empty()` を「該当行なし」の
  シグナルとした。404 への変換判断（`ResourceNotFoundException`）は Application 層に残し、Repository は「存在するか
  しないか」のみを返す薄い契約にした（Cart の `findStock` と同じ Optional 方針）。

**Catalog（中）**
- 生の在庫数量（qty）を必要とする `checkOrderable` のためだけに `domain/catalog/ItemStock`（record: itemId,
  stockQuantity）を新設した。`ItemDetail`/`ItemSummary` は引き続き `StockStatus` 射影のみを持ち qty を持たない
  （ID-28維持）。`findItemDetailById`（`ItemDetail` 用）と `findItemStockById`（`ItemStock` 用）は同じ
  `CatalogCustomMapper#selectItemById` を呼ぶ別々の Repository メソッドにした。両方が同一ユースケース内で
  同時に呼ばれることは無い（`getItem` は前者のみ、`checkOrderable` は後者のみ）ため、クエリ数の純増は発生しない。
- C1（AC4）どおり `CatalogApplicationServiceSpec` を新設し、一覧系の親not-foundガード（category/product 不存在時に
  以降のクエリを一切呼ばないこと）・検索の空キーワード短絡（repositoryへ一切問い合わせない）・categoryId有無の
  正規化・`checkOrderable` の5分岐（not found/invalid qty/out of stock/exceeds stock/ok）をDB非依存で固定した。

**Order（最重・O1〜O3）**
- **O1（案A採用・確定どおり）**: rich な Order 集約は作らず、`domain/order/NewOrder`（record:
  userId/billing/shipping/totalPrice/status/orderDate）・`OrderLine`（record: itemId/lineNum/quantity/unitPrice）の
  最小書込みVOのみ新設した。`@Transactional`・item_id昇順固定順ループ・ガード減算＋`AffectedRows.requireUpdated`・
  カート全クリア・成功/失敗REQUIRES_NEW監査はすべて `OrderApplicationService` に残した（#8の並行保証はそのまま）。
- **O2**: `OrderRepository`（`insertHeader(NewOrder):Long`／`insertLine(Long,OrderLine)`）と
  `domain/inventory/InventoryRepository`（`decrease(itemId,quantity):int`＝affected rows をそのまま返す）に分割した。
  `AffectedRows.requireUpdated` の呼び出しは計画どおり Application 層に残した（0件=在庫不足→throwの
  固定順/all-or-nothingセマンティクスはorchestrationの知識のため）。
- **O3**: `CartRepository#clearItems(Long cartId)` を追加し、実装は `cartCustomMapper.deleteCartItems(cartId)` へ
  委譲した。`OrderApplicationService` は既存の `CartRepository#ensureCart`/`findByCartId` をそのまま再利用し、
  `selectCartItems` の `ORDER BY ci.item_id`（#8固定順）が `findByCartId`→`Cart.items()` を経由しても保持されることを
  実装時に再確認した（`CartCustomMapper.xml` の `selectCartItems` を確認。行28-34参照）。
- **WHO解決**: `MyBatisOrderRepository`/`MyBatisInventoryRepository` はいずれも `CurrentUserProvider` を保持し、
  `create_user_id`/`update_user_id` を自己解決する（#29 `MyBatisCartRepository` と同じ思想）。`NewOrder.userId()`
  自体は「注文の持ち主」を表す別概念のため、WHO解決とは独立に Application 層が `currentUserProvider.
  requireCurrentUser().userId()` から明示的に渡す。
- `OrderApplicationServiceSpec` は3 mapper mock（`CartCustomMapper`/`OrderCustomMapper`/`InventoryCustomMapper`）から
  3 repository mock（`CartRepository`/`OrderRepository`/`InventoryRepository`）へ全面書換した。AC-neg3（userId紐付け）
  の検証は、旧実装ではEntityのcreateUserId/updateUserIdまで直接assertしていたが、WHO解決の責務がRepository実装内へ
  移ったため、Application層のテストでは `NewOrder.userId()` の一致のみを検証し、WHOカラム自体の検証は新設した
  `MyBatisOrderRepositorySpec`/`MyBatisInventoryRepositorySpec`（Mapper mock）側へ分離した。

### 退行ガード結果

- `./gradlew test`（全Spock UT）・`./gradlew integrationTest`（全Testcontainers IT）ともに green。
- `OrderConcurrencyIntegrationSpec`（#8 二重発注で売り越さない・最重要）を含む全ITが green
  （`build/test-results/integrationTest/TEST-...OrderConcurrencyIntegrationSpec.xml`: tests=1, failures=0, errors=0）。
- `CatalogControllerSpec`/`CatalogCustomMapperSpec`/`AccountControllerSpec`/`AccountContactCustomMapperSpec`/
  `OrderControllerSpec`/`InventoryCustomMapperSpec`/`CartCustomMapperSpec`/`CartControllerSpec`（#29資産）はいずれも
  無変更のまま green。
- `grep -rn "infrastructure\.mybatis" src/main/java/.../application/` は0件（`AuthApplicationService` を含む全
  Application Service で0件。AuthApplicationServiceはそもそも `infrastructure.security.*` のみ注入しmybatisに
  一切依存しないため、除外を明示するまでもなく自明に0件だった）。
- `*CustomMapper`/XML・`SecurityConfig`・database は無変更のまま残した（Repositoryが委譲する既存規約どおり）。

### TDDでの気づき（既知パターンの再発）

- `CatalogApplicationServiceSpec`の「categoryIdが指定されていれば」テストで、`given:`ブロックの裸stub
  （`catalogRepository.searchProducts(...) >> []`）と `then:` ブロックの引数一致インタラクション（`>>`無し）を
  分けて書いたところ、`then:`側が優先され`given:`側の戻り値が無視されNPEになった（backend-conventions §9・
  Sprint11/12に続く3回目の遭遇）。1つの`then:`インタラクションにmatcherと`>>`をまとめる形で解消した。
