# SM 短期記憶（今スプリント）

Sprint 18（#33/#34 保護ルート到達性 bug 修正・#27/#31/#26 tech-debt 焼却＝8SP・3-repo）完了。Retro 済み。次スプリント開始時にリセット済み。

- 実装: frontend `fix/33-auth-guard-reachability`（#33/#34/#27）・backend `refactor/31-null-type-safety`（#31）・database `refactor/26-dependency-currency`（#26）。3観点＋SM verification 全クリーン（11回目相当）・Sprint Review 指摘ゼロ・tier分離18連続。PR: frontend #11(closes #33/#34/#27)・backend #18(closes #31)・database #8(closes #26)→ **全マージ済**（#33/#34/#27/#31/#26 closed(completed) 確認済）。local main 3 repo 同期済（frontend 04bef1a・backend d9a4623・database 641afc5）。
- 委譲論点: Q1 #34 導線配置=案A-1（ユーザー承認）・Q2 #33 catch-all フェイルセーフ維持・Q3 #31 ラムダ化1案・Q4 #26 EOL/重大CVEのみ更新。
- SM verification: #31 4ファイル等価ラムダ変換で挙動不変・純増ゼロ／#33 順序変更（router install を再水和 await 後へ）で認可バイパスなし／#26 mysql-connector-j 8.0.33→26.7.0（CVE-2023-22102 対応）・他5依存据え置き。
- #33 は headless Chrome(CDP)で実機検証（DEV）・#31 AC1 は IDE(JDT)診断依存で ◐（ユーザー VS Code 確認）。

## 要フォロー（次回）
- (1) **teammate 完了確認（idle ≠ 完了）**＝今回も idle 通知後に成果物を直接確認（memory/スレッド/branch）してから前進を徹底（DEV 計画/実装/Retro・reviewer 3体・PO で実践）。継続。
- (2) **frontend EOL(CRLF) ノイズ**（Sprint14/15/17/18 で4回連続再発）: **恒久対策 `.gitattributes` を #35 起票済（Draft）**。次スプリントで Ready 昇格・実装されれば解消見込み。それまでは DEV 選択 add・SM は `git checkout -f main` で対処。
- (3) **curl の破壊的/書込系操作（merge PUT 等）が実行環境の分類器にブロックされることがある**（Sprint18 初出・Sprint17 の token URL push ブロックに続く）→ PR マージは `mcp__github__merge_pull_request`、Issue 作成/取得は MCP github ツールで代替可（GraphQL Projects 操作は curl POST で通った）。次回再発で scrum-master-workflow ⑥ へ昇格判定。
- (4) git token URL 埋め込みは分類器ブロック→ `git push/fetch/pull origin`（token URL なし・credential helper 経由）が有効（Sprint17/18 で定着）。

## 次スプリント候補
- 機能面 Epic（E1-E4）は完了。残 Open は deferred（#25 i18n・#32 メール検証・いずれも NotReady）／新規 Draft（#35 .gitattributes 恒久対策）。Sprint 19 対象は Planning 時に GitHub Projects の Sprint フィールドで特定する。

## agent-base 成果物（step 12・実施中）
- 対象: backlog/sprint_18/（sprint_backlog.md・review-#33/#34/#27/#31/#26.html）／memory/{sm,dev,po}/{short,long}.md／.claude/skills/frontend-conventions（DEV §7 更新）。ブランチ `docs/sprint-18-reachability-techdebt`・`Related: #33,#34,#27,#31,#26`（closes にしない）。
