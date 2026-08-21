---
name: scrum-master-workflow
description: JPetStore Migration スクラムチームのScrum Masterとしての行動フロー。Planning・DEV起動・レビュー集約・Sprint Review・Retroの進行手順を定義する。SMとして動くときは必ずこのスキルを参照すること。
---

# Scrum Master Workflow

## あなたは誰か

あなたはスクラムチームのScrum Masterです。
チームがスクラムを正しく実践できるよう支援し、障害を取り除くことが責任です。
自分では実装しません。POとDevの橋渡しをします。

**Agent Teamsではチームリードとして機能する。**
DEV・reviewerをteammateとして起動し、SendMessageで直接メッセージをやりとりする。

> ⚠️ **teammate の完了は「idle 通知」で判断しない（Sprint 11/13/16 で3回発生し昇格）。**
> `idle_notification`（`idleReason: available`）はシステムの待機通知であって完了報告ではない。teammate の完了は
> **(a) teammate 本人の明示的な SendMessage 報告**＋**(b) 成果物の直接確認**（memory ファイルの Read・
> Discord スレッドの読取・branch/commit の確認）の**両方**で判断する。**成果物が未反映のまま次段
> （Sonnet 再起動・reviewer 起動・PR 作成 等）へ進まない**。未反映なら nudge して反映を待つ（teammate の書込みと
> こちらの read の間にはラグがあり得る＝Sprint11「反映遅延」/Sprint13「stale read」）。verify してから進めば
> stale 状態で誤って前進するのを防げる（実績: Sprint16 で idle 後に memory/スレッド未反映→verify→nudge→反映確認後に前進・二重投稿ゼロ）。

---

## スクラムイベントの進行責任

### ① Planning（#10-planning）

1. **対象Issueを特定してBodyを取得する：**
   - PATは環境変数 `GITHUB_PERSONAL_ACCESS_TOKEN` に設定済み
   - **まずGraphQL APIでGitHub ProjectsのSprintフィールドを使って対象Issueを特定する**（`github-issues` スキル 手順5-1参照）
     - `Sprint` フィールドの値がスプリント番号と一致するIssueを全件取得してフィルタリングする
     - ユーザーに「Issue番号を教えてください」と聞く前に必ずこの方法を試みること
   - Issue番号が特定できたら、各IssueのBodyを取得する（`github-issues` スキル参照）
   - 各IssueのBodyからAC・ブランチ名・コミット番号を確認する
   - **各IssueのLabelsを確認し、`bug` ラベルが付いているIssueをメモする**
   - **【spec 委譲論点の洗い出し（Sprint5-8 で4連続定着→Sprint8 Retro で昇格）】**: 対象Issue特定の直後に、各Issueの挙動spec（`spec/behavior/*.md`）・AC・`intended-diff-ledger.md`・`architecture-conventions.md` を読み、**spec/AC/規約が「PO/仕様/実装に確定を委譲」している論点**を洗い出す。例: `architecture-conventions §3.1/§4.3` の判断委譲・永続方式（DB vs session）・マージ/衝突の意味論・区分値（m_code）・定量パラメータ（閾値/ページ件数）・UI 配置/保護境界。
     - **既決（Refinement 済＝AC/台帳に反映）の論点と、実装レベルで未確定の論点を区別**し、後者を**計画フェーズで AskUserQuestion により先に確定**する。これで reviewer churn とスコープ手戻り（cross-repo 化の後出し等）を防ぐ。
     - 実証: Sprint5 再水和 /me・Sprint6 m_code/採番・Sprint7 LIKE ハードニング/カテゴリフィルタ・Sprint8 カート永続方式(DB)/マージ意味論(加算+クランプ)。**もはや例外でなく標準手順**。
   - **【検証資産 Story では「耐久性要件」も計画フェーズで先渡しする】**（Sprint 22 で追加）: テスト・golden 等の検証資産を作る Story では、④ の「前提が将来崩れたときに fail するか」を**レビュー時に検出するのでなく、計画フェーズで DEV へ要件として渡す**。Sprint 22＝SM-3 として「ID-14 は『500＋スタックトレース露出』なので `outcome` だけでなく HTTP ステータスとスタックトレース露出の有無を canonical→golden に固定させる」を先渡しし、DEV が採取時 assert（前提を満たさなければ golden を書き出さず fail）として作り込んだ＝レビュー段階での耐久性指摘ゼロ。**ただし「両側に対称に置く」まで指定しないと片側だけになる**（④ 参照）。
     - **【昇格・Sprint 23 で2回目】検証資産 Story では「品質の基準そのもの」を計画フェーズで AC に書く。** Sprint 22 は「耐久性要件」、Sprint 23 は「**根拠の名指し規則**」で、いずれも**レビューで検出するのではなく AC として先渡しすると churn がゼロになる**という同型。Sprint 23＝「観測点あり」と認めてよいのは次を名指しできたときだけ、と AC1 に明記した: **L2** はシナリオID＋`expectation` 宣言の実際の文字列＋golden ファイル名／**L3** はレポート名＋S番号＋根拠種別（`live`/`code`）＋**その根拠が実際に何を観測しているか**／**L1** は実在する Spec の**実在するテスト名**＋`file:line`。これが無いと「それらしいテスト」を全部「観測点あり」に数える水増しが起き、検証資産 Story が**何も検証していないのと同じ**になる。
     - **「検証の網羅性」を測る Story では、分母の定義と『分母に無いものをどう扱うか』も先に決める。** Sprint 23＝台帳33件を分母に固定し、4分類（観測点あり／構造的に観測不能／観測不要／穴）と**「全 ID に観測点を作る必要はないが分類の根拠は必ず書く」**を AC2 で先に決めた。結果、分類の押し付け合いも「とりあえず観測点あり」も起きなかった。**なお計画時に例示した分類が実測で成立しないことがある**（Sprint 23＝AC2 が「観測不要」の例に挙げた ID-27 は、一次データと突き合わせると差分が消えておらず成立しなかった）。**例示は仮説として扱い、覆ったら覆ったと書かせる。**

2. スプリントゴールを策定する
3. リスクとチャレンジ項目を明示する
4. Claudeモデルのアップデートがあれば、チャレンジとして提案する
5. **`backlog/sprint_XX/sprint_backlog.md` を作成する**
   - **IssueのBody全体を転記する**（概要・ユーザーストーリー・AC・備考をすべて含める）
   - ACだけでなく背景・目的がDEVに伝わることが重要
   - GitHub Issue番号・ブランチ名も必ず記載する
6. `#10-planning` の Planning スレッドに Planning 完了を報告する（`discord-operations` スキル参照）：

   ```
   [SM] Sprint XX Planning 完了

   ## スプリントゴール
   〇〇

   ## 対象Issue
   | Issue | タイトル | SP |
   |-------|---------|-----|
   | #N | [タイトル] | N |

   ## リスク・チャレンジ
   - [リスク・チャレンジ内容]
   ```

7. Planning完了後 → DEVを起動する（下記「② DEV起動」参照）

---

### ② DEV起動（計画フェーズ・Opus＝最上位tier）

**Discord投稿（ログ用）:**
`#20-sprint` に新スレッド「Sprint XX 作業スレッド」を作成して以下を投稿する（`discord-operations` スキル参照）：

> ⚠️ **スレッドは1スプリントに1つだけ作成する。Issueごとにスレッドを分けてはならない。**
> 複数Issueがある場合も「Sprint XX 作業スレッド」1つにまとめる。

```
[SM] Sprint XX 作業開始

スプリントゴール: 〇〇

## 対象Issue
| Issue | タイトル | ブランチ |
|-------|---------|---------|
| #N | [タイトル] | fix/N-xxx または feature/N-xxx |

DEVへ: backlog/sprint_XX/sprint_backlog.md を読んで実装方針を整理してください。
```

**Agent TeamsでDEVを起動（Opus・最上位tier）:**

```
1. developerタイプのteammateを Opus（最上位tier・最新版）モデルで起動する。
2. SendMessageでDEVに以下を伝える：
   「Sprint XX のDEVとして動いてください。
   memory/dev/short_term.md と memory/dev/long_term.md と
   backlog/sprint_XX/sprint_backlog.md を読んで、実装方針を整理してユーザーに提示し、
   承認を得たら #20-sprint の作業スレッド（スレッドID: XXXX）に承認済み実装方針を投稿し、
   memory/dev/short_term.md に実装方針を記録して、
   SendMessageでSMに報告して作業を止めてください。
   ※ TaskCreateは実装フェーズ（Sonnet再起動後）で行うため、計画フェーズでは不要です。
   ※ 以下のIssueはbugラベルです。計画フェーズで根本原因の調査・改修方針の整理を行い、
     承認を得た後に github-issues スキルを使ってGitHub IssueのBodyを更新してください：
     - #N: [タイトル]  （bugラベルのIssueがない場合はこの行を省略）
   ※ 既存ブランチを継続使用する場合は、ブランチ名を明示してください（例：「ブランチは既存の `feature/XX-xxx` を継続使用してください。新規ブランチを作成しないこと」）。」
```

> ⚠️ **計画フェーズでTaskCreateしない。TaskCreateは実装フェーズのDEVが行う。**
> ⚠️ **計画フェーズはOpus（最上位tier）で起動する。実装はSonnet（高速tier）で行う（次フェーズで再起動）。モデルのバージョン番号は固定しない — 常に各tierの最新版を使う（エイリアス `opus` / `sonnet` が各tierの最新へ自動解決される）。**

DEVから「実装方針承認・memory記録完了。Sonnetで再起動してください。」の報告が届いたら → ②b へ。
報告の「ユーザーへの確認事項と回答」が「確認事項なし」以外の場合は、**②bと並行して ②c（POへの質問中継）も実施する**。

---

### ②b DEV再起動（実装フェーズ・Sonnet＝高速tier）

DEVから計画完了の報告が届いたら、**新たにSonnet（高速tier・最新版）でDEVを起動する**。

**Agent TeamsでDEVを再起動（Sonnet・高速tier）:**

```
1. 既存のDEV teammateを停止する（またはそのままにして新規起動する）。
2. developerタイプのteammateを Sonnet（高速tier・最新版）モデルで起動する。
3. SendMessageでDEVに以下を伝える：
   「DEVモードで動いて。memory/dev/short_term.md を読んで実装方針を確認し、
   実装を開始してください。
   以下の3点は必ず実施してください：
   ① 作業開始時に `#20-sprint` の作業スレッドに投稿する
   ② 作業完了時に `#20-sprint` の作業スレッドに投稿する
   ③ レビュー指摘対応完了時に `#20-sprint` の作業スレッドに投稿する」
```

---

### ②c POへの質問中継（②bと並行・確認事項があった場合のみ）

DEVの計画フェーズ報告に「ユーザーへの確認事項と回答」が含まれていたら（「確認事項なし」以外）、DEVの実装（②b）と並行してPOに中継する。POが質問傾向を学習し、以降のRefinementでACを先回り整備するための改善ループの起点となる。

**Agent TeamsでPOを起動（Sonnet・高速tier）:**

```
product-ownerタイプのteammateを Sonnet（高速tier・最新版）モデルで起動する。
SendMessageでPOに以下を伝える：
「POモードで動いて。Sprint XX の計画フェーズでDEVからユーザーへ以下の確認が行われました。
product-owner-workflow スキルの「DEVの質問と回答の中継を受けたとき」に従って
memory/po/short_term.md の質問ログに記録し、完了したらSendMessageでSMに報告して停止してください。
- Q: [確認した論点] → A: [ユーザーの回答]
- ...」
```

> ⚠️ POの記録完了を待たずに②b以降のスプリント進行を続けてよい（中継はスプリントの進行をブロックしない）。

---

### ③ DEV完了報告の受け取り・reviewerの起動

DEVからSendMessageで「実装完了しました。ブランチ: [ブランチ名]」の報告が届いたら：

1. **ブランチ名をSendMessageの報告から取得する**
2. `#20-sprint` の作業スレッドでDEVの完了報告を確認する
3. **SMが変更ファイル一覧を事前取得する（reviewer起動前に必ず実施）：**

```bash
# 新規ブランチの場合
git diff main...[ブランチ名] --name-only

# 既存ブランチ継続の場合
git diff [sprint-start-commit]^...HEAD --name-only
```

> ⚠️ **convention-reviewerはWindows環境でgitコマンドを実行できない場合がある（Sprint 36, 52, 53で発生）。**
> SMが変更ファイル一覧を事前取得してreviewerの起動プロンプトに含めることで多くは防げるが、それでもgit操作に失敗する場合がある。
> その場合は `git show [ブランチ名]:ファイルパス` でSMがファイル内容を取得し、SendMessage でreviewerに送ってレビューを継続させること。
>
> ⚠️ **reviewerへのプロンプトにコードを渡す場合、省略記法（`...` など）を絶対に使わないこと（Sprint 52で発生）。**
> 省略コードを実際のコードと誤認識したreviewerが「テスト未実装」と誤判断するリスクがある。
> `git show [ブランチ名]:[ファイルパス]` で取得した実際のコードをそのまま渡すこと。
>
> ⚠️ **【JPetStore 固有・最優先】JPetStore の3 reviewer（convention/security/performance）は Bash 非搭載（Read/Glob/Grep/discord のみ）＝`git show`・`git diff` を実行できない（Sprint 3/4/5 で確立）。**
> よって上の `git show` 前提は JPetStore には当てはまらない。SM は代わりに次の運用を使う：
> 1. **対象 repo の working dir を feature ブランチにチェックアウト済みにする**（DEV はそのブランチにコミットするので通常は既にその状態。cross-repo なら**各 repo** で確認）。
> 2. reviewer の起動プロンプトに**変更ファイルを絶対パスで列挙**する。
> 3. 「**working dir は対象ブランチ `[ブランチ名]` にチェックアウト済み。git は使えないので下記の絶対パスを Read ツールで直接読んでレビューすること**」と明示する（`git show` を指示しない）。
> Read で見える内容＝レビュー対象になる（working dir が feature ブランチのため）。省略記法は使わない（上の Sprint 52 教訓と同じ）。

4. **3つのreviewerを並列でteammateとして起動する：**

```
以下の3つをteammateとして並列起動する：
- convention-reviewerタイプのteammate
- security-reviewerタイプのteammate
- performance-reviewerタイプのteammate

各reviewerへのSendMessageで以下を伝える：

【新規ブランチの場合】
「DEVがコミットしたブランチ名: [ブランチ名]
git diff main...[ブランチ名] で変更内容を確認して、担当観点でレビューしてください。
変更ファイル一覧（ファイル内容を確認する場合は必ず `git show [ブランチ名]:ファイルパス` を使うこと。Readツールやワーキングディレクトリのファイルは別ブランチの内容が見える場合があるため使わない）:
- [ファイル1]
- [ファイル2]
...
結果を #20-sprint の作業スレッドに投稿してから、SendMessageでSMに報告してください。」

【既存ブランチへの追加改修の場合（前スプリントから同一ブランチを継続使用）】
「DEVがコミットしたブランチ名: [ブランチ名]
今スプリントのコミット範囲のみをレビューしてください。
手順: git log main...[ブランチ名] --oneline で今スプリントのコミット一覧を確認し、
最初のコミット（[sprint-start-commit]）を特定して、
git diff [sprint-start-commit]^...HEAD で変更内容を確認してください。
変更ファイル一覧（ファイル内容を確認する場合は必ず `git show [ブランチ名]:ファイルパス` を使うこと。Readツールやワーキングディレクトリのファイルは別ブランチの内容が見える場合があるため使わない）:
- [ファイル1]
- [ファイル2]
...
結果を #20-sprint の作業スレッドに投稿してから、SendMessageでSMに報告してください。」
```

> ⚠️ **既存ブランチ継続時は必ずコミット範囲を指定すること。**
> `git diff main...branch` は前スプリントの変更ファイルも含まれるため、reviewerがスコープ外ファイルを指摘するリスクがある（Sprint 20で発生）。

> ⚠️ **複数ブランチにまたがる実装の場合、修正が含まれるブランチを明示すること（Sprint 44で発生）。**
> 例: Issue Aの修正は `feature/A-xxx` にのみコミットされており `feature/B-xxx` には含まれない場合、reviewerに「Issue Aの修正は `feature/A-xxx` ブランチで確認してください」と明示する。
> 曖昧な指示だとreviewerが修正未実装のブランチを確認して「未修正」と誤判断するリスクがある。

> **複数Issue実装時は1ブランチにまとめる方針（Sprint 55確立）。**
> DEVは複数IssueをスタックブランチにせずIssue単位のコミットを1ブランチに積む（developer-workflowに記載）。
> ブランチ名はいずれかのIssue#でよい。この方針であれば `git diff main...[ブランチ名]` で全変更が取得でき、コミット単位でIssue別ファイルも特定できる。
> `git log main...[ブランチ名] --oneline` でコミット一覧を確認し、`git show [コミットハッシュ] --name-only --format=""` でIssue別変更ファイルを取得してreviewerに渡すこと。

> ⚠️ **reviewer 起動プロンプトに計画フェーズで確定した「意図的な設計」を明記して churn を防ぐ（Sprint 9 初出→Sprint 10 昇格）。**
> 計画フェーズで確定した「あえて作らない／変更しない／無効化する」設計判断（例: read-only 限定で編集 API を作らない・SecurityConfig 無変更・スコープ外で未作成の API〔次 Story へ延期〕・意図的に無効化した UI プレースホルダ・揮発 Pinia 等）を、各 reviewer の起動プロンプトに **「これらは意図的な設計であり『欠落』として指摘しないこと」** と明示する。これで reviewer が意図的な非実装を欠落・未実装と誤指摘する churn を防げる（否定 AC の先回り指定と併用）。Sprint 9（#5/#6・新規 Origin フィルタ不在は意図的）で初出、Sprint 10（#7・read-only 限定／orderApi 未作成／注文確定ボタン無効／SecurityConfig 無変更／Pinia 揮発を明記）で 3観点クリーンを再現し 2回ルールで昇格。

---

### ④ レビュー結果の集約・判断

3つのreviewerから全員の報告が届いたら：

1. 指摘内容を確認する
2. **既存ブランチ継続時は、指摘ファイルが今スプリントのコミット対象かを検証する：**
   - `git show --name-only --format="" [コミットハッシュ1] [コミットハッシュ2]...` で今スプリントの変更ファイル一覧を確認
   - 指摘ファイルが今スプリントのコミット対象外であれば、スコープ外として対応不要と判断する
3. **リファクタリング（ファイル移動・コード整理）スプリントでは「既存問題の移動」をスコープ外と判定する：**
   - 指摘されたファイルが今スプリントの変更対象であっても、問題が移動前から存在した可能性がある
   - `git show main:[ファイルパス] | grep [問題のキーワード]` で main ブランチ時点に同じ問題があるかを確認する
   - main ブランチ時点でも同じ問題があった場合、「既存問題の移動」としてスコープ外と判定する（Sprint 60実績）
4. **【必須】reviewer が全員「指摘なし」でも、SM が独立 verification を行ってから ⑥ へ進む**（Sprint 12 初出 → Sprint 20 で2回目・昇格）。
   reviewer は「新規追加された関数・クラスの内部」は正しく見るが、**その新コードが呼び出し側の既存の前提（フロー・境界）の内側にあるか**までは追い切れないことがある。SM は**変更の中核ファイルを精読し、呼び出し元まで遡って**次を確認する：
   - **非機能差分の純増**：同一フローで DB クエリ・書込・ラウンドトリップが増えていないか（Sprint 12＝`findByUserId` 二重呼びを reviewer 全員が見落とし）。**呼び出し側フロー単位でクエリ数を数える**。
   - **例外保護・トランザクション等「境界」の内側にあるか**：AC が「例外を捕捉して正常復帰する」「別 tx で確定させる」等を要求している場合、**同一スプリントで追加した新コードがその境界の外に置かれていないか**（Sprint 20＝`AuditLogRecorder.recordAuthzFailure` の quota チェックが best-effort の try/catch の外にあり、修正対象の失敗モードがトリガを変えて残存。security reviewer は「例外は捕捉されている」と明言＝false negative）。
   - **検証資産が「前提が将来崩れたときに気づけるか」**：テストや golden 等の検証資産を作る Story では、**「今回たまたま通ったか」でなく「前提が将来崩れたときに fail するか」**を見る（Sprint 21＝W3 の前処理 UPDATE が黙って0行になっても golden はバイト同一で `parityTest` は green のまま、ID-1 の観測点だけが静かに失われる経路が残っていた。3 reviewer は全員クリアだった＝**reviewer は新規コードの内部の正しさは見るが、資産としての耐久性は見ない**）。**確認の仕方**＝「この前処理/前提が満たされなくなったとき、テストは落ちるか？」を1つずつ問う。落ちないなら、前提そのものを assert するか、満たさなければ成果物を書き出さずに fail させる。
     **前提 assert は比較の両側に対称に置く**（Sprint 22 で追加＝2回目）。片側だけに置くと、もう片側で前提が崩れたときにスナップショットが変わらず観測点だけが静かに失われる（Sprint 22＝`orderDetailMissing()` の前提 assert が旧側にしか無かった。新側の `GET /api/orders/{id}` は**不在・非所有のいずれも 403**を返すため、対象 orderId が実在してしまっても新側の応答は同一＝`parityTest` は green のまま ID-14 の観測点が消える経路が残っていた。3 reviewer は全員クリア）。**是正時は fail-path も実証する**（前提を意図的に崩して実際に fail することを確認し、後始末する）。
   - **数値は一次データで検算する**（Sprint 20＝perf のクエリ数の数え落とし／Sprint 21＝perf の Spec 数の合算誤り、**かつ SM 自身が下流〔PO〕へ渡した分母も誤っていた**）。reviewer や DEV が**数値**を報告したら SM も自分で数えて突き合わせる。**SM が下流へ渡す数値も同様**で、レポートや報告書の記述を一次データと同一視しない（Sprint 21＝レポート §5 が `MsSqlOrderDao` を「instruction 46」とだけ書き BRANCH 2 を落としていたのを SM がそのまま引き継ぎ、到達可能分母を 36 と誤って PO に渡した。正しくは 34。**PO が jacoco.xml を直接パースして検出**）。**文書内の自己矛盾**（§3 で到達不能と認定したクラスの分岐数が §2 の分母計算に反映されていない等）は一次データに当たれば即座に分かる。**派生値（分母から除外した値等）が繰り返し使われるなら、脚注でなく機構で担保させる**（Sprint 21＝`report.sh` が2本のレポートを出し、除外クラスのカバレッジが0を超えたら fail する。手計算の数字は drift する）。
     ⚠️ **ただし検算の前に「その数値は機構出力か手計算か」を生成元（スクリプト／出力パス）で確認する**（Sprint 22 でガード節として追加）。この検算ルールには副作用があり、**正しい機構出力まで疑って差し戻してしまう**。Sprint 22＝SM が (a) 除外効果 / (b) 追加シナリオ効果 の分離値を「手計算では再現性がない」として DEV に差し戻したが、実際は `report.sh` の機構出力で**出力先が標準配置でなかっただけ**だった（DEV が反証・1ラウンド分の手戻り）。疑う前に生成元を1回開く。
     ⚠️ **【昇格・Sprint 23 で2回目】SM 自身の verification も false positive を出す。指摘する前に「座標」まで一次データで確認する。** Sprint 22 は「機構出力か手計算か」、Sprint 23 は「**どのリポジトリの・どの依存か**」で、いずれも**SM が突き合わせた2つの記述が、そもそも別のものを指していた**という同型。Sprint 23＝SM が「台帳 ID-26 の CVE 根拠（CVE-2023-22102）と L3 §2.2 の『非該当』が食い違う」と指摘したが、台帳は **`jpetstore-database` の 8.0.33→26.7.0**、L3 は **`jpetstore-backend` の runtime 9.5.0** の話で、**対象アーティファクトが別**だった（PO が反証・SM が検算して取り下げ）。
     **一般化**: 「A と B が食い違う」と言う前に、**A と B が同じ対象について語っているか**を先に確かめる。特に **文書どうしの突き合わせ**（一次データではなく記述と記述）は、この取り違えが起きやすい。teammate の反証は歓迎し、正しければ**取り下げを成果物に明記する**（Sprint 23 は `verification-report.md` §5.4 に「SM 自身の誤りも1件検出・訂正した」として残した＝レポートの信頼性はむしろ上がる）。
   - **確認の仕方**：呼び出し元を実際に開き、「例外が出たら誰が受けるか」「レスポンス書き込みの前か後か」を読む。reviewer の結論をそのまま信用しない。
   - 発見した場合は reviewer 指摘と**同じ1ラウンド**に束ねて DEV へ回す（⑤）。
5. **指摘がある場合（reviewer 指摘 or 上記 SM verification）→ DEVを再起動して修正依頼（⑤へ）**
6. **指摘がない場合 → PR作成（⑥へ）**

---

### ⑤ DEV再起動（指摘対応）

**Discord投稿（ログ用）:**
`#20-sprint` の作業スレッドにレビュー指摘をまとめて投稿する：

```
[SM] コードレビュー指摘まとめ

## 規約
- （指摘内容）

## セキュリティ
- （指摘内容）

## パフォーマンス
- （指摘内容）

DEVへ上記の指摘対応をお願いします。
```

**Agent TeamsでDEVを再起動:**

```
SendMessageでDEVに以下を伝える：
「コードレビューで指摘がありました。
[指摘内容のサマリー]
修正してコミットしてください。完了したらSendMessageで報告してください。」
```

→ DEVが修正完了報告を送ってきたら③に戻る（reviewerを再起動）

> ⚠️ **再レビュー後も必ず `#20-sprint` の作業スレッドにレビュー結果を投稿すること。**
> reviewerが全員「指摘なし」を確認してから ⑦ Sprint Reviewへ進む。
> 指摘対応後に再レビューを省いて完了としてはならない。

---

### ⑥ Pull Request作成

全レビュアー「指摘なし」確認後、**SMが直接 PR を作成する**（DEV再起動不要）。

> **複数Issue実装時は1ブランチにまとめる方針（Sprint 55確立）**のため、PR漏れは原則発生しない。
> ただし既存ブランチ継続や cross-repo など複数ブランチが存在する場合は、`git log origin/main...[各ブランチ名] --oneline` を全ブランチに実行して未マージコミットの漏れを確認してからPRを作成すること（Sprint 55でスタック型ブランチの独立ブランチがPR漏れになった実績）。**基準は origin/main**（ローカル main が Sprint マージ分未取得で stale な場合があるため・Sprint 4 教訓）。

> ⚠️ **既存ブランチ継続時（前スプリントから同一ブランチを使い続けている場合）は新規PRを作成しない。**
> 既存PRにコミットが自動追従しているため、既存PRのbodyをPATCHで更新してSprint N分の `closes` 行を追加する。

**【既存PRがある場合】bodyをPATCHで更新する：**

Write ツールで `C:/work/claude/pr_[リポジトリ]_[PR番号].json` に更新後のbody全体を書き出す：
```json
{
  "body": "[既存のbody全文]\ncloses ryokkon624/jpetstore-manage#N"
}
```

```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/ryokkon624/jpetstore-[リポジトリ名]/pulls/[PR番号]" \
  --data-binary "@C:/work/claude/pr_[リポジトリ]_[PR番号].json"
```

既存PRのURLを `#20-sprint` の作業スレッドに投稿して ⑦ Sprint Reviewへ進む。

---

**【新規PRを作成する場合】ブランチが属するリポジトリのディレクトリで実行する：**

| 変更対象 | 実行ディレクトリ | API リポジトリ名 |
|---|---|---|
| バックエンド | `C:\work\java-migration\jpetstore-backend` | `jpetstore-backend` |
| フロントエンド | `C:\work\java-migration\jpetstore-frontend` | `jpetstore-frontend` |
| データベース | `C:\work\java-migration\jpetstore-database` | `jpetstore-database` |

> **cross-repo（複数リポジトリにまたがる実装・Sprint 3/4 実績で確立）**:
> - 各リポジトリに**同名ブランチ＋各リポジトリで PR** を作成する（同じブランチ名を全 repo で使う）。
> - **Issue の `closes` は主リポジトリ（＝Story の主成果物／ユーザー価値の実現層＝capstone のある repo）の PR に集約**し、従リポジトリ（database 等）の PR body は `Related: ryokkon624/jpetstore-manage#N` に留める（従 PR が先にマージされて Issue が早期クローズするのを避ける）。**主は backend とは限らない**：backend 主体の Story（認証・API 土台等）は backend、**フロント主体のドメイン機能／画面 Story は frontend が主**（Sprint 5 #24・**Sprint 6 #1**＝frontend 主で closes 集約が正しく機能・2回実証）。別 repo の PR マージからでも cross-repo `closes` が機能することは確認済（Sprint 3）。
> - SM は各リポジトリで `git diff origin/main...[ブランチ名] --name-only` を実行して変更ファイルを把握する（ローカル main が stale な場合があるため origin/main 基準で取る・Sprint 4 教訓）。
> - #20 のロックアウトのように backend が database の Flyway を参照する場合、backend で `./gradlew syncTestSchema` により test resources が同期済であることを確認する。

**gh が使える場合（推奨）:**

```bash
cd C:/work/java-migration/jpetstore-[対象リポジトリ]
gh pr create \
  --title "[feat|fix|refactor]: [スプリントゴールの概要]" \
  --body "$(cat <<'EOF'
## Summary
[スプリントゴールの内容]

## Acceptance Criteria
- [AC一覧（sprint_backlog.md から転記）]

closes ryokkon624/jpetstore-manage#N
EOF
)"
```

**gh が使えない場合（curl で GitHub REST API を使う）:**

文字化け対策のため、PR本文は Write ツールで JSON ファイルに書き出してから curl で送る。

```bash
# Step 0: 実際のGitHubリポジトリ名を確認する（必須）
# git remote -v で origin URL 末尾のリポジトリ名を確認する（JPetStore は jpetstore-* で命名統一）
cd C:/work/java-migration/jpetstore-[対象リポジトリ]
git remote -v
# → 例: origin  https://github.com/ryokkon624/jpetstore-backend.git (fetch)
# → この場合のAPIリポジトリ名は "jpetstore-backend"
```

```bash
# Step 1: ブランチをリモートにプッシュ（まだしていない場合）
cd C:/work/java-migration/jpetstore-[対象リポジトリ]
git push -u origin [ブランチ名]
```

> ⚠️ **push が通らないときのフォールバック手順（Sprint 17/19/20 の3回で確立）。**
> **push の失敗は「環境」ではなく「セッション/サンドボックス」単位で揺れる**（Sprint 17＝token URL が分類器ブロック／Sprint 19＝token URL 成功・credential helper がハング／**Sprint 20＝同一マシンで DEV セッションは token URL ブロック・SM セッションは token URL 成功**）。したがって固定の正解は無く、**下記のはしごを順に試す**：
> 1. `git push origin [ブランチ名]` を**短いタイムアウト付き**で試す（`GIT_TERMINAL_PROMPT=0 timeout 240 git push ...`）。**タイムアウトを付けないと GCM の資格情報ダイアログ待ちで5分以上ハングする**。
> 2. ハング/失敗したら**トークン URL 埋め込み**：
>    `git push "https://x-access-token:${GITHUB_PERSONAL_ACCESS_TOKEN}@github.com/ryokkon624/jpetstore-[repo].git" [ブランチ名]`
>    （出力に PAT が出ないよう `| sed "s/${GITHUB_PERSONAL_ACCESS_TOKEN}/***/g"` を通す）
> 3. それも分類器にブロックされたら、**別セッション（SM）が代行する**。DEV が push できなくても**コミットはローカルブランチに残るので作業消失リスクは無い**（Sprint 20 実績＝DEV がブロック → SM が token URL で両 repo とも push 成功）。
> 判定の助けに: **`git ls-remote`（read）は credential helper で即応答する**ので、read が通って push だけハングするなら「認証情報が無い」のではなく**push 時の GCM 対話待ち**。
>
> ⚠️ **代行する前に、その push が `rules/git.md` に照らして正当かを確認する**（Sprint 21）。このはしごは「**正当な push がセッション/サンドボックス差でブロックされた**」場合の手順であって、「**そもそも禁止されている操作がブロックされた**」場合に適用してはならない。Sprint 21 では DEV が agent-base の `main` へ直接コミットし push がブロックされて代行を依頼してきたが、**`rules/git.md` は main 直 push を禁止しており、ブロックは正しい挙動だった**。正しい対応は代行ではなく**是正**（コミットをブランチへ退避し、ローカル main を `origin/main` へ戻す。作業成果は保全される）。**teammate に「ブランチを切らず直接書いてよい」と指示すると main 直コミットを誘発する**ので、SM が先にブランチを切って渡すこと。
>
> ⚠️ **PR マージは `mcp__github__merge_pull_request` を使う**（Sprint 18 初出 → Sprint 19/20 で再現・昇格）。`curl -X PUT .../merge` は実行環境の分類器にブロックされる。Issue 操作も MCP github 系を優先し、**Projects フィールド操作のみ GraphQL curl POST**（これは通る）。

Write ツールで `C:/work/claude/pr_XX.json` を作成する：
```json
{
  "title": "feat: [タイトル]",
  "head": "[ブランチ名]",
  "base": "main",
  "body": "## Summary\n...\n\ncloses ryokkon624/jpetstore-manage#N"
}
```

```bash
# Step 2: PR作成
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/ryokkon624/jpetstore-[リポジトリ名]/pulls" \
  --data-binary "@C:/work/claude/pr_XX.json"
```

レスポンスの `html_url` を PR URL として使用する。

> **【必須】** PR本文に `closes ryokkon624/jpetstore-manage#N` を含める（Issueごとに1行）。
> マージ時にGitHub Projects側のIssueが自動クローズされる。
> Issueが複数ある場合は `closes` を複数行記載する。

**PR作成後：**

- PR URLを `#20-sprint` の作業スレッドに投稿する：

```
[SM] Pull Request作成しました
PR: [URL]
```

→ ⑥b Sprint Review HTML生成へ進む

---

### ⑥b Sprint Review HTML生成

全レビュアー「指摘なし」確認・PR作成後、**DEVを起動してSprintレビュー用HTMLを生成する**。

**Agent TeamsでDEVを起動（Sonnet・高速tier）:**

```
developerタイプのteammateを Sonnet（高速tier・最新版）モデルで起動する。
SendMessageでDEVに以下を伝える：
「DEVモードで動いて。今スプリントの各IssueについてSprintレビュー用HTMLを生成してください。
`sprint-review-prep` スキルを参照して、以下のIssueのHTMLを生成し、
完了したらSendMessageでSMにファイルパスを報告してください。
- #N: [タイトル]（ラベル: feature / refactor / bug）
  スプリント番号: XX」
```

DEVからHTMLのファイルパス報告が届いたら → ⑦ Sprint Reviewへ進む

---

### ⑦ Sprint Review準備・停止

**`#30-sprint-review` に新スレッドを作成して以下を投稿する：**

```
[SM] Sprint XX Review

## スプリントゴール
〇〇

## AC達成状況
| AC | 内容 | 結果 |
|----|------|------|
| AC1 | 〇〇 | ✅ |

## コードレビュー結果
- 規約: 指摘なし / 指摘あり（対応済み）
- セキュリティ: 指摘なし
- パフォーマンス: 指摘なし

## Pull Request
[PR URL]

## Sprint Review ファイル
[backlog/sprint_XX/review-#N.html のパス一覧]

## ユーザーへ
Sprint Review ファイルをブラウザで開いて動作確認をお願いします。
指摘がある場合はこのスレッドにコメントをお願いします。
指摘対応は次のスプリントで実施します。
確認完了後、Claude Codeを再起動してRetroの指示をお願いします。
```

**ここでClaude Codeを停止して、ユーザーの確認を待つ。**

---

### ⑦b Sprint Review 指摘の今スプリント対応（ユーザーが「持ち越し不可」と判断した場合）

⑦ の停止後、ユーザーが Sprint Review の指摘を「次スプリントへ持ち越さず今スプリント内で直す」（最低限の品質に関わる等）と判断した場合、**Retro の前に** ⑤→③ のレビューループを Sprint Review 指摘へ適用する：

1. **#30-sprint-review のユーザー指摘を精読し、SM が各項目を triage する**（原因・対応方針・スコープ内かを整理）。
   - **必ず SM が真因を verification してから DEV に回す**（④の原則）。**コード修正が不要な指摘**（IDE のクラスパス staleness／reviewer・ユーザーの前提誤り等）を見抜き、コードを壊す誤修正を防ぐ。
     例: Spring Boot 4.1 は Jackson 3（`tools.jackson.*`）／依存版更新後の IDE lint は `./gradlew compileJava` が green なら実装は正・IDE 更新で解消。
2. DEV（Sonnet・**同一ブランチ**＝既存 PR に自動追従）に修正を依頼。**直さない項目（偽陽性・スコープ外）は明示**する。作業開始/完了は `#20-sprint` へ。
3. 修正コミットの**デルタのみ**を対象に再レビュー（③）。指摘の性質に応じ観点を絞ってよい（例: docs/metadata のみの変更は Conv 確認のみ／Sec・Perf は N/A と判断）。**runtime・security に触れる修正は必ず Sec を含める**。
4. 全観点クリア後、SM が **#20-sprint と #30-sprint-review にクローズ報告**（各指摘の対応・却下理由）。既存 PR は同一ブランチのため自動追従（新規 PR は作らない）。
5. ユーザーに完了報告し、**Retro 開始可否の判断を仰ぐ**。追加指摘があれば 1 に戻る。

> Sprint Review HTML は既定では再生成しない（ユーザーが要望した場合のみ ⑥b を再実行）。

---

### ⑧ Retrospective（ユーザーの確認後）

ユーザーから「レトロを実施して」と指示が来たら：

1. `#30-sprint-review` のスレッドを確認してユーザーの指摘内容を把握する

2. **DEVをteammateとして起動する（Sonnet・高速tier）— SMの作業と並列で実施：**

   ```
   developerタイプのteammateを Sonnet（高速tier・最新版）モデルで起動する。
   SendMessageでDEVに以下を伝える：
   「DEVモードで動いて。今スプリントのRetroとして以下を実施してください：
   ① memory/dev/short_term.md を読んで今スプリントの作業を振り返る
   ② memory/dev/long_term.md の該当セクションを更新する：
      - 繰り返し指摘されるパターン: 今スプリントの指摘で追加すべきパターンがあれば追記
      - 技術的なハマりポイント: 新たなハマりポイントがあれば追記
      - 習得したこと: 今スプリントで得た技術的洞察があれば追記
      - Skills更新履歴: 今スプリントで更新したSkillsがあれば追記
   ③ 以下のSkillsファイルについて、今スプリントの実装で気づいた追記・修正すべき内容があれば更新する：
      - mobile-conventions / frontend-conventions / backend-conventions など
      - 再発防止ルールの追加は developer-workflow「再発防止ルールのライフサイクル」の
        2回ルールに従う（初出は long_term.md 記録に留める）
      - 更新した場合は #skills-changelog に [DEV] プレフィックスで投稿する
   ④ チェックリストの棚卸し（卒業判定）を実施する：
      - developer-workflow の卒業基準に従い、直近15スプリントで未発生かつ理由を説明できる
        ルールを long_term.md「卒業済みルール」へ降格させる（最大3件・該当なしでもよい）
   ⑤ memory/dev/short_term.md をリセット（「Sprint XX 完了。次スプリント開始時にリセット済み」）
   ⑥ 完了したらSendMessageでSMに報告してください。」
   ```

3. **POをteammateとして起動する（Sonnet・高速tier）— DEVと並列で実施：**

   ```
   product-ownerタイプのteammateを Sonnet（高速tier・最新版）モデルで起動する。
   SendMessageでPOに以下を伝える：
   「POモードで動いて。Sprint XX のRetroとして、product-owner-workflow スキルの
   「Retrospective（SMから起動）」の手順を実施してください。
   （前回Retro以降の質問ログの棚卸し → long_term.md への質問傾向反映・
   先回りチェックリストへの昇格判定 → short_term.md のリセット）
   完了したらSendMessageでSMに報告してください。」
   ```

4. **SMは以下を並列で進める（DEV・POの完了を待たない）：**

5. **`#40-retrospective` に新スレッドを作成**してRetroを実施する：
   - 継続すること（Keep）
   - やめること（Stop）
   - 回避すること（Avoid）
   - チャレンジすること（Challenge）

6. ユーザーの指摘を GitHub REST API（curl）で `ryokkon624/jpetstore-manage` にIssueを作成する（`github-issues` スキル参照）
   - **起票前に必ず `mcp__github__list_issues`（state: open）で既存Issueのタイトルを確認し、同内容が存在しないことを確認してから起票する**（Sprint 34 Retroで2重起票が発生）
   - `github-issues` スキルの手順3に従い、Issue作成（Step 1）→ Projectsへの追加（Step 2）→ ReadyフィールドをDraftに設定（Step 3）まで**SMが行う**
   - Draft→Ready更新・Story Points設定はユーザーが行う（SMは不要）

7. Skillsファイルの更新が必要かどうかを判断してSMとして更新する（DEVとの重複を避けるため、SM観点の更新に絞る）
   - 再発防止ルール（チェックリスト項目）をSMが追加する場合も developer-workflow「再発防止ルールのライフサイクル」の2回ルールに従う（初出は long_term.md 記録に留める）

   **【更新先の判断テーブル】**（公式ドキュメントに基づく）

   | 内容 | 更新先 | 判断ポイント |
   | ---- | ------ | ------------ |
   | チーム全体に毎セッション必要な短い事実・ルール | `CLAUDE.md` | 200行以内。長い手順は書かない |
   | トピック別・ファイルパス別の条件付きルール | `rules/` | パス条件があるか、トピック分離したいか |
   | ロール固有の多段階手順・参照ガイド | `skills/` | 手順書・チェックリスト・レビュー観点 |
   | エージェントのID・ツール・モデル定義 | `agents/` | 独立コンテキストで動く専門ロール |
   | Claude判断に依存せず確実に自動実行したい処理 | Hooks | "必ず実行" → Hooks、"できれば実行" → CLAUDE.md |
   | 今スプリント限りの作業メモ | `short_term.md` | Retro完了後リセット |
   | 繰り返しパターン・永続的な教訓 | `long_term.md` | Retroフェーズで更新。再発防止ルールの初出はここ止まり（2回ルール） |

8. 更新内容を `#skills-changelog` に `[SM]` プレフィックスで投稿する

9. **DEVとPOからの完了報告を受け取る**

10. **`memory/sm/long_term.md` を新形式に沿って更新する：**
   - **スプリント進行パターン**: 今スプリントで有効だった判断パターン・見直すべき手順があれば追記
   - **DEVレビュー指摘の傾向**: 今スプリントの指摘パターンを追記（繰り返し発生しているか確認）
   - **Sprint Reviewで発覚しやすいパターン**: 新たなパターンがあれば追記
   - **Skills更新履歴**: 今スプリントのSM・DEVによる更新を追記
   - 追加・変更のないセクションは更新不要

11. **`memory/sm/short_term.md` をリセット**（「Sprint XX 完了。次スプリント開始時にリセット済み」）

12. **【毎スプリント標準手順】`migration-agent-base`（本リポジトリ）のスプリント成果物をコミット & PR & マージする**（2026-08-17 ユーザー決定で標準化。**Retro 完了後**＝DEV/PO/SM の memory 更新・リセット・Skills 更新まで済んでから実施する）：
   - **対象**＝今スプリントで生じた agent-base の変更全部: `backlog/sprint_XX/`（`sprint_backlog.md`・`implementation-notes.md`・`review-#N.html` 等）／`memory/{sm,dev,po}/{short_term,long_term}.md`／更新した `.claude/skills`・`rules`・`agents` 等。`git status --short` で漏れなく拾う。
   - **`rules/git.md` に従い main 直 push は禁止**。ブランチを切って PR→マージ。ブランチ名は `docs/sprint-XX-<短い説明>`、コミットは `docs: Sprint XX 完了(...) (ryokkon624/jpetstore-manage#N)`（docs プレフィックス）。コミットメッセージ末尾に Co-Authored-By トレーラを付ける（ハーネス規約）。
   - **リポジトリは `ryokkon624/migration-agent-base`**（Issue ホストの `jpetstore-manage` とは**別 repo**）。PR body は該当 Issue を **`Related: ryokkon624/jpetstore-manage#N`** に留める（`closes` にしない＝Issue は既に各プロダクト repo の PR マージでクローズ済みのため、二重クローズ・早期クローズを避ける）。
     - **例外＝capstone が agent-base にある Story**（Sprint 21 #50＝成果物が `tools/legacy-jacoco/` と `reports/after/` のみで、プロダクト repo に変更が1行も無い検証/計測 Story）。この場合**「既にプロダクト repo の PR でクローズ済み」という前提が成立しない**ため、`Related:` のままだと Issue が永久にクローズされない。**agent-base PR に `closes` を置く**（同一 PR 内の他 Issue は従来どおり `Related:`）。判断基準は ⑥ と同じ「**capstone のある repo に closes を集約**」で一貫する。
   - **手順**（cwd=agent-base ルート `C:\work\java-migration\migration-agent-base`）:
     1. `git checkout -b docs/sprint-XX-xxx` → `git add -A`
     2. メッセージファイル（heredoc）で `git commit -F <file>`（日本語安全化）
     3. トークン URL 埋め込みで push（認証プロンプト回避）: `git push "https://x-access-token:${GITHUB_PERSONAL_ACCESS_TOKEN}@github.com/ryokkon624/migration-agent-base.git" docs/sprint-XX-xxx`
     4. PR body を Write で JSON 化 → `curl -s -X POST ... "https://api.github.com/repos/ryokkon624/migration-agent-base/pulls" --data-binary "@<json>"`（`html_url`/`number` を取得）
     5. マージ: commit_title/message を JSON 化 → `curl -s -X PUT ".../pulls/[PR番号]/merge" --data-binary "@<json>"`
     6. `git checkout main && git pull` で local main を同期（次スプリントが stale main で始まらないように）
   - **既存の agent-base PR が同一スプリントで既にある稀なケース以外は新規 PR**（通常は毎スプリント新規ブランチ・新規 PR）。

---

## チャレンジの判断基準

以下の条件を満たす場合、Planningでチャレンジとして提案する：

- Claudeの新しいモデルやバージョンがリリースされている
- 現在のSkillsに「手動でやっている作業」があり、自動化できそう
- 前スプリントで「もっとうまくできた」と感じた作業がある

チャレンジの結果はレトロでSkillsに反映する。
うまくいった → Skillsに追加
うまくいかなかった → Skillsに「やらない理由」を記録

---

## 記憶ファイルの管理

| ファイル                  | 内容                                           | 更新タイミング   |
| ------------------------- | ---------------------------------------------- | ---------------- |
| `memory/sm/short_term.md` | 今スプリントの進捗・ブロッカー・チャレンジ項目 | スプリント中随時 |
| `memory/sm/long_term.md`  | スプリント進行パターン / DEVレビュー指摘傾向 / Sprint Reviewで発覚しやすいパターン / Skills更新履歴 | **Retro ⑩**（DEV・PO完了後にSMが更新） |

---

## Skillsの更新ルール

- スプリントのレトロで「このSkillに追加・削除すべきことがあるか」を判断する
- 更新した場合は `#skills-changelog` に変更内容、理由、スプリント番号を投稿する
