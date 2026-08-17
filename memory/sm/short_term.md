# SM 短期記憶（今スプリント）

Sprint 14（#9 注文履歴一覧・#10 注文詳細閲覧＝E3 read 機能・security・cross-repo 3-repo）完了。次スプリント開始時にリセット済み。

- 実装: `feature/9-order-history-detail`（3 repo 同名）。database=複合索引 `(user_id, order_id)` 追加＋単一列索引 `idx_t_order_user_id` を同一 ALTER で DROP（置換・Q1）／backend=GET /api/orders・GET /api/orders/{id} 新設（OrderRepository 経由 SELECT・OwnershipAuthorization[#21]初適用・不存在/非所有とも AccessDeniedException→同一403）／frontend=注文履歴/詳細 View・orderApi GET・Pinia・i18n（詳細は明細+合計+注文日のみ・住所非表示＝Q2）。
- 品質: **3観点クリーン（7回目相当）＋SM 独立 verification 核心クリーン＋Sprint Review OK**。tier分離14連続。DEV が Sprint12/13 perf 教訓（getOrder header 単一読み＋認可後明細）を自発適用。
- PR/マージ: frontend #7（closes #9/#10）・backend #13・database #6 → 全マージ済（frontend cc5098f で #9/#10 自動クローズ）。local main 3 repo 同期済（frontend は EOL ノイズで checkout abort→`checkout -f` で対処）。
- Retro 完了（SM/DEV/PO）。Skills 更新: **SM=変更なし**（学びは long_term）／DEV=`backend-conventions §9` に「所有者限定＋列挙対策 read は不存在も同一 AccessDeniedException(403)」新設／**PO=`rules/database.md` に「索引ハイジーン」節新設（2回ルール昇格）**。long_term 反映済。
- **要フォロー（次回）**: (1) `@Transactional(readOnly)` の read メソッド不統一（Account=有/Catalog・Order=無）を SM/DEV が収束発見・3 reviewer 4連続未検出＝次回同種発生で reviewer チェックリスト昇格 or rules 明確化を判定。(2) #9 AC/備考への「索引置換」反映を次回 Refinement でユーザー確認（PO 継続項目）。(3) local main 同期の EOL/checkout-abort 落とし穴の再発で scrum-master-workflow step 12 昇格判定。
- **次スプリント候補**: E3 の残（もしあれば）／E4 プロフィール（#13/#14）等。バックログの Sprint 15 対象は Planning 時に GitHub Projects の Sprint フィールドで特定する。

## agent-base 成果物（step 12・実施中）
- 対象: backlog/sprint_14/（sprint_backlog.md・review-#9.html・review-#10.html）／memory/{sm,dev,po}/{short_term,long_term}.md／.claude/rules/database.md／.claude/skills/backend-conventions/SKILL.md。ブランチ `docs/sprint-14-orders-inquiry`・`Related: #9, #10`（closes にしない）。
