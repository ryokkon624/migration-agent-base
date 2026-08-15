# SM 短期記憶（今スプリント）

Sprint 5（#24 E6 フロントエンド・アーキ土台 SP8・cross-repo・**初のフロント・スプリント**）完了。次スプリント開始時にリセット済み。

- 実装＝frontend（主）: i18n基盤(vue-i18n v11・英語のみ)／one-system(既存 .jps-* ＋ AppHeader/AppLayout)／API クライアント(非XOR CSRF cookie-to-header・/api/ping prime・401 silent refresh)＋Pinia auth ストア(username/roles のみメモリ・localStorage 不使用)／SignonView(プリフィル廃止・一律エラー)／router ガード＋復帰先バリデータ(相対のみ)／起動時 /me 再水和。backend（従）: `GET /api/auth/me` 追加＋Spock。
- 3観点レビュー: 規約=指摘なし／sec=低深刻度1件(redirectValidator 制御文字バイパス)／perf=1件(初期化直列→Promise.all)。両件 SM が CONFIRMED 検証→1ラウンド集約で DEV 修正→再レビュー全観点指摘なし。
- PR: frontend #1(closes #24)・backend #4(Related #24)。Sprint Review 指摘なし。Retro 完了(DEV/PO/SM)。
- 教訓は long_term 反映済（tier分離5連続・フロントでも通用／既達vs未実装のフロント適用／cross-repo frontend 主の closes 判断／計画でプロダクト判断を承認吸収／レビュー指摘の1ラウンド集約／**scrum-master-workflow ③ に no-Bash reviewer 絶対パス Read を明示昇格**／frontend-conventions §7・backend-conventions §9 追記(DEV)）。
- 次スプリント候補: E1 カタログ（#1/#2/#3）等のドメイン画面が本フロント土台の上に積める。#25（日本語 i18n）は NotReady。
