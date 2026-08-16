# SM 短期記憶（今スプリント）

Sprint 8（#4 [E2] カート追加/数量更新/削除/表示・SP8・feature＝**Epic E2 初回 Story・3-repo cross-repo**）完了。次スプリント開始時にリセット済み。

- 実装: **database**（V00_000_010 `t_cart`/`t_cart_item`・version なし・単一表+UNIQUE で幽霊行 ID-17 構造的是正）＋**backend**（Cart ドメイン・CartCustomMapper+XML〔在庫JOIN・加算UPSERT〕・CartApplicationService〔在庫上限=在庫数 server強制・在庫切れ不可・qty≤0削除・小計サーバ計算・マージ加算+クランプ〕・CartController 4EP+merge・orderable EP・SecurityConfig 無変更・IDOR面ゼロ設計）＋**frontend**（cartStorage〔localStorage 初導入〕・cart store〔false→true で1回マージ〕・cartApi・CartView 公開ルート・AppHeader バッジ・ItemDetail・i18n）。
- **SM 計画フェーズ確定（AskUserQuestion）**: 永続方式=**DB永続3-repo**／マージ=**数量加算・在庫クランプ**（台帳 ID-19 具体化）／qty 非露出（ID-28）維持で在庫上限 server強制／カート画面=公開ルート（D2）／t_cart_item version なし（D3）。計画前 Explore で「サーバーカート永続基盤 皆無」を発見→3-repo 確定。
- **3観点レビュー**: conv 指摘なし・**sec 1件（中・addItem 数量下限バリデーション欠落=SBD-2）→ ea9102b で修正〔@Min(1)＋サービス層拒否＋Math.addExact〕→delta 再レビューで解消確認**・perf 軽微2件（非ブロッキング）。
- **PR/マージ**: 3-repo 同名ブランチ `feature/4-cart-operations`。SM トークン URL push（GCM 回避）。frontend PR#4（closes #4）・backend PR#7・database PR#5（各 Related）→ **3-repo マージ済・Issue #4 closed(completed)**。Sprint Review 指摘なし（クリーン）。
- Retro 完了（DEV/PO/SM）。**教訓は long_term 反映済**: tier分離8連続・初 write ドメインでも通用／C1 先例再利用成功（SecurityConfig 無変更・IDOR面ゼロ）／計画前調査で永続基盤皆無→3-repo／**spec 委譲論点 SM 計画確定が4連続→scrum-master-workflow ① へ正式昇格（実施済）**／sec の「同種メソッド群の検証一貫性の抜け」教訓／perf 軽微の非ブロッキング継続。SM Skills: scrum-master-workflow ① 昇格。DEV: frontend-conventions §7 localStorage 追記（backend は初出で 2回ルール据え置き）。PO: 台帳 ID-19 具体化・チェックリスト2昇格。
- **agent-base `feature/sprint8`: Retro 完了後に PR＆マージ**（このリセット時点で処理中／ユーザー指示 2026-08-16「PR はマージして OK」）。コミット: Planning(sprint_backlog.md)・Review(review-#4.html)・implementation-notes.md＋Retro 成果物（memory dev/po/sm・spec ledger・scrum-master-workflow ① 昇格・frontend-conventions §7）。
- 次スプリント候補: **E2 初回完了**につき E3（注文＝checkout ウィザード・在庫原子減算 D6・カート連携・在庫充足の実強制）へ。カート土台（t_cart/t_cart_item・CartApplicationService・orderable EP・localStorage パターン）を注文導線で再利用・接続。
