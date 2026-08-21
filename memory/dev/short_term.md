# DEV 短期記憶

Sprint 23 完了。Retro で振り返り済み（`memory/dev/long_term.md` へ反映）。次スプリント開始時にリセット済み。

## 次スプリントへの申し送り

1. **数値・判定を成果物に書くときは一次データを機械的に走査する**（`developer-workflow` へ2回ルール昇格済み・Sprint21→22→23）。特に「すべて／〜しかない／理論上限」は全件列挙してから書く。
   - **他レポートの集計値は疑ってよい**。実例: `l3-security-regression-backend.md` の「うち**10件**をライブ実測で確証」は、§1 表を機械パースすると `live` を根拠に含む行は **17**（`code` のみは S2・S4・S20・S21 の4行）で、10 は **`live`+`code` 併記行**の数だった。同レポートの引用元「全18シナリオ」も 17 が正だった。**引用する前に一次データで数え直す。**
2. **`./gradlew test` は `UP-TO-DATE` でスキップされる**。「実行結果」を報告する Story では `--rerun-tasks`。件数は `build/test-results/{task}/*.xml` から合算する（`backend-conventions` §9）。
3. **`jpetstore-frontend` のテストは `npm run test`**（`test:unit` は存在しない・`frontend-conventions` §7）。
4. **指示された対象範囲の外に成果物がある可能性に気づいたら、勝手に「無い」で締めずSMに確認する**（Sprint23 で `jpetstore-database` を含めるかを確認し、SM が「指定漏れ」と認めて承認された）。
5. **Phase 4 は完走済み**。`reports/after/verification-report.md` が最終成果物、意図差分台帳は **33件**（ID-32・ID-33 が L4 で追記）。
6. **L2 ゲート値は BRANCH 28/34・INSTRUCTION 1360/1424 で据え置き**（非退行フロア）。**「28/34 は理論上限」は撤回済み** — 残6は4種類（構造的に到達不能2・seed 前提で到達不能1・**到達可能だがスコープ外3**）。
7. **次イテレーション（#54 = 穴埋め／#55 = 部分観測の補強と退行検知器）の候補は L4 から導出済み**（根拠は `backlog/sprint_23/dev-observation-points.md` 末尾「次イテレーションの L2/L1 シナリオ候補」）。DEV が名指しした5本:
   - `item-detail-missing`（L2）— ID-14 の**2本目**の L2 観測点。副次で legacy 未踏分岐 `SqlMapItemDao.getItem:39` の `item == null` 側を踏む。新側は `CatalogControllerSpec:154` で 404 固定済みなので**旧側 golden を採るだけで宣言が書ける**
   - `item-out-of-stock-add`（L2）— ID-18 の旧側実測。副次で `SqlMapItemDao.isItemInStock:30` の未踏2アウトカム
   - カート行数の非ページング assert（L1）— **ID-33（穴）**。現状 `CartControllerSpec` の最大ケースは2行で、旧の閾値4件超が1レスポンスで返る観測が無い
   - `STATELESS`/`JSESSIONID` 不発行 assert（L1）— **ID-32 の回帰検知器**（現状 assert 0件で設定を戻しても赤くならない）
   - `t_order.order_id` の AUTO_INCREMENT assert（L1・database）— ID-23 の部分観測解消。`m_account.user_id`（`AccountTablesSpec:16`）と対称化になる
   - **導出の順序が肝**: 「カバレッジが低いから足す」ではなく「**台帳 ID に観測点が無いから足す**」。未踏分岐を踏むのは副次効果。**ゲート値 28/34 は引き上げない**（#52 AC-neg1・据え置き＝非退行フロア）。
8. **`tools/legacy-jacoco/out{,2,3}/` は削除しない**（ゲート値の唯一の裏取り経路・gitignore 済みで未コミット）。事故ディレクトリ2つは Sprint23 で削除済み＋`.gitignore` で再発防止済み。
9. **Git Bash の `awk`/`sed` は CRLF ファイルを LF に落とす**（SM/PO 申し送り）。行挿入・行移動を script でやるときは注意し、`git diff --stat` が全行差分になっていないか確認する。
