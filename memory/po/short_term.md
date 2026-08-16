# PO 短期記憶（今スプリント）

## Sprint 7 Retro（2026-08-16）で棚卸し済み

Sprint 6 Retro以降の文脈（Sprint7計画フェーズ〔#2 検索・カテゴリフィルタ〕でのSM→ユーザー確認2件〔LIKEメタ文字ハードニング／AC1カテゴリフィルタ実装要否〕・DEV→ユーザー確認5件〔検索APIパス・カテゴリフィルタUI配置・検索対象列・不正categoryId時HTTPステータス・EOL差分整理〕、Epic E1完成でのSprint7マージ）はSprint 7 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint7セクション追記・意思決定ログ6件追記〔LIKEハードニング・AC1実装確定・検索APIパス・フィルタUI配置・検索対象列・不明categoryId時挙動〕・`spec/intended-diff-ledger.md` ID-29追加）に反映済み。チェックリストの新規正式昇格は無し（既存項目「先例規約未定義」の3回目再発を確認・2件は初出のため次回以降の再発時に判断）。

### 未解決の判断事項

- 確認メール（#8備考）を独立の将来Feature Issue として NotReady で track するか（現状は #8 備考に記録のみ）。
- #23のAC/備考への先回り明記（スコープ境界・実証手段・監査ログ範囲・秘密管理方針・他repo連携方式）は次回Refinementでユーザーに確認のうえ反映する（Sprint2 Retro以降継続未着手。#23は実装済みのため優先度低）。
- #8 の SP=8 は本移行の目玉Story（同時/二重発注の売り越し防止テスト等）で見積り上振れリスクあり。Planningで並行テスト負荷が重いと判断されれば13へ引き上げを検討。
- #1のAC3/備考へ、Sprint6計画フェーズで確定した3点（残少閾値N=5・在庫ステータスm_code方式・ページ1-index）を反映するかは次回Refinementでユーザーに確認のうえ判断する（現状は`sprint_backlog.md`承認済み計画セクションのみに反映）。
- #2のAC1「カテゴリフィルタは任意（PO決定）」の確定値（今スプリントで実装＝API `categoryId`任意＋UIカテゴリ選択）と、検索語LIKEメタ文字（`%`/`_`）のハードニング仕様（リテラル化・ESCAPE併用）をAC/備考へ反映するかは次回Refinementでユーザーに確認のうえ判断する（`spec/intended-diff-ledger.md`のID-29登録はSprint7 Retroで完了済み。Issue #2本体のAC/備考更新のみ未着手）。

### 次回PO稼働時のTODO

- 残りの Ready昇格＋SP付与: #9〜#17（E3後半・E4）＋#26（E6依存版currency）。#27（refactor・SP1・Draft）はスプリント差し込み時にReady昇格。
- 確認メール（#8備考）の将来Feature化（Issue起票 or ドロップ）の判断。
- #23のAC/備考へ、Sprint2質問ログで判明した5観点（スコープ境界・実証手段・監査ログ範囲・秘密管理・他repo連携）を反映（着手可否含め次回Refinementで判断）。
- Sprint5傾向2（フロント土台起票時のbackend API過不足未確認によるcross-repo追加）が次回以降のStoryで再発した場合、正式昇格を判断する。
- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29を追記済み）。
- architecture-conventions §3.1「区分値は基本的にm_codeに登録する」の一般方針としてのfirmup要否は、同種の質問（区分値のm_code/enum判断で確認が発生するケース）が次回以降再発した場合に判断する（Sprint6が初出のため引き続き見送り）。
- Sprint7傾向2（検索/フィルタ系featureのUI配置・検索対象範囲・異常系レスポンス未定義）とSprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
