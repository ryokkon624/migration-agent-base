# SM 短期記憶（今スプリント）

Sprint 11（#8 [E3] 注文確定・在庫の原子的引当・整合性＝F3.2・SP8・security/E3）完了。次スプリント開始時にリセット済み。

- 実装: cross-repo `feature/8-order-placement`（**backend 主**=注文ドメイン一式〔OrderController/OrderApplicationService/domain/order/InsufficientStockException→409/custom mapper・entity/在庫ガード減算 `qty>=:n`/カート全クリア/AuditLogRecorder の REQUIRES_NEW 失敗監査〕＋**frontend 従**=orderApi/order store/CheckoutConfirmStep 配線/CheckoutCompleteView 最小/cart clearAfterOrder/i18n）。**database ノータッチ（全既達）**。
- **3観点クリーン（6回目・初の書込系トランザクション×並行制御でも通用）**。計画前 Explore 3-repo でスコープ縮小（3→2-repo）＋spec委譲論点の**2段階確定**（SM計画前3件〔在庫不足409/完了画面最小/価格変動そのまま確定〕＋DEV報告後エッジ論点の再 AskUserQuestion〔空カート409/**Q3 監査の成功·失敗両方＝REQUIRES_NEW をユーザーオーバーライド**〕）＋否定AC実DB実証（2スレッド同時発注で売り越さない・totalPrice/username フィールド不在で構造的担保）＋意図的設計 reviewer 明記で churn ゼロ。tier分離11連続・手戻りゼロ。
- PR: backend #10（主・closes #8）＋frontend #6（従・Related）→ **両マージ済・Issue #8 completed クローズ**。
- Sprint Review 指摘なし。Retro 完了（SM/DEV/PO）。Skills 更新: SM=変更なし（long_term 止まり）／DEV=`backend-conventions §9` に REQUIRES_NEW 独立監査記録パターン新設／PO=先回りチェックリスト2件昇格（異常系HTTPステータス先回り／台帳既存エントリ確認）・`intended-diff-ledger` ID-22 説明文強化。長期記憶反映済。
- agent-base 成果物: レトロ完了時にブランチ切ってコミット＆PR＆マージ（ユーザー指示・**実施中**）。
- **次スプリント候補**: E3 継続 → **#9/#10（注文照会・履歴一覧・詳細閲覧）**。#8 の注文ドメイン基盤（`OrderCustomMapper`/`domain/order`・t_order/t_order_line）を再利用。**IDOR 対策（プリンシパル基準・not-owned/not-found 同一応答＝ID-4/SBD-8）が #9/#10 中核**。ID-24（履歴経由の商品名表示）は #10。
