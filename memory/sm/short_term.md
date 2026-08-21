# SM 短期記憶（今スプリント）

Sprint 21（#48 L2 パリティ検証基盤・縦切り1本 W1 ／ #49 読み取り系＋W2/W3 の横展開 ／ #50 legacy カバレッジ計測＋ゲート値 PO 合意・11SP）完了。Retro 済み。次スプリント開始時にリセット済み。

- **性格**: **プロダクトコードを1行も変えない「検証基盤」スプリント**（新種）。`jpetstore-backend` の test スコープ単独＋`migration-agent-base`（overlay 定義・レポート）。**cross-repo なし**・`legacy-jpetstore` は起動のみで**無改変を維持**。
- **実装**: backend `feature/48-l2-parity-foundation`（10コミット・**PR #21 マージ済＝#48/#49 クローズ**・local main `cb860a4` 同期済）。agent-base は `docs/sprint-21-l2-parity`（step12 で PR）。**AC 30/30**。
- **レビュー**: 初回＝conv 1件（**SM verification で却下**＝`.each{} + return` は continue の意味で正しく `ensureCsrfToken` とは意味論が逆）・sec/perf 0。デルタ＝conv/sec とも 0（perf は観点を絞り N/A 判定）。**Sprint Review 指摘ゼロ**。
- **SM verification の確定所見2件**（いずれも是正済み）: ①**W3 の ID-1 証拠が資産に固定されていない**（前処理が将来0行になっても golden はバイト同一で green のまま観測点が失われる）②**カバレッジレポートの因果分析が推測のまま下流で確定扱い**。
- **【SM 自身の誤り】** PO へ渡した「到達可能分母 36」が誤り（正しくは **34**）。**PO が jacoco.xml を直接パースして検出**。是正＝`report.sh` の2本出し＋除外反証 fail（機構で担保）。
- **#50 ゲート値 PO 合意**: **BRANCH ≥ 16/34（47.0%）・INSTRUCTION ≥ 1144/1588（72.0%）**の非退行フロア。分母は二層（AC1＝計測／ゲート＝AC1−到達不能3クラス・**両方併記必須**）。CLASS はゲートにしない。評価契機は**シナリオ集合が変わったとき**・自動ラチェットなし。
- **Skills 昇格3件**（詳細は long_term「Skills更新履歴 Sprint 21」）: `scrum-master-workflow` ④＝検証資産の耐久性＋**数値は一次データで検算（SM が下流へ渡す数値も含む）**／⑥＝**push 代行前に規約上の正当性を確認**／step12＝**capstone が agent-base にある Story は `closes` を置く**。

## 次スプリントへの申し送り

- (1) **teammate 完了は idle≠完了**。成果物直接確認（memory/Discord/Issue/branch）。**副作用を伴う最終化の nudge は冪等指示**。Sprint21 では idle 通知が実作業完了より**先に**届くケースを確認（stale read ではない・時系列の差）。
- (2) **push はセッション単位で揺れる**（⑥ のはしご）。ただし**代行前に `rules/git.md` 上の正当性を確認**（Sprint21 で昇格）。マージは `mcp__github__merge_pull_request`。
- (3) **teammate に「ブランチを切らず直接書いてよい」と指示しない**。**SM が先に作業ブランチを切って渡す**（Sprint21 の main 直コミットの誘因）。
- (4) **javadoc `{@link}` 宙吊り参照**は Sprint20 の2件から**追加発生なし**（Sprint21 は該当なし）。3件目が出たら `backend-conventions §9` へ追加を判定。
- (5) frontend EOL(CRLF) ノイズ（#35 `.gitattributes` 済）。**Sprint20/21 とも frontend 無変更のため観測機会なし**（要フォロー継続）。
- (6) **PO 申し送り**: `l2-parity-design.md` の R2/F5 内部矛盾は **SM が Retro で是正済み**（R2 を「集合」に統一＋§2 に比較単位の規約を明記）。
- (7) **PO の傾向候補α**（設計書内の記述どうしの矛盾が PO に確定要求として回る）は**初出継続**・次回同種発生で昇格判定。
- (8) **台帳の残タスク**: #47(C) 完了後に **ID-22 の関連Story欄拡張の要否**を判定（#47 は現状 NotReady）。

## 次スプリント候補

- **#51**（[L2] W4/W5・注文履歴照会・カート境界値・`OrderValidator` 配線調査／**SP 5・NotReady**）＝Sprint21 Retro で起票。**Ready 昇格の条件**＝Refinement で①旧新アカウント系テーブルの対応づけ（**#13/#14 の entity/mapper を一次情報源に**）②**ID-2 の宣言方法**（**PO 推奨＝案A＝password を canonical 比較から除外し、新側ログイン成功は独立の機能検証**。平文とハッシュは値として比較不能で `divergentFields` 完全一致の枠組みと整合しないため）を確定すること。
- その他の open Issue: **#32**（メール検証・NotReady/deferred）・**#42〜#47**（L3 Low 束・すべて NotReady 塩漬け）。#42〜#47 の Ready 昇格トリガは本番デプロイ基盤の整備決定／Phase 4 完了後の容量。**#44/#46/#47 は `AuditLogRecorder` 周辺を共通で触るため束ねるのが自然**。
- **#50 は open のまま**（agent-base PR の `closes #50` でクローズ予定）。
