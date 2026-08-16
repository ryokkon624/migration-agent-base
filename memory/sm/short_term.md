# SM 短期記憶（今スプリント）

Sprint 9（#5 [E2] 価格サーバ権威・SBD-2/17・SP3 ＋ #6 [E2] カート CSRF・冪等・SBD-3/15・SP3＝計6SP・security ハードニング）完了。次スプリント開始時にリセット済み。

- 実装（backend のみ・`feature/5-cart-price-csrf-hardening`・2コミット）: #5=UpdateCartItemRequest→@NotNull @Min(0) Integer（0=削除温存・負数/欠落→400）・merge ≤0→400・GlobalExceptionHandler に HttpMessageNotReadable→400／#6=XSRF-TOKEN Cookie に SameSite=Strict/Secure（既存 jwt.cookie.* 再利用・CsrfTokenRepository bean 切出）＋否定AC 回帰テスト（価格注入無視・外部オリジン拒否・冪等性）。
- 性格: **Sprint 4 型「既達が大きい」ハードニング**。計画前 Explore で既達/未実装切り分け→過剰実装回避（新規 Origin フィルタ・グローバル FAIL_ON_UNKNOWN を足さない）。
- **SM 計画フェーズ AskUserQuestion 確定（spec 委譲かつ #4/cart.md と衝突）**: #6 Origin検証=SameSite＋トークンで充足／#5 update 0=削除維持・merge ≤0→400。台帳追記なし。
- **3観点クリーン**（conv/sec 指摘0＝Sprint3/6/7 に続く4回目）。perf の merge N+1 は SM が `git diff` で Sprint8 由来の既存問題と検証→非ブロッキング→#28 で backlog 化。
- PR#8 マージ済・#5/#6 closed(completed)・Sprint Review 指摘なし。
- Retro 完了（DEV/PO/SM）。教訓は long_term 反映済：tier分離9連続・security ハードニングでも通用／「既達が大きい」ハードニングの過剰実装回避＝Sprint4型再現／spec 委譲かつ衝突論点の計画確定（5回目・衝突解消次元）／perf 既存問題のスコープ外判定→backlog／reviewer プロンプトに確定事項明記で churn 防止（初出）。DEV: backend-conventions §9 catch-all テーブルに HttpMessageNotReadable→400 追記。PO: 傾向1（否定AC 実装レベル論点）初出見送り・Origin/SameSite は Sprint4 昇格済チェックリスト3件目。
- agent-base `feature/sprint9`: Retro 完了後に PR＆マージ（ユーザー指示 2026-08-16「PR はマージしてください」）。コミット: Planning(sprint_backlog.md)・Review(review-#5/#6.html)＋Retro 成果物（memory dev/po/sm・backend-conventions §9）。
- 次スプリント候補: **E2 完成**（#4/#5/#6）につき **E3（注文＝checkout ウィザード #7・在庫原子引当 #8・注文履歴 #9/#10・remoting 廃止 #11・支払プレースホルダ #12）**へ。カート土台を注文導線で再利用・接続。在庫充足の実強制（ID-1）が E3 中核。
