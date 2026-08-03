---
name: backend-conventions
description: HwHubバックエンド（hw-hub-backend）およびバッチ（hw-hub-batch）の設計規約・実装方針。Javaファイル・Groovyファイル・MyBatisマッパー・Flywayマイグレーションファイルを新規作成・編集するときは必ずこのスキルを参照すること。DDDライク3層構造・ドメインモデル・セキュリティ・テスト方針など、実装の判断に必要な規約をすべてここに集約している。
---

# Backend Conventions

hw-hub-backend・hw-hub-batchの設計規約・実装方針。

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
