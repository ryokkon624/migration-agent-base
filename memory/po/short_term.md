# PO 短期記憶（今スプリント）

## Sprint 21 Retro（2026-08-21）で棚卸し済み

Sprint20 Retro以降の文脈（#42〜#47 SEC Low束2セットのRefinement塩漬け確定・#48〜#50 Phase4 L2起票+AC5ゲート値合意・Sprint21計画フェーズQ&A中継7件〔D1〜D3・Q1〜Q4〕）は本Retroで棚卸し済み。要点は`memory/po/long_term.md`（Sprint21セクション追記・候補α/β判定・チェックリスト一般化・D3のrules/database.md firmup・Q4のl2-parity-design.md明文化・意思決定ログ6件追記）に反映済み。

**台帳（`spec/intended-diff-ledger.md`）更新（本Retroで実施・4件）**:
- ID-1の関連Storyへ#49を追加（`#8`→`#8, #49`）。#49のW3シナリオが`INTENDED_DIVERGENCE(ID-1)`として直接検証。
- ID-29の関連Storyへ#49を追加（`#2`→`#2, #49`）。#49のR6シナリオが`INTENDED_DIVERGENCE(ID-29)`として直接検証。
- ID-5の関連Storyへ#50を追加（`#11, #23`→`#11, #23, #50`）。JaCoCo分母設計（§4.1）が`service`/`service.client`除外の根拠として引用。
- ID-6の関連Storyへ#50を追加（`全ドメイン(#1–#24)`→`全ドメイン(#1–#24), #50`）。JaCoCo分母設計が`web.struts`/`web.spring`除外の根拠として引用。
- ID-20は見送り（L2の読み取り系シナリオはEQUIVALENT判定のみでID-20自体を直接検証するシナリオがないため）。

**文書firmup（本Retroで実施・2件）**:
- `.claude\rules\database.md`に「R__はTestcontainersベースの自動テスト実行経路に届かない」節を新設（D3対応。Sprint19 #36とSprint21 #48 AC5の2度の表面化を受けた直接firmup。PO内チェックリスト昇格は見送り）。
- `spec/l2-parity-design.md`§2に`INTENDED_DIVERGENCE(ID-x)`判定の受入基準（`divergentFields`完全一致）を明文化（Q4対応。#50 AC6の次期シナリオ追加が踏襲する先例規約）。

**チェックリスト一般化（本Retroで実施）**: 「セキュリティ対策の新規追加要否は既存機構充足を先に確認する」項目を、Sprint19 #25→Sprint21 #48/#49（候補β・2回目の発生）を受けてセキュリティ限定から「新規実装（テスト基盤含む）vs既存資産充足」全般へ一般化。

**申し送り（SM/DEVへ・未実施）**: `spec/l2-parity-design.md`§2 R2「productId順序つきリスト」と§7.4 F5「集合で比較」の内部矛盾（候補α）は、#48 AC3/#49 AC1の決定（canonical キー昇順ソート後に比較・並び順は比較対象外）を未反映のまま残っている。design doc自体の訂正はDEV/SM側での対応を推奨（PO傾向としては初出のため昇格見送り。doc訂正自体はPO判断の範囲外と判断し、SMへ申し送り済み）。

## 未解決の判断事項

- 確認メール（#8備考。注文確定完了時の受領メール送付）を独立の将来Feature Issue として NotReady で track するか（現状は#8備考に記録のみ。#8自体はクローズ済みだが、この将来Feature化の判断自体は未決着のため継続）。
- **#42〜#47 は 2026-08-20 の Refinement で NotReady 確定・塩漬け（SP は全件設定済み）**。Ready 昇格のトリガは、#43(B)(E)・#45＝本番デプロイ基盤／本番プロファイルの整備決定、#42・#44・#43(C)(D)・#46・#47＝Phase 4 完了後に容量が空いた時点。**#44／#46／#47 は `AuditLogRecorder` 周辺を共通で触るため、昇格させるなら同時期に束ねるのが自然**（着手順は #47(B)(C) の境界整理 → #46 のキー複合化 → #44 の結線 → #47(A)）。
- **#46 の重大度は本番デプロイ基盤の整備決定時に再判定**する（quota キーが `getRemoteAddr()` 固定のため、リバースプロキシ/LB 配下では全クライアントが単一バケットを共有し「per-IP なので他人の監査は消せない」という Low 格下げ根拠が崩れる）。#45／#43(B)(E) と同じタイミングで見直す。
- **#47(C) 完了後の Retro で、台帳 ID-22 の関連Story欄拡張の要否を判定する**（#47 は現状 NotReady・未着手のため未実施。Sprint20 の ID-25/ID-11 と同型の運用）。
- **`reports/after/l3-security-regression-backend.md` §1 回帰表の判定（S10「是正」・S15「消滅＋是正」・S17「消滅」）は、Sprint20で#38/#39/#41が実装・マージされたことにより実効性が回復した見込みだが、正式な回帰再実証（L3再実行）はまだ行っていない**。Phase 4 の合否ゲート（L3・L4）判定および `reports/after/verification-report.md` 作成時に、SEC側での回帰再検証結果と実装内容を突き合わせる必要がある（SM/PO の L4 作業として継続監視）。
- ~~L2 カバレッジのゲート値は #50 AC5 で PO 合意が必要~~ → **2026-08-20 に決着**。BRANCH ≥ 16/34（47.0%）・INSTRUCTION ≥ 1144/1588（72.0%）を到達可能分母上の非退行フロアとして合意。**残タスク＝DEV によるレポート反映（到達可能分母 36→34・44.4%→47.1% の訂正を含む）と `report.sh` の2本出し＋除外反証 fail の実装**（未実施・継続監視）。
- **L2 のアカウント系シナリオ（W4 登録・W5 更新）は次イテレーション（1件・SP 5・NotReady）で SM が起票する**。Ready 昇格の前提は (1) 旧 `account`/`profile`/`signon` ↔ 新 `m_account`/`m_profile`/`m_signon` の対応づけ確定（`spec/l2-parity-design.md` §6-2）と (2) ID-2（パスワード平文→ハッシュ）を W4/W5 の期待値としてどう宣言するかの確定。**起票前の PO 補足（本Retroで整理・SMへ伝達済み）**:
  - (1) は `account`/`profile`/`signon` の DDL から再導出せず、既に実装済みの #13（登録）・#14（アカウント編集）の実装（entity/mapper 定義）を対応づけの一次情報源として参照する。
  - (2) は password フィールドを `INTENDED_DIVERGENCE(ID-2)` として値比較の対象に含めるのではなく、canonical 比較から**除外**（WHO 列・version 等と同様の正規化除外）した上で、新側ログイン成功を独立の機能検証として確認する方式を推奨する（平文とハッシュは値として比較不能なため、`divergentFields` 完全一致判定＝Q4 の枠組みとも整合しない）。
- #32（メール検証・Sprint16 Retro新規起票）は現状NotReady（deferred）。実SMTP基盤・検証トークン表の着手判断が出た時点でReady昇格の要否を判断する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
