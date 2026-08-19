# SM 短期記憶（今スプリント）

Sprint 20（#38 JWT署名鍵 fail-fast / #39 監査抑止＋未認証write増幅 / #40 注文失敗監査＋入力制約 / #41 レート制限 TOCTOU・13SP・2-repo）完了。Retro 済み。次スプリント開始時にリセット済み。

- **性格**: Phase 4 L3（セキュリティ回帰）の Find-and-Fix の **Fix 半分**＝機能追加ゼロのセキュリティ修正スプリント（新種）。主成果物は**否定AC の回帰テスト**＝SEC が手で実証した PoC の CI 資産化。
- **実装**: backend `fix/38-l3-security-fixes`（7コミット・PR #20 で `closes #38/#39/#40/#41`）／database 同名（1コミット・PR #10 `Related:`）。**両 PR マージ済・4 Issue クローズ確認済・local main 両 repo 同期済**（backend `73c8d13` / database `17c40de`）。frontend 無変更。**AC 26/26**。
- **レビュー**: 初回＝conv/sec 指摘なし・perf 1件（`LoginAttemptService` の tx 非対称）／**SM verification 確定所見1件**（quota チェックが best-effort 境界の外＝#39 が直している N2 と同一失敗モードの残存・**sec は false negative**）。デルタ再レビュー＝perf/sec クリーン・conv suggestion 1件（javadoc）→ **docs のみのため4回目ラウンドは省略し SM 現物確認でクローズ**。**Sprint Review 指摘ゼロ**。
- **C2 成功**: SEC が自粛したライブ・バーストPoC（L3 §3 残件1）を `RateLimitBurstConcurrencySpec`（Testcontainers＋20並列）で資産化 → **L3 残件1 クローズ**。
- **Skills 昇格2件**（詳細は long_term「Skills更新履歴 Sprint 20」）: `scrum-master-workflow` ④＝reviewer 全クリアでも SM 独立 verification 必須／⑥＝push フォールバックのはしご＋merge は MCP。

## 要フォロー（次回）
- (1) **teammate 完了は idle≠完了**。成果物直接確認（memory/Discord/Issue/branch）。**副作用を伴う最終化の nudge は冪等指示**（「完了済みなら再実行せず Message ID を返答」）＝Sprint20 で有効性実証・二重投稿ゼロ。
- (2) **teammate のツール可否は個体差あり**（Sprint19 DEV=github MCP 不可／Sprint20 DEV=`discord_get_messages` 不可）。**SM の成果物確認は teammate の完了報告受領後に行う**と観測ずれが出ない。
- (3) **push はセッション単位で揺れる** → ⑥ に昇格済（①タイムアウト付き `git push origin` →②token URL →③別セッション代行）。**agent-base も同様**。マージは `mcp__github__merge_pull_request`。
- (4) **javadoc `{@link}` 宙吊り参照**が Sprint20 で2件（同一スプリント内＝2回ルール未達で見送り）。**3件目が出たら `backend-conventions §9` に「`{@link}` 先の実在確認」を追加 → それでも再発ならビルド設定（`-Xdoclint`）を Issue 起票**、の順で判定する（DEV 申し送りへの SM 判定）。
- (5) frontend EOL(CRLF) ノイズは #35 `.gitattributes` 済。**Sprint20 は frontend 無変更のため観測機会なし**（要フォロー継続）。

## 次スプリント候補
- open Issue は **#42 / #43 / #44 / #45（いずれも L3 Low 束・Ready=Draft）** と **#32（メール検証・NotReady/deferred）**。
- #42〜#45 はすべて Phase 4 L3 由来で **Sprint 20 と同じ「PoC → 回帰テスト」枠組みがそのまま使える**。Sprint 21 対象は Planning 時に Projects の Sprint フィールドで特定する。
- **Retro 積み残し**: PO が #44(B)（`languagePreference` allowlist）を保持中。Sprint20 では allowlist を実装せず**データ衛生（dev DB の正規化）のみ**実施した。

## agent-base 成果物（step12）
- 対象: `backlog/sprint_20/`（sprint_backlog・implementation-notes・review-#{38,39,40,41}.html）／`memory/{sm,dev,po}/{short,long}_term.md`／`.claude/skills/{scrum-master-workflow,backend-conventions}/SKILL.md`／`spec/intended-diff-ledger.md`（ID-11・ID-25 強化）／**`reports/after/l3-security-regression-{backend,frontend}.md`（SEC の L3 レポート・未追跡だったので今回追加）**。
- ブランチ `docs/sprint-20-l3-security-fixes`・PR body は `Related: #38/#39/#40/#41`（`closes` にしない）。
