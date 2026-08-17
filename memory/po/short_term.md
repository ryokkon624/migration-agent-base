# PO 短期記憶（今スプリント）

## Sprint 11 Retro（2026-08-17）で棚卸し済み

Sprint 10 Retro以降の文脈（Sprint11計画フェーズ〔#8 [E3]注文確定・サーバ再計算・在庫原子的引当・整合性〕でのSM/DEV確定7件）はSprint 11 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint11セクション追記〔傾向1「異常系/否定ACのHTTPステータス未定義」＝Sprint9傾向1の条件拡張・正式昇格／傾向2「監査ログACの成功/失敗粒度未定義」＝初出・傾向記録に留める／傾向3「intended-diff-ledgerの既存エントリが後続StoryのAPI/データ設計に及ぼす制約の確認」＝Sprint8傾向1の2回目・正式昇格〕・チェックリスト更新2件・意思決定ログ8件追記）に反映済み。`spec/intended-diff-ledger.md`のID-22説明文を強化済み（注文作成失敗時のresult=FAILURE記録を明記。新規差分IDの追加なし）。

### 未解決の判断事項

- #7のAC1（プリフィル住所データ源=backend `GET /api/account/me`・cross-repo新設）・スコープ境界（確定前段=#7／送信・在庫引当・永続化=#8）・ウィザード下書き保持方式（Piniaのみ・揮発）・API命名（`AccountController`等）・空カート誘導UX（`/cart?reason=empty-checkout`）・ルート構成（`/checkout`単一ルート）を、次回RefinementでAC/備考へ反映するかユーザーに確認する。
- #8のAC-neg/AC6/備考へ、Sprint11計画フェーズで確定した5点（在庫競合409・空カート409・完了画面スコープ最小化・価格変動時再計算値確定・監査ログ成功/失敗両方記録）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- 確認メール（#8備考）を独立の将来Feature Issue として NotReady で track するか（現状は #8 備考に記録のみ）。
- #23のAC/備考への先回り明記（スコープ境界・実証手段・監査ログ範囲・秘密管理方針・他repo連携方式）は次回Refinementでユーザーに確認のうえ反映する（Sprint2 Retro以降継続未着手。#23は実装済みのため優先度低）。
- #8 の SP=8 は本移行の目玉Story（同時/二重発注の売り越し防止テスト等）で見積り上振れリスクあり。実装フェーズで並行テスト負荷が重いと判明すれば13への引き上げを検討する。
- #1のAC3/備考へ、Sprint6計画フェーズで確定した3点（残少閾値N=5・在庫ステータスm_code方式・ページ1-index）を反映するかは次回Refinementでユーザーに確認のうえ判断する（現状は`sprint_backlog.md`承認済み計画セクションのみに反映）。
- #2のAC1「カテゴリフィルタは任意（PO決定）」の確定値（今スプリントで実装＝API `categoryId`任意＋UIカテゴリ選択）と、検索語LIKEメタ文字（`%`/`_`）のハードニング仕様（リテラル化・ESCAPE併用）をAC/備考へ反映するかは次回Refinementでユーザーに確認のうえ判断する（`spec/intended-diff-ledger.md`のID-29登録はSprint7 Retroで完了済み。Issue #2本体のAC/備考更新のみ未着手）。
- #4のAC5/AC-neg1または備考へ、未ログインカートの在庫上限検証手段（`GET /api/items/{itemId}/orderable?quantity=N`・qty非露出維持）を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD1で決定）。
- #4のAC3備考へ、カート画面ルートが公開（`meta.requiresAuth`なし）・認証必須は`/api/cart/**` APIのみである旨を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD2で決定）。

### 次回PO稼働時のTODO

- 残りの Ready昇格＋SP付与: #13〜#17（E4）＋#26（E6依存版currency）。#27（refactor・SP1・Draft）はスプリント差し込み時にReady昇格。
- 確認メール（#8備考）の将来Feature化（Issue起票 or ドロップ）の判断。
- #23のAC/備考へ、Sprint2質問ログで判明した5観点（スコープ境界・実証手段・監査ログ範囲・秘密管理・他repo連携）を反映（着手可否含め次回Refinementで判断）。
- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化、Sprint10はID-30を追記済み・Sprint9は追記なし〔SBD-2/17は既存維持項目のため台帳対象外と判定〕・Sprint11はID-22の説明強化のみ追記〔新規差分IDの追加なし〕）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列）は2セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro）。architecture-conventions文書自体の一般原則firmup（個別確認を減らす明文化）要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint11傾向2（監査ログACの成功/失敗粒度未定義）は初出のため、次回以降の同種Story（監査ログを扱うStory）で再発した場合、正式昇格を判断する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
