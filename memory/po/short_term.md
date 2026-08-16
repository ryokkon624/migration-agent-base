# PO 短期記憶（今スプリント）

## Sprint 8 Retro（2026-08-16）で棚卸し済み

Sprint 7 Retro以降の文脈（Sprint8計画フェーズ〔#4 カート追加/数量更新/削除/表示〕でのDEV→ユーザー確認3件〔D1 匿名カートの在庫上限検証・D2 カート画面のルート保護境界・D3 `t_cart_item`のversion列〕、Epic E2着手・3-repo cross-repo）はSprint 8 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint8セクション追記・チェックリスト2件正式昇格〔新ドメインfeature全般のUI配置/保護境界・architecture-conventionsのPO判断委譲箇所〕・意思決定ログ5件追記〔サーバーカート永続スコープ・マージ数量意味論・D1/D2/D3の決定〕・`spec/intended-diff-ledger.md` ID-19具体化〔数量加算・在庫クランプ〕）に反映済み。

### 未解決の判断事項

- 確認メール（#8備考）を独立の将来Feature Issue として NotReady で track するか（現状は #8 備考に記録のみ）。
- #23のAC/備考への先回り明記（スコープ境界・実証手段・監査ログ範囲・秘密管理方針・他repo連携方式）は次回Refinementでユーザーに確認のうえ反映する（Sprint2 Retro以降継続未着手。#23は実装済みのため優先度低）。
- #8 の SP=8 は本移行の目玉Story（同時/二重発注の売り越し防止テスト等）で見積り上振れリスクあり。Planningで並行テスト負荷が重いと判断されれば13へ引き上げを検討。
- #1のAC3/備考へ、Sprint6計画フェーズで確定した3点（残少閾値N=5・在庫ステータスm_code方式・ページ1-index）を反映するかは次回Refinementでユーザーに確認のうえ判断する（現状は`sprint_backlog.md`承認済み計画セクションのみに反映）。
- #2のAC1「カテゴリフィルタは任意（PO決定）」の確定値（今スプリントで実装＝API `categoryId`任意＋UIカテゴリ選択）と、検索語LIKEメタ文字（`%`/`_`）のハードニング仕様（リテラル化・ESCAPE併用）をAC/備考へ反映するかは次回Refinementでユーザーに確認のうえ判断する（`spec/intended-diff-ledger.md`のID-29登録はSprint7 Retroで完了済み。Issue #2本体のAC/備考更新のみ未着手）。
- #4のAC5/AC-neg1または備考へ、未ログインカートの在庫上限検証手段（`GET /api/items/{itemId}/orderable?quantity=N`・qty非露出維持）を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD1で決定）。
- #4のAC3備考へ、カート画面ルートが公開（`meta.requiresAuth`なし）・認証必須は`/api/cart/**` APIのみである旨を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD2で決定）。

### 次回PO稼働時のTODO

- 残りの Ready昇格＋SP付与: #9〜#17（E3後半・E4）＋#26（E6依存版currency）。#27（refactor・SP1・Draft）はスプリント差し込み時にReady昇格。
- 確認メール（#8備考）の将来Feature化（Issue起票 or ドロップ）の判断。
- #23のAC/備考へ、Sprint2質問ログで判明した5観点（スコープ境界・実証手段・監査ログ範囲・秘密管理・他repo連携）を反映（着手可否含め次回Refinementで判断）。
- Sprint5傾向2（フロント土台起票時のbackend API過不足未確認によるcross-repo追加）が次回以降のStoryで再発した場合、正式昇格を判断する。
- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化を追記済み）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列）は2セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro）。architecture-conventions文書自体の一般原則firmup（個別確認を減らす明文化）要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint8傾向1（先行スプリントのintended-diff-ledgerエントリが後続StoryのAPI設計に及ぼす制約の未参照。D1）は初出のため、次回以降の同種発生時に正式昇格を判断する。Refinement/計画フェーズで対象Storyに関連するledgerエントリを確認する運用の要否も併せて検討する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
