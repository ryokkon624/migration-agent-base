# CLAUDE.md - migration-agent-base

JPetStore レガシー刷新プロジェクトのスクラムエージェント基盤。
脆弱性を抱えた **Struts 1 レガシー（JPetStore）** を、AIエージェント（SM・DEV・PO・各レビュアー・SEC）で
**「脆弱性の棚卸し → 仕様抽出 → モダン構成へ新規リビルド → 脆弱性消滅の実証」** まで一気通貫で回す。

（`scrum-agent-base`（HwHub 用）を複製し、JPetStore 移行向けに再ポイントしたもの。設計背景は
OneDrive `brain/30_Zenn/java-migration/concept.md`、作業ログは同 `log.md`。）

---

## プロジェクトのパス構成

| リポジトリ           | パス                                          | 役割                                                     |
| -------------------- | --------------------------------------------- | -------------------------------------------------------- |
| エージェント基盤     | `C:\work\java-migration\migration-agent-base` | 本体（このリポジトリ）                                   |
| レガシー題材(before) | `C:\work\java-migration\legacy-jpetstore`     | Struts1.2+Spring+iBATIS の JPetStore（+ 脆弱性注入）      |
| バックエンド(after)  | `C:\work\java-migration\jpetstore-backend`    | モダン版 Spring Boot 4.x（Phase 3 で作成）               |
| フロントエンド(after)| `C:\work\java-migration\jpetstore-frontend`   | モダン版 Vue 3（Phase 3 で作成）                         |
| データベース         | `C:\work\java-migration\jpetstore-database`   | Flyway マイグレーション（Phase 3 で作成）               |

---

## 技術スタック

### レガシー題材（before / `legacy-jpetstore`）

Java(JDK8 想定) / Apache Struts **1.2.9** / Spring 3.1 / iBATIS 2 / JSP / HSQLDB。
実行は Docker（HSQLDB 1.8 サーバ + Tomcat 9/JRE8 を1コンテナ）。手順は `legacy-jpetstore/run/README.md`。

### リビルド先（after / HwHub 準拠）

| リポジトリ     | 主要技術                                                                   |
| -------------- | -------------------------------------------------------------------------- |
| フロントエンド | Vue 3 / TypeScript / Pinia / Tailwind CSS / Vite / Vitest                  |
| バックエンド   | Java 21 / Spring Boot 4.x / MyBatis / Flyway / MySQL 8.4 / Groovy + Spock  |
| データベース   | MySQL 8.4 / Flyway                                                         |

**JSP + サーバーサイドレンダリング → Vue 3 SPA + REST API** に作り替える。

---

## 移行パイプライン（Phase 0-4）

[アルバータ Velocity White Papers](https://thevelocitywhitepapers.com/) の4アプローチのうち **「AI Garage(migrate) + AI Factory」** に相当。

| Phase | やること                                          | 主担当                                  |
| ----- | ------------------------------------------------- | --------------------------------------- |
| 0 題材確保       | `legacy-jpetstore` を Docker で起動（**完了**）       | —                                       |
| 1 Scan/Discovery | before の脆弱性棚卸し（＋ 脆弱性注入）                | SEC / security-scanner / security-reviewer |
| 2 Spec化         | 旧コードを読み、挙動・業務ルールを `spec/` に抽出      | PO（当面は手動。育てば skill/agent 化を検討） |
| 3 Rebuild        | HwHub アーキで新規リビルド（secure-by-default）       | SM / PO / DEV / 各 reviewer             |
| 4 Verify         | Red/Blue を新ビルドに再実行し、脆弱性消滅を実証       | SEC / security-verifier / security-poc-runner |

成果物の置き場：`spec/`（Phase2 抽出仕様）・`backlog/`（リビルドのバックログ）・`reports/`（scan=before / verify=after）。

---

## ロールの起動方法

ユーザーから「〇〇モードで動いて」と指示されたら、対応する agent 定義を参照して行動する。

| 指示                  | 参照する agent 定義               |
| --------------------- | --------------------------------- |
| 「SMモードで動いて」  | `.claude/agents/scrum-master.md`  |
| 「DEVモードで動いて」 | `.claude/agents/developer.md`     |
| 「POモードで動いて」  | `.claude/agents/product-owner.md` |
| 「SECモードで動いて」 | `.claude/agents/security-lead.md` |

---

## 行動原則

- バックログに書いていない追加実装は自己判断でやらない
- Agent Teams が使えない場合は Discord 投稿のみで完了とする
- Discord チャンネルは **HwHub チームと共用**。**Forum スレッドのタイトルに `[JPS]` プレフィックス必須**
  （`discord-operations` skill 参照）
- **レガシー題材のソースコードは無改変**が原則（脆弱性の意図的注入を除く）。ビルドを通すための
  pom 座標変更等は実施済み

---

## 環境制約

- `gh` CLI は未インストール → Issue/PR は curl + GitHub REST/GraphQL API（`github-issues` skill 参照）
- **Issue ホスト**: `ryokkon624/jpetstore-manage`（private）／ **Project**: 「JPetStore Migration」#2
- コミットの Issue 参照は `(ryokkon624/jpetstore-manage#N)`
- レガシー／リビルドのビルド・実行は **Docker 前提**（ホストに Maven/JDK8/Tomcat/MySQL を入れない）

---

## バックログの場所

- 各スプリントバックログ: `backlog/sprint_XX/sprint_backlog.md`

---

## skill / rules の状態（複製元 `scrum-agent-base` からの調整）

- **破棄**: `mobile-conventions`（モバイル無し）
- **再ポイント済（JPetStore 向け）**: `github-issues`（jpetstore-manage + Project #2 + 新フィールドID）／
  `discord-operations`（`[JPS]` スレッドプレフィックス）／`rules/git.md`（jpetstore-manage）／
  `hooks/pre-commit.sh`（jpetstore-frontend/backend）
- **未調整（Phase 3 実装時に JIT 調整）**: `backend-conventions` / `frontend-conventions` /
  `developer-workflow` / `scrum-master-workflow` / `product-owner-workflow` / `sprint-review-prep` /
  `rules/database.md` 内に残る `hw-hub-*` パス参照。実装フェーズで `jpetstore-*` に読み替え・修正する。
