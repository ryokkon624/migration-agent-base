# Sprint 3 バックログ

## スプリントゴール

**E5 認証（サインオン/サインオフ）を end-to-end で実働させる。**
Sprint 2 の認証土台（#23＝JWT httpOnly Cookie＋**refresh のみ**）の上に、
**パスワードのハッシュ＋ソルト保存・照合（#19 / S7 是正）** と
**初回ログイン/ログアウト（#18 / credential 交換 → access/refresh 発行・`UserDetailsService` の DB 結線・Spring Security 標準）** を積み上げ、
**セッション固定化防止（SBD-4）・CSRF（SBD-3）・オープンリダイレクト対策付き元URL復帰（SBD-9）・弱い既定資格情報の排除（SBD-6）** を満たす。
これで認証プリンシパルが実在化し、後続の認可土台（#21 F5.4）・各ドメイン認可の前提が揃う。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | 実装順 |
|-------|---------|-------|----|-----------|-------|
| [#19](https://github.com/ryokkon624/jpetstore-manage/issues/19) | [E5] パスワードをハッシュ＋ソルトで保存・照合する | `security` / `E5` | 3 | `jpetstore-backend`（＋必要なら `jpetstore-database`） | ① |
| [#18](https://github.com/ryokkon624/jpetstore-manage/issues/18) | [E5] サインオン/サインオフ（セッション再生成・元URL復帰）を提供する | `feature` / `E5` | 5 | `jpetstore-backend`（＋フロントは計画で線引き） | ② |

**合計 8 SP**。

> **実装順**: #19（PasswordEncoder＋照合基盤＋デモシード）→ #18（login/logout＋`UserDetailsService`）。#18 の credential 照合は #19 の成果を使うため #19 が先。
> **ブランチ**: **1ブランチにコミット単位で積む**（Sprint 55 方針）。`jpetstore-backend` に**新規ブランチ**を切る（Sprint 2 の `feature/23-backend-arch-foundation` は main へマージ済）。ブランチ名は SM 提案 `feature/18-signon-auth`（#18/#19 を包含）。DEV は計画フェーズで確定・明示すること。
> **bug ラベルなし**（#19=security, #18=feature）＝計画フェーズでの Issue Body 更新（根本原因調査）は不要。

---

## Issue #19 本文（転記）

### ユーザーストーリー

**As a** サイト運営者
**I want to** パスワードをハッシュ＋ソルトで保存・照合したい
**So that** DB 漏えい時も平文パスワードが漏れない（S7 是正）

### トレース

- **Epic**: E5 認証（Auth / Signon）
- **Feature**: F5.2 パスワードのハッシュ化
- **挙動spec**: spec/behavior/auth.md §3, §5（S7）
- **横断NFR**: spec/security-baseline.md（SBD-5）

### Acceptance Criteria

- [ ] **AC1 (SBD-5)**: パスワードは bcrypt/argon2 等でハッシュ＋ソルト保存・比較（平文保存/平文比較しない）。
- [ ] **AC2**: 既定弱資格情報（j2ee/j2ee 等）をシードに残さない。
- [ ] **AC-neg1 (否定AC / SBD-5)**: DB 内に平文パスワードが存在しない。既定弱資格情報でログインできない。

### 備考

- 優先順位の根拠: 全登録/ログイン/PW変更の前提。
- 依存関係: #22（E6.1・`signon.password` をハッシュ長 varchar(255) へ拡張・**完了済み**）。

---

## Issue #18 本文（転記）

### ユーザーストーリー

**As a** 登録ユーザー
**I want to** ログイン/ログアウトし、保護ページ要求時は元の場所へ復帰したい
**So that** 安全に認証状態を扱える

### トレース

- **Epic**: E5 認証（Auth / Signon）
- **Feature**: F5.1 サインオン/サインオフ
- **挙動spec**: spec/behavior/auth.md §2, §6
- **横断NFR**: spec/security-baseline.md（SBD-4, SBD-3, SBD-9, SBD-15）

### Acceptance Criteria

- [ ] **AC1**: サインオン/サインオフを Spring Security 標準＋REST で提供（手組み session accountForm 廃止・JSP廃止）。認証＝ **JWT を httpOnly Cookie＋refresh**（localStorage 不使用・決定済）。
- [ ] **AC2 (SBD-4)**: ログイン成功時に **セッション/認証状態を再生成**（固定化防止）、サインオフで無効化。
- [ ] **AC3**: 保護ページ要求→ログイン→ **元URLへ復帰**（維持）。
- [ ] **AC4 (SBD-3)**: ログイン/ログアウトは CSRF 前提・非冪等POST（Cookie 方式ゆえ必須）。
- [ ] **AC-neg1 (否定AC / SBD-4)**: ログイン前後で session/認証識別子が変わる（固定化不可）。
- [ ] **AC-neg2 (否定AC / SBD-3)**: 外部オリジンからのログイン/ログアウト（状態変更）が拒否される。GET での認証・状態変更リンクが存在しない。

### 備考

- 決定（2026-08-10）: JWT httpOnly Cookie＋refresh・元URL復帰維持。
- 依存関係: #23（E6.2 Spring Security基盤・**完了済み**）／#19（F5.2 ハッシュ・**本スプリント①**）。

---

## 実装の前提コンテキスト（SM調査メモ）

DEV は計画フェーズで以下を精査すること。

### 既存の状態（Sprint 2 `#23` 完了後の `jpetstore-backend` main）

認証土台は **refresh のみ**実装済み。**login/logout の入口はこのスプリントで新設**する。

| 既存資産 | 内容 | 本スプリントでの扱い |
|---|---|---|
| `infrastructure/security/JwtService` / `JwtProperties` / `AuthCookieSupport` / `JwtAuthenticationFilter` | JWT 生成・検証（access/refresh の `typ` 区別済）・httpOnly Cookie 読み書き・認証フィルタ | **既存を尊重して再利用**。login で access/refresh を初回発行する導線を追加 |
| `config/SecurityConfig` | CSRF・stateless・JWT フィルタ結線（#23 で再設計済） | login/logout パスの認可・CSRF 適用を追加 |
| `presentation/rest/AuthController` | **`POST /api/auth/refresh` のみ**。コメントに「login API は **#21 の範囲**」と誤記（実際は **#18**） | **`POST /api/auth/login`・`POST /api/auth/logout` を追加**。stale コメントを #18 に是正 |
| `application/service/AuthApplicationService` | `refreshAccessToken` のみ。同じく「初回発行・UserDetailsService 結線は #21」と誤記 | login/logout ユースケースを追加。stale コメント是正 |
| `domain/security/AuthenticatedUser` / `SecurityContextCurrentUserProvider` | 認証プリンシパル型・取得口 | login で発行するプリンシパルの供給元に |
| `presentation/rest/security/AuditingAuthenticationEntryPoint` | 認証失敗の監査 EntryPoint | login 失敗・保護resource 401 の監査に活用 |

### DB スキーマの状態（Sprint 1 `#22` 完了・**#19 の DB 準備は概ね完了済み**）

`jpetstore-database/flyway/sql/V00_000_004__create_account_tables.sql`：

- **`m_signon.password_hash VARCHAR(255) NOT NULL`**（旧 `password varchar(25)` 平文 → ハッシュ格納長を確保済／SBD-5）。
- **bannerdata 廃止**（auth.md §4 の「認証クエリが bannerdata と INNER JOIN → 該当行が無いとログイン失敗」という**罠は新スキーマで解消済**）。
- `m_account.user_id BIGINT AUTO_INCREMENT`（代理キー）＋ `username` UNIQUE（自然キー・検索キー）。account/signon/profile に `version` 楽観ロック列。
- 開発/テスト用シード `flyway/sql-test/R__test_user.sql`（repeatable・冪等）は**既に j2ee/j2ee 等の弱資格情報を含まず**、bcrypt 形のダミーハッシュを使用。**ただしログインを実証できる「既知PW＋実bcryptハッシュ」のデモユーザーは未整備**。

### spec の要点（auth.md §2/§3/§5/§6・security-baseline）

- **§3 業務ルール**: as-is は `where signon.password=#password#`＝**平文の直接比較**。after は PasswordEncoder による**ハッシュ照合**へ（#19）。ログイン失敗は**一律メッセージ**（ユーザ列挙 clean を維持・SBD-6）。
- **§5 secure-by-default（before→after）**: S7平文PW→ハッシュ（SBD-5/#19）、S8セッション固定→**ログイン成功時にID再生成**（SBD-4/#18 AC2）、S9オープンリダイレクト→**allowlist/相対のみ**（SBD-9/#18 AC3）、S5 CSRF→**トークン必須・非冪等POST**（SBD-3/#18 AC4）、S10/S11弱既定資格情報・GET認証→**排除・POST body のみ**（SBD-6）。
- **§6 スコープ**: 挙動等価で残す＝サインオン/サインオフ・保護ゲートのサインオン誘導＋**元URL復帰**。モダン化＝Spring Security 標準・JSP→Vue3 SPA＋REST。**認証方式は JWT httpOnly Cookie＋refresh（localStorage 不使用・決定済）**。**PO 論点: 多言語ログイン画面の扱い（§6①）**。

### ✅ 計画フェーズ確定事項（2026-08-15・ユーザー承認）

- **論点1（フロント有無）＝ backend REST＋Spring Security に絞る**（DEV推奨採用）。Vue ログイン画面・Pinia auth ストア・ルーターガード（元URL復帰）・SPA配送＝#18 AC1/AC3 の**フロント責務分は今スプリント対象外**。
  - **持ち越し先を明示化済**: **#24（E6 フロント土台・Sprint 5 予定）に AC7（サインオン/サインオフ UI・login/logout/refresh 呼び出し＋CSRF cookie→header）・AC8（元URL復帰・復帰先は相対のみ／SBD-9）・AC-neg2 を追記**（2026-08-15 SM が Issue Body 更新）。次回 #24 Refinement で PO が SP・AC 文言を最終確定する。
  - backend 側で満たす分（今スプリント）: login/logout/refresh REST・UserDetailsService・CSRF・平文非保存・弱資格排除・**SBD-9 は backend にリダイレクト sink を作らず構造的に解消**（保護resource は 401 を返すのみ）。全セキュリティAC/否定AC は backend Spock で検証。
- **論点2〜7 は DEV 推奨で決め打ち**（詳細は下記スコープ境界・DEV計画報告のとおり）。セッション再生成＝新規トークン発行/Cookie失効に翻訳、CSRF は #23 基盤を login/logout に適用、デモシードは実bcryptの`demo_user`1件（弱資格なし）、テストは PasswordEncoder=Spock単体・login/logout=Testcontainers統合。
- **cross-repo 注意**: #19 のデモシードは `jpetstore-database`（`R__test_user.sql`）にあるため、`jpetstore-backend` と `jpetstore-database` の**両方に `feature/18-signon-auth` ブランチ＋各コミット**（両方に該当 Issue 参照）。

### ⚠️ スコープ境界（DEV が計画フェーズで線引きしユーザー承認を得ること）

1. **フロント（Vue ログイン画面）を今スプリントに含めるか**（最大の論点）。#18 AC1 は「JSP廃止・Vue3 SPA」を含み、AC3「元URL復帰」は SPA+REST+httpOnly Cookie 方式では**主にフロント責務**（SPA が遷移先を保持→ログイン後に復帰、backend は 401 応答）。`jpetstore-frontend` は存在するが未整備。**backend REST＋security に絞るか、フロントのログイン画面まで作るか**を明示してユーザー承認を得る。
2. **「セッション再生成」(AC2/AC-neg1・SBD-4) の JWT 方式への翻訳**。httpOnly Cookie JWT では HttpSession を使わない。「ログイン前後で session/認証識別子が変わる」の否定AC を、**「ログイン成功＝新規 access/refresh 発行、ログアウト＝Cookie 無効化」**という検証可能な形へどう落とすかを具体化。
3. **#19 と #18 の境界**。#19＝PasswordEncoder bean＋ハッシュ照合基盤＋デモシード、#18＝login/logout エンドポイント＋`UserDetailsService`（#19 の照合を利用）。コミットを Issue 単位で分ける。
4. **デモ/開発シードの扱い**（#19 AC2/AC-neg1）。ログイン実証に「既知PW＋実bcryptハッシュ」のユーザーが必要だが、**弱資格情報は入れない**。repeatable（`R__`）＋冪等（`WHERE NOT EXISTS`）で1件用意（rules/database.md 準拠）。

---

## リスク・チャレンジ

| # | 種別 | 内容 | 対応方針 |
|---|------|------|---------|
| R1 | リスク | **#19 と #18 の密結合・スコープ重複**。#18 のログイン credential 照合が #19 の PasswordEncoder を使う。土台（#23）の AuthController は refresh のみで login 未実装 | 実装順 #19→#18、1ブランチにコミット単位で積む。計画フェーズで両 Story の境界を DEV が明示 |
| R2 | リスク | **JWT ステートレス方式と「セッション再生成」(AC2/AC-neg1・SBD-4) の意味論ギャップ** | 「session/認証識別子が変わる」を JWT 方式へ翻訳（成功＝新規発行/失効＝Cookie無効化）。検証可能な否定ACの形を計画フェーズで確定 |
| R3 | リスク | **元URL復帰（AC3）＋オープンリダイレクト対策（SBD-9）の SPA 実現方式**。SPA では主にフロント責務、backend は 401 応答 | 復帰先は allowlist/相対のみ。**フロントを今スプリントで作るか backend REST に絞るか**を計画フェーズでユーザー承認（スコープ最大の論点＝上記境界①） |
| R4 | リスク | **弱既定資格情報の排除（#19 AC2/AC-neg1・SBD-6）とデモシードの両立**。ログイン実証には既知PW＋実bcryptハッシュのユーザーが必要 | repeatable・冪等シードに実bcryptユーザー1件（弱資格情報なし）。否定AC（平文なし・弱資格でログイン不可）をテスト化 |
| R5 | リスク | **CSRF（AC4・SBD-3）と httpOnly Cookie 方式の整合**。login/logout も CSRF 前提・非冪等POST | #23 の CSRF 基盤を login/logout に適用。SameSite/Origin 検証と、SPA が初回 CSRF トークンを取得する経路を確認 |
| R6 | 好材料（非リスク） | **bannerdata INNER JOIN 罠（auth.md §4）は新スキーマで解消済**（bannerdata 廃止）。`password_hash varchar(255)` も #22 で確保済 | 新 `UserDetailsService` 照合クエリで bannerdata を再導入しないこと（罠の再発防止）。DB 側の #19 準備は完了、backend 結線に集中 |
| R7 | リスク | **土台コードの stale コメント**。AuthController/AuthApplicationService が login API を「#21 の範囲」と誤記。実際は #18（#21 は F5.4 認可土台で別物） | 実装時にコメントを #18 に是正 |
| C1 | チャレンジ | 計画フェーズを **Opus 4.8（1M context）** で実施し、#19/#18＋auth.md＋security-baseline＋#23土台コードを一括読解して、スコープ境界（フロント有無・セッション再生成の翻訳・元URL復帰方式）を先に確定 → 実装 Sonnet で手戻りなく完走（Sprint 1・2 で実証済の tier 分離踏襲） | 計画フェーズを Opus で起動 |
| C2 | チャレンジ | **security ラベル Story（#19）＝ Sec reviewer への明示的検証依頼を先回り**。平文残存・弱既定資格情報・トークン種別・オープンリダイレクト・CSRF/固定化を検証観点として計画に明記（Sprint 2 で Sec reviewer が確定した実績） | レビュー段で Sec 観点を具体指定 |

---

## Definition of Done

- #19: パスワードが bcrypt/argon2 でハッシュ＋ソルト保存・照合され（AC1）、シード/DB に平文・弱既定資格情報が存在しない（AC2/AC-neg1）。
- #18: `POST /api/auth/login`・`POST /api/auth/logout` を Spring Security 標準＋JWT httpOnly Cookie で提供（AC1）。ログイン成功で認証状態を再生成・ログアウトで無効化（AC2/AC-neg1）。元URL復帰（AC3）。login/logout は CSRF 前提・非冪等POST・GET状態変更なし（AC4/AC-neg2）。
- テストは Groovy＋Spock。否定AC（平文なし・弱資格でログイン不可・外部オリジン拒否・固定化不可）を自動テスト化。
- 実機起動＋主要エンドポイント疎通（login→保護resource→logout）＋IDE 警告ゼロ（Sprint 2 DoD 追加分）。
- 3観点レビュー（規約・セキュリティ・パフォーマンス）で指摘なし。
- PR 作成済み（`closes ryokkon624/jpetstore-manage#19` / `closes ryokkon624/jpetstore-manage#18`）。
- Sprint Review 用 HTML 生成済み。
