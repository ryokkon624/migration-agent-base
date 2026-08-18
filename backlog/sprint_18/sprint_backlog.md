# Sprint 18 バックログ

## スプリントゴール

**出荷済み E3/E4 保護ルート機能の「実機到達性」を回復し、蓄積した低リスク技術的負債を焼却する。**

Sprint 14 以降に出荷したチェックアウト（#7）・注文履歴/詳細（#9/#10）・アカウント編集（#14）・PW変更（#15）は、
機能自体は正常に動くが **リロード/直リンクで認証ガードが誤判定（#33）** し、かつ **ログイン後の導線が UI に無い（#34）** ため、
ユーザーからは実質到達不能だった。この2つの到達性バグを直して出荷済み機能への入口を復旧する。
あわせて、E4 完結後に残っていた低リスクの技術的負債 —
frontend の非推奨 `baseUrl`（#27）・backend の null type safety 警告（#31）・database 依存の版 currency（#26・SBD-12）— を焼却する。

- **対象 repo**: **3-repo**（frontend＝#33/#34/#27・backend＝#31・database＝#26）。ただし**各 Issue はそれぞれ単一 repo で完結**（同一 Issue が複数 repo にまたがらない）＝cross-repo だが closes は各 repo の PR に単純分散。
- **合計**: 8SP（#33=2・#34=2・#27=1・#31=1・#26=2）。Sprint 17（8SP）と同規模。
- **方針の一貫性**（PO Refinement 2026-08-18）: 「到達性バグ修正（#33→#34）＋技術的負債の焼却（#27→#31→#26）」。

## 対象 Issue（優先順位順）

| 優先 | Issue | タイトル | ラベル | SP | repo | 主 repo/branch（暫定） |
|----|-------|---------|--------|----|----|----|
| ① | #33 | [bug] 保護ルートのリロード/直リンクでログイン済みでもサインオンに飛ばされる（認証ガードが再水和前に評価） | bug | 2 | frontend | frontend `fix/33-auth-guard-reachability` |
| ② | #34 | [bug] ログイン後に注文履歴/アカウント設定への導線（ナビゲーションリンク）が無い | bug | 2 | frontend | 同上（#33 と 1 ブランチ・Issue 単位コミット） |
| ③ | #27 | [frontend] tsconfig.app.json の非推奨 baseUrl オプションを解消する | refactor | 1 | frontend | 同上（frontend 3 Issue を 1 ブランチに集約・Sprint55 方針） |
| ④ | #31 | [backend] Null type safety 警告（ストリームのメソッド参照）を解消する | refactor | 1 | backend | backend `refactor/31-null-type-safety` |
| ⑤ | #26 | [E6] 依存の版currency見直し（mysql-connector-j 等・SBD-12） | foundation / E6 | 2 | database | database `refactor/26-dependency-currency` |

> **bug ラベル**: #33・#34（いずれも 2026-08-18 のライブ手動検証で SM がライブ再現・根本原因特定済み。Issue Body に詳細記載あり）。
> **実装順序**: **#33（認証ガードのレース修正）→ #34（導線追加）** を推奨（#33 を先に直すと、追加した導線経由でもハードロード/リロードで signon へ飛ばされず安定到達できる。#34 Body 依存欄で明示）。#27/#31/#26 は独立（他 Story をブロックしない・されない）。

---

## 計画フェーズで確定すべき委譲論点（SM 洗い出し・DEV 計画フェーズで確定）

SM ワークフロー①の標準手順（spec/AC/規約が PO/仕様/実装へ委譲した論点を計画フェーズで確定し reviewer churn・スコープ手戻りを防ぐ）。今スプリントは**大半が実装詳細寄り**で、DEV 実コード精読後の確定が自然（Sprint11/15 型 2 段階の後段主体）。ただし **#34 の導線配置は UX 判断**のため計画フェーズでユーザー承認を取る候補。

### Q1（#34・UX判断・要ユーザー承認候補）: 導線の「配置形態」
- AC1 は「ヘッダー**（またはアカウントメニュー）**から注文履歴/アカウント設定へ遷移できる」と**両許容**。
  - 案A: ヘッダーに平置きリンク（Orders / Account を Home/Catalog/Cart と並べる）。
  - 案B: 「Hi, <username>」をアカウントドロップダウンメニュー化し、その中に Orders / Account / Sign Out を収める。
- **既存 `AppHeader.vue` のレイアウト・`--jps-*` デザイントークン・i18n（`domain.context.key`）に整合**する範囲で、DEV が計画フェーズで案を提示しユーザー承認を取る。

### Q2（#33・実装詳細・DEV 精読後で確定可）: 再水和（`GET /api/auth/me`）が**失敗**した場合のガード挙動
- AC2 は「Cookie 無効/期限切れ＝未認証として signon 誘導（回帰なし）」。真のネットワーク/サーバエラーで `/me` が失敗した場合の扱い（未認証扱いで signon か・現状の `fetchCurrentUser` 実装がどうハンドルしているか）を DEV が実コードで確認し、AC2 の回帰が起きない範囲で確定する。
- 根本原因は裏取り済（`main.ts:15` の `app.use(router)` が `main.ts:23` の再水和 `await Promise.all([...])` **より前**に呼ばれ、router install 時の初期ナビゲーションがガードを再水和完了前に走らせる）。修正案（`app.use(router)` を await 後へ移す等）は AC を満たす範囲で DEV 判断。

### Q3（#31・実装手段・DEV 精読後で 1 案確定＝churn 防止）: null 警告の解消手段の統一
- 解消手段（メソッド参照のラムダ化・局所的 `@SuppressWarnings("null")`・nullness アノテーション付与・当該診断 severity 調整）は AC を満たす範囲で DEV 選定。**複数案に割れたまま実装に入らず 1 案に確定**する（Sprint4 教訓）。**null 解析のグローバル無効化のみ禁止（AC4）**。挙動不変（AC2・`./gradlew test` GREEN）。

### Q4（#26・調査結果依存・DEV 調査後で確定）: 依存更新のトリガ基準
- AC3 は「EOL または重大 CVE が確認された依存は現行安定版へ更新／更新不要なら据え置き理由を明記」。実際に `mysql-connector-j:8.0.33 → 9.x` 等へ上げるかは**棚卸し調査の結果依存**。DEV が調査後に「更新する/据え置く」を判断し、更新する場合は `./gradlew build` + `./gradlew test`（Testcontainers 統合含む）GREEN を担保。**スコープは `jpetstore-database` の依存のみ（AC4・backend は対象外）**。

---

## 各 Issue の詳細（Issue Body 全文転記）

### #33 [bug] 保護ルートのリロード/直リンクでログイン済みでもサインオンに飛ばされる（認証ガードが再水和前に評価）

**ラベル**: bug ／ **SP**: 2 ／ **repo**: frontend ／ **branch（暫定）**: `fix/33-auth-guard-reachability`

#### 現象
ログイン済みでも、`meta.requiresAuth` の保護ルートを**リロード / URL 直打ち / ディープリンク**で開くと `/signon?redirect=...` にリダイレクトされる。飛ばされた signon 画面のヘッダーは「Hi, <username>」＝**認証済み**表示で、`GET /api/auth/me` も **200**（セッション有効）。つまり本当は認証できているのにガードが未認証と誤判定している。

#### 再現手順（2026-08-18 ライブ再現済み）
1. `demo_user` でログイン（ヘッダーが「Hi, demo_user」になる）。
2. ブラウザのアドレスバーで `http://localhost:5173/account/orders` を直接開く（またはリロード）。
3. → `/signon?redirect=/account/orders` にリダイレクトされる。ヘッダーは「Hi, demo_user」のまま・`GET /api/auth/me` は 200。
4. 参考: signon 画面で再度ログインすると redirect クエリでクライアント遷移し、`/account/orders` が正しく表示される（`GET /api/orders?page=1` → 200・注文1件表示）。＝機能自体は正常で、ハードロード時のガード誤判定のみが問題。

#### 根本原因
`jpetstore-frontend/src/main.ts` で `app.use(router)` が `await Promise.all([primeCsrfToken(), useAuthStore().fetchCurrentUser()])` **より前**に呼ばれている。vue-router は install（`app.use(router)`）時に初期ナビゲーションを開始しガードを走らせるため、**再水和（/api/auth/me）の完了を待つ前にガードが `isAuthenticated=false` で評価** → signon へ誘導する。`app.mount()` 前に await している意図（コメント「マウント前に /api/auth/me で再水和してから描画する(…ガード誤判定防止)」#24）が、router install が先に走るため効いていない。
（**SM 裏取り済 2026-08-18**: 現行 `main.ts` は `app.use(router)`=15行目・再水和 await=23行目で記述と一致。）

#### 影響範囲
全 `meta.requiresAuth` ルート: `/checkout`・`/checkout/complete`・`/account/orders`・`/account/orders/:orderId`・`/account`・`/account/password`。#7 チェックアウト・#9/#10 注文履歴/詳細・#14 アカウント編集・#15 PW変更が、リロード/直リンクでログイン済みでも使えない。注文履歴（#9/#10）は導線も無い（#34）ため URL 直打ちが唯一の到達手段で、本バグにより実質到達不能。

#### Acceptance Criteria
- [ ] AC1: 有効な JWT セッションがある状態で保護ルートをリロード/直リンク/ディープリンクしても、signon に飛ばされず当該ページが表示される。
- [ ] AC2: 未認証（Cookie 無効/期限切れ）の場合は従来どおり signon へ誘導し、`redirect` で元 URL に復帰する（回帰なし）。
- [ ] AC-neg1（否定AC）: `GET /api/auth/me` が 200 を返す状態で保護ルートを直リンクしても、signon へのリダイレクトが発生しない。
- [ ] AC3: 既存の Vitest（authGuard・SignonView の redirect 復帰）が回帰しない。

#### 修正案（実装時に DEV 判断）
`app.use(router)` を再水和 await の後に移す（＝ガード評価前に再水和を完了させる）等。プリフェッチ済みの identity でガードが正しく通ることを Vitest/実機で担保する。

---

### #34 [bug] ログイン後に注文履歴/アカウント設定への導線（ナビゲーションリンク）が無い

**ラベル**: bug ／ **SP**: 2 ／ **repo**: frontend ／ **branch**: #33 と同一ブランチ（`fix/33-auth-guard-reachability`・Issue 単位コミット）

#### 現象
ログイン後のヘッダーは **Home / Catalog / Cart ＋「Hi, <username>」＋ Sign Out** のみで、注文履歴（`/account/orders`）・アカウント設定（`/account`）・パスワード変更（`/account/password`）への**リンク/メニューが UI に一切存在しない**。URL 直打ちでしか到達できず、しかも直打ちは #33（認証ガードのレース）により signon に飛ばされるため、実質到達不能。

#### 再現手順（2026-08-18 ライブ再現済み）
1. `demo_user` でログイン。
2. ヘッダー・画面のどこにも注文履歴/アカウント設定へのリンクが無いことを確認（`AppHeader.vue` の認証時表示は挨拶＋Sign Out のみ）。
3. コード上も `/account/orders`（order-history）への参照はルート定義とページ内ページネーション（自己遷移）のみで、ナビゲーション導線が存在しない。

#### 根本原因
#9/#10（注文履歴一覧・詳細）・#14/#15（アカウント編集・PW変更）でページ・ルート・API は実装したが、**ヘッダー/アカウントメニューへの導線配線が漏れていた**。`AccountEditView.vue` は `/account/password` へのリンクのみ保持し、注文履歴やアカウント設定入口は未配線。

#### Acceptance Criteria
- [ ] AC1: 認証済み時、ヘッダー（またはアカウントメニュー）から**注文履歴（/account/orders）**と**アカウント設定（/account）**へ遷移できる。
- [ ] AC2: 未認証時はこれらの導線を表示しない（Sign In のみ）。
- [ ] AC3: 既存のヘッダーレイアウト・デザイントークン（`--jps-*`）・i18n キー構造（`domain.context.key`）に整合する（frontend-conventions）。
- [ ] AC4: 認証済み時は home ヒーローの「New Here?」→ `/register` 導線を非表示にする（未認証時のみ表示）。認証時ナビ整合の一部として本Issueで是正する。

#### 依存/順序
- **実装順は #33（認証ガードのレース修正）→ 本Issue（導線追加）を推奨**。#33 を先に直すと、追加した導線経由でもハードロード/リロード時に signon へ飛ばされず安定到達できる。

#### 備考
- Refinement（2026-08-18・PO）: AC4 を「認証済み時は New Here? を非表示」の確定ACへ昇格（当初の「要否確定」から #34 に畳む決定）。同一領域（AppHeader/認証時ナビ整合）のため本Issueに内包し低コストで是正する。

---

### #27 [frontend] tsconfig.app.json の非推奨 baseUrl オプションを解消する

**ラベル**: refactor ／ **SP**: 1 ／ **repo**: frontend ／ **branch**: #33 と同一ブランチ

#### ユーザーストーリー
**As a** フロントエンド開発者 **I want to** tsconfig.app.json の非推奨 `baseUrl` オプションを解消したい **So that** TypeScript 7.0 へのアップグレード時にビルド/型チェックが壊れず、開発時の非推奨警告ノイズをなくせる

#### 背景 / 発生している警告
`jpetstore-frontend/tsconfig.app.json` で「オプション 'baseUrl' は非推奨であり、TypeScript 7.0 で機能しなくなります」の警告が出ている。
- 現状 `baseUrl: "."` は path alias `@/* → ./src/*` の解決のためだけに使われている。
- `paths` の値は既に相対（`./src/*`）であり、TypeScript 4.1+ では `baseUrl` 無しでも tsconfig ファイル基準で解決される。
- 実行時の alias 解決は `vite.config.ts` の `resolve.alias`（`@ → ./src`）が独立して担っており、`baseUrl` 削除の影響を受けない。
- `src/` からの裸(bare)インポートは存在しない（全て `@/` alias 経由）ことを確認済み。

#### Acceptance Criteria
- [ ] AC1: `tsconfig.app.json` から `"baseUrl": "."` を削除し、`baseUrl` 非推奨警告が出ないこと（`ignoreDeprecations` による黙殺ではなく、根本的に解消する）。
- [ ] AC2: `@/*` path alias が引き続き機能し、型チェック（`vue-tsc` / `npm run type-check` 相当）がエラーなく通ること。
- [ ] AC3: `npm run build`（vite ビルド）が成功すること。
- [ ] AC4: 既存の Vitest テストが全て pass すること（alias 解決のリグレッションが無いこと）。
- [ ] AC5: 他の tsconfig（`tsconfig.json` / `tsconfig.node.json`）に `baseUrl` が無いことを確認済みであること（本Issueの対象は tsconfig.app.json のみ）。

#### スコープ境界
対象は `tsconfig.app.json` の `baseUrl` 削除のみ。`ignoreDeprecations` を足す対処療法は採らない（根本解消）。他の非推奨オプションのリファクタは対象外。

---

### #31 [backend] Null type safety 警告（ストリームのメソッド参照）を解消する

**ラベル**: refactor ／ **SP**: 1 ／ **repo**: backend ／ **branch**: `refactor/31-null-type-safety`

#### ユーザーストーリー
**As a** jpetstore-backend の開発者 **I want to** IDE（VS Code / Eclipse JDT）が出力する "Null type safety" 警告を解消したい **So that** 実装中の警告ノイズを減らし、本当に見るべき警告が埋もれないようにできる。

#### 背景 / 発生している警告（4ファイル・計6件）
| # | ファイル | 行 | 対象（件数） |
|---|---------|----|------|
| 1 | `application/service/CartApplicationService.java` | 154 | `Map.merge(..., CartApplicationService::addSaturating)`（BiFunction 引数1・引数2 = 2件） |
| 2 | `application/service/OrderApplicationService.java` | 172 | `reduce(BigDecimal.ZERO, BigDecimal::add)`（1件） |
| 3 | `domain/cart/Cart.java` | 53 | `map(CartItem::lineTotal)` ＋ `reduce(BigDecimal.ZERO, BigDecimal::add)`（2件） |
| 4 | `infrastructure/mybatis/cart/MyBatisCartRepository.java` | 75 | `toMap(StockAvailability::itemId, Function.identity())`（1件） |

**性質（スコープ判断の前提）**: Gradle ビルドは失敗しない（本 repo の Gradle lint は spotless のみ・null 解析ツール未導入）。この警告は Eclipse JDT LS（redhat.java 拡張）の null 解析が classpath 上の nullness アノテーションを自動検出して有効化している **IDE 診断**で、CI/ビルドを止めない。JDK 標準の関数型インターフェイス（`Function`/`BiFunction`）に対するメソッド参照で JDT の型推論制約に起因する **false-positive 寄り**の警告。

#### Acceptance Criteria
- [ ] AC1: 上表 4ファイル・6件の "Null type safety" 警告が、IDE（VS Code Problems パネル / Eclipse JDT 診断）で解消されていること。
- [ ] AC2: 挙動不変であること — 既存の Spock テスト（`./gradlew test`）が全て GREEN。特に Cart 小計計算・merge 数量合算・Order 合計計算のロジックが変わらないこと。
- [ ] AC3: `./gradlew spotlessApply` 実行後に差分が出ず、`./gradlew build` が成功すること。
- [ ] AC4: null 解析を**グローバルに無効化して警告を隠す対処は採らない**こと（`java.compile.nullAnalysis.mode` を `disabled` にする等）。将来の実 null 不整合を検出する能力を殺さない範囲で解消する。

#### スコープ境界
対象は上記 4ファイルの当該警告のみ。解消手段（ラムダ化・局所的 `@SuppressWarnings("null")`・nullness アノテーション付与・severity 調整）は AC を満たす範囲で DEV が選定してよい。**null 解析のグローバル無効化のみ禁止（AC4）**。他ファイルの警告掃討・null 解析ツールの Gradle 導入は対象外。

---

### #26 [E6] 依存の版currency見直し（mysql-connector-j 等・SBD-12）

**ラベル**: foundation / E6 ／ **SP**: 2 ／ **repo**: database ／ **branch**: `refactor/26-dependency-currency`

#### 背景
Sprint 1（#22 DB移行基盤）の security-reviewer 参考メモ（正式指摘ではない）を Retro で backlog 化。`jpetstore-database` の `mysql-connector-j:8.0.33` が現行メジャーライン（9.x 系）より古い。重大 CVE の確証はないが、**SBD-12（保守された現行版を使い EOL を排除・版固定）** の観点で見直す。

#### スコープ
- 対象は **`jpetstore-database` の依存のみ**（`runtimeOnly` / `testImplementation` の `mysql-connector-j`、Flyway / Spock / Testcontainers 等）。
- **`jpetstore-backend` の主要ランタイム依存の棚卸しは本Issue対象外**（必要が生じた時点で別Issueとして起票）。

#### Acceptance Criteria（Refinement 2026-08-18 確定）
- [ ] AC1: `jpetstore-database` の依存（`mysql-connector-j`・Flyway・Spock・Testcontainers 等）を棚卸しし、各依存の現行版・EOL 状況・既知の重大 CVE の有無を一覧化する（結果を Issue または PR に残す）。
- [ ] AC2: 各依存のバージョンが**固定指定（レンジ非固定・単一版ピン）**であることを確認する。レンジ指定があれば固定へ是正する。
- [ ] AC3: EOL または重大 CVE が確認された依存は現行の安定版へ更新し、更新後に `./gradlew build` と `./gradlew test`（Testcontainers 統合含む）が GREEN であること。更新不要と判断した依存は「据え置き理由」を Issue に明記する。
- [ ] AC4（スコープ境界）: 対象は `jpetstore-database` の依存に限定し、`jpetstore-backend` の依存には手を入れない。

#### 備考
優先度: **低**（現時点で稼働・テストに支障なし）。依存関係: なし。

---

## リスク・チャレンジ

- **リスク1（#33・実機到達性の検証困難）**: SPA のハードロード/リロード時のガード誤判定は **jsdom/Vitest だけでは再現しにくい**（Vue Router の install 時初期ナビゲーションと再水和 await の順序問題）。Vitest で authGuard の順序担保テストを組みつつ、**実機（`npm run dev` + ブラウザで直リンク/リロード）で AC1/AC-neg1 を確認**する。PO 傾向メモ「SPA 保護ルートの実機到達性が AC/受入検証から漏れやすい」に対応。
- **リスク2（#26・影響未確証・調査重め）**: `mysql-connector-j 8.0.33 → 9.x` へ上げると **Testcontainers 統合テストや Flyway 実行が壊れる可能性**。AC3 の GREEN 担保を必ず通す。更新の要否は「EOL/重大 CVE」を基準に判断し、不要なら据え置き理由を明記（無理に上げない）。
- **リスク3（cross-repo 3-repo）**: frontend（#33/#34/#27）・backend（#31）・database（#26）の 3 repo にまたがる。ただし各 Issue は単一 repo 完結で closes 分散は単純。frontend は 3 Issue を 1 ブランチに集約（Sprint55 方針・Issue 単位コミット）。
- **チャレンジ C1（frontend EOL/CRLF ノイズの恒久対策）**: `.gitattributes` 未整備により frontend の working-tree に CRLF ノイズ（`npm run format` 由来）が Sprint14/15/17 で再発（SM 要フォロー(2)・Retro Challenge 候補）。今スプリントは frontend 変更が多い（#33/#34/#27）ため**再発の可能性が高い**。DEV は実差分のみ選択 add で誤コミット回避を徹底しつつ、**`.gitattributes`（`* text=auto eol=lf` 等）の恒久対策を今スプリントで導入検討**する（Retro で採否判定）。
- **チャレンジ C2（モデル）**: 計画フェーズ=Opus（最上位 tier・最新版）／実装フェーズ=Sonnet（高速 tier）の tier 分離を継続（17 連続で有効）。

---

## ブランチ / PR / closes 方針

| repo | ブランチ | 対象 Issue | closes |
|---|---|---|---|
| frontend | `fix/33-auth-guard-reachability` | #33・#34・#27 | frontend PR に `closes #33` `closes #34` `closes #27` |
| backend | `refactor/31-null-type-safety` | #31 | backend PR に `closes #31` |
| database | `refactor/26-dependency-currency` | #26 | database PR に `closes #26` |

- 各 Issue が単一 repo 完結のため、各 repo の PR にその repo の Issue を `closes` で集約する（Related 分散は不要）。
- frontend 3 Issue は **1 ブランチに Issue 単位コミットで積む**（Sprint55 方針）。ブランチ名は最優先 bug の #33 を採用。
- 変更把握は各 repo で `git diff origin/main...[ブランチ名] --name-only`（origin/main 基準・Sprint4 教訓）。
