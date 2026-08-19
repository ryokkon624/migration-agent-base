# Phase 4 L3 — セキュリティ回帰テスト（jpetstore-backend / after）

> **目的**: before ベースライン（[`reports/before/baseline-summary.md`](../before/baseline-summary.md)）の確定 findings（Struts run `_02` = S1〜S21）を、モダン版 `jpetstore-backend` に対して **1件ずつ名指しで** 回帰判定し、「消えたこと」を実証する（問1）。加えて after で新たに生まれた攻撃面に作り込まれた脆弱性が無いかを Discovery→Verification で探す（問2）。
> **担当**: SEC（security-lead）／ **日付**: 2026-08-19 ／ **run**: `security/20260819_01/`
> **稼働環境（ライブPoC実施）**: backend `http://localhost:8080`・frontend `http://localhost:5174`・MySQL docker `dev-jpetstore-db`（mysql:8.4.0, 127.0.0.1:3306）。開発資格情報 `demo_user`（userId=2）でログインして実測。
> **照合の枠組み**: [`spec/security-baseline.md`](../../spec/security-baseline.md)（SBD-1〜18）を after の満たすべき NFR、[`spec/intended-diff-ledger.md`](../../spec/intended-diff-ledger.md)（ID-1〜31）を「仕様どおりの変更（脆弱性ではない）」の宣言として使う。
> **原則**: 発見（Discovery）と検証（Verification）を分離。憶測で「消えた」と書かず、コード位置 or 実測（HTTP応答・DB証跡）を根拠にする。

---

## 全体結論（サマリ）

| 区分 | 結果 |
| --- | --- |
| **問1 回帰（S1〜S21）** | **21/21 すべて解消**（消滅=設計変更で攻撃面除去 / 是正=secure-by-default 実装）。うち **10件をライブ実測で確証**（404実測・IDOR 403・CSRF 403・列挙不可・平文PW不在・SQLi不成立 等）、残りはコード位置で確証。**未対応（残存脆弱性）は 0件**。 |
| **問2 新規 Discovery** | §2 参照（Discovery→Verification 多数決で確定）。 |
| **残件（要追加検証）** | §3 参照（TLS/HSTS 等の運用レイヤ・refresh 失効の設計上の割り切り 等、"脆弱性" ではないが Phase 4/運用で追認すべき項目）。 |

**回帰の判定凡例**: 消滅（エンドポイント/機構自体が存在しない）／是正（機構は残るが secure に作り直し）／設計変更で消滅（アーキ転換で前提が消失）／未対応（脆弱性が残っている）／不明（判定不能）。

---

## §1 回帰表（before S1〜S21 の全行）

> 「before の内容」列は run `_02`（Struts）の finding。R# は同一根本原因の Spring MVC run `_01` 対応。
> 「根拠」列: `code`=コード位置による確証、`live`=稼働 backend/DB への実リクエストによる実測確証。

| ID | before の内容（Struts `_02`） | after の状態 | 根拠 | 対応 SBD / ID |
| --- | --- | --- | --- | --- |
| **S1** | Struts1 **CVE-2014-0114**（無認証 `*.do` から `class.classLoader.*` 束縛＝ClassLoader 操作 RCE 経路に到達可能） | **消滅（設計変更）**: Struts1/ActionServlet/`*.do` を全廃し REST 化。BeanUtils.populate 型のバルクバインドは存在しない。 | `live`: 認証済み `GET /newOrder.do?confirmed=true` → **404**（ハンドラ不在）。build.gradle に Struts 依存なし。 | ID-5 / SBD-7 |
| **S2** | editAccount 乗っ取り（`BeanUtils.populate` マスアサインで `account.username` 等を束縛し他人プロフィール上書き＋PWリセット。R3） | **是正**: `AccountEditRequest`（record）が編集可フィールドの allowlist。username/userid/status/version/WHO列を**型として持たない**。対象行は `CurrentUserProvider` 由来の userId のみで解決（クライアント username を受けない）。 | `code`: `AccountController.java:120-154`（DTO）, `AccountApplicationService.java:127-166`（userId=principal・allowlist UPDATE） | ID-2/ID-4 / SBD-2/SBD-1 |
| **S3** | identity-rebind IDOR（所有者判定元のセッション属性を同一リクエストで差し替え、他人注文/PII 閲覧） | **消滅（設計変更）**: stateless JWT（`SessionCreationPolicy.STATELESS`）で差し替え対象のセッション属性が存在しない。認可は認証プリンシパルのみを源にする。 | `live`: demo_user が他人注文 → **403**（後述 IDOR PoC）。`code`: `SecurityConfig.java:87`, `OwnershipAuthorizationService.java:32-37` | ID-4 / SBD-1 |
| **S4** | 注文マスアサイン（`totalPrice`/`unitPrice`/`username` を束縛して価格改ざん・他人名義注文。R4） | **是正**: `PlaceOrderRequest` は配送/請求先住所と別配送フラグのみ受理。合計はサーバが `m_item.list_price` で再計算、username は principal 由来。数量は DB カート由来。 | `code`: `OrderController.java:101-110`（DTO）, `OrderApplicationService.java:97-134`（`calculateTotal`・userId=principal） | ID-4 / SBD-2 |
| **S5** | CSRF 対策が全域で不在（token/Origin/SameSite 皆無。R6） | **是正**: cookie-to-header double-submit（`CookieCsrfTokenRepository.withHttpOnlyFalse` + 非XOR `CsrfTokenRequestAttributeHandler`）＋ 全 Cookie に `SameSite=Strict; Secure`。 | `live`: `X-XSRF-TOKEN` 無しの `POST /api/account/password`・`/api/auth/logout`・`/api/orders` → いずれも **403**。 | ID-9 / SBD-3 |
| **S6** | 現在パスワード未確認で PW 変更（CSRF・マスアサインと連鎖で遠隔乗っ取り） | **是正**: `changePassword` は `currentPassword` を必須にし `passwordEncoder.matches` で再認証。不一致は 422 で更新前に中断。 | `live`: 誤 `currentPassword` の `POST /api/account/password`（CSRF正常）→ **422** "Current password is incorrect."（PW未変更）。`code`: `AccountApplicationService.java:181-197` | ID-13 / SBD-16 |
| **S7** | 平文パスワード保存・平文比較（ハッシュ/ソルト無し。R5） | **是正**: `{bcrypt}` プレフィックス付きハッシュ（`DelegatingPasswordEncoder`）で保存・照合。列は `m_signon.password_hash VARCHAR(255)` のみ、平文列なし。 | `live`: DB 実測 — 平文列ゼロ、`password_hash` は `{bcrypt}$2a$10$...`。`code`: `PasswordEncoderConfig` + `V00_000_004`（schema） | ID-2 / SBD-5 |
| **S8** | セッション固定（ログイン成功時に session ID を再生成しない。R7） | **消滅（設計変更）**: stateless。ログインで発行するのは常に新規署名の access/refresh トークンのみ（供給トークンを再利用しない）。`JSESSIONID` を発行しない。 | `live`: ログイン応答の Set-Cookie は `ACCESS_TOKEN`/`REFRESH_TOKEN` のみ（`JSESSIONID` 無し）。`code`: `AuthApplicationService.java:60-100` | ID-10 / SBD-4 |
| **S9** | オープンリダイレクト（`forwardAction` を無検証 `sendRedirect`。R11） | **消滅（設計変更）**: SPA+REST 化でサーバ側リダイレクト機構が存在しない。 | `live`+`code`: backend src 全体に `sendRedirect`/`RedirectView`/`redirect:` は**0件**。 | ID-12 / SBD-9 |
| **S10** | ブルートフォース対策皆無＋弱い既定資格情報（`j2ee/j2ee` プリフィル、レート制限/ロックアウト無し。R10） | **是正**: DB-backed ロックアウト（`t_login_attempt`・max-attempts=5 / lock PT15M）。プリフィル無し。seed は既知強PW（`Sprint3-DemoLogin!26`）で `j2ee/j2ee` 不使用。 | `code`: `application.yml:53-58`, `LoginAttemptService`, `AuthApplicationService.java:64-84`。`live`: seed に j2ee 不在（DB実測）。 | ID-11 / SBD-6 |
| **S11** | 資格情報を GET でも受理（R13） | **是正**: login/register は POST body 限定。 | `live`: `GET /api/auth/login?username=..&password=..` → **405**、`GET /api/register` → **405**。 | ID-11 / SBD-6 |
| **S12** | 登録画面でユーザ名列挙（R14） | **是正（ログイン）＋設計判断（登録）**: ログインは未知username/誤PWを**バイト一致の一律401**に正規化（列挙不可）。登録の username 重複は 409＋明示メッセージだが、これは意図差分（ID-11・E4決定＝レート制限 `t_register_attempt` で緩和）。 | `live`: 存在ユーザ誤PW と 非存在ユーザ → **同一401ボディ**。`code`: `SecurityConfig.java:130-136`（hideUserNotFoundExceptions）, `RegisterAttemptService` | ID-11 / SBD-6 |
| **S13** | HttpInvoker 逆シリアライズ（無認証 `/remoting/*` exporter 到達） | **消滅（攻撃面除去）**: remoting 面を全廃。Spring HttpInvoker exporter 不在。 | `live`: 認証済み `GET /remoting/OrderService` 等 → **404**。build.gradle に remoting 依存なし。 | ID-5 / SBD-7 |
| **S14** | Hessian/Burlap 逆シリアライズ（無認証 `/remoting/*` 到達） | **消滅（攻撃面除去）**: 同上。Hessian/Burlap exporter・依存とも不在。 | `live`: 認証済み `/remoting/*` → **404**。 | ID-5 / SBD-7 |
| **S15** | **無認証 `getOrder` で全顧客 PII 総当り**（連番 orderId・所有者チェック不在。R2＝before 看板 PoC） | **消滅＋是正**: remoting 経路が 404（消滅）。REST の注文取得は認証必須＋サービス層で所有者スコープ。not-found と not-owned を**同一403**に正規化し連番の存在推測を封じる。 | `live`: IDOR PoC（後述）— 自分=200 / 他人=403 / 非存在=403（区別不能）/ `?account.username=` 注入は無効 / 監査に DENIED 記録。 | ID-4/ID-5 / SBD-1/SBD-8 |
| **S16** | Apache **Axis 1.4**(EOL) を無認証露出（WSDL/バージョン開示） | **消滅（設計変更）**: `/axis/*` 全廃、Axis 依存なし。 | `live`: 認証済み `GET /axis/services/Version`・`/axis/servlet/AxisServlet` → **404**。 | ID-5 / SBD-7・SBD-12 |
| **S17** | Axis 管理 PW をソースに平文（R15） | **消滅**: Axis 撤去で管理PWの概念自体が消失。秘密は環境変数注入（fail-fast）でソース非保持。 | `code`: `JwtProperties.java:25-41`・`application.yml`（`${JWT_SECRET}`/`${DB_*}` デフォルト無し）。`live`: ソースに平文 admin PW 0件。 | ID-25 / SBD-11 |
| **S18** | スタックトレース露出（error-page 不在。R9） | **是正**: `GlobalExceptionHandler` が全例外を正規化し trace/内部パス/版数を出さない。`spring.web.error.include-stacktrace=never`。 | `live`: 403/404/422 応答は固定 JSON（`code`/`message`/`path`/`timestamp` のみ・trace 無し）。`code`: `GlobalExceptionHandler.java`, `application.yml:9-14` | ID-14 / SBD-10 |
| **S19** | 平文 HTTP＋Cookie フラグ欠落（R16） | **是正（コード）**: 全 Cookie（ACCESS/REFRESH/XSRF）に `Secure; HttpOnly※; SameSite=Strict`（※XSRF は SPA 読取のため httpOnly=false は仕様）。TLS 終端は運用（§3）。 | `live`: ログイン Set-Cookie に `Secure; HttpOnly; SameSite=Strict` を実測。`code`: `AuthCookieSupport.java:64-74` | ID-25 / SBD-15 |
| **S20** | EOL/脆弱依存スタック（Struts1.2.9/Axis1.4/Spring3.1/Hessian4.0.7/hsqldb1.8/xalan2.5.1…。R12） | **是正**: Spring Boot 4.1.0 / Java 21 / MyBatis 4.1.0 / jjwt 0.12.6 / mysql-connector-j 9.5.0。Struts/Axis/Hessian/hsqldb/xalan とも不在。（依存 CVE の網羅は §2 Discovery で確認） | `code`: `build.gradle:32-86` | ID-26 / SBD-12 |
| **S21** | 版レンジ未固定でビルド非再現（R17） | **是正**: 依存は Spring Boot BOM ＋ 明示的 exact-version 固定。レンジ指定なし。 | `code`: `build.gradle`（全 `:x.y.z` 固定） | ID-26 / SBD-12 |

**集計**: 消滅/設計変更 **9件**（S1・S3・S8・S9・S13・S14・S16・S17・＋S15の消滅側）／是正 **12件**（S2・S4・S5・S6・S7・S10・S11・S12・S15の是正側・S18・S19・S20・S21）。**未対応=0件**。

### §1 付録 — ライブPoC 証跡（要約）

以下は稼働 backend/DB への実リクエストで取得した実測（後始末済み。合成データは削除確認済み）。

**(a) レガシー攻撃面の消滅（S1/S13/S14/S16 ほか）** — 未認証だと deny-by-default で 401 になるため、`demo_user` で**認証済み**に叩き 404（ハンドラ真の不在）を確認：
```
[認証済み] 200  GET /api/auth/me            ← 正常系（認証確立）
[認証済み] 404  GET /remoting/OrderService  /remoting/AccountService /remoting/CatalogService
[認証済み] 404  GET /axis/services/Version   /axis/servlet/AxisServlet /services/OrderService
[認証済み] 404  GET /shop/viewOrder.do  /editAccount.do  /newOrder.do?confirmed=true  /shop/index.do
[認証済み] 404  GET /actuator/env  /actuator/beans  /actuator/mappings   （health/info のみ 200）
```

**(b) 水平 IDOR の消滅（S15/S3/R2）** — user_id=1 所有の合成注文を1件作成し `demo_user`(userId=2) から探索：
```
[200] 自分の注文 /api/orders/1, /api/orders/2                         ← 明細つき本人注文
[403] 他人注文   /api/orders/3   {"code":"FORBIDDEN","message":"Access is denied"}
[403] 非存在     /api/orders/999999   ← 他人注文と同一応答（存在推測不能・SBD-8）
[403] 他人注文 + ?account.username=ac_neg1_user 注入 → 403 のまま（認可はプリンシパルのみ・SBD-1）
[200] /api/orders?account.username=ac_neg1_user → 返るのは demo_user 自身の注文のみ（自己スコープ固定）
監査ログ: t_audit_log に AUTHZ_FAILURE / actor=demo_user / result=DENIED を記録（SBD-14）
後始末: 合成注文（create_program='SEC_L3_POC'）を DELETE、残 0 行を確認
```

**(c) CSRF（S5）** — `X-XSRF-TOKEN` を欠いた状態変更はすべて 403。double-submit は Cookie（XSRF-TOKEN）とヘッダ（X-XSRF-TOKEN）の**両方**が揃った時のみ通過（片方欠落で 403 を実測）。

**(d) 認証堅牢化（S11/S12）** — `GET /api/auth/login` → 405、存在ユーザ誤PW と 非存在ユーザのログイン失敗が**バイト一致の 401**。

**(e) 平文PW不在（S7）** — `information_schema` 上のパスワード列は `m_signon.password_hash` のみ。値は bcrypt。

**(f) SQLi 維持（SBD-17 / S列にない基準線維持）** — 商品検索に `%' OR '1'='1`・`___`・`'; DROP TABLE m_product;--` を投入 → いずれも注入不成立（0件正規化）、`m_product` は 16 行のまま無傷。

---

## §2 新規 Discovery（after で新しく生まれた攻撃面）

**手法**: 発見（Discovery）と検証（Verification）を分離。5攻撃面で `security-scanner` を並列起動して候補を独立発見（`security/20260819_01/discovery/*.md`）→ 根本原因で重複排除 → **ライブPoC を最強証拠**として確定（PoC成功で多数決は省略。SEC原則）。複数スキャナが同一根本原因を独立発見した所見は収束（convergent）として信頼度を上げた。

**検証凡例**: `CONFIRMED(live)`=稼働環境の実PoCで確証／`CONFIRMED(code)`=コード解析で確証（ライブ未実施）／`REFUTED/降格`=Discoveryの主張を検証が是正。

### §2.1 確定所見テーブル

| # | finding-key | 所見 | 重大度 | 検証 | 根拠(要約) |
| --- | --- | --- | --- | --- | --- |
| **N1** | `backend:secrets:jwt-signing-key-is-public-placeholder` | **稼働 backend が公開既知の署名鍵（git 追跡下 `.env.example` の placeholder）で JWT を署名/検証。fail-fast は鍵長(≥32)しか見ず、既知鍵でも起動する。→ 資格情報なしで任意ユーザなりすまし＋任意ロール（ADMIN）捏造** | **Critical**（as-run）| **CONFIRMED(live)** | 偽造トークンで `ac_neg1_user` の PII 取得(200)・`roles:["ADMIN"]` 偽造で ADMIN限定 `/api/secured/ping`→200・別鍵署名は401（＝署名検証は正常＝鍵が公開なのが根因）。`JwtProperties.java:19,29-37`／`.env`／`.env.example`(tracked) |
| **N2** | `backend:audit:authz-failure-suppression-via-long-uri` | 101字超の URI で `t_audit_log.action VARCHAR(100)` の INSERT が破綻→セキュリティハンドラ内から例外→error dispatch で **403が401化＋本来の認可失敗監査（実行者・対象）が消失**。攻撃者が自分の認可失敗の監査を任意に握り潰せる | **Medium** | **CONFIRMED(live)**・収束(3スキャナ) | 短URI→403+監査行(actor=demo_user)／長URI(102字)→401+`actor=NULL,action=/error`。SBD-14無効化・SBD-10逸脱。データ漏えい無/SBD-8維持 |
| **N3** | `backend:audit:order-create-failure-unrecorded` | `placeOrder` の catch が `InsufficientStockException` のみ。その他失敗（住所超過長等）は 500 になり `ORDER_CREATE` の失敗監査が**一切残らない**（ID-22「成功・失敗いずれも記録」に反する） | **Medium** | **CONFIRMED(code+live)**・収束(2スキャナ) | `OrderApplicationService.java:129`／`OrderAddressRequest` に `@Size` 皆無。スキャナ実測: postalCode 40字→500・監査0。成功時は記録される（対照確認済） |
| **N4** | `backend:auth:rate-limit-burst-toctou` | ログイン/登録のロックアウトが check-then-act（`assertNotLocked`→bcrypt→`recordFailure` に排他なし・`login` は非トランザクション）。並行バーストで1窓あたり実効 スレッド数分の推測が成立し閾値5を大きく超過 | **Medium** | **CONFIRMED(code)** | `AuthApplicationService.java:64-84`（相互排他不在）。※ライブ・バーストPoCは並列auth大量送信のため自粛（§3・permission-gated） |
| **N5** | `backend:auth:login-error-normalization-gap` | 保存ハッシュに `{id}` プレフィックス欠落のアカウントでログイン→`IllegalArgumentException` が `catch(AuthenticationException)` を素通り→**400＋内部ライブラリメッセージ露出**。非存在(401)と弁別可＝列挙オラクル＋`recordFailure` バイパス | Low | **CONFIRMED(live)** | `ac_neg1_user`→400+`DelegatingPasswordEncoder…{noop}…`／demo_user誤PW・非存在→一律401。根因: `GlobalExceptionHandler.java:145-148` が生メッセージをそのまま返す＋エンコーダ例外を401へ正規化していない。現状トリガーはdev/testフィクスチャ限定（潜在） |
| **N6** | `backend:authz:secured-demo-endpoints-exposed` | 実証専用 `SecuredPingController` が稼働面に残存＋未認証 `/v3/api-docs` に列挙。`/api/secured/my-resource/{id}`＝自己user_idオラクル。`/api/secured/ping`(ADMIN限定)は `simulateError=unexpected` で内部パス入り例外を投げる（**N1でADMIN偽造可能なため到達可能**） | Low | **CONFIRMED(live)** | `my-resource/2`→200,他→403／`/v3/api-docs` に `/api/secured/*` 列挙。`SecuredPingController.java:36-49` |
| **N7** | `backend:error:pagination-offset-int-overflow` | `(page-1)*size` の int オーバーフロー（page上限クランプ無し）で **未認証 500**。コードコメントの「クランプして空200」宣言と実装が乖離 | Low | **CONFIRMED(live)** | `?page=2147483647&size=100`→検索・カテゴリ商品一覧で500。`PageRequest.java:33`。越境データ漏えいは無し |
| **N8** | `backend:exposure:openapi-swagger-public` | `/v3/api-docs`・`/swagger-ui` が未認証公開（profile分離なし）。全 API のパス/スキーマ開示 | Low | **CONFIRMED(live)**・収束(3スキャナ) | `application.yml:31-35`／`SecurityConfig.java:62-64`。現フェーズでは許容余地大だが本番は profile ガード推奨 |
| **N9** | `backend:secrets:hardcoded-generator-db-credentials` | `jpetstore/jpetstore` 平文が `EnumGenerator.java`・`generatorConfig.xml` にあり **boot jar に同梱**（`BOOT-INF/classes/generator/…`）。※ランタイム経路は正しく外出し済 | Low | CONFIRMED(scanner) | docker既定creds（`docker-compose.yml` に公開）と同値。台帳 §補足「ソース内に実効的秘密なし」への部分未達 |
| **N10** | `backend:audit:state-change-coverage-gap` | `recordStateChange` の呼び出しが注文作成のみ。account編集・PW変更・登録・ログイン成功が無記録（SBD-14） | Low | CONFIRMED(code) | `AuditLogRecorder` 呼び出し箇所は `OrderApplicationService` 2箇所のみ。SBD-14は「過大評価しない」追加NFRのため severity 抑制 |
| **N11** | `backend:input:missing-size-constraints-500` | `OrderAddressRequest` の `@Size` 欠落・`favoriteCategoryId` の実在検証欠落→DB制約違反で 500（`DataIntegrityViolationException` 専用ハンドラ不在） | Low | CONFIRMED(scanner)・N3と同根 | `OrderController.java`／`AccountController.java:133` |
| **N12** | `backend:input:language-preference-no-allowlist` | `languagePreference` が `@Size` のみ（同一DTOの `colorSchemePreference` は `@Pattern` あり＝非対称）。任意文字列（`<img onerror=…>`）が永続化され `/api/auth/me`・`/api/account` で返る | Low | CONFIRMED(scanner) | backend単体では実行不能（JSON応答）＝**frontend Discovery へ引き継ぎ**（SBD-18の出力エスケープはSPA側責務）。`AccountController.java:132` |
| **N13** | `backend:csrf:token-accepted-in-query-param` | CSRF トークンを `?_csrf=` で受理（Spring既定）。URLログ/リファラ経由で漏えいしうる | Low | CONFIRMED(scanner) | 実測200。防御は破れないが機微値のURL露出 |
| **N14** | `backend:audit:unauthenticated-write-amplification` | 未認証リクエスト1件ごとに監査ログ1行 INSERT（レート制限なし）→監査表フラッド（N2と連鎖で `/error` 行埋め） | Low | CONFIRMED(code) | `AuditingAuthenticationEntryPoint`。DoS/汚染 |
| **N15** | `backend:error:media-type-not-normalized` | Content-Type 不一致→500・Accept 不一致→401(`/error`)。SBD-10 の 4xx 正規化未達（情報露出は無し） | Low | CONFIRMED(scanner) | 専用ハンドラ不在 |
| **N16** | `backend:authz:db-user-excessive-grants` | `GRANT ALL PRIVILEGES ON jpetstore_db.* TO jpetstore@%`（DDL/DML同一アカウント）。単体では非exploitだが他脆弱性の被害増幅 | Low | CONFIRMED(live) | 実測 SHOW GRANTS。最小権限逸脱（DoD/防御多層） |

### §2.2 検証で是正・反証した Discovery（発見と検証を分離した効用）

- **C1 `backend:csrf-cors:csrf-cookie-deleted-per-authenticated-request`（Discovery=Medium「CSRF防御が壊れている」）→ 降格/実質REFUTED**。検証: 認証済み応答は XSRF トークンを**削除ではなく毎回ローテート**し、**ローテート直後のトークンは使用可能**（`POST /api/cart/items`→200を3回連続で実測）。Discoveryが観測した「連続403」は **curl の cookie-jar がSecure/セッションCookieをhttpで永続化しない副作用**であってサーバ欠陥ではない。double-submit＋SameSite=Strict は健在。残る事実は「毎リクエストのトークンローテーション（やや異例。SPAは初回 `GET /api/ping` で prime）」で、実害は Low〜情報。
- **依存CVE → 指摘なし（S20/S21 の是正を確認）**。scanner が boot jar の runtime 86 jar を版単位で評価し確定重大CVEゼロ。台帳 ID-26 が根拠に挙げた **CVE-2023-22102 は 8.2.0 で修正済＝mysql-connector-j 9.5.0 は非該当**。版レンジ指定は1件も無し（SBD-12後段=版固定を充足）。→ §3 に「知識期限後 advisory の live OSV/GHSA 照会」を残件として明記。
- **refresh の revocation/ローテーション欠如・IP無しレート制限** → 意図差分台帳＋コード javadoc で明示済みの設計判断のため**新規所見にしない**（§3 残件として記載）。

### §2.3 堅牢と確認した領域（before の基準線維持＋新規NFRの達成）

実測・コード両面で clean と確認（過大主張回避のため明示）:
- **SQLi/動的SQL（SBD-17 維持）**: mapper XML 6本＋アノテーションSQL を全走査し `${}` はゼロ（Java側 `${}` は Spring `@Value` のみ）。ORDER BY は固定リテラル、LIMIT/OFFSET は `#{}`。ID-29 の LIKE ESCAPE は実測有効（`%`/`_`/`' OR '1'='1`/`; DROP TABLE`→全て注入不成立・`m_product` 無傷）。
- **マスアサインメント（SBD-2）**: DTO は record の allowlist。`@ModelAttribute`/Mapバインド/`BeanUtils`/リフレクション使用ゼロ。注文・アカウント・カートともサーバ権威フィールドは常にサーバ決定。
- **在庫減算の並行安全（D6/ID-1）**: ガード付き単文アトミック減算（`quantity>=#{quantity}`）で TOCTOU/売り越し不能。item_id 昇順固定順でデッドロック回避、`@Transactional` all-or-nothing、affected-rows==0 判定。orderId 原子採番（AUTO_INCREMENT）。
- **認可/IDOR（SBD-1/8）**: 注文は所有者スコープ・not-owned≡not-found（応答も所要時間も区別不能）、一覧は principal スコープ、カート/アカウントは cartId/userId をクライアントから受けない構造。垂直昇格は（署名鍵が秘密である限り）経路なし ← **ただし N1 により現状は破れる**。
- **CORS**: CORS 設定なし＝クロスオリジン読取不可（`Access-Control-Allow-Origin` を返さないことを実測）。ワイルドカード+credentials の危険設定なし。
- **エラー情報露出（SBD-10）**: `ErrorResponse` に trace/クラス名/版数のフィールド自体が無く、全 500/4xx 応答で露出なし（`Server` ヘッダも無）。※N2/N5/N7/N15 は「4xx正規化/一部メッセージ」の穴であり trace 露出とは別。
- **監査のログ汚染耐性**: `detail` は Jackson で構造化エスケープ、`client_ip` は `getRemoteAddr()` 固定（X-Forwarded-For を意図的に不信頼）。
- **JWT の署名検証/typ 混同/Cookie属性・セッション固定化・資格情報POST限定・actuator最小露出**: いずれも clean（§1 と scanner 実測）。※ただし N1 で署名鍵自体が公開されているため「署名検証が正しい」ことの実効防御が無効化されている点に注意。

---

## §3 未確認・要追加検証の残件

1. **N4（レート制限バースト TOCTOU）のライブPoC**: コード解析で CONFIRMED だが、並列auth大量送信（ブルートフォース様）を避け**実バーストPoCは未実施**（permission-gated）。承認が得られれば「20並列失敗ログイン→`t_login_attempt.attempt_count` が閾値5を大きく超過」で経験的に実証可能。
2. **依存の知識期限後 advisory**: オフライン 86-jar 分析では確定重大CVEなしだが、Spring Boot 4.1.0 / Tomcat 11.0.22 / jjwt 0.12.6 等は新しく、**live OSV/GHSA 照会**での最終確認が望ましい（S20 の完全クローズ）。
3. **refresh トークンの失効設計**: revocation store 無し＝PW変更/ログアウト後も既存 refresh が最大7日有効（`/api/auth/refresh` は permitAll）。**意図差分台帳＋javadoc で明示済みの設計判断**だが、N1 と重なると影響が増幅する（既知鍵で発行した refresh は7日間有効）。将来の revocation store 導入で強化を推奨。
4. **トランスポート（S19 の運用側残件）**: アプリは Cookie に `Secure` を付与するが、**TLS 終端・HSTS・CSP は本番プロキシ/フロント側の責務**（dev は http localhost）。C7(`missing-hsts-csp`)・`useSSL=false&allowPublicKeyRetrieval=true` はこの運用前提。
5. **在庫枯渇（denial-of-inventory）**: 決済ゲートが ID-8 で意図撤去済のため、認証済アカウント1つで状態変更APIのレート制限なしに全在庫（実測≒28アイテム・最大100）を短時間で 0 にできる。**ID-8 の帰結として受容される可能性**があり PO 判断を仰ぐ（台帳追記 or 受容明記）。
6. **注文の二重送信**（`order-double-submit-duplicate`, Low）: 冪等キー無しで同一カートの並行 POST が注文2件を生む（売り越しは起きない）。台帳に記載が無いため、受容 or 冪等キー導入の判断。
7. **mysql-connector 版乖離**: backend 9.5.0 vs database 26.7.0。CVE主張ではないが台帳に記録の無い据え置き差分（ID-26 の版固定方針との整合を記録推奨）。

### PoC の後始末（実施済み）
本 L3 のライブPoCで作成した状態はすべて実行前へ復元済み: 合成注文（`create_program='SEC_L3_POC'`）削除・discovery ワーカーが作成した実注文(order_id=4)削除＋在庫 EST-1 を +2 復元・合成 `t_login_attempt` 行削除・PoC由来の監査プローブ行削除。最終確認: アカウント=seed2件のみ／注文=1,2／カート空／EST-1在庫=98／demo_user ログイン200。
※ 監査ログは追記専用（append-only）のため、注文作成PoCの `STATE_CHANGE` 記録1件（対象注文は削除済み）は**不変条件尊重のため残置**した（当該記録は無害）。

---

## 受け渡し（Patching）

本書は SEC の Find-and-Fix ループの「発見→検証」まで。**修正は行わない**。§2 の確定所見（特に N1=Critical・N2〜N4=Medium）は Sprint に載せ、PO が Refinement（AC/SP・否定AC）、DEV が TDD で修正＋回帰テスト化（＝PoCの自動化）する。**Issue 化は外向き・実質不可逆のため、起票前にユーザー承認を取る**（NEW/KNOWN/REGRESSION の別と束ね方を一覧提示 → GO 後に `security` ラベル付きで `ryokkon624/jpetstore-manage` へ起票）。現時点では既存 open/closed の `security` Issue 突合は未実施（承認フェーズで行う）。

