# SM 短期記憶（今スプリント）

Sprint 17（#15 PW変更再認証・#16 CSRF・#17 入力検証＝E4 アカウント Epic 機能面 完了・8SP・2-repo）完了。Retro 済み。次スプリント開始時にリセット済み。

- 実装: `feature/15-e4-account-security`（backend/frontend 同名）。3観点＋SM verification 全クリーン（10回目相当）・Sprint Review 指摘ゼロ・tier分離17連続。PR: backend #16（closes #16）・frontend #10（closes #15/#17）→ **全マージ済**（#15/#16/#17 closed(completed) 確認済）。local main 2 repo 同期済（backend b8547ef・frontend c910bd9）。
- 委譲論点4件を計画確定（Q1 PW強度8〜72字/UTF-8 72バイト上限/4種中2種以上・Q2 最大長=DBカラム幅整合・Q3 トークンローテート・Q4 CSRF既達回帰+明文化）＋DEV 精読後2ラウンド目で **422三系統分離**確定（現在PW誤り422/弱PW400/未認証401/CSRF403）→ churn ゼロ。
- SM verification: PW変更=SELECT+UPDATE 最小2クエリ・再SELECTなし／`StrongPasswordValidator` ReDoSなし・UTF-8 72バイト上限／422=Spring7.0 `UNPROCESSABLE_CONTENT` 改名を正しく処理・trace非露出／`SignonCustomMapper` パラメタライズ・PK アクセス。
- ユーザー追加依頼: **backend README にローカルログイン資格情報**（`demo_user`/`Sprint3-DemoLogin!26`・seedDevData で投入・ローカル専用）を記載 → 別 docs PR #17 マージ済（sprint スコープと分離）。

## 要フォロー（次回）
- (1) **teammate 完了確認（idle ≠ 完了）**＝今回も idle 通知後に成果物未反映→verify→nudge→反映確認後に前進を徹底（DEV 計画フェーズで実践）。継続。
- (2) **frontend EOL(CRLF) ノイズ**（Sprint14/15/17 再発）: DEV 選択 add で回避・SM は main 同期を `git checkout -f main` で対処。**恒久対策 .gitattributes は Challenge 候補・次回再発で backlog 起票判定**。
- (3) **git token URL 埋め込みが実行環境の分類器にブロックされる**（初出）→ `git fetch/push origin`（token URL なし）を既定にする。
- (4) **#15 AC「401/403相当」→422 確定値へのバックログ更新**（PO・次回 Refinement 継続。#15 クローズ済）。

## 次スプリント候補
- E4 完了により機能面 Epic 完了。残 Open は tech-debt（#27 tsconfig baseUrl・#31 backend null警告）／deferred（#25 i18n・#26 依存版・#32 メール検証）。Sprint 18 対象は Planning 時に GitHub Projects の Sprint フィールドで特定する。

## agent-base 成果物（step 12・実施中）
- 対象: backlog/sprint_17/（sprint_backlog.md・review-#15/#16/#17.html）／memory/{sm,dev,po}/{short,long}.md／.claude/skills/backend-conventions（DEV §9 2点新設）。ブランチ `docs/sprint-17-e4-account-security`・`Related: #15,#16,#17`（closes にしない）。
