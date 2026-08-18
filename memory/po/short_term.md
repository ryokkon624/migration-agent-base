# PO 短期記憶（今スプリント）

## Sprint 18 Retro（2026-08-18）で棚卸し済み

Sprint 17 Retro以降の文脈（DEV→ユーザー中継1件〔#34 Q1 UI配置委譲論点〕）はSprint 18 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint18セクション追記・意思決定ログ追記・チェックリスト引用リスト＋説明文へ〔Sprint18 #34〕追記・intended-diff-ledger.mdのID-26拡張）に反映済み。team-lead依頼分（Q1=案A-1確定・#26スコープdatabase限定確定・#34 AC4畳み込み 等の意思決定ログ反映／ledger追記要否判定／チェックリスト昇格判定）も本Retroで判定・実施済み。

**GitHub Issueクローズ状況の整理（本Retroで`mcp__github__list_issues`state:openにて確認）**: 現在openなのは#32（メール検証・NotReady）・#25（日本語ローカライズ・NotReady）・**#31（backend null type safety・Sprint18で実装完了・レビュー済みだが未クローズ）**の3件のみ。Sprint17 Retro時点で保留していた#15（PW変更AC-neg1の422反映判断）は本Retロ時点でクローズ済みと確認できたため、Sprint16 Retroで確立した先例（「issue close後のAC反映TODOは対象外」）に倣い、以下の未解決リストから除外した。#33/#34/#26/#27もクローズ済み。

### 未解決の判断事項

- 確認メール（#8備考。注文確定完了時の受領メール送付）を独立の将来Feature Issue として NotReady で track するか（現状は#8備考に記録のみ。#8自体はクローズ済みだが、この将来Feature化の判断自体は未決着のため継続）。
- #32（メール検証・Sprint16 Retro新規起票）は現状NotReady（deferred）。実SMTP基盤・検証トークン表の着手判断が出た時点でReady昇格の要否を判断する。

### 次回PO稼働時のTODO

- #31（backend null type safety警告）はSprint18でReady+SP付与済み・実装完了・レビュー済み（`backlog/sprint_18/sprint_backlog.md`・review-#31.html）だが、本Retro時点のGitHub Issue上ではまだopen。次回POサイクルでクローズ済みを確認する（他4件〔#33/#34/#27/#26〕は既にクローズ確認済み）。
- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化、Sprint10はID-30を追記済み・Sprint9は追記なし〔SBD-2/17は既存維持項目のため台帳対象外と判定〕・Sprint11はID-22の説明強化のみ追記〔新規差分IDの追加なし〕・Sprint12は台帳追記なし〔#28〜30/D1/D2はいずれもAPI仕様・レスポンス形状に影響しない内部実装リファクタと判定〕・Sprint13は台帳追記なし〔#30はQ1〜Q3含めAPI仕様・レスポンス形状不変の内部リファクタと判定〕・Sprint14は追記なし・Sprint15はID-8の説明強化のみ追記〔新規差分IDの追加なし。#28は挙動不変のためAC上も台帳対象外と判定〕・Sprint16はID-11の拡張のみ追記〔新規差分IDの追加なし。メール検証プレースホルダは実装差分が生じていないため台帳対象外と判定・別Issue #32へ分離〕・Sprint17は台帳追記なし〔#15/16/17はいずれも既存security-baseline宣言（SBD-16/SBD-3/SBD-5）の実装・既達確認の範疇で新規の観測可能差分エントリを要しないと判定〕・Sprint18はID-26の関連Story拡張＋CVE具体化（`mysql-connector-j` CVE-2023-22102・8.0.33→26.7.0）のみ追記〔新規差分IDの追加なし。#33/#34は出荷済みfeatureの実装完全性を復旧する不具合修正（legacyに比較対象概念自体が無い）・#27/#31は挙動不変が明示された内部実装/ビルド設定リファクタと判定し、いずれも台帳対象外〕）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列・§9集約深度・§4.2 account/profileのversion単一/二重トークン）は4セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro。Sprint13 #30・§9で3件目、Sprint16 #14・§4.2で4件目の実例追加）。architecture-conventions文書自体の一般原則firmup（個別確認を減らす明文化）要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint11傾向2（監査ログACの成功/失敗粒度未定義）は初出のため、次回以降の同種Story（監査ログを扱うStory）で再発した場合、正式昇格を判断する。
- Sprint15傾向3（intended-diff-ledgerとの整合確認対象をUI表示文言のニュアンスへ拡張できないか）は初出のため、次回以降の同種発生時（既存ledger決定とUI表示文言のニュアンスの不整合）に正式昇格を判断する。
- Sprint16傾向5（DTO optionalフィールドの登録画面UI表示要否が未定義）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint17傾向1（1エンドポイント内の複数エラー系統のステータス配分＋既存クロスカット処理との衝突確認）は再発なし判定のため、次回以降の同種発生時（複数失敗理由が1エンドポイントに同居する状態変更APIを扱うStory）に正式昇格を判断する。
- Sprint18傾向「SPA保護ルートの実機到達性（リロード/直リンク/導線配線がAC/受入検証から漏れやすい）」は初出（発生源が#33/#34自体のため本Retro時点で再発観測なし）のため、次回以降のSPA保護ルート系Storyで同種（再水和タイミング・ナビ導線配線の未検証）が再発した場合、正式昇格を判断する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
