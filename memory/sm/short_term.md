# SM 短期記憶（今スプリント）

Sprint 7（#3 F1.3 参照堅牢化/出力安全化・SP3・security／#2 F1.2 商品検索・SP5・feature＝**Epic E1 カタログ完成**・**2-repo cross-repo**）完了。次スプリント開始時にリセット済み。

- 実装: **backend**（#3=`GlobalExceptionHandler` に例外3ハンドラ〔型不一致→400/必須param欠落→400/未知パス→404〕・型不一致のみ400で範囲外はクランプ空200／#2=`GET /api/products/search`・純VO `ProductSearchTerms`〔語分割+LIKEメタ文字エスケープ=ID-29〕・`CatalogCustomMapper.xml` searchProducts/countSearchProducts〔語分割 OR・`ESCAPE '\'`・全#{}〕・permitAll は既存 `/api/products/**` GET で自動カバー＝SecurityConfig 変更不要）＋**frontend**（#2=ヘッダ検索バー・`SearchResultView`・route・api/store・カテゴリフィルタ〔結果画面配置〕・i18n／#3=SBD-18回帰・stale頁送り正規化）。
- ユーザー確定2決定（SM 計画フェーズ AskUserQuestion）: **LIKE メタ文字 `%`/`_`=ハードニング〔リテラル化・ESCAPE〕→ID-29 台帳登録済／カテゴリフィルタ=実装**。SM 実地調査で **seed 投入済→2-repo に縮小**（Sprint6 の 3-repo の逆）を計画時点で確定。
- 3観点レビュー **conv/sec 指摘なし・perf 軽微2件（非ブロッキング・SM verification 済→再修正なし）**。Sprint6 同型クリーンパス。PR: backend #6(closes #3)・frontend #3(closes #2)＝**各 Issue の closes を capstone repo に分散**。同時マージで #2/#3 とも closed（completed）確認。Sprint Review 指摘なし。
- Retro 完了（DEV/PO/SM）。教訓は long_term 反映済（tier分離7連続・Epic完成でも通用／計画前調査の縮小方向〔2-repo〕／複数Issue cross-repo closes 分散／spec委譲論点確定が Sprint5/6/7 で3連続定着＝次回で workflow ① 昇格判定／catch-all 例外ハンドラ取りこぼしが Sprint3→7 で2回目→DEV が backend-conventions §9 昇格／先例再利用でクリーンパス〔C1 成功〕／perf 軽微の非ブロッキング判定で過剰対応回避）。DEV: backend-conventions §9 に2点。PO: ID-29 追加・質問傾向2件初出記録。
- **agent-base `feature/sprint7`: Retro 完了後に PR＆マージ**（このリセット時点で PR＆マージ処理中／ユーザー指示 2026-08-16）。コミット: Planning(sprint_backlog.md)・Review(review-#2/#3.html)＋Retro 成果物（memory/spec 更新）。
- 次スプリント候補: **E1 完了**につき E2（カート）・E3（注文）等の次 Epic へ。#1 が確立し #2/#3 が再利用実証した先例（ページDTO・カードグリッド部品・在庫バッジ・m_code・例外正規化基盤・検索/VO パターン）を別ドメインで再検証。perf 微最適化（検索画面カテゴリ既ロード時 fetch スキップ）は低優先・issue化見送り。
