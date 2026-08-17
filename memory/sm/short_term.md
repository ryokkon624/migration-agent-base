# SM 短期記憶（今スプリント）

Sprint 13（#30 Repository 層を Catalog/Account/Order へ展開＝refactor・SP8・backend 単一 repo）完了。次スプリント開始時にリセット済み。

- 実装: 新規ブランチ `refactor/30-repository-rollout`（3コミット・24ファイル・database ノータッチ）。#29 テンプレを Catalog/Account/Order へ横展開し **Mapper 直呼び全廃**（Application 層の `infrastructure.mybatis` import：Order 8→0/Catalog 5→0/Account 2→0・Auth 除く全 Service 0 件）。Repository 移行は #29+#30 で完了。
- 確定した設計（ユーザー承認）: **Q1=案A**（Order は rich 集約化せず #8 並行オーケストレーションを Application 残置・最小 write record `NewOrder`/`OrderLine`）／**Q2=統一 `...Repository` 命名**（read も Repository・意味論は CQRS 射影のまま・ユーザーオーバーライド）／**Q3=新規 `domain/inventory`**。O3=`CartRepository#clearItems` 追加・Order は `ensureCart`/`findByCartId`（ORDER BY item_id）再利用。
- **品質ハイライト**: 3観点 reviewer 全員クリア＋**SM verification（Order/Catalog/Account 精読）も全クリーン**。#29 と違い SM も perf 純増を検出せず＝**DEV が Sprint12 教訓（findByCartId 再利用でクエリ数純増回避）を自発適用**＋#29 テンプレ無改造横展開（C2 実効性検証成功）。#8 並行保証維持・ID-28 非露出・IDOR 安全を確認。
- PR: backend **#12**（closes #30）→ **マージ済**（merge commit b95159b）。Issue #30 自動クローズ。Sprint Review 指摘なし（「OK」）。
- Retro 完了（SM/DEV/PO）。Skills 更新: **SM=`scrum-master-workflow` に step 12 追記**（agent-base 毎スプリントコミット標準化・ユーザー指示）／DEV=`backend-conventions §9` に「書込集約の適用範囲（rich 集約 vs 薄い書込 record・Cart/Order の判断軸）」追記・Spock 罠3回目は §9 昇格済で棚卸し／PO=質問傾向引用追記（判断委譲3件目・先例規約未定義4/5件目）。長期記憶反映済。
- agent-base 成果物: **step 12 に沿ってブランチ切ってコミット＆PR＆マージ（実施中）**。
- **次スプリント候補**: E3 継続 **#9/#10（注文照会・履歴一覧・詳細閲覧）**。#8 の注文ドメイン基盤（`OrderRepository`/t_order/t_order_line）を再利用。**IDOR 対策（プリンシパル基準・not-owned/not-found 同一応答＝ID-4/SBD-8）が中核**。Repository 移行完了により**新規 Story は最初から Repository 経由**（運用ルール）＝#9/#10 Refinement 時に AC/備考へ反映（PO 申し送り済）。
