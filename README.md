# migration-agent-base

**JPetStore レガシー刷新プロジェクト**の AI スクラムチーム基盤。
`scrum-agent-base`（HwHub 用）を複製し、脆弱な **Struts 1 レガシー（JPetStore）** を
モダン構成へ刷新するパイプライン向けに再ポイントしたもの。

- 設計・方針: OneDrive `brain/30_Zenn/java-migration/concept.md`
- 作業ログ: 同 `log.md`
- エージェントの起動方法・技術スタック・パス構成: [`CLAUDE.md`](./CLAUDE.md)

---

## 移行パイプライン（Phase 0-4）

| Phase | やること | 主担当 |
| ----- | -------- | ------ |
| 0 題材確保       | `legacy-jpetstore` を Docker で起動（**完了**） | — |
| 1 Scan/Discovery | before の脆弱性棚卸し（＋ 脆弱性注入） | SEC / security-scanner / security-reviewer |
| 2 Spec化         | 旧コードを読み、挙動・業務ルールを `spec/` に抽出 | PO |
| 3 Rebuild        | HwHub アーキで新規リビルド（secure-by-default） | SM / PO / DEV / 各 reviewer |
| 4 Verify         | Red/Blue を新ビルドに再実行、脆弱性消滅を実証 | SEC / security-verifier / security-poc-runner |

before（Phase1）と after（Phase4）の差分が、Zenn 記事③（レガシー刷新）の背骨になる。

---

## 3つのフロー（複製元から継承）

ターミナルで `claude` を起動し、フローごとの起動フレーズを送ると始まる。

- **Sprint**：バックログを実装し、レビュー・PR・レトロまで回す（SM がリード）
- **Refinement**：バックログを整え、優先順位と次 Sprint の対象を決める（PO）
- **Discovery & Verification**：脆弱性を発見・検証し、確定分をバックログに起票（SEC）。修正は Sprint 側

起動例：
```
SMモードで動いて。Sprint XXのPlanningを開始してください。
POモードで動いて。Refinementしてください。
SECモードで動いて。legacy-jpetstore の Discovery / Verification を実行してください。
```

---

## ディレクトリ構成

```
migration-agent-base/
├── CLAUDE.md                 # エージェントが起動時に読む設定
├── README.md                 # このファイル
├── .claude/
│   ├── settings.json         # Agent Teams 有効化設定
│   ├── hooks/pre-commit.sh   # コミット前フック（jpetstore-frontend/backend を整形）
│   ├── rules/                # git.md（jpetstore-manage）・database.md
│   ├── agents/               # SM/DEV/PO/各reviewer/SEC系
│   └── skills/               # workflow・conventions・discord-operations・github-issues・sprint-review-prep
├── spec/                     # Phase2: legacy から抽出した仕様
├── backlog/                  # リビルドのスプリントバックログ
└── reports/                  # Phase1 scan(before) / Phase4 verify(after)
```

---

## 複製元 `scrum-agent-base` からの調整点

- **破棄**: `mobile-conventions` skill（モバイル無し）
- **再ポイント済**:
  - `github-issues` → Issueホスト `ryokkon624/jpetstore-manage`（private）、Project「JPetStore Migration」#2
  - `discord-operations` → 既存チャンネル共用、**Forum スレッドタイトルに `[JPS]` プレフィックス**
  - `rules/git.md` → Issue参照 `(ryokkon624/jpetstore-manage#N)`、整形先 `jpetstore-*`
  - `hooks/pre-commit.sh` → `jpetstore-frontend`/`jpetstore-backend` を検出
- **未調整（Phase 3 実装時に JIT 調整）**: `backend-conventions` / `frontend-conventions` /
  `*-workflow` / `rules/database.md` 内に残る `hw-hub-*` パス参照

---

## 関連リポジトリ

| リポジトリ | 役割 |
| ---------- | ---- |
| `legacy-jpetstore` | Struts1.2+Spring+iBATIS の題材（before・+脆弱性注入） |
| `jpetstore-backend`  | モダン版 Spring Boot 4.x（Phase 3 で作成） |
| `jpetstore-frontend` | モダン版 Vue 3（Phase 3 で作成） |
| `jpetstore-database` | Flyway マイグレーション（Phase 3 で作成） |
| `ryokkon624/jpetstore-manage` | Issue/バックログ管理（private・GitHub） |
