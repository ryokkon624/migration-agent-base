# Sprint 13 バックログ

## スプリントゴール

**#29 で確立した Repository テンプレを Catalog / Account / Order へ横展開し、Application Service からの MyBatis Mapper 直呼び・`*CustomEntity` の上位層漏れを全廃する。** Auth を除く全 Application Service で `infrastructure.mybatis.*` の import を **0 件**にする。
- **Catalog / Account は CQRS 射影**（Domain に query interface を置き、read-model record〔`Product`/`ItemSummary`/`Page<T>`/`AccountContact` 等〕を返す。集約 `reconstruct()` を強制しない。Entity→record 変換は Repository 実装内）。
- **Order は #29 の書込集約パターン準拠**（`OrderRepository`＋`InventoryRepository`＋既存 `CartRepository` 再利用〔`ensureCart`/`findByCartId`〕＋`clearItems` 追加）。**#8 の在庫原子引当・監査・並行保証を壊さない**。
- **API・エンドポイント・レスポンス形状・挙動は不変**（内部リファクタ）、**3観点クリーン**。#30 で Repository 移行を完了し Mapper 直呼びを全廃する。

## 対象Issue

| Issue | タイトル | ラベル | SP | ブランチ |
|-------|---------|--------|----|---------|
| #30 | [E6] Repository 層を全 bounded context へ展開（Catalog/Account/Order・Mapper 直呼び全廃） | E6 / **refactor** | 8 | `refactor/30-repository-rollout`（**単一 repo: backend のみ・新規ブランチ1本**） |

**スコープ確定（AskUserQuestion 2026-08-17 / ユーザー承認済）**: **子 Issue に分割せず、Catalog + Account + Order を Sprint 13 で一括**。
> Issue タイトルは「Catalog/Account/Auth」だが、**body は 2026-08-17 Refinement で是正済**＝対象は **Catalog / Account / Order**（Order は最重の違反源で追加）、**Auth 除外**（Mapper/Entity 直依存なし・drift なし）。

**関連する意図差分台帳**: なし（挙動・API・レスポンス不変の内部リファクタ。新規 intended-diff の追加は不要＝PO 確認事項）。

---

## リファクタ Story の性質（#29 と同じ・スコープ規律）

- **挙動・API・レスポンス形状は一切変えない**。既存の Catalog/Account/Order 系 AC を退行させないことが完了条件。
- **退行ガード（Testcontainers・グリーン維持）**: `CatalogControllerSpec`／`CatalogCustomMapperSpec`／`AccountControllerSpec`／`AccountContactCustomMapperSpec`／`OrderControllerSpec`／**`OrderConcurrencyIntegrationSpec`（#8 在庫並行保証・最重要）**／`InventoryCustomMapperSpec`／`CartCustomMapperSpec`。
- **リファクタ Story のレビュー原則（scrum-master-workflow ④-3）**: reviewer 指摘が **main 時点から存在した既存問題の移動**なら「既存問題の移動」＝スコープ外（SM が `git show main:<path>` で裏取り）。
- **非対象**: Auth の Repository 化（drift なし）／新規機能・API 追加（retrofit に純化）。

---

## 計画前の実地調査（既達 vs 未実装 / drift 実態）サマリ

backend 単一 repo を Explore で調査。3 context の drift・#29 テンプレ適用・相対複雑度を確定。

### mybatis import ベースライン（AC「Auth 除く全 Service で 0 件」の現状）

| Service | mybatis import | 是正後の目標 |
|---|---|---|
| `OrderApplicationService` | **8**（entity5＋mapper3） | 0 |
| `CatalogApplicationService` | **5**（entity4＋mapper1） | 0 |
| `AccountApplicationService` | **2**（entity1＋mapper1） | 0 |
| `CartApplicationService` | 0（#29 済） | 0 |
| `AuthApplicationService` | 0（drift なし・対象外） | 0 |

既存 Repository/Converter は **#29 の Cart 系のみ**（`domain/cart/CartRepository`・`infrastructure/mybatis/cart/{MyBatisCartRepository,CartConverter}`）。他 context には未存在＝新規作成。

### context 別（複雑度: Account〔小〕＜ Catalog〔中〕＜ Order〔大・最重〕）

**Account（小・読取・CQRS 射影）**
- 注入: `AccountContactCustomMapper`＋`AccountContactCustomEntity`（import L6/L7）。公開は `getMyContact()`→`AccountContact`(record)の1件（`@Transactional(readOnly)`）。`OwnershipAuthorizationService` 未使用（対象は常に principal＝IDOR 面ゼロ）。
- ドメインモデル: `AccountContact`=record。変換 `toAccountContact`(private)。
- テスト: **`AccountApplicationServiceSpec`=純UT あり**（Mapper mock）／`AccountContactCustomMapperSpec`・`AccountControllerSpec`=Testcontainers。
- 適用: `AccountRepository`/`AccountQuery`(Domain・record 返し・reconstruct 不要)。純UT は mock 対象を Mapper→interface に差し替えるだけ。**最軽**。

**Catalog（中・読取・CQRS 射影）**
- 注入: `CatalogCustomMapper`＋4 Entity（`Category`/`ItemDetail`/`ItemSummary`/`ProductCustomEntity`・import L13-17）。公開8メソッド（`listCategories`/`getCategory`/`listProductsByCategory`/`getProduct`/`listItemsByProduct`/`searchProducts`/`getItem`/`checkOrderable`）、戻り値は全 read-model record＋`Page<T>`。
- 変換: `toCategory`/`toProduct`/`toItemSummary`（private）＋`getItem`/`checkOrderable` は Entity をインライン処理（`StockStatusCalculator.of(entity.getQuantity())` を Service 内で適用＝qty 非露出ロジックが Service に居る）。
- テスト: **Service 純UT なし**（`CatalogControllerSpec`/`CatalogCustomMapperSpec`=Testcontainers のみ）。純ドメイン UT は `StockStatusCalculatorSpec`/`ProductSearchTermsSpec` のみ。
- 適用: `CatalogQuery`(Domain・record 返し・reconstruct 不要)、変換＋`StockStatusCalculator` 適用を Repository 実装へ移設。**AC「不変条件・分岐を DB 非依存 UT 化」に沿い `CatalogApplicationServiceSpec`(query mock) を新設**（検索の categoryId 有無・checkOrderable 分岐を DB 非依存で固定）。

**Order（大・最重・書込集約）**
- 注入: `CartCustomMapper`/`OrderCustomMapper`/`InventoryCustomMapper`＋5 Entity（import L12-19）。`placeOrder`（`@Transactional`）が: `ensureCart`→`selectCartItems`（`ORDER BY ci.item_id`＝固定順）→ 注文ヘッダ INSERT → **item_id 昇順でガード減算**（`InventoryCustomMapper.decreaseInventory` `WHERE quantity>=:n`＋`AffectedRows.requireUpdated(rows, ()->InsufficientStockException)`）＋明細 INSERT → `deleteCartItems`（カート全クリア）→ 監査（成功=`recordStateChange`／失敗=`recordStateChangeIndependently`＝**REQUIRES_NEW**）。
- ドメインモデル: `domain/order` は record 3本のみ（`OrderConfirmation`/`PlaceOrderCommand`/`OrderAddress`）。**Order 集約（private ctor＋`reconstruct()`）は未存在＝新規**。
- **#29 CartRepository 再利用可**: `ensureCart(userId)→Long`＝Order の `ensureCartFor` を置換／`findByCartId(cartId)→Cart`＝`selectCartItems` を置換（`CartConverter.toCart` が mapper 返却順を stream 保持＝**ORDER BY item_id の固定順を維持し #8 のデッドロック回避を壊さない**。`CartItem` は itemId/quantity/listPrice を保持＝`calculateTotal` と明細 INSERT に十分）。
- **不足→追加要**: カート全クリア（`deleteCartItems` 相当）が `CartRepository` に無い（単一 `removeItem` のみ）→ **`CartRepository#clearItems(cartId)` を追加**（cross-cutting＝#29 資産の拡張）。
- テスト: `OrderApplicationServiceSpec`=純UT だが **3 Mapper 直 Mock**（Repository interface Mock へ書換必須）／`OrderControllerSpec`・**`OrderConcurrencyIntegrationSpec`（#8 並行保証）**・`InventoryCustomMapperSpec`・`CartCustomMapperSpec`=Testcontainers。
- 適用: `OrderRepository`（header/line INSERT＋Entity→Domain）＋`InventoryRepository`（ガード減算の単文アトミック委譲）＋`CartRepository` 拡張（`clearItems`）＋各 Converter。WHO カラム解決（`setCreateUserId/setUpdateUserId`）は #29 同様 Repository 実装へ移設。**並行保証（ガード UPDATE・`AffectedRows`・item_id 固定順・REQUIRES_NEW 監査・`@Transactional` all-or-nothing）のオーケストレーションは Application 層に残し、Repository は単文アトミック委譲に留める**切り分けが要注意（Order を過剰に rich 集約化しない＝#8 の並行制御は persistence/tx の関心）。

### Auth（対象外・裏取り済）
- `AuthApplicationService` は `AuthenticationManager`/`JwtService` 等 security infra のみ注入・`infrastructure.mybatis` import 0。ユーザ読込は `JdbcUserDetailsService`（Spring Security 統合点＝別概念）。Repository 化の要否は本 Issue 範囲外。

---

## Issue #30 本文（転記）

### 背景 / Why
Cart PoC（#29）で確立した Repository 経由（Domain interface ＋ Infrastructure 実装）のパターンを、残りの bounded context へ展開し、Application Service からの MyBatis Mapper 直呼び・`*CustomEntity` の上位層漏れを**全廃**する。規約は backend-conventions `SKILL.md` §1 / §2 / §9。

### 対象の drift 実態（2026-08-17 実コード確認）
| Application Service | Mapper/Entity 直依存 | 本Issueで対応 |
|---|---|---|
| Catalog | CatalogCustomMapper＋4 Entity | ○（CQRS 射影） |
| Account | AccountContactCustomMapper＋Entity | ○ |
| **Order** | Cart+Inventory+Order の3 Mapper＋5 Entity（**最重**） | ○（当初スコープから漏れていたため追加） |
| Cart | （#29 で Repository 化） | #29 完了済み・対象外 |
| Auth | Mapper/Entity 直依存なし | 対象外 |

### スコープ
- 対象 Service: `CatalogApplicationService`（読み取り=CQRS 射影）、`AccountApplicationService`、`OrderApplicationService`。**Cart は #29 完了・対象外。Auth 対象外**（drift なし・`JdbcUserDetailsService` は別概念）。API 仕様・レスポンス形状は不変（内部リファクタ）。

### 方針
- **読み取り側（Catalog）は CQRS 射影**: Domain に query インターフェイスは置くが read-model record（`Product`/`ItemSummary`/`Page<T>`）を返す。集約 `reconstruct()` 再構築を強制しない。Entity→record 変換は Repository 実装内。
- Account / Order は本人スコープ認可（`OwnershipAuthorizationService`）・在庫の原子的引当・監査ログ等の既存規約を維持しつつ Repository 経由へ。**Order は書き込み系が濃いため #29 の集約パターンに準拠**。

### Acceptance Criteria
- [x] **AC1**: Catalog / Account / Order の各 Application Service が Domain 層の Repository / Query インターフェイスのみを注入し、`*CustomMapper` / `*CustomEntity` の import・注入が Application 層から消える。
- [x] **AC2**: 各 Repository 実装は `infrastructure.mybatis.*` に置き、Entity→Domain（read-model record 含む）変換を内包する。
- [x] **AC3**: Application 層に `infrastructure.mybatis` への依存が残っていないことを `grep` 等で確認（回帰防止）。**Auth を除く全 Application Service で 0 件**。
- [x] **AC4**: 各 Service の不変条件・分岐を可能な範囲で DB 非依存の Spock UT 化（Repository モック）。既存の統合テストはグリーン維持。
- [ ] **AC5**: 3観点レビュークリーン・挙動退行なし。（reviewer未起動・DEV実装完了時点では未検証）
- [x] **AC6**: 規模に応じて bounded context 単位で子 Issue に分割してよい（Catalog / Account / Order）。→ **今スプリントは分割せず一括（ユーザー決定 2026-08-17）**。

### 備考
- ブランチ: bounded context 単位（分割時）。→ 一括のため単一 `refactor/30-repository-rollout`。
- **依存: #29（Cart PoC）完了後に着手**（テンプレ踏襲）。規約: backend-conventions §1/§2/§9。参照実装: #29。
- **運用ルール（2026-08-17 ユーザー決定）**: 今後の新規 Story は最初から Repository 経由で実装。本Issueは既存分の retrofit に純化。
- SP: 8（Order 込み）。

---

## spec 委譲論点の洗い出し（既決 vs 実装レベル未確定）

### 既決（AC/§9/#29 先例・body 方針・再確認不要）
- interface=Domain 層・実装=Infra 層／Application は Repository/Query のみ注入・`infrastructure.mybatis` import 0。
- 読取（Catalog/Account）=CQRS 射影（record 返し・reconstruct 不要）／書込（Order）=#29 集約パターン。
- API・挙動・レスポンス不変／Auth 除外／Cart は #29 済。
- Order は #8 並行保証（ガード減算・`AffectedRows`・item_id 固定順・REQUIRES_NEW 監査・`@Transactional`）を維持。

### 実装レベルで未確定（DEV の Opus 計画で具体案→ユーザー承認、割れたら AskUserQuestion）
設計方針は §9＋body で既決だが、以下は DEV が現状コードを分析して具体化。**#29 同様、SM 計画前の先出し AskUserQuestion は投げず、DEV 計画報告後にエッジ論点があれば AskUserQuestion**（2段階の後段主体）:
- **O1（Order 集約 vs orchestration の線引き）**: Order の書込は #8 並行制御が persistence/tx の関心＝Cart のような item 単位不変条件が薄い。**rich な Order 集約（reconstruct＋不変条件メソッド）をどこまで作るか、あるいは Repository で mapper を包み並行オーケストレーションは Application に残すか**。過剰抽象（YAGNI）を避ける線引き。
- **O2（Repository 分割粒度）**: Order 周りを `OrderRepository`＋`InventoryRepository`＋`CartRepository` 拡張の3面に割るか、集約するか。`InventoryRepository` のガード減算メソッドの戻り（affected rows）と `AffectedRows.requireUpdated` の呼び場所（Application or Repository）。
- **O3（CartRepository への `clearItems` 追加）**: #29 資産（`CartRepository`/`MyBatisCartRepository`/`CartConverter`）に触る cross-cutting。ドメイン語彙命名・既存 Cart テストのグリーン維持。
- **C1（Catalog 純UT 新設）**: AC4 に沿い `CatalogApplicationServiceSpec`(query mock) を新設し検索/checkOrderable 分岐を DB 非依存 UT 化するか（現状 Service 純UT 皆無）。

---

## リスク・チャレンジ

- **R1（Order の #8 並行保証維持・最重要）**: 在庫ガード減算（`WHERE qty>=:n`＋`AffectedRows.requireUpdated`）・**item_id 昇順固定順**・REQUIRES_NEW 監査・`@Transactional` all-or-nothing を Repository 化で壊さない。**`OrderConcurrencyIntegrationSpec`（二重発注で売り越さない）を退行ガード**にグリーン維持。`CartRepository#findByCartId` が ORDER BY item_id 順を保持することを確認（Explore で確認済だが実装時に再確認）。
- **R2（一括ゆえのレビュー分散・ユーザー選択のトレードオフ）**: 読取（機械的）と Order（高リスク並行）が混在。緩和＝**実装は読取先行（Account→Catalog）→ Order の順**、reviewer 起動時は **context 別に変更ファイルを整理**して渡し観点を集中させる。Order が急ぎ気味にならないよう SM が Order の delta を重点 verification。
- **R3（cross-cutting＝#29 資産への変更）**: Order のため `CartRepository#clearItems` を追加＝#29 の `CartRepository`/`MyBatisCartRepository`/`CartConverter` に触る。既存 Cart 系テスト（`CartApplicationServiceSpec`/`CartCustomMapperSpec`/`CartControllerSpec`）を**グリーン維持**。
- **R4（Catalog 純UT 不在）**: interface 化の挙動保証が現状 Testcontainers 頼り。AC4 に沿い `CatalogApplicationServiceSpec`(query mock) を新設して分岐を DB 非依存 UT 化（#29 の C2 テンプレを Catalog へ適用）。
- **R5（Order 集約の過剰抽象回避＝O1）**: Cart は item 単位不変条件が濃かったが Order の「不変条件」は原子引当＝persistence/tx の関心。**rich な Order 集約を過剰に作らない**（YAGNI）。DEV が計画で線引き→ユーザー承認。
- **意図的設計の明記（churn 防止・Sprint10 昇格③）**: reviewer 起動プロンプトに「**欠落・未実装として指摘しないこと**」と明示: API/エンドポイント/レスポンス DTO 無変更／Auth の Repository 化はしない（drift なし・#30 対象外）／`*CustomMapper`/XML は無変更で残し Repository が委譲（#29 同様）／Catalog/Account は reconstruct を強制しない（CQRS 射影は record 返しが規約）／SecurityConfig/database 無変更／Order を過剰に rich 集約化しない（#8 並行制御は tx の関心）。
- **チャレンジ C1（tier分離13連続）**: 計画=Opus／実装=Sonnet。#29 に続くリファクタ・**初の複数 bounded context 横断・読取(CQRS)と書込(集約)の混在**でも通用するか実証。
- **チャレンジ C2（#29 テンプレの実効性検証）**: #29 で確立したテンプレ（§9 記録済）が Catalog=CQRS 射影／Order=集約＋CartRepository 再利用 の両面で無改造適用できるか（Sprint7 型「先例再利用」の Repository 版）。
