# PO 短期記憶（今スプリント）

## Sprint 10 Retro（2026-08-16）で棚卸し済み

Sprint 9 Retro以降の文脈（Sprint10計画フェーズ〔#7 [E3]チェックアウト・ウィザード〕でのSM確定3件・DEV確定4件、計7件）はSprint 10 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint10セクション追記〔傾向1「機能Storyが依存する上流Feature未着手によるcross-repo追加」＝Sprint5傾向2の2回目の発生・正式昇格（範囲をフロント土台Story限定→機能Story一般へ拡張）／傾向2「新ドメインfeature全般の異常系UI遷移未定義」＝Sprint7/Sprint8で昇格済み項目の3回目の再発・記述強化〕・チェックリスト更新2件・意思決定ログ6件追記）に反映済み。`spec/intended-diff-ledger.md`にID-30（チェックアウト・ウィザードの下書き保持方式。legacy session `workingOrderForm`永続→新Pinia揮発）を追記済み。

### 未解決の判断事項

- #7のAC1（プリフィル住所データ源=backend `GET /api/account/me`・cross-repo新設）・スコープ境界（確定前段=#7／送信・在庫引当・永続化=#8）・ウィザード下書き保持方式（Piniaのみ・揮発）・API命名（`AccountController`等）・空カート誘導UX（`/cart?reason=empty-checkout`）・ルート構成（`/checkout`単一ルート）を、次回RefinementでAC/備考へ反映するかユーザーに確認する。
- 確認メール（#8備考）を独立の将来Feature Issue として NotReady で track するか（現状は #8 備考に記録のみ）。
- #23のAC/備考への先回り明記（スコープ境界・実証手段・監査ログ範囲・秘密管理方針・他repo連携方式）は次回Refinementでユーザーに確認のうえ反映する（Sprint2 Retro以降継続未着手。#23は実装済みのため優先度低）。
- #8 の SP=8 は本移行の目玉Story（同時/二重発注の売り越し防止テスト等）で見積り上振れリスクあり。Planningで並行テスト負荷が重いと判断されれば13へ引き上げを検討。
- #1のAC3/備考へ、Sprint6計画フェーズで確定した3点（残少閾値N=5・在庫ステータスm_code方式・ページ1-index）を反映するかは次回Refinementでユーザーに確認のうえ判断する（現状は`sprint_backlog.md`承認済み計画セクションのみに反映）。
- #2のAC1「カテゴリフィルタは任意（PO決定）」の確定値（今スプリントで実装＝API `categoryId`任意＋UIカテゴリ選択）と、検索語LIKEメタ文字（`%`/`_`）のハードニング仕様（リテラル化・ESCAPE併用）をAC/備考へ反映するかは次回Refinementでユーザーに確認のうえ判断する（`spec/intended-diff-ledger.md`のID-29登録はSprint7 Retroで完了済み。Issue #2本体のAC/備考更新のみ未着手）。
- #4のAC5/AC-neg1または備考へ、未ログインカートの在庫上限検証手段（`GET /api/items/{itemId}/orderable?quantity=N`・qty非露出維持）を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD1で決定）。
- #4のAC3備考へ、カート画面ルートが公開（`meta.requiresAuth`なし）・認証必須は`/api/cart/**` APIのみである旨を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD2で決定）。

### 次回PO稼働時のTODO

- **2026-08-16 Refinement完了**: #9〜#12（E3後半 F3.3〜F3.6）をReady昇格＋SP付与（#9=3/#10=5/#11=2/#12=3）。full-stack（Vue画面+REST）スコープで確定。先回り明記＝#9ページング先例(PageResponse/1-index/size12・cap100)＋認証必須ルート、#10 AC3を403統一に確定＋認証必須、#11 remoting面は新backendに構造的不在＝既達（SBD-9型・回帰テスト固定）、#12 DBカード列は#22で既達（残=DTO/API確認＋frontend表示）。台帳追記不要（#10=ID-24・#12=ID-8 既登録）。**ユーザー手動残作業: 対象Sprintのassignと優先順位並び替え。**
- 残りの Ready昇格＋SP付与: #13〜#17（E4）＋#26（E6依存版currency）。#27（refactor・SP1・Draft）はスプリント差し込み時にReady昇格。
- 確認メール（#8備考）の将来Feature化（Issue起票 or ドロップ）の判断。
- #23のAC/備考へ、Sprint2質問ログで判明した5観点（スコープ境界・実証手段・監査ログ範囲・秘密管理・他repo連携）を反映（着手可否含め次回Refinementで判断）。
- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化、Sprint10はID-30を追記済み・Sprint9は追記なし〔SBD-2/17は既存維持項目のため台帳対象外と判定〕）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列）は2セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro）。architecture-conventions文書自体の一般原則firmup（個別確認を減らす明文化）要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint8傾向1（先行スプリントのintended-diff-ledgerエントリが後続StoryのAPI設計に及ぼす制約の未参照。D1）は初出のため、次回以降の同種発生時に正式昇格を判断する。Refinement/計画フェーズで対象Storyに関連するledgerエントリを確認する運用の要否も併せて検討する。
- Sprint9傾向1（security hardening Storyにおける否定AC実装レベル論点＝エラー正規化ハンドラ配置・Cookieセキュリティ属性設定方式・検証層配置）は初出のため、次回以降の同種Story（既存feature/APIへの後乗せ的なセキュリティ強化Story）で再発した場合、正式昇格を判断する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
