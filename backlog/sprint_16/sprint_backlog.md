# Sprint 16 バックログ

## スプリントゴール

**E4 アカウント（Account & Profile）の登録と編集を secure-by-default で提供する** —
新規ユーザーがアカウントを登録して自動ログインでき（#13）、認証済みユーザーが**自分のアカウント/プロフィールだけ**を後勝ち上書きなく安全に編集できる（#14）状態にする。

- **対象 repo**: **3-repo（backend + frontend + database）**（第2ラウンド E1 で確定）。DB 変更は**登録レート制限用テーブルの新規 Flyway のみ**（version 列・password_hash・bannerdata 除外は既達 = `V00_000_004`）。
- **ブランチ**: `feature/13-e4-account`（3 repo 同名・複数 Issue 1ブランチ方針 Sprint55）。
- **合計**: 10SP（#13=5・#14=5）。

## 対象 Issue

| Issue | タイトル | ラベル | SP | 主 repo（暫定） |
|-------|---------|--------|----|----|
| #13 | [E4] ユーザー登録（自動ログイン・セッション再生成）を提供する | feature / E4 | 5 | frontend 主（capstone=登録画面）暫定 |
| #14 | [E4] アカウント/プロフィール編集を本人固定・allowlist バインドにする | security / E4 | 5 | capstone に応じ PR 時確定 |

---

## 計画フェーズで確定した委譲論点（ユーザー承認済 2026-08-17）

### Q1: メール検証のスコープ（#13 AC4 / SBD-6）→ **レート制限で担保＋検証はプレースホルダ**
- AC-neg2（登録の総当り/列挙抑止）は**新設の DB-backed 登録試行テーブル＋レート制限サービス**（既存 `LoginAttemptService`/`t_login_attempt` と同方式・**IP キー**・XFF 非信頼＝Sprint2 教訓）で担保する（**第2ラウンド E1・ユーザー確定 2026-08-17**＝in-memory ではなく永続方式を選択 → 3-repo 化）。超過は 429。
- メール検証は**実 SMTP/JavaMailSender 基盤・検証トークン表が現状ゼロ**のため、**プレースホルダ扱い＋別バックログへ持ち越し**（Sprint15 支払プレースホルダ = ID-8 と同型）。→ 台帳追記は PO へ。
- 既存 `LoginAttemptService` は username キーのロックアウト（認証失敗用）で登録には不適。**転用せず、同方式の登録試行テーブル/サービスを新設**（キーが IP 単位で別）。

### Q2: #13 の入力検証範囲（§6論点③ / ID-16）→ **as-is 同等＋#17 へ委譲**
- #13 は**必須項目非空・password==repeatedPassword・username 一意（DB UNIQUE）**のみ。
- email 形式・最大長・PW 強度（8字以上・複数文字種）は台帳 **ID-16 のとおり #17（F4.5）/#15 で実施**（#13 では作らない = reviewer に「欠落として指摘しない」意図的スコープ）。

## 計画フェーズ第2ラウンド確定（DEV 実コード精読報告後・ユーザー承認 2026-08-17）

- **E1（ユーザー確定）**: 登録レート制限は **DB-backed 登録試行テーブル**（既存 `LoginAttemptService`/`t_login_attempt` と同方式・IP キー・XFF 非信頼・超過 429）。→ **3-repo 化**（database に新規 Flyway）。in-memory 案は不採用（永続・多インスタンス耐性を優先）。閾値既定は DEV が調整。
- **E6（ユーザー確定）**: `frontend main.css` の `.jps-required::after` を**グローバルに 'Required' へ英語化**（新規フォーム＋既存チェックアウト AddressForm を一括是正・CSS のみ）。
- **E2（SM 承認）**: `m_account.version` を編集アグリゲートの**単一楽観ロックトークン**（GET/PUT で1往復）。account を version ガード→409、profile は同一 tx で無ガード更新（account ガードが tx 全体を中断＝profile も lost update なし）。二重 version は非採用。
- **E3（SM 承認）**: 新規 `GET /api/account`（編集プリフィル・version 込み）を追加。チェックアウト用 `GET /api/account/me` は無変更（既存テスト波及回避）。
- **E4（SM 承認・spec 確定）**: username 重複は DB UNIQUE 違反捕捉→**409＋明示「使用済み」**（列挙対策はレート制限が担保する前提）。
- **E5（SM 承認）**: 登録フォームに langpref/favcategory 入力欄を出さない（langpref はサーバ既定 "english"・favcategory は NULL。設定は #14 編集）。DTO は optional で受理。
- **E7（SM 承認）**: 登録の WHO は `create_user_id=NULL`（未認証 guest・arch §2.1 準拠）。`create_program` はインターセプタ自動補完。
- **E8（SM 承認）**: 登録エンドポイントは **`POST /api/register`（独立パス）**。`/api/account/**` を一律 authenticated に保ち、メソッド別 permitAll の微妙さを回避。
- **E9（SM 承認）**: 自動ログインは `AuthApplicationService.issueTokensFor(user, response)` を login 末尾から抽出して register で再利用（既存 login 不変）。
- **申し送り**: backend 作業ツリーの `V00_000_001/002`（test flyway sql）の未コミット変更は LF→CRLF の改行差のみ（内容差分なし・DEV 由来でない）。実装時に誤コミットしないこと（Sprint6/15 の EOL ノイズ教訓）。

---

## 既決事項（確認のみ・reviewer には意図的設計として明記）

- **AC2/SBD-4 セッション再生成の解釈（JWT stateless）**: `SecurityConfig` は `SessionCreationPolicy.STATELESS`。**HttpSession を導入せず、登録成功＝fresh JWT を httpOnly Cookie に発行**（`JwtService.generate*` + `AuthCookieSupport.write*`）で固定化防止を担保。新規ユーザーゆえ無効化すべき既存トークンは無い。→ **HttpSession 追加は過剰実装なので作らない**（意図的設計・ID-10）。
- **status="OK" サーバ決定・内部項目非表示**（#14 既決）／**langpref 任意保持・i18n 英語のみ**（AC5/ID-27・日本語は #25）／**bannerdata・MyList 廃止**（ID-7・favcategory のみ任意プロフィール設定として残置）。
- **認証トークン方針**: JWT を httpOnly Cookie 保管（localStorage 不使用）＋短命＋refresh。Cookie 方式ゆえ CSRF（SBD-3）は既存 httpClient で自動担保。

## スコープ境界（本スプリント対象外・台帳で確定）

- **パスワード変更**（現在PW 再認証 SBD-16 / ID-13）→ **#15**。#14 編集は **m_account + m_profile フィールドのみ**（m_signon/password は非対象）。
- **入力検証強化**（ID-16）→ **#17/#15**。
- **メール検証本実装**（SMTP・トークン表）→ 別バックログ持ち越し（Q1）。

---

## 計画前 Explore の結論（既達 vs 未実装）

### 共通の既達土台（無改造で流用可）
- **JWT stateless 発行**: `JwtService.generateAccessToken/generateRefreshToken`・`AuthCookieSupport.writeAccessTokenCookie/writeRefreshTokenCookie`・`SecurityConfig.java:84` `SessionCreationPolicy.STATELESS`。
- **bcrypt**: `PasswordEncoderConfig`（DelegatingPasswordEncoder・`{bcrypt}`）。encode 呼出は新規（登録で `passwordEncoder.encode(raw)`）。
- **楽観ロック 409 足場**: `OptimisticLockConflictException` → `GlobalExceptionHandler.handleConflict`（409）／`AffectedRows.requireUpdated(rows)`（affected==0 で送出）。**実 UPDATE 先例はゼロ = #14 が第1号**。
- **本人スコープ**: `OwnershipAuthorizationService.assertOwner`（403・監査付き）／`CurrentUserProvider.requireCurrentUser()` 起点で本人行のみ触る read 先例（`AccountApplicationService.getMyContact` = IDOR 面ゼロ）。
- **DDL 既達**: `m_account`/`m_signon`/`m_profile`（`V00_000_004`）= user_id AUTO_INCREMENT PK・username UNIQUE・**version 列 3表とも存在**・password_hash VARCHAR(255)・bannerdata/mylistopt/banneropt 除外済。
- **frontend**: フォーム kit（`.jps-*`・`SignonView.vue`/`AddressForm.vue` がテンプレ）・auth ストア（`signon`/`signoff`/`fetchCurrentUser`/`isAuthenticated`）・CSRF 自動付与 httpClient・`HttpError`（status 保持）・GET `/api/account/me`（`accountApi.fetchAccountContact`）。

### #13 ユーザー登録 — 未実装（新規作業）
**backend**:
1. `POST /api/account`（or `/api/register`）コントローラ＋登録 DTO（allowlist: username/password/氏名/住所/email/phone/langpref?/favcategory?）。
2. 登録ユースケース `AccountApplicationService.register(...)`: `passwordEncoder.encode()` ＋ m_account/m_signon/m_profile INSERT（新規書き込み mapper・WHO/version 初期値）。**username UNIQUE 衝突ハンドリング**。
3. **自動ログイン**: 照合を経ない JWT 発行経路（`login()` を参考に `JwtService`+`AuthCookieSupport` を直接呼ぶ）。既存 `login()`（AuthenticationManager 経由）を壊さない。
4. `SecurityConfig` permitAll に登録パス追加（未認証到達可・CSRF は既存設定）。
5. **DB-backed 登録レート制限**（AC-neg2 担保・E1 確定）: database に登録試行テーブルの新規 Flyway（`t_login_attempt` 相当・IP キー・WHO 列）＋ backend に `LoginAttemptService` 同方式の登録試行サービス/mapper。XFF 非信頼（Sprint2 教訓）・超過 429。閾値既定は DEV 調整。

**frontend**:
6. `accountApi.registerAccount(payload)` = POST。登録 DTO 型新設。
7. `RegisterView.vue` 新規（SignonView/AddressForm を下敷きに `.jps-field`）。
8. ルート `/register`（`requiresAuth` なし = guest 可・必要なら guest-only リダイレクト判定）。
9. 登録成功後の自動ログイン配線（auth ストアで user セット or `fetchCurrentUser()`）。
10. `HomeView.vue` の "New Here?" ダミーリンク（`href="#"`）を `/register` へ配線。
11. i18n `account.register.*`。

### #14 アカウント/プロフィール編集 — 未実装（新規作業）
**backend**:
12. `PUT/PATCH /api/account`（本人固定 = URL に userId を取らず `CurrentUserProvider` 起点・`assertOwner` 併用可）＋編集 DTO（allowlist: email/氏名/住所/phone/langpref/favcategory。userid/username/status/version/WHO はサーバ権威）。
13. 編集ユースケース＋`UPDATE m_account/m_profile ... WHERE user_id=:id AND version=:readVersion` mapper（**version 楽観ロック UPDATE の初実装**）。`AffectedRows.requireUpdated(rows)` → affected==0 → `OptimisticLockConflictException` → 409。
14. GET 側で **version を返す**拡張（現行 `AccountContact` record は version 非保持のため編集用 read/write モデルを拡張 or 新設）。

**frontend**:
15. `accountApi.updateAccount(payload)` = PUT/PATCH。取得レスポンスに version を含める型拡張。
16. `AccountEditView.vue` 新規（`fetchAccountContact()` でプリフィル・**allowlist で編集可フィールド限定**）。
17. ルート `/account`（or `/account/edit`）を `requiresAuth: true`。
18. **409 競合 UX（新規パターン）**: `HttpError.status===409` を検知し「他で更新されたため最新を再読込」を促す（store に conflict フラグ + 再取得ボタン/アラート）。既存 order.ts の 409→終端文言とは別の「再読込促進」フロー。
19. i18n `account.edit.*`（フィールド/成功/409 競合/一般エラー）。

### 留意（既存不整合）
- `frontend main.css` の `.jps-required::after` が日本語 `'必須'`。英語のみ方針の新規フォームで日本語ラベルが出る。→ 英語化 or 個別対応を DEV 判断。

---

## Issue 全文（転記）

### #13 [E4] ユーザー登録（自動ログイン・セッション再生成）を提供する（feature / E4・SP5）

**ユーザーストーリー**
- **As a** 新規ユーザー
- **I want to** アカウントを登録して自動でログインしたい
- **So that** すぐ買い物を始められる

**トレース**
- Epic: E4 アカウント（Account & Profile）
- Feature: F4.1 ユーザー登録
- 挙動spec: spec/behavior/account.md §2, §3, §5
- 横断NFR: spec/security-baseline.md（SBD-4, SBD-5, SBD-6, SBD-3, SBD-18）

**Acceptance Criteria**
- [x] AC1: account/signon/profile 3表相当への登録を REST＋SPA で提供（JSP廃止）。登録後は自動ログイン。
- [x] AC2 (SBD-4): 登録直後の自動ログインで **セッションID/認証状態を再生成**（固定化防止）。→ *本プロジェクトは STATELESS/JWT。fresh JWT 発行で担保（HttpSession 非導入）。*
- [x] AC3 (SBD-5): パスワードはハッシュ＋ソルトで保存（平文保存しない）。
- [x] AC4 (SBD-6): ユーザー名列挙対策として **レート制限＋メール検証**（登録の一律メッセージ化は非現実的なため代替）。→ *Q1: レート制限で担保・メール検証はプレースホルダ持ち越し。*
- [x] AC5: `profile.langpref` は任意項目として保持（i18n は英語のみ＋基盤・PO決定）。bannerdata/MyList は廃止（決定済）。
- [x] AC6 (SBD-18): 入力表示はエスケープ。bannerName 等の HTML 内包列は継承しない。
- [x] [L2] 旧同値: 登録 → account/signon/profile が各1行・入力値どおり。※PWハッシュ化は ID-2（平文を期待値にしない）
- [x] AC-neg1 (否定AC / SBD-5): 登録後、DB に平文パスワードが存在しない。
- [x] AC-neg2 (否定AC / SBD-6): 登録エンドポイントの総当り/列挙がレート制限で抑止される。

**備考**
- 依存関係: #18-#19（認証土台・ハッシュ）／#22（E6.1・hash列拡張/bannerdata除外）／#23（E6.2）。
- PO決定（Refinement 2026-08-11）: i18n 英語のみ＋基盤・bannerdata/MyList 廃止（決定済 2026-08-10）。

### #14 [E4] アカウント/プロフィール編集を本人固定・allowlist バインドにする（security / E4・SP5）

**ユーザーストーリー**
- **As a** 認証済みユーザー
- **I want to** 自分のアカウント/プロフィールだけを編集したい
- **So that** 他人のアカウントを書き換えられない（S2/S3 是正）

**トレース**
- Epic: E4 アカウント（Account & Profile）
- Feature: F4.2 アカウント/プロフィール編集（本人固定）
- 挙動spec: spec/behavior/account.md §2, §5（S2, S3）
- 横断NFR: spec/security-baseline.md（SBD-1, SBD-2, SBD-3）
- アーキ規約: spec/architecture-conventions.md §4.2（version 楽観ロック）／.claude/rules/database.md「並行制御」

**Acceptance Criteria**
- [x] AC1 (SBD-1): 更新対象を **認証プリンシパル本人に固定**（`username` をクライアントから受けない）。
- [x] AC2 (SBD-2): マスアサインメント allowlist（編集可フィールドのみ受理、userid/status 等の権威値はサーバ決定）。account.status は内部項目（既定OK・非表示・PO決定）。
- [x] AC3 (arch §4.2): account/profile など**更新エンティティ表は `version` 楽観ロック**。更新は `SET ..., version = version + 1 WHERE pk = :id AND version = :readVersion`、**affected rows == 0（競合）は HTTP 409 Conflict** を返し最新の再読込を促す（`updated_at` はロックに使わず監査専用）。読込時に `version` を返し更新要求で往復させる。
- [x] AC-neg1 (否定AC / SBD-1): `account.username=他人` で editAccount しても、他人は更新されず自分のみ更新される（before S2 editAccount 乗っ取り消滅）。
- [x] AC-neg2 (否定AC / SBD-2): 権威フィールド（userid/status 等）を注入しても無視される。
- [x] AC-neg3 (否定AC / arch §4.2): 古い `version` を持つ更新要求は 409 で拒否され、**後勝ちの上書き（lost update）が起きない**。

**備考**
- 優先順位の根拠: before Top3「CSRF 駆動の遠隔乗っ取り(S5+S2+S6)」の起点。
- アーキ根拠: 編集系の後勝ち防止は architecture-conventions §4.2（version 楽観ロック→409 Conflict）。並行性 AC の根拠として参照。
- 依存関係: #18（認証）／#22（E6.1・account/profile に version 列）／#23（E6.2・409 統一マッピング）。
- PO決定（Refinement 2026-08-11）: account.status は内部項目（非表示）。

---

## リスク・チャレンジ

### リスク
- **R1（最大）**: **version 楽観ロック UPDATE のコードベース初実装**（#14）。足場（`AffectedRows.requireUpdated`/`OptimisticLockConflictException`/`handleConflict`/DDL version 列）は既達だが、UPDATE の version ガード＋read 時 version 往復＋409 後の再読込 UX まで一気通貫の初実装。→ AC-neg3 を**古い version の並行更新テスト**で実証（#8 の並行テスト手法を応用）。
- **R2**: 登録の自動ログインは既存 `login()` が AuthenticationManager 経由（password 照合）なので、**照合スキップの JWT 発行経路を新設**する必要（既存 login を壊さない）。
- **R3**: **DB-backed 登録レート制限**（AC-neg2・E1 確定）。既存 `LoginAttemptService` は username キーのロックアウトで登録に不適 → 同方式の登録試行テーブル（IP キー・新規 Flyway＝**3-repo 化の要因**）＋サービスを新設。XFF 非信頼（Sprint2 教訓）。
- **R4**: `.jps-required::after` の日本語 `'必須'`（frontend main.css）— 英語のみ方針の新規フォームで日本語ラベルが出る既存不整合。DEV 判断で英語化 or 個別対応。
- **R5**: メール検証プレースホルダの**明示**（台帳追記＋別バックログ起票）を PO と連携して漏らさない（Sprint15 ID-8 と同型）。

### チャレンジ
- **C1**: **先例再利用の実効性検証** — Sprint4 で先取り設計された 409 楽観ロック足場（`AffectedRows`/`OptimisticLockConflictException`）が、3スプリント（Sprint13/14/15 の #29/#30 Repository 展開後）を経て version lock 初実装に無改造で機能するか。#8 の `AffectedRows.requireUpdated` パターン（在庫ガード）を version ガードへ横展開。
- **C2**: **tier分離 16連続** — 計画=Opus（最上位）/実装=Sonnet（高速）。E4 初の write ドメイン（登録 INSERT・編集 UPDATE）でも手戻りゼロ完走を狙う。
- **モデル更新**: 現行は Opus 4.8 [1m]（最上位 tier 最新）。新モデルのリリースは無いため今スプリントのモデル更新チャレンジは無し。

### reviewer 起動時に明記する意図的設計（churn 防止）
- HttpSession 非導入（STATELESS・fresh JWT で SBD-4 担保）を「欠落として指摘しない」。
- #13 の email 形式/PW 強度検証の不在（#17 へ委譲）を「欠落として指摘しない」。
- #14 のパスワード変更 UI/API 不在（#15 へ委譲）を「欠落として指摘しない」。
- メール検証本実装の不在（プレースホルダ・別バックログ）を「欠落として指摘しない」。
