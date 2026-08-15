# Sprint 4 バックログ

## スプリントゴール

**E5 認証を「認可土台」と「認証堅牢化」で仕上げ、認証面の攻撃（S9/S10/S11）を塞ぎ、全 Epic の認可の前提を整える。**
Sprint 2（#23＝Spring Security JWT 土台・監査ログ）・Sprint 3（#18 login/logout・#19 bcrypt 照合）の上に、

- **#21 認可土台（F5.4）**: 認可判定を **認証プリンシパル基準**・**サービス/ドメイン層**・**チャネル非依存**で強制する土台を提供し（SBD-1）、**認可失敗を監査ログに記録**（SBD-14）。リクエスト束縛値（form/param）の username を認可に使う経路を構造的に不可能にする（before S3 の再populate 汚染の封殺）。
- **#20 認証堅牢化（F5.3）**: **レート制限/ロックアウト**（SBD-6）を新設し、**既定資格情報プリフィル廃止・GET 認証遮断・一律エラー**（大半は #18/#19 で既達）を維持、**オープンリダイレクト対策**（SBD-9）を構造的に担保する（before S10/S11/S9 の解消）。

これで認証プリンシパルが「実在＋堅牢＋認可の土台」として揃い、後続の各ドメイン認可（E3 注文・E4 編集/履歴）が安全に積める。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | 実装順 |
|-------|---------|-------|----|-----------|-------|
| [#21](https://github.com/ryokkon624/jpetstore-manage/issues/21) | [E5] 認証プリンシパル基準の認可土台を全ドメインへ提供する | `security` / `E5` | 5 | `jpetstore-backend` | ① |
| [#20](https://github.com/ryokkon624/jpetstore-manage/issues/20) | [E5] 認証を堅牢化する（レート制限/ロックアウト・既定資格情報廃止・GET認証廃止・リダイレクト検証） | `security` / `E5` | 5 | `jpetstore-backend`（＋ロックアウト保持先次第で `jpetstore-database`） | ② |

**合計 10 SP**。両 Issue とも Project #2 で **Sprint=4 / Ready / Story Points=5**。

> **実装順**: #21（認可土台）→ #20（認証堅牢化）。両者は触る領域が異なり（#21＝認可レイヤ／#20＝ログイン試行の前段フィルタ）ほぼ独立だが、#21 は「全 Epic の認可の前提（備考）」＝土台性が高いため先に確定させる。DEV は計画フェーズで境界を明示すること。
> **ブランチ**: **1ブランチにコミット単位で積む**（Sprint 55 方針）。`jpetstore-backend` に**新規ブランチ**を切る。ブランチ名は SM 提案 **`feature/21-authz-foundation`**（#21/#20 を包含）。DEV は計画フェーズで確定・明示すること。※ #20 のロックアウトを DB 保持で実装する場合は `jpetstore-database` にも同名ブランチ＋コミットが要る（cross-repo・Sprint 3 実績の運用）。
> **bug ラベルなし**（#21/#20 とも `security`）＝計画フェーズでの Issue Body 更新（根本原因調査）は不要。
> **参考**: この migration-agent-base 側の Planning/Review 成果物は `feature/sprint4` ブランチにコミットし、Retro 完了時に PR＆マージする（ユーザー指示・2026-08-15）。実装コードの PR は `jpetstore-backend`（＋必要なら `jpetstore-database`）側で別途作成する。

---

## Issue #21 本文（転記）

### ユーザーストーリー

**As a** 全ドメイン（注文/編集/履歴）
**I want to** 認証プリンシパル基準の認可土台を使いたい
**So that** identity の完全性を前提に各ドメインの認可が成立する

### トレース

- **Epic**: E5 認証（Auth / Signon）
- **Feature**: F5.4 保護ゲート＋認可土台
- **挙動spec**: spec/behavior/auth.md §1, §5, §6
- **横断NFR**: spec/security-baseline.md（SBD-1, SBD-14）

### Acceptance Criteria

- [x] **AC1 (SBD-1)**: 認可判定は **認証プリンシパル** から行い、リクエスト束縛値（form/param）を認可に使わない基盤を提供。サービス/ドメイン層で強制（チャネル非依存）。
- [x] **AC2 (SBD-14)**: 認可失敗を監査ログに記録。
- [x] **AC-neg1 (否定AC / SBD-1)**: 認可にフォーム束縛の username を使う経路が存在しない（before S3 の再populate 汚染が構造的に不可能）。

### 備考

- 優先順位の根拠: E3/E4 の認可はこの土台に依存＝全 Epic の前提。
- 依存関係: #23（E6.2）。

---

## Issue #20 本文（転記）

### ユーザーストーリー

**As a** サイト運営者
**I want to** 総当り・弱い既定資格情報・GET認証・オープンリダイレクトを塞ぎたい
**So that** 認証面の攻撃（S9/S10/S11）を防ぐ

### トレース

- **Epic**: E5 認証（Auth / Signon）
- **Feature**: F5.3 認証堅牢化
- **挙動spec**: spec/behavior/auth.md §2, §3, §5（S9, S10, S11）
- **横断NFR**: spec/security-baseline.md（SBD-6, SBD-9）

### Acceptance Criteria

- [x] **AC1 (SBD-6)**: レート制限/ロックアウトを設ける。既定資格情報のプリフィルを廃止。資格情報は POST body のみで受理（GET/URL で受理しない）。
- [x] **AC2 (SBD-9)**: リダイレクト先は **allowlist/相対のみ**。生パラメータを sendRedirect しない。
- [x] **AC3 (SBD-6)**: 認証エラーは一律メッセージ（ユーザ列挙不可）＝before clean の維持。
- [x] **AC-neg1 (否定AC / SBD-6)**: `?username=..&password=..` の GET 認証が成立しない。総当りがレート制限で抑止される。
- [x] **AC-neg2 (否定AC / SBD-9)**: `forwardAction=//evil` 等で外部サイトへ遷移しない。

### 備考

- 依存関係: #18（F5.1）。before S9/S10/S11 の解消。

---

## 実装の前提コンテキスト（SM調査メモ）

DEV は計画フェーズで以下を精査すること（SM が `jpetstore-backend` を実地調査した結果）。**両 Story とも「既に達成済み」の割合が大きく、実質の新規作業が絞られる**のがポイント。

### #21（認可土台）の現状 — 土台の大半は Sprint 2/3 で完成済み

| 資産（実在） | 状態 | #21 での扱い |
|---|---|---|
| `domain/security/AuthenticatedUser`（record: `userId/username/roles`） | **実装済み**（チャネル非依存のプリンシパル型） | SBD-1 の identity 型。再利用 |
| `domain/security/CurrentUserProvider`（`currentUser()`/`requireCurrentUser()`） | **実装済み**。Javadoc に「サービス/ドメイン層は request param でなく本 IF で認証プリンシパルを取得せよ」と **SBD-1 の設計意図を明記済** | 認可判定の唯一の identity 供給口。ドメイン認可はこれを DI して書く |
| `infrastructure/security/SecurityContextCurrentUserProvider` | **実装済み**（`SecurityContextHolder` から取得・anonymous を空に落とす） | 再利用 |
| `config/SecurityConfig`：`@EnableMethodSecurity`・URL 認可（既定 `anyRequest().authenticated()`）・CSRF・stateless・例外ハンドラ結線 | **実装済み** | メソッドセキュリティ基盤は有効。ドメインガードを積むだけ |
| `infrastructure/audit/AuditLogRecorder#recordAuthzFailure`＋`AuditingAccessDeniedHandler`(403)＋`AuditingAuthenticationEntryPoint`(401)＋`GlobalExceptionHandler`(@PreAuthorize 由来) | **実装済み・3経路結線・テスト済**（`SecurityEndToEndSpec` が 401/403 で `t_audit_log` 1行を検証） | **AC2(SBD-14) の認可失敗記録は実質達成済**。#21 では確認＋（必要なら）ドメイン認可失敗も同経路に乗ることを実証 |
| `infrastructure/audit/AuditLogRecorder#recordStateChange` | **API のみ・実呼び出しゼロ**（対象ドメインユースケース未実装のため） | 状態変更の記録は各ドメイン Story で結線。#21 スコープ外の可能性大 |

**未実装＝#21 の主対象**:
- **サービス/ドメイン層の「認可ガード／所有者（本人スコープ）チェック」のパターンが未確立**（`@PreAuthorize` はテスト用 `SecuredPingController` の1箇所のみ、適用先の order/account ドメインサービス自体がまだ無い）。
- **ロールモデルが未整備**：`JdbcUserDetailsService` が全ユーザに `["USER"]` 固定付与（role/authority 表が無い）。**ADMIN を取得する経路が無い**＝ロールベース認可は実質 USER 単一。

**→ #21 は #23 と同じ「土台 Story」の構図**：適用先ドメインが未実装のため、#21 では「**認可土台の仕組み（本人スコープ判定の再利用可能な部品／`CurrentUserProvider` 起点の認可パターン）＋実証（`SecuredPingController` 相当）**」までを提供し、**各ドメインへの実適用は各ドメイン Story（#8/#9/#10/#14 等）へ委譲**する線引きが素直。AC-neg1「form 束縛 username を認可に使う経路が無い」は **stateless REST＋`CurrentUserProvider` 起点で構造的にほぼ達成**（form 束縛値を認可に使う sink が現状存在しない）。

### #20（認証堅牢化）の現状 — 実質メインは「レート制限/ロックアウト」のゼロ実装

| SBD 要件 | 現状 | #20 での扱い |
|---|---|---|
| SBD-6 資格情報は **POST body のみ**（GET/URL 不可） | **達成済**。`AuthController#login` は `@Valid @RequestBody LoginRequest` のみ。`GET /api/auth/login,logout` は 405（`AuthLoginLogoutSpec` で検証済） | 維持を確認。AC-neg1 の GET 認証不成立は既達 |
| SBD-6 認証エラー **一律メッセージ**（列挙不可） | **達成済**。未知 username・誤 PW とも `BadCredentialsException`→ 一律 401（`hideUserNotFoundExceptions=true`／`AuthLoginLogoutSpec` が timestamp 以外完全一致を検証） | AC3 は既達。維持を確認 |
| SBD-6 **弱既定資格情報の排除** | **達成済（backend/シード）**。`R__test_user.sql` は `j2ee/j2ee` 等を含まず（`DemoUserFixtureSpec` が非存在を検証）。`demo_user` は実 bcrypt | backend シードは OK。「**プリフィル廃止**」の実体はログイン画面の初期値＝**フロント責務**（下記スコープ境界②） |
| SBD-6 **レート制限/ロックアウト** | **完全未実装**。bucket4j/resilience4j 等の依存なし・試行回数カウンタなし・`isAccountNonLocked()` は `true` 固定・保持テーブル/カラムなし | **#20 の主作業＝ゼロから新規実装**（下記スコープ境界①） |
| SBD-9 **オープンリダイレクト対策** | **構造的に sink 無し**。`@RestController` のみで `sendRedirect`/`RedirectView`/`forwardAction` 相当なし（grep no match）。302 は springdoc の swagger 内部固定のみ | backend の違反箇所ゼロ。AC2/AC-neg2 は「**予防的 allowlist ガードを足すか**／**構造的解消で足る（sink 無しを明文化・テストで固定）**」を計画フェーズで決める（下記スコープ境界③） |

### spec の要点（auth.md §1/§2/§3/§5/§6・security-baseline SBD-1/6/9/14）

- **auth.md §1**: 保護ゲートは認証済み identity（旧 session `accountForm`）が注文・編集・履歴の認可の土台＝**本ドメインの完全性が全 Epic の前提**。after は Spring Security 標準プリンシパル（＝`AuthenticatedUser`）へ移行済。
- **auth.md §5（S9/S10/S11）**: S9 オープンリダイレクト→allowlist/相対のみ（SBD-9）、S10 ブルートフォース＋弱既定資格情報→レート制限/ロックアウト・プリフィル廃止（SBD-6）、S11 GET でも資格情報受理→POST body のみ（SBD-6）。
- **SBD-1**: 認可判定は認証プリンシパルから・**form/param 束縛値を認可に使わない**・チャネル非依存でサービス/ドメイン層強制。回帰の種＝`?account.username=他人`/無認証 API → 自分の資源のみ・他人は 403。
- **SBD-14**: 認可失敗＋状態変更を監査ログに記録（誰が/何を/結果）。回帰の種＝認可拒否・注文作成が記録される。

### ✅ 計画フェーズで確定すべき論点（DEV が整理→ユーザー承認）

以下は SM 事前調査で洗い出したが**未確定**。DEV が計画フェーズで方針を提示しユーザー承認を得ること。

---

## ⚠️ スコープ境界（DEV が計画フェーズで線引きしユーザー承認を得ること）

1. **#20 レート制限/ロックアウトの実装方式（最大の新規作業）**。
   - **ライブラリ（bucket4j 等）vs 自前カウンタ**、**保持先**（in-memory/Caffeine ＝単一ノード前提 vs DB テーブル ＝ stateless/水平スケール整合・cross-repo に `jpetstore-database` 変更 vs Redis ＝依存増）、**キー**（username 単位 / client_ip 単位 / 併用）、**閾値・ロック期間・解除条件**、**列挙対策との両立**（ロック有無で応答を弁別させない＝一律 401/429 の方針）を具体化。`isAccountNonLocked()` の扱い（DB ロック状態と連動させるか、フィルタ前段で 429 を返すか）も決める。**DB 保持を選ぶ場合は `jpetstore-database` に試行回数/ロック列 or テーブルを Flyway で追加（cross-repo・Sprint 3 の運用）**。
2. **#20 既定資格情報「プリフィル廃止」のフロント責務分の持ち越し**。backend シード/設定は達成済。ログイン画面の初期値プリフィル廃止は **フロント責務**（`jpetstore-frontend` 未整備）。Sprint 3 の #18→#24 と同様、**今スプリントで扱わない分は持ち越し先 Issue（#24 E6 フロント土台・Sprint 5 予定）に AC 化**するかを提案（該当すれば SM が Body PATCH）。
3. **#20 オープンリダイレクト対策（SBD-9）の実現方式**。backend は sink 無し（構造的に安全）。**「予防的 allowlist/相対のみガードを足す」か「sink 不在を明文化＋回帰テストで固定して構造的解消とする」か**を選ぶ。フロントのログイン後遷移（元URL復帰）に allowlist/相対制約が要る分は #24 側 AC（Sprint 3 で AC8 として既に持ち越し済＝重複回避を確認）。
4. **#21 認可土台のスコープ**。適用先ドメインサービス（order/account）が未実装。**「土台の仕組み＋実証（`SecuredPingController` 相当／本人スコープ判定の再利用部品＋`CurrentUserProvider` 起点の認可パターン確立）」に絞り、各ドメインへの実適用は各ドメイン Story へ委譲**する線引きでよいか（#23 と同じ「土台 vs 機能実装」の判断）。**ロールモデル（ADMIN 取得経路）を #21 で整備するか**（現状 USER 単一固定・role 表なし）＝ #21 の AC が role ベース認可を要求していないため、**「本人スコープ（所有者一致）」に主眼を置き role 表整備は必要になった Story まで遅延**する案を提示・承認を得る。
5. **#21 AC2（SBD-14 認可失敗の監査記録）の達成判定**。既に 401/403 の 3 経路で記録・テスト済。**「既存機構で達成済＝確認と、ドメイン認可失敗も同一経路に乗ることの実証」で足るか**を確認（過剰実装＝スコープ逸脱を防ぐ）。

> **設計原則の再確認（過大評価しない）**: security-baseline の注記どおり **SBD-14 は before の直接 finding ではなくモダン化で足す追加**。#21/#20 とも「土台の大半は既達」なので、**AC を満たす最小限＋実証（否定AC のテスト化）に絞り、ドメイン機能の先取り実装をしない**（Sprint 2 #23 のスコープ規律を踏襲）。

---

## リスク・チャレンジ

| # | 種別 | 内容 | 対応方針 |
|---|------|------|---------|
| R1 | リスク | **「土台 Story」の過剰実装リスク**（#21）。適用先ドメインが未実装なのに認可を全ドメインへ広げようとすると、order/account ドメインを先取り実装＝スコープ逸脱に陥る | #23 の規律を踏襲。#21 は「認可土台の仕組み＋実証」に絞り、各ドメイン適用は各 Story へ委譲。計画フェーズで境界をユーザー承認（スコープ境界④） |
| R2 | リスク | **レート制限の保持先とステートレス整合**（#20）。in-memory は水平スケールで破綻、DB は cross-repo 変更、Redis は依存増。キー/閾値/解除条件/列挙対策の設計論点が多い | 計画フェーズで方式決定＋ユーザー承認（スコープ境界①）。stateless 前提と整合する保持先を選ぶ。DB 採用なら `jpetstore-database` に Flyway 追加（cross-repo 運用） |
| R3 | リスク | **「既達」の見落としによる二重実装**（#20）。POST body 限定・一律エラー・GET 遮断・弱資格排除・リダイレクト sink 無しは #18/#19 で既達。再実装は無駄＋レビュー混乱 | SM 調査メモの「既達」表を DEV に共有。#20 の新規作業はレート制限/ロックアウトに集約。既達分は「維持を回帰テストで固定」する扱い |
| R4 | リスク | **ロックアウトと列挙対策の衝突**（#20）。アカウントロック状態を応答で弁別させると、逆にユーザ存在推測の手がかりになる | ロック時も一律応答（例 429 or 401 を username 非依存に）。ロック有無で応答を区別しない方針を計画で確定・否定AC 化 |
| R5 | リスク | **フロント責務分の取りこぼし**（#20 プリフィル廃止／SBD-9 元URL復帰）。backend で完結せずフロントに残る分が宙に浮く | Sprint 3 の #18→#24 と同じく「持ち越し＝AC化」。#24 に既存 AC8（元URL復帰 allowlist/相対）があるため重複回避を確認しつつ、プリフィル廃止分の AC 要否を判定（スコープ境界②③） |
| R6 | 好材料（非リスク） | **土台の大半が Sprint 2/3 で完成済**：認証プリンシパル・`CurrentUserProvider`（SBD-1 設計意図を Javadoc 明記）・`@EnableMethodSecurity`・監査ログ 3経路（SBD-14 の認可失敗記録はテスト済） | 新規実装を最小化できる。#21 は「土台の確立＋実証」、#20 は「レート制限のみ」に集中。既存資産を壊さず再利用（`recordStateChange` の API も温存） |
| C1 | チャレンジ | 計画フェーズを **Opus 4.8（1M context）** で実施し、#21/#20＋auth.md §1/2/3/5/6＋security-baseline SBD-1/6/9/14＋現行 backend 認証/認可/監査コードを一括読解して、スコープ境界（土台 vs ドメイン適用・レート制限方式・リダイレクト実現・フロント持ち越し）を先に確定 → 実装 Sonnet で手戻りなく完走（Sprint 1/2/3 で実証済の tier 分離踏襲） | 計画フェーズを Opus で起動 |
| C2 | チャレンジ | **security ラベル Story ×2＝ Sec reviewer への検証観点を先回り明記**。SBD-1（form 束縛 username を認可に使う経路の不在・チャネル非依存）／SBD-14（認可失敗の監査記録）／SBD-6（レート制限の実効・列挙不可・GET 不可・弱資格排除）／SBD-9（リダイレクト外部遷移不可）を否定AC＝「攻撃が失敗すること」で検証依頼（Sprint 2/3 で Sec reviewer が確定した実績） | レビュー段で Sec 観点を具体指定 |

---

## Definition of Done

- **#21**: 認可判定が **認証プリンシパル（`CurrentUserProvider` 起点）** から行われ、form/param 束縛値を認可に使う経路が存在しない土台を提供（AC1/AC-neg1）。認可失敗が監査ログ（`t_audit_log`）に記録される（AC2/SBD-14）。土台の再利用可能性を実証（`SecuredPingController` 相当 or 本人スコープ判定部品＋テスト）。各ドメインへの実適用は各ドメイン Story へ委譲（スコープ明示）。
- **#20**: **レート制限/ロックアウト**が機能し総当りが抑止される（AC1/AC-neg1）。GET 認証不成立・資格情報 POST body 限定・認証エラー一律（AC1/AC3・既達を維持）。**オープンリダイレクトで外部遷移しない**（AC2/AC-neg2・構造的解消 or allowlist ガード）。既定資格情報プリフィル廃止は backend 完結分を満たし、フロント責務分は持ち越し先へ AC 化。
- テストは Groovy＋Spock。否定AC（form 束縛 username での認可不可・認可失敗の監査記録・GET 認証不成立・総当り抑止・ロック時の列挙不可・外部リダイレクト不可）を自動テスト化（UT＝Spock 単体／IT＝Testcontainers）。
- 実機起動＋主要エンドポイント疎通（login→保護resource の 401/403＋監査記録→レート制限の 429 等）＋IDE 警告ゼロ（Sprint 2 DoD）。
- 3観点レビュー（規約・セキュリティ・パフォーマンス）で指摘なし。
- PR 作成済み（`closes ryokkon624/jpetstore-manage#21` / `closes ryokkon624/jpetstore-manage#20`／cross-repo の場合は各リポジトリ PR に closes 記載）。
- Sprint Review 用 HTML 生成済み。
