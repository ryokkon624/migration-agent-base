---
name: backend-conventions
description: HwHubバックエンド（hw-hub-backend）およびバッチ（hw-hub-batch）、jpetstore-backendの設計規約・実装方針。Javaファイル・Groovyファイル・MyBatisマッパー・Flywayマイグレーションファイルを新規作成・編集するときは必ずこのスキルを参照すること。DDDライク3層構造・ドメインモデル・セキュリティ・テスト方針など、実装の判断に必要な規約をすべてここに集約している。
---

# Backend Conventions

hw-hub-backend・hw-hub-batch・jpetstore-backendの設計規約・実装方針。

> §1〜§8 はhw-hub由来（ベースパッケージ`com.hwhub.backend`の実例を含む）。**§9はjpetstore-backend固有**
> （Spring Boot 4.x／ベースパッケージ`com.example.jpetstore.backend`）。DDDライク3層・`reconstruct()`パターン
> 等の思想はプロジェクト共通だが、実例のパッケージ名は各プロジェクトの実態に読み替えること
> （CLAUDE.md記載のとおりPhase 3実装時にJIT調整中）。

---

## 1. アーキテクチャ（DDDライク 3層構造）

```
Presentation層  →  Application層  →  Domain層
                                          ↑
                    Infrastructure層  ─────┘
```

- Controller は Application Service を呼び出す。Repository を直接呼ばない
- Request/Response DTO は Controller 層に閉じる。Application Service には渡さない
- Entity（MyBatis Generator生成）は Infrastructure 層に閉じる。上位層へ出さない
- `com.hwhub.backend.domain.enums` 配下の自動生成Enumは編集禁止

### オブジェクト種別と層ごとの依存ルール

| 層             | オブジェクト種別            | Presentation | Application | Domain | Infrastructure | メモ                                                       |
| -------------- | --------------------------- | :----------: | :---------: | :----: | :------------: | ---------------------------------------------------------- |
| Presentation   | request/response DTO        |      ○       |      ×      |   ×    |       ×        | class / record どちらでも可                                |
| Application    | Presentation層への戻り値DTO |      ○       |      ○      |   ×    |       ×        | Service の Inner Class として record で実装                |
| Domain         | Model                       |      ○       |      ○      |   ○    |       ○        | 業務的な単位・業務処理あり                                 |
| Domain         | 参照系Model                 |      ○       |      ○      |   ○    |       ○        | record で実装                                              |
| Domain         | 検索条件VO                  |      ○       |      ○      |   ○    |       ○        | record で実装（MyBatis mapper のパラメータとして対応済み） |
| Infrastructure | generated entity            |      ×       |      ×      |   ×    |       ○        | MBG生成・テーブルと1対1                                    |
| Infrastructure | custom entity               |      ×       |      ×      |   ×    |       ○        | JOINの結果を受け取るための手書きEntity                     |

**重要な制約**

- `generated entity` / `custom entity` は Infrastructure 層に閉じる。Service / Controller には絶対に出さない
- Presentation 層の DTO は Controller 内で完結させ、Service には渡さない

---

## 2. ドメインモデル & コンバーター

- Domainクラスのコンストラクタは `private` とし、再構築には `reconstruct()` ファクトリメソッドを使用する
- Infrastructure層からDomainに変換する際は、手書きの `XxxConverter` を作成し `toModel` メソッド内で `reconstruct()` を呼ぶ
- Enumは `m_code` テーブルから生成する（自動生成ファイルは編集禁止）

```java
// 例: Domainクラスの reconstruct() パターン
public class HouseworkTask {
    private final Long id;
    private final String title;

    private HouseworkTask(Long id, String title) { ... }

    public static HouseworkTask reconstruct(Long id, String title) {
        return new HouseworkTask(id, title);
    }
}

// 例: XxxConverter の toModel パターン
public class HouseworkTaskConverter {
    public HouseworkTask toModel(HouseworkTaskCustomEntity entity) {
        return HouseworkTask.reconstruct(entity.getId(), entity.getTitle());
    }
}
```

---

## 3. バリデーション & 例外

- Controller での `@Valid`（Bean Validation）と Domain での整合性チェックの二段構え
- 例外は `GlobalExceptionHandler`（`@RestControllerAdvice`）で一括ハンドリング
- 基本は `ResourceNotFoundException` / `IllegalArgumentException` を使用
- 認可失敗（世帯・リソースへの所属チェック等）は `org.springframework.security.access.AccessDeniedException` を使う（`GlobalExceptionHandler` で 403 にマッピング済み）。`HouseholdAuthorizationService.assertUserBelongsToHousehold` をはじめ既存の認可チェック全体で統一されているパターンであり、新規実装でも踏襲する

> **背景（Sprint 67 レビュー）**: convention-reviewer が `AccessDeniedException` を本規約に未記載の例外型として指摘したが、`HouseholdAuthorizationService` を含む既存の認可チェック全体で確立済みのパターンであり、本規約側の記載漏れだったため追記した（#187/#188）。

---

## 4. トランザクション

- Service層のメソッドには `@Transactional` を適切に付与する
- 参照系メソッドは `@Transactional(readOnly = true)`

---

## 4a. N+1問題の防止

Service 層でループ内に Repository 呼び出し（クエリ）を行ってはならない。

```java
// NG: ループ内でクエリを実行（N+1）
for (Long householdId : householdIds) {
    int count = memberRepository.countActiveMembersByHouseholdId(householdId); // N回クエリが走る
    if (count > 1) throw new OwnerCannotBeDeletedException();
}

// OK: 一括クエリで取得
Map<Long, Integer> countMap =
    memberRepository.countActiveMembersByHouseholdIds(householdIds); // 1回のクエリ
for (Long householdId : householdIds) {
    if (countMap.getOrDefault(householdId, 0) > 1) throw new OwnerCannotBeDeletedException();
}
```

一括クエリのパターン:
- `findByIds(List<Long> ids)` — ID リストで複数件取得
- `countByIds(List<Long> ids)` — ID リストで件数を `Map<Long, Integer>` で返す
- `findAllEnabled()` — 条件なし全件取得（一覧のグループ化が必要な場合）

> **背景（Sprint 45 レビュー）**: `UserService.deleteAccount()` でループ内に `findActiveByHouseholdId()` を呼び出す N+1 が発生。`countActiveMembersByHouseholdIds()` 一括クエリに変更した。`buildNotificationGroupMap()` でも同様の指摘。

---

## 5. セキュリティ & パーミッション

- 認証: JWT（jjwt）+ Google OAuth / Spring Security で保護
- `/actuator/health`, `/actuator/info` は認証不要（permitAll）

### CORS設定（罠あり・注意）

CORS設定は `CorsConfig`（`CorsConfigurationSource` @Bean）で管理すること。

```java
// ✅ 正しい: CorsConfigurationSource を使う
@Bean
public CorsConfigurationSource corsConfigurationSource() { ... }

// ❌ 禁止: WebMvcConfigurer#addCorsMappings は使わない
// → Spring Security の CorsFilter（FilterChain 5番目）に届かないため
```

### パーミッションチェック（AOP）

管理系機能は `@RequiresPermission` アノテーションで宣言的に権限を制御する。

```java
@RequiresPermission(Permission.INQUIRY_REPLY)
public List<AdminInquiryRow> findPendingStaff() { ... }
```

- `RequiresPermissionAspect`（AOP）が SecurityContext の userId からロールを取得
- `m_role_permission` テーブルのマッピングと照合して 403 を返す
- build.gradle に `implementation 'org.aspectj:aspectjweaver'` が必要

### ロール・パーミッション対応表

| ロール  | code_value | 保有パーミッション                                   |
| ------- | ---------- | ---------------------------------------------------- |
| ADMIN   | `ADMIN`    | USER_LIST_VIEW / ROLE_MANAGE / INQUIRY_REPLY（全て） |
| SUPPORT | `SPPRT`    | INQUIRY_REPLY のみ                                   |

### 例外メッセージに内部IDを含めない（セキュリティ）

例外・エラーレスポンスのメッセージに内部ユーザーID（`userId` 等）を含めてはならない。ログや API レスポンスに内部IDが露出するとセキュリティリスクになる。

```java
// NG: 例外メッセージに内部 userId を含める
throw new IllegalArgumentException(
    "User " + userId + " is already linked to another Google account");

// OK: 固定メッセージのみ使う
throw new AlreadyLinkedException(
    "このGoogleアカウントはすでに別のアカウントに連携されています");
```

> **背景（Sprint 45 レビュー）**: `UserService.java` の Google 連携処理で例外メッセージに内部 userId を埋め込んでいた（4箇所）。

### リソース認可でクライアント入力の householdId を信頼しない（IDOR防止）

リソース（家事・買い物等）の更新・削除の認可は、リクエスト body やクライアントが指定した `householdId` ではなく、**対象リソースIDからサーバー側で世帯を解決**して呼び出し元の所属を検証する。body の `householdId` を信頼すると、攻撃者が自世帯IDを詐称して他世帯のリソースを操作できる（世帯越境 IDOR / confused deputy）。

```java
// NG: body の householdId で認可 → findByHouseworkId は別世帯の record を返しうる（IDOR）
householdAuthorizationService.assertUserBelongsToHousehold(request.getHouseholdId(), userId);
HouseworkModel model = repo.findByHouseworkId(houseworkId); // V の record を更新できてしまう

// OK: houseworkId からサーバー側で世帯解決 → その世帯への所属を検証
HouseworkModel model = repo.findByHouseworkId(houseworkId);
householdAuthorizationService.assertUserBelongsToHousehold(model.getHouseholdId(), userId);
```

- 認可は世帯を解決できる層（Service）に集約する。Controller で body の `householdId` を使う認可は書かない。
- UPDATE / DELETE の SQL も `WHERE ... AND household_id = ?`（解決済み世帯）でスコープして多層防御にする。
- **作成系**は呼び出し元が `request.householdId` の世帯に所属することを必ず検証する（メンバーシップ検証の欠落は他世帯へのレコード注入を許す）。
- ShoppingItem 系（`item.getHouseholdId()` + `canAccessHousehold`）と同じ思想。新しいリソースの作成・更新・削除 API を作るときは必ずこの型で認可する。

> **背景（Sprint 67 #188）**: 家事の更新が body の `householdId` で認可し `WHERE housework_id` のみで更新、作成は呼び出し元のメンバーシップ検証が無く世帯越境の書き込みができた。

### 外部IDトークン検証は aud/iss を必ずチェック（OAuth）

Google 等の ID トークンを tokeninfo で検証する際は、署名・期限だけでなく **`aud`（audience）が自アプリの clientId と一致すること・`iss`（issuer）が正規発行者であること**を必ず検証する。未検証だと別クライアント宛てトークンでのなりすまし（audience confusion）を許す。

- `aud == clientId` はハード必須チェック。`azp` を「aud 不一致でも azp 一致なら通す」OR許容には使わない（修正効果が弱まる）。
- `iss ∈ {accounts.google.com, https://accounts.google.com}` を検証する。
- 検証は**全消費経路が通るチョークポイント**（infrastructure の `verifyIdToken`）1箇所に集約すると、mobileLogin / linkGoogleAccountByIdToken 等の複数経路を同時にカバーできる。
- テストは `MockRestServiceServer` で tokeninfo 応答JSON（aud/iss）を組んで、別aud/iss不正/欠落の拒否と正規audの回帰を検証する。

> **背景（Sprint 67 #187）**: `RestClientGoogleOAuthClient.verifyIdToken` が tokeninfo をマップして返すだけで aud/iss を未検証だった（🔴Critical アカウント乗っ取り経路）。

### クライアント由来のストレージキー（fileKey等）はプレフィックス強制で検証する

S3等のオブジェクトストレージキーをクライアントから受け取って永続化する場合（アップロード完了後の登録APIなど）、キーをそのまま信頼してはならない。サーバー側で「期待するプレフィックス」（世帯ID・ユーザーID等でスコープしたもの）を組み立て、`startsWith` で強制するだけでなく、**プレフィックス以降（残り部分）に `/` や `..` が含まれないことも検証する**。前方一致だけでは `shopping-item/1/100-evil/...` のような前方一致誤爆や、`user-icon/5/../6/icon.jpg` のようなプレフィックス内の `..` 混入を見逃す。

```java
// OK: プレフィックス強制 + 残り部分の "/" ".." 混入チェック
public static void assertKeyWithinPrefix(String fileKey, String expectedPrefix) {
  if (fileKey == null || !fileKey.startsWith(expectedPrefix)) {
    throw new AccessDeniedException("不正なファイルキーです");
  }
  String remainder = fileKey.substring(expectedPrefix.length());
  if (remainder.contains("/") || remainder.contains("..")) {
    throw new AccessDeniedException("不正なファイルキーです");
  }
}
```

拡張子・mimeType の allowlist も同じ理由でクライアント入力の再検証が必要。ファイル名から拡張子を抽出する際は、パス区切り（`/` `\`）より前の部分を無視し最後のセグメントのみを見ることで、ファイル名自体に埋め込まれたパストラバーサル（例: `"a.jpg/../../evil"`）を無害化できる。アップロードURL発行API（presigned URL発行）と登録API（メタ情報保存）が分離・ステートレスな設計の場合、**両方のAPIに同じ検証を適用する**（発行側だけでは登録側から直接バイパスされ得るため）。allowlist・プレフィックス検証は共有utilに集約し、複数経路（例: 添付・アイコン）から呼び出す。

> **背景（Sprint 68 #189）**: `ShoppingItemAttachmentService`/`UserIconService` がクライアント由来の fileKey/拡張子/mimeType を再検証せず、他世帯・他ユーザーの S3 オブジェクトにアクセスできた。共有util `UploadImagePolicy` に集約し、添付・アイコンの両経路（アップロードURL発行・登録）に適用した。

### 認可チェックはリソースの存在・状態を開示する分岐より前に置く（オラクル回避）

トークン等で特定できるリソース（招待・共有リンク等）に対する状態変更操作では、認可チェック（呼び出し元がそのリソースの正当な当事者か）を、**リソースの存在確認（notFound）の直後・状態判定（終端/期限切れ等）より前**に置く。認可を後段に置くと、正当な当事者でない呼び出し元でも `ResourceNotFoundException` 等のレスポンス差異から「そのリソースが存在する」「特定の状態である」という情報を推測できてしまう（オラクル化）。

```java
// OK: notFound判定の直後・状態判定より前に認可チェック
HouseholdInvitationModel inv = invRepository.selectByToken(token);
if (inv == null) {
  throw new ResourceNotFoundException("invitation.notFound");
}

// 認可を最優先（terminal/expired判定より前）
if (!Objects.equals(user.getEmail(), inv.getInvitedEmail())) {
  throw new AccessDeniedException("Authenticated user is not the invitee of this invitation");
}

if (inv.isTerminal()) { ... }
```

> **背景（Sprint 68 #190）**: `declineInvitation`/`revokeInvitation`/`acceptInvitation` の認可チェックをこの順序で統一した。招待の revoke/decline/accept は同一の根本原因（状態変更系メソッドに認可チェックが無い）を持つため、1つを直す際は同一リソースの全ての状態変更メソッドを洗い出すこと。

---

## 6. DB命名規約

```
テーブル種別
  m_xxx   マスターテーブル
  t_xxx   トランザクションテーブル

全テーブル共通カラム（WHOカラム必須）
  create_user / create_time / update_user / update_time

Flywayマイグレーションファイル命名
  V00_000_001__create_user.sql
```

DB操作コマンド（Flyway / MBG / generateEnums）の詳細手順は `.claude/rules/database.md` を参照。

---

## 7. テスト方針（Groovy / Spock）

### 単体テスト

- Groovy + Spock で記述する
- `where:` ブロックを活用し、カバレッジ（Instruction/Branch）を限りなく100%にする

```groovy
// where: ブロックの例
def "タスクのステータス更新"() {
    expect:
    task.updateStatus(input) == expected

    where:
    input           || expected
    Status.DONE     || true
    Status.PENDING  || false
}
```

### 統合テスト

- Groovy + Spock + Testcontainers で記述する
- `@Tag("integration")` を付与し、UTとITを分離する
- `IntegrationTestBase` を継承して作成する
- MySQLコンテナ（mysql:8.4）を使用し、Flywayマイグレーションを自動適用する
- S3等の外部依存は `@MockitoBean` でモックに差し替える
- PRマージ時にCIで自動実行される

---

## 8. hw-hub-batch 固有の注意事項

- backendと同じDDDライク3層構造・命名規約・実装方針を適用する
- バッチ処理は Spring Batch の Job / Step / Tasklet で構成する
- HTTPサーバーとして起動しない（エンドポイントなし）
- EventBridge Scheduler → ECS Fargate の単発タスクとして実行される
- Dockerfileはシングルステージ（JARをCOPYするだけ）
- backendのマルチステージとは異なるため注意

---

## 9. jpetstore-backend 固有の注意事項（Spring Boot 4.x / Spring Security 7）

### Spring Boot 4.1 の自動構成 ObjectMapper は Jackson 3系

Spring管理の `ObjectMapper` を注入する場合は **`tools.jackson.databind.ObjectMapper`**（Jackson 3系）を使う。
`com.fasterxml.jackson.databind.ObjectMapper`（Jackson 2系）は Spring Bean 未登録で
`NoSuchBeanDefinitionException` になる。

```java
// ✅ 正しい（Spring Boot 4.1）
import tools.jackson.databind.ObjectMapper;
import tools.jackson.core.JacksonException; // 例外もJackson3系（非チェック例外）

// ❌ Bean未登録でエラーになる
import com.fasterxml.jackson.databind.ObjectMapper;
```

Jackson 2系（`com.fasterxml.jackson.*`）はjjwt-jackson/springdoc等サードパーティの内部利用のみで
クラスパスに残存する（`@JsonProperty`等のannotationパッケージはJackson3でも`com.fasterxml.jackson.annotation`
のまま変わらない点に注意）。

> **背景（Sprint 2 #23）**: convention-reviewerがJackson2前提で`tools.jackson.*` importを誤指摘（偽陽性）。
> `./gradlew dependencies`の依存木で`spring-boot-starter-jackson → tools.jackson.core:jackson-databind`
> （Jackson3）が実際に解決されることを確認して却下した。Boot 4.1以降のプロジェクトはこの前提で判断すること。

### JWTのaccess/refreshは `typ` claimで型を区別する（secure-by-default）

access/refreshトークンをTTL以外同一構造で発行すると、種別を取り違えて悪用されうる
（例: refresh tokenをaccess token用Cookieに入れると保護エンドポイントに直接認証できてしまう）。

- 発行時に `typ` claim（`"access"`/`"refresh"`）を埋め込む
- 検証メソッドを型ごとに分離する（例: `parseAccessToken`/`parseRefreshToken`）。共通ロジックは
  内部で期待型を受け取り `typ` claimと照合、不一致は検証失敗（`Optional.empty()`等）として扱う
- 消費箇所（認証フィルタ・refresh処理等）はそれぞれ対応する検証メソッドのみを呼ぶ

> **背景（Sprint 2 #23・SecReviewer指摘）**: `JwtService.buildToken`がaccess/refreshで完全同一構造・
> `typ`無しだったため、`jpetstore-backend`の`JwtService`（`parseAccessToken`/`parseRefreshToken`）で対応した。

### 監査ログ等の client_ip は X-Forwarded-For を無条件信頼しない

`X-Forwarded-For`はクライアントが自由に送れるヘッダ。信頼できるリバースプロキシ構成
（プロキシがヘッダを上書きする設定）が無い限り、既定は **`request.getRemoteAddr()`** を使う。
XFFを無条件信頼すると偽装により監査証跡・アクセス制御の判断材料が汚染されうる。
信頼プロキシ配下で運用する場合のXFF採用は、対象プロキシのIPを検証したうえで限定的に拡張する。

> **背景（Sprint 2 #23・SecReviewer指摘）**: `AuditLogRecorder#clientIp`がXFFを無条件信頼していた。

### カスタム（MyBatis Generator非生成）entity/mapperの配置・命名

hw-hub-backendの`infrastructure.mybatis.custom.{entity,mapper}`慣習をjpetstore-backendでも踏襲する。

- 配置: `infrastructure.mybatis.custom.entity` / `infrastructure.mybatis.custom.mapper`
  （生成物の`infrastructure.mybatis.generated.*`とは明確に分離）
- 命名: `XxxCustomEntity` / `XxxCustomMapper`
- 実装方式: 動的条件の無い単純なCRUD（1SQL・パラメータもシンプル）は `@Insert`/`@Select`等の
  アノテーションで簡潔に書いてよい。複雑な動的SQL・JOINはXMLマッパー（`resources/mapper/custom/*.xml`）
  を使う（hw-hub-backendの既存custom mapperはXML中心）
- **純追記表**（update/delete を業務上許可しないテーブル。例: 監査ログ）の entity/mapper は
  **MyBatis Generatorの対象にしない**（意図しないupdate/delete系メソッドが生成されてしまうため）。
  詳細・アーキ上の位置づけは `spec/architecture-conventions.md` §4.4 参照

> **背景（Sprint 2 #23）**: `AuditLogEntity`/`AuditLogMapper`（当初`infrastructure.audit`直下に手書き）を、
> ユーザーからの配置に関する質問を受けて`infrastructure.mybatis.custom.{entity,mapper}`へ
> `AuditLogCustomEntity`/`AuditLogCustomMapper`として改名移設した。

### PasswordEncoderはDelegatingPasswordEncoderを使い、ハッシュに`{bcrypt}`等のプレフィックスを含める

パスワードのハッシュ化・照合は Spring Security 標準の
`PasswordEncoderFactories.createDelegatingPasswordEncoder()`（既定bcrypt）を `PasswordEncoder` Bean として使う。

- エンコード結果は `{bcrypt}$2a$10$...` のようにアルゴリズムIDプレフィックス付きの文字列になる
- **プレフィックス無しの生bcrypt文字列を`matches()`に渡すと失敗する**（`DelegatingPasswordEncoder`は既定で
  `defaultPasswordEncoderForMatches`が未設定のため、プレフィックスからアルゴリズムを解決できない）
- DB seed・テストフィクスチャで bcrypt ハッシュを直接書く場合も、必ず `{bcrypt}` プレフィックスを含めること
- 将来 argon2 等へ移行する場合も、プレフィックス判定により既存ハッシュを壊さず段階移行できる

> **背景（Sprint 3 #19）**: `jpetstore-backend`の`PasswordEncoderConfig`で採用。デモシード
> （`jpetstore-database`の`R__test_user.sql`）の`password_hash`にも`{bcrypt}`プレフィックスを付与した。

### DaoAuthenticationProviderの`hideUserNotFoundExceptions`既定動作を壊さない（列挙不可・SBD-6）

`UserDetailsService#loadUserByUsername`が投げた`UsernameNotFoundException`は、`DaoAuthenticationProvider`が
既定（`hideUserNotFoundExceptions=true`）で誤パスワードと同一の`BadCredentialsException`に正規化する。

- 未知ユーザーのログイン失敗と誤パスワードのログイン失敗を同一の401（ユーザ列挙不可）にするための
  Spring Security標準機能。カスタム`UserDetailsService`実装がこの既定動作を意識せず壊す
  （例外を個別にキャッチして別メッセージ・別ステータスを返す等）と列挙攻撃を許してしまう
- ログイン系エンドポイントの例外処理は、`AuthenticationException`（`BadCredentialsException`含む）を
  一律同一の401レスポンスにマッピングする既存の`GlobalExceptionHandler`にそのまま委譲すればよい

> **背景（Sprint 3 #18）**: `jpetstore-backend`の`JdbcUserDetailsService`で採用。

### 本人スコープ（所有者一致）認可は `OwnershipAuthorizationService` に集約する

ドメイン固有のリソース（注文・アカウント等）への操作を「呼び出し元本人のリソースか」で認可する場合は、
`domain.security.OwnershipAuthorizationService#assertOwner(Long resourceOwnerUserId)` を使う。

- **`resourceOwnerUserId`は必ずサーバー側で解決した値を渡す**（対象リソースIDからRepository等で解決した
  真の所有者userId）。リクエストのparam/body（例: `?userId=`）をそのまま渡してはならない
  （hw-hub-backend §5「リソース認可でクライアント入力のhouseholdIdを信頼しない」と同じ思想＝IDOR防止）
- 判定は`CurrentUserProvider`のみをidentity源とする。不一致・未認証は`AccessDeniedException`を投げ、
  既存の`GlobalExceptionHandler`が403へ正規化しつつ監査ログに記録する（新規のエラーハンドリングは不要）
- ADMINロール等の別経路が必要な場合は`@PreAuthorize("hasRole('ADMIN')")`と併用してよい
  （`OwnershipAuthorizationService`自体はUSERプリンシパルの本人性のみを扱う薄い部品）

```java
// OK: リソースIDからサーバー側で所有者を解決してから検証する
OrderModel order = orderRepository.findById(orderId);
ownershipAuthorizationService.assertOwner(order.getUserId());

// NG: クライアント入力のuserIdをそのまま検証に使う（IDOR）
ownershipAuthorizationService.assertOwner(request.getUserId());
```

> **背景（Sprint 4 #21）**: 認可土台として`OwnershipAuthorizationService`（`domain.security`）を新設。
> 本Storyでは対象ドメインリソースが未実装のため`SecuredPingController#myResource`での実証にとどめ、
> 各ドメインへの適用（リソースIDから所有者を解決する処理）は各Storyへ委譲した。

### 「現在の自分」を返す自己識別エンドポイント（`/me`パターン）は`permitAll`に入れない

フロントのクライアント状態（Pinia/Reduxストア等）はページリロードで揮発するが、httpOnly Cookieで
保持するトークンはリロード後もブラウザが自動送信する。フロントが起動時に identity を再水和するための
「現在の自分」エンドポイント（例: `GET /api/auth/me`）は、以下のパターンで実装する。

- **`SecurityConfig`の`permitAll`には追加しない**。既存の`anyRequest().authenticated()`配下に置けば、
  未認証リクエストはコントローラに到達する前に既存の`AuthenticationEntryPoint`が401を返す
  （新規の認証チェックを自前で書く必要が無い）
- 実装は`CurrentUserProvider.requireCurrentUser()`から取得した`AuthenticatedUser`をそのまま返すだけでよい。
  **クエリ/パスパラメータで対象ユーザーを指定させない**（他人のidentityを引けると列挙・なりすまし調査の
  オラクルになる。常に「認証プリンシパル自身」のみを返す）
- GET＝冪等のためCSRFトークンは不要（Spring SecurityのCSRF保護は既定で非GETのみ対象）

```java
// OK: 自分自身のidentityのみを返す。permitAllに入れない
@GetMapping("/me")
public ResponseEntity<LoginResponse> me() {
  AuthenticatedUser user = currentUserProvider.requireCurrentUser();
  return ResponseEntity.ok(new LoginResponse(user.username(), user.roles()));
}
```

> **背景（Sprint 5 #24）**: フロント（jpetstore-frontend）のリロード後identity再水和のため
> `AuthController`に`GET /api/auth/me`を追加。既存の`login`応答DTO（`LoginResponse`）をそのまま
> 再利用し新規DTOを増やさなかった。

> Swagger UIのpermitAll・`server.error.*`→`spring.web.error.*`・依存更新後のIDE lint staleness・
> `@RestControllerAdvice`のcatch-allがフレームワーク例外（`HttpRequestMethodNotSupportedException`等）を
> 意図しないステータスに丸める問題・CSRFトークンのconsume-then-regenerate挙動・セキュリティ上意味のある
> 日時比較はDB側`NOW(6)`で行うべき問題（Sprint4）・`ON DUPLICATE KEY UPDATE`のSET句左→右評価順依存の
> 二重計算（Sprint4）は、いずれも初出（1回目）のため、2回ルールに従い本Skillには未反映
> （`memory/dev/long_term.md`「技術的なハマりポイント」参照）。2回目の発生でSkill昇格を検討する。
