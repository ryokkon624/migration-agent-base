# SM 長期記憶（過去スプリントの教訓）

## スプリント進行パターン

- **tier分離が有効**（Sprint 1）: 計画フェーズ=Opus（論点洗い出し→ユーザー承認）／実装フェーズ=Sonnet（TDD）。計画フェーズで設計論点（命名規約・キー戦略・seed範囲・テスト手段）を先に確定させると実装が手戻りなく完走する。基盤／新規リポジトリ着手 Story で特に有効。
- **レビュー指摘は SM が verification してから DEV に回す**（Sprint 1）: perf の「supplier_id 全スキャン」は InnoDB が FK 索引を自動生成するため偽陽性だったが、product_id との一貫性という妥当な観点に読み替えて明示索引追加に落とした。reviewer の指摘理由が技術的に誤っていても、別観点で妥当な是正に転換できることがある。偽陽性でも一貫性・自己文書化の観点で採否を判断する。
- **PO質問中継（②c）は計画フェーズに確認事項がある限り必ず回す**: 質問傾向を PO が学習し Refinement 先回りに繋げる改善ループの起点。

## DEVレビュー指摘の傾向

- **DBスキーマ Story**: FK 列の明示セカンダリインデックスの一貫性（Sprint 1: m_item.supplier_id）。InnoDB は FK 索引を自動生成するため機能影響は無いが、同種の兄弟列に明示索引がある場合は揃える。2回目の発生で rules/database.md への昇格を判定（現在1回目・DEV long_term に記録済み）。

## Sprint Reviewで発覚しやすいパターン

- **Flyway 採番規約（versioned vs repeatable）**（Sprint 1）: 開発/テスト用シード（`flyway/sql-test`）を versioned（`V__`）で採番すると version 順序に組み込まれ、後から `flyway/sql` に低い version を足すと out-of-order で破綻する懸念。ユーザーレビューで発覚。→ repeatable（`R__`）＋冪等を rules/database.md に明文化済み。**自動3reviewer は規約に無い観点は全員見逃す**ため、規約の明文化が再発防止の要（規約 > レビュアーの勘）。

## Skills更新履歴

- **Sprint 1**: `.claude/rules/database.md` に flyway/sql-test の採番規約（repeatable `R__`・冪等・`WHERE NOT EXISTS`）を追記。ローカル適用手順の「sql-test のバージョンと競合」という versioned 前提の記述も repeatable 前提に是正。（SM）
