# Sprint 20 実装ノート

## L3 finding → テスト 対応表（C1）

| L3 | Issue/AC | テストクラス | 概要 |
|---|---|---|---|
| N1 live PoC(偽造token) | #38 Q3 | 新 `JwtForgedTokenL3RegressionSpec`(IT) | `.env.example` 実鍵の偽造 access token → `/api/auth/me` 401 |
| N1 live PoC(ADMIN捏造) | #38 Q3 | 同上 | 同鍵 `roles:["ADMIN"]` → `/api/secured/ping` 401 |
| N1 根因 | #38 AC-neg1 | 新 `JwtSecretContextFailFastSpec` | `.env.example` の値ではコンテキスト起動失敗 |
| N1 補助 | #38 AC2/AC-neg2 | 同上 | ユニーク24未満で起動失敗／`openssl rand -base64 32` 相当は正常起動 |
| N1 denylist/メッセージ | #38 AC1/AC3 | 新 `JwtSecretPolicySpec`(unit) | trim/大小文字非依存の完全一致・秘密値非露出 |
| N1 鍵長維持 | #38 AC2 | 既存 `JwtPropertiesSpec`(改修) | 32byte未満は例外＋宙吊り参照是正 |
| N2 live PoC(長URI) | #39 AC1/AC-neg1 | 新 `AuditSuppressionL3RegressionSpec`(IT) | 200文字級URIで403のまま・actor＋action先頭100文字が残る |
| N2 truncate | #39 AC1 | 既存 `AuditLogRecorderSpec`(追記) | 101文字以上でも先頭側保持でINSERT成功 |
| N2 best-effort | #39 AC2/AC-neg2 | 新 `AuditLogRecorderBestEffortSpec`(unit) | 例外を伝播せずERRORログに残す |
| N2 best-effort e2e | #39 AC-neg2 | `AuditSuppressionL3RegressionSpec` | INSERT失敗でも403/401＋ErrorResponse |
| N14 | #39 AC3/AC-neg3 | 新 `AuditWriteQuotaServiceSpec`(IT)＋上記IT | 未認証AUTHZ_FAILUREが窓内上限で頭打ち・suppressed_count＋WARN |
| N3 | #40 AC1/AC-neg3 | 新 `OrderFailureAuditL3RegressionSpec`(IT) | 在庫不足以外の失敗でもORDER_CREATE/FAILUREが1行残る |
| N3 単体 | #40 AC1 | 既存 `OrderApplicationServiceSpec`(追記) | RuntimeExceptionでも独立監査→再送出／既存経路不変 |
| N11 | #40 AC2/AC-neg1 | 既存 `OrderControllerSpec`(追記) | postalCode 40文字→400 |
| N11 shipping | #40 AC3/AC-neg2 | 同上 | `useSeparateShipping=true` で shipping 空→400 |
| N11 DB制約 | #40 AC4 | 既存 `GlobalExceptionHandlerSpec`(追記) | DataIntegrityViolation→400・生メッセージ非露出（AC-neg1 経路からは到達しない防御多層） |
| N4 ＋ §3残件1 | #41 AC1/AC-neg1 | 新 `RateLimitBurstConcurrencySpec`(IT) | 20並列失敗ログインで `failed_attempt_count` が5で頭打ち |
| N4 登録側 | #41 AC2/AC-neg2 | 同上 | 20並列登録で `attempt_count` が5で頭打ち |
| S1 | #41 | 同上 | 5並列の「成功」ログインが全て200（誤ロックしない） |
| N4 列挙耐性 | #41 AC3 | 既存 `LoginLockoutSpec`（**無改変**） | ロック時応答の完全一致／非実在usernameも対称 |
| N4 窓リセット | #41 AC4/AC-neg3 | 既存 `LoginLockoutSpec`/`RegistrationControllerSpec`（**無改変**） | 窓リセット・ロック解除・成功リセット・別IP分離 |

## 意図的な設計（追加分・reviewer起動時に明示）

- **F2**: `OrderAddressRequest.address2` の 80 は `t_order` 由来。`AccountEditRequest.address2` の 40（`m_account` 由来）との差は別テーブル由来の正しい非対称。
- **truncate 4列拡張**: AC1 は `action` のみ要求だが `target_type`/`target_id`/`actor_username` の3列も追加＝意図的な防御多層化。
- **quota の未認証限定**: 認証済み403に quota を掛けない（掛けると #39 が直している監査抑止を再導入してしまうため）。
- **S1**: `login` に `@Transactional` を付けない代償として成功ログインも枠を消費し、高並行成功ログインで誤401が起こり得る（`recordSuccess` のDELETEで即自己回復・実害極小）。受容したトレードオフ。
- **S3**: `DataIntegrityViolationException` ハンドラは AC-neg1 の経路からは到達しない防御多層。単体テストで独立に固定。
- **F7**: 白箱 Spec 4本（`LoginAttemptServiceSpec`/`RegisterAttemptServiceSpec`/`AuthApplicationServiceSpec`/`RegistrationApplicationServiceSpec`）の改修は API 変更に伴う意図的な追随。AC-neg3 の実質受入条件は振る舞い IT（`LoginLockoutSpec`/`RegistrationControllerSpec`）の無改変 green。
- **F1**: テスト鍵 fixture 5ファイル（`IntegrationTestBase`/`JwtServiceSpec`/`JwtAuthenticationFilterSpec`/`JwtPropertiesSpec`/`ApplicationBootFailFastSpec`）の差し替えは #38 AC2（最小エントロピー検証）導入に伴う不可避な付随作業。新設 `support/TestJwtSecrets`（`STRONG`/`ENV_EXAMPLE_PLACEHOLDER`/`LOW_ENTROPY`）に集約した。

---

## #38: JWT署名鍵が公開のplaceholder値で稼働し、資格情報なしで任意ユーザ/ADMINのトークンを偽造できる

### 仕様外の判断・変更・妥協点

- **`JwtSecretContextFailFastSpec` の `conversionService` bean 明示登録**: `ApplicationContextRunner`（プレーンな `AnnotationConfigApplicationContext`）は Spring Boot 拡張の `Duration` コンバータを持たないため、`jwt.access-token-ttl`/`jwt.refresh-token-ttl`（`Duration` 型 `@Value`）の文字列変換が失敗し、**JWT_SECRET の値に関わらず常にコンテキスト起動が失敗する**（AC-neg1/AC-neg2が「別の理由での起動失敗」に紛れて偽陽性GREENになる罠）。`conversionService` という bean名で `ApplicationConversionService` を明示登録して解消した（実装中にRED確認の過程で発見）。
- **F1（テスト鍵 fixture 一括是正）**: 計画フェーズで確定済みのとおり `support/TestJwtSecrets` を新設し、5ファイル（`IntegrationTestBase`/`JwtServiceSpec`/`JwtAuthenticationFilterSpec`/`JwtPropertiesSpec`/`ApplicationBootFailFastSpec`）を是正した。`JwtServiceSpec`の「異なる鍵で署名されたトークン」テストは、`TestJwtSecrets`に含まれない別の高エントロピー鍵をその場で用意した（STRONGと衝突しない別鍵が必要なため）。
- **`JwtPropertiesSpec` の宙吊り参照是正**: javadocの`{@link SecretFailFastSpec}`（実在しないクラス）を`{@link com.example.jpetstore.backend.config.ApplicationBootFailFastSpec}`へ修正した（#38 改修方針4のとおり）。

---

## #39: 過大長URIで認可失敗の監査記録が消え、403が401に化ける（監査抑止）

### 仕様外の判断・変更・妥協点

- **既存IT specへの`t_audit_write_quota`クリア追加**: AC3導入により未認証`recordAuthzFailure`にquotaゲートが掛かるため、IT間で共有される単一MySQLコンテナ上でカウンタが積み上がると、未認証401の監査行をアサートする既存specが偽陰性化しうる（F5で予見済みの罠）。`AuditLogRecorderSpec`（新規追加した2テストも含む）・`OwnershipAuthorizationEndToEndSpec`・`SecurityEndToEndSpec`のsetup()に`DELETE FROM t_audit_write_quota`を追加した（3ファイルとも「未認証401→監査行アサート」のテストを持つことを確認して対象化）。他の未認証401テスト（`AuthMeSpec`等、HTTPステータスのみを見る）は監査内容を見ないため対象外とした。
- **`IntegrationTestBaseSmokeSpec`のマイグレーション数更新**: `V00_000_014`追加に伴い既存の`flyway_schema_history`件数アサーション（13→14）を更新した（新規マイグレーション追加時の定型対応）。

### レビュー指摘対応: Fix 1（SM verification 確定所見・#39 AC2 未達）

**発見自体に記録価値あり**: `AuditLogRecorder.recordAuthzFailure` の実装当初、`auditWriteQuotaService.tryAcquire` 呼び出しは try/catch の**外**にあり、`insert(...)` 内の `mapper.insert` だけが例外保護されていた。`tryAcquire` は `@Transactional(REQUIRES_NEW)` で新規コネクション取得を伴うため、未認証フラッド時（＝まさに quota が守ろうとしている状況）にコネクションプール枯渇等で例外を投げやすく、これが `recordAuthzFailure` の全4呼び出し元（`AuditingAccessDeniedHandler`/`AuditingAuthenticationEntryPoint`/`GlobalExceptionHandler`の2箇所）へ素通りし、セキュリティハンドラ内からの例外送出→`/error`ディスパッチ→**403/401がそもそもの応答にならず監査も残らない**、という**#39が修正対象にしているN2と全く同一の失敗モード**を、トリガを「過大長URI」から「quotaのDBエラー」に変えただけで再現してしまう状態だった。TDDの否定ACテストが「`mapper.insert`が失敗するケース」しか固定していなかったため、実装時のRED→GREENサイクルでは検出できず、SMのverification（コード精読）で初めて確定した。

**修正**: `isWithinQuota(clientIp)` private メソッドへ切り出し、`tryAcquire`呼び出しをtry/catchで保護。例外時は**fail-open**（枠ありとみなして`insert(...)`へ進む）とし、アプリログへERRORを残す。fail-closed（例外時にreturn）にすると、quotaのDB障害自体が新しい監査抑止経路になってしまうため不採用。
テスト: `AuditLogRecorderBestEffortSpec`に3件追加（fail-open伝播なし・insertへ進むこと・ERRORログ）、`AuditSuppressionL3RegressionSpec`に1件追加（未認証401のe2eでquota例外時も本来のErrorResponseが返ること）。

---

## #40: 注文確定の失敗が監査に残らず500になる（入力制約欠落・ID-22未達）

### 仕様外の判断・変更・妥協点

- **`OrderFailureAuditL3RegressionSpec`は`MockitoSpyBean`で`OrderRepository#insertHeader`を1回だけ失敗させて実証**: #40 AC2/AC3導入後、N11の入力検証由来の500経路はBean Validationで400に塞がれるため、「在庫不足以外の想定外の失敗」を実HTTP経由で再現するには疑似的なDB層失敗の注入が必要だった。既存カタログseed（EST-1）を使い、`insertHeader`が例外を投げても在庫減算（後続処理）が発生しない実装順序を確認したうえで採用した。

---

## #41: ログイン/登録のレート制限がcheck-then-actで並行バーストにより回避できる（TOCTOU）

### 仕様外の判断・変更・妥協点

- **`RateLimitBurstConcurrencySpec`で登録側テストのHikariCP接続池上限を50へ引き上げ**: 登録側`RegisterAttemptService#acquireAttemptSlotOrThrow`は`REQUIRES_NEW`（F6）のため、呼び出し元`register()`の主`@Transactional`が保持する接続とは別にもう1本DB接続を要する。20並列だと最大40本同時に必要となり既定のHikariCP pool（10）を使い切って`TimeoutException`になることを実際に確認した（本番実装のロジック不具合ではなく、本テスト特有の高並列に対する接続池サイズ不足）。本spec専用に`@DynamicPropertySource`で`spring.datasource.hikari.maximum-pool-size=50`を上書きして解消した（本番のpoolサイジング自体は本Sprintのスコープ外）。
- **登録側バーストテストのリクエストボディはpassword/repeatedPasswordを意図的に不一致にした強力な文字列にした**: 当初は短い`"pw-a"`/`"pw-b"`を使っていたが、`@StrongPassword`のBean Validationに先に弾かれ（400）、`acquireAttemptSlotOrThrow`自体に一度も到達しない状態で「レート制限が効いていない」ように誤って見えることが判明した（TDDのRED確認中に発見）。両方とも個別には強度基準を満たすが互いに不一致な文字列（`"Correct#Passw0rd!"`/`"Correct#Passw0rd!X"`）へ変更し、Bean Validationを通過させたうえでService層のpassword不一致（400）に到達させることで、枠確保の並列制御のみを対象化した。

### レビュー指摘対応: Fix 2（performance指摘・LoginAttemptServiceの非対称是正）

`LoginAttemptService.acquireAttemptSlotOrThrow`の`ensureRow`（INSERT..ODKU）と`acquireSlot`（UPDATE）が個別にautocommitされ、ログイン試行1回あたりコミットが2回発生していた。同型の`RegisterAttemptService#acquireAttemptSlotOrThrow`/`AuditWriteQuotaService#tryAcquire`はいずれも`@Transactional(REQUIRES_NEW)`のため、`LoginAttemptService`だけが非対称だった（reviewer指摘）。

**修正**: `acquireAttemptSlotOrThrow`に`@Transactional(propagation = Propagation.REQUIRES_NEW)`を付与。以下2点をjavadocに明記した:
1. **設計意図（bcryptを行ロック内に抱えない）は損なわれない**: `AuthApplicationService.login`は本メソッドの**return後**に`authenticationManager.authenticate`（bcrypt）を呼ぶため、本メソッドのトランザクション（行ロック）はbcrypt開始前に必ずコミット済みになる。
2. **ロールバック安全性の不変条件（レート制限バイパス防止）**: `BadCredentialsException`は`affected==0`（枠を確保できなかった）ときにのみ送出されるため、ロールバックされるのは「枠を消費していないケース」だけ。将来「枠確保成功後に例外を投げる」経路を追加すると、枠消費がロールバックで巻き戻りレート制限をバイパスできてしまうため、この不変条件を崩さないことを明記した。

`LoginAttemptServiceSpec`はプレーンな`new LoginAttemptService(...)`で構築する単体テストのため`@Transactional`はSpringプロキシ非経由（アノテーション自体は動作に影響しない）で無改変green。`LoginLockoutSpec`（挙動IT・5本）も無改変greenを再確認した。
