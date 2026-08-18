# PO 短期記憶（今スプリント）

## Sprint 19 Retro（2026-08-18）で棚卸し済み

Sprint 18 Retro以降の文脈（DEV→ユーザー中継2件〔#25 AC3実装レベル・#25/#36 UI整合〕）はSprint 19 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint19セクション追記〔傾向候補X/Y・いずれも初出のため正式昇格見送り〕・意思決定ログ追記）に反映済み。傾向学習自体はteam-lead依頼によりSprint19中に先行記録済みだったため、本Retroでは2回ルールの再判定（再発なし・判定据え置き）と、team-lead依頼分の追加論点（Sprint Review指摘＝#36 seed drift〔`R__test_user.sql`更新漏れ〕のPO傾向記録要否）を判定・実施した。seed drift事象は「AC記述ギャップ」ではなく実装/DoD完全性の問題と判定し、PO内チェックリストへの追加は見送った（SM/DEV側の既存トレンド系譜〔`memory/sm/long_term.md`〕に委ねる）。

**GitHub Issueクローズ状況の整理（本Retroで`mcp__github__list_issues` state:openにて確認）**: 現在openなのは**#32（メール検証・NotReady/deferred）のみ**。#36（テーマ切替）・#25（日本語ローカライズ）・#37（HomeViewトークンスロット撤去）・#35（.gitattributes）はいずれもクローズ済み。

### 未解決の判断事項

- 確認メール（#8備考。注文確定完了時の受領メール送付）を独立の将来Feature Issue として NotReady で track するか（現状は#8備考に記録のみ。#8自体はクローズ済みだが、この将来Feature化の判断自体は未決着のため継続）。
- #32（メール検証・Sprint16 Retro新規起票）は現状NotReady（deferred）。実SMTP基盤・検証トークン表の着手判断が出た時点でReady昇格の要否を判断する。

### 次回PO稼働時のTODO

- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化、Sprint10はID-30を追記済み・Sprint9は追記なし・Sprint11はID-22の説明強化のみ追記・Sprint12は台帳追記なし・Sprint13は台帳追記なし・Sprint14は追記なし・Sprint15はID-8の説明強化のみ追記・Sprint16はID-11の拡張のみ追記・Sprint17は台帳追記なし・Sprint18はID-26の関連Story拡張＋CVE具体化のみ追記・**Sprint19（本Retroで実施）はID-27を更新（#25の日本語ローカライズ完了・実装レベル確定値を反映）＋ID-31を新規追加（#36テーマ切替＝legacyに比較対象概念自体が無い新規UX、ID-28型の扱い）**）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列・§9集約深度・§4.2 account/profileのversion単一/二重トークン）は4セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro。Sprint13 #30・§9で3件目、Sprint16 #14・§4.2で4件目の実例追加）。architecture-conventions文書自体の一般原則firmup要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint11傾向2（監査ログACの成功/失敗粒度未定義）は初出のため、次回以降の同種Story（監査ログを扱うStory）で再発した場合、正式昇格を判断する。
- Sprint15傾向3（intended-diff-ledgerとの整合確認対象をUI表示文言のニュアンスへ拡張できないか）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint16傾向5（DTO optionalフィールドの登録画面UI表示要否が未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint17傾向1（1エンドポイント内の複数エラー系統のステータス配分＋既存クロスカット処理との衝突確認）は再発なし判定のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint18傾向「SPA保護ルートの実機到達性」は初出（Sprint19では未再発）のため、次回以降のSPA保護ルート系Storyで再発した場合、正式昇格を判断する。
- **Sprint19傾向候補X（i18n/フォーマット系Storyの実装レベルAC未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。**
- **Sprint19傾向候補Y（新規UX追加時の既存編集導線との整合未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。**
- **Sprint19 Sprint Review指摘（#36 seed drift）はPO傾向としては追加なしと判定済み（詳細はlong_term.md参照）。次回スキーマ変更Story（既存テーブルへの列追加を伴うfeature/refactor Story）で同種のseed/fixture同期漏れが再発した場合、rules/database.md直接firmup（Sprint14型）の要否を改めて判断する。**

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
