# Phase 4 L3 — セキュリティ回帰テスト（jpetstore-frontend / after）

> **目的**: フロントでしか検証できないセキュリティ観点（XSS 出力エスケープ・トークンの JS 保持・CSRF 転記・依存 CVE・バンドル混入・オープンリダイレクト/CSP 等）を、モダン版 SPA `jpetstore-frontend` に対して回帰判定する。特に backend L3（[`l3-security-regression-backend.md`](./l3-security-regression-backend.md)）が **frontend Discovery へ引き継いだ N12**（`languagePreference` に allowlist が無く任意文字列＝`<img onerror=…>` が永続化され `/api/auth/me`・`/api/account` で返る／SBD-18 の出力エスケープは SPA 側責務）を名指しで裏取りする。
> **担当**: SEC（security-lead）／ **日付**: 2026-08-19 ／ **姉妹レポート**: backend L3 `security/20260819_01/`
> **稼働環境（ライブ確認実施）**: frontend `http://localhost:5174`（Vite dev）・backend `http://localhost:8080`（`/api` proxy 経由）・開発資格情報 `demo_user`（userId=2 / `Sprint3-DemoLogin!26`）でログインして実測。Playwright で JS コンテキストのストレージ/クッキー/DOM を直接観測。
> **照合の枠組み**: [`spec/security-baseline.md`](../../spec/security-baseline.md)（SBD-3 CSRF / SBD-9 リダイレクト / SBD-12 依存 / SBD-15 Cookie / SBD-18 XSS）を after の満たすべき NFR、[`spec/intended-diff-ledger.md`](../../spec/intended-diff-ledger.md)（ID-6 SPA 化 / ID-15 description plaintext 化 / ID-31 テーマ 等）を「仕様どおりの変更（脆弱性ではない）」の宣言として使う。
> **原則**: 発見（Discovery）と検証（Verification）を分離。憶測で「消えた」と書かず、**コード位置**（`code`）または**実測**（`live`＝JS ストレージ/クッキー/DOM の実観測・HTTP応答・ユニットテスト）を根拠にする。台帳に載っている変更は仕様であり脆弱性として起票しない。

---

## 全体結論（サマリ）

| 重点項目 | 判定 | 一言 |
| --- | --- | --- |
| **1. XSS（SBD-18 / ID-15）** | **PASS** | 実コードに `v-html`/`innerHTML`/`dangerouslySet` 等の生 HTML sink は **0件**。description は `{{ }}` テキスト補間のみ。**backend N12 の永続 XSS ペイロードを SPA が allowlist で無害化することをライブ実証**（`<img onerror>`→canonical `'en'`・DOM 注入 0）。 |
| **2. トークン保管（SBD-15）** | **PASS** | ログイン後も localStorage/sessionStorage/JS 可読 Cookie に **JWT・機微情報は一切なし**（実測）。ACCESS/REFRESH は httpOnly（`document.cookie` に出現しない）。JS が保持するのは `user{username,roles}` のみ（メモリ）。 |
| **3. CSRF 転記（SBD-3）** | **PASS** | `XSRF-TOKEN` Cookie → `X-XSRF-TOKEN` ヘッダを非XORで転記。API 呼び出しは**すべて相対 `/api` 同一オリジン**＝外部オリジンへトークンを漏らす経路なし。double-submit のライブ疎通確認済。 |
| **4. 依存 CVE（SBD-12）** | **PASS**（残件1） | `npm audit` = **脆弱性 0**（info/low/mod/high/crit すべて 0）。全依存が現行版・EOL なし。残件は「知識期限後 advisory の live 照会」（backend §3.2 と対）。 |
| **5. バンドル混入** | **PASS** | `dist` に**ソースマップなし・秘密/内部URL/DB資格情報/JWT なし**。`.env` は gitignore かつ不在、`VITE_*` の秘密焼き込みなし。 |
| **6. その他（リダイレクト/rel/CSP/trace）** | **PASS（1 Low 所見）** | オープンリダイレクトは堅牢な allowlist で **2箇所とも**封鎖（SBD-9）。外部 `target=_blank` リンクは存在せず。エラー表示に内部パス/trace 露出なし。**CSP 不在のみ Low 所見**（§2 F1・防御多層/運用レイヤ）。 |

**新規 findings**: §2 参照。確定は **F1（CSP 不在・Low・防御多層/運用寄り）1件のみ**。SPA は secure-by-default が徹底されており、過大主張を避けるため「clean と確認した領域」を §2.3 に明示する。
**未対応（残存脆弱性）**: **0件**。

---

## §1 重点項目 1〜6 の判定（根拠つき）

### 1. XSS（SBD-18 / ID-15）— PASS

**判定**: 反射/格納 XSS の**実行 sink が SPA に存在しない**。ID-15（description の plaintext 化）の決定が実装で守られている。

- **生 HTML sink の全数確認（`code`）**: `src` 全走査で `v-html` / `innerHTML` / `domPropsInnerHTML` / `outerHTML` / `insertAdjacentHTML` / `document.write` / `dangerouslySet` は**実コードに 0件**（ヒットはコメントとテストのみ）。`eval` / `new Function` / 文字列 `setTimeout` も 0件。
- **description の描画経路（`code`）**: レガシーの HTML 内包列（`product.description`）は **テキスト補間 `{{ }}` のみ**で描画。
  - `views/catalog/ItemDetailView.vue:110` `<p>{{ catalogStore.currentItem.productDescription }}</p>`
  - `views/catalog/ItemListView.vue:61` `<p>{{ catalogStore.currentProduct.description }}</p>`
  - Vue のテキスト補間は既定でエスケープ（フレームワーク既定を無効化していない）。ユニットテスト `ItemDetailView.spec.ts` の `AC-neg1(SBD-18): descriptionにHTML/scriptタグを与えても生描画されず実行されない` が**green**（後述テスト実行）。
- **属性バインド sink（`code`）**: `:src` は `resolveCatalogImage()`（`utils/catalogImage.ts:25-30`＝**バンドル済みアセットか placeholder のみ**を返す／未知IDは placeholder）と静的 import（logo/hero）のみ。`:style` の `--hero-image` も静的 import。**ユーザー入力を載せる `:href` は無し**、`javascript:` スキームの動的束縛も無し。
- **backend N12 の引き継ぎ（`live`＝§2.1 で詳述）**: DB に永続化された `languagePreference = <img src=x onerror=alert(1)>` を SPA が **API 境界の allowlist で canonical 値 `'en'` に写像**して取り込むため、DOM/i18n の sink に生ペイロードが到達しない。稼働環境で **`onerror` img 注入 0・シリアライズ DOM に生ペイロード不在・alert 不発**を実測（下記 §2.1 N-F0）。
  - 経路: `stores/auth.ts`（signon/fetchCurrentUser）→ `stores/preferences.ts:73-79 hydrateFromDb` → `utils/preferencesMapping.ts:7-9 toCanonicalLanguage`（`'japanese'`→`'ja'`・**それ以外は一律 `'en'`**）／`preferences.ts:27-29 normalizeColorScheme`（`light`/`dark` 以外は `'system'`）。適用先は `applyLanguage`（i18n locale 文字列）と `applyColorScheme`（検証済み enum の `classList.add`）のみ。

### 2. トークン保管（SBD-15）— PASS

**判定**: **localStorage / sessionStorage / JS 可読 Cookie に JWT・機微情報を一切置いていない**。httpOnly Cookie 発行後に JS 側がコピー保持する決定違反も無し。

- **設計（`code`）**: `stores/auth.ts:30-33` — 「保持するのは `AuthenticatedUser`（username/roles）のみ…アクセストークン等は一切保持しない（httpOnly Cookie が保持し JS から触れない）。Pinia state はメモリ上のみで localStorage/sessionStorage へ永続化しない」。実装も state は `user`（メモリ）のみ、永続化コードは無い。
- **ストレージ書き込みの全数確認（`code`）**: `localStorage.setItem` の実書き込みは **2 用途のみ** — `utils/cartStorage.ts`（未ログインカート `jps.cart`）と `utils/preferencesStorage.ts`（`jps.colorScheme`/`jps.language`）。いずれも**トークンでも PII でもない**非機密な UI/カート状態。`sessionStorage`/`indexedDB` への書き込みは 0件。
- **ライブ実測（`live`）**: `demo_user` でログイン前後に JS コンテキストを直接観測 —

  | 局面 | `localStorage` | `sessionStorage` | `document.cookie`（JS 可読） | JWT/トークン名の露出 |
  | --- | --- | --- | --- | --- |
  | ログイン前 | `{jps.colorScheme, jps.language}` | `{}` | `XSRF-TOKEN=…`（CSRF用のみ） | なし |
  | **ログイン後** | `{jps.colorScheme, jps.language}` | `{}` | `""`（空） | **なし**（`anyJwtVisibleToJS=false`・`ACCESS/REFRESH/Bearer=不検出`） |
  | GET /api/ping 後 | 同上 | `{}` | `XSRF-TOKEN=…`（ローテート後） | なし |

  → **ACCESS_TOKEN / REFRESH_TOKEN は `document.cookie` に一度も現れない**＝httpOnly。XSS でトークンを盗ませない SBD-15 決定が実装で成立している。JS 可読なのは CSRF 用 `XSRF-TOKEN` のみ（double-submit 上必要・仕様）。

### 3. CSRF 転記（SBD-3）— PASS

**判定**: cookie-to-header double-submit が正しく実装され、トークンを外部オリジンへ漏らす経路がない。

- **転記実装（`code`）**: `api/httpClient.ts:26-32` が `XSRF-TOKEN` Cookie を固定名の正規表現で読み（インジェクション余地なし）、`:47-58` で**非冪等メソッド（POST/PUT/PATCH/DELETE）にのみ** `X-XSRF-TOKEN` ヘッダへ**生値のまま（非XOR・マスクなし）**転記。backend の `CsrfTokenRequestAttributeHandler`（非XOR）と整合。
- **外部オリジン漏えいの否定（`code`）**: `api/*.ts` の全リクエスト path は**相対リテラル `/api/...`**（path 変数は `encodeURIComponent`・keyword は `URLSearchParams`）。絶対 URL / 外部ホストは 0件。`fetch(path, {credentials:'include', headers})` は同一オリジンにしか飛ばず、`X-XSRF-TOKEN` が外部に載る経路がない。
- **自己修復 prime（`code`+`live`）**: 状態変更で XSRF Cookie が失効（consume-then-regenerate）した場合、`httpClient.ts:49-54` が `GET /api/ping` で再発行させてから送信。ライブでも「ログイン直後 `document.cookie` 空 → `GET /api/ping` 後に `XSRF-TOKEN` 再出現」を実測。**ログイン POST 自体が 200 で成立＝double-submit がエンドツーエンドで機能**している経験的証拠。
- **GET は非対象（`code`）**: `httpClient.spec.ts` の「GET は `X-XSRF-TOKEN` を付与せず `credentials:include`」green。

### 4. 依存 CVE（SBD-12）— PASS（残件1）

**判定**: 既知重大 CVE・EOL 依存なし。版固定も充足。

- **`npm audit`（`live`）**: `{"info":0,"low":0,"moderate":0,"high":0,"critical":0,"total":0}` — **脆弱性 0**。
- **版の現行性（`code`）**: `vue ^3.5.22` / `vue-router ^4.6.3` / `pinia ^3.0.4` / `vue-i18n ^11.4.8` / `vite ^7.1.11` / `typescript ~5.9` / `tailwindcss ^4.1` — いずれも保守された現行版で EOL なし。`engines.node ^20.19 || >=22.12`（LTS 系）。
- **版固定（`code`）**: `package.json` は caret レンジだが `package-lock.json` が正確版にロック（再現ビルド可）。レンジ由来の非再現リスクは lockfile で解消。
- **残件（§3-1）**: オフライン監査のため、知識期限後に公開された advisory の **live OSV/GHSA 照会**が望ましい（backend §3.2 と同性質）。

### 5. バンドル混入 — PASS

**判定**: ビルド成果物・ソースに秘密/内部 URL/デバッグ情報の混入なし。

- **ソースマップ（`code`）**: `dist` に `*.map` **0件**（本番構成でソース非開示）。
- **秘密/内部ホストの精査（`code`）**: `dist/assets/*.js` に対する精密 grep で `localhost:8080` / `127.0.0.1` / `jpetstore/jpetstore`（DB資格情報）/ `JWT_SECRET` / `-----BEGIN` / `Bearer <token>` / `eyJ…`（JWT）は**すべて不検出**。`password` のヒットは i18n ラベル・フィールド種別（`type:"password"`・`account.password.*` キー）のみ＝秘密ではない。
- **.env の扱い（`code`）**: `.env*` は `.gitignore` 済みかつリポジトリに**不在**。dev の backend 接続は `vite.config.ts` の proxy（`/api`→`localhost:8080`・dev 専用で成果物に非同梱）。秘密を焼き込む `VITE_*` 変数も無し。

### 6. その他（オープンリダイレクト / 外部リンク rel / CSP / trace 露出）

- **オープンリダイレクト（SBD-9）— PASS（`code`）**: `utils/redirectValidator.ts sanitizeRedirectTarget` が **path-absolute（`/…`）のみ許可**し、絶対 URL・プロトコル相対（`//evil`）・バックスラッシュ混在（`/\evil`）・先頭空白・C0 制御文字混入（`/\t/evil`）をすべて fallback `'/'` へ落とす（`redirectValidator.spec.ts` で各ケース green）。**復帰 URL を扱う 2 箇所とも**この検証を通す — `views/SignonView.vue:24`・`views/RegisterView.vue:86`（`router.push(sanitizeRedirectTarget(route.query.redirect))`）。`location.href`/`window.location`/`assign`/`replace(生URL)` の DOM リダイレクト sink は 0件。認可ガードも `router/index.ts:135 router.beforeEach(createAuthGuard())` で登録済（保護ルート 6 本に `requiresAuth`）。
- **外部リンク rel — N/A（`code`）**: `target="_blank"` の外部リンク・`window.open` は**存在しない**（アプリ内遷移は Vue Router のみ）。→ 現状 `rel="noopener"` を要する箇所が無い。将来外部リンクを追加する際は `rel="noopener noreferrer"` を付けること（§3-4 前向き指針）。
- **CSP — 不在（Low 所見 §2.1 F1）**: `index.html`/dev サーバとも Content-Security-Policy を送出しない。現状 XSS sink が無いため直接の被害はないが、防御多層が欠ける。**運用（本番プロキシ/エッジ）で付与する前提**（backend §3.4 の HSTS/CSP と同じ運用レイヤ責務）。
- **スタックトレース/内部情報の露出 — PASS（`code`）**: `HttpError.message`（`Request failed: POST /api/... (500)` ＝内部 API パスを含む）は**どのテンプレートにも描画されない**。ストア/ビューは HttpError を理由 enum（`USERNAME_TAKEN`/`INVALID_CURRENT_PASSWORD`/`VALIDATION_ERROR` 等）や boolean フラグへ写像し、表示は i18n 文言のみ（テンプレートの `.message` は `t('orderComplete.message')` の i18n キー 1 箇所のみ）。ブラウザ console には起動時 `GET /api/auth/me` 401（未ログイン再水和の想定挙動）と favicon 404 が出るが、機微情報・trace は含まない。

#### §1 付録 — ユニットテスト実行（回帰自動化の存在確認）

セキュリティ関連 spec を実行し **55/55 green**（回帰テストが自動化済であることの確認）:
```
✓ views/catalog/__tests__/ItemDetailView.spec.ts  … AC-neg1(SBD-18) XSS 非実行を含む (7)
✓ stores/__tests__/auth.spec.ts                    … signon成功時にトークン等をlocalStorageへ書かない
✓ utils/__tests__/redirectValidator.spec.ts        … 絶対/プロトコル相対/制御文字/javascriptスキーム拒否
✓ api/__tests__/httpClient.spec.ts                 … 非冪等POSTのみ生値X-XSRF-TOKEN転記・GETは非付与
Test Files 4 passed (4) / Tests 55 passed (55)
```

---

## §2 新規 Discovery（Discovery → Verification 分離）

**手法**: 6 攻撃面（XSS sink / トークン保持 / CSRF 転記 / 依存 / バンドル / リダイレクト・CSP・trace）をコード全走査で独立発見し、ライブ実測（JS ストレージ/DOM/HTTP・`npm audit`・`dist` 精査）で確定/反証。**ライブ PoC を最強証拠**とする（成功時は多数決を省略＝SEC 原則）。

**検証凡例**: `CONFIRMED(live)`=稼働環境の実観測で確証／`CONFIRMED(code)`=コード解析で確証／`REFUTED/降格`=Discovery の主張を検証が是正。

### §2.1 確定所見テーブル

| # | finding-key | 所見 | 重大度 | 検証 | 根拠(要約) |
| --- | --- | --- | --- | --- | --- |
| **N-F0** | `frontend:xss:languagepref-stored-payload-defanged`（＝backend N12 の frontend 側裏取り） | backend N12 が DB へ永続化した `languagePreference = <img src=x onerror=alert(1)>` を SPA が **API 境界 allowlist（`toCanonicalLanguage`→`'en'`）で無害化**。DOM/i18n の sink に生ペイロードが到達せず**実行不能**。→ **frontend に格納 XSS は成立しない（PASS の実証）** | **情報（実行不能を実証）** | **CONFIRMED(live)** | ログイン後・`/account` 表示後とも `img[onerror]` 注入 **0**・シリアライズ DOM に `onerror=alert` 不在・alert 不発。language `<select>` は canonical `'en'`（options `en`/`ja`）。`preferencesMapping.ts:7-9`／`preferences.ts:27-29,73-79` |
| **F1** | `frontend:hardening:missing-csp` | SPA が Content-Security-Policy を一切送出しない（`index.html` meta も dev サーバヘッダも無し）。現状 XSS sink が無いため直接被害はないが、将来 sink 混入時の**防御多層が欠落**。加えて `index.html` は FOUC 対策の**インライン `<script>`** を持つため、将来の厳格 CSP 導入時は hash/nonce 化が必要 | **Low**（防御多層・運用寄り） | **CONFIRMED(code)** | `index.html`（CSP 無・インライン script あり）／`vite.config.ts`（ヘッダ注入無）。backend §3.4（HSTS/CSP＝本番プロキシ責務）と同レイヤ。ID/SBD に CSP の明示要求は無いため過大評価しない |

> **起票判断**: **N-F0 は「clean の実証」であり脆弱性ではない**（Issue 化しない）。**F1 は Low の防御多層/運用寄り**で、backend §3.4 と束ねて「本番エッジで HSTS/CSP を付与」として PO/運用判断を仰ぐのが妥当（frontend 単体の欠陥として起票するか、運用受容とするかは §3 で残件提示）。**現時点で NEW として即起票すべき frontend 由来の脆弱性は無い。**

### §2.2 検証で反証・是正した Discovery（発見と検証を分離した効用）

- **「ログイン直後 `document.cookie` が空＝CSRF が壊れている」→ REFUTED**。検証: これは consume-then-regenerate による XSRF トークンのローテーション途中の状態で、`GET /api/ping`（httpClient の自己 prime）後に `XSRF-TOKEN` が JS 可読で再出現する。ログイン POST 自体が 200 で成立している＝double-submit は健在。backend §2.2 C1 と同じ現象で、サーバ欠陥ではない。
- **「`resolveCatalogImage` の id がユーザー制御なら `javascript:` src を作れる」→ REFUTED**。検証: `catalogImage.ts` は id からサフィックスを作り**バンドル済みアセットの既知 path 集合と照合**し、未一致は placeholder。返るのは常に既知アセット URL か placeholder で、生 URL・スキームは載らない。
- **「`readCsrfCookie` の `new RegExp(Cookie名)` にインジェクション」→ REFUTED**。検証: 名前は定数 `CSRF_COOKIE_NAME='XSRF-TOKEN'`（ユーザー入力ではない）。動的正規表現構築だが注入面なし。
- **依存 CVE → 指摘なし**。`npm audit` 0 件・現行版・EOL 無し（S20/S21 の frontend 側是正を確認）。

### §2.3 堅牢と確認した領域（過大主張回避のため明示）

コード＋実測の両面で clean と確認:
- **XSS 出力エスケープ（SBD-18/ID-15）**: 生 HTML sink 0・description は `{{ }}`・画像はバンドルアセット限定・N-F0 で格納 XSS の実行不能を実証。
- **トークン非 JS 保持（SBD-15）**: JS 可読な保存領域にトークン 0（実測）・auth Cookie は httpOnly。
- **CSRF（SBD-3）**: 非XOR 転記・非冪等のみ・同一オリジン限定・自己 prime。
- **オープンリダイレクト（SBD-9）**: 堅牢 allowlist を復帰 2 箇所とも通過・DOM location sink 無。
- **マスアサインメント（SBD-2・frontend 側の担保）**: `api/*.ts` の送信 DTO は allowlist フィールドのみ（`orderApi` は billing/shipping/useSeparateShipping のみ・`totalPrice`/`username`/`quantity` を持たない／`accountApi` register/update/changePassword は userid/status/version/WHO 列を送らない）。サーバ権威フィールドをクライアントから送る経路が構造的に無い。
- **依存/バンドル衛生**: audit 0・秘密混入 0・ソースマップ無・`.env` 非同梱。
- **認可ガード**: `beforeEach` 登録済・保護ルート 6 本に `requiresAuth`・未認証は signon へ退避（復帰 URL は検証つき）。

---

## §3 未確認・要追加検証の残件

1. **依存の知識期限後 advisory（`npm audit` の live 補完）**: オフライン `npm audit` は 0 件だが、Vite 7 / Vue 3.5 / vue-i18n 11 等は新しく、**live OSV/GHSA 照会**での最終確認が望ましい（SBD-12 の完全クローズ・backend §3.2 と対）。
2. **CSP / HSTS（F1・運用レイヤ）**: SPA は CSP を持たない。本番エッジ（リバースプロキシ/ホスティング）で **CSP・HSTS を付与**する前提。導入時は `index.html` のインライン FOUC script を **hash/nonce 許可**する必要がある（`'unsafe-inline'` で逃げると CSP の XSS 抑止効果が減じるため非推奨）。frontend 単体の欠陥として起票するか運用受容とするかは **PO/運用判断**（backend §3.4 と束ねて Sprint 化を推奨）。
3. **backend N12 の永続ペイロード残置**: `demo_user` の `languagePreference` に backend N12 PoC の `<img src=x onerror=alert(1)>` が**まだ DB に残っている**（本 run では frontend が無害化することの実測に活用しただけで、当該 DB 状態は SEC が作成したものではない）。frontend では無害だが、**根本原因の N12（backend の入力 allowlist 欠落）は backend Issue として起票対象**。data hygiene として当該行の正規化（`'english'` へ）を backend 修正時に併せて実施することを推奨。
4. **外部リンク追加時の rel（前向き指針）**: 現状 `target="_blank"` の外部リンクは無いが、将来追加する場合は `rel="noopener noreferrer"` を必須にする（reverse tabnabbing 防止）。
5. **本番ビルドの CSRF/Cookie は TLS 前提**: dev は http localhost のため Cookie の `Secure` 属性が実効化しない。本番 TLS 終端下で `Secure; HttpOnly; SameSite=Strict`（auth）／`Secure; SameSite=Strict`（XSRF・httpOnly=false）が効くこと自体は backend §1 S19 で確認済。frontend 側の追加検証は不要。

---

## 受け渡し（Patching）

本書は SEC の Find-and-Fix ループの「発見→検証」まで。**修正は行わない**。

- **frontend 由来の即起票すべき脆弱性は 0件**（SPA は secure-by-default が徹底）。

### 既存 `security` Issue 突合の結果（2026-08-19・ユーザー承認済み）

backend L3 findings は既に #38〜#44 として起票済み（全 open）。frontend L3 の triage 結果は以下（実施済み）:

| frontend 所見 | 判定 | 実施したアクション |
| --- | --- | --- |
| **N-F0**（languagePreference 永続 XSS を SPA が無害化＝clean の実証） | **KNOWN**（source は既存 #44 (B)） | **#44 にコメント追記**（[#issuecomment-5342193254](https://github.com/ryokkon624/jpetstore-manage/issues/44#issuecomment-5342193254)）— 出力側は安全・残る是正は backend 側入力 allowlist のみ・DB 残置ペイロードの正規化を推奨。新規 Issue は作成せず。 |
| **F1**（CSP/HSTS 未整備・Low・運用エッジ） | **NEW** | **[#45](https://github.com/ryokkon624/jpetstore-manage/issues/45) を新規起票**（`security` ラベル・`finding-key: frontend:hardening:missing-csp`・Project #2 追加・Ready=Draft）。backend §3.4（HSTS/CSP）と cross-repo で 1 件に束ねた。 |

- **backend N12（`languagePreference` 入力 allowlist 欠落・stored XSS の source）** は backend Issue **#44 (B)** として既起票。frontend は defense-in-depth で無害化済みだが、source を塞ぐのは backend の責務（#44 コメントで裏取りを記録）。
- **REGRESSION（既存 closed の再検出）**: 該当なし。

### 後始末（実施済み）
本 run のライブ確認は **GET リクエストとログインのみ**で、DB/ストレージへの新規状態作成は行っていない（§3-3 の `languagePreference` ペイロードは backend N12 の既存残置＝SEC 非作成）。ブラウザセッションはクローズ済み。
