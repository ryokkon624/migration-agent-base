# SM 長期記憶（過去スプリントの教訓）

## スプリント進行パターン

- **tier分離が有効**（Sprint 1・**Sprint 2 で再確認**）: 計画フェーズ=Opus（論点洗い出し→ユーザー承認）／実装フェーズ=Sonnet（TDD）。計画フェーズで設計論点を先に確定させると実装が手戻りなく完走する。**13SP の大型土台 Story（#23）でも手戻りゼロで完走**。基盤／新規リポジトリ着手 Story で特に有効。
- **レビュー指摘は SM が verification してから DEV に回す**（Sprint 1・**Sprint 2 で強化**）: reviewer の指摘理由が誤っていても別観点で妥当な是正に転換できることがある一方、**偽陽性は反証して却下する**。偽陽性は依存ツリー/`./gradlew compileJava`/実コードで反証、確定指摘は実コードで裏取りしてから DEV に回す。Sprint 2 実績＝Jackson import 偽陽性を却下（Spring Boot 4.1=Jackson 3 `tools.jackson`）・JWT type confusion / 監査 XFF を確定として修正へ。
- **土台/基盤 Story はスコープ境界を計画フェーズで確定→ユーザー承認**（Sprint 2）: 「土台 vs 機能実装」の線引き（例 #23 は login=#21・在庫=#8・account編集=#14 へ委譲しドメイン service/endpoint を作らない）を計画フェーズで具体化しユーザー承認を得ると過剰実装＝スコープ逸脱を防げる。PO も「E6基盤 Story は how/どこまで が未定義になりがち」を先回りチェックリスト化（計8項目）。
- **PO質問中継（②c）は計画フェーズに確認事項がある限り必ず回す**: 質問傾向を PO が学習し Refinement 先回りに繋げる改善ループの起点。Sprint 2 は6件中5件が #23 AC 先回り整備候補として記録された。
- **Sprint Review 指摘の今スプリント対応（⑦b）**（Sprint 2 確立）: ユーザーが「持ち越し不可（最低限の品質）」と判断した場合、Retro 前に ⑤→③（fix→デルタ再レビュー）を回す。同一ブランチで既存 PR 追従・新規 PR は作らない。手順は scrum-master-workflow ⑦b に明文化。
- **tier分離が3スプリント連続で有効**（Sprint 3 で再々確認）: 8SP・cross-repo・認証という難度でも計画=Opus で最大論点を先に確定→実装=Sonnet で手戻りゼロ完走。
- **責務またぎ Story の線引きは「持ち越し＝AC化」で取りこぼしを防ぐ**（Sprint 3 確立）: feature Story の AC が backend/frontend 両責務にまたがる場合（例 #18 AC1「Vue3 SPA」/AC3「元URL復帰UX」）、今スプリントで扱わない分を口頭で終わらせず、**持ち越し先 Issue に AC として明示反映**（#18→#24 に AC7/AC8/AC-neg2 を SM が Body PATCH）。Sprint Review の AC 達成状況では ◐（部分達成・backend充足/フロントは持ち越し先）で明示。PO も「backend/frontend 責務またぎのスコープ境界」を先回り候補として記録（初出・2回目で昇格判定）。
- **cross-repo Story の PR/ブランチ/closes 運用**（Sprint 3 実績）: 変更が複数リポジトリ（backend＋database）にまたがる場合、**各リポジトリに同名ブランチ＋PR、各 PR body に `closes ryokkon624/jpetstore-manage#N`**。Issue は別 repo `jpetstore-manage` にあるが、**cross-repo `closes` で両 Issue が正しく自動クローズされることを確認**（別 repo の PR マージからでも closed になった）。SM が変更ファイル一覧を各リポジトリで取得（`git diff main...branch --name-only`）して reviewer に渡す。
- **push/PR/merge の日本語文字列は JSON ファイル＋`--data-binary` に統一**（Sprint 3 教訓）: curl `-d` にシェル直書き（日本語 commit_title）で「Problems parsing JSON」。PR body だけでなく **merge の commit_title も JSON ファイル経由**にする。ブランチ push はトークン URL 埋め込み（`https://x-access-token:$PAT@...`・upstream 追跡なし）で認証プロンプト回避。

## DEVレビュー指摘の傾向

- **DBスキーマ Story**（Sprint 1）: FK 列の明示セカンダリインデックスの一貫性（m_item.supplier_id）。InnoDB は FK 索引を自動生成するため機能影響は無いが、兄弟列に明示索引がある場合は揃える。2回目の発生で rules/database.md への昇格を判定。
- **セキュリティ土台 Story**（Sprint 2）: secure-by-default 基盤では①**トークン種別の区別**（JWT access/refresh の型混同＝`typ` claim 未使用で refresh を access として悪用可）②**信頼できない HTTP ヘッダの扱い**（監査 client_ip の X-Forwarded-For 無条件信頼＝偽装可）が頻出論点。いずれも「取り違え防止」「信頼境界」を明示的に検証依頼すると Sec reviewer が確定してくれる。
- **reviewer の偽陽性（新しめの FW 版）**（Sprint 2）: Spring Boot 4.1=Jackson 3（`tools.jackson`）を Jackson 2（`com.fasterxml.jackson`）前提で誤指摘。新版採用時は reviewer が旧版前提で誤指摘し得る → SM が依存ツリー/compile で verification してから採否判断（規約 > レビュアーの勘）。
- **認証 Story でも3観点クリーンだった**（Sprint 3）: #19/#18（bcrypt照合・login/logout）は規約・Sec・Perf 全員指摘なし。Sprint 2 で secure-by-default 土台（JWT/CSRF/監査/DaoAuthenticationProvider 前提）を固めた効果。Sec の重点観点（平文非保存/列挙不可の一律401/CSRF/固定化/オープンリダイレクトsink不在/JWT typ維持/SQLiパラメタライズ）を起動プロンプトで具体指定したのも寄与。
- **security FYI（対応不要）の受容判断は SM が裏取り**（Sprint 3）: 「demo_user の平文PWがシードのコメントに記載」は、DB格納が `{bcrypt}` ハッシュのみ・`flyway/sql-test`（test専用）・弱資格でない・本番 `flyway/sql` に漏れなし、を SM が現物確認して SBD-5/6 非違反＝**指摘化せず受容**。テスト用フィクスチャの既知平文をコメント明記するのは、login 統合テストが bcrypt 照合を実証するのに必要＝許容（本番シード分離が前提）。

## Sprint Reviewで発覚しやすいパターン

- **Flyway 採番規約（versioned vs repeatable）**（Sprint 1）: 開発/テスト用シードを versioned で採番すると out-of-order 破綻の懸念。→ repeatable（`R__`）＋冪等を rules/database.md に明文化。**自動3reviewer は規約に無い観点は全員見逃す**（規約の明文化が再発防止の要）。
- **「テスト green ＝完成」の盲点**（Sprint 2）: 実機起動の基本動作（Swagger UI 疎通）・IDE 警告（deprecated プロパティ・lint・unknown property・metadata 不足）・依存更新後の IDE クラスパス staleness は、**自動3reviewer もテストも拾わない**。#23 の Sprint Review 指摘8件中6件がこれ由来。→ DoD に「実機起動＋主要エンドポイント疎通（ping/swagger-ui/actuator health）＋IDE 警告ゼロ」を追加（developer-workflow 反映済）。
- **IDE 由来の指摘の切り分け**（Sprint 2）: 依存版更新後（例 jjwt 0.11.5→0.12.6）の IDE lint（`parser() deprecated`/`verifyWith`/`subject` undefined 等）は、`./gradlew compileJava` が green なら**実装は正・IDE のクラスパス staleness**。コードを旧 API に直すとビルドが壊れる。SM が真因を verification してから DEV に回す（コード修正不要と判断できる）。IDE 設定は gitignore 済でリポジトリに影響なし。

## Skills更新履歴

- **Sprint 1**: `.claude/rules/database.md` に flyway/sql-test の採番規約（repeatable `R__`・冪等・`WHERE NOT EXISTS`）を追記。ローカル適用手順の versioned 前提記述も是正。（SM）
- **Sprint 2**:
  - `scrum-master-workflow` に **⑦b「Sprint Review 指摘の今スプリント対応」** を新設（SM）。
  - `backend-conventions` に **§9 jpetstore-backend 固有の注意事項** 新設（Jackson3・JWT typ claim 型区別・監査 client_ip の getRemoteAddr 既定・カスタム mapper/entity 配置`custom/{entity,mapper}`と命名・アノテーション/XML 使い分け・純追記表の MyBatis Generator 除外）（DEV）。
  - `developer-workflow` の「作業完了時」に **DoD 追加**（バックエンドで新規EP・Security 設定・application.yml 変更を伴う場合は実機起動＋主要EP疎通＋IDE 警告ゼロを確認）（DEV・2回ルール例外＝定量根拠が強いため即時反映）。
  - `spec/architecture-conventions.md` に **§4.4**（純追記表は Generator 対象外）新設（DEV）。
  - 2回ルール据え置き（1回目・long_term のみ）: Swagger permitAll `/swagger-ui.html`・`server.error.*`→`spring.web.error.*`・依存更新後の IDE staleness。
- **Sprint 3**: skill ファイルの変更はなし（今スプリントの SM 学びはすべて 2回ルールで long_term 止まり）。long_term のみに記録＝(a) cross-repo Story の PR/ブランチ/closes 運用、(b) push/PR/merge の日本語は JSON ファイル＋`--data-binary`（merge commit_title 含む）、(c) 責務またぎ Story の持ち越しは AC 化（#18→#24）、(d) Bash 非搭載 reviewer（Read/Glob/Grep のみ）への対応＝SM が working dir を対象ブランチにチェックアウト済みにして**絶対パス Read** を指示（workflow の `git show` 前提と実態が食い違う）。**2回目発生時に scrum-master-workflow の PR節（hw-hub 前提・未調整）を jpetstore＋cross-repo 向けに JIT 調整して昇格判定**。
