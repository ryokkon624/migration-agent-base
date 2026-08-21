# PO 短期記憶（今スプリント）

## Sprint 22 Retro（2026-08-21）で棚卸し済み

Sprint21 Retro以降の文脈（#51計画フェーズのQ1〜Q7・C1〜C4の質問ログ11件、Sprint ReviewでのSMからの明示報告2件〔R8aのexpectation変更・AC7ゲート値再合意案〕へのPO判断、Issue #51本文の訂正要否の確定）は本Retroで棚卸し済み。要点は`memory/po/long_term.md`（Sprint22セクション追記・傾向1「リファクタ/是正・棚卸し系Story起票時の前提裏取り」の適用範囲をL2 parity/特性化テストStoryへ拡張・決定ログ6件追記）に反映済み。

**本Retroで実施した確定作業**:
- **PO判断1（承認）**: R8aのexpectation変更（Issueスコープ表の`EQUIVALENT`→`INTENDED_DIVERGENCE(ID-24)`）。台帳ID-24・design doc側の更新内容を確認済み。
- **PO判断2（承認）**: AC7ゲート値再合意案（BRANCH≥28/34=82.4%・INSTRUCTION≥1360/1424=95.5%・`gate`→`gate-v2`分母切替）。`out2`/`out3`の`gate-v2`jacoco.csvをPOが直接パースして検算済み。
- `reports/after/l2-parity-coverage.md` §6「ゲート値の再合意案（PO提示）」→「（PO合意済み）」へ本Retroで更新（検算根拠を追記）。
- `spec/intended-diff-ledger.md`のID-14・ID-24、`spec/l2-parity-design.md`§2・R2/F5の内部矛盾是正（Sprint21 Retro申し送り分）がいずれも#51で解消済みであることを確認（追加対応不要）。

## 未解決の判断事項

- 確認メール（#8備考。注文確定完了時の受領メール送付）を独立の将来Feature Issue として NotReady で track するか（現状は#8備考に記録のみ。#8自体はクローズ済みだが、この将来Feature化の判断自体は未決着のため継続）。
- **#42〜#47 は 2026-08-20 の Refinement で NotReady 確定・塩漬け（SP は全件設定済み）**。Ready 昇格のトリガは、#43(B)(E)・#45＝本番デプロイ基盤／本番プロファイルの整備決定、#42・#44・#43(C)(D)・#46・#47＝Phase 4 完了後に容量が空いた時点。**#44／#46／#47 は `AuditLogRecorder` 周辺を共通で触るため、昇格させるなら同時期に束ねるのが自然**（着手順は #47(B)(C) の境界整理 → #46 のキー複合化 → #44 の結線 → #47(A)）。
- **#46 の重大度は本番デプロイ基盤の整備決定時に再判定**する（quota キーが `getRemoteAddr()` 固定のため、リバースプロキシ/LB 配下では全クライアントが単一バケットを共有し「per-IP なので他人の監査は消せない」という Low 格下げ根拠が崩れる）。#45／#43(B)(E) と同じタイミングで見直す。
- **#47(C) 完了後の Retro で、台帳 ID-22 の関連Story欄拡張の要否を判定する**（#47 は現状 NotReady・未着手のため未実施。Sprint20 の ID-25/ID-11 と同型の運用）。
- **`reports/after/l3-security-regression-backend.md` §1 回帰表の判定（S10「是正」・S15「消滅＋是正」・S17「消滅」）は、Sprint20で#38/#39/#41が実装・マージされたことにより実効性が回復した見込みだが、正式な回帰再実証（L3再実行）はまだ行っていない**。Phase 4 の合否ゲート（L3・L4）判定および `reports/after/verification-report.md` 作成時に、SEC側での回帰再検証結果と実装内容を突き合わせる必要がある（SM/PO の L4 作業として継続監視）。
- #32（メール検証・Sprint16 Retro新規起票）は現状NotReady（deferred）。実SMTP基盤・検証トークン表の着手判断が出た時点でReady昇格の要否を判断する。
- **#51のIssue Body（Refinement確定版）に4箇所の訂正が必要（次回Refinementでユーザーに確認のうえ実施）**：(1) AC2「W5: アカウント編集 — 2ケース」→3ケース（W5a/W5b/W5c）、(2) R8bの理由説明文「新側は404」→403、(3) AC-neg4「`POST /api/login`」→「`POST /api/auth/login`」、(4) スコープ表のR8a期待値「`EQUIVALENT`」→「`INTENDED_DIVERGENCE(ID-24)`」（本Retroで承認したPO判断1に伴う訂正）。(1)〜(3)はSprint22計画フェーズでSM/DEVが実コード・実測値に当たって判明（C1〜C3）。(4)はSprint ReviewでのSM報告を受け本Retroで確定。**なお「到達可能上限30/34→28/34」はIssue本文には元々記載が無かった数値（`backlog/sprint_22/sprint_backlog.md`というSM作業物側の記載）のため、Issue本文の訂正対象には含めない**（本Retroで`mcp__github__get_issue`により実物確認済み）。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
