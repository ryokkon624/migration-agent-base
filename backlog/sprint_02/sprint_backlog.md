# Sprint 2 バックログ

## スプリントゴール

**secure-by-default なバックエンド・アーキ土台（`jpetstore-backend`）を確立する。**
Java 21 / Spring Boot 4.x / MyBatis / 3層（DDDライク）構成の上に、
**JWT httpOnly Cookie 認証・CSRF・正規化エラーハンドリング・監査ログ・並行制御（409統一マッピング / ガード付きアトミック減算 / `@Transactional`）**
の横断基盤を、各ドメイン Story が「設定し忘れても安全（secure-by-default）」な形で整備する。
これは #21（F5.4 認証）・#8（在庫）・#14（account 編集）など後続ドメイン実装の共通土台となる。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | ブランチ |
|-------|---------|-------|----|-----------|---------|
| [#23](https://github.com/ryokkon624/jpetstore-manage/issues/23) | [E6] バックエンド・アーキ土台（Spring Boot 4 / 3層 / Spring Security JWT / CSRF / 監査ログ）を整備する | `foundation` / `E6` | 13 | `jpetstore-backend` | `feature/23-backend-arch-foundation` |

> ブランチはIssue本文に指定がないため SM が命名。scaffold は既に `jpetstore-backend` の **main にコミット済み**（`09ec431`）のため、**新規ブランチ**を切って土台を積む（既存ブランチ継続ではない）。

---

## Issue #23 本文（転記）

### ユーザーストーリー

**As a** 開発チーム
**I want to** secure-by-default なバックエンド基盤を整えたい
**So that** 各ドメインが横断NFRを設定し忘れても安全になる

### トレース

- **Epic**: E6 横断：secure-by-default／基盤（ターゲットアーキ）
- **Feature**: E6 基盤 — バックエンド・アーキ土台
- **spec**: `spec/backlog-map.md`（E6）／`spec/security-baseline.md` 全般／`spec/architecture-conventions.md`（§2 WHO・§4 並行制御）
- **横断NFR**: SBD-1, SBD-3, SBD-4, SBD-10, SBD-11, SBD-12, SBD-14, SBD-15

### Acceptance Criteria

- [x] **AC1**: Java 21 / Spring Boot 4.x / MyBatis / 3層（DDDライク）構成の土台（`jpetstore-backend`）。パッケージ `com.example.jpetstore.backend`。
- [x] **AC2 (SBD-1)**: 認可はサービス/ドメイン層・認証プリンシパル基準・チャネル非依存の基盤（#21 F5.4 と一体）。
- [x] **AC3 (SBD-3/4/15)**: CSRF 基盤・セッション/認証状態管理・JWT httpOnly Cookie＋refresh・Secure/HttpOnly/SameSite Cookie を secure-by-default で提供。
- [x] **AC4 (SBD-10)**: 例外はスタックトレース/内部パス/版数を露出しない正規化エラーハンドリング基盤。
- [x] **AC5 (SBD-11)**: 認証情報・鍵をソースに置かない（環境/シークレットストア）。
- [x] **AC6 (SBD-12)**: 依存は保守された現行版で版固定（EOL排除・レンジ非固定にしない）。
- [x] **AC7 (SBD-14)**: 監査ログ基盤（認可失敗・状態変更）。
- [x] **AC8 (arch §4)**: **並行制御の secure-by-default 基盤**＝(a) 楽観ロック競合（`version` 不一致＝affected rows==0）を **HTTP 409 Conflict に統一マッピング**、(b)「後勝ちで壊れる」更新は **ガード付きアトミック UPDATE ＋ affected-rows 判定** を標準パターンに、(c) 状態変更は `@Transactional` で all-or-nothing・複数行更新は固定順でデッドロック回避。SBD-2（サーバ権威）／SBD-14（監査）と一体。
- [x] **AC-neg1 (否定AC / SBD-11)**: ソースに平文の管理者PW/鍵が含まれない。

### 備考

- 優先順位の根拠: 横断 SBD の secure-by-default 実装土台。
- アーキ根拠: `architecture-conventions` §4（在庫ガード付き減算・version 楽観ロック→409）。#8（在庫）・#14（account 編集）の並行性 AC の実装基盤。
- 依存関係: #22（E6.1・**完了済み**）。テスト方針＝Groovy＋Spock。

---

## 実装の前提コンテキスト（SM調査メモ）

DEV は計画フェーズで以下を精査すること。

### 既存の状態（`jpetstore-backend` scaffold `09ec431`）

初回雛形が **main にコミット済み**。以下が既に存在する（**壊さず土台を積むのが基本線**）：

| 既存資産 | 内容 | 本スプリントでの扱い |
|---|---|---|
| `build.gradle` | Spring Boot **4.1.0** / Java 21 / MyBatis 4.1.0 / Spring Security / AOP / **jjwt 0.11.5** / springdoc / Spock(Groovy5) / Testcontainers / Flyway(test) / Spotless(google-java-format) | 依存の**版固定・EOL/CVE点検**（AC6）。jjwt 0.11.5 は現行が 0.12.x のため版方針を確認 |
| `config/SecurityConfig.java` | **csrf/formLogin/httpBasic を disable にした雛形**。「TODO(Phase3): JWT httpOnly Cookie 認証導入時に再設計」と明記 | **本スプリントで再設計**（AC2/AC3）。csrf 有効化・JWT フィルタ・stateless セッション |
| `infrastructure/audit/`（`ProgramContext` / `ProgramContextAspect` / `AuditProgramInterceptor`） | **WHO カラム自動付与**（AOP set-once ＋ MyBatis Interceptor）。§2 の「最外の業務サービスが勝つ」実装 | **既存を尊重**。監査ログ基盤（AC7）は WHO と別の「認可失敗・状態変更の記録先」を検討（§2 の WHO＝行レベル監査、SBD-14＝イベント監査の関係を整理） |
| `domain/enums/`（`CodeEnum` / `OrderStatus` / `CardType`）・`tool/EnumGenerator.java` | m_code → Java enum 生成物とジェネレータ | 既存を尊重（本スプリント対象外） |
| `presentation/rest/PingController.java` | `/api/ping` 疎通のみ | **土台のテスト用エンドポイント**として活用可（CSRF/例外/409 のテスト起点） |
| `application.yml` | DB 接続 URL・**user/pass 平文（`jpetstore`/`jpetstore`）**・springdoc・actuator | **秘密管理（AC5/AC-neg1）の主対象**。DB 資格情報・JWT 署名鍵の環境変数化 |

### spec の要点

- **§4 並行制御（`architecture-conventions.md`）**＝AC8 の根拠：
  - 在庫＝ガード付きアトミック減算（`UPDATE ... WHERE qty >= :n`、affected rows==0 で失敗）。`version`/`FOR UPDATE`/リトライ不要。
  - 編集系＝`version` 楽観ロック（`WHERE pk=:id AND version=:readVersion`、affected rows==0 → **409 Conflict**）。
  - 状態変更は `@Transactional` で all-or-nothing、複数行更新は `item_id` 昇順など**固定順でデッドロック回避**。
- **security-baseline.md**（該当 SBD）：
  - SBD-1 認可＝サービス層・プリンシパル基準・チャネル非依存 → AC2
  - SBD-3 CSRF＋非冪等POST / SBD-4 セッション（ログイン成功時ID再生成・ログアウト無効化）/ SBD-15 Cookie に Secure/HttpOnly/SameSite → AC3
  - SBD-10 例外で trace/内部パス/版数を露出しない → AC4
  - SBD-11 秘密をソースに置かない → AC5/AC-neg1
  - SBD-12 保守版・版固定・EOL排除 → AC6
  - SBD-14 監査ログ（認可失敗・状態変更） → AC7
  - **認証トークン方針（決定）**: JWT を **httpOnly Cookie** に保管（localStorage 不使用）＋短命＋refresh。Cookie 方式ゆえ **CSRF（SBD-3）必須**。SBD-4 と一体。

### ⚠️ スコープ境界（最重要・DEV が計画フェーズで線引きしユーザー承認を得ること）

本 Story は **「土台/基盤」** であり、**ドメイン機能そのものではない**。以下の線引きを明確にすること：

- **AC2 認可基盤**は #21（F5.4 認証）と「一体」。**実際のログインAPI・JWT発行の入口は #21** の範囲。本 Story では
  「認可を強制する仕組み（メソッドセキュリティ/サービス層ゲート）」「認証プリンシパルの型・取得口」を土台として用意する想定。
- **AC3 JWT+refresh**：ログインエンドポイント（#21）が無い状態で「提供」をどう実証するか。
  → JWT 生成/検証フィルタ・Cookie 書き込み/読み取り基盤・refresh 機構を**土台として用意**し、テストは内部発行（テスト用トークン）で検証する等、**実証手段を DEV が提示**。
- **AC8 並行制御**：具体的な在庫（#8）・account 編集（#14）は後続 Story。本 Story では
  「409 統一マッピング（`@ExceptionHandler` / 楽観ロック競合例外→409）」「ガード付き UPDATE ＋ affected-rows 判定の標準パターン（規約/ヘルパ）」「`@Transactional` 方針」を**再利用可能な基盤**として用意する想定。
- **共通の問い**：ドメインendpointが無い基盤 Story を **Spock で何をテストするか**（CSRF拒否・Cookieフラグ・例外正規化で500にtraceが出ない・409マッピング・監査ログ記録）。MockMvc slice か Testcontainers 統合かの選択を計画フェーズで確定。

---

## リスク・チャレンジ

| # | 種別 | 内容 | 対応方針 |
|---|------|------|---------|
| R1 | リスク | **スコープ境界の曖昧さ**（土台 vs 機能実装）。AC2/AC3 は #21 認証と一体、AC8 は #8/#14 と一体で、「基盤としてどこまで作るか」が最大の論点 | DEV が計画フェーズで各 AC の「土台の完成形」を具体化し、ユーザー承認を得る（過剰実装＝スコープ逸脱を防ぐ） |
| R2 | リスク | 既存 scaffold（`09ec431`）との整合。SecurityConfig の TODO 雛形を再設計する際、WHO自動付与（AOP+Interceptor）・enum生成・Ping を壊さないこと | 既存資産を尊重し、SecurityConfig・例外ハンドラ・監査基盤を**追記/差し替え**で積む。既存の振る舞いを回帰させない |
| R3 | リスク | **秘密管理（AC5/AC-neg1）**。application.yml に DB pass 平文。JWT 署名鍵も新規に必要 | DB資格情報・JWT鍵を環境変数化（`${...}`）。**デフォルト値を持たせず未設定なら起動失敗（fail-fast）**を方針化。ローカル開発用の扱い（`.env`/README）とソース平文禁止の線引きを提示 |
| R4 | リスク | AC8 並行制御を「実証可能な最小形」でどう示すか（ドメイン更新が無い） | 楽観ロック競合例外→409 の `@ExceptionHandler`、affected-rows==0 判定の標準ヘルパ/規約、テスト用の最小 version 更新例で実証。実在庫/account更新は後続 Story と明記 |
| R5 | リスク | テスト戦略（Spock）。基盤 Story のテスト対象が不明瞭 | MockMvc slice（CSRF拒否・Cookieフラグ・例外正規化・401/403）＋必要に応じ Testcontainers 統合（409・監査ログ）を計画フェーズで確定 |
| R6 | リスク | 依存の版固定（AC6/SBD-12）。BOM 管理と明示ピンの混在。jjwt 0.11.5 は現行 0.12.x | 依存棚卸しで EOL/既知CVE を点検し、版固定方針（BOM経由 or 明示ピン）を確認。jjwt の版更新要否を判断 |
| C1 | チャレンジ | 計画フェーズを **Opus 4.8（1M context）** で実施し、scaffold 全体＋spec（arch §4／security-baseline 全SBD）を一括読解して土台の設計論点（スコープ境界・JWT実証手段・秘密管理・テスト戦略）を先に確定 → 実装フェーズ Sonnet で手戻りなく完走（Sprint 1 で有効だった tier 分離の踏襲） | 計画フェーズを Opus で起動 |

---

## Definition of Done

- 全 AC（AC1〜AC8, AC-neg1）を満たすバックエンド・アーキ土台が `jpetstore-backend` に整備されている。
- 3観点レビュー（規約・セキュリティ・パフォーマンス）で指摘なし。
- PR 作成済み（`closes ryokkon624/jpetstore-manage#23`）。
- Sprint Review 用 HTML 生成済み。
