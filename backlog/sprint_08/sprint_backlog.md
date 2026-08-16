# Sprint 8 バックログ

## スプリントゴール

**Epic E2「カート」の初回 Story として、追加/数量更新/削除/表示ができるカートを、REST＋SPA状態で新規リビルドする。** 未ログインはクライアント（Pinia/localStorage）保持、ログイン時にサーバーカート（DB永続）へ数量加算マージ。在庫切れ追加不可・数量上限＝在庫数を server-side で強制し、不正 itemId は SBD-10 で 404/検証エラーに正規化する。as-is の itemMap desync（幽霊行）バグは踏襲せず map/list 一貫の単一削除意味論に是正する。

- Epic E2（Cart）／Feature F2.1 カート操作 の capstone。E1（カタログ）完成に続く**購入導線の中核**。
- **3-repo cross-repo**（database＋backend＋frontend）。ユーザー決定（下記「計画フェーズ確定事項」①）。

---

## 対象Issue

| Issue | タイトル | Epic/Feature | SP | ラベル |
|-------|---------|--------------|-----|--------|
| #4 | [E2] カートの追加/数量更新/削除/表示ができるようにする | E2 / F2.1 | 8 | `feature`, `E2`（**bug なし**） |

- GitHub Issue: `ryokkon624/jpetstore-manage#4`（Sprint=8, SP=8, Ready）
- ブランチ（各 repo 同名）: `feature/4-cart-operations`
- 挙動spec: `spec/behavior/cart.md` §2, §3, §6 ／ 横断NFR: `spec/security-baseline.md`（SBD-10・SBD-2・SBD-3）
- 台帳: ID-17（幽霊行バグ是正）・ID-18（在庫切れ追加不可・数量上限=在庫数）・ID-19（未ログイン=クライアント保持＋ログイン時サーバーマージ）

---

## Issue #4 Body（全文転記）

### ユーザーストーリー

**As a** 買い物客（未認証を含む）
**I want to** 商品をカートに入れ、数量を変え、削除し、内容を確認したい
**So that** 購入前に注文内容を組み立てられる

### トレース

- **Epic**: E2 カート（Cart）
- **Feature**: F2.1 カート操作
- **挙動spec**: spec/behavior/cart.md §2, §3, §6
- **横断NFR**: spec/security-baseline.md（SBD-10）

### Acceptance Criteria

- [x] **AC1**: 追加/数量更新/削除/表示をカート REST＋SPA状態で提供（セッションカート手組みJSP廃止）。数量更新は明示的な {itemId, quantity} API（as-is の「パラメータ名=itemId」暗黙規約は廃止）。
- [x] **AC2**: 数量0以下は行削除。**削除は map/list 一貫の単一意味論に正規化**（承認済の非等価変更＝as-is の itemMap desync「幽霊行」バグを踏襲しない）。
- [x] **AC3**: 未ログインカートは **クライアント状態（Pinia/localStorage）に保持** し、**ログイン時にサーバーカートへマージ**（PO決定 E2①）。
- [x] **AC4 (SBD-10)**: 不正/存在しない itemId は 404/検証エラーへ正規化（as-is の getItem null→NPE を踏襲しない）。
- [x] **AC5**: 在庫切れアイテムは追加不可、数量上限＝在庫数（PO決定）。在庫表示はバッジ（在庫あり/残少/在庫切れ）。
- [x] **[L2] 旧同値**: item X 2個＋item Y 1個 → 小計=Σ(listPrice×qty)
- [x] **AC-neg1 (否定AC)**: 在庫数を超える数量での追加/更新が拒否される（カート段階の上限チェック）。

### 備考

- 優先順位の根拠: 購入導線の中核。E1 に続く。
- 依存関係: #1/#2（商品・在庫参照）／#18（ログイン→マージ）／#24（E6.3）。
- PO決定（Refinement 2026-08-11）: 未ログインはクライアント保持＋ログイン時マージ・削除正規化・在庫切れ追加不可・数量上限=在庫数。

---

## 計画フェーズ確定事項（SM 計画フェーズ AskUserQuestion・2026-08-16）

> spec `cart.md` §6 の「PO へ送る論点」3つ（未ログイン永続/マージ・在庫切れ表示・数量上限）は Refinement 2026-08-11 で確定済（AC3/AC5・台帳 ID-18/19）。以下は spec/AC が**実装レベルに委譲**していた論点を SM が計画フェーズで確定した分。

**① サーバーカートの永続スコープ = DB永続サーバーカート（3-repo）**
- database に `t_cart` / `t_cart_item`（`V00_000_010`〜）を新設し、backend で永続化3層＋ログイン時マージ、frontend は未ログイン localStorage 保持。
- **AC3 を完全充足**しデバイス跨ぎで永続。backend は STATELESS/JWT のため「サーバーカート」= DBテーブルが実質必須（in-memory/session は不可）。
- 所有者は `m_account.user_id`（既存規約: t_order と同じ代理キー）を FK に張る。

**② ログイン時マージの数量意味論 = 数量を加算（在庫数で上限クランプ）**
- 同一 item が client カートとサーバーカート両方にある場合、client+server を**合算**し、在庫数を超える分はクランプ。
- 例: client 2個＋server 3個→5個（在庫≥5なら5、在庫3なら3にクランプ）。一般的な EC カートの挙動。
- **新規挙動＝台帳追記対象**（ID-19 のマージ意味論を「加算・在庫クランプ」に具体化。PO が Refinement/Retro で台帳反映）。

**③ spec 由来の設計方針（ユーザー確認不要・spec §5 に準拠）**
- **既存カート行が後から在庫減で上限超過した場合**は、cart.md §5「カートは表示・警告まで、在庫充足の実強制は E3 確定時」に従い、**カート表示時はバッジ警告のみ（数量は保持）**。ハード拒否は add/update アクション時のみ（AC-neg1）。実強制は E3 に接続。
- **qty 非露出の維持（ID-28）**: 在庫上限チェックは **server-side で強制**し、生の quantity をレスポンスに露出しない。上限超過は 400/検証エラーで返す（client は残少バッジで scarcity を認識、正確な在庫数は知らない）。→ DEV は「在庫上限を露出せず server で弾く」設計を計画フェーズで具体化すること。

---

## 既達 vs 未実装（計画前 実地調査・Explore／3-repo）

> カート機能は**3リポジトリ全て未実装**（after 側の "cart" は AppHeader 仮リンク・i18nキー・ItemDetail の disabled「Coming soon」ボタン・CSS のみ）。土台は E1 で完備。

| repo | E2 で新規に作る | 既存土台（流用可） |
|---|---|---|
| **backend** | `CartController`（`/api/cart` 認証必須）・`CartApplicationService`（在庫切れ/上限=在庫数/マージ）・`Cart`/`CartItem` ドメイン・`CartCustomMapper`＋XML（t_cart/t_cart_item 読み書き・在庫JOIN・生quantity取得）・Cart用DTO record・SecurityConfig への `/api/cart/**`（permitAll に**入れない**＝既定で認証必須） | 4層（presentation/application/domain/infrastructure）・`AuthenticatedUser.userId`・`CurrentUserProvider`・`OwnershipAuthorizationService`（所有者チェック）・`StockStatusCalculator`（在庫3段階）・t_inventory JOIN SQL 先例・`GlobalExceptionHandler`（404/409/400 SBD-10 正規化）・`ResourceNotFoundException`・CSRF/認証/refresh・Testcontainers 統合テスト・`syncTestSchema`・カスタムXMLマッパー方式 |
| **frontend** | `cart` store（Pinia・未ログイン localStorage＋ログイン時サーバーマージ）・`api/cartApi.ts`・`CartView`＋route（**公開ルート＝requiresAuth なし**。AC3 で未ログインもクライアントカートを閲覧するため。認証必須なのは `/api/cart/**` API のみ＝計画フェーズ D2 訂正）・AppHeader 仮リンク→実ルート化＆件数バッジ接続・ItemDetailView の disabled ボタン→実装・`cart.*` i18nキー | `httpClient`（CSRF cookie-to-header/401 silent refresh/HttpError）・auth store（`isAuthenticated`/`fetchCurrentUser` 再水和）・`authGuard`/`meta.requiresAuth`・`StockBadge`/`ProductCard`/`Pagination` 部品・`STOCK_STATUS` 定数・i18n `domain.context.key`・`.jps-cart-count` CSS |
| **database** | **`V00_000_010`〜: t_cart / t_cart_item**（所有者 FK→`m_account.user_id`・item FK→`m_item.item_id`・WHO6列・必要なら version）。sql-test にカートフィクスチャ追加も検討 | m_item/m_product/t_inventory スキーマ＋seed(V008)・`m_account.user_id` 代理キー・`demo_user` ログインフィクスチャ・Vマイグレーション連番規約・`seedDevData`/Flyway・backend `syncTestSchema` 連携 |

**最重要**: ログインユーザー用サーバーカート永続基盤（`t_cart`/`t_cart_item`）は皆無で**新規作成が必須**。所有者識別・在庫参照・item参照・認証必須既定・CSRF・エラー正規化・UI部品・Flyway/test同期は完成済み土台としてそのまま乗る。

---

## リスク・チャレンジ

### リスク

1. **localStorage 導入がフロント初**: `stores/auth.ts` は「Pinia state はメモリ上のみ、localStorage/sessionStorage 永続化なし」と明記（トークンは httpOnly Cookie）。未ログインカートの localStorage 保持は**フロント初の新規パターン**（既存先例なし）。永続キー設計・タブ間同期・破損データのフォールバックを計画で具体化。
2. **8SP・3-repo で範囲が大きい**: DB新設＋backend 永続化3層＋マージ＋在庫検証＋frontend cart store＋localStorage＋cartApi＋CartView＋header/ItemDetail 配線＋i18n＋3-repo テスト。最大スコープ。計画フェーズで作業分解を明確化し、AC 単位で優先度を付ける。
3. **qty 非露出（ID-28）と「数量上限=在庫数」の両立**: 在庫数を client に露出せず server-side で上限を強制する設計が必要（露出すると ID-28 違反）。DEV が計画で「露出せず弾く」方式を具体化。
4. **マージのタイミング/冪等性**: ログイン遷移（`isAuthenticated` false→true）を検知してマージを1回だけ実行する設計。二重マージ・失敗時リトライ・マージ後の localStorage クリアを整理。
5. **cross-repo 連携**: database に V010 を足したら backend で `./gradlew syncTestSchema` を実行して test resources を同期（Sprint 4/6 と同じ運用）。

### チャレンジ

- **C1（先例再利用の実効性・Sprint7 の再検証）**: E1 で固めた土台（`OwnershipAuthorizationService`／`StockStatusCalculator`／`GlobalExceptionHandler`／`httpClient`／`StockBadge`/`ProductCard`）を **別ドメイン（カート・状態変更あり）**で無改造再利用できるか検証。Sprint 7 は同一カタログドメイン内の再利用だったが、E2 は状態変更（書き込み・所有者スコープ・在庫ガード）を伴う**初の write ドメイン**での再検証。
- **Claude モデル**: 計画=Opus（最上位tier・最新）／実装=Sonnet（高速tier・最新）の tier 分離を継続（7スプリント連続で手戻りゼロ）。現行 Opus 4.8 が最新のため新モデル提案はなし。

---

## Definition of Done（このスプリント）

- AC1〜AC5・[L2]・AC-neg1 を満たす（server-side 在庫上限強制・map/list 一貫削除・SBD-10 正規化・小計サーバ計算）。
- 3観点レビュー（規約/セキュリティ/パフォーマンス）で指摘なし（または対応済）。
- backend: 統合テスト green・`compileJava` green・IDE 警告ゼロ。新規EP は主要疎通確認。
- frontend: Vitest green・`npm run format` 済。
- database: V010 マイグレーション適用可・backend `syncTestSchema` 同期済。
- 各 repo 同名ブランチ `feature/4-cart-operations`＋各 PR。**`closes ryokkon624/jpetstore-manage#4` は capstone repo（購入導線 UX の実現層＝frontend が主）**の PR に集約、backend/database 従 PR は `Related:`。
