# Sprint 1 バックログ

## スプリントゴール

**Flyway / MySQL 8.4 による secure-by-default な DB 移行基盤（`jpetstore-database`）を確立する。**
legacy（HSQLDB / iBATIS）のスキーマを MySQL 8.4 へ移行し、全ドメイン実装の前提となる業務テーブル群と監査ログ基盤を、
架構規約（WHO列・version 楽観ロック）とセキュリティベースライン（hash長拡張・bannerdata廃止・カード列除外・金額decimal）を満たす形で整備する。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | ブランチ |
|-------|---------|-------|----|-----------|---------|
| [#22](https://github.com/ryokkon624/jpetstore-manage/issues/22) | [E6] DB移行基盤（Flyway・MySQL 8.4）を整備しスキーマを移行する | `foundation` / `E6` | TBD | `jpetstore-database` | `feature/22-db-migration-foundation` |

> ブランチはIssue本文に指定がないため SM が命名。既存ブランチ継続ではなく **新規ブランチ**（`jpetstore-database` リポジトリ上）。

---

## Issue #22 本文（転記）

### ユーザーストーリー

**As a** 開発チーム
**I want to** Flyway による MySQL 8.4 スキーマ移行基盤を整えたい
**So that** secure-by-default なスキーマで各ドメインを実装できる

### トレース

- **Epic**: E6 横断：secure-by-default／基盤（DB移行）
- **Feature**: E6 基盤 — DB移行（Flyway）
- **spec**: `spec/backlog-map.md`（E6 DB移行の要点）／`spec/security-baseline.md`／`spec/architecture-conventions.md` §2・§4
- **横断NFR**: SBD-5, SBD-7, SBD-13, SBD-14, SBD-18

### Acceptance Criteria

- [x] **AC1**: HSQLDB→MySQL 8.4、iBATIS→MyBatis 前提の Flyway マイグレーション基盤（`jpetstore-database`）を用意。DB名 `jpetstore_db`。
- [x] **AC2 (SBD-5)**: `signon.password` をハッシュ格納可能な長さへ拡張（例 varchar(255)）。
- [x] **AC3**: **bannerdata 依存を廃止**（account/ログイン取得クエリから bannerdata を除外＝as-is の INNER JOIN 依存を解消。決定済 2026-08-10）。MyList/バナー関連スキーマは持たない。
- [x] **AC4 (SBD-13)**: 金額列は decimal（double を使わない）。
- [x] **AC5 (F3.6)**: カード関連列（creditcard/exprdate/cardtype）をスキーマから除外。
- [x] **AC6 (SBD-14)**: 監査ログ用テーブル/基盤を用意（認可失敗・状態変更の記録先）。
- [x] **AC7 (arch §4.2/§4.3)**: **更新が発生するエンティティ表に `version BIGINT NOT NULL DEFAULT 0`**（楽観ロック用）を付与。**純追記表（注文明細・履歴・ログ）・migration 管理の `m_code`・在庫表には付けない**（在庫はガード付きアトミック減算が主機構）。WHO 6列は全業務表に付与し、`updated_at` は監査専用（ロックに使わない）。
- [x] **AC-neg1 (否定AC)**: bannerdata 行が無くてもログイン/アカウント取得が失敗しない（INNER JOIN 依存の解消を確認）。

### 備考

- 優先順位の根拠: 全ドメインの実装前提（最上流）。
- E6 の Story 化: PO 判断で Phase3 に暗黙化せず backlog 化（Refinement 2026-08-11）。
- 決定: bannerdata 廃止・hash列拡張・カード列除外。version 列の付与範囲は `architecture-conventions` §4.2/§4.3 に準拠（更新エンティティ表のみ）。
- 依存関係: なし。

---

## 実装の前提コンテキスト（SM調査メモ）

DEV は計画フェーズで以下を精査すること。

### 既存の状態（`jpetstore-database`）
- 初回雛形がコミット済み（`c83f4fc`）。現状の Flyway マイグレーションは以下の**2本のみ**：
  - `flyway/sql/V00_000_001__create_tables.sql` … **`m_code`（区分値マスタ）テーブルのみ**。WHO列ボイラープレート付き。
    ヘッダに「ドメイン業務テーブル（account/product/order 等）は Phase 3 で PO の仕様から起こすため、ここでは作らない」と明記。
  - `flyway/sql/V00_000_002__insert_m_code.sql` … m_code 初期データ（**サンプル**：OrderStatus / CardType の2区分。実区分値は仕様で確定）。
- **本スプリントは業務テーブル群＋監査ログ基盤を追加マイグレーション（`V00_000_003__...` 以降）で積むのが基本線**。
  Flyway は適用済みマイグレーションの改変を許さない（checksum）ため、原則 **既存2本は改変せず追記**する。
  ※ ただし未デプロイ・開発初期であり「雛形の作り直し」を選ぶ余地もある。DEV が方針を提示しユーザー承認を得ること。

### 移行元（legacy）リファレンス
- MySQL 版スキーマ: `C:\work\java-migration\legacy-jpetstore\db\mysql\jpetstore-mysql-schema.sql`
- データロード: 同 `jpetstore-mysql-dataload.sql`
- これが移行元の権威。ただし **bannerdata / MyList / カード列は意図的に持ち込まない**（AC3/AC5）。

### 規約の要点（`spec/architecture-conventions.md`）
- **WHO 6列**（§2.1）は全業務表に付与（固定ボイラープレート）。値は AOP + MyBatis Interceptor 自動付与（seed は `'INIT_DATA'` 明示）。
- **version 楽観ロック列**（§4.2/§4.3）の付与範囲を厳守：
  - 付ける = **更新が発生するエンティティ表**（account/profile/signon 等）
  - 付けない = 純追記表（注文明細・履歴・ログ）／`m_code`／**在庫表**（在庫はガード付きアトミック減算が主機構）
- 金額は `decimal`（§4 / SBD-13）。`double` 禁止。
- 監査ログ（SBD-14）: 認可失敗・状態変更の「誰が/何を/結果」を記録する先。**新規設計**（legacy に存在しない）。

---

## リスク・チャレンジ

| # | 種別 | 内容 | 対応方針 |
|---|------|------|---------|
| R1 | リスク | 既存雛形（`m_code` のみ）との整合。Flyway checksum のため既存マイグレーション改変不可 | DEV が「追記（V003〜）」か「雛形作り直し」かを計画フェーズで提示・ユーザー承認 |
| R2 | リスク | legacy スキーマの正確な移植（型・制約）と、bannerdata/カード列の意図的除外の取りこぼし | 移行元 `jpetstore-mysql-schema.sql` を精読し、除外対象を明示リスト化して確認 |
| R3 | リスク | version 列の付与範囲の誤り（全表付与＝規約違反） | §4.2/§4.3 の判定基準（更新エンティティ/純追記/在庫）を表ごとに明記 |
| R4 | リスク | AC6 監査ログ基盤は新規設計。Sprint 1（DBのみ）でどこまで作るか曖昧 | 「記録先テーブルの用意」までを Sprint 1 スコープと明確化（記録ロジックは backend 実装の後続 Sprint） |
| R5 | リスク | AC-neg1（bannerdata なしでログイン成立）を DB 単体で実証する手段 | Sprint 1 では「bannerdata テーブル/依存を持たない」ことで担保。ランタイム検証は backend Sprint（Phase 4 回帰の種）で |
| C1 | チャレンジ | 計画フェーズを Opus 4.8（1M context）で実施し、legacy スキーマ全体＋spec を一括読解して移行方針の精度を上げる | 計画フェーズを Opus で起動 |

---

## Definition of Done

- 全 AC（AC1〜AC7, AC-neg1）を満たす Flyway マイグレーションが `jpetstore-database` に追加されている。
- 3観点レビュー（規約・セキュリティ・パフォーマンス）で指摘なし。
- PR 作成済み（`closes ryokkon624/jpetstore-manage#22`）。
- Sprint Review 用 HTML 生成済み。
