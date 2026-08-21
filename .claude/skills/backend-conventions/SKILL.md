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
- Application Service は **Domain 層の Repository インターフェイス**を注入して永続化にアクセスする。MyBatis の Mapper（`*Mapper` / `*CustomMapper`）・Entity（`*Entity` / `*CustomEntity`）を Application 層へ注入・import しない。Repository 実装は Infrastructure 層に置き、Mapper 呼び出しと Entity→Domain 変換（§2）をそこに閉じる（依存性逆転＝上図：Infrastructure が Domain のインターフェイスを実装する）
- `com.hwhub.backend.domain.enums` 配下の自動生成Enumは編集禁止

### オブジェクト種別と層ごとの依存ルール

| 層             | オブジェクト種別            | Presentation | Application | Domain | Infrastructure | メモ                                                       |
| -------------- | --------------------------- | :----------: | :---------: | :----: | :------------: | ---------------------------------------------------------- |
| Presentation   | request/response DTO        |      ○       |      ×      |   ×    |       ×        | class / record どちらでも可                                |
| Application    | Presentation層への戻り値DTO |      ○       |      ○      |   ×    |       ×        | Service の Inner Class として record で実装                |
| Domain         | Model                       |      ○       |      ○      |   ○    |       ○        | 業務的な単位・業務処理あり                                 |
| Domain         | 参照系Model                 |      ○       |      ○      |   ○    |       ○        | record で実装                                              |
| Domain         | 検索条件VO                  |      ○       |      ○      |   ○    |       ○        | record で実装（MyBatis mapper のパラメータとして対応済み） |
| Domain         | Repository interface        |      ×       |      ○      |   ○    |       ○        | 実装はInfrastructure層（DIで注入）。永続化アクセスの唯一の入口 |
| Infrastructure | generated entity            |      ×       |      ×      |   ×    |       ○        | MBG生成・テーブルと1対1                                    |
| Infrastructure | custom entity               |      ×       |      ×      |   ×    |       ○        | JOINの結果を受け取るための手書きEntity                     |

**重要な制約**

- `generated entity` / `custom entity` は Infrastructure 層に閉じる。Service / Controller には絶対に出さない
- Presentation 層の DTO は Controller 内で完結させ、Service には渡さない
- Application Service は Repository インターフェイス（Domain層）経由でのみ永続化にアクセスする。`*Mapper` / `*CustomMapper` や `*Entity` / `*CustomEntity` を Application 層へ注入・import しない（jpetstore の現状ドリフトと目標形は §9「Application Service は Repository 経由」を参照）

---

## 2. ドメインモデル & コンバーター

- Domainクラスのコンストラクタは `private` とし、再構築には `reconstruct()` ファクトリメソッドを使用する
- Infrastructure層からDomainに変換する際は、手書きの `XxxConverter` を作成し `toModel` メソッド内で `reconstruct()` を呼ぶ
- `XxxConverter` は **Repository の実装クラス（Infrastructure層）から呼び出す**。これにより Application 層は Entity を一切見ず Domain モデルのみを受け取る（§1・§9）。参照系Model（record）は `reconstruct()` を必須とせず直接生成してよいが、Entity→record 変換自体も Repository 実装内に閉じる
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

### 初のMyBatisカスタムXMLマッパー導入時は`mybatis.mapper-locations`の明示設定が必須

MyBatis Generator生成物（`resources/mapper.generated`）しか使っていないプロジェクトで初めて手書きの
`resources/mapper/custom/*.xml` を追加する場合、`application.yml` に以下を明示しないと
`mapperLocations` が未設定（null相当）のままとなり、追加したXMLマッパーが一切ロードされない。

```yaml
mybatis:
  mapper-locations: classpath:mapper/**/*.xml
```

起動時エラーにはならず、該当SQLが見つからない実行時失敗として顕在化するため気づきにくい。
`mapper/**/*.xml` のようなワイルドカードでgenerated/customの両方を一括カバーする設定にすること。

> **背景（Sprint 6 #1）**: `jpetstore-backend`本プロジェクト初のMyBatis XMLマッパー利用（カタログ参照系）
> で発生。`application.yml`に`mybatis.mapper-locations`を追加して解消した。

### PasswordEncoderはDelegatingPasswordEncoderを使い、ハッシュに`{bcrypt}`等のプレフィックスを含める

パスワードのハッシュ化・照合は Spring Security 標準の
`PasswordEncoderFactories.createDelegatingPasswordEncoder()`（既定bcrypt）を `PasswordEncoder` Bean として使う。

- エンコード結果は `{bcrypt}$2a$10$...` のようにアルゴリズムIDプレフィックス付きの文字列になる
- **プレフィックス無しの生bcrypt文字列を`matches()`に渡すと失敗する**（`DelegatingPasswordEncoder`は既定で
  `defaultPasswordEncoderForMatches`が未設定のため、プレフィックスからアルゴリズムを解決できない）
- DB seed・テストフィクスチャで bcrypt ハッシュを直接書く場合も、必ず `{bcrypt}` プレフィックスを含めること
- 将来 argon2 等へ移行する場合も、プレフィックス判定により既存ハッシュを壊さず段階移行できる
- **bcryptは入力を72バイトまでしか使わず、それを超えるバイト列は暗黙に切り詰められる。** パスワード強度
  バリデータ等で上限文字数を設ける場合、`length()`（文字数）ではなく
  `value.getBytes(StandardCharsets.UTF_8).length`（UTF-8バイト長）で判定すること。マルチバイト文字
  （日本語等）を含むパスワードは、文字数が72未満でもバイト長が72を超えうる（ASCIIのみの入力では文字数=
  バイト数のため誤りに気づきにくい）。

> **背景（Sprint 3 #19）**: `jpetstore-backend`の`PasswordEncoderConfig`で採用。デモシード
> （`jpetstore-database`の`R__test_user.sql`）の`password_hash`にも`{bcrypt}`プレフィックスを付与した。
> **Sprint 17 #15**: 新設`@StrongPassword`制約（下記参照）の上限バリデーションで、文字数判定のままだと
> マルチバイトパスワードの暗黙切り詰めを見逃すことが判明し、UTF-8バイト長判定に修正した
> （frontend側`isStrongPassword`も`TextEncoder`でミラー）。

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

### 所有者限定＋列挙対策の read エンドポイントは、不存在も含めて同一の`AccessDeniedException`（403）に正規化する

連番（auto increment等）で推測可能なリソースID（例: `orderId`）に対する本人限定の詳細取得APIは、
「リソースが存在しない」と「リソースは存在するが自分の所有ではない」を**同一の403**として応答する。
存在有無で応答（403 vs 404）を分岐させると、攻撃者がIDを総当たりするだけで「そのIDのリソースが
存在するか」を判別できてしまう（列挙オラクル化・SBD-8）。

```java
// OK: 不存在・非所有のいずれも同一のAccessDeniedException（→403）に正規化する
OrderHeader header = orderRepository.findHeaderById(orderId)
    .orElseThrow(() -> new AccessDeniedException("Order not found or not owned"));
ownershipAuthorizationService.assertOwner(header.userId());
```

- **上記「認可チェックはリソースの存在・状態を開示する分岐より前に置く」（§5）との使い分け**:
  招待トークン等、ID自体が既に推測困難（UUID・署名付きトークン等）なリソースは、
  `ResourceNotFoundException`（404）→認可チェック（403）の順で構わない（存在確認自体は情報漏洩に
  ならない）。一方、連番などIDそのものが容易に推測・総当たり可能なリソースは、存在確認の結果自体を
  秘匿する必要があるため、不存在も`AccessDeniedException`に含めて一律403にする。
- 明細等の付随データ（例: 注文明細）は**認可通過後にのみ**取得する。所有者解決用の読取（例:
  ヘッダ）と最終応答用の読取を同一メソッドで済ませ、認可通過前に不要な追加クエリを発行しない
  （識別子解決用の読取と最終応答用の読取を分けずに使い回す＝Sprint12/13のperf教訓の踏襲）。

> **背景（Sprint 14 #10）**: `OrderApplicationService#getOrder`で`OwnershipAuthorizationService`
> （#21）を初めて実ドメインへ適用した。`findHeaderById`が空の場合と`assertOwner`が失敗する場合の
> 両方を同一の`AccessDeniedException`にまとめ、既存の`GlobalExceptionHandler`が403＋監査へ正規化する
> 経路にそのまま合流させた（新規の例外型・専用ハンドラは不要）。

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

### 区分値をm_code化する場合、算出ロジックは生成enumに書かず非生成クラスに分離する

`./gradlew generateEnums`（EnumGenerator）は**全`m_code` `code_type`を一括で`domain/enums/*.java`に生成**する
（特定の`code_type`だけを選んで生成することはできない）。そのため、区分値に付随する算出ロジック（例:
数量から在庫ステータスを判定する`of(qty)`）を生成対象のenumクラスに実装すると、次回の`generateEnums`実行で
上書きされ消失する。

- 生成されたenum（例: `StockStatus`）は区分値の**値と表示名のみ**を保持する生成物として扱い、編集しない
- 算出ロジックは同じ`domain`パッケージ内の**別の非生成クラス**（例: `StockStatusCalculator#of(int quantity):
  StockStatus`）に分離する
- 閾値等のマジックナンバーは定数/configとして非生成クラス側に持たせる（生成enumには持たせない）

> **背景（Sprint 6 #1）**: 在庫ステータスをm_code区分値として採用（ユーザー方針「区分値は基本的にm_codeに
> 登録する」）。生成された`StockStatus.java`に`of(qty)`を実装すると再生成で消えるため、`StockStatusCalculator`
> （非生成）に分離した。

### 一覧APIの汎用ページングDTOは`Page`/`PageRequest`/`PageResponse<T>`の3型構成・1-index

複数件を返す一覧API（カテゴリ内商品一覧・商品内item一覧等）のページングは、以下の3型構成に統一する。

- `domain.common.PageRequest`（VO・リクエスト側。`page`/`size`を保持）
- `domain.common.Page<T>`（Application層の戻り値。`content`/`page`/`size`/`totalElements`/`totalPages`）
- `presentation.rest.dto.PageResponse<T>`（Controller層。`Page<T>`から変換してJSONへ返す）
- **ページ番号は1-index**（`page=1`始まり。0-indexにしない）。既定`size`はAPIごとに定める（例: 既定12・
  上限cap 100）
- Application層はDomainの`Page<T>`のみを扱い、Presentation層のDTO（`PageResponse<T>`）には依存しない
  （変換はController側で行う）

> **背景（Sprint 6 #1）**: カタログ一覧API（category内product一覧・product内item一覧）で確立。
> #2（商品検索）・#9（注文履歴一覧）が再利用する先例規約として明文化。

### catch-allの`@ExceptionHandler(Exception.class)`はフレームワーク例外を横取りする（新規エンドポイント追加時は都度棚卸し）

`GlobalExceptionHandler`のような catch-all（`@ExceptionHandler(Exception.class)`）を持つ
`@RestControllerAdvice`は、専用ハンドラの無いフレームワーク例外まで拾って意図しないステータス
（多くは500）に丸めてしまう。Spring MVCが個別ステータスへ自動マッピングするはずの例外は、
新規エンドポイント・パラメータを追加するたびに横取りされていないか棚卸しし、必要な専用ハンドラを
明示的に追加すること。

これまでに顕在化した該当例外（見つかり次第このリストへ追記する）:

| 例外 | 本来のステータス | 発生条件 |
|---|---|---|
| `HttpRequestMethodNotSupportedException` | 405 | 未マッピングHTTPメソッドへのアクセス |
| `MethodArgumentTypeMismatchException` | 400 | クエリ/パスパラメータの型変換失敗（非数値・桁あふれ等） |
| `MissingServletRequestParameterException` | 400 | 必須クエリパラメータの欠落 |
| `NoResourceFoundException` | 404 | どのハンドラマッピング・静的リソースにも一致しない未知パス |
| `HttpMessageNotReadableException` | 400 | リクエストボディの型不一致・不正JSON（非数値文字列等でのデシリアライズ失敗） |
| `DataIntegrityViolationException` | 400 | `@Size`/`@Valid`カスケード等の入口検証をすり抜けた想定外のDB制約違反（列幅超過・NOT NULL違反等） |

> **背景（Sprint 3 #18・Sprint 7 #3）**: Sprint 3で`HttpRequestMethodNotSupportedException`が
> catch-allに落ちて500になる問題が初めて発覚（自動テストで顕在化）。当時は初出のためSkill未反映
> だったが、Sprint 7で`?page=abc`のような型不一致・未知パスへのアクセスが同じ理由で500に落ちる
> 穴が再発したため、2回目としてSkillへ昇格した。新規`@RequestParam`・新規エンドポイントを追加する際は
> 上表の例外が発生しうるケース（非数値パラメータ・存在しないパス等）を実機/自動テストの両方で確認する。
> **Sprint 9 #5**では`UpdateCartItemRequest.quantity`に非数値文字列（`"abc"`）を送るケースで
> `HttpMessageNotReadableException`（リクエストボディのデシリアライズ失敗）が同じ理由で500に落ちる穴が
> 見つかり表に追記した（新規パターンの2回ルール判定ではなく、既にSkill昇格済みの本テーブルへの追加）。
> 新規`@RequestBody`を扱うエンドポイントを追加する際は、ボディの型不一致（非数値文字列等）も
> 上表の確認対象に含めること。

### LIKE等のSQL用サニタイズ・エスケープ処理はSQL文字列非依存の純VOに隔離する

検索語のLIKEメタ文字（`%`/`_`/`\`）エスケープのような「入力文字列を安全な形へ変換するだけ」の
ロジックは、SQL文字列の組み立てや`#{}`バインドとは完全に分離した純粋なドメインVO（record等）に
実装する。

- VOはトークン分割・エスケープ後の文字列（例: `%esc%`パターン列）のみを返し、SQL文字列そのものは
  一切組み立てない（呼び出し側のMyBatis `#{}` バインドに委譲する）
- こうすることで、VO単体のロジック（境界値・メタ文字混入等）をDB接続（Testcontainers）を必要としない
  高速な単体テストで検証できる。DB統合テストは「VOが返したパターンをSQLに渡した結果が正しいか」の
  確認のみに絞れる
- MySQLの`LIKE ... ESCAPE '\\'`句は、SQLテキスト中に**2つのバックスラッシュ文字**を書く
  （MySQL文字列リテラルの規則でエスケープされ実際には1文字の`\`になる。`generatorConfig.xml`の
  `LIKE 'm\_%' ESCAPE '\\'`が先例）

> **背景（Sprint 7 #2・ID-29）**: 検索語の`%`/`_`をLIKEワイルドカードとして機能させずリテラル化する
> ハードニングを`domain.catalog.ProductSearchTerms`に実装。SQL非依存の`ProductSearchTermsSpec`
> （Spock・DBなし）でエスケープ境界値を実証し、`CatalogCustomMapperSpec`（Testcontainers）は
> 実際のLIKE一致結果の確認のみに絞れた。

### 呼び出し元txのロールバックに影響されない独立監査記録は`@Transactional(REQUIRES_NEW)`の別beanメソッドで実装する

失敗した状態変更（在庫不足・バリデーション失敗等）の監査ログを「呼び出し元の主トランザクションが
ロールバックされても記録として残す」必要がある場合、`AuditLogRecorder`のような監査コンポーネント側に
`@Transactional(propagation = Propagation.REQUIRES_NEW)`を付けた専用メソッドを新設し、呼び出し元は
そのメソッドを呼ぶだけにする。

- **REQUIRES_NEWは必ず別bean（Spring管理コンポーネント）のメソッド経由で呼ぶこと。** Spring AOPの
  プロキシは自己呼び出し（同一クラス内の`this.xxx()`呼び出し）を素通りするため、`@Transactional`を
  付けたメソッドを同じクラスの別メソッドから呼んでも新トランザクションは開始されない（Spring AOPの
  古典的な落とし穴）。呼び出し元（例: `OrderApplicationService`）と監査コンポーネント（`AuditLogRecorder`）が
  別beanであれば、呼び出しは必ずプロキシを経由するため正しく機能する。
- 主フローの成功時記録（`recordStateChange`）とは別メソッド（`recordStateChangeIndependently`）として
  用意し、`@Transactional`を明示的に付けない既存メソッドと伝播レベルを混同しないようにする。
- 追記専用テーブル（監査ログ等）への独立INSERTは、対象となる主フローのテーブル（在庫等）の行ロックと
  競合しないためデッドロックの心配がない。

```java
// OK: 別beanのメソッド経由（プロキシが正しく介在する）
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void recordStateChangeIndependently(
    String action, String targetType, String targetId, String result, Object detail) {
  // ...insert...
}

// 呼び出し元（別クラス）
try {
  // ...在庫減算・注文INSERT...
  auditLogRecorder.recordStateChange(action, type, id, "SUCCESS", detail);
} catch (InsufficientStockException e) {
  auditLogRecorder.recordStateChangeIndependently(action, null, null, "FAILURE", detail);
  throw e; // 主txは通常どおりロールバックされるが、監査行は別txで既にコミット済み
}
```

> **背景（Sprint 11 #8）**: 注文確定の在庫不足・空カート失敗時にも監査記録を残す要件（SM決定：成功/失敗の
> 両方を記録）で、`AuditLogRecorder#recordStateChangeIndependently`として新設した。本プロジェクト初の
> `REQUIRES_NEW`利用。

### Application Service は Repository 経由で永続化にアクセスする（MyBatis Mapper を直接注入しない）

§1 / §2 のとおり、Application Service は **Domain 層の Repository インターフェイス**を注入し、MyBatis の
`*CustomMapper` や `*CustomEntity`（Infrastructure層）を Application 層へ import・注入してはならない。
jpetstore-backend は Story 単位で Sprint を進める過程で Service が `CatalogCustomMapper` /
`CartCustomMapper` を直接注入し `*CustomEntity` を Application 層で扱う実装に**ドリフトしている**
（§1「Entity は Infrastructure 層に閉じる」違反）。HwHub 由来の §1/§2（依存性逆転・Repository 経由）が
jpetstore で未追認のまま Mapper-first に流れたもの。以下の目標形へ是正する（convention-reviewer は
Application 層に `infrastructure.mybatis.*` への依存が残っていないかを確認する）。

- **インターフェイスは Domain 層、実装は Infrastructure 層**に置く（依存性逆転）。
  - 例（Cart）: `domain.cart.CartRepository`（interface・ドメイン語彙 `findByUserId` / `save`）／
    実装 `infrastructure.mybatis.cart.MyBatisCartRepository`（`CartCustomMapper` と `XxxConverter` を保持し、
    戻り値は Domain モデルのみ。`*CustomEntity` を Application 層へ出さない）
- **書き込み側は集約リポジトリ**にする。在庫上限・加算オーバーフロー（`Math.addExact`）・merge クランプ等の
  不変条件は Service ではなく `Cart` / `CartItem` ドメインモデルのメソッドに置く（現状の anemic domain ＋
  トランザクションスクリプトからの脱却）。在庫qty（`stockQuantity`）は不変条件の強制に必要なため集約内では
  保持してよいが、Application / Presentation の外向き表現では落とす（在庫数非露出＝ID-28。業務不変条件は
  ドメイン、露出制御は presentation の責務）。
- **読み取り側（カタログ一覧・検索・詳細）は CQRS 射影**として扱う。Domain 層に query インターフェイスは
  置くが、返すのは read-model の record（`Product` / `ItemSummary` / `Page<T>`）のままでよく、集約の
  `reconstruct()` 再構築を強制しない（過剰抽象を避ける）。Entity→record 変換は Repository 実装内で行う。
- 動機の優先順位: 「MySQL→別DB / ファイルへ差し替え可能に」は弱い（YAGNI）。実利益は ①層純化で在庫qty
  非露出を型で強制 ②Repository インターフェイスのモックで Service を DB 非依存の Spock UT ③N+1（§4a）・
  IDOR（§5）・`OwnershipAuthorizationService`（§9）等が前提とする永続化アクセスの単一チョークポイント。

> **背景（2026-08-17 ユーザー合意 / #29 #30）**: HwHub 時代からの DDDライク3層設計者（ユーザー）と、
> Application Service の Mapper 直呼びドリフトを確認して是正方針を確定。まず本規約を明文化（本エントリ・
> §1/§2 追記）、次に Cart を参照実装として Repository ＋集約化を PoC（#29）、その後 Catalog/Account/Auth へ
> 展開（#30）。実装は各 Story で対応するため、本追記時点ではコードは未変更。

> Swagger UIのpermitAll・`server.error.*`→`spring.web.error.*`・依存更新後のIDE lint staleness・
> CSRFトークンのconsume-then-regenerate挙動・セキュリティ上意味のある日時比較はDB側`NOW(6)`で
> 行うべき問題（Sprint4）・`ON DUPLICATE KEY UPDATE`のSET句左→右評価順依存の二重計算（Sprint4）・
> `syncTestSchema`が`flyway/sql-test`を同期対象外とする点（Sprint6）・`m_code.code_value`の
> VARCHAR(10)制約（Sprint6）・MockMvc経由でCSRF Cookie属性（SameSite等）を検証できない制約と
> bean切り出しユニットテストによる回避策（Sprint9）・GroovyのGStringが`equals(String)`で常にfalseに
> なる問題（Sprint10）・SpockのStubがインターフェースのデフォルトメソッドへ委譲しない問題（Sprint10）・
> `m_item.item_id`等VARCHAR(10)自然キー列へテスト用IDを設計する際の桁数超過（Sprint11）・
> Repository層導入時に「識別子解決用の読取」と「最終応答用の読取」を同じ集約全体読み込みメソッドで
> 済ませてしまいクエリ数が純増する問題（Sprint12・回避パターンは下記「#29 PoCで確立した実装パターン」
> 参照）は、いずれも初出（1回目）のため、2回ルールに従い本Skillのチェックリストには未反映
> （`memory/dev/long_term.md`「技術的なハマりポイント」「繰り返し指摘されるパターン」参照）。
> 2回目の発生でSkill昇格を検討する。

### Spockの`then:`インタラクションは`given:`の裸stubより優先される（同一呼び出しはmatcherと`>>`を1つのthen:にまとめる）

Spockの`Mock()`で、同一メソッド・同一引数パターンの呼び出しに対し `given:` ブロックの裸stub
（`mock.method(_) >> {...}`）と `then:` ブロックの引数一致インタラクション（`N * mock.method({matcher})`）を
**分けて宣言すると、`then:`側が優先され`given:`側の返り値/副作用クロージャが無視される**（Groovy/Spockの
既知の挙動）。返り値がnull/デフォルト値になり、後続コードがNPEや期待値の比較失敗を起こす。

```groovy
// NG: given:の裸stubとthen:の引数一致インタラクションを分けて書く
// → then:が優先されgiven:の副作用(header.cartId = CART_ID)が無視され、cartIdはnullのまま
def "ensureCartはcartIdを返す"() {
    given:
    cartCustomMapper.ensureCart(_ as CartHeaderCustomEntity) >> { CartHeaderCustomEntity h ->
        h.cartId = CART_ID
    }

    when:
    def cartId = repository.ensureCart(USER_ID)

    then:
    cartId == CART_ID                                        // 失敗（実際はnull）
    1 * cartCustomMapper.ensureCart({ it.userId == USER_ID })
}

// OK: 1つのthen:インタラクションにmatcherと>>(返り値/副作用クロージャ)をまとめる
def "ensureCartはcartIdを返す"() {
    when:
    def cartId = repository.ensureCart(USER_ID)

    then:
    1 * cartCustomMapper.ensureCart({ it.userId == USER_ID }) >> { CartHeaderCustomEntity h ->
        h.cartId = CART_ID
    }
    cartId == CART_ID                                        // 成功
}
```

同一呼び出しに対して「返り値/副作用の設定」と「呼び出し内容（引数・回数）の検証」を両方行いたい場合は、
必ず1つの`then:`インタラクションへ引数マッチャーと`>>`をまとめて書くこと。`given:`側で裸stubを書くのは、
`then:`側でその呼び出しの引数・回数を明示検証**しない**場合のみに限る。

> **背景（Sprint11 #8で初出→Sprint12 #29で2回目発生・2回ルール昇格）**: Sprint11の
> `OrderApplicationServiceSpec`（`orderCustomMapper.insertOrderHeader(_)`の`orderId`補完クロージャが
> `then:`の引数一致検証と衝突しNPE）で初めて発覚。Sprint12の`CartApplicationServiceSpec`
> （`cartRepository.ensureCart`/`findByCartId`スタブ）・`MyBatisCartRepositorySpec`
> （`cartCustomMapper.ensureCart`スタブ）の両方で同じ罠を踏みRED化したため2回目と判定し、Skillへ昇格した。

### #29 PoCで確立した実装パターン（#30が踏襲する先例テンプレ）

コードベース初のRepository層導入（Cart PoC・#29）で確立した3パターン。#30（Catalog/Account/Order全体展開）
はこれらをそのまま踏襲できる。

1. **集約は`record`ではなく`class`＋privateコンストラクタ＋用途別static工場メソッドにする**。不変条件
   コマンドメソッド（`Cart#addItem`等）を持たせるにはrecordでは不十分（正準コンストラクタが公開されてしまい
   不正な状態を作れてしまう）。読取再構築用の`reconstruct(...)`（Converterから呼ぶ・全フィールド指定）と、
   書込専用の`forWrite(...)`（package-private・永続化に必要な最小フィールドのみ）を用途別に分離する。
   ```java
   public final class Cart {
     private Cart(Long cartId, List<CartItem> items) { ... }
     public static Cart reconstruct(Long cartId, List<CartItem> items) { return new Cart(cartId, items); }
     public static Cart identity(Long cartId) { return new Cart(cartId, List.of()); } // 下記2参照
   }
   ```
2. **集約のコマンドメソッドが集約state（`items`等）を使わず注入VOのみで動く設計の場合、軽量identityハンドル
   を用意する**（`Cart.identity(cartId)`）。「識別子解決」のためだけに集約全体（明細JOIN込み）を読み込む
   必要が無くなり、Repository層導入時にありがちなクエリ数純増（上記「未反映の技術的ハマりポイント一覧」
   Sprint12参照）を構造的に避けられる。この軽量ハンドルは表示用途には使わない（`items`/`subtotal`は空/ゼロ）
   ことをJavadocで明記する。
3. **Repositoryモック合成でDB非依存のクエリ数証明UTを書く**。実DBのクエリカウント計測インフラが無くても、
   「Repository実装の各メソッド＝1 SQL文であること」（`MyBatisXxxRepositorySpec`・Mapper mock・
   `N * mapper.method(...)`で検証）と「Application Serviceが各Repositoryメソッドを正確にN回だけ呼ぶこと」
   （`XxxApplicationServiceSpec`・Repository mock・`N * repository.method(...)`で検証）を組み合わせれば、
   書込1操作あたりのSQL発行数をDB接続なしかつ決定的に裏取りできる。

> **背景（Sprint12 #29）**: SMが3reviewer全員クリア後にコア精読で発見したperf差分（書込4操作の
> `findByUserId`二重呼び・+2クエリ/操作）の是正で確立。詳細な設計判断は`memory/dev/long_term.md`
> 「習得したこと」（jpetstore-backend）参照。

### 書込集約の適用範囲（rich集約 vs 薄い書込record＋orchestration残置・#30で確定）

上記1（record→class＋reconstruct）は**すべての書込系Repositoryに機械的に適用するパターンではない**。適用可否は
「集約の不変条件がどれだけ濃いか」で判断する。

- **rich集約（record→class＋reconstruct、上記1）が適するケース**: `Cart`/`CartItem`のように、在庫上限・
  オーバーフロー検出・mergeクランプ等の**item単位の不変条件**がドメインモデル自身のメソッドで表現できる場合。
- **薄い書込record＋orchestration残置が適するケース**: `Order`のように、並行制御（`@Transactional`の
  all-or-nothing・item_id昇順固定順ループ・ガード付きアトミック減算・`REQUIRES_NEW`失敗監査）が
  **persistence/txの関心**であり、item単位の不変条件が薄い場合。この場合はrich集約（private ctor＋
  `reconstruct()`＋不変条件メソッド）を作らず、`NewOrder`/`OrderLine`のような最小の書込み用record（VO）のみを
  新設し、オーケストレーション（トランザクション境界・固定順ループ・`AffectedRows.requireUpdated`の呼び出し・
  監査記録）はApplication Serviceに残す。Repositoryは単文アトミック委譲＋Entity構築＋WHOカラム解決に純化する。

過剰にrich集約化すると、tx/並行制御の関心事がドメインモデルのメソッドに漏れ出し、`@Transactional`境界や
固定順ループの意味がドメイン層とApplication層に分散してしまう（YAGNI違反）。新規に書込系Repositoryを設計する
際は、まず対象集約の不変条件がitem単位でどれだけ濃いか（Cart型）か、tx/並行制御がどれだけ支配的か（Order型）
かを見極めてから、上記1を適用するかどうかを判断すること。

> **背景（Sprint13 #30・O1）**: `OrderApplicationService`のRepository化で、当初は#29と同じrich集約化を
> 踏襲する想定だったが、DEVが計画フェーズで「#8の並行制御はpersistence/txの関心でありCartのようなitem単位の
> 不変条件が薄い」と分析し、ユーザー承認のうえ薄い書込record＋orchestration残置（案A）を採用した。POから
> 「Issue本文の『#29集約パターンに準拠』という文言がrich集約と読めた」との指摘があり、本節でこの判断軸を
> 明文化した。詳細は`memory/dev/long_term.md`「習得したこと」（jpetstore-backend）参照。

### 型自体が撤去/非依存のフレームワーク機能の構造的不在は、Bean不在ではなくクラス不在（`Class.forName`）で回帰テスト固定する

Spring 6+ で `org.springframework.remoting.*` のエクスポータ階層（`HessianServiceExporter`/`BurlapServiceExporter`/
`HttpInvokerServiceExporter`/`RmiServiceExporter`/`RemoteExporter`等）自体が撤去されているため、「Springコンテキ
ストに該当Beanが登録されていないこと」をassertする通常の方式は使えない（型そのものがクラスパスに存在せずimport
すらできない）。このように**型自体が撤去/非依存のフレームワーク機能の構造的不在**を回帰テストで固定したい場合は、
`Class.forName(fqcn)` が `ClassNotFoundException` になることを直接assertするplain Spock（Spring context不要・
DBも不要）を書く。

```groovy
def "remoting/WSエクスポータ/エンドポイントクラス(#className)はclasspathに存在しない(SBD-7)"() {
    when:
    Class.forName(className)

    then:
    thrown(ClassNotFoundException)

    where:
    className << [
            'org.springframework.remoting.caucho.HessianServiceExporter',
            'org.springframework.remoting.httpinvoker.HttpInvokerServiceExporter',
            'org.springframework.remoting.rmi.RmiServiceExporter',
            'org.springframework.remoting.support.RemoteExporter',
            // ...
    ]
}
```

将来これらの依存が誤って追加された場合、本specが即座に赤化して退行を検知する。Sprint4のSBD-9（オープンリダイレクト
sink不在の回帰固定）と同じ「不在の実証」哲学を、「削除対象コードが元から存在しない既達判定Story」に適用する際の
具体的な実装技法として使い分ける。あわせて、露出面をREST（`presentation.rest`）のみに限定する旨は`package-info.java`
（Javadocパッケージコメント）で明文化する（ADRディレクトリの慣習が本コードベースに無いため、パッケージ境界の説明は
package-infoに置く）。

> 発生スプリント: Sprint15（#11・`RemotingSurfaceAbsenceSpec`＋`presentation/rest/package-info.java`）

### セキュリティ関連の試行カウンタ/レート制限はDB-backedテーブルで永続化する（in-memoryにしない）

ログイン試行制限・登録レート制限のような「セキュリティ上意味のある回数カウンタ」は、原則としてin-memory
（アプリケーションプロセス内のMap/キャッシュ）ではなく専用のDBテーブル（`t_xxx_attempt`）へ永続化する。
理由は2つ: ①アプリケーションの再起動でカウンタが消失すると制限が無かったことになる、②将来的にマルチ
インスタンス構成になった場合インスタンスごとに別カウンタとなりバイパスの温床になる（本プロジェクトは
現状シングルインスタンスだが、in-memory実装は将来スケールした際に静かに無効化される）。新規に試行
カウンタ/レート制限を設計する際は、まずDB-backedを第一候補として検討し、in-memoryを選ぶ場合は明示的な
理由（例: 業務上重要でない・秒単位の粒度が必要等）をユーザーに確認してから採用する。

- 単文アトミック更新（`INSERT ... ON DUPLICATE KEY UPDATE`）でread-then-writeの競合を避ける
  （`LoginAttemptCustomMapper`/`RegisterAttemptCustomMapper`）。
- 時刻比較（ロック期限・ウィンドウ判定）はJava側ではなくDB側（`NOW(6)`）で行う（Sprint4の教訓・環境間
  クロックスキュー回避。上記「技術的なハマりポイント」参照）。
- キーは用途に応じて選ぶ（認証済みログイン失敗＝`username`／未認証な登録＝`client_ip`。いずれもFK制約・
  version列は不要）。`client_ip`は`X-Forwarded-For`を無条件信頼せず`request.getRemoteAddr()`を既定にする
  （既出）。
- 超過判定はService層のゲート（`assertNotLocked`/`assertNotRateLimited`）に閉じ、既存の失敗系統
  （401/429等）へ合流させる（新しい失敗系統を作らない）。
- **枠確保の原子化トランザクションは`@Transactional(propagation = Propagation.REQUIRES_NEW)`で統一し、
  同型のカウンタ系サービス間で伝播属性が非対称にならないようにする。** `RegisterAttemptService`/
  `AuditWriteQuotaService`/`LoginAttemptService`はいずれも同じ「(1)行の存在保証→(2)条件付きUPDATEで
  affected rowsを見る」構造を持つ。1クラスだけ`REQUIRES_NEW`を欠くと、そのクラスだけ2文が別々の
  autocommitでコミットされ性能特性が揃わなくなる。新規に同型カウンタサービスを追加・改修する際は、
  既存の同型クラスとtx伝播属性が揃っているか横断的に突き合わせること（Sprint20 performance-reviewer指摘）。
- **既存のcheck-then-act（非原子）ゲートを条件付きUPDATEで原子化する2文イディオム**: (1) no-op ODKUで
  行の存在を保証する（例: `INSERT INTO t_xxx (...) VALUES (?, 0, ...) ON DUPLICATE KEY UPDATE
  col = col`）→ (2) 既存のcheck判定式を**一字も変えずに**`WHERE`句へ移植した条件付き`UPDATE`を発行し、
  `affected rows`で可否を判定する。(1)で行の存在を常に保証するため、`affected rows==0`は「条件不一致
  （枠切れ/ロック中）」以外の意味になり得ず、曖昧さが構造的に排除される。既存のSET句/WHERE句を独立に
  書き直さず移植するのは、`ON DUPLICATE KEY UPDATE`のSET句が左→右評価される既知挙動（Sprint4の教訓・
  上記「技術的なハマりポイント」参照）に暗黙依存している式があり、書き直すと評価順ズレが再発しうるため。

```java
// (1) ensureRow: no-op ODKUで行の存在を保証（seedはDDLのDEFAULTと一致させる）
mapper.ensureRow(key);
// (2) acquireSlot: 既存のcheck式をそのままWHERE句へ移植した条件付きUPDATE
int affected = mapper.acquireSlot(key); // UPDATE ... SET count = count + 1, ... WHERE key = ? AND (...)
if (affected == 0) {
  throw new RateLimitExceededException(key); // 既存の失敗系統へ合流させる
}
```

> **背景（Sprint4 #20 `t_login_attempt`で初出→Sprint16 #13 `t_register_attempt`で2回目発生・2回ルール
> 昇格）**: 登録レート制限の計画フェーズでは当初in-memory案が候補に挙がったが、ユーザーが「in-memoryでは
> なくDB-backedを選択」と明示的に確定した（`backlog/sprint_16/sprint_backlog.md` E1。3-repo化の要因にも
> なった）。2スプリントにまたがり同じ設計判断（DB永続化を選ぶ）が繰り返されたため、以後デフォルトで
> in-memory案を出さずDB-backedを第一候補とする一般ルールとして明文化した。**Sprint20（#41・ログイン/
> 登録レート制限のTOCTOU是正、#39・未認証監査writeのquota）で上記の原子化2文イディオムを確立し、
> `REQUIRES_NEW`統一の教訓とあわせて本節へ追記した**（既存節への追記のため2回ルール対象外）。

### version楽観ロックUPDATEの実装パターン（コードベース初のUPDATE実装・#14）

Sprint4（#20/#21）で用意した足場（`AffectedRows.requireUpdated(rows)` → `OptimisticLockConflictException` →
`GlobalExceptionHandler.handleConflict`（409）・DDLのversion列）は、Sprint12/13/14（Repository層展開・
`OwnershipAuthorizationService`実適用）を経てもUPDATE自体の実利用例がゼロのまま維持されていた。#14
（アカウント編集）が初めてのversion楽観ロックUPDATE実装であり、以下4点を今後の同種UPDATE実装（プロフィール
以外の編集系全般）が踏襲できる型として確立した。

1. **GET側でversionをレスポンスに含め、PUT/PATCHでそのまま往復させる**。クライアントは編集前に取得した
   versionをそのまま送り返すだけでよく、更新対象の識別（pk）とは別に楽観ロックトークンとして扱う。
2. **UPDATE文は`SET ..., version = version + 1 WHERE pk = :id AND version = :readVersion`の1文にまとめ、
   `AffectedRows.requireUpdated(rows)`でaffected==0を`OptimisticLockConflictException`へ変換する**
   （Sprint4で用意した`Supplier<RuntimeException>`オーバーロードは使わず既定の楽観ロック用例外のまま
   でよい＝当初の設計意図どおり無改造で機能した）。
3. **同一集約内の複数テーブルにまたがる更新（例: m_account + m_profile）は、単一のversionトークン
   （集約ルート＝m_accountのversion）でガードし、依存テーブル側のUPDATEはガード対象のUPDATEがaffected>0
   だった場合にのみ発行する**（Repository内で早期return）。依存テーブル側に別途version列を持たせて
   二重にガードする必要はない。
4. **UPDATE成功後、確認のための再SELECTは行わない**。永続化された値は送信したコマンド入力そのものである
   ため、レスポンスは`command`の入力値＋`expectedVersion + 1`から直接組み立てる（Sprint12/13の「識別子
   解決用readと最終応答用readを同じ集約全体読み込みで済ませない」教訓をさらに進め、書込操作の最終応答では
   再読取り自体が不要なケースがあることを示す）。

> **背景（Sprint16 #14）**: 並行安全性（AC-neg3・同一readVersionへの2並行PUT）はSprint11（#8）の2段ラッチ
> テスト手法（`CountDownLatch`×2）を応用し初回でgreen化できた（C1チャレンジ実証）。詳細な設計判断は
> `memory/dev/long_term.md`「習得したこと」（jpetstore-backend）参照。

### 認証隣接の失敗系統は既存の401/403と衝突しない専用ステータスに分離する

ログイン以外の「認証済みユーザーが本人性を再証明する」系のAPI（パスワード変更等）で、再証明の失敗
（例: 現在パスワード誤り）を401や403でそのまま返すと、以下の既存語彙と衝突する。

- **401**: `httpClient`の401検知→silent refresh+retry経路（本人性再証明の失敗を「トークン失効」と誤認し、
  不要なrefreshトライ・誤ったリトライを引き起こす）
- **403**: CSRFトークン欠落時の応答と同じステータスになり、フロント側で原因を判別できない

意味的に近い既存ステータス（401/403）がフロント側の横断的処理にフックされている場合は、衝突を避けるため
**未使用の専用ステータス**を割り当てる。本人性再証明の失敗系統は以下のように分離する。

| 失敗系統 | ステータス | 例外/経路 |
|---|---|---|
| 現在パスワード誤り（本人性再証明の失敗） | **422** | 新設`InvalidCurrentPasswordException`→`GlobalExceptionHandler` |
| 弱いパスワード/不正な入力形式 | 400 | Bean Validation（`MethodArgumentNotValidException`） |
| 真の未認証（トークン失効等） | 401 | 既存のhttpClient silent-refresh経路 |
| CSRFトークン欠落 | 403 | 既存のCSRF保護 |

新しいドメインエラーのHTTPステータスを設計する際は、まずフロント側の横断的処理（401 silent refresh・
403判定等）が対象ステータスにフックされていないかを確認し、衝突する場合はAPI語彙内で未使用のステータス
（422等）を専用に割り当てること。

### パスワード等の共有バリデーション制約はBean Validationカスタム制約に1本化する

同一の検証ロジック（例: パスワード強度＝英大/英小/数字/記号の4種中2種以上・8〜72バイト）を複数のDTO
（新規登録・パスワード変更等）で使う場合は、専用の`@interface`＋`ConstraintValidator`（例:
`@StrongPassword`）として1本化し、各DTOのフィールドへ付与するだけにする。DTOごとに同じ検証ロジックを
重複実装しない。

```java
// presentation/rest/validation/StrongPassword.java
@Constraint(validatedBy = StrongPasswordValidator.class)
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface StrongPassword {
  String message() default "...";
  Class<?>[] groups() default {};
  Class<? extends Payload>[] payload() default {};
}

// 適用側: 複数DTOへ同一制約を付与するだけ
public record RegisterRequest(..., @StrongPassword String password) {}
public record PasswordChangeRequest(@NotBlank String currentPassword, @StrongPassword String newPassword) {}
```

上限バイト長判定（72バイト・bcrypt制約）は上記「PasswordEncoderは...」節参照。

> **背景（Sprint17 #15/#17）**: パスワード変更API（#15）でのAC3インライン検証設計時に確定。既存の
> `RegisterRequest.password`（#17）と新設`PasswordChangeRequest.newPassword`（#15）の両方へ
> `@StrongPassword`を付与し、DTOごとの重複実装を回避した。ステータス分離は計画フェーズのユーザー確認
> （現在PW誤り=422／`httpClient.ts`のsilent refresh誤発火とCSRF 403との衝突回避）で確定した。詳細な
> 設計判断は`memory/dev/long_term.md`「習得したこと」（jpetstore-backend）参照。

### login()実行中は`CurrentUserProvider`が使えない（stateless JWTの制約・userId明示引数のread method）

`CurrentUserProvider`はJWT認証フィルタがSecurityContextへ設定した認証プリンシパルを読む前提の部品のため、
**`/api/auth/login`のリクエスト処理中（認証成功直後・まだレスポンスを返す前）は使えない**（JWTフィルタは
次リクエスト以降でしかSecurityContextを設定しない）。login()実行中にログイン成功ユーザー自身のデータを
読みたい場合は、`CurrentUserProvider`に依存する既存のread method（例: `getMyContact()`）とは別に、
**`Long userId`を明示的に受け取るオーバーロード**（例: `getPreferences(Long userId)`）を用意し、
`login()`が返した`AuthenticatedUser.userId()`をそのまま渡す。

```java
// AccountApplicationService: 通常のread系(currentUserProvider由来)とlogin時用(userId引数)を両方持つ
@Transactional(readOnly = true)
public AccountContact getMyContact() {
  Long userId = currentUserProvider.requireCurrentUser().userId(); // /api/account/me等
  ...
}

@Transactional(readOnly = true)
public UserPreferences getPreferences(Long userId) {  // /api/auth/login・/api/auth/me両方から呼べる
  return accountRepository.findPreferencesByUserId(userId).orElseGet(...);
}
```

**複数エンドポイントが同一の応答DTO（record）を共有している場合、その1箇所を拡張するだけで全エンドポイント
に効く。** `AuthController.LoginResponse`は`/api/auth/login`と`/api/auth/me`が共有するrecordのため、
1回のフィールド追加で両エンドポイントへ同時に反映できる（呼び出し側ごとに個別DTOを作らない）。

> **背景（Sprint19 #36/#25）**: ヘッダーのテーマ/言語設定をDB権威で再水和する機能で、login()直後に
> 自分自身のm_profile値を読む必要があったが、`CurrentUserProvider`はstateless JWTの制約で使えなかった。
> `getPreferences(Long userId)`という明示引数版のread methodを新設し、login()は返却値の`userId()`を、
> me()は`currentUserProvider`由来のuserIdを、それぞれ渡す設計で解決した。詳細は`memory/dev/long_term.md`
> 「習得したこと」（jpetstore-backend）参照。

### セキュリティ統制（fail-closed）と、統制を支える可用性のための緩和策（fail-open）を区別する

新しい緩和策/補助機構（quota・キャッシュ・レート制限等）を、既存のセキュリティ統制（監査記録・認証・認可等）
の**内側**に追加する場合、その緩和策自体が障害を起こしたときにfail-closed（例外伝播）とfail-open（握り潰して
主処理を継続）のどちらに倒すべきかを、**その緩和策が「守っている主目的の統制」より弱い可用性であってよいか**
で判断する。

- **主目的の統制自体（例: 認証・認可・監査記録の実行）は原則fail-closed**（統制が効かない状態で処理を
  継続させない）。
- **その統制を支えるためだけに追加した緩和策（例: 監査write量を抑えるquota）はfail-open**にする。
  fail-closedにすると、緩和策自身の障害（DB接続枯渇等）が新しい経路になって**主目的の統制そのものを
  止めてしまう**本末転倒が起きる。

```java
// NG: quota障害で監査記録という主目的の統制ごと止まってしまう（fail-closed）
public void recordAuthzFailure(...) {
  if (!auditWriteQuotaService.tryAcquire(clientIp)) { // tryAcquire自体が例外を投げるとここで止まる
    return; // 抑止
  }
  mapper.insert(entity); // 到達しない = 監査記録という統制自体が失われる
}

// OK: quotaチェック自体の障害はfail-openにし、監査記録（主目的の統制）は継続させる
private boolean isWithinQuota(String clientIp) {
  try {
    return auditWriteQuotaService.tryAcquire(clientIp);
  } catch (RuntimeException e) {
    log.error("audit write quota check failed; treating as within quota (fail-open)", e);
    return true; // 枠ありとみなし記録処理へ進む
  }
}
```

新しい緩和策/補助機構を設計する際は、まず「これは主目的の統制そのものか、それとも統制を支える補助的な
可用性対策か」を切り分けてから、fail-closed/fail-openの既定を決めること。

> **背景（Sprint20 #39）**: `AuditLogRecorder.recordAuthzFailure`のquotaチェック（`tryAcquire`・
> `@Transactional(REQUIRES_NEW)`で新規コネクション取得）が例外保護の外にあり、quota障害時に監査記録
> （SBD-14）という主目的の統制自体が失われる状態だった（SMのコア精読で発見。#39が修正対象にしている
> N2＝監査抑止と同一の失敗モードがトリガを変えて再現していた）。`isWithinQuota`ヘルパーへ切り出し
> fail-openで是正した。詳細は`memory/dev/long_term.md`「繰り返し指摘されるパターン」（jpetstore-backend）
> 参照。

### `ApplicationContextRunner`でコンテキスト起動失敗を実ブート経路と分離して固定する

`@Value`のfail-fast検証（例: `JwtProperties`のdenylist/エントロピー判定）のように、**特定のプロパティ値で
アプリケーションコンテキストの起動自体が失敗すること**を固定したい否定ACは、既存の実ブート経路のSpec
（`ApplicationBootFailFastSpec`等・Testcontainers込みの実DB起動）へケースを足すのではなく、`Spring
ApplicationContextRunner`で分離した専用Specに書く。

```groovy
new ApplicationContextRunner()
    .withUserConfiguration(JwtProperties)
    .withBean(ConversionService, ApplicationConversionService.&getSharedInstance) // 下記の罠を参照
    .withPropertyValues("jwt.secret=" + weakSecret)
    .run { context ->
        assert context.startupFailure != null
    }
```

- **利点**: Bean生成時例外ではなく**コンテキスト起動失敗そのもの**をassertできる／DB不要で高速／実ブート
  経路（Flyway・DataSource初期化順）に依存しないため、実ブートSpecへ足すより既存specへの副作用が無くflaky
  にならない。
- **罠**: `Duration`型など変換を要する`@Value`プロパティを使う場合、素の`ApplicationContextRunner`には
  変換器が無いため、意図した検証ロジックとは無関係な型変換失敗で常に起動失敗となり**偽陽性GREEN**になる
  （否定ACが「本当に検証ロジックで落ちているか」を確認せず通ってしまう）。`conversionService`
  （`ApplicationConversionService.getSharedInstance()`）を明示登録して解消する。
- 実ブート経路での確認自体が必要な場合（DoD等）は、別途1回の実機起動確認で担保し、否定ACの主固定は
  `ApplicationContextRunner`側に寄せる。

> **背景（Sprint20 #38）**: `JwtSecretContextFailFastSpec`実装時、素の`ApplicationContextRunner`だと
> `Duration`型`@Value`の変換が常に失敗しAC-neg1/AC-neg2が別理由の起動失敗で偽陽性GREENになる罠があり、
> `conversionService` bean明示登録で解消した。詳細は`memory/dev/long_term.md`「習得したこと」
> （jpetstore-backend）参照。

### L2パリティ検証ハーネス（`parity`パッケージ）のtest scope実装パターン（Sprint21 #48/#49・Sprint22 #51）

コードベース初の「プロダクトコード（`src/main`）を一切変更しないtest scope専用スプリント」（旧新パリティ
検証基盤）で確立した、test-only実装パターン。今後のR系/W系シナリオ追加・同種の特性化テスト
（characterization test）新設で再利用できる。

#### Groovyの`.each{}`クロージャ内`return`はループを抜けない（`continue`相当）

Groovyのクロージャ内`return`は、そのクロージャ呼び出し（＝1反復分）だけを終了させ、`.each{}`自体のループは
最後まで回り続ける（Javaの`for`ループの`return`とは意味が異なる）。

```groovy
// NG: 早期終了のつもりが実際には最後まで回り続ける（.each{}内returnは"continue"相当）
(1..maxAttempts).each { attempt ->
    if (tokenPresent()) { return token }  // 抜けない。ループは10回とも実行される
}

// OK: ループ自体を抜けたい場合は素のforループ + return（メソッドを抜ける）
for (attempt in 1..maxAttempts) {
    if (tokenPresent()) { return token }  // メソッド自体を抜けるので意図通り
}
```

**`.each{}`内`return`が「意図どおりcontinue相当」として正しく使われている既存コード（例: 不正なCookieヘッダ
1件をスキップする`captureCookies`）を、この罠と混同して機械的に`for`へ統一してはならない。** 同じ`return`でも
「早期終了のつもりが抜けていない実バグ」と「continueとして正しい実装」は意味論が逆であり、統一的な書き換えは
むしろ新しいバグ（例: 不正ヘッダ1件でCookie取り込み処理が全停止する）を招く。ループを抜ける意図の`return`か、
次の要素へ進む意図の`return`かをコメントで明示すること。

> **背景（Sprint21 #48）**: `NewHttpClient.ensureCsrfToken()`の`(1..N).each { ... return token }`が実際には
> 最後まで回り続ける実バグとして`OrderParitySpec`実行時に`IllegalStateException`で顕在化した。素の`for`
> ループへ書き換えて解消。convention reviewerが「`captureCookies`の`return`も同様に`for`へ統一すべき」と
> 提案したが、SM verificationで「意味論が逆（continueとして正しい実装）であり機械的統一は新バグを招く」として
> 却下された。

#### 既存の共有test基底（MOCK環境）を無変更のまま、実HTTP（RANDOM_PORT）が必要なspecだけ切り替える

`@SpringBootTest`の`webEnvironment`はサブクラス側で再宣言すると上書きできる。既存の共有基底
（`IntegrationTestBase`。`webEnvironment`未指定＝MOCK・Testcontainers MySQL 8.4＋Flyway共有）を変更せず、
実HTTPが必要な一部のspecだけに`@SpringBootTest(webEnvironment = RANDOM_PORT)`を再宣言したサブクラス基底
（`ParityIntegrationTestBase extends IntegrationTestBase`）を新設するだけで、Testcontainers/Flyway等の共有
設定を継承しつつ実サーバ（Tomcat）を実ポートで起動できる。独立した基底クラス＋別コンテナを新設するより
変更範囲が小さい。

```java
// 既存の共有基底（無変更）
@SpringBootTest // webEnvironment未指定=MOCK
abstract class IntegrationTestBase { /* Testcontainers MySQL + Flyway */ }

// 実HTTPが必要なspec専用のサブクラス基底（新設）
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT) // 再宣言で上書き
abstract class ParityIntegrationTestBase extends IntegrationTestBase { ... }
```

実サーバ起動の確認は、テスト実行ログの`Tomcat started on port <port> (http)`（MOCK環境では出力されない）で
裏取りできる。

> **背景（Sprint21 #48・コードベース初のRANDOM_PORT利用）**: `ParityIntegrationTestBaseSmokeSpec`でこの構成が
> 機能することをスモーク確認した（SM申し送り①）。想定していたフォールバック（独立基底＋同一Singleton
> コンテナ）は不要だった。

#### Secure Cookie環境（`jwt.cookie.secure=true`）でのRANDOM_PORT e2eテストは独自Cookie jarで対応する

`jwt.cookie.secure=true`（本番相当設定）のまま`@SpringBootTest(webEnvironment = RANDOM_PORT)`で平文HTTP
（`http://localhost:<port>`）へ接続する場合、JDK標準の`java.net.CookieManager`はSecure属性付きCookieを平文
HTTPへ送信しないため、サーバーが発行したCookie（JWT access/refresh・XSRF-TOKEN）が一切クライアント側に
保持されない。

- **`application.yml`の`jwt.cookie.secure`を上書きするプロパティハックは避ける**（本番相当設定でのe2e検証
  という目的自体が損なわれる）。
- 代わりに、Set-Cookieヘッダを自前でパースしCookie値を保持・後続リクエストへ手動で`Cookie`ヘッダとして付与
  する薄い自作Cookie jarを実装する（`NewHttpClient`）。
- 空値または`Max-Age=0`の`Set-Cookie`は「削除」として扱い、保持中のトークンをクリアする（下記CSRF
  ローテーション対応と合わせて必要）。

> **背景（Sprint21 #48・計画フェーズで新発見）**: `application.yml:51`の`jwt.cookie.secure: true`が原因で、
> `ParityIntegrationTestBase`のRANDOM_PORT環境で`CookieManager`がCookieを一切保持しないことが判明した。

#### CSRFトークンの交互ローテーション（あれば削除・無ければ発行）への対処

Spring SecurityのCSRF Cookie（`XSRF-TOKEN`）はGETリクエストのたびに「トークンCookieが存在すれば削除・
無ければ発行」という交互ローテーションで動く（連続GETで有無がトグルする）。e2eクライアント側で「トークンが
取れるまで`GET`を繰り返す」リトライヘルパを用意し、上限到達時は試行履歴つきで明示的にfailさせる
（`XSRF-TOKEN Cookieが10回のGET /api/pingでも取得できなかった: attempt 1: present, attempt 2: absent, ...`
のような診断出力にする）。非GETリクエストの直前に必ずこのヘルパを呼び、取得したトークンを`X-XSRF-TOKEN`
ヘッダへ載せる。

> **背景（Sprint21 #48）**: `NewHttpClient.ensureCsrfToken()`として実装。spike段階でも4回踏んだ落とし穴。

#### グローバル採番（AUTO_INCREMENT）列への「新規作成件数」はCOUNT差分で測る（MAX(id)差分にしない）

MySQLの`AUTO_INCREMENT`はDELETE後もリセットされないため、同一プロセス内で複数のwriteシナリオを連続実行する
テストハーネスで「シナリオ実行による新規作成件数」を求める場合、`MAX(id)`の前後差分ではなく**`COUNT(*)`の
前後差分**を使う。`MAX(id)`差分は、対象テーブルの行が復元不可（DELETE後もカウンタが戻らない）の環境では
2番目以降のシナリオで実際の作成件数と一致しなくなる。

> **背景（Sprint21 #49）**: `LegacyDbReader#orderCount`/`NewDbReader#orderCount`で採用。新側（MySQL
> `t_order.order_id`）が`DELETE`後もAUTO_INCREMENTをリセットしないため、`order-multi-item`実行時に
> `ordersCreated`が誤って`2`（正しくは`1`）と算出される不一致で発覚した。

#### 設計ドキュメントのフォーマット仕様は実機の生応答で裏取りする（legacy JSPの`fmt:formatNumber`の実例）

design.mdやJSPソースに`<fmt:formatNumber pattern="$#,##0.00">`のような記述があっても、実際のHTTP応答でその
フォーマットが適用されるとは限らない（本プロジェクトのlegacy実機では`$`無し・末尾ゼロ無しの生数値がそのまま
出力された）。HTML抽出の正規表現・パーサをドキュメント記載のフォーマット仕様だけから組み立てず、**必ず
`curl`等で実機の生応答を確認してから実装する**こと。

> **背景（Sprint21 #49）**: `Product.jsp`/`Item.jsp`の`fmt:formatNumber`を前提に`$`付き正規表現で実装した
> ところ、golden採取直後の目視確認でentries/listPriceが空・nullになる欠陥として即座に検出された。
> `<td>数値のみ</td>`という「セル内容が数値のみ」で価格セルを識別する方式へ是正した。

#### 検証資産（golden/フィクスチャ）は前提条件を実機で検査し、満たさなければ書き出さずfailする

golden/フィクスチャのような「実測値を記録して以後の比較基準にする」検証資産は、**「テストが今回たまたま
通ったか」ではなく「前提が将来崩れたときに気づけるか」**を設計原則にする。

- 前処理・後処理のUPDATE（在庫復元等）はaffected rowsを検査し、0行なら即座にfailする（黙って0行のまま処理が
  進み、観測ポイントが静かに失われることを防ぐ）。
- シナリオの前提条件（例: 在庫<注文数）と結果の意味（例: 在庫がマイナス化）を実際にDBへ問い合わせて検証し、
  **満たさなければgoldenを書き出さずfail**する。
- 検証した実測値は、比較対象外の付随情報としてgolden自体（例: `preconditions`フィールド）に残し、人が読んでも
  前提が分かる状態にする。
- fail-pathの動作は、実際に前提を崩す入力（存在しないitemId等）を注入して**「本当にfailすること」を実証**
  する（`captureGolden`実行 → 例外・golden未書き出しを確認 → 元に戻す）。
- **旧側にだけ前提assertを置いて満足しない。新側（比較対象）にも対になる前提assertを必ず用意し、
  「前提が崩れたときに新側だけが素通りしてparityTestがgreenのまま観測点が失われる」経路を潰す。**
  旧新でスナップショットの見え方が同じ（例: 不存在も非所有も同一の403に正規化される）場合、旧側の前提が
  崩れても新側の応答形は変化しないため、旧側assertだけでは片側防御にしかならない。

> **背景（Sprint21 #48/#49、SM verification確定所見）**: W3（在庫不足）シナリオで、前処理UPDATE
> （`restoreInventoryQty`）がaffected rowsを検査しない裸のUPDATEだったため、itemId不一致等でUPDATEが黙って
> 0行になってもgolden自体は変化せず、観測ポイント（ID-1の実証）だけが静かに失われる欠落があった。上記4点で
> 是正し、実際にitemIdを差し替えてfail-pathを実証した。
> **Sprint22 #51（SM verification確定所見・同型2回目）**: `NewScenarioRunner.orderDetailMissing()`
> （R8b＝存在しないorderIdの注文詳細照会）は旧側`LegacyDbReader#orderExists`の前提assertのみを持ち、新側に
> 対になるassertが無かった。`GET /api/orders/{id}`は不存在・非所有のいずれも同一403（ID-4/SBD-8）に正規化
> されるため、前提（orderIdが実在しないこと）が崩れてもスナップショットの見え方は変わらず、parityTestは
> green のまま観測点（ID-14の実証）だけが失われる経路が残っていた。`NewDbReader#orderExists`を新設し
> `orderDetailMissing()`冒頭でassertする形で両側対称化し、999999999を強制的に実在させたシナリオでfail-pathも
> 実証した。上記の対症箇条書きへ反映した。

#### DB間でcamelCaseキーを突合する場合、列ラベルの大文字小文字はDBドライバ依存で信用できない

HSQLDB（legacy）はSQLの列エイリアスをUPPERCASEへ正規化して返す。`ResultSetMetaData.getColumnName()`を
`toLowerCase()`する汎用DB読み出しヘルパーをそのまま使うと、`AS firstName`のようなcamelCaseエイリアスが
`firstname`に潰れ、MySQL（新側）のcamelCaseキーと文字列が一致せず**偽の不一致**でfailする。

- 新規にDB直読みcanonicalフィールドを追加する際は、列ラベルに頼らず**SELECT列順とordinal位置**で
  camelCaseキー名を組み立てる（旧新両側で同じ設計に揃える＝ドライバ非依存の防御的設計）。
- captureGolden実行直後は必ずgolden JSONの中身を目視確認し、意図したキー名で値が入っているか確認する
  （偽の不一致は`captureGolden`自体は正常終了するため気づきにくい）。

> **背景（Sprint22 #51）**: 新設`accountRow`（アカウント系canonical読取）で既存の`queryRow`/`queryRows`
> ヘルパー（`orderRow`等が前提とする列名lowercase方式）を流用したところ、旧側キーが`firstname`等の全小文字に
> 潰れ、新側（camelCaseのまま）と一致せずアカウント系シナリオ全件が偽の不一致でfailする状態になった
> （golden JSON出力後の目視確認で発覚）。両側の`accountRow`をordinal位置での組み立てに是正した。
