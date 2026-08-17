# SM 短期記憶（今スプリント）

Sprint 16（#13 [E4]ユーザー登録＋自動ログイン・#14 [E4]アカウント/プロフィール編集の本人固定・allowlist・version 楽観ロック初実装＝E4 アカウント・3-repo・10SP）完了。Retro 済み。次スプリント開始時にリセット済み。

- 実装: `feature/13-e4-account`（backend/frontend/database 同名）。3観点＋SM verification 全クリーン（9回目相当）・Sprint Review 指摘ゼロ・tier分離16連続。PR: frontend #9（closes #13/#14）・backend #15・database #7（Related）→ **全マージ済**（#13/#14 closed(completed) 確認済）。local main 3 repo 同期済（database は transient DNS fetch 失敗を検知して再同期＝e7b068d・backend 6d05d41・frontend 6dc5fa0）。
- 委譲論点2ラウンド確定（SM 先回り Q1メール検証プレースホルダ/Q2入力検証#17委譲＋DEV 実コード精読後 E1-E9）→ churn ゼロ。E1 でユーザーが in-memory→DB-backed にオーバーライド→3-repo 化。
- SM verification: version lock 初実装の正当性（affected==0 で profile UPDATE 発行せず→409→rollback）・login 非破壊・新規 read の readOnly 整合・クエリ純増ゼロを精読確認。
- Retro: SM=`scrum-master-workflow` に「teammate 完了は idle 通知で判断しない」昇格（3回目）／DEV=`backend-conventions §9` に DB-backed レート制限一般ルール（2回ルール昇格）＋version 楽観ロック UPDATE 実装パターン／PO=`architecture-conventions` D7 新設＋`intended-diff-ledger` ID-11 拡張＋Issue #32（メール検証 deferred）起票。long_term 反映済。

## 要フォロー（次回）
- (1) **teammate 完了確認（idle ≠ 完了）**＝scrum-master-workflow 昇格済。次回も verify→未反映なら nudge→反映後前進を徹底。
- (2) **`@Transactional(readOnly)` reviewer 盲点**（Sprint14 継続）: Sprint16 は DEV が新規 read `getAccountForEdit` に readOnly を先回り適用し非該当化。次の read Story でも reviewer が拾えなければ rules 明確化 or reviewer チェックリスト昇格を判定。
- (3) **メール検証本実装（Issue #32・NotReady）**: SMTP 基盤が要る。着手時に intended-diff-ledger 再判定（PO）。
- (4) **local main 同期の transient DNS/fetch 失敗**: 今回 database で発生→再確認で検知。次回も `reset --hard origin/main` 後に HEAD を確認する。
- (5) E4 残: #15 パスワード変更（現在PW 再認証 SBD-16/ID-13）・#17 入力検証強化（ID-16）。次スプリント候補。

## 次スプリント候補
- E4 残（#15 PW変更・#17 入力検証）や E5 等。Sprint 17 対象は Planning 時に GitHub Projects の Sprint フィールドで特定する。

## agent-base 成果物（step 12・実施中）
- 対象: backlog/sprint_16/（sprint_backlog.md・implementation-notes.md・review-#13/#14.html）／memory/{sm,dev,po}/{short,long}.md／.claude/skills/scrum-master-workflow・backend-conventions／spec/architecture-conventions.md（D7）・intended-diff-ledger.md（ID-11）。ブランチ `docs/sprint-16-e4-account-register-edit`・`Related: #13,#14`（closes にしない）。
