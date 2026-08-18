# Sprint 17 バックログ

## スプリントゴール

**E4 アカウント（Account & Profile）のセキュリティを完結させる** —
認証済みユーザーが**現在パスワード再認証つき**で安全にパスワードを変更でき（#15）、
登録/編集/PW変更の**全状態変更が CSRF から保護**され（#16）、
登録/編集の入力が **email 形式・最大長・PW 強度**で検証される（#17）状態にする。
これにより **E4 アカウント Epic（機能面）を完了**する。

- **対象 repo**: **2-repo（backend + frontend）**。database 変更なし（`m_signon.password_hash` は既に VARCHAR(255)＝#22 既達・新規テーブル不要）＝Sprint7/11 型のスコープ縮小。
- **ブランチ**: `feature/15-e4-account-security`（2 repo 同名・複数 Issue 1ブランチ方針 Sprint55）。
- **合計**: 8SP（#15=3・#16=2・#17=3）。

## 対象 Issue

| Issue | タイトル | ラベル | SP | 主 repo（暫定） |
|-------|---------|--------|----|----|
| #15 | [E4] パスワード変更に現在パスワード確認（再認証）を必須にする | security / E4 | 3 | frontend 主（capstone=PW変更画面）暫定 |
| #16 | [E4] アカウント状態変更（登録/編集/PW変更）に CSRF 対策を施す | security / E4 | 2 | backend 主（capstone=CSRF 回帰テスト+明文化）暫定 |
| #17 | [E4] アカウント入力検証（email形式・最大長・PW強度）を強化する | feature / E4 | 3 | 主 repo は capstone に応じ PR 時確定（backend retrofit + frontend インライン UI 両面） |

> **実装順序（recon 確定の依存に基づく）**: **#15（PW変更フルスタック新規）→ #16（PW変更ぶんの CSRF 回帰は #15 端点に依存）**。#17 は register/edit DTO への retrofit で #15/#16 と並行可能だが、PW 強度制約は #15 と共有するため**共有制約を先に1本化**する。

---

## 計画フェーズで確定した委譲論点（ユーザー承認済 2026-08-18）

SM ワークフロー①の標準手順（spec/AC/台帳が PO/仕様/実装へ委譲した論点を計画フェーズで AskUserQuestion 確定）。reviewer churn / スコープ手戻り防止。

### Q1: PW 強度ポリシー（#15 AC2 / #17 AC2・SBD-5・ID-16）→ **8〜72字・4種中2種以上**
- 長さ **8〜72字**（**bcrypt の 72 バイト上限**に合わせ上限も設定）。
- **英大文字 / 英小文字 / 数字 / 記号 の 4 種中 2 種以上**を必須（PO決定「複数文字種」の実装レベル具体化）。
- **共有の強度制約を1本化**し、`RegisterRequest.password`（#17 retrofit）と新設 `PasswordChangeRequest.newPassword`（#15）の**両方に適用**（別実装で仕様分岐しないこと）。

### Q2: 各項目の最大長（#17 AC1）→ **DB カラム幅に整合**
- 各フィールドの `@Size(max)` を対応する `m_account` / `m_signon` カラム幅に合わせる（DB 切り詰めエラーを防ぐ単一の真実源）。
- 実カラム幅は **DEV が DDL（`jpetstore-database` の Flyway）から取得**して適用。DB 変更はしない（読むだけ）。

### Q3: PW 変更成功後の JWT セッション扱い（#15・STATELESS/JWT 前提）→ **現在セッションをローテート**
- 変更成功時に **fresh JWT を再発行**（#13 登録の自動ログインと同じ `AuthApplicationService.issueTokensFor(user, response)` を流用）。現行セッションのトークンを更新。
- 他デバイスのトークンは**短命 access + refresh 失効**に委ねる（現状方針どおり）。
- **全セッション即時失効（token version/blacklist）は今スプリント対象外＝別Issue級**（必要なら PO が起票判定）。

### Q4: #16 CSRF の担保方針（AC1「Origin/SameSite 検証」の実装解釈）→ **既達を回帰+明文化**
- **SameSite=Strict + double-submit CSRF トークン**で外部オリジンの状態変更を拒否（`SecurityConfig` に既に実装・register/edit は**テスト済**）。
- **新規 Origin/Referer allowlist フィルタは足さない**（Sprint9 #6 と同方針＝過剰実装回避・`SecurityConfig.java:108-111` にコメント明記済）。
- **PW変更ぶんの CSRF 回帰テスト1本を #15 実装後に追加**＋設計を package-info/コメント等で明文化。

### （DEV 実コード精読で確定予定・2ラウンド目候補）
- **AC3 インラインエラーの実現方式**: **frontend 自前のフィールド単位検証**（既存 `RegisterView` の password-mismatch client パターン踏襲）＋ **backend は権威 400（一律メッセージ据え置き・`ErrorResponse` 契約を拡張しない）** を**既定**とする。DEV が精読後、backend の field-level エラー返却が本当に要るか判定し、要れば実装フェーズ前に AskUserQuestion で確認（Sprint11/14/16 型 2 段階確定）。
- **PW変更エンドポイントの verb/パス**: `PATCH /api/account/password`（or `POST`）等は DEV 設計判断（非冪等・CSRF 必須・本人固定）。`m_signon` は version 楽観ロック対象外（現在PW 再認証ゲートで担保・`m_account.version` アグリゲートに含めない）。

---

## 計画前 Explore の結論（既達 vs 未実装・recon 実地確認済）

### 共通の既達土台（無改造で流用可）
- **bcrypt PasswordEncoder**: `PasswordEncoderConfig.java:22-24`（DelegatingPasswordEncoder）。`encode` / `matches` 両方すぐ使える。現在PW照合は `passwordEncoder.matches(rawCurrent, storedHash)`。
- **自動ログイン/トークン発行**: `AuthApplicationService.issueTokensFor(user, response)`（Sprint16 E9 で login から抽出済）＝PW変更後のローテートに流用。
- **本人固定（IDOR ゼロ）**: `CurrentUserProvider` 起点で本人行のみ触るパターン（`AccountApplicationService` #14 と同型）。
- **CSRF 基盤（全 state-changing に有効）**: `SecurityConfig.java:88-92`（csrf 有効）・`CookieCsrfTokenRepository.withHttpOnlyFalse()` + SameSite=Strict/Secure カスタマイザ `:112-119`・非XOR `CsrfTokenRequestAttributeHandler`（cookie-to-header）`:53`・`CsrfCookieFilter.java:18-29`（毎リクエスト発行強制）。
- **frontend CSRF 自動付与**: `httpClient.ts:25-58`（POST/PUT/PATCH/DELETE に `X-XSRF-TOKEN` 自動添付）。
- **バリデーション例外→400 正規化**: `GlobalExceptionHandler.java:103-107`（`MethodArgumentNotValidException`→400・trace 非露出＝AC3 の trace 部分は既達）。`@Min` 等の Bean Validation 実績は `CartController.java:86,95`。
- **必須(非空)検証**: register `RegistrationController.java:54-69`（全 `@NotBlank`）・edit `AccountController.java:86-99`（`@NotBlank`）。#13/#14 で「非空+PW一致のみ」で **#17 へ委譲済**（`RegistrationController.java:26,51` コメント）。

### #15 パスワード変更（再認証）— **フルスタック新規**（未実装）
**backend**:
1. **PW変更エンドポイント**（非冪等・CSRF 必須・本人固定）＋ `PasswordChangeRequest` DTO（`currentPassword` / `newPassword`。allowlist・username はサーバ権威）。
2. **ユースケース** `AccountApplicationService.changePassword(...)`: `CurrentUserProvider` で本人 userId 解決 → **userId 起点で現在 hash を取得**（新設の取得口。既存 `AccountAuthCustomMapper.findByUsername` は login 専用の username 起点） → `passwordEncoder.matches(current, storedHash)` で**現在PW照合**（不一致は 401/403 相当で拒否＝AC-neg1） → 新PWを**強度検証（Q1 共有制約）** → `passwordEncoder.encode(new)` → `m_signon.password_hash` UPDATE（新設 mapper メソッド）。
3. **トークンローテート**（Q3）: 変更成功時に `issueTokensFor` で fresh JWT 再発行。
4. **frontend**: `accountApi.changePassword(payload)`・`PasswordChangeView.vue` 新規（`.jps-field` kit 流用）・ルート `/account/password`（`requiresAuth: true`）・auth/account store アクション・i18n `account.password.*`（現在PW誤り/強度エラー/成功）。`HomeView`/アカウント画面から導線。

### #16 CSRF（状態変更）— **大部分既達 → 回帰 + 明文化**
- **register/edit の CSRF は既達＋テスト済**: `RegistrationControllerSpec.groovy:227`（CSRFなしPOST→403）・`:236`（GET→405）／`AccountEditControllerSpec.groovy:243`（CSRFなしPUT→403）。GET での状態変更は構造的に不在（register=POST専用・edit=PUT）。
- **未実装（#15 依存の小片のみ）**: **PW変更端点の CSRF 回帰テスト**（"PW変更を CSRF トークン無しで叩くと 403"）を #15 実装後に1本追加。
- **明文化**: 「SameSite=Strict + double-submit で Origin 面を担保・新規 Origin フィルタは足さない」設計を package-info / コメントで明記（Sprint4 SBD-9 型・Sprint15 #11 明文化と同型）。

### #17 入力検証（email形式・最大長・PW強度）— **retrofit + net-new インライン UI**
**backend（retrofit）**:
- `RegisterRequest` / `AccountEditRequest`（`AccountController` 編集 DTO）へ **`@Email`・`@Size(max=…)`** 追加（Q2＝DB カラム幅整合）。account 系に `@Email/@Size/@Pattern` は現状 **0 個**。
- **PW 強度**（Q1 共有制約）を register.password（および #15 の newPassword）に適用。
**frontend（新規）**:
- **フィールド単位インラインエラー表示は net-new**（既存は form 単位 `jps-alert` のみ・`RegisterView.vue:56-61`/`AccountEditView.vue:85-100`）。`AddressForm.vue` に maxlength/フィールドエラー無し。→ 既定は**frontend 自前検証＋backend 権威400**（上記「2ラウンド目候補」）。
- **i18n**: 検証エラー用キー新設（`en.ts:110-116` は USERNAME_TAKEN/RATE_LIMITED/PASSWORD_MISMATCH/default のみ）。email 形式/最大長/PW 強度/現在PW誤り 用キー追加。

---

## スコープ境界（本スプリント対象外）

- **メール検証本実装**（SMTP・トークン表）→ #32（NotReady・deferred）。#17/#16/#15 では扱わない。
- **全セッション即時失効（token version/blacklist）** → 別Issue級（Q3・必要なら PO 起票判定）。
- **日本語ローカライズ** → #25（deferred）。i18n は英語のみ（新規キーは en）。
- **database 変更なし**（password_hash は既に255・新規テーブル不要）。

---

## Issue 全文（転記）

### #15 [E4] パスワード変更に現在パスワード確認（再認証）を必須にする（security / E4・SP3）

**ユーザーストーリー**
- **As a** 認証済みユーザー
- **I want to** パスワード変更時に現在パスワードの確認を求めたい
- **So that** セッション乗っ取り時の不正なPW変更を防ぐ（S6 是正）

**トレース**
- Epic: E4 アカウント（Account & Profile）
- Feature: F4.3 パスワード変更の再認証
- 挙動spec: spec/behavior/account.md §5（S6）
- 横断NFR: spec/security-baseline.md（SBD-16, SBD-5）

**Acceptance Criteria**
- [x] AC1 (SBD-16): パスワード変更は **現在パスワード確認/再認証を必須** にする。
- [x] AC2 (SBD-5): 新パスワードはハッシュ＋ソルトで保存。強度検証（8字以上・複数文字種・PO決定）。
- [x] AC-neg1 (否定AC / SBD-16): 現在パスワード無し/誤りでの PW 変更が拒否される。

**備考**
- 依存関係: #19（F5.2 ハッシュ）／#14（F4.2）。
- PO決定（Refinement 2026-08-11）: PW 強度ポリシー（8字以上・複数文字種）。→ **本スプリント Q1 で「8〜72字・4種中2種以上」に具体化・確定**。

### #16 [E4] アカウント状態変更（登録/編集/PW変更）に CSRF 対策を施す（security / E4・SP2）

**ユーザーストーリー**
- **As a** サイト運営者
- **I want to** アカウント系の状態変更を正規リクエストのみ受理したい
- **So that** CSRF 駆動の遠隔乗っ取り（S5+S2+S6）の起点を遮断する

**トレース**
- Epic: E4 アカウント（Account & Profile）
- Feature: F4.4 状態変更の CSRF
- 挙動spec: spec/behavior/account.md §5（S5）
- 横断NFR: spec/security-baseline.md（SBD-3）

**Acceptance Criteria**
- [x] AC1 (SBD-3): newAccount/editAccount/PW変更に CSRF トークン必須・非冪等POST・Origin/SameSite 検証。
- [x] AC-neg1 (否定AC / SBD-3): 外部オリジンからの登録/編集/PW変更が拒否される。GET での状態変更リンクが存在しない。

**備考**
- 優先順位の根拠: before Top3 #3 の起点遮断。F4.1-F4.3 と一体で担保。
- 依存関係: #23（E6.2 CSRF基盤）。→ **本スプリント Q4 で「既達を回帰+明文化・新規Originフィルタ無し」に確定**。PW変更ぶんは #15 依存。

### #17 [E4] アカウント入力検証（email形式・最大長・PW強度）を強化する（feature / E4・SP3）

**ユーザーストーリー**
- **As a** サイト運営者 / ユーザー
- **I want to** 登録/編集の入力を適切に検証したい
- **So that** 不正・不整合データや弱いパスワードを防ぐ

**トレース**
- Epic: E4 アカウント（Account & Profile）
- Feature: F4.5 入力検証
- 挙動spec: spec/behavior/account.md §2, §6論点③
- 横断NFR: spec/security-baseline.md（SBD-5 関連）

**Acceptance Criteria**
- [x] AC1: email 形式・各項目の最大長・必須を検証（as-is は非空＋PW一致のみ）。
- [x] AC2 (SBD-5 関連): パスワード強度（8字以上・複数文字種・PO決定）を検証。
- [x] AC3: 検証エラーは分かりやすいインラインエラーで表示（trace 非露出）。
- [x] AC-neg1 (否定AC): 不正 email 形式・超過長・弱いPWが拒否される。

**備考**
- 依存関係: #13（F4.1）／#14（F4.2）／#15（F4.3）。
- PO決定（Refinement 2026-08-11）: 検証範囲＝email 形式＋最大長＋PW 強度。→ **本スプリント Q1（PW強度）/Q2（最大長=DBカラム幅整合）で具体化・確定**。

---

## リスク・チャレンジ

### リスク
- **R1（最大）**: **PW変更フルスタック新規（#15）**。userId 起点の現在 hash 取得口が既存に無い（既存 `AccountAuthCustomMapper.findByUsername` は login 専用の username 起点）。→ **userId 起点の password_hash 取得 mapper を新設**。現在PW照合の失敗経路（AC-neg1）を実テストで実証。
- **R2**: **PW 強度制約の1本化（#15/#17 重複）**。共有制約を別々に実装すると仕様分岐→**担当を先に1つ決めて共有 Validator/制約を register.password と newPassword に適用**（recon 指摘の手戻り要因）。
- **R3**: **実装順序依存**。#16 の PW変更ぶん CSRF 回帰は #15 端点に依存。**#15 → #16** の順で進める（reviewer に「PW変更ぶんは #15 実装後に追加」を明示）。
- **R4**: **AC3 インラインエラーが net-new frontend**。既存は form 単位アラートのみ。frontend 自前フィールド検証を新規実装（backend 契約は据え置きが既定・2ラウンド目で再判定）。
- **R5**: **トークンローテート（Q3）が login/register を壊さない**こと。`issueTokensFor` 流用で既存経路不変を担保（Sprint16 E9 の抽出済メソッドを再利用）。

### チャレンジ
- **C1**: **先例再利用の実効性検証** — Sprint16 で抽出した `issueTokensFor`（自動ログイン）が PW変更ローテートに、#14 の本人固定パターンが #15 に、#23 CSRF 基盤が #16 に無改造で機能するか。
- **C2**: **tier分離 17連続** — 計画=Opus（最上位）/実装=Sonnet（高速）。E4 セキュリティ完結（PW変更・CSRF・入力検証）でも手戻りゼロ完走を狙う。
- **モデル更新**: 現行は Opus 4.8 [1m]（最上位 tier 最新）。新モデルのリリースは無いため今スプリントのモデル更新チャレンジは無し。

### reviewer 起動時に明記する意図的設計（churn 防止）
- **#16 で新規 Origin/Referer フィルタを作らない**（SameSite=Strict + double-submit で担保・Sprint9 #6 同方針）を「欠落として指摘しない」。
- **PW変更で全セッション失効（token version/blacklist）を実装しない**（現在セッションのローテートのみ・全失効は別Issue級）を「欠落として指摘しない」。
- **`m_signon` に version 楽観ロックを付けない**（PW変更は現在PW再認証ゲートで担保・`m_account.version` アグリゲートに含めない）を「欠落として指摘しない」。
- **#17 で backend の `ErrorResponse` を field-level に拡張しない**（既定＝frontend 自前検証＋backend 権威400・一律メッセージ据え置き。2ラウンド目で変更あれば別途明示）を「欠落として指摘しない」。
- **メール検証本実装の不在**（#32・deferred）を「欠落として指摘しない」。
- **database 無変更**（password_hash 既に255・新規テーブル不要）を「欠落として指摘しない」。
