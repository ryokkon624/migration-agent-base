# SM 短期記憶（今スプリント）

Sprint 6（#1 E1 カタログ階層閲覧・F1.1・SP8・**本プロジェクト初のドメイン機能**・**3-repo cross-repo**）進行中。

## 計画フェーズ（2026-08-16 完了）
- **対象=#1 のみ**（ユーザー指示）。依存 #22（DB Done）/#24（フロント土台 Done）完了済。E1 は F1.1(#1・今回)/F1.2(#2・S7 検索)/F1.3(#3・S7 参照堅牢化 SBD-10/18集約) の3 Feature。
- **SM 実地調査（Explore）で重要発見**: カタログ4テーブル DDL は #22 済だが**シードデータ皆無**→ **3-repo 化（database＋backend＋frontend）**。backend/frontend のカタログ機能コードは完全ゼロ。frontend は CSS 部品（カード/グリッド/バッジ/ページネーション）・画像アセット・i18n 一部が既達（.vue 化のみ）。例外正規化(404)基盤は backend 既達。
- **計画=Opus で DEV が 3 repo/spec/conventions/レガシー seed 精読**（tier分離6連続の挑戦）。DEV が論点8点に回答＋3 repo ファイル一覧＋TDD＋DoD を整理。
- **ユーザー承認 3 決定（AskUserQuestion）**: ①残少閾値 **N=5** ②在庫ステータス**＝m_code 区分値登録**（★DEV 推奨の手書き enum をユーザーがオーバーライド・方針「区分値は基本 m_code」／§3.1 の「確定は PO/仕様で」を m_code 確定に）③ページ採番**＝1-index**。
- **SM 確定（技術/プロセス）**: 主=frontend(closes #1)/従=database・backend(Related)・3 repo 同名ブランチ `feature/1-catalog-browsing`／**size を API パラメータ化(既定12・cap100)**＝[L2] 忠実 seed だと最大 DOGS6商品/item4件で全て12未満＝多頁実証に size 指定要(test は size=2)／item 詳細カート追加＝#1 は非活性(実挙動 ID-18 は #4)／not-found＝#1 は 404 まで(集約ハードニングは #3)／MyBatis＝カスタム手書き XML／seed＝`V00_000_008`(FK順1ファイル・plaintext・[L2] cat5/prod16/item28・qty3状態)。
- ②の m_code 化に伴い database(code_type seed＋生成)・frontend(生成定数取り込み)に追加作業（SP8 内見込み）。qty 非露出(R3)は不変。

## 進行メモ
- migration-agent-base 側 Planning/Review 成果物は **`feature/sprint6` ブランチ**にコミット→**Retro 完了後に PR＆マージ**（ユーザー指示）。実装 PR は各 repo で SM 作成。
- Discord: #10-planning に Planning完了報告(thread 1538151454294933636)／#20-sprint 作業スレッド **thread 1538151521311653969**。
- 次: DEV が承認済み方針を #20 投稿＋memory 記録→**Sonnet で再起動して実装(②b)**。確認事項3件あり→**PO へ質問中継(②c)を並行実施**（改善ループ・「区分値は基本 m_code」方針の firmup を PO/§3.1 で検討）。
- ②の「区分値は基本 m_code」はユーザーの一般方針＝将来 Story にも効く。Retro で architecture-conventions §3.1 firmup を判断（初出＝2回ルールで long_term 止まりか要検討）。

## 未使用/継続
- レビュー段の観点先回り（C3）: Sec=AC-neg1(v-html禁止/plaintext)・SBD-10(404/trace非露出)・AC4(公開GETのみ)・qty非露出／Conv=backend §9(custom mapper/XML・区分値 enum は m_code 整合)・frontend §7／Perf=N+1(list は SELECT+COUNT のみ)・画像 lazy。
