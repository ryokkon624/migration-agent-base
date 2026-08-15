# SM 短期記憶（今スプリント）

Sprint 4（#21 認可土台 SP5 / #20 認証堅牢化 SP5・計10SP）完了。次スプリント開始時にリセット済み。

- 実質新規作業＝#21=本人スコープ認可ガードの部品化（`OwnershipAuthorizationService`）＋実証EP／#20=レート制限/ロックアウト（分離表 `t_login_attempt`・per-username 一時ロック）のゼロ実装。既達分（POST body限定/一律エラー/GET遮断/弱資格排除/redirect sink不在）は回帰固定。
- 3観点レビュー: 規約/perf 指摘なし・sec 非ブロッキング2件（タイミング副次チャネル／ロック延長）を SM 実コード検証のうえ受容（ユーザー承認）。cross-repo PR＝backend#3・database#3。
- Sprint Review 指摘なし。Retro 完了（DEV/PO/SM）。教訓は long_term 反映済（tier分離4連続・既達vs未実装の事前調査でスコープ限定・計画複数案の実装前1案確定・受容リスク分類・**scrum-master-workflow ⑥ を jpetstore＋cross-repo 昇格＋⑧ 起票先バグ是正**）。
- 持ち越し: #20 プリフィル廃止フロント分＝#24 AC9／元URL復帰＝#24 AC8／per-IP レート制限は見送り。
- 次スプリント: #24（E6 フロント土台・Vue3 SPA・持ち越しAC7/8/9 消化）が候補。
