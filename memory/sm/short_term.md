# SM 短期記憶（今スプリント）

Sprint 15（#11 remoting/WS getOrder 廃止の実証・#12 支払プレースホルダ確定・#28 カートマージ N+1 バッチ化＝E3 残セキュリティ/支払＋E2 perf・cross-repo 2-repo）完了。Retro 済み。次スプリント開始時にリセット済み。

- 実装: `feature/12-e3-hardening-cart-perf`（backend/frontend 同名）。backend 3コミット（#28 e34f6f8・#11 980413a・#12 92a6576）・frontend 1コミット（#12 cfb72eb）。全テスト green。
- 品質: **3観点＋SM verification 全クリーン（8回目相当）・Sprint Review 指摘ゼロ・tier分離15連続**。3件とも「既達判定」から出発し計画前 Explore で残スコープ最小化＝過剰実装回避。
- PR/マージ: backend #14（closes #11/#28・Related #12）・frontend #8（closes #12）→ **マージはユーザー確認済 Sprint Review 後の通常フロー**（本セッションでは PR 作成まで。マージ状態は次回要確認）。
- 委譲論点2ラウンド確定（SM 先回り Q1-Q3＋DEV 実コード精読後 Q2'/Q3'）→ churn ゼロ。DEV がバックログ2前提（localStorage=map・型残骸=孤立）の誤りを撤去前確認で訂正→**#12 型残骸は両 repo とも codegen 生成物ゆえ温存＝実削除ゼロ**。
- Retro: SM=skill 変更なし（学びは long_term）／DEV=`backend-conventions §9` に「型撤去済 FW 機能の構造的不在は `Class.forName` でクラス不在固定」新設／PO=先回りチェックリスト昇格（「リファクタ/是正 Story は前提〔データ構造・生成物か〕も実コード裏取り」＝Sprint12傾向2 の2件目昇格）＋`intended-diff-ledger.md` ID-8 記述強化。long_term 反映済。

## 要フォロー（次回）
- (1) **「撤去/リファクタ対象が生成物か・実データ構造を実コードで裏取り」**＝PO は先回りチェックリスト昇格済。SM 側は次回再発で scrum-master-workflow ①（計画前 Explore）へ「前提の実コード裏取り」を昇格判定。
- (2) `@Transactional(readOnly)` reviewer 盲点（Sprint14 継続・今 Sprint は read API 新設なしで非該当）。次の read Story 発生時に reviewer チェックリスト昇格 or rules 明確化を判定。
- (3) #9 AC への索引置換反映（PO 継続・#9 クローズ済のため次回 Refinement）／#12 ID-8 記述強化は反映済。
- (4) local main 同期の EOL/checkout-abort 落とし穴（frontend）。今回は push のみで非該当だが、次スプリント開始時の main 同期で再確認。

## 次スプリント候補
- E3 は #11/#12 で残セキュリティ/支払を消化。次は E4 プロフィール（#13/#14/#15 系）等。バックログの Sprint 16 対象は Planning 時に GitHub Projects の Sprint フィールドで特定する。

## agent-base 成果物（step 12・実施中）
- 対象: backlog/sprint_15/（sprint_backlog.md・implementation-notes.md・review-#11/#12/#28.html）／memory/{sm,dev,po}/{short,long}.md／.claude/skills/backend-conventions/SKILL.md／spec/intended-diff-ledger.md。ブランチ `docs/sprint-15-e3-hardening-cart-perf`・`Related: #11,#12,#28`（closes にしない）。
