# PO 短期記憶（今スプリント）

## Sprint 20 Retro（2026-08-20）で棚卸し済み

Sprint 19 Retro以降の文脈（#38〜#41 SEC L3是正4件のRefinement2回・Sprint20計画フェーズQ&A中継12件・Sprint20 Retro本体）は本Retroで棚卸し済み。要点は `memory/po/long_term.md`（Sprint20セクション追記・傾向1〜4整理・SM verification所見等3件のPO傾向対象外判定・チェックリスト引用リストへ〔Sprint20 #39〕追記・意思決定ログ7件追記）に反映済み。

**台帳（`spec/intended-diff-ledger.md`）更新（本Retroで実施・2件）**:
- ID-25の関連Storyへ#38を追加（`#23, #24` → `#23, #24, #38`）。JWT署名鍵のdenylist（既知placeholder恒久収録）→最小鍵長32byte→ユニーク文字数24以上の3段fail-fast検証を「新」列へ追記。
- ID-11の関連Storyへ#41を追加（`#20, #13` → `#20, #13, #41`）。照合前スロット確保方式により成功ログインも枠を消費する意味論（高並行時の一過性401・`recordSuccess`のDELETEで自己回復）を「新」列へ追記。
- いずれも新規ID起票は不要（既存宣言の未達是正／実装詳細の明確化にとどまる）と判定。

**GitHub Issueクローズ状況**: #38・#39・#40・#41は実装完了・PRマージ済み・クローズ済みを確認（`mcp__github__get_issue`で個別確認）。Sprint Reviewはユーザー確認でOK・指摘ゼロ（クリーンパス）。

### 未解決の判断事項

- 確認メール（#8備考。注文確定完了時の受領メール送付）を独立の将来Feature Issue として NotReady で track するか（現状は#8備考に記録のみ。#8自体はクローズ済みだが、この将来Feature化の判断自体は未決着のため継続）。
- **#42〜#45（Phase 4 L3 SEC所見の Low 束・4件）は Ready=Draft のまま未Refinement**。#38〜#41 の Refinement は完了・Sprint 20 で実装・マージ済み。残り4件の優先順位付け・AC詳細化は次回Refinementで実施する。#42(D) は #40 AC4 のハンドラ再利用が確定済み（申し送りコメント投稿済み）。
- **`reports/after/l3-security-regression-backend.md` §1 回帰表の判定（S10「是正」・S15「消滅＋是正」・S17「消滅」）は、Sprint20で#38/#39/#41が実装・マージされたことにより実効性が回復した見込みだが、正式な回帰再実証（L3再実行）はまだ行っていない**。Phase 4 の合否ゲート（L3・L4）判定および `reports/after/verification-report.md` 作成時に、SEC側での回帰再検証結果と実装内容を突き合わせる必要がある（SM/PO の L4 作業として継続監視）。
- #32（メール検証・Sprint16 Retro新規起票）は現状NotReady（deferred）。実SMTP基盤・検証トークン表の着手判断が出た時点でReady昇格の要否を判断する。

### 次回PO稼働時のTODO

- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化、Sprint10はID-30を追記済み・Sprint9は追記なし・Sprint11はID-22の説明強化のみ追記・Sprint12は台帳追記なし・Sprint13は台帳追記なし・Sprint14は追記なし・Sprint15はID-8の説明強化のみ追記・Sprint16はID-11の拡張のみ追記・Sprint17は台帳追記なし・Sprint18はID-26の関連Story拡張＋CVE具体化のみ追記・Sprint19はID-27を更新＋ID-31を新規追加・**Sprint20（本Retroで実施）はID-25関連Story拡張〔#38・denylist+entropy実装詳細〕とID-11関連Story拡張〔#41・S1トレードオフ〕の2件を追記（新規ID起票なし）**）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列・§9集約深度・§4.2 account/profileのversion単一/二重トークン）は4セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro。Sprint13 #30・§9で3件目、Sprint16 #14・§4.2で4件目の実例追加）。architecture-conventions文書自体の一般原則firmup要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint11傾向2（監査ログACの成功/失敗粒度未定義）は初出のため、次回以降の同種Story（監査ログを扱うStory）で再発した場合、正式昇格を判断する。
- Sprint15傾向3（intended-diff-ledgerとの整合確認対象をUI表示文言のニュアンスへ拡張できないか）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint16傾向5（DTO optionalフィールドの登録画面UI表示要否が未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint17傾向1（1エンドポイント内の複数エラー系統のステータス配分＋既存クロスカット処理との衝突確認）は再発なし判定のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint18傾向「SPA保護ルートの実機到達性」は初出（Sprint19・Sprint20では未再発）のため、次回以降のSPA保護ルート系Storyで再発した場合、正式昇格を判断する。
- Sprint19傾向候補X（i18n/フォーマット系Storyの実装レベルAC未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint19傾向候補Y（新規UX追加時の既存編集導線との整合未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint19 Sprint Review指摘（#36 seed drift）はPO傾向としては追加なしと判定済み（詳細はlong_term.md参照）。次回スキーマ変更Story（既存テーブルへの列追加を伴うfeature/refactor Story）で同種のseed/fixture同期漏れが再発した場合、rules/database.md直接firmup（Sprint14型）の要否を改めて判断する。
- **Sprint20傾向候補（Q3・#38計画フェーズQ&A中継）「既存機構での充足確認判定（既存チェックリスト項目）は、Sprintの主眼がPoCトレーサビリティ資産化の場合は例外とすべき」は初出のため、次回以降の同種発生時に正式昇格を判断する。**
- **Sprint20傾向候補（B1/B2・#38/#41、同一Sprint内2件）「セキュリティ強化ACの実装が既存テスト資産〔fixture・白箱Spec〕へ波及することがAC/見積りに未織込み」は、Sprint9型の判断枠組み（同一Sprint内の複数発生は2回ルールを満たさない）により正式昇格を見送る。次回以降、別Sprintでの同種発生時に判断する。**
- **Sprint20傾向候補（S3・#40）「ACが要求する防御が別ACの入口検証によって到達不能になり検証経路が変わる」は初出のため、次回以降の同種発生時に正式昇格を判断する。**
- **Sprint20（SM verification所見・#39 AC2/AuditLogRecorder quotaチェックのbest-effort境界外配置）はPO傾向対象外と判定済み（実装完全性の問題。詳細はlong_term.md参照）。SM/DEV側のトレンド系譜での扱いに委ねる。**

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
