# Sprint 14 バックログ

## スプリントゴール

**注文照会機能（履歴一覧・詳細閲覧）を「本人スコープ・サービス層認可（認証プリンシパル基準）」で新ビルドに実装し、before S3 identity-rebind IDOR（一覧・詳細双方）と列挙オラクルを消滅させる。**

- **#9 注文履歴一覧**: `GET /api/orders`（本人スコープ・サーバページング・新しい順）＋ 注文履歴画面（Vue3 SPA）。認可は認証プリンシパルから（form/param の username を認可に使わない＝SBD-1）。
- **#10 注文詳細閲覧**: `GET /api/orders/{orderId}`（所有者限定）＋ 注文詳細画面（Vue3 SPA）。**not-owned と not-found を同一 403 に統一**して連番 orderId の存在推測を封じる（SBD-8）。明細に商品名を join して表示（ID-24・非等価改善）。金額は BigDecimal（SBD-13）。
- **cross-repo 3-repo**（database＋backend＋frontend）。**既達土台（#8 注文ドメイン・#21 認可部品・catalog ページング/JOIN 先例）を最大限再利用**し、新規は「一覧/詳細の read API＋画面＋複合索引」に集中。3観点クリーンを目標。

## 対象Issue

| Issue | タイトル | ラベル | ブランチ |
|-------|---------|--------|---------|
| #9 | [E3] 自分の注文履歴一覧を表示する（本人スコープ・サービス層認可） | security / E3 | `feature/9-order-history-detail`（**3 repo 同名ブランチ**） |
| #10 | [E3] 注文詳細を所有者限定で閲覧できるようにする（列挙対策込み） | security / E3 | 同上（**#9/#10 を1ブランチに集約**・Sprint 55 方針） |

> **ラベルは `security`＋`E3`（`bug` ではない）** ＝ feature Story（E3 の read 機能）。ブランチ prefix は `feature/`。
> **1ブランチ集約方針（Sprint 55 確立）**: #9/#10 を各 repo でスタックせず、Issue 単位のコミットを1ブランチに積む。ブランチ名はいずれかの Issue# でよい。

---

## 計画フェーズ確定事項（ユーザー承認済）

### 委譲論点（Refinement 2026-08-16 で PO 既決 → 再確認不要）
- **#9 ページング**: 先例規約 `PageResponse<T>`（content/page/size/totalElements/totalPages）・**1-index・既定 size=12・cap=100**（catalog #1/#2 踏襲・ID-20）。
- **#9/#10 認可**: 認証プリンシパル基準（`CurrentUserProvider.requireCurrentUser()` の userId）。リクエストで束縛される値（form/param の username）を認可に使わない（SBD-1・ID-4）。
- **#10 同一 403**: not-owned と not-found を**同一 403** に統一（Refinement で 403 に確定・SBD-8）。
- **#10 商品名表示**: 明細に Item を join（ID-24・意図差分台帳登録済）。金額 BigDecimal（ID-3・SBD-13）。
- **#9/#10 認証必須**: frontend ルート `meta.requiresAuth: true`・本人スコープ。未認証は #18/#24 のサインオン誘導＋元URL復帰。

### 実装レベル未確定 → AskUserQuestion 2026-08-17 で確定
- **Q1（索引/repo数）= 3-repo・複合索引を追加**: 一覧ソートは**新しい順（`ORDER BY order_id DESC`＝主キー・同日タイでも決定的）**で確定。`(user_id, order_id)` 複合索引の Flyway マイグレーションを **jpetstore-database に追加**＝ **cross-repo 3-repo（database＋backend＋frontend）**。
- **Q2（詳細の表示範囲）= AC どおり最小**: 注文詳細 = **明細（商品名・単価×数量）＋注文合計＋注文日のみ**。配送先/請求先住所は**表示しない**（AC 外・過剰実装回避）。**backend DTO も明細＋合計＋日付に絞る**（住所を DTO に含めない）。

### 実装機構（既決として実装・reviewer に意図的設計として明記）
- **#10 同一 403 の実装**: `OrderApplicationService.getOrder` で「注文が**不存在** OR **非所有**」の両方に `AccessDeniedException` を投げる → 既存 `GlobalExceptionHandler` が **403＋監査記録**に正規化。**`ResourceNotFoundException`（404）は使わない**（404 を返すと列挙オラクルになる）。
- **非数値/型不一致 orderId path**（例 `/api/orders/abc`）→ 既存 `GlobalExceptionHandler.handleTypeMismatch` の **400**（malformed は存在を漏らさない＝どの非数値でも一律 400）。存在する/しない・所有/非所有の弁別が起きるのは**数値 orderId のみで、その応答は一律 403**。
- **認可部品**: `OwnershipAuthorizationService.assertOwner(resourceOwnerUserId)`（#21 で用意・**本 Story が初の実ドメイン適用**）。渡すのは**サーバ側で解決した真の所有者 userId**（クライアント入力を認可に使わない）。#10 は「orderId → サーバで order.userId を解決 → assertOwner」の流れ。未一致/未認証 → `AccessDeniedException` → 403＋監査（既存結線が自動カバー）。

### Repository 経由の層構造（運用ルール・PR#12 で明文化済）
- **新規 Story は最初から Repository 経由**。#9/#10 の SELECT は `OrderRepository` に SELECT メソッドを追加して実装し、Application 層から MyBatis Mapper/`*CustomEntity` を直呼びしない（Sprint 12/13 で確立）。
- `OrderRepository` の設計方針 O1（案A）: rich な Order 集約は作らず、各メソッドは**単文アトミック委譲**に純化（一覧取得・count・単一取得・明細取得をそれぞれ単純メソッドとして追加）。

---

## 計画前の実地調査（既達 vs 未実装）サマリ

backend / frontend を Explore で並列調査。**既達土台が大きい**（Sprint 4/9/11 型のハードニング Story パターン）。

### database（jpetstore-database）
| 項目 | 判定 | 備考 |
|---|---|---|
| `t_order` / `t_order_line` DDL | **既達（#8・V00_000_005）** | 一覧・詳細に必要な列は揃う（user_id・order_date・total_price・status_code・明細 item_id/quantity/unit_price）。**新規テーブル・列は不要**。 |
| ソート用複合索引 | **新規（Q1 決定）** | 現状 `idx_t_order_user_id (user_id)` 単一列のみ → **`(user_id, order_id)` 複合索引の Flyway マイグレーションを新規追加**。`t_order_line` は `(order_id, line_num)` UNIQUE 既存で `WHERE order_id=?` 明細取得は追加索引不要。 |

### backend（jpetstore-backend）
| 項目 | 判定 | 備考 |
|---|---|---|
| `GET /api/orders`（一覧） | **未実装** | OrderController は `POST /api/orders` のみ |
| `GET /api/orders/{orderId}`（詳細） | **未実装** | 同上 |
| `OrderApplicationService.listOrders/getOrder` | **未実装** | 現状 `placeOrder` のみ |
| `OrderRepository` SELECT メソッド群 | **未実装** | 現状 `insertHeader`/`insertLine` のみ（SELECT 皆無）。listByUser(offset,limit)＋countByUser＋findById＋findLinesByOrderId を追加 |
| Mapper SELECT SQL（明細の商品名 JOIN 含む） | **未実装（Order側）** | `CatalogCustomMapper.selectItemById` の `m_item ⋈ m_product`（`p.name AS product_name`）JOIN が **#10 AC2 の参考実装**。`t_order_line ⋈ m_item ⋈ m_product` の2段 JOIN を新規 SQL で。 |
| `Page`/`PageRequest`/`PageResponse<T>` | **既達（無改造再利用）** | 1-index・DEFAULT_SIZE=12・MAX_SIZE=100・範囲外はクランプして空 200。**Javadoc に「#9 が再利用する先例」と明記済**。`CatalogApplicationService.listProductsByCategory` が組立パターンの参照実装。 |
| `CurrentUserProvider` / `AuthenticatedUser` | **既達** | `requireCurrentUser().userId()` |
| `OwnershipAuthorizationService.assertOwner` | **既達（未適用）** | #21 で用意・実ドメイン初適用が本 Story |
| `GlobalExceptionHandler`（403/404 正規化・監査結線） | **既達** | AccessDenied→403＋`recordAuthzFailure`、ResourceNotFound→404、想定外→trace 非露出 500 |
| `AuditLogRecorder`（認可失敗監査） | **既達** | assertOwner 経由で自動カバー |

### frontend（jpetstore-frontend）
| 項目 | 判定 | 備考 |
|---|---|---|
| 注文履歴/詳細 View・ルート | **未実装** | `checkout/CheckoutView.vue`・`CheckoutCompleteView.vue` のみ。完了画面は明細を持たず**#10 へ委譲済**（コメント明記）。`src/views/order/` は未存在 |
| `orderApi` の GET メソッド | **一部あり（要拡張）** | `orderApi.ts` は `placeOrder` のみ。一覧/詳細メソッドを追加。`catalogApi.ts`（DTO→domain 変換・`toPageResult`・`pageQuery`）が参照実装 |
| ルーター / authGuard / 元URL復帰 | **既達** | `meta.requiresAuth: true` 付与のみで配線ゼロ。`sanitizeRedirectTarget` で復帰。`authGuard.spec` は `/account/orders?page=2` を例示（命名ヒント） |
| ページング UI（`PageResult<T>`・`Pagination.vue`・`buildPageWindow`・`ProductListView.vue`） | **既達** | `PageResult<T>` は **Javadoc/コメントで #9 向け先例と明記**。URL クエリ `?page=` に状態を持たせる定型パターン |
| httpClient / CSRF | **既達** | cookie-to-header・401 refresh。403/404 の個別ハンドリングは呼び出し側 store で新規記述 |
| Pinia ストア（履歴/詳細用） | **未実装（新規）** | `stores/order.ts` は確定結果のみ。`checkout.ts`/`catalog.ts` の揮発ストア・ページングステートが手本 |
| i18n `order.history.*` / `order.detail.*` | **未実装（新規）** | `orderComplete.*` のみ既存。`en.ts` 1ファイルに追記（英語のみ・ID-27） |
| 明細テーブル・金額フォーマット | **既達（転用可）** | `CheckoutConfirmStep.vue` の `<table class="jps-table">`（商品名＋単価＋数量＋行合計＋合計）／`n(price,{style:'currency',currency:'USD'})`＋`.jps-price` が **#10 詳細の明細表示にほぼそのまま転用可** |

---

## リスク・チャレンジ

- **R1（#10 同一 403 の reviewer churn 防止）**: 既存 `GlobalExceptionHandler` は not-found→404／access-denied→403 に**分岐**する作り。#10 は両方を **403 に統一**するため getOrder で不存在・非所有の両方に `AccessDeniedException` を投げる。sec/conv reviewer が「不存在は 404 が正しいのでは」と誤指摘しないよう、**意図的設計（列挙オラクル封じ・SBD-8）として reviewer 起動プロンプトに明記**する。
- **R2（cross-repo 3-repo 運用）**: database（複合索引マイグレーション）＋backend＋frontend の**同名ブランチ＋各 PR**。closes 集約先の管理（下記）。`git diff origin/main...branch --name-only` を各 repo で取得（ローカル main が stale な場合があるため origin/main 基準）。
- **R3（IDOR の中核・SBD-1）**: `OwnershipAuthorizationService` の初の実ドメイン適用。**assertOwner に渡すのはサーバ解決した真の所有者 userId**（クライアント入力を認可に使わない）。一覧は `WHERE user_id = #{principalUserId}` で principal 由来のみ。AC-neg1（`?account.username=他人` を与えても自分の履歴のみ）を**否定AC 回帰テストで先取り実証**。
- **R4（Sprint Review で thin に見えるリスク）**: 詳細画面は AC どおり最小（住所非表示）で確定。reviewer/Sprint Review で「住所欠落」を欠落指摘しないよう**意図的スコープとして明記**（Q2 確定）。
- **Challenge（モデル）**: 計画=Opus 最新／実装=Sonnet 最新（tier 分離13連続で有効）。エイリアス `opus`/`sonnet` が各 tier 最新へ解決。新規チャレンジは無し（既に最新 tier を使用）。

### cross-repo closes 判断（PR 時に最終確定）
- **主リポジトリ = frontend**（capstone＝注文履歴/詳細**画面**＝ユーザー価値の実現層。read 系ドメイン画面＝Sprint 6 #1・Sprint 10 #7 の frontend 主パターン）。
- **closes は frontend PR に集約**（`closes ryokkon624/jpetstore-manage#9` / `closes ryokkon624/jpetstore-manage#10`）。従 = backend / database PR は **`Related: #9, #10`** に留める（早期クローズ回避）。
- backend が database の Flyway（複合索引）を参照するため、backend で `./gradlew syncTestSchema` により test resources 同期を確認。

---

## 否定AC（reviewer 起動プロンプトに先回り指定・攻撃が失敗することを実証）

- **AC-neg1（#9・SBD-1）**: `GET /api/orders?account.username=<他人>`（または任意の username 束縛パラメータ）を与えても、返るのは**認証プリンシパル本人の履歴のみ**。before S3 identity-rebind IDOR が一覧で再現しない。セッションの identity が汚染されない。
- **AC-neg1（#10・SBD-1）**: 他人の orderId → **403**（自分の注文以外は見えない）。
- **AC-neg2（#10・SBD-8）**: 存在しない orderId と他人の orderId の応答が**区別不能**（同一 403・存在推測不可）。**500/スタックトレースが出ない**（SBD-10）。
- **意図的設計（欠落として指摘しないこと）**: 詳細画面に配送先/請求先住所を出さない（Q2）／注文編集・キャンセル API は作らない（read-only 限定）／SecurityConfig 無変更（`/api/orders/**` は既定 `authenticated()`＋CSRF は GET 非対象）／status は ID-22 の固定プレースホルダ（状態遷移運用は作らない）。

---

## Issue 全文転記

### #9 [E3] 自分の注文履歴一覧を表示する（本人スコープ・サービス層認可）

**ラベル**: security, E3

#### ユーザーストーリー
- **As a** 認証済みユーザー
- **I want to** 自分の注文履歴だけを一覧で見たい
- **So that** 過去の注文を確認できる（他人の履歴は見えない）

#### トレース
- **Epic**: E3 注文（Checkout & Orders）
- **Feature**: F3.3 注文履歴一覧（本人スコープ）
- **挙動spec**: spec/behavior/order.md §2.2, §5（S3）
- **横断NFR**: spec/security-baseline.md（SBD-1, SBD-8, SBD-10）

#### Acceptance Criteria
- [ ] **AC1**: 認証ユーザー **本人の注文のみ** を一覧表示（orderId/date/totalPrice）。サーバサイドページングあり（PO決定）。ページングは先例規約 `PageResponse<T>`（`content/page/size/totalElements/totalPages`）に従い、**1-index**・**既定 size=12・cap=100**（#1/#2 catalog 踏襲・Refinement 2026-08-16）。
- [ ] **AC2 (SBD-1)**: 認可はサービス層で **認証プリンシパル基準**。リクエストで束縛される値（form/param の username）を認可に使わない。
- [ ] **AC3**: 注文履歴の画面・APIは **認証必須**（frontend ルート `meta.requiresAuth: true`・本人スコープ）。未認証は #18/#24 のサインオン誘導＋元URL復帰に従う（Refinement 2026-08-16）。
- [ ] **AC-neg1 (否定AC / SBD-1)**: `listOrders?account.username=他人` を与えても、返るのは自分の履歴のみ（before S3 identity-rebind IDOR が一覧でも再現しない）。セッションの identity が汚染されない。

#### 備考
- 優先順位の根拠: before S3 は一覧・詳細双方が対象。認可土台の適用面。
- スコープ（Refinement 2026-08-16）: **full-stack**。backend REST（`GET /api/orders` 本人スコープ・ページング）＋ frontend 注文履歴画面（Vue3 SPA）。checkout ウィザード（#7）とは別画面として本Storyが自画面を持つ。
- 依存関係: #8（F3.2）／#18（認証）／#21（F5.4 認可土台）／#23（E6.2）。
- PO決定（Refinement 2026-08-11）: 履歴一覧にサーバページングを設ける。
- **Sprint 14 確定**: ソート＝新しい順（`order_id DESC`）／`(user_id, order_id)` 複合索引を database に追加（3-repo）。

---

### #10 [E3] 注文詳細を所有者限定で閲覧できるようにする（列挙対策込み）

**ラベル**: security, E3

#### ユーザーストーリー
- **As a** 認証済みユーザー
- **I want to** 自分の注文の詳細だけを見たい
- **So that** 明細を確認できる（他人の注文や存在推測はできない）

#### トレース
- **Epic**: E3 注文（Checkout & Orders）
- **Feature**: F3.4 注文詳細閲覧（所有者限定）
- **挙動spec**: spec/behavior/order.md §2.3, §5（S3・列挙オラクル）
- **横断NFR**: spec/security-baseline.md（SBD-1, SBD-8, SBD-10, SBD-13）

#### Acceptance Criteria
- [ ] **AC1 (SBD-1)**: orderId 指定で **自分の注文のみ** 詳細表示。認可はサービス層で所有者判定（認証プリンシパル基準）。
- [ ] **AC2**: 注文詳細に **商品名を表示**（PO決定・非等価改善。as-is は履歴経由で明細の商品名が空）。明細に Item を join する等で商品名/単価を補完。
- [ ] **AC3 (SBD-8/SBD-10)**: **not-owned と not-found を同一 403 に統一**（連番 orderId の存在推測を封じる。AC-neg1 と整合・Refinement 2026-08-16 で 403 に確定）。as-is の存在しない orderId→NPE 500 を解消。
- [ ] **AC4 (SBD-13)**: 金額表示は BigDecimal/decimal。
- [ ] **AC5**: 注文詳細の画面・APIは **認証必須**（frontend ルート `meta.requiresAuth: true`・本人スコープ・Refinement 2026-08-16）。
- [ ] **[L2] 旧同値**: 注文の明細（単価×数量）・注文合計が旧同値。※商品名表示は ID-24 の意図差分
- [ ] **AC-neg1 (否定AC / SBD-1)**: 他人の orderId → 403（自分の注文以外は見えない）。
- [ ] **AC-neg2 (否定AC / SBD-8)**: 存在しない orderId と他人の orderId の応答が区別不能（存在推測不可）。500/trace が出ない。

#### 備考
- スコープ（Refinement 2026-08-16）: **full-stack**。backend REST（`GET /api/orders/{orderId}` 所有者限定）＋ frontend 注文詳細画面（Vue3 SPA）。
- 商品名表示は意図差分台帳 **ID-24**（登録済み・台帳追記不要）。
- 依存関係: #8（F3.2）／#22（E6.1・明細join）／#21（F5.4）。
- PO決定（Refinement 2026-08-11）: 注文詳細で商品名を表示（非等価改善）。
- **Sprint 14 確定**: 表示は AC どおり最小（明細＋合計＋注文日のみ・住所非表示）／同一 403 は getOrder で不存在・非所有の両方に `AccessDeniedException`。

---

## 退行ガード（グリーン維持）

- backend: `OrderControllerSpec`／**`OrderConcurrencyIntegrationSpec`（#8 在庫並行保証・最重要・退行させない）**／`OrderApplicationServiceSpec`／`CatalogCustomMapperSpec`（JOIN 参照）／既存 Repository/Mapper Spec。新規に `OrderApplicationServiceSpec`（listOrders/getOrder のページング・認可分岐を DB 非依存 UT）／Order の一覧・詳細 Mapper Spec（Testcontainers）／`OrderController` の GET Spec（未認証401・他人403・不存在403・型不一致400・ページング）を追加。
- frontend: 既存 `authGuard.spec`／`pagination.spec`／`i18n index.spec`（キー網羅）をグリーン維持。新規 View/store/api の Vitest。
