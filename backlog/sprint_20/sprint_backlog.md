# Sprint 20 バックログ

## スプリントゴール

**Phase 4 L3（セキュリティ回帰）が after 側で発見した確定所見のうち Critical 1件・Medium 3件を潰し、SEC が手で実証した PoC を「CI で守れる回帰テスト資産」に変換する。**

- 本スプリントは **Find-and-Fix ループの Fix 半分**。機能追加は行わない **セキュリティ修正スプリント**。
- 中核は #38（JWT 署名鍵の公開 placeholder 稼働＝資格情報なしのなりすまし／ADMIN 昇格）。**dev の `.env` 差し替えで終わらせず、コード側の fail-fast を強化して「既知 placeholder / 低エントロピー値では起動しない」ようにする**のが本質の欠陥是正。
- 残る3件は **監査完全性（SBD-14）とレート制限実効性（SBD-6）の毀損**＝Phase 4 合否ゲート L3/L4 の確からしさに直結する。
  - #39 監査抑止（過大長 URI で認可失敗監査が消え 403→401 化）
  - #40 注文失敗の監査欠落（ID-22 未達）＋入力制約欠落による 500
  - #41 レート制限の check-then-act（並行バーストで閾値回避）
- **全 Story 共通の主成果物 = 否定AC の回帰テスト**（`verification-strategy.md` §1 L3「before の PoC が after で失敗すること」の運用＝**L3 成果をテスト資産にする**）。

## 対象 Issue

| Issue | タイトル | ラベル | SP(Project) | repo |
|-------|---------|-------|-----|------|
| #38 | [SEC][L3][Critical] JWT署名鍵が公開のplaceholder値で稼働し、資格情報なしで任意ユーザ/ADMINのトークンを偽造できる | bug / security | 2 | backend |
| #39 | [SEC][L3][Medium] 過大長URIで認可失敗の監査記録が消え、403が401に化ける（監査抑止） | bug / security | 5 | backend(主) + database |
| #40 | [SEC][L3][Medium] 注文確定の失敗が監査に残らず500になる（入力制約欠落・ID-22未達） | bug / security | 3 | backend |
| #41 | [SEC][L3][Medium] ログイン/登録のレート制限がcheck-then-actで並行バーストにより回避できる（TOCTOU） | bug / security | 3 | backend |

**合計 SP = 13**（Project 現在値どおり。Planning での再見積り無し）。

**実装順（推奨）**: #38 → #39 → #40 → #41（Issue #38 備考「他の SEC 所見より優先する」に従う。#39/#40 は監査系で近接するため連続実施が効率的）。

## ブランチ（1ブランチ集約・Sprint 55 方針）

- **backend**: `fix/38-l3-security-fixes`（#38/#39/#40/#41 の全コミットを Issue 単位で積む）
- **database**: `fix/38-l3-security-fixes`（同名ブランチ。#39 の Flyway `V00_000_014` のみ）
- **frontend**: 変更なし（触らない）

---

## 横断確定事項（Planning 2026-08-19・AskUserQuestion 4 件をユーザー確定）

### Q1: #39 AC3（未認証由来の監査 write 抑止）の保持方式 = **新規カウンタ表 `t_audit_write_quota`**

- `jpetstore-database` に **Flyway `V00_000_014__create_audit_write_quota.sql`** を追加。`client_ip VARCHAR(45)` を PK、FK 制約なし（`t_login_attempt.username` / `t_register_attempt.client_ip` / `t_audit_log.actor_user_id` と同じ no-FK 判断）、`version` 列なし（一過性のセキュリティ運用状態）、WHO カラム標準ブロック付き。
- backend 側は **`INSERT ... ON DUPLICATE KEY UPDATE` の単文アトミック更新**で枠取り（`t_login_attempt` / `t_register_attempt` と完全同型）。枠超過時は監査行を INSERT せず、**抑止された事実をアプリログに残す**（AC3「黙って消えないこと」）。
- 根拠: `spec/architecture-conventions.md` **D7**「secure-by-default 系の試行カウンタ・レート制限状態は DB-backed で永続化（in-memory / HTTP セッション保持は不可）」。D7 の判例2件（`t_login_attempt`＝Sprint4 #20 / `t_register_attempt`＝Sprint16 #13）と同一の設計軸。
- **→ #39 は cross-repo（backend 主 + database）となる。**
- 上限値・窓の**具体値**は DEV が既存 `auth.lockout`（max-attempts=5 / PT15M）との整合を見て提案する（AC3 が DEV 提案としている範囲）。設定は `application.yml` で env 上書き可にすること。

### Q2: #41 AC1（レート制限ゲートの原子化）の方式 = **条件付き UPDATE によるスロット確保**

- **既存 `t_login_attempt` / `t_register_attempt` のスキーマは据え置き（DB 変更ゼロ）＝ #41 は backend 単一 repo で完結。**
- bcrypt 照合の **前** に、単文の条件付き UPDATE で枠を原子的に確保する。`affected rows == 1` なら照合へ進み、`== 0` なら枠切れとして **`authenticate()` に到達させず短絡**する。
  ```sql
  UPDATE t_login_attempt
     SET failed_attempt_count = failed_attempt_count + 1, ...
   WHERE username = ?
     AND (lock_until IS NULL OR lock_until <= NOW(6))
     AND failed_attempt_count < :maxAttempts
  ```
- これにより「判定してから照合し、後で数える」（check-then-act）が消え、並行 N 本でも `authenticate()` 到達回数が閾値近傍で頭打ちになる。
- **注意（AC4 の受入条件）**: 既存 `recordFailure` は MySQL の `ON DUPLICATE KEY UPDATE` が **SET 句を左→右に評価**する挙動に**意図的に依存**して閾値判定している（同じ条件式を2箇所で独立に書くと二重計算で閾値判定が1回分ずれる不具合が過去に IT で発覚）。**この窓リセット意味論を壊さないこと**。行が存在しない初回失敗（INSERT 経路）の扱いも含めて設計する。
- **AC3（列挙耐性）も受入条件**: 実在/非実在 username でロック挙動・応答ボディ・所要時間が区別できないこと（no-FK 対称扱い・`assertNotLocked` が誤資格と同一の `BadCredentialsException` を投げる現行仕様を保つ）。

### Q3: #38 の PoC 回帰テスト粒度 = **L3 PoC を名指しした回帰 Spec を追加する**

- Issue #38 備考の PO 判断（「別鍵署名→401」「roles 偽造→401」は既存 `JwtServiceSpec` / `JwtAuthenticationFilterSpec` で既達につき新規追加しない）を、**ユーザー指示により上書き**する。
- AC-neg1 / AC-neg2（placeholder 値・低エントロピー値では起動しない）に加えて、**L3 N1 の PoC そのものを名指しで固定する薄い回帰 Spec** を追加する:
  - `.env.example` の実リテラル値（`please-replace-with-a-random-secret-of-at-least-32-bytes`）で署名した偽造 access token → `GET /api/auth/me` **401**
  - 同鍵で `roles:["ADMIN"]` を偽造した token → ADMIN 限定エンドポイント **401**
- 既存テストと論理的には重複するが、**「SEC が手で実証した PoC が CI で守られている」トレーサビリティ**を成果物として残すことが目的（本スプリントの主眼）。テスト名・javadoc に L3 N1 由来であることを明記する。

### Q4: L3 PoC 残置データの衛生 = **Sprint 20 内で単発 UPDATE して解消**

- 実機確認済み（Planning 時・SM 実測）:
  ```
  user_id  language_preference             color_scheme_preference
  1        english                         system
  2        <img src=x onerror=alert(1)>    dark      ← demo_user・L3 PoC(N12) の残置
  ```
- seed `jpetstore-database/flyway/sql-test/R__test_user.sql` は **`WHERE NOT EXISTS` の INSERT のみ**のため、**再投入では直らない**。
- **DEV が dev MySQL（コンテナ `dev-jpetstore-db`）へ以下を1回実行**し、`#20-sprint` 作業スレッドに実行結果を報告する。**コード変更なし・AC 化しない**（スコープ逸脱を避ける）。
  ```sql
  UPDATE m_profile SET language_preference = 'english' WHERE user_id = 2;
  ```
- `languagePreference` の allowlist（`@Pattern`）付与＝混入経路そのものの封鎖は **#44(B) のスコープ**であり、本スプリントでは実装しない。

---

## 計画前 実地調査（既達 vs 未実装・SM 実施 2026-08-19）

`jpetstore-backend` / `jpetstore-database` の実コードを直接読んで確認した事実。PO の Refinement（各 Issue の「実コード裏取り」節）と突き合わせ済み。

| 論点 | 実コードでの確認結果 | 帰結 |
|---|---|---|
| #38 `JwtProperties` | `MIN_SECRET_BYTES = 32` のみ検証（`JwtProperties.java:19,29-37`）。denylist・エントロピー検証なし | AC1/AC2 は**完全に未実装**（新規追加） |
| #38 `.env.example` | `git ls-files` で**追跡下**であることを確認。`JWT_SECRET=please-replace-with-a-random-secret-of-at-least-32-bytes`（56byte・32byte 検証を通過する） | Q1 denylist に**この実リテラルを恒久収録**する |
| #38 README | `README.md` 秘密管理節に「最小 32byte。起動時に鍵長を検証する」とあり**差し替え必須の明示なし**。手順は「`.env.example` を `.env` にコピーして値を設定する」 | AC4 で**破壊的変更（placeholder では起動しない）を明記**する必要あり |
| #39 `t_audit_log.action` | `VARCHAR(100) NOT NULL`。DDL コメントは「操作(例: ORDER_CREATE, LOGIN, EDIT_ACCOUNT)」 | AC1 の truncate 幅 = **100**（確定値） |
| #39 呼び出し側 | `GlobalExceptionHandler.java:106,113` が `request.getRequestURI()` を無検証で渡す（`handleAccessDenied` / `handleAuthentication`）。他2箇所は `AuditingAccessDeniedHandler` / `AuditingAuthenticationEntryPoint` | **計4経路**。truncate は `AuditLogRecorder` 側（AC1）で一元化 |
| #39 `AuditLogRecorder.insert` | `mapper.insert(entity)` を try なしで呼ぶ（`AuditLogRecorder.java:103`）。例外はそのまま呼び出し元＝セキュリティハンドラへ伝播 | AC2 の best-effort 化は**未実装**（新規） |
| #40 `GlobalExceptionHandler` | 既存ハンドラ 15 種を確認。**`DataIntegrityViolationException` 専用ハンドラは不在**（`@ExceptionHandler(Exception.class)` の catch-all が 500 に丸める） | AC4 は新規追加。`backend-conventions §9` の catch-all 棚卸しチェックリストに沿う |
| #41 `AuthApplicationService.login` | `@Transactional` なし。`assertNotLocked`(SELECT) → `authenticate`(bcrypt) → catch 内 `recordFailure` の順（`AuthApplicationService.java:64-77`）。相互排他なし | check-then-act を実コードで確認。Q2 方式で是正 |
| #41 mapper | `LoginAttemptCustomMapper.recordFailure` / `RegisterAttemptCustomMapper.recordAttempt` とも `INSERT..ODKU` 単文アトミック・**戻り値は affected rows のみで閾値到達可否を返さない** | 条件付き UPDATE で「枠確保の可否」を affected rows として返す設計へ |
| #41 スキーマ | `t_login_attempt`（PK=username）・`t_register_attempt`（PK=client_ip）とも Q2 方式に必要な列を既に保持 | **database 変更不要**を確認 |
| 残置データ | `docker exec dev-jpetstore-db mysql ... SELECT` で XSS ペイロード残置を実測 | Q4 のとおり単発 UPDATE で解消 |

---

## リスク・チャレンジ

### リスク

- **R1: #38 は破壊的変更**。修正後、`.env.example` をコピーしただけの `.env` では **backend が起動しなくなる**。README（AC4）更新は必須 AC であり、**Sprint Review でユーザーが実機起動する際に影響する**。DEV は完了報告時に「ローカル `.env` の `JWT_SECRET` を `openssl rand -base64 32` で生成した値へ差し替える必要がある／既に差し替え済みなら追加作業なし」を明記すること（作業ツリーの `.env` は L3 PoC 後にローテート済みだが、denylist に `changeme` 等の弱リテラルも入るため要確認）。
- **R2: #41 は並行制御の変更**で、**認証の中心経路（login）に手を入れる**。AC4（窓リセット意味論・SET 句左→右評価依存）・AC3（列挙耐性）・AC-neg3（既存 Spec/IT が green のまま）という「壊してはいけない既存仕様」が3つ明示されている。**過去に IT で「閾値判定が1回分ずれる」不具合が実際に発覚している箇所**なので、既存 `LoginAttemptServiceSpec` / `RegisterAttemptServiceSpec` / 関連 IT を退行ガードとして先に green 確認してから着手する。
- **R3: #39 の cross-repo 化**（Q1 で確定）。`jpetstore-database` に Flyway を追加するため、backend 側で `./gradlew syncTestSchema` により test resources が同期済であることを確認する（Sprint 3/4 で確立した cross-repo 手順）。
- **R4: 監査系2件（#39/#40）の変更が近接**。`AuditLogRecorder` は #39（truncate・best-effort・quota）と #40（失敗監査の拡張）の両方から触られる。**Issue 単位でコミットを分ける**こと（reviewer が Issue 別に変更ファイルを追える形にする）。
- **R5: スキーマ変更 Story の dev-seed drift**（Sprint 19 で Sprint Review 指摘として実際に発生）。#39 で新表を追加するため、**DoD に「ローカル dev スタックで flywayMigrate + seed 投入まで実機確認」を含める**。自動テスト（Testcontainers）は `flyway/sql-test` の `R__` を通らないため、この盲点は自動テストでは拾えない。

### チャレンジ

- **C1: PoC → 回帰テストの変換を「成果物」として明示する**。本スプリントの主眼は「SEC が手で実証したものを CI で守れる形に落とす」こと。各否定AC のテストに **L3 finding-key（N1〜N4・N11・N14）を javadoc/テスト名で紐付け**、Sprint Review で「L3 の何番がどのテストになったか」を対応表で示せるようにする。
- **C2: #41 の並列バースト回帰テスト**。SEC が「稼働機へのブルートフォース様送信」を理由に**自粛したライブ PoC**（§3 残件1）を、Testcontainers 実 DB + `ExecutorService` + `CountDownLatch` の統合テストとして**テスト資産に置き換える**（Sprint 11 の `OrderConcurrencyIntegrationSpec`・Sprint 16 の version lock 並行テストで確立した技法の再利用）。成功すれば L3 §3 残件1 が閉じる。
- **C3: 既存先例の無改造再利用**。`t_audit_write_quota`（#39）は `t_login_attempt` / `t_register_attempt` の DDL・mapper・service を**そのままテンプレート化**できるはず。新規発明を避け、D7 判例のパターン踏襲で通せるかを検証する。

---

## reviewer 起動時に明示する「意図的な設計」（churn 防止・Sprint 10 昇格ルール）

以下は **計画フェーズで確定した意図的な設計判断**であり、reviewer は「欠落」として指摘しないこと。

- `.env.example` の `JWT_SECRET` **値は変更しない**（#38 改修方針2・PO判断）。denylist で実運用不能化することで根本原因を解消する。将来値を変えても**過去に配布した値を denylist から削除しない**。
- `.env.example` の **DB 資格情報（`DB_USERNAME`/`DB_PASSWORD`＝`jpetstore`）は対象外**（#38 スコープ境界・#43(C)(E) で扱う）。
- **本番デプロイでの実秘密注入の運用確認は AC 化しない**（本プロジェクトに本番デプロイ基盤が存在せず DoD で検証不能・README 記載に留める＝#38 AC4）。
- `t_audit_log.action` を **「操作名」に戻して生 URI を `detail` へ移す是正は行わない**（#39 改修方針4・PO判断）。最小変更（truncate）を選択。DDL 想定と呼び出し側の乖離は技術的負債として記録済み。
- `AuditLogRecorder.client_ip` の **`X-Forwarded-For` 不信頼は現行仕様**（javadoc に明記済み・信頼プロキシ構成が無いため）。#39 で変更しない。
- **`t_order` のスキーマは変更しない**（#40 依存関係・DTO 側を列幅に合わせる方向で解決）。
- 空カート確定時の 409、在庫不足時の 409＋FAILURE 監査は **変更しない**（#8/Sprint11 決定・#40 既存挙動の維持）。
- レート制限の **キー粒度（per-username / per-IP）と閾値（5回／15分）は見直さない**（#41 スコープ境界・per-IP 併用は Sprint4 #20 で明示的に見送り済み）。
- **refresh トークンの失効／ローテーション欠如は設計判断**（台帳＋javadoc で明示済み・SEC も §2.2 で「新規所見にしない」と判定）。本スプリントで扱わない。
- **frontend は一切変更しない**。`languagePreference` の allowlist（`@Pattern`）付与も本スプリント対象外（#44(B)）。
- 以下の L3 所見は**本スプリント対象外**（別 Issue に割当済み）: N5 ログインエラー正規化ギャップ／N7 ページング int オーバーフロー／N15 メディアタイプ非正規化 → **#42**。N6 demo エンドポイント／N8 Swagger 公開／N9 生成ツール creds／N16 DB 権限 → **#43**。N10 状態変更監査の網羅性／N12 languagePreference allowlist → **#44**。CSP/HSTS → **#45**。N13 `?_csrf=` 受理 → 未割当（Low・据え置き）。

---

## Definition of Done（本スプリント固有の追加分）

通常の DoD（`developer-workflow`）に加えて:

1. **全否定AC が自動テストとして green**（#38 AC-neg1/neg2 ＋ L3 PoC 名指し Spec、#39 AC-neg1〜3、#40 AC-neg1〜3、#41 AC-neg1〜3）。
2. **既存テストが全て green**（特に `LoginAttemptServiceSpec` / `RegisterAttemptServiceSpec` / `AuditLogRecorderSpec` / `AuditingAccessDeniedHandlerSpec` / `AuditingAuthenticationEntryPointSpec` / `GlobalExceptionHandlerSpec` / `OrderConcurrencyIntegrationSpec`）。#41 AC-neg3・#40 AC-neg3 の受入条件。
3. **実機起動確認**: `.env` の `JWT_SECRET` を正当な乱数値にした状態で `bootRun` が起動し、`/api/ping`・`/actuator/health` が 200。**加えて placeholder 値では起動しないことを実機で1回確認**（AC-neg1 の実機裏取り）。
4. **dev スタックでの Flyway + seed 実機確認**（#39 の `V00_000_014` 追加に伴う。R5 対策）: `flywayMigrate` 成功 → `flyway/sql-test` の seed 投入成功 → backend 起動 → demo_user ログイン 200。
5. **L3 finding → テスト 対応表**を実装ノート（`backlog/sprint_20/implementation-notes.md`）に残す（C1）。
6. **残置データ解消の実行報告**（Q4・`#20-sprint` 作業スレッド）。
7. `./gradlew spotlessApply` 実行済み（コミット前必須作業）。

---

## 対象 Issue の全文（GitHub Issue Body 転記）

以下は `ryokkon624/jpetstore-manage` の Issue Body をそのまま転記したもの。**AC だけでなく背景・原因・改修方針・スコープ境界まで読むこと。**


---

### Issue #38: [SEC][L3][Critical] JWT署名鍵が公開のplaceholder値で稼働し、資格情報なしで任意ユーザ/ADMINのトークンを偽造できる

- **URL**: https://github.com/ryokkon624/jpetstore-manage/issues/38
- **ラベル**: bug / security
- **ブランチ**: `fix/38-l3-security-fixes (backend)`
- **コミット Issue 参照**: `(ryokkon624/jpetstore-manage#38)`

#### 発生事象

稼働中の backend が、**git 追跡下の `.env.example` に平文で書かれた placeholder 秘密鍵**で JWT を署名・検証していた。起動時の fail-fast 検証（`JwtProperties`）は**鍵長(≥32byte)しか見ない**ため、公開既知の placeholder 値でも起動してしまう。README の手順が「`.env.example` を `.env` にコピー」であり、作業ツリーの `.env` はバイト単位で同一のままだった。

その結果、**リポジトリを見られる誰でも、資格情報なしに任意ユーザ／任意ロールの有効な JWT を偽造できる**状態だった。

#### ライブPoC（SEC 実測）

既知鍵 `please-replace-with-a-random-secret-of-at-least-32-bytes` で HS384 署名した偽造トークン:

- `sub=1, username=ac_neg1_user, roles=[USER], typ=access` → `GET /api/auth/me` **200** / `GET /api/account/me` **200**（他人PII: 氏名・email・電話・住所を取得）＝**資格情報なしのなりすまし**。
- `sub=9999, username=attacker, roles=["ADMIN"], typ=access` → ADMIN限定 `@PreAuthorize("hasRole('ADMIN')")` の `GET /api/secured/ping` → **200**＝**ADMINロール捏造（垂直昇格）**。
- 対照: **別の秘密鍵**で署名したトークン → **401**（＝署名検証は正しく動作。根因は鍵が公開されていること）。

#### 現時点の状態（2026-08-19 Refinement で実コード確認）

- 作業ツリーの `.env` は既に乱数値へローテート済み（mtime 2026-08-19 21:52＝PoC 実施後。`.gitignore` 対象で未追跡）。**稼働面の即時是正は完了済み**。
- 一方、**コード／リポジトリ側の欠陥は未修正のまま**（`JwtProperties` の fail-fast は鍵長のみ／`.env.example` は placeholder のまま／README はコピー導線のまま）。本Issueはこの**恒久対策**を対象とする。

#### ユーザーストーリー

**As a** JPetStore のサイト運営者（および利用者）
**I want to** 出荷されている手順どおりに backend を起動した場合、JWT 署名鍵が必ず「秘密の値」であることを起動時に強制されるようにしたい
**So that** リポジトリを読めるだけの第三者が、資格情報なしに任意ユーザ・任意ロール（ADMIN）の JWT を偽造して他人のPII閲覧や垂直昇格を行うことを、構造的に不可能にできる

#### トレース

- **横断NFR**: `spec/security-baseline.md` SBD-11（秘密管理）。関連 SBD-4（認証状態管理）
- **意図差分台帳**: `spec/intended-diff-ledger.md` ID-25（認証情報をソースに平文 → シークレットストア／関連Story #23・#24）の未達部分。あわせて §補足の維持項目「ソース内に実効的秘密なし」への未達
- **§1 回帰判定への影響**: `reports/after/l3-security-regression-backend.md` §1 **S17**（Axis 管理PW をソースに平文）は「**消滅**（秘密は環境変数注入〔fail-fast〕でソース非保持）」と判定され、根拠に `JwtProperties.java:25-41` と「ソースに平文 admin PW 0件」が挙げられている。本件は、**git 追跡下の `.env.example` が実運用可能な署名鍵を保持しており fail-fast がそれを通す**ことを示し、S17 の「ソース非保持」判定を毀損する。あわせて §2.3「JWT の署名検証／typ 混同／Cookie属性…はいずれも clean」という判定も、鍵が公開されている限り実効防御としては無効化される（同§が注記済み）。
- **実装元**: #23（backend アーキ土台。AC5/AC-neg1 で `JwtProperties` の fail-fast を実装）
- **由来**: Phase 4 L3 セキュリティ回帰 N1（`reports/after/l3-security-regression-backend.md` §2.1）

#### Acceptance Criteria

- [x] AC1: `JwtProperties` の起動時検証に**既知 placeholder 値の denylist** を追加し、一致する `JWT_SECRET` では ApplicationContext の起動が失敗する（fail-fast）。denylist には最低限、現在 `.env.example` が配布している `please-replace-with-a-random-secret-of-at-least-32-bytes` を**恒久的に**含める。判定は前後空白除去・大文字小文字非依存の完全一致とし、`changeme` / `change-me` / `secret` / `password` 等の弱いリテラルも併せて拒否する。
- [x] AC2: AC1 の補助として最小エントロピー要件を課し、**ユニーク文字数が24未満**の `JWT_SECRET` では起動しない。既存の最小鍵長（32byte）検証は維持し、これに追加する。（根拠＝Refinement 時の実測: 現 placeholder はユニーク21種／3.88 bit·char⁻¹、`openssl rand -base64 32` はユニーク約32種／4.87 bit·char⁻¹。エントロピー単独では両者の弁別が薄いため、denylist を主・本ACを補助と位置づける）
- [x] AC3: 起動失敗時の例外メッセージに**秘密の値そのものを含めず**、対処方法（`openssl rand -base64 32` 等で生成し直す旨）を示す。
- [x] AC4: `jpetstore-backend/README.md` の秘密管理節を更新し、「`.env.example` の `JWT_SECRET` はダミーであり**その値のままでは起動しない**。必ず `openssl rand -base64 32` 等で生成した値へ差し替える」ことを必須手順として明記する。あわせて本番デプロイでは実秘密を環境変数／シークレットストアから注入する旨も記載する（**運用そのものの確認は本ACの検証対象外**。下記スコープ境界を参照）。
- [x] AC-neg1（否定AC）: `.env.example` に記載された `JWT_SECRET` の値をそのまま設定した状態では backend が起動しない（回帰テストで固定。SEC のライブPoC の回帰テスト化に相当）。
- [x] AC-neg2（否定AC）: ユニーク文字数24未満の値（例: `a` の40文字反復）では起動しない。一方、`openssl rand -base64 32` 相当の値（32byte以上・ユニーク文字数24以上）では正常に起動する（正当な鍵を誤って拒否しないことの確認）。

#### 原因

- `infrastructure/security/JwtProperties.java:19,30-37` — fail-fast が最小鍵長（`MIN_SECRET_BYTES = 32`）のみを検証し、既知／placeholder 値を弾かない。
- `.env.example:16`（**git 追跡下**）に、32byte 超で「そのまま実運用可能」な placeholder（56byte）を同梱している。
- `README.md:54` が「`.env.example` を `.env` にコピーして値を設定する」という導線で、値の差し替えを強制していない。

#### 改修方針

1. **`JwtProperties` の fail-fast 強化**（AC1〜AC3）: 既存の鍵長検証に、denylist（主）＋ユニーク文字数下限（補助）を追加する。
2. **`.env.example` は現状維持**（PO判断・2026-08-19）: 値を変更せず据え置く。AC1 の denylist に当該値を恒久的に含めることで「コピーしただけでは起動しない」＝**実運用不能化**され、SEC が根本原因に挙げた「実運用可能な placeholder の同梱」は解消される。将来 `.env.example` の値を変更する場合も、**過去に配布した値を denylist から削除しない**こと（既存の `.env` コピーが黙って残り続けるため）。
3. **README 更新**（AC4）: 秘密管理節に必須手順として明記する。
4. **回帰テスト**（AC-neg1/AC-neg2）: `JwtPropertiesSpec` に追加する。なお同 Spec の javadoc が参照する `SecretFailFastSpec` は**実在しない宙吊り参照**のため、本対応時に併せて是正する。

#### 備考

- **優先順位の根拠**: L3 セキュリティ回帰で唯一の Critical（as-run）。稼働面の鍵は既にローテート済みで急性の危険は解消しているが、出荷される dev/デモ手順そのものが完全な認証バイパス状態であり、secure-by-default 主張（SBD-11）の根幹に関わる。他の SEC 所見（#39〜#45）より優先する。また #43(A) の ADMIN 限定 `/api/secured/ping` への到達は本Issueの ADMIN ロール偽造と連鎖するため、本Issueの解消で当該連鎖経路も断たれる。
- **依存関係**: なし（`jpetstore-backend` 単一リポジトリで完結。cross-repo 変更なし）。
- **スコープ境界**:
  - **対象**: `JWT_SECRET` の起動時検証強化・README 導線是正・回帰テスト。
  - **対象外(1)**: `.env.example` の DB 資格情報（`DB_USERNAME`/`DB_PASSWORD`＝`jpetstore`）。`jpetstore-database` の docker-compose 公開既定値であり、JWT 鍵と異なりトークン偽造には使えない。秘密衛生としては **#43(C)（生成ツール同梱 creds）・#43(E)（DB 権限分離）** で扱う。
  - **対象外(2)**: 本番デプロイでの実秘密注入の運用確認（ops）。本プロジェクトに本番デプロイ基盤が存在せず DoD で検証できないため、AC 化せず README 記載（AC4）に留める（PO判断・2026-08-19）。
- **既存機構での充足済み事項（新規実装不要）**: SEC の想定AC にあった「別の秘密鍵で署名した偽造トークン → 401」「`roles` 偽造 → 401」は、いずれも「鍵が秘密である限り署名検証が正しく動く」ことの再確認であり、既存テストで既達。`JwtServiceSpec` の「異なる鍵で署名されたトークンはparseAccessTokenで空を返す」「改ざんされたトークンはparseAccessTokenで空を返す」、および `JwtAuthenticationFilterSpec` の「改ざんされたaccess tokenのCookieならSecurityContextに何もセットせずchainを継続する」が該当する。**本Issueでは新規追加しない**。
- **実コード裏取り**（2026-08-19 Refinement・PO実施）: `JwtProperties.java:19,30-37`／`.env.example:16`（tracked）／`README.md:52,54`／`.env`（`.gitignore` 対象・ローテート済）／`JwtPropertiesSpec`（鍵長検証のみ）／`JwtServiceSpec`・`JwtAuthenticationFilterSpec`（別鍵・改ざんは既達）を確認済み。
- **意図差分台帳**: ID-25 の関連Story へ本Issueを追加する要否は Sprint 20 Retro で判定する（本Issueは新規の「旧→新」挙動差分ではなく、既存宣言〔ID-25／SBD-11〕の未達是正のため、新規ID起票は不要と見込む）。
- **出典**: `reports/after/l3-security-regression-backend.md` §2.1 N1（SEC・run `security/20260819_01`）。修正は DEV が TDD で行う。


---

### Issue #39: [SEC][L3][Medium] 過大長URIで認可失敗の監査記録が消え、403が401に化ける（監査抑止）

- **URL**: https://github.com/ryokkon624/jpetstore-manage/issues/39
- **ラベル**: bug / security
- **ブランチ**: `fix/38-l3-security-fixes (backend + database)`
- **コミット Issue 参照**: `(ryokkon624/jpetstore-manage#39)`

#### 発生事象

`AuditLogRecorder.recordAuthzFailure` が `request.getRequestURI()` を**長さ検証なしで** `t_audit_log.action VARCHAR(100)` に INSERT する。URI が **101文字以上**だと `Data too long` で INSERT が例外→**セキュリティハンドラ（AccessDeniedHandler / AuthenticationEntryPoint / GlobalExceptionHandler）内から例外送出**→`/error` への ERROR ディスパッチ（JWTフィルタ非適用）に落ちる。

結果、**403 が 401 に化け、本来の AUTHZ_FAILURE 監査行（実行者・対象URI）が残らない**。認証済み攻撃者は URI を伸ばすだけで**自分の認可失敗の監査を任意に握り潰せる**。

#### ライブPoC（SEC 実測）

- `GET /api/orders/909090909`（21字, demo_user）→ **403**・監査行 `actor=demo_user, action=/api/orders/909090909, DENIED`（正常）。
- `GET /api/orders/<81×'0'>909090909`（102字, 意味的に同一）→ **401**・監査行は `actor=NULL, action=/error, DENIED`（**誰が/何を が両方消失**）。
- 境界は列幅(100)と厳密一致（100=記録OK / 101=消失）。`orderId` は `Long` なので先頭ゼロ埋めで URI 長を自由に伸ばせる。未認証でも成立。

#### 併合した所見（N14・未認証監査 write の増幅）

未認証リクエスト1件ごとに監査ログ1行を INSERT するがレート制限が無く、監査表フラッド（上記 N2 と連鎖して `/error` 行での埋め尽くし）が成立する（`AuditingAuthenticationEntryPoint`）。同一の監査 write 経路の問題であり、**本Issueに併合する**（PO判断・2026-08-19。SEC 所見 N14 は起票時どのIssueにも収容されていなかった）。

#### 現時点の状態（2026-08-19 Refinement で実コード確認）

- `t_audit_log.action VARCHAR(100) NOT NULL`（`jpetstore-database/flyway/sql/V00_000_006__create_audit_log.sql`）。DDL コメントは「操作(例: ORDER_CREATE, LOGIN, EDIT_ACCOUNT)」＝**本来は操作名を入れる想定の列**。
- 生 URI を渡しているのは3箇所: `AuditingAccessDeniedHandler.java:39-40` ／ `AuditingAuthenticationEntryPoint.java:40-41` ／ `GlobalExceptionHandler.java:106,113`。
- 一方、単体テスト `AuditLogRecorderSpec` は `"SecuredPingController#ping"`（操作名）を渡しており、**列設計・テスト側の想定と本番呼び出し側が乖離**している。
- `AuditLogRecorder.insert`（`AuditLogRecorder.java:84-104`）は例外を一切ハンドルせず、呼び出し元（＝セキュリティハンドラ）へそのまま伝播する。

#### ユーザーストーリー

**As a** サイト運営者（監査証跡の利用者）
**I want to** 認可失敗の監査記録がリクエスト内容によらず必ず「誰が／何を／結果」で残り、かつ監査記録の失敗が応答そのものを壊さないようにしたい
**So that** 攻撃者が URI を細工して自分の認可失敗の痕跡を消したり、本来 403 の応答を 401 に化けさせて検知を回避したりできない

#### トレース

- **横断NFR**: `spec/security-baseline.md` SBD-14（監査ログ＝認可失敗と状態変更を「誰が/何を/結果」で記録）・SBD-10（エラー処理・4xx 正規化）
- **意図差分台帳**: 本件は台帳掲載の意図差分では**ない**。SBD-14 で宣言済みの挙動に対する**実装の未達**であり、`verification-strategy.md` §4「台帳に無い差分＝要調査（欠陥候補）」に該当する。台帳への新規 ID 追記は不要。
- **§1 回帰判定への影響**: `reports/after/l3-security-regression-backend.md` §1 **S15**（無認証 `getOrder` による全顧客 PII 総当り）の「消滅＋是正」判定は、ライブPoC 証跡の一部として「監査ログ: `t_audit_log` に AUTHZ_FAILURE / actor=demo_user / result=DENIED を記録（SBD-14）」を挙げている。本件はその証跡を攻撃者が任意に消せることを示し、**S15 判定のうち「監査による検知」部分を毀損する**。
- **実装元**: #23（AC7・監査記録機構）／#21（認可失敗の記録結線）
- **由来**: Phase 4 L3 **N2**（`backend:audit:authz-failure-suppression-via-long-uri`）＋ **N14**（`backend:audit:unauthenticated-write-amplification`）

#### Acceptance Criteria

- [x] AC1: `AuditLogRecorder` が `action` へ入れる値を、INSERT 前に `t_audit_log.action` の列幅（**100文字**）以内へ truncate する。truncate は**先頭側を保持**する（URI の先頭100文字が残る）。
- [x] AC2: **監査記録の失敗を呼び出し元へ伝播させない**（best-effort 化）。`AuditLogRecorder` の記録系メソッドは内部で例外を捕捉し、アプリケーションログに ERROR として残したうえで正常復帰する。これによりセキュリティハンドラ（`AuditingAccessDeniedHandler` / `AuditingAuthenticationEntryPoint` / `GlobalExceptionHandler`）内からの例外送出と `/error` への ERROR ディスパッチが発生しない。**記録失敗を黙って捨てないこと**（ログには必ず残す）。
- [x] AC3: 未認証リクエスト由来の監査 write に濫用抑止を設ける（N14）。同一 `client_ip` からの `AUTHZ_FAILURE` 記録を**一定窓内で上限付き**にする（集約または間引き）。上限値・窓・保持方式は、既存の `t_login_attempt` / `t_register_attempt`（`spec/architecture-conventions.md` **D7**＝secure-by-default 系カウンタは DB-backed）と整合する形で DEV が提案し、**計画フェーズで確定する**。抑止が発生した事実自体は記録またはログに残す（黙って消えないこと）。
- [x] AC-neg1（否定AC）: **200文字級の URI** での認可失敗（例: 認証済みユーザによる他人注文の参照）→ **403** が返り、`actor`（実行者）と `action`（対象URI の先頭100文字）を含む `AUTHZ_FAILURE` / `DENIED` 行が残る。401 に化けず、`actor=NULL` かつ `action='/error'` の行にはならない（**L3 ライブPoC の回帰テスト化**）。
- [x] AC-neg2（否定AC）: 監査 INSERT が失敗する状況（例: mapper が例外を投げるようスタブ）でも、認可失敗の応答は本来のステータス（403／401）と本来の `ErrorResponse` ボディで返る。
- [x] AC-neg3（否定AC）: 未認証リクエストを AC3 の上限を超えて連続送出しても、`t_audit_log` の行数が上限相当で頭打ちになる。

#### 原因

- `infrastructure/audit/AuditLogRecorder.java:49-60,84-104` — `action` を列幅検証なしで INSERT し、INSERT 例外を一切ハンドルせず呼び出し元へ伝播する。
- `t_audit_log.action VARCHAR(100) NOT NULL`（`V00_000_006__create_audit_log.sql`）に対し、呼び出し側3箇所（`AuditingAccessDeniedHandler.java:39-40` / `AuditingAuthenticationEntryPoint.java:40-41` / `GlobalExceptionHandler.java:106,113`）が長さ無制限の `request.getRequestURI()` を渡す。
- 監査 INSERT がレスポンス生成の**前**に、例外保護なしでセキュリティハンドラ内から実行される。

#### 改修方針

1. **truncate**（AC1）: 列幅内へ切り詰めて「そもそも溢れさせない」を主対策とする。
2. **best-effort 化**（AC2）: 保険として、記録失敗が応答経路を壊さないようにする。ただし SBD-14「記録する」宣言に対する後退を最小化するため、**握り潰して黙るのではなくアプリログへ ERROR で残す**。
3. **未認証 write の上限**（AC3）: 保持方式は D7（DB-backed）との整合を計画フェーズで確定する。
4. **`action` 列の意味づけ是正（操作名へ戻し生URIは `detail` へ移す）は本Issueでは行わない**（PO判断・2026-08-19）。3ハンドラ＋ handler spec 群の改修と §1 S15 証跡形式の変更を伴うため、最小変更（truncate）を選択した。乖離自体は下記の技術的負債として記録する。

#### 備考

- **優先順位の根拠**: Medium。データ漏えいは無く SBD-8（not-owned ≡ not-found）も維持されるが、破壊されるのは**監査の完全性（SBD-14）と 4xx 正規化（SBD-10）**であり、かつ §1 S15 の回帰判定根拠を毀損する。Phase 4 の合否ゲート（L3）の確からしさに直結するため、他の Low 束（#42〜#45）より優先する。
- **依存関係**: 基本は `jpetstore-backend` 単一で完結。ただし **AC3 の保持方式が DB-backed カウンタになる場合は cross-repo（`jpetstore-database` に Flyway 追加）となる**ため、計画フェーズで方式とあわせて確定する。
- **スコープ境界**:
  - **対象**: 認可失敗監査（`recordAuthzFailure`）の記録経路の堅牢化（truncate・best-effort）＋未認証 write の抑止。
  - **対象外(1)**: 状態変更監査の**呼び出し漏れ**（account 編集・PW 変更・登録・ログイン成功が `recordStateChange` を呼んでいない）＝ **#44(A)**。本Issueは「記録経路の堅牢性」、#44(A) は「記録箇所の網羅性」で別軸。
  - **対象外(2)**: 注文確定失敗の監査欠落（ID-22 未達）＝ **#40**。
  - **対象外(3)**: `AuditLogRecorder` の `client_ip` が `X-Forwarded-For` を意図的に不信頼としている件は現行仕様（同クラス javadoc に明記済み・信頼プロキシ構成が無いため）。本Issueで変更しない。
- **技術的負債（本Issue対象外・記録のみ）**: `t_audit_log.action` は DDL 上「操作名」を入れる列だが、本番の3ハンドラは生 URI を渡しており、`AuditLogRecorderSpec` の想定（`"SecuredPingController#ping"`）と乖離している。将来の監査ログ整理時に是正要否を判断する。
- **実コード裏取り**（2026-08-19 Refinement・PO実施）: `AuditLogRecorder.java:49-60,84-104` ／ `V00_000_006__create_audit_log.sql`（`action VARCHAR(100) NOT NULL`）／ 呼び出し3箇所 ／ `AuditLogRecorderSpec`・`AuditingAccessDeniedHandlerSpec`・`AuditingAuthenticationEntryPointSpec`・`GlobalExceptionHandlerSpec`（`action` 期待値の形）を確認済み。
- **出典**: `reports/after/l3-security-regression-backend.md` §2.1 N2・N14（SEC・run `security/20260819_01`）。修正は DEV が TDD で行い、PoC を回帰テスト化する。


---

### Issue #40: [SEC][L3][Medium] 注文確定の失敗が監査に残らず500になる（入力制約欠落・ID-22未達）

- **URL**: https://github.com/ryokkon624/jpetstore-manage/issues/40
- **ラベル**: bug / security
- **ブランチ**: `fix/38-l3-security-fixes (backend)`
- **コミット Issue 参照**: `(ryokkon624/jpetstore-manage#40)`

#### 発生事象

`OrderApplicationService.placeOrder` の `catch` は `InsufficientStockException` のみを捕捉し、失敗監査（`recordStateChangeIndependently` / `result=FAILURE`）を記録する。**それ以外の失敗（DB 例外等）は `ORDER_CREATE` の監査行が一切残らない**。成功時の `recordStateChange` は主トランザクション内のため失敗時はロールバックされ、結果として**監査ゼロ**になる。

これは **ID-22「注文作成は成功・失敗いずれも `ORDER_CREATE` として記録し、失敗時は `result=FAILURE`」に正面から反する**。

#### トリガー（入力制約欠落）

`OrderController.OrderAddressRequest` は他 DTO と異なり `@Size` が皆無。`t_order` の該当列は VARCHAR(20)〜(80)。SEC スキャナ実測: **postalCode 40文字**で `POST /api/orders` → **500・監査行ゼロ**。成功時は正しく記録される（対照確認済み）。

#### Refinement の実コード裏取りで新規に発見した事実（SEC 報告に無い）

`PlaceOrderRequest` の `shipping` に **`@Valid` が付いていない**（`billing` は `@NotNull @Valid`、`shipping` は素の `OrderAddressRequest`）。Bean Validation はネストした record へ `@Valid` 無しではカスケードしないため、**`useSeparateShipping=true` のとき shipping の各項目は `@NotBlank` すら適用されない**。空値・欠落のまま NOT NULL 列（`ship_address1` 等）へ到達し、`@Size` 欠落と同じ「500＋監査ゼロ」経路に落ちる。`@Size` 付与だけでは塞がらないため、本Issueのスコープに含める。

#### ユーザーストーリー

**As a** サイト運営者
**I want to** 注文確定が失敗した場合も必ず `ORDER_CREATE` / `result=FAILURE` として監査に残り、かつ入力起因の失敗は 4xx で返るようにしたい
**So that** ID-22 の宣言どおり注文作成の成否を完全に追跡でき、攻撃者が長大な住所を送るだけで注文失敗の痕跡を消したり 500 を誘発したりできない

#### トレース

- **意図差分台帳**: **ID-22**「固定プレースホルダ・状態変更は監査ログに記録（注文作成は成功・失敗いずれも `ORDER_CREATE` イベントとして記録し、失敗時は `result=FAILURE`）」。本件は台帳掲載の意図差分では**なく、台帳宣言に対する実装の未達**（`verification-strategy.md` §4「台帳に無い差分＝要調査＝欠陥候補」）。台帳への新規 ID 追記は不要。
- **横断NFR**: `spec/security-baseline.md` SBD-14（監査ログ）・SBD-2（allowlist バインド／長さ制約）・SBD-10（エラー正規化＝不正入力は正規化した 4xx へ）
- **実装元**: #8（注文確定・AC6 で失敗監査を実装）
- **由来**: Phase 4 L3 **N3**（`backend:audit:order-create-failure-unrecorded`）＋ **N11**（`backend:input:missing-size-constraints-500`・order 側）

#### Acceptance Criteria

- [x] AC1: `OrderApplicationService.placeOrder` の失敗監査を `InsufficientStockException` 以外の失敗にも広げ、**注文確定が失敗した場合は必ず** `ORDER_CREATE` / `result=FAILURE` を記録する。記録は現行方式（`AuditLogRecorder#recordStateChangeIndependently`・`@Transactional(REQUIRES_NEW)`）を踏襲し、主トランザクションのロールバックに巻き込まれないようにする。
- [x] AC2: `OrderAddressRequest` の各項目に `t_order` の列幅と整合する `@Size` を付与する。確定値（`V00_000_005__create_order_tables.sql` 実測）: `firstName`／`lastName`／`address1`／`address2`／`city`／`state` = **max 80**、`postalCode`／`country` = **max 20**。超過長は **400** に正規化される（Bean Validation → 400 の既存先例に揃える）。
- [x] AC3: `PlaceOrderRequest.shipping` に `@Valid` を付与し、`useSeparateShipping=true` のとき shipping の各項目にも billing と同一の検証（`@NotBlank` ＋ AC2 の `@Size`）が適用される。
- [x] AC4: `DataIntegrityViolationException` を 4xx（**400**）へ正規化するグローバル例外ハンドラを新設する。AC2/AC3 の入口検証を通過した想定外の DB 制約違反でも 500 を返さない。**#42(D)（`favoriteCategoryId` の実在検証欠落による FK 違反 500）は本ハンドラを再利用する**（PO判断・2026-08-19。重複実装を避けるため #42 側にも申し送り済み）。
- [x] AC-neg1（否定AC）: 列幅超過の住所（例 `postalCode` 40文字）での `POST /api/orders` → **400**（500 ではない）。**L3 スキャナ実測 PoC の回帰テスト化**。
- [x] AC-neg2（否定AC）: `useSeparateShipping=true` かつ shipping の必須項目が空／欠落 → **400**（500 ではない）。
- [x] AC-neg3（否定AC）: 注文確定が在庫不足以外の理由で失敗した場合も、`t_audit_log` に `ORDER_CREATE` / `result=FAILURE` の行が 1 件残る（監査ゼロにならないこと）。既存の在庫不足・空カート時の失敗監査（#8 AC6）は挙動不変。

#### 原因

- `application/service/OrderApplicationService.java:127-131` — `catch (InsufficientStockException e)` のみが失敗監査を記録し、他の例外は監査なしで伝播する。成功時の `recordStateChange`（同 121-126 行）は主トランザクション内のため、失敗時はロールバックされて残らない。
- `presentation/rest/OrderController.java:80-88` — `OrderAddressRequest` に `@Size` が皆無（同 repo の `AccountController.java:122-134` は全項目に `@Size` 付与済み＝**同一 backend 内で非対称**）。
- `presentation/rest/OrderController.java:101-104` — `PlaceOrderRequest.shipping` に `@Valid` が無く、ネスト検証がカスケードしない。
- `DataIntegrityViolationException` 専用ハンドラが `GlobalExceptionHandler` に不在で、DB 制約違反が catch-all の 500 に落ちる。

#### 改修方針

1. **失敗監査の拡張**（AC1）: `catch` を広げ、在庫不足以外の失敗でも `REQUIRES_NEW` で FAILURE 監査を記録してから再送出する。既存の在庫不足経路の挙動は変えない。
2. **入口検証の対称化**（AC2/AC3）: `AccountController` の既存 DTO と同じ粒度で `@Size` を付与し、`shipping` に `@Valid` を追加する。
3. **DB 制約違反の 4xx 正規化**（AC4）: `GlobalExceptionHandler` に `DataIntegrityViolationException` ハンドラを新設する。応答は既存 `ErrorResponse` 形式（trace／内部メッセージ非露出＝SBD-10 維持）とし、**DB 由来の生メッセージをそのまま返さない**。
4. 回帰テストで AC-neg1〜3 を固定する。

#### 備考

- **優先順位の根拠**: Medium。データ漏えいは無いが、**ID-22 という台帳の明文宣言に対する未達**であり、Phase 4 の合否ゲート L4（実測差分 ⊆ 台帳）の判定に直接影響する。加えて監査を消せる点で #39 と同系統（監査完全性の毀損）。
- **依存関係**: なし（`jpetstore-backend` 単一リポジトリで完結。`t_order` のスキーマ変更は不要＝ DTO 側を列幅に合わせる方向で解決する）。
- **スコープ境界**:
  - **対象**: 注文確定の失敗監査・注文住所 DTO の入力制約・`DataIntegrityViolationException` の 4xx 正規化ハンドラ新設。
  - **対象外(1)**: `favoriteCategoryId` の実在検証（アカウント側）＝ **#42(D)**。本Issueで新設するハンドラを再利用する前提のため、#42(D) 側は実在検証の要否のみを別途判断する。
  - **対象外(2)**: 状態変更監査の呼び出し漏れ（account 編集・PW 変更・登録・ログイン成功）＝ **#44(A)**。
  - **対象外(3)**: 認可失敗監査の握り潰し＝ **#39**。
  - **対象外(4)**: メディアタイプ不一致（415/406）・ページング int オーバーフローの 500 ＝ **#42(B)(C)**。
- **既存挙動の維持**: 空カート確定時の 409（`InsufficientStockException` 経由・Sprint11 決定）と、在庫不足時の 409＋FAILURE 監査は**変更しない**。AC1 はあくまで「それ以外の失敗も記録する」拡張である。
- **実コード裏取り**（2026-08-19 Refinement・PO実施）: `OrderApplicationService.java:96-133`（catch 範囲・成功監査の tx 位置）／`OrderController.java:80-104`（`@Size` 皆無・`shipping` の `@Valid` 欠落）／`AccountController.java:122-134`（対照＝`@Size` 付与済み）／`V00_000_005__create_order_tables.sql:29-45`（列幅 80/20 の実測値）を確認済み。
- **出典**: `reports/after/l3-security-regression-backend.md` §2.1 N3・N11（SEC・run `security/20260819_01`）。修正は DEV が TDD で行い、PoC を回帰テスト化する。


---

### Issue #41: [SEC][L3][Medium] ログイン/登録のレート制限がcheck-then-actで並行バーストにより回避できる（TOCTOU）

- **URL**: https://github.com/ryokkon624/jpetstore-manage/issues/41
- **ラベル**: bug / security
- **ブランチ**: `fix/38-l3-security-fixes (backend)`
- **コミット Issue 参照**: `(ryokkon624/jpetstore-manage#41)`

#### 発生事象

ログイン／登録のロックアウトが **check-then-act**（相互排他なし）。`AuthApplicationService.login` は `@Transactional` ですらなく、

`assertNotLocked(username)`（SELECT）→ `authenticationManager.authenticate(...)`（bcrypt・数十〜百ms）→ `recordFailure(username)`

の間にロックが無い。並行バーストでは N 本が全て count=0 の状態で `assertNotLocked` を通過し、**全員が `authenticate`（＝パスワード推測）に到達してから** `recordFailure` する。

結果、**1ロック窓（5回/15分）に対し実効で Tomcat スレッド数（既定200）規模の推測が成立**する。カウンタ自体の `INSERT ... ON DUPLICATE KEY UPDATE` はアトミックだが、**穴はゲート側**。

#### 現時点の状態（2026-08-19 Refinement で実コード確認）

- `AuthApplicationService.login`（`AuthApplicationService.java:65-79`）は `@Transactional` なし。`assertNotLocked` → `authenticate` → `catch` 内で `recordFailure` の順。
- `LoginAttemptService.assertNotLocked`（`LoginAttemptService.java:38-42`）は `countActiveLock`（SELECT COUNT）のみで、判定と計数が分離している。
- `LoginAttemptCustomMapper.recordFailure`（`LoginAttemptCustomMapper.java:40-62`）は `INSERT ... ON DUPLICATE KEY UPDATE` の単文アトミックで、**カウンタの取りこぼしは無い**。戻り値は affected rows のみで、閾値到達可否は返さない。
- 登録側 `RegistrationApplicationService.register`（`RegistrationApplicationService.java:67-93`）も同型: `assertNotRateLimited(clientIp)` → 本処理 → `finally { recordAttempt(clientIp) }`。
- 閾値は `application.yml:53-58` の `auth.lockout.max-attempts: 5` ／ `lock-duration: PT15M`（env 上書き可）。

#### ユーザーストーリー

**As a** サイト運営者
**I want to** ログイン／登録のロックアウト閾値が、並行リクエストが同時に来ても実効的に守られるようにしたい
**So that** ID-11／SBD-6 で宣言した「レート制限／ロックアウトあり・総当り抑止」が、並列バーストで実質的に無効化されない

#### トレース

- **意図差分台帳**: **ID-11**「…レート制限／ロックアウト（ログイン=`t_login_attempt`・登録=`t_register_attempt`、いずれも DB-backed。architecture-conventions D7）」。本件は台帳掲載の意図差分では**なく、台帳が宣言した対策の実効性に対する未達**（`verification-strategy.md` §4）。台帳への新規 ID 追記は不要。
- **横断NFR**: `spec/security-baseline.md` **SBD-6**（認証の堅牢化。「Phase 4 回帰テストの種」欄に**総当り抑止**が明記されている）
- **§1 回帰判定への影響**: `reports/after/l3-security-regression-backend.md` §1 **S10**（ブルートフォース対策皆無＋弱い既定資格情報）は「**是正**（DB-backed ロックアウト `t_login_attempt`・max-attempts=5 / lock PT15M）」と判定済み。本件はその閾値が並行バーストで実効的に守られないことを示し、**S10 の「是正」判定の実効性を毀損する**。Phase 4 合否ゲート L3（before の PoC がすべて after で失敗）の確からしさに直結する。
- **実装元**: #20（ログインのレート制限／ロックアウト）／#13（登録レート制限・`t_register_attempt`）
- **由来**: Phase 4 L3 **N4**（`backend:auth:rate-limit-burst-toctou`）

#### Acceptance Criteria

- [x] AC1: ログインのロック判定と失敗計数を、**check-then-act ではない単一のアトミックな操作**に統合する。並行リクエストが同時に到達しても、**資格情報照合（`authenticationManager.authenticate`）に到達する回数が設定閾値（`auth.lockout.max-attempts`）を実質的に超えない**こと。実装方式（条件付き UPDATE によるスロット確保・`SELECT ... FOR UPDATE` でのゲート直列化・`recordFailure` の戻り値による短絡 等）は **DEV 裁量**とする。
- [x] AC2: 登録側（`RegistrationApplicationService.register`・`clientIp` キー・`t_register_attempt`）にも AC1 と同じ方式を適用する。
- [x] AC3: **既存の列挙耐性を維持する**。実在 username と非実在 username で、ロック挙動・応答ボディ・所要時間が区別できないこと（`t_login_attempt` の no-FK 設計、および `assertNotLocked` が誤資格と同一の `BadCredentialsException` を投げる現行仕様を保つ）。
- [x] AC4: **既存のロック窓のリセット意味論を保つ**。ロック期間が経過した後の失敗は新規窓として `failed_attempt_count=1` にリセットされる（`LoginAttemptCustomMapper.recordFailure` が SET 句の左→右評価に依存して閾値判定を行っている点を壊さないこと。過去に IT で発覚した「閾値判定が1回分ずれる」不具合を再発させない）。
- [x] AC-neg1（否定AC）: 閾値を超える **N 本（例: 20並列）の失敗ログイン**を同一 username へ同時送出しても、実際に `authenticate` に到達する回数が**閾値近傍で頭打ち**になり、`t_login_attempt.failed_attempt_count` が閾値を大きく超過しない。**L3 §3 残件1 の未実施ライブ・バーストPoC を、回帰テストとして実装することで代替実証する**。
- [x] AC-neg2（否定AC）: 登録側でも同一 `clientIp` からの並列バーストで同様に頭打ちになる。
- [x] AC-neg3（否定AC）: 単一スレッドでの通常のログイン成功／失敗、ロック発動、ロック解除の既存挙動が変わらない（既存 `LoginAttemptServiceSpec` / `RegisterAttemptServiceSpec` / 関連 IT が green のまま）。

#### 原因

- `application/service/AuthApplicationService.java:65-79` — `login` に相互排他もトランザクションも無く、`assertNotLocked`（SELECT）と `recordFailure`（UPDATE）の間に bcrypt 照合を挟む check-then-act 構造。
- `infrastructure/security/LoginAttemptService.java:38-42` — 判定（`countActiveLock`）と計数（`recordFailure`）が別メソッド・別クエリに分離している。
- `application/service/RegistrationApplicationService.java:67-93` — 登録側も同型（`assertNotRateLimited` → 本処理 → `finally recordAttempt`）。

#### 検証状況

コード解析で **CONFIRMED**（相互排他の不在は自明）。**ライブ・バーストPoC（20並列失敗ログイン）は、稼働機への並列 auth 大量送信＝ブルートフォース様のため SEC が自粛**（`reports/after/l3-security-regression-backend.md` §3 残件1・permission-gated）。→ 本Issueでは AC-neg1 の回帰テストとして実装する（下記備考）。

#### 改修方針

1. **ゲートの原子化**（AC1/AC2）: 「判定してから照合し、後で数える」から「**照合前にスロットを原子的に確保する**」構造へ変える。方式は DEV が既存 mapper の単文アトミック UPDATE 方針と整合する形で選定する。
2. **列挙耐性・窓リセット意味論の保存**（AC3/AC4）: 既存の設計判断（no-FK 対称扱い・SET 句左→右評価による閾値判定）を壊さないことを明示の受入条件とする。
3. **並列回帰テストの追加**（AC-neg1/AC-neg2）: L3 で自粛されたバーストPoC をテスト資産化する。

#### 備考

- **ライブ・バーストPoC の扱い（PO判断・2026-08-19）**: SEC は §3 残件1 で「承認が得られれば 20 並列失敗ログインで経験的に実証可能」としていたが、**AC-neg1 の回帰テスト（並列失敗ログインの統合テスト）が当該 PoC をそのままテスト資産化したものであるため、別途の稼働機ライブPoC は実施しない**。`verification-strategy.md` §1 の L3 定義（before の PoC が after で失敗することを検証する）および「PoC を回帰テストに落とす」運用に沿う。
- **優先順位の根拠**: Medium。単独ではデータ漏えいを起こさないが、§1 S10 の「是正」判定の実効性に直結し、Phase 4 合否ゲート L3 の確からしさに影響する。加えて弱いパスワードのアカウントに対しては実被害（アカウント奪取）につながりうる。
- **依存関係**: なし（`jpetstore-backend` 単一リポジトリで完結する方式を優先する）。**`t_login_attempt` / `t_register_attempt` のスキーマ変更を要する方式を選ぶ場合は cross-repo（`jpetstore-database`）となる**ため、計画フェーズで方式とあわせて確定する。
- **スコープ境界**:
  - **対象**: ゲート（ロック判定→照合→計数）の原子性のみ。ログイン側・登録側の両方。
  - **対象外(1)**: レート制限の**キー粒度**（per-username / per-IP）および**閾値の値**（5回／15分）の見直し。現行 ID-11・`application.yml` の値を維持する。per-IP 併用は Sprint4 #20 で明示的に見送り済みの決定。
  - **対象外(2)**: ログインエラーの正規化ギャップ（`{id}` プレフィックス欠落ハッシュでの 400＋内部メッセージ露出）＝ **#42(A)**。同じログイン経路だが原因も対策も別（例外正規化）。
  - **対象外(3)**: refresh トークンの失効／ローテーション欠如は、台帳＋コード javadoc で明示済みの設計判断であり SEC も「新規所見にしない」と判定済み（§2.2）。本Issueで扱わない。
- **実コード裏取り**（2026-08-19 Refinement・PO実施）: `AuthApplicationService.java:65-79`（`@Transactional` 不在・呼び出し順）／`LoginAttemptService.java:38-56`／`LoginAttemptCustomMapper.java:28-66`（単文アトミック・戻り値は affected rows・SET 句左→右評価の意図的依存）／`RegistrationApplicationService.java:67-93`（同型）／`application.yml:53-58`（max-attempts=5・PT15M）を確認済み。
- **出典**: `reports/after/l3-security-regression-backend.md` §2.1 N4・§3 残件1（SEC・run `security/20260819_01`）。修正は DEV が TDD で行い、自粛されたバーストPoC を回帰テスト化する。
