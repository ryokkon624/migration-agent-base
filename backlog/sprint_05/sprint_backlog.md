# Sprint 5 バックログ

## スプリントゴール

**E6 フロントエンド・アーキ土台を立ち上げ、Vue3 SPA を Claude Design の "one system" で統一し、i18n 基盤・新規画像アセットを整え、secure-by-default な認証UI（サインオン/サインオフ・元URL復帰・プリフィル廃止・CSRF・トークン非JS保持）を実装する。**

Sprint 2（#23＝backend 土台）・Sprint 3（#18 login/logout・#19 bcrypt）・Sprint 4（#21 認可土台・#20 認証堅牢化）で backend の認証/認可を固めた上に、**フロントエンドの土台**を新規に立ち上げる。

- **#24 フロントエンド・アーキ土台（E6 基盤）**: Vue3 SPA を Claude Design（`spec/design/`）で統一（ヘッダ/カード/フォーム/ボタンを one system・ライト/ダーク）、**新規画像アセット**（nano banana 生成）を適用、**i18n 基盤**（英語のみ）を用意し、**認証UI**（API クライアント＋Pinia auth ストア／サインオン・サインオフ／元URL復帰の router ガード／プリフィル廃止）を secure-by-default で実装する。

これで **#18/#20 のフロント責務持ち越し（AC7＝サインオン/サインオフ UI・AC8＝元URL復帰・AC9＝プリフィル廃止）を消化**し、以降の全ドメイン画面（E1 カタログ〜E4 アカウント）を積むための実装土台を確立する。

**これは本プロジェクト初のフロントエンド・スプリント。** backend で 4 スプリント連続で有効だった tier 分離（計画=Opus／実装=Sonnet）・土台規律（土台 vs ドメイン実装の線引き）がフロントでも通用するかを検証する。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | 実装順 |
|-------|---------|-------|----|-----------|-------|
| [#24](https://github.com/ryokkon624/jpetstore-manage/issues/24) | [E6] フロントエンド・アーキ土台（Vue3 SPA / Claude Design / i18n基盤 / 画像アセット）を整備する | `foundation` / `E6` | 8 | `jpetstore-frontend` | ① |

**合計 8 SP**。Project #2 で **Sprint=5 / Ready / Story Points=8**。

> **リポジトリは cross-repo**（**計画フェーズのユーザー承認 2026-08-15 で確定**）: **主＝`jpetstore-frontend`**（AC 大半のフロント土台）／**従＝`jpetstore-backend`**（後述の `GET /api/auth/me` 追加のみ）。AC7/AC8/AC9 はフロント責務で、既存の呼び先（`/api/auth/login|logout|refresh`）は Sprint 3 #18 で確立済。**認証状態のリロード再水和のために `/me` を今スプリントで backend に追加する**判断（論点①）により cross-repo 化した。
> **ブランチ**: **両リポジトリに同名ブランチ `feature/24-frontend-foundation`**（各 `main` から分岐）。DEV は計画フェーズで確定済。
> **bug ラベルなし**（`foundation` / `E6`）＝計画フェーズでの Issue Body 更新（根本原因調査）は不要。
> **参考**: この migration-agent-base 側の Planning/Review 成果物は `feature/sprint5` ブランチにコミットし、Retro 完了時に PR＆マージする（ユーザー指示・2026-08-15）。実装コードの PR は `jpetstore-frontend`（主・`closes #24`）＋`jpetstore-backend`（従・`Related: #24`）の各 repo で SM が作成する。

---

## 承認済み計画（計画フェーズ・2026-08-15 ユーザー承認）

計画=Opus で整理し、下記3点をユーザー承認で確定（tier分離5連続）。

| 論点 | 決定 |
|---|---|
| ① 認証状態のリロード再水和 | **backend に `GET /api/auth/me` を今スプリント追加**（cross-repo 化）。認証済プリンシパルの `{username, roles}` を 200 で返す（未認証は既存 Security で 401・`anyRequest().authenticated()` 配下＝permitAll に入れない）。GET＝冪等・CSRF 不要。**フロントは起動時に `/me` を呼び identity を再水和**（200→Pinia セット／401→未認証）。access失効時のサイレントrefresh（AC7）も実装。※DEV 推奨は (b) メモリのみ＋持ち越しだったが、ユーザー判断で /me 追加＝リロード後も identity 表示を復元する方針に決定 |
| ② AC8 実証方式 | **router ガード＋復帰先バリデータを純関数 Vitest で網羅検証**。ライブの保護デモ画面は追加しない（消費者=保護ドメイン画面が未実装のため過剰実装回避）。保護画面は各ドメインStory で追加時に `meta.requiresAuth` で接続 |
| ③ AC3 画像スコープ | foundation で使う **hero.png / logo.svg に限定**（新規アセット使用の仕組みを確立）。product/category 24枚は各ドメインStory で取り込み（未使用アセット回避）。AC3 は「レガシー非継承・新規アセット使用」の仕組み確立で ◐ 部分達成 |
| FYI | design `main.css` の `.jps-required::after {content:'必須'}` は日本語ハードコード → 本スプリントでは `.jps-required` 装飾を使わない（疑似要素の i18n 化は将来課題） |

**確定事項**: ブランチ=`feature/24-frontend-foundation`（両 repo）／i18n=vue-i18n v11・英語のみ・`domain.context.key`／one-system=既存 `.jps-*` CSS 活用＋新規は `AppHeader`/`AppLayout` の2つのみ／作る画面=Home（i18n英語化）＋Signon＋Signoff（ヘッダアクション）のみ／CSRF=`GET /api/ping` で `XSRF-TOKEN` Cookie を prime→生値を `X-XSRF-TOKEN` へ（非XOR）。

---

## Issue #24 本文（転記）

### ユーザーストーリー

**As a** 開発チーム
**I want to** 一貫したデザインの Vue3 SPA 基盤を整えたい
**So that** 各画面を統一されたコンポーネント体系で実装できる

### トレース

- **Epic**: E6 横断：secure-by-default／基盤（ターゲットアーキ）
- **Feature**: E6 基盤 — フロントエンド・アーキ土台
- **spec**: spec/design/design-brief.md／spec/design/（Claude Design 出力）／spec/behavior/auth.md §2, §3, §6（AC7/AC8/AC9 認証UI 持ち越し分）
- **横断NFR**: SBD-15, SBD-18, SBD-3, SBD-9（AC8 元URL復帰）, SBD-6（AC6 一律メッセージ / AC9 プリフィル廃止）

### Acceptance Criteria

- [x] **AC1**: Vue 3 / TypeScript / Pinia / Tailwind CSS / Vite / Vitest の SPA 土台（jpetstore-frontend）。
- [x] **AC2**: **Claude Design で作成した全体デザイン**（spec/design/）を適用。ヘッダ/カード/フォーム/ボタンを one system で統一。ライト/ダーク対応。
- [x] **AC3**: 画像は **nano banana 生成の新規アセット**（spec/design/images/）を使用。レガシーの JSP/埋め込み画像・HTML は継承しない（SBD-18）。※計画フェーズ承認済み論点③のとおり、本スプリントは hero.png/logo.svg に限定（product/category 24枚は各ドメインStoryへ委譲）。
- [x] **AC4**: i18n 基盤（キー構造）を用意。翻訳は英語のみ・日本語は将来（PO決定）。
- [x] **AC5 (SBD-15)**: フロントは **トークンを JS に持たない**（localStorage 禁止・httpOnly Cookie 前提）。状態変更は明示ボタン＋CSRF（GET リンクで確定しない）。
- [x] **AC6 (SBD-6)**: ログイン失敗は一律メッセージ表示（ユーザ名を推測させない）。
- [x] **AC7 (#18 AC1 持ち越し / F5.1 サインオン・サインオフ UI)**: 認証UIを Vue3 SPA で提供（サインオン/サインオフ画面・JSPは無い）。API クライアント＋Pinia auth ストアが、ログイン→`POST /api/auth/login`、ログアウト→`POST /api/auth/logout`、access 失効時→`POST /api/auth/refresh`（いずれも Sprint 3 #18 で backend 提供済）を呼ぶ。CSRF は `XSRF-TOKEN` Cookie → `X-XSRF-TOKEN` ヘッダで送出（AC5 と一体・非冪等POST）。ストアは Vitest 必須。
- [x] **AC8 (#18 AC3 持ち越し / SBD-9 オープンリダイレクト対策)**: 保護ルート要求→ログイン→**元URLへ復帰**。Vue Router ガードで未認証時にログインへ誘導し、認証後に要求元へ戻す。**復帰先は相対パスのみ許可**（絶対URL・`//`・`/\` 等の外部/プロトコル相対は拒否＝オープンリダイレクト防止）。ルーターガード＋復帰先バリデータは Vitest 必須。
- [x] **AC9 (#20 AC1 持ち越し / SBD-6 既定資格情報プリフィル廃止)**: ログインフォームは既定資格情報（before `SignonForm.jsp` の j2ee/j2ee 等）を初期値にプリフィルしない。初期表示で username/password フィールドが**空**であることを Vitest で固定。before S10 の弱い既定資格情報プリフィルの是正（backend/シード側の弱資格排除は Sprint 4 #20 で達成済＝フロントは表示層の是正のみ）。
- [x] **AC-neg1 (否定AC / SBD-18)**: レガシー由来の生HTML描画面が存在しない。
- [x] **AC-neg2 (否定AC / SBD-9・AC8)**: 復帰先に外部URL/プロトコル相対（`//evil`・`https://evil`・`/\evil`）を与えても外部遷移しない（相対のみ許可）。

### 備考

- 優先順位の根拠: 全画面の実装土台。
- 依存関係: spec/design/design-brief.md／#23（E6.2・API/認証方式）／**#18（E5 サインオン・サインオフ・Sprint 3 で backend REST/認証確立済＝AC7/AC8 の呼び先）**／**#20（E5 認証堅牢化・Sprint 4 で backend 確立済＝AC9 プリフィル廃止の対）**。
- PO決定（Refinement 2026-08-11）: i18n 英語のみ＋基盤。
- AC7/AC8 は #18（Sprint 3）から、AC9 は #20（Sprint 4）からのフロント責務持ち越し。

---

## 実装の前提コンテキスト（SM調査メモ）

DEV は計画フェーズで以下を精査すること（SM が `jpetstore-frontend` の雛形と `jpetstore-backend` の auth 契約を実地調査した結果）。**AC1/AC2 の骨格は雛形で相当程度達成済み**で、実質の新規作業は **i18n・画像アセット・認証UI（AC7/8/9）・router ガード**に絞られる。

### 既達（雛形で達成済み・回帰として維持）

`jpetstore-frontend`（初回雛形＋Tailwind v4 導入済・2コミット）に以下が既にある：

| 資産（実在） | 状態 | #24 での扱い |
|---|---|---|
| `package.json`: Vue 3.5 / TypeScript 5.9 / Pinia 3 / **Vue Router 4** / Vite 7 / **Vitest 3** / @vue/test-utils / jsdom | **導入済** | **AC1 の骨格は充足**。i18n ライブラリのみ追加が要る |
| `src/assets/main.css`: デザイントークン `--jps-*`（テラコッタ×セージ×クリーム）・**ライト/ダーク**（OS追従＋`html.dark`/`html.light`）・`@layer` の `.jps-btn`/`.jps-badge`/`.jps-card` | **導入済** | **AC2 の基盤**。header/card/form/button の one-system を全体適用する土台 |
| Tailwind v4（`@tailwindcss/vite`・`main.css` 1行目 `@import 'tailwindcss';`・最小 `tailwind.config.js`） | **導入済** | AC1/AC2。CSS-first セットアップ |
| `src/views/HomeView.vue` ＋ `__tests__/HomeView.spec.ts` | **実装済** | AC1 の実装/テスト例。one-system 適用の起点 |
| `src/router/index.ts`（`/` → Home） | **実装済** | AC8 の router ガードを積む土台 |
| `vite.config.ts` dev proxy `/api` → `http://localhost:8080` | **導入済** | AC7 の API クライアントは相対パス `/api/...` を叩けばよい（CORS 回避） |
| `src/assets/`: `hero.png` / `logo.svg` | 一部あり | AC3。category/product 画像は `spec/design/images/` から取り込みが必要 |

### 未実装（本スプリントの新規作業）

- **AC2 の残り**: `spec/design/`（design-brief.md／main.css／standalone HTML）の one-system を **Home 以外にも全体適用**（共通レイアウト `AppHeader`/`AppLayout`・フォーム/ボタン/カードの共通部品）。
- **AC3**: `spec/design/images/`（category_*.png・product_*.png・hero.png・logo.svg・placeholder.svg）を frontend の assets へ取り込み。**レガシー JSP/埋め込み画像は継承しない**（SBD-18）。
- **AC4**: **i18n 基盤**（vue-i18n 等・キー構造・英語のみ）— 現状ライブラリ未導入＝完全に新規。日本語は将来（#25）。
- **AC5**: トークン非JS保持を**構造的に保証**（`localStorage`/`sessionStorage` にトークンを置かない・httpOnly Cookie 前提）＋状態変更は明示ボタン＋CSRF（GET リンクで確定しない）。
- **AC6**: ログイン失敗の**一律メッセージ**（ユーザ名を推測させない）。
- **AC7**: **API クライアント＋Pinia auth ストア**（login/logout/refresh 呼び出し）＋CSRF cookie-to-header＋**サインオン/サインオフ UI**。**ストアは Vitest 必須**。
- **AC8**: **Vue Router ガード**（未認証→ログイン→**元URL復帰**）＋**相対のみ許可の復帰先バリデータ**。**ガード＋バリデータは Vitest 必須**。
- **AC9**: **ログインフォームのプリフィル廃止**（初期表示で username/password が**空**）。**Vitest で固定**。
- **AC-neg1**: レガシー由来の生HTML描画面が存在しない（`v-html` 等でレガシー HTML を注入しない）。
- **AC-neg2**: 復帰先に外部URL/プロトコル相対を与えても外部遷移しない（相対のみ許可）。**Vitest で否定AC固定**。

### backend の auth 契約（DEV 向け・SM が `jpetstore-backend` を実地確認）

AC7 の呼び先は Sprint 3 #18 で確立済。契約は以下（`AuthController.java` / `SecurityConfig.java` で確認）：

| エンドポイント | メソッド | リクエスト | レスポンス | 備考 |
|---|---|---|---|---|
| `/api/auth/login` | POST | body `{ "username": string, "password": string }`（NotBlank） | **200** `{ "username": string, "roles": string[] }`／失敗は**一律 401**（誤PW・未知username 問わず・SBD-6 列挙不可） | 成功時 access/refresh を **httpOnly Cookie** にセット。`permitAll` |
| `/api/auth/logout` | POST | body なし・**credential 不要** | **204** No Content | access/refresh Cookie を即時失効。`permitAll` |
| `/api/auth/refresh` | POST | **refresh Cookie のみ**・credential 不要 | **204** No Content | access Cookie を再発行。`permitAll` |

- **CSRF**: backend は `CookieCsrfTokenRepository.withHttpOnlyFalse()`＝**`XSRF-TOKEN` Cookie（httpOnly=false＝JS 可読）**を発行。**非XOR の `CsrfTokenRequestAttributeHandler`**（マスクなし・raw トークン）を採用。→ **フロントは `XSRF-TOKEN` Cookie の生値をそのまま `X-XSRF-TOKEN` ヘッダに載せる**（マスク処理は実装しない）。非冪等 POST（login/logout/refresh）に付与。
- **トークンは httpOnly Cookie ＝ フロントは JS で触れない**。よって **AC5（トークン非JS保持）は backend の設計により構造的に充足**。フロントは Cookie を意識せず `credentials: 'include'`（同一オリジン proxy なので実質不要だが明示）で API を叩き、ログイン成功応答の `{username, roles}` のみを Pinia に**メモリ保持**する（localStorage には置かない）。

### ⚠️ 計画フェーズで確定すべき論点（DEV が整理 → ユーザー承認）

1. **認証状態のリロード再水和**: httpOnly Cookie はリロード後もブラウザが自動送信するが、**Pinia の `{username, roles}` はリロードで揮発する**。backend に **`/me` 相当（現在ユーザー取得）エンドポイントは存在しない**（login/logout/refresh のみ）。方針を確定すること：
   - (a) 起動時に `POST /api/auth/refresh` を試行し、204 なら「認証済」とみなし最小情報で UI 復元（ただし username/roles は取れない）／
   - (b) メモリ保持のみ＝リロードで UI 上はログアウト表示（Cookie は生きているが表示は未認証）／
   - (c) backend に `/me` 追加が必要と判断するなら**本スプリント scope 外＝持ち越しAC 化**（フロント土台は (a) or (b) で完結させる）。
   - → **backend 追加を伴わずフロント内で完結する範囲**を確定し、ユーザー承認を得ること。
2. **ブランチ名**（SM 提案 `feature/24-frontend-foundation`）。
3. **i18n ライブラリ選定**（vue-i18n 等）とキー構造（`frontend-conventions` の i18n キー構造規約に準拠）。
4. **one-system の適用範囲**＝土台としてどこまで共通コンポーネント化するか（`AppHeader`/`AppLayout`/フォーム/ボタン/カード）。
5. **本スプリントで作る画面の範囲**（下記スコープ境界を DEV が具体化）。

---

## ⚠️ スコープ境界（DEV が計画フェーズで線引きしユーザー承認を得ること）

**#23（backend 土台）の規律を踏襲＝土台 Story は「仕組み＋認証UI＋実証」に絞り、ドメイン画面は各 Story へ委譲する。**

| 含む（本スプリント） | 含まない（各 Story へ委譲） |
|---|---|
| SPA 土台の確立（AC1 骨格の仕上げ・i18n 基盤） | カタログ/検索の画面（E1・#1/#2/#3） |
| Claude Design の one-system 共通部品（AC2・ヘッダ/レイアウト/フォーム/ボタン/カード） | カート画面（E2・#4/#5/#6） |
| 新規画像アセットの取り込み（AC3） | チェックアウト/注文履歴/注文詳細（E3・#7〜#12） |
| 認証UI＝サインオン/サインオフ・auth ストア・API クライアント（AC7） | 登録/アカウント・プロフィール編集/PW変更（E4・#13〜#17） |
| router ガード土台＋元URL復帰バリデータ（AC8・AC-neg2） | 各ドメイン画面固有の状態管理・API 呼び出し |
| プリフィル廃止（AC9）・一律メッセージ（AC6）・トークン非JS保持（AC5・AC-neg1） | 日本語ローカライズ（#25・i18n は英語のみ） |

> **土台 Story の過剰実装を回避**（#23/#21 の教訓）。認証UI に必要な最小の共通レイアウト＋Home 以外のドメイン画面は作らない。各ドメイン画面（#1〜#17）は本土台の上に各 Story で積む。

---

## リスク・チャレンジ

| # | 種別 | 内容 | 対応 |
|---|------|------|------|
| R1 | リスク | **土台 Story の過剰実装**（ドメイン画面の先取り）。認証UIに必要な範囲を超えてカタログ/カート/注文画面を作ると E1〜E4 の各 Story を先取り＝スコープ逸脱 | 上記スコープ境界を計画フェーズでユーザー承認。「認証UI＋共通レイアウト＋Home」に絞る |
| R2 | リスク | **認証状態のリロード再水和**（`/me` 不在）。Pinia の `{username,roles}` はリロードで揮発し、backend に現在ユーザー取得 EP が無い | 計画フェーズで方針（refresh 試行／メモリのみ／持ち越し）を確定・ユーザー承認（論点①）。backend 追加が要るなら scope 外＝持ち越しAC 化。②c で PO 中継候補 |
| R3 | リスク | **CSRF cookie-to-header の非XOR前提の取り違え**。backend は raw トークン（非マスク）を要求。フロントが XOR マスクを実装すると 403 で全 POST 失敗 | backend は `CsrfTokenRequestAttributeHandler`（非XOR）＝**`XSRF-TOKEN` Cookie の生値をそのまま `X-XSRF-TOKEN` へ**。マスク処理を書かない（SM調査メモに明記） |
| R4 | リスク | **オープンリダイレクト（AC8/AC-neg2）＝復帰先バリデータの実装漏れ**。相対のみ許可の判定が甘いと `//evil`・`https://evil`・`/\evil` で外部遷移 | 相対パスのみ許可（絶対URL・`//`・`/\`・`http(s):` を拒否）を **Vitest で否定AC 固定**。バリデータを単体関数化して網羅テスト |
| R5 | リスク | **フロント DoD の未確立**（初のフロント Story）。テスト green だけでは型エラー・ビルド失敗・format 未実行を見逃す | DoD に `npm run test`（Vitest green）＋`npm run build`（vue-tsc 型チェック green）＋`npm run format` 実行を含める。backend 未起動でも Vitest は API モックで green にできる設計 |
| R6 | 好材料（非リスク） | **雛形が充実**（AC1 骨格・デザイントークン・ライト/ダーク・Home+test・router・vite proxy）＋**backend auth 契約が Sprint 3 で確立済**（呼び先 `/api/auth/*` が揃っている） | 新規実装を i18n・画像・認証UI・ガードに集中できる。既存雛形（デザイントークン・Home）を壊さず再利用 |
| C1 | チャレンジ | 計画フェーズを **Opus 4.8（1M context）** で実施し、#24 全AC＋`design-brief.md`＋backend auth 契約（AuthController/SecurityConfig）＋frontend 雛形を一括読解してスコープ境界（土台 vs ドメイン画面・認証状態再水和・i18n 選定・one-system 範囲）を先に確定 → 実装 Sonnet で手戻りなく完走。**初のフロント Story で tier 分離・土台規律がフロントでも通用するか検証**（backend で 4 連続実証済） | 計画フェーズを Opus で起動 |
| C2 | チャレンジ | **reviewer 観点の先回り**＝Sec に AC5（localStorage 非保持）／AC8・AC-neg2（オープンリダイレクト＝相対のみ許可）／AC7（CSRF cookie-to-header 非XOR）を否定AC で検証依頼。Conv に `frontend-conventions`（Flux 構造・カラートークン・i18n キー構造・テスト方針）準拠を、Perf に初回バンドル/画像最適化を | レビュー段で観点を具体指定（`frontend-conventions` skill 参照） |

**モデル**: Opus 4.8（1M context）が現行最上位 tier。計画=`opus`／実装=`sonnet` のエイリアスで各 tier 最新へ自動解決。新規モデル提案なし。

---

## Definition of Done

- 全 AC（AC1〜AC9・AC-neg1・AC-neg2）を満たす。
- **Vitest green**: auth ストア（AC7）・router ガード＋復帰先バリデータ（AC8・AC-neg2）・ログインフォームのプリフィル廃止＝空フィールド（AC9）を単体テストで固定。
- **`npm run build`（vue-tsc 型チェック）green**・**`npm run format` 実行**（`.claude/rules/git.md` のコミット前必須作業）。
- `frontend-conventions` skill 準拠（Flux 構造・カラートークン・i18n キー構造・テスト方針）。
- 3観点レビュー（規約/セキュリティ/パフォーマンス）指摘なし。
- レガシー由来の生HTML描画面が存在しない（AC-neg1）。
