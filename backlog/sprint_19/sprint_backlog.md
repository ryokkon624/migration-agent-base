# Sprint 19 バックログ

## スプリントゴール

**ユーザー嗜好（テーマ配色・表示言語）をヘッダーから即時切替でき、DB 権威で跨デバイス追従する「設定基盤」を確立し、あわせてトップ画面の開発用スロット撤去と EOL ノイズの恒久対策でフロントの完成度・開発体験を底上げする。**

- 中核は #36（テーマ切替）と #25（日本語ローカライズ）で、両者は**同一の設定永続機構**（ヘッダー設定コントロール＋localStorage 即時＋AccountEdit で DB 保存＋再水和で DB 権威適用）を共有する。**共有機構を一度作り、テーマと言語の両方へ適用する**方針。
- #37・#35 は独立の小粒（トップ画面デモスロット撤去／`.gitattributes` EOL 恒久対策）。

## 対象 Issue

| Issue | タイトル | ラベル | SP(Project) | repo |
|-------|---------|-------|-----|------|
| #36 | [frontend] テーマ（ライト/ダーク/システム連動）を切り替え・DB 保持できるようにする | feature | 5 | frontend(主)＋backend＋database |
| #25 | [i18n] 日本語ローカライズ（全画面 i18n リソース整備） | feature | 3 ⚠️再見積り | frontend(主)＋backend |
| #37 | [frontend] HomeView のデザイントークン確認スロットを削除する | refactor | 1 | frontend |
| #35 | [chore] frontend の EOL/CRLF ノイズ恒久対策（.gitattributes 導入） | refactor | 1 | frontend |

**合計 SP（Project 現在値）= 10。ただし #25 は Planning でユーザーが「完全実装（AC1-6 厳密）」を選択 → 実サイズ 5〜8 相当に拡大（下記 Q1）。実効合計は 13〜15 相当。SP=3 の再見積りを推奨（SP フィールド更新はユーザー操作）。**

---

## 横断確定事項（Planning 2026-08-18・AskUserQuestion 3 件をユーザー確定）

### Q1: #25 のスコープ = **完全実装（AC1-6 を厳密に）**
- ja.ts 全書き起こし（~160 キー/9 namespace/全 15 画面）＋ヘッダー言語切替 UI ＋ `numberFormats`/`datetimeFormats`（通貨/日付の ja 整形）＋**DB 権威での跨デバイス追従（Q2 の /me 拡張が前提）**＋全 15 画面のレイアウト崩れ検証。
- → #25 は **cross-repo 化（frontend＋backend）**。言語の DB 保存経路は既存 `languagePreference` フィールドで**完全配線済（database 変更不要）**だが、再水和適用のため backend /me 拡張を伴う。

### Q2: 再水和適用方式 = **`/api/auth/me` を拡張**（#36・#25 共通）
- `/api/auth/me` の DTO に `colorSchemePreference`（＋ `languagePreference`）を追加して返す。
- ログイン/再水和（`fetchCurrentUser`）完了時に **/me が返す嗜好値を単一ソースで適用**し localStorage へ seed（DB 権威・跨デバイス追従）。
- **1 回の backend 変更で #36（テーマ）と #25（言語）の両方をまかなう**（`AuthUserResponseDto` にテーマ・言語の両嗜好を追加）。

### Q3: FOUC 対策（#36 AC4）= **index.html にインライン head script**
- `index.html` の `<head>` に同期インラインスクリプトを追加し、`localStorage` のテーマを**描画前**に `<html>` の `.dark`/`.light` へ適用（ちらつき無しを確実に満たす）。
- main.ts での適用はモジュール download/parse 後になりちらつきリスクがあるため不採用。

### 計画フェーズ追補（DEV recon 裏取り＋ユーザー確認確定・2026-08-18）

DEV（Opus）が recon(path:line)を 3-repo 実コードで全裏取り。backlog 前提の 5 件を修正・確認 2 件をユーザー確定。

**recon 裏取り修正（実装事実）:**
- **A1**: backend 拡張対象は `AuthUserResponseDto`（不在＝frontend TS interface 名）ではなく **`AuthController.LoginResponse(username, roles)`**（/me・/login が共有）。1 変更で両方に効く。
- **A2**: stateless JWT ゆえ **login() 中は SecurityContext 未populated → `currentUserProvider` 不可**。prefs 取得は **`getPreferences(Long userId)`**（login は返却 userId を渡す・/me は currentUserProvider 由来 userId）。
- **A3**: register は backend **無変更**（insertProfile が色列非列挙・`NOT NULL DEFAULT 'system'` で自動 system）→ #36 backend threading **6→5 箇所**。`ProfileRegistrationCustomEntity` 無変更。
- **A4**: 通貨は全画面インライン Intl（`n(price,{style:'currency',currency:'USD'})`）でロケール連動 → **numberFormats 冗長**。
- **A5**: 日付は backend `LocalDate` の ISO 文字列を無整形表示（`OrderHistoryView`/`OrderDetailView` の `{{ order.orderDate }}`）。

**共有機構（確定）**: `usePreferencesStore`（Pinia 単一ソース）＝state `colorScheme`/`language`・localStorage 2 キー `jps.colorScheme`/`jps.language`・`init()`（不正/未知→System/'en' フォールバック＝#36 AC-neg1/#25 AC5）・`setColorScheme`/`setLanguage`・`hydrateFromDb()`（DB 権威・/me/login 後）。共通=ヘッダー同型ドロップダウン部品（open/close・click-outside・aria/keyboard 新規）。**個別（非対称）**: apply primitive（テーマ→`<html>` `.dark`/`.light`／言語→`i18n.global.locale`）・**FOUC はテーマ専用**（言語は createI18n 時に localStorage から locale seed＝head script 不要）・DB 値マッピング（言語 `english/japanese` ↔ canonical `en/ja` を API 境界で相互変換／テーマ pass-through）。

**/me・/login 拡張（確定）**: backend `AccountRepository.findPreferencesByUserId(userId)`＋`AccountApplicationService.getPreferences(Long userId)`（readOnly・m_profile 軽量 SELECT・新 read-model）→ `AuthController` 注入で `LoginResponse` 拡張。frontend authApi login/fetchCurrentUser を `{user, preferences}` 返却へ→auth store が `hydrateFromDb`→main.ts 既存 `await Promise.all`(:22) 内で mount 前解決（ブート順契約 main.spec.ts #33 不変）。

**確定事項（ユーザー確認）:**
- **Q-1 = 最小-正**: `datetimeFormats.ja` 追加＋`OrderHistoryView`/`OrderDetailView` の日付 2 箇所を `d()` 整形へ変更。**通貨はインライン Intl 維持**（既にロケール連動）。numberFormats 名前付き設定は入れない（冗長）。
- **Q-2 = パリティ**: ヘッダーをテーマ/言語の主コントロール化＋AccountEdit の既存言語 select を store へ rebind、**さらに AccountEdit にテーマ select も明示追加**（テーマ・言語とも「ヘッダー＋AccountEdit」両方で編集可＝対称）。
- **register 既定（確定）**: ゲストの localStorage 選択を保持・登録フォームにテーマ/言語欄なし・prefs 適用は /me と /login のみ（backlog E5 準拠）。

**Bean Validation**: `AccountEditRequest.colorSchemePreference` は `@Pattern(regexp="^(system|light|dark)$")`（enum 固定・Size20 整合）。

---

## cross-repo ブランチ / closes 戦略（Sprint 55 方針＝1 repo 1 ブランチ・Issue 単位コミット）

- **ブランチ名（3 repo 同名）**: `feature/36-user-preferences-i18n`
  - frontend: #36 テーマ／#25 i18n／#37 スロット撤去／#35 .gitattributes を **Issue 単位コミットで 1 ブランチに積む**。
  - backend: #36 の `AccountEditDetail`/`colorSchemePreference` スレッディング ＋ #36/#25 共通の `/api/auth/me` 拡張。
  - database: #36 の `V00_000_013__...color_scheme_preference`（#25 は database 変更なし）。
- **closes 配分**（各 Issue の capstone repo に集約）:
  - frontend PR: `closes #36`, `closes #25`, `closes #37`, `closes #35`（テーマ/言語 UX の capstone・トップ撤去/EOL は frontend 完結）
  - backend PR: `Related: #36`, `Related: #25`（従・DTO 拡張）
  - database PR: `Related: #36`（従・Flyway 列追加）
- **#35 の運用注意**: `.gitattributes` 追加＋`git add --renormalize .` は EOL のみの一括変更を生む。**#35 を frontend ブランチの早い段階で独立コミット**し、後続の feature 差分を LF クリーンにする（reviewer には「AC-neg1: EOL 変更のみ・意味的差分なし」を明示）。
- sprint-start commit（reviewer スコープ用）: frontend `04bef1a` / backend `d9a4623` / database `641afc5`（Sprint 18 マージ後の main）。

---

## 各 Issue 詳細

### #36 [frontend] テーマ切替・DB 保持（feature・主=frontend / 従=backend・database）

#### ユーザーストーリー
- **As a** JPetStore を利用するユーザー（未ログイン／ログイン済みの双方）
- **I want to** 画面の配色をライト／ダーク／システム連動から選んで切り替え、その選択が記憶される
- **So that** 好みや利用環境（OS のダークモード・時間帯・目の負担）に合わせて快適に閲覧できる

#### スコープ / 方針（Refinement 確定）
- **切替 UI**: `AppHeader.vue` のアカウントクラスタ内に**アイコン＋ドロップダウン**（Light / Dark / System の 3 択・未ログインでも表示・操作可）。
- **既定値**: `System`（main.css の OS 追従挙動と一致）。
- **永続方式**: ヘッダー選択で即時適用（`<html>` の `.dark`/`.light` 付替え）＋ `localStorage` 保存（全ユーザー端末ローカル）。ログイン済みは AccountEdit 保存（既存 `PUT /api/account`）時に `m_profile` 新規列へ反映。ログイン/初期化時は DB 値を権威に適用し localStorage へ seed（**Q2＝/me 拡張で実現**）。

#### Acceptance Criteria
- **AC1**: ヘッダーのアイコン＋ドロップダウンから Light/Dark/System を選択でき、選択が即座に全画面へ反映（`<html>` クラス切替でトークン参照 UI が一斉追従）。
- **AC2**: System 選択時は OS の `prefers-color-scheme` に追従し、OS 設定のライブ変更にも追従（`.dark`/`.light` を付けない状態）。
- **AC3**: 既定値は System。保存値なし（初回）は System として表示。
- **AC4**: 選択は `localStorage` に保存されリロード・再訪で維持（未ログインでも有効）。適用は**初回描画前**（**Q3＝index.html インライン head script**）で FOUC を起こさない。
- **AC5**: ログイン済みの選択は AccountEdit 保存（`PUT /api/account`）時に `m_profile` 新規列へ永続化され `GET /api/account` で読み出せる。
- **AC6**: ログイン／再水和（`fetchCurrentUser`）完了時に DB 値を適用し localStorage へ反映（DB 権威・跨デバイス追従）。**Q2＝/api/auth/me 拡張で /me から取得して適用**。
- **AC7（backend）**: `AccountEditDetail`/DTO に `colorSchemePreference`（enum: system/light/dark）を追加し `GET/PUT /api/account` の往復に含める（allowlist バインド・本人固定・version 楽観ロックは既存踏襲）。
- **AC8（database）**: `m_profile` に `color_scheme_preference VARCHAR(20) NOT NULL DEFAULT 'system'` を Flyway 新規（**V00_000_013**）で追加。既存行はデフォルト system で埋まる。
- **AC9（回帰）**: 既存 Vitest／`vue-tsc`／`npm run build`、backend/database 既存テストが回帰しない。
- **AC-neg1**: `localStorage`／DB に不正・未知の値が入っていた場合は System にフォールバックし例外で描画が壊れない。

#### 計画前 recon（実装ノート・path:line は recon 時点）
- **ダークトークン完備 ✓**: `frontend/src/assets/main.css` に3モード（`:root` ライト:29-153／`:root.dark`:172-290／`@media prefers-color-scheme` OS追従:294-383）。`.bg-jps-*`/`.text-jps-*` は全て CSS 変数参照 → `<html>` クラス切替で全 UI 再テーマ・**新規配色不要**。ヘッダーコメント(:6-10)に `.dark`/`.light` 上書き戦略明記。
- **FOUC 未実装 → 新規**: `index.html`(13行) に pre-paint script 無し・`<html lang="ja">`。`main.ts` は `createApp→pinia→i18n→await Promise.all([primeCsrf, fetchCurrentUser])(:22)→app.use(router)(:27)→mount(:29)`。**AC4 は index.html の `<head>` 同期インライン script で実現**（Q3）。
- **AppHeader dropdown 皆無 → 完全新規部品**: `AppHeader.vue` の `.app-header__account`(:62-81) は flat RouterLink＋button のみ。repo 全体に再利用 dropdown/menu/popover 無し。**open/close・click-outside・aria/keyboard を新規実装**。
- **langpref テンプレは read/store/persist のみ・apply 半分は不在**: front `domain/account.ts:52`・`api/accountApi.ts:46-60,93,135-163`・`stores/account.ts:41-115`・`AccountEditView.vue:36,66,97,147-155`。i18n は en 固定で locale 適用コード皆無 → **テーマの `<html>` 適用配線は新規**。
- **backend スレッディング点（6 箇所・parallel to languagePreference）**: `presentation/rest/AccountController.java`（`AccountEditRequest`:119-150 / `AccountEditResponse`:153-183）・`AccountEditCommand.java` / `AccountUpdate.java` / `domain/account/AccountEditDetail.java`・`AccountApplicationService.updateAccount`（AccountUpdate 構築 ~99-113・応答再構築 118-131・**再SELECT なし**）・`AccountEditCustomEntity.java`（read）/`ProfileUpdateCustomEntity.java`（update）（＋登録デフォルトなら `ProfileRegistrationCustomEntity`）・`resources/mapper/custom/AccountEditCustomMapper.xml`（findByUserId SELECT に `p.color_scheme_preference AS colorSchemePreference`／updateProfile に `color_scheme_preference = #{...}`）。Bean Validation の Size は DB 列幅(20)に整合。**＋ `/api/auth/me`(`AuthUserResponseDto`) にも colorScheme/language を追加（Q2）**。
- **database**: `V00_000_004__create_account_tables.sql:76-94` に m_profile（`language_preference VARCHAR(80) NOT NULL`:78）。色列なし。最新 = `V00_000_012` → **次は V00_000_013**。

#### 意図的設計（reviewer churn 防止・「欠落」として指摘しない）
- 新規配色トークンは追加しない（main.css 既存を流用）。
- テーマ即時適用は `<html>` クラス切替のみ（コンポーネント個別スタイル改変なし）。
- 未ログインの DB 保存経路は作らない（localStorage のみ・DB 反映は AccountEdit 保存時）。
- 専用軽量エンドポイント `PUT /api/account/preferences` は**作らない**（Refinement で見送り・将来 Issue）。
- 登録フォーム（#13）にテーマ入力欄は設けない（既定 system）。

#### 意図差分台帳
- テーマ切替はレガシー（JSP）非存在の純新規 UX。**着手時に `spec/intended-diff-ledger.md` 追記要否を DEV/PO で判定**（#36 備考）。

---

### #25 [i18n] 日本語ローカライズ（feature・主=frontend / 従=backend）— **完全実装（Q1）**

#### ユーザーストーリー
- **As a** 日本語で利用したいユーザー
- **I want to** 全画面の UI 文言・メッセージ・数値/日付フォーマットが日本語で表示される
- **So that** 日本語環境でも自然に JPetStore を利用できる

#### Acceptance Criteria
- **AC1**: 日本語メッセージリソース（i18n キーの ja 翻訳）を**全画面分**整備する。
- **AC2**: UI 文言（ラベル・ボタン・バリデーション/エラーメッセージ）を日本語化する。
- **AC3**: 日本語ロケールでの数値・日付・通貨フォーマットが適切に表示される（**`numberFormats`/`datetimeFormats` を新規設定**）。
- **AC4**: m_code 由来の区分値表示は日本語表示される（**在庫バッジ等は既存 `catalog.stockStatus.*` i18n キー経由 → ja 値追加で自動日本語化。`display_name_ja` 機構は frontend 不要**）。
- **AC5**: 言語切替（**ヘッダー言語切替 UI＋profile.langpref**）で日英が切り替わり、未翻訳キーの英語フォールバックが壊れない。
- **AC6**: 主要画面で日本語表示を検証（文言はみ出し・レイアウト崩れがない）＝**全 15 画面 QA**。
- **AC7（追加・Q2）**: 再水和時に DB の言語嗜好を適用（`/api/auth/me` 拡張で取得・DB 権威・跨デバイス追従）。

#### 計画前 recon（実装ノート）
- **en のみ・ja.ts 皆無**: `src/i18n/index.ts`（`legacy:false`・`locale:'en'`・`fallbackLocale:'en'`・`messages:{en}` のみ・numberFormats/datetimeFormats 無し）。`locales/` は `en.ts` 1 ファイルのみ。**~160 leaf キー/9 namespace（app/home/catalog/auth/account/cart/checkout/orderComplete/order）を ja.ts へ全書き起こし**（`en.ts` は `as const`・shape をミラー）。
- **i18n 利用範囲**: 22/26 コンポーネント・全 15 ビュー・228 箇所。
- **言語切替 UI 皆無 → 新規**: `i18n.global.locale` を書き換えるコードがアプリ内に無い（locale は 'en' ハードワイヤ）。**ヘッダーに言語切替 UI（#36 テーマドロップダウンと同型の設定コントロール）を新規追加**し locale を mutate。
- **langpref 保存経路は既存・apply が不在**: AccountEdit の `languagePreference`（english/japanese select・`AccountEditView.vue:143-154`）は DB 保存されるが locale に未適用。**保存経路は backend/database 変更不要**（`m_profile.language_preference` 既存・DTO 既存）。**再水和適用のみ Q2＝/me 拡張が必要**。
- **m_code**: 在庫は `utils/stockBadge.ts` が `catalog.stockStatus.*`（`en.ts:67-72`）にルーティング → ja 値追加で自動日本語化。カテゴリ chip/card は backend 供給 name（i18n 非経由）。

#### 意図的設計（reviewer churn 防止）
- カテゴリ/商品名など backend 供給の実データ文言は i18n 対象外（既存どおり）。
- `display_name_ja` 列/機構は frontend に新設しない（i18n キー経由で足りる）。
- 言語の DB 保存に新規 backend/database 変更は入れない（既存 langpref フィールド流用）。/me 拡張のみが backend 変更。

#### 意図差分台帳
- 出典 = 意図差分台帳 **ID-27**（i18n）。翻訳リソース整備が主眼で新規観測差分は基盤側に無いが、ヘッダー言語切替 UI の追加は純新規 UX → **着手時に ID-27 との整合・追記要否を DEV/PO で判定**。

---

### #37 [frontend] HomeView デザイントークン確認スロット削除（refactor・frontend）

#### ユーザーストーリー
- **As a** JPetStore の開発者 / **I want to** HomeView のデザイントークン確認スロット（#24 の名残）を削除 / **So that** 実ユーザー向けトップに開発用 UI が露出せず画面が整う

#### Acceptance Criteria
- **AC1**: HomeView からトークン確認スロット（`.tokens` セクション）を削除しトップがヒーロー領域のみになる。
- **AC2**: 未使用になった `.tokens*` scoped CSS と i18n キー `home.tokens.*` を撤去（デッド CSS/未使用キーを残さない）。
- **AC3**: `catalog.stockStatus.*` 等の他画面使用中キー・トークンクラスに影響しない（誤削除しない）。
- **AC4**: 既存 Vitest／`vue-tsc`／`npm run build` が回帰しない。

#### 計画前 recon（実装ノート）
- 撤去対象: `HomeView.vue:40-51`（template `<section class="tokens ...">`）／`HomeView.vue:126-144`（`.tokens__title`/`.tokens__desc`/`.tokens__row` scoped CSS・他 `.tokens*` 無し）／`en.ts:35-38`（`home.tokens.title`/`.desc`・`home:` 配下）。`home.tokens.*` は HomeView 以外**未使用**（撤去安全）。
- **温存必須**（誤削除しない）: `catalog.stockStatus.*`（`en.ts:67-72`）＝`stockBadge.ts`・catalog/cart/checkout の `StockBadge.vue` で load-bearing／`badge-jps-stock-*`（`main.css:583-598`）／`jps-badge`。
- `HomeView.spec.ts`（3 テスト）は tokens 非参照 → 破壊なし。

---

### #35 [chore] frontend EOL/CRLF ノイズ恒久対策（.gitattributes 導入）（refactor・frontend）

#### 背景
`npm run format`（Prettier）後に working-tree が EOL（LF↔CRLF）差分で大量 `M` 表示される現象が **Sprint 14/15/17/18 で 4 回連続再発**（Windows `core.autocrlf=true` × Prettier LF 出力）。実内容差分ゼロだが誤コミット・main 同期失敗リスク。SM Challenge（要フォロー(2)起票トリガ到達）。

#### Acceptance Criteria
- **AC1**: `jpetstore-frontend` に `.gitattributes` を追加しテキストの EOL を LF に正規化する設定を入れる。
- **AC2**: `git add --renormalize .` 実行後、`npm run format` を実行しても `git status` に EOL のみの `M` ノイズが出ない。
- **AC3**: 既存 Vitest・`npm run build`・`vue-tsc` が回帰しない。
- **AC-neg1**: 一括正規化コミットが実コードの意味的差分を含まない（EOL 変更のみ）。

#### 計画前 recon（実装ノート）
- `.gitattributes`・`.editorconfig` とも**不在**。`.prettierrc.json` は `endOfLine` 未設定 → Prettier 既定 **LF**（`prettier@^3.9.6`）。**`* text=auto eol=lf`（＋必要に応じ拡張子別）で Prettier 既定と整合**。
- **運用**: frontend ブランチの早い段階で `.gitattributes` 追加＋`git add --renormalize .` を**独立コミット**し、後続 feature 差分を LF クリーンに保つ。

---

## リスク・チャレンジ

- **R1（スコープ）**: #25 完全実装＋#36 で **cross-repo 3-repo・実効 13〜15SP** 相当。Sprint 過去最大級（#23=13SP に匹敵）。#25 SP=3 の**再見積り推奨**（ユーザー操作）。設定基盤（#36/#25 共有機構）を先に固め、翻訳リソース（~160 キー ja）はボリューム作業として並行。
- **R2（共有機構）**: #36/#25 は同一の設定永続機構を共有。**共通コンポーザブル/ストア（例 preferences store）を 1 本作りテーマ・言語の両方へ適用**する設計を DEV 計画で確定（二重実装を避ける）。/me 拡張は 1 回で両嗜好を返す。
- **R3（backend cross-repo の後出し防止）**: /me 拡張（`AuthUserResponseDto`）と AccountEditDetail の `colorSchemePreference` スレッディングは計画フェーズで確定済み。reviewer プロンプトに意図的設計を明記。
- **R4（EOL 運用）**: #35 の renormalize を早期独立コミット化。SM の local main 同期は `git checkout -f main` 併用（Sprint 14 教訓）。
- **C1（Challenge・恒久対策）**: #35 で 4 回連続再発の EOL ノイズを恒久解消（要フォロー(2)のクローズ）。
- **C2（tier 分離 19 連続）**: 計画=Opus（本 Planning で論点確定済）／実装=Sonnet。cross-repo・設定基盤でも手戻りゼロ完走を狙う。
- **C3（実機検証）**: #36 テーマ FOUC・#25 言語切替は Vitest で拾いにくい実機挙動 → 主要画面の実機目視（ちらつき無し・言語切替・跨デバイス追従の再水和）を DoD に含める。

---

## 計画前調査（recon）サマリ
- 3 本並列 Explore（#25 i18n 実態／#36 3-repo 前提／#37・#35）で「既達 vs 未実装」を確定。
- 主要発見: ①ダークトークン完備（配色新規不要）②langpref は保存のみで apply 不在（テーマ/言語とも適用配線は新規）③/me は {username,roles} のみ（再水和適用に /me 拡張が必要）④ヘッダーに再利用 dropdown 皆無（切替 UI は新規部品）⑤ja.ts 皆無（~160 キー全書き起こし）⑥#37/#35 は小粒・前提クリア。
