# Sprint 11 バックログ

## スプリントゴール

**E3 注文確定を成立させる。** #7 のチェックアウト・ウィザード（内容確認まで）から、実際の注文確定を **secure-by-default** で実行する。合計・単価は**マスター価格からサーバ再計算**（クライアント値無視）、`username` は**認証プリンシパル**、確定は**非冪等POST＋CSRF**（GET確定リンク廃止）。在庫は **ガード付きアトミック減算で原子的に引き当て**（在庫不足/競合負けは注文失敗・**売り越し不可**）、注文ヘッダ＋明細＋在庫減算を **`@Transactional` で all-or-nothing**、注文作成を**監査ログに記録**する。**ID-1（在庫充足の実強制）を中核**に、価格改ざん・過剰販売・不整合を防ぐ。

## 対象Issue

| Issue | タイトル | ラベル | SP | ブランチ |
|-------|---------|--------|----|---------|
| #8 | [E3] 注文確定でサーバ再計算・在庫の原子的引当・整合性を保証する | security / E3 | 8 | `feature/8-order-placement`（**cross-repo: backend 主 + frontend 従、同名ブランチ**） |

**関連する意図差分台帳**: ID-1（在庫ガード付き減算＝#8中核）／ID-3（金額 BigDecimal）／ID-9（非冪等POST＋CSRF）／ID-21（courier/locale撤去）／ID-22（status固定・状態変更を監査ログ）／ID-23（DB原子採番）。**いずれも既存台帳エントリの実装であり、新規 intended-diff の追加は不要**（PO確認事項）。

---

## 計画フェーズ確定事項（AskUserQuestion 2026-08-17 / ユーザー承認済）

spec/AC/規約が実装レベルで委譲していた 3 論点を計画で確定（reviewer churn・スコープ手戻り防止）。

1. **在庫不足・競合負け時の応答 = 409 Conflict**
   - ガード付き `UPDATE ... WHERE quantity >= :n` の **affected rows==0**（在庫不足 or 同時発注の競合負け）を、**専用ドメイン例外**（例 `InsufficientStockException`）→ `GlobalExceptionHandler` で **409 Conflict** にマップ。
   - 既存の楽観ロック競合（`OptimisticLockConflictException`=409）と系を揃える。フロントは「在庫が不足しています」を表示。
   - 実装: `AffectedRows.requireUpdated(rows, supplier)`（#8 を名指しで想定済みのヘルパ）の `supplier` で在庫不足例外を投げる。

2. **注文完了画面（#8）のスコープ = 最小（注文番号＋合計＋サンクスメッセージ）**
   - 完了ビューは **注文番号・サーバ再計算合計・サンクスメッセージのみ**。**明細行・商品名の一覧表示は作らない**（#10 注文詳細閲覧に委譲。ID-24 履歴経由の商品名表示も #10）。
   - Sprint7型のスコープ縮小方針と整合。

3. **確定時にマスター価格がカート表示時と変動していた場合 = 再計算値でそのまま確定**
   - 確定時点の `m_item.list_price` で `Σ(unit_price × quantity)` を BigDecimal 再計算し、そのまま確定。**価格変動の差分検知・再確認フローは実装しない**。
   - as-is（legacy `Order.initOrder` の listPrice 取込）と挙動等価。AC-neg1（`totalPrice` 注入無視）は担保。MVP に価格編集の管理画面が無く変動は稀のためスコープ最小。

### その他の計画方針（既存規約・調査から確定・質問不要）

- **エンドポイント = `POST /api/orders`（複数形）に統一**: frontend の #7 コメント（`CheckoutConfirmStep.vue`・`en.ts`）が `/api/orders` を想定済み＋REST 慣習。backend 調査時の `/api/order`（単数）は表記ゆれのため**複数形に確定**。
- **確定リクエストの allowlist（SBD-2 マスアサインメント防止）**: 受理するのは**配送/請求先住所・別配送フラグ・支払プレースホルダ入力のみ**。**数量はサーバ側 DB カート**（`selectCartItems`）から読む（リクエストの数量を信用しない）。**価格＝サーバ再計算**・**`username`＝認証プリンシパル**・`itemId`/`linenum`/`orderDate`/`status`/`orderId`＝サーバ権威。
- **status プレースホルダ = `OrderStatus.NEW` 固定**（m_code 0001・enum 既達）。遷移運用なし（AC6・ID-22）。
- **監査（SBD-14）= `AuditLogRecorder.recordStateChange("ORDER_CREATE", …)` で `t_audit_log` に明示記録**（#23 で「注文作成が呼ぶ想定」で用意済みの API）。加えて **WHO カラムは AOP/Interceptor が自動付与**（`OrderApplicationService` を `application.service` 配下に置くだけ）。
- **原子的引当（arch §4.1）**: 複数商品は **`item_id` 昇順で固定順減算**しデッドロック回避。**`SELECT … FOR UPDATE`・`version` 列・リトライループは不使用**（ガード付き UPDATE の行ロックで直列化）。注文ヘッダ＋明細＋在庫減算を **`@Transactional` で all-or-nothing**。
- **orderId 採番 = AUTO_INCREMENT**（`sequence` 廃止・ID-23。既達スキーマ）。
- **カートクリア**: 注文成功後に `t_cart_item` を全削除する mapper メソッドを新規追加（現状は行単位削除のみ）＋ frontend cart ストアのリセット。
- **database ノータッチ**: `t_order`/`t_order_line`/`t_inventory`・シード・原子採番・m_code・`t_audit_log` は全既達（V00_000_005/006/008/002）。**新規 Flyway マイグレーションは作らない**。
- **SecurityConfig 無変更**: `/api/orders` は permitAll に無いため `anyRequest().authenticated()` で自動保護、CSRF も自動適用（カートと同型）。

### 意図的な設計判断（reviewer には「欠落として指摘しない」と明示する）

- **database の新規マイグレーションを作らない**（全既達）。
- **完了画面は最小**＝明細/商品名の一覧は**意図的に作らない**（#10 スコープ）。
- **注文詳細閲覧API・注文履歴一覧API は #8 で作らない**（#9/#10 スコープ）。
- **在庫表に `version` 列を足さない／`SELECT … FOR UPDATE`・リトライループを使わない**（ガード付き減算が主機構＝arch §4.1）。
- **価格変動の再確認フローを実装しない**（再計算値で確定）。
- **SecurityConfig 無変更**。

---

## Issue #8 本文（転記）

### ユーザーストーリー

**As a** サイト運営者 / 購入者
**I want to** 注文確定時に金額をサーバ再計算し、在庫を充足チェック付きで原子的に引き当てたい
**So that** 価格改ざん・過剰販売・不整合を防ぐ

### トレース

- **Epic**: E3 注文（Checkout & Orders）
- **Feature**: F3.2 注文確定・在庫引当・整合性
- **挙動spec**: spec/behavior/order.md §2.1, §3, §5
- **横断NFR**: spec/security-baseline.md（SBD-1, SBD-2, SBD-3, SBD-13, SBD-14）
- **アーキ規約**: spec/architecture-conventions.md §4.1（在庫ガード付きアトミック減算）／.claude/rules/database.md「並行制御」

### Acceptance Criteria

- [x] **AC1 (SBD-2)**: 確定時、**合計・単価はマスター価格からサーバ再計算**しクライアント値を無視。`username` は **認証プリンシパル**（フォーム束縛値を使わない）。数量は E2 カート工程の入力を用いる。
- [x] **AC2 (arch §4.1)**: **在庫はガード付きアトミック減算で引当**＝`UPDATE inventory SET qty = qty - :n WHERE item_id = :id AND qty >= :n`。**affected rows == 0 を在庫不足（or 競合負け）として注文失敗**（read→act 分離の TOCTOU を避ける。`SELECT ... FOR UPDATE`・`version` 列・リトライループは不要）。在庫を負数化しない＝承認済の非等価変更「過剰販売防止」。
- [x] **AC3 (arch §4.1)**: 在庫減算＋注文ヘッダ＋明細を **`@Transactional` で all-or-nothing**（1品でも不足なら全ロールバック）。複数商品は **`item_id` 昇順など固定順で減算しデッドロックを回避**。orderId は **DB 原子採番**（as-is の select→+1→update 非アトミックを是正）。
- [x] **AC4 (SBD-3)**: 確定は **非冪等POST＋CSRF**（as-is の GET 確定リンク `newOrder.do?confirmed=true` を廃止）。
- [x] **AC5 (SBD-13)**: 金額は BigDecimal / decimal で扱う（double を使わない・承認済）。
- [x] **AC6 (SBD-14)**: 注文作成（状態変更）を監査ログに記録（誰が/何を/結果）。status は固定プレースホルダ（遷移運用なし・PO決定）。
- [x] **[L2] 旧同値(特性化)**: item X を2個注文 → available_qty が2減／明細合計=単価×数量／注文合計=Σ明細（§3正規化: WHO/version/採番ID/日時を除外。在庫ガードは ID-1・BigDecimal は ID-3 の意図差分）
- [x] **AC-neg1 (否定AC / SBD-2)**: `order.totalPrice=0.01` 等を注入しても、永続値はサーバ再計算合計になる。
- [x] **AC-neg2 (否定AC / 過剰販売防止・arch §4.1)**: 在庫数を超える数量の確定が失敗し、`inventory.qty` が負数にならない。**同一在庫への同時/二重発注でも売り越さない**（ガード付き UPDATE の行ロックで直列化）。
- [x] **AC-neg3 (否定AC / SBD-1)**: `order.username=他人` を注入しても、注文は認証プリンシパル本人に紐づく。

### 備考

- 承認済の非等価変更: 過剰販売防止（在庫充足チェック）／金額 BigDecimal／支払カード撤去。
- スコープ外（将来Feature候補）: **注文確認メール**（legacy の `SendOrderConfirmationEmailAdvice`＝現状 config 無効）は MVP 対象外（PO決定 E3）。
- アーキ根拠: 在庫並行制御は architecture-conventions §4.1（ガード付きアトミック減算・固定順減算でデッドロック回避）＝legacy のガード無し減算（売り越し可能）を是正。SBD-2／SBD-14 と一体。
- 依存関係: #22（E6.1）／#23（E6.2）／#4-#6（カート）／#18（認証）。

---

## 事前実地調査（既達 vs 未実装）サマリ

3-repo を Explore 並列調査。結論: **backend の横断基盤・DBスキーマ・frontend の #7 ウィザード資産はほぼ全て既達。#8 は「注文ドメインの Java 実装（100% 未実装）を既存基盤の上に書き下ろす」作業。database はノータッチ**（Sprint7型の縮小＝当初 3-repo 想定→ 2-repo）。

### 既達（再利用でスコープを絞る）

**backend**
- **監査基盤**: `AuditLogRecorder.recordStateChange(action, targetType, targetId, result, detail)`（Javadoc に「注文作成等の状態変更は後続ドメインが呼ぶ想定」と明記）＋ `recordAuthzFailure`。WHO 自動付与＝`ProgramContext`/`ProgramContextAspect`（`..application.service..` pointcut）/`AuditProgramInterceptor`。
- **認証プリンシパル→userId**: `CurrentUserProvider.requireCurrentUser().userId()`（カートが踏襲済・IDOR面ゼロ）／`AuthenticatedUser` record／`OwnershipAuthorizationService.assertOwner`。
- **並行制御ヘルパ**: `domain/concurrency/AffectedRows.requireUpdated(rows, supplier)`（**#8 の在庫ガード減算を名指しで想定**）。
- **例外正規化**: `GlobalExceptionHandler`（404/409/403/401/400/405 既存）。`OptimisticLockConflictException`=409／`ResourceNotFoundException`=404。→ **在庫不足例外(409)のみ新規追加**。
- **BigDecimal 価格権威**: `Cart.of`/`CartApplicationService.toCartItem`（`listPrice.multiply(...)` を BigDecimal・DB権威 `m_item.list_price`）。全経路 `DECIMAL(10,2)`。
- **カート読取**: `CartCustomMapper.selectCartItems(cartId)`（item_id/quantity/list_price/stock_quantity を返す）＋`ensureCart`。
- **enum**: `OrderStatus`（NEW/PAID/SHIPPED・`CodeEnum`・`fromCode`）既達。
- **SecurityConfig**: `/api/orders` は既定で authenticated＋CSRF 自動（STATELESS・`CookieCsrfTokenRepository`）。**無変更で成立**。
- **custom mapper/entity 配置規約**: `AuditLogCustomMapper`（`@Insert`・追記専用）／`CartCustomMapper.xml`（JOIN/動的SQL）が手本。
- **統合テスト基盤**: `IntegrationTestBase`（Testcontainers MySQL 8.4 + Flyway）／`OptimisticLockSqlSemanticsSpec`（JdbcTemplate で SQL 意味論を実DB検証＝**並行引当検証の手本**）。

**frontend（#7 資産）**
- `/checkout` ルート（`requiresAuth`）＋`CheckoutView.vue`（空カートは `/cart?reason=empty-checkout` へ replace＝AC-neg1 のフロント側）＋3ステップ（`CheckoutCartStep`/`CheckoutAddressStep`/`CheckoutConfirmStep`）＋`AddressForm.vue`。
- `checkout` Pinia ストア（billing/shipping/useSeparateShipping・揮発）＋`domain/checkout.ts`。
- `httpClient.ts`（CSRF cookie-to-header 自動付与・401 silent refresh。POST は `request<T>('/api/...', {method:'POST', body})` で再利用可）。
- cart ストア読取 getter（`displayItems`/`subtotal`/`isEmpty`）／`accountApi`（住所プリフィル）。
- api モジュール＋Vitest の規約（`cartApi.ts`/`accountApi.spec.ts` が orderApi の雛形）。
- 既存 i18n `checkout.*` の大半。

**database（全既達・ノータッチ）**
- `t_order`（AUTO_INCREMENT・`total_price DECIMAL(10,2)`・`status_code`・WHO6列・version無）／`t_order_line`（`unit_price DECIMAL(10,2)`・UNIQUE(order_id,line_num)）／`t_inventory`（`quantity`・version無）＝V00_000_005。
- inventory シード（V00_000_008・EST-1〜28。**在庫切れ**=EST-3/EST-21、**残少**=EST-2:1/EST-9:3/EST-15:5、他=100）。
- 原子採番=AUTO_INCREMENT（sequence 廃止）／注文ステータス m_code 0001（NEW/PAID/SHIPPED・V00_000_002）／`t_audit_log`（event_type=STATE_CHANGE・action=ORDER_CREATE 対応・V00_000_006）。
- Flyway 最新=V00_000_010。**backend の `syncTestSchema` は既に V00_000_010 まで同期済**（新規マイグレーションが無いため追加同期不要）。

### 未実装（#8 の新規作業）

**backend（主）**
1. **在庫ガード付きアトミック減算 Mapper**（+entity）: `UPDATE t_inventory SET quantity = quantity - :qty WHERE item_id = :id AND quantity >= :qty`。affected rows==0 を `AffectedRows.requireUpdated(rows, supplier)` で在庫不足例外へ。
2. **在庫不足/引当失敗の専用例外**（例 `InsufficientStockException`）＋ `GlobalExceptionHandler` の **409** マッピング。
3. **注文ヘッダ/明細 INSERT Mapper+Entity**（`t_order`/`t_order_line`・custom 手書き。orderId は AUTO_INCREMENT）。
4. **カート全クリア Mapper メソッド**（`DELETE FROM t_cart_item WHERE cart_id = :cartId`）。
5. **`OrderApplicationService`**（`@Transactional`）: カート読取 → サーバ権威で `m_item.list_price` 再取得＆`total_price` を BigDecimal 再計算 → 在庫を item_id 昇順でガード減算 → 注文ヘッダ/明細 INSERT → カートクリア → `recordStateChange("ORDER_CREATE",…)`。
6. **`OrderController`**（`POST /api/orders`）＋ リクエスト/レスポンス DTO（配送/請求先・別配送フラグ・支払プレースホルダを allowlist 受理／レスポンスは orderId・再計算合計）。
7. **`domain/order/`**（Order/OrderLine record・注文結果 record）。
8. **テスト一式**（Spock unit ＋ Testcontainers 統合・**同時引当競合**の検証）。

**frontend（従）**
- `src/api/orderApi.ts`（`POST /api/orders`）＋ `src/domain/order.ts` ＋ `src/api/__tests__/orderApi.spec.ts`。
- **注文完了ビュー（最小）**＋ ルート（例 `/checkout/complete` or `/order/:id`）。
- `CheckoutConfirmStep.vue` の `disabled` 撤去＋クリックハンドラ配線（orderApi 呼出→成功で完了画面へ／失敗=在庫不足でエラー表示）。`placeOrderComingSoon` 撤去。
- 注文確定の状態管理（`checkout` ストア action or 新規 order ストア／loading・error・orderId）。
- cart ストアの**注文成功後クリア action**（サーバカートクリア反映＋ローカルリセット）。
- i18n: 送信中/成功/失敗（在庫不足）・完了画面の文言（最小）。

---

## リスク・チャレンジ

- **cross-repo（backend 主 + frontend 従）**: 各 repo に同名ブランチ `feature/8-order-placement`＋各 PR。`closes ryokkon624/jpetstore-manage#8` は**主=backend PR に集約**、従=frontend PR は `Related:`（Sprint3/4 の backend 主パターン。#7 とは主従が逆＝#8 の capstone は注文確定トランザクション＝backend）。
- **並行安全の実証が #8 品質の要（AC-neg2）**: 「同一在庫への同時/二重発注でも売り越さない」を **Testcontainers 実DB で並行発注を実行して検証**（`OptimisticLockSqlSemanticsSpec` が手本）。ガード付き UPDATE の affected rows==0 判定＝在庫不足の否定AC も実DBで固定する。
- **否定AC 先回り指定（reviewer 起動プロンプトで具体化）**: AC-neg1（`totalPrice=0.01` 注入→永続値はサーバ再計算合計）・AC-neg2（在庫超過失敗・`quantity` 負数化なし・二重発注で売り越さない）・AC-neg3（`username=他人` 注入→認証プリンシパル本人に紐づく）。SBD-2/SBD-1 系の否定AC を Sprint8-10 同様に先回り。
- **意図的設計の明記（churn 防止・Sprint9初出→10で3観点クリーン実証）**: 上記「意図的な設計判断」（database 無変更／完了画面最小／注文詳細・一覧API 未作成／version列不追加・FOR UPDATE不使用／価格変動再確認なし／SecurityConfig無変更）を各 reviewer に「欠落として指摘しないこと」と明示。
- **スコープ規律**: backend は注文確定ユースケースに限定（#9/#10 の注文照会・履歴・詳細を先取りしない）。「既達が大きい」ため過剰実装を避ける（Sprint4/9/10 型）。
- **チャレンジ（C1 先例再利用）**: 監査/WHO/`AffectedRows`/BigDecimal 価格権威/カート読取/`httpClient` CSRF/api-module/Vitest/Testcontainers を無改造再利用できるか実証（Sprint7-10 の先例再利用成功の継続）。
- **チャレンジ（モデル tier 分離 11 連続）**: 計画=Opus 4.8（最上位）／実装=Sonnet（最新・高速）。新モデルのリリースは現時点なし。**初の書き込み系トランザクション×並行制御 Story**（write ドメインは Sprint8 カートで実証済だが、注文確定＋在庫原子引当＋監査を1トランザクションに束ねるのは新難度）でも tier 分離が通用するかを実証。
