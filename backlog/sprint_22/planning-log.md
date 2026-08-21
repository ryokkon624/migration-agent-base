# Sprint 22 Planning ログ（Discord 代替）

> ⚠️ **本スプリントでは Discord MCP サーバが未接続**（`mcp__discord__*` がセッションのツール一覧に出ない。`.mcp.json` には定義あり）。
> `#10-planning` / `#20-sprint` への投稿ができないため、投稿予定だった内容を本ファイルに記録する。
> 接続が回復したら、以下をそのまま投稿する（スレッドタイトルには `[JPS]` プレフィックス必須）。

---

## 1. `#10-planning` へ投稿予定（Forum 新規スレッド）

**スレッドタイトル**: `[JPS] Planning完了報告 Sprint 22`

```
[SM] Sprint 22 Planning 完了

## スプリントゴール
L2 パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、
未踏として名指しされている分岐を実際に踏んで、ゲート値を再合意する。

## 対象Issue
| Issue | タイトル | SP |
|-------|---------|-----|
| #51 | [L2] パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、ゲート値を引き上げる | 5 |

Project #2 の Sprint フィールドで Sprint 22 は #51 の1件のみを確認。PO Refinement 済み（2026-08-21）・Ready。

## 性格
Sprint 21 に続く「プロダクトコードを1行も変えない検証基盤スプリント」（2回目）。
jpetstore-backend の test スコープ単独 ＋ migration-agent-base（レポート/spec）。
cross-repo なし。legacy-jpetstore は起動のみ・無改変。

## Planning での SM verification（一次データで検算）
Refinement「確定3-④」に事実誤りが1件あり、ユーザー承認のうえ AC を訂正した。

- **SM-1**: 「W5 を2ケースに分割すれば SqlMapAccountDao の未踏4分岐を踏める」は成立しない（2ケースでは最大 3/4）。
  `if (password != null && password.length() > 0)` は 2分岐×2アウトカム＝4 で、到達には null / 空文字 / 非空 の3通りが必要。
  `getAccountByUsername` の resultMap が password 列を写さないため、`account.password` パラメータ自体を送らない POST
  でのみ null 側に到達する（ブラウザは常に空文字を送るため通常UI経路では到達しない）。
  → **W5 は 3ケース**に変更（ユーザー承認済み）。W5c は新側に対応概念が無いため「カバレッジ専用・パリティ観測点ではない」と明記する。
- **SM-2**: 到達可能上限の見積り = 30/34（88.2%）。AC7 の暫定目標 24/34 は余裕をもって達成可能な見込み（ただし実測が正）。
- **SM-3**: R8b に Sprint 21 の SM verification 所見①（検証資産の耐久性）を適用。
  ID-14 は「500＋スタックトレース露出」なので、HTTP ステータスとスタックトレース露出の有無を golden に固定させる。
- **SM-4/SM-5**: 新旧両側の実装上の落とし穴を先渡し（PUT /api/account の必須項目・PW変更時のトークンローテーション・
  旧 checkbox パラメータでの listOption/bannerOption 制御 等）。

## リスク・チャレンジ
- R1: AC5 と AC7 を別々に処理してしまう（分母が動くため成立しない）→ 同一タスク束として扱う
- R2: 除外だけで上がった数値を「カバレッジが向上した」と報告してしまう → SM が gate/jacoco.csv で検算する
- R3: Testcontainers に R__ が届かず GET/PUT /api/account が成立しない → m_profile 必須を先渡し済み
- R4: t_register_attempt / t_login_attempt の後始末漏れで ID-11 レート制限に阻まれる
- R5: docker stop を graceful にせず JaCoCo exec が書かれない
- R6: 採取用 legacy と新 backend の 8080 衝突
- R7: workingAccountForm が session scope のため W5c（null）が順序依存
- R8: POST /api/account/password のトークンローテーションで以降 401
- C1（チャレンジ）: design §4.4 の「未踏分岐から逆算 → シナリオ化 → 実測 → 再合意」ループを2周目として回す初回

## ブロッカー
- **Discord MCP サーバ未接続**。本 Planning 報告および Sprint 22 作業スレッドを Discord に作成できない。
  代替として backlog/sprint_22/planning-log.md に記録した。
```

---

## 2. `#20-sprint` へ投稿予定（Forum 新規スレッド）

**スレッドタイトル**: `[JPS] Sprint 22 作業スレッド`

```
[SM] Sprint 22 作業開始

スプリントゴール: L2 パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、
未踏として名指しされている分岐を実際に踏んで、ゲート値を再合意する。

## 対象Issue
| Issue | タイトル | ブランチ |
|-------|---------|---------|
| #51 | [L2] パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、ゲート値を引き上げる | feature/51-l2-parity-account-orders |

ブランチは SM が先に作成済み（新規作成しないこと）:
- jpetstore-backend: feature/51-l2-parity-account-orders（main = cb860a4 から）
- migration-agent-base: docs/sprint-22-l2-parity-account-orders（main = fac6098 から）
  ※ reports/after/l2-parity-coverage.md と spec/intended-diff-ledger.md の更新はこちらのブランチへ。
     main への直接コミットは rules/git.md で禁止。

DEVへ: backlog/sprint_22/sprint_backlog.md を読んで実装方針を整理してください。
特に「SM verification と計画フェーズ確定事項」（SM-1〜SM-6）は Refinement 本文より優先します。
```

---

## 3. 記録（Planning 実施内容）

- 実施日: 2026-08-21
- Issue 特定: GraphQL で Project #2 の Sprint フィールドを走査 → Sprint 22 = #51 のみ（SP 5・Ready）
- 読んだもの: #51 本文全文／`reports/after/l2-parity-coverage.md` §1-§7／`spec/l2-parity-design.md` §2・§4.4・§6／
  `.claude/rules/database.md`「R__ は Testcontainers ベースの自動テスト実行経路に届かない」節／
  `memory/sm/{short_term,long_term}.md`
- SM が一次データで検算したもの: `tools/legacy-jacoco/out2/report/gate/jacoco.csv`（BRANCH_MISSED 内訳・分母34の再現）／
  `legacy-jpetstore` の `SqlMapAccountDao` `SqlMapOrderDao` `Account` `Account.xml` `AccountActionForm`
  `NewAccountAction` `EditAccountAction` `EditAccountFormAction` `ViewOrderAction` `ListOrdersAction`
  `struts-config.xml` `web.xml` `applicationContext.xml` `petstore-servlet.xml` 各 JSP／
  `jpetstore-backend` の `AccountController` `RegistrationController` `OrderController` `ParityScenarios`
- ユーザー確定事項: **W5 は 3ケース**（SM-1）
- 成果物: `backlog/sprint_22/sprint_backlog.md`・両 repo の作業ブランチ・`memory/sm/short_term.md` 更新

---

## 4. DEV Planning（計画フェーズ）— Discord 代替記録

> **Discord MCP は本セッションでも未接続**（`mcp__discord__*` 不可）のため、`#10-planning` へ投稿予定だった
> 内容を以下に記録する。接続回復後にそのまま投稿する（スレッドタイトルには `[JPS]` プレフィックス必須）。

- 実施日: 2026-08-21
- 実施者: DEV
- 状態: **実装方針をユーザーへ提示済み・承認待ち（Q1〜Q7 未回答）**。実装・コミットは未着手。
- 詳細な方針全文: `memory/dev/short_term.md`（Sprint 22 / Issue #51 節）

**スレッドタイトル案**: `[JPS] DEV 計画フェーズ完了報告 Sprint 22 (#51)`

```
[DEV] Sprint 22 / #51 計画フェーズ完了（実装は未着手・ユーザー承認待ち）

## 読んだ一次情報
#51 本文全文＋SM-1〜SM-6／reports/after/l2-parity-coverage.md §3-§5／spec/l2-parity-design.md §2・§4.4／
rules/database.md「R__ は Testcontainers に届かない」節／既存 parity 資産一式（22ファイル・golden 9本）／
tools/legacy-jacoco/report.sh・README.md／legacy 実コード（Struts Action・iBATIS map・web.xml・
applicationContext.xml・petstore-servlet.xml・各 JSP）／新 backend 実コード（Account/Registration/Order
Controller・ApplicationService・Mapper XML・Flyway スキーマ）

## 実コードで見つかった訂正2件（Issue 本文／SM-2 の誤り）
- 訂正A: **R8b の新側は 404 ではなく 403**。OrderApplicationService.java:171-179 が不存在も非所有も同一の
  AccessDeniedException にし、GlobalExceptionHandler.java:102-109 が 403 に正規化する（ID-4 と重畳）。
  ID-14 の趣旨（500＋スタックトレース露出 → 露出なし）は 403 でも成立するため R8b は ID-14 のままとし、
  台帳 ID-14 に注記を足す方針。
- 訂正B: **到達可能上限は 30/34 ではなく 29/34**。CartItem の未踏1分岐は getTotalPrice() の
  `if (item != null)` の false 側で、CartItem は Cart.addItem() 内でしか生成されず必ず setItem(非null)
  されるため HTTP 経路から構造的に到達不能。AC4 で踏めるのは Cart の3のみ。
  クラス粒度の除外機構では落とせないため分母34は据え置き（#50 §5-5 と同じ理由）。
  AC7 暫定目標 24/34 は依然余裕あり。**数値は実測が正・ゲート値は実測後に PO と再合意**。

## 方針サマリ
- 台帳に8行追加（account-register / account-edit-nopw / account-edit-pw / account-edit-pwfield-absent /
  orders-list / order-detail-own / order-detail-missing / cart-boundary）。W3 が末尾のままになるよう直前に挿入。
- ParitySnapshot に4フィールド追加（account: Map・accountsCreated・httpStatus・stackTraceExposed）。
  判定規則そのものは無変更（AC6）。R8b の divergentFields = ["httpStatus","stackTraceExposed"]、
  例外クラス名は比較対象外の preconditions に証拠として残す。
- SM-3 の自己点検（「前提が崩れたとき parityTest は落ちるか？」）に全10前提で回答し、落ちないものは
  採取時 assert（満たさなければ golden を書き出さず fail）で担保する表を作成。
- W5c の順序依存は resetSession() ＋ editAccountForm.do 直後の POST で構造的に解消
  （getAccountByUsername の resultMap が password 列を写さないことを実物で確認）。
- Testcontainers フィクスチャは m_account/m_signon/**m_profile** を直接 INSERT（AccountEditCustomMapper が
  JOIN するため）。後始末は t_audit_log / t_login_attempt / **t_register_attempt**（PK は client_ip・
  成功時リセット無し・5回/15分）まで含める。
- AC-neg4 は AccountParitySpec の別 feature（golden には載せない）。実パスは POST /api/auth/login。
- AC5 は「両バリデータとも到達不能」で確定（web.xml L87-91 で petstore は宣言されるが L134-145 で
  servlet-mapping がコメントアウト・唯一の呼び出し元は petstore-servlet.xml L37/L98/L108 の Spring MVC
  コントローラのみ）。§3 の AccountValidator 記述は誤りとして訂正する。
- AC-neg3 は既存3クラス ==0 を維持し、2クラスは BASELINE_EXCLUDED="OrderValidator:3:0 AccountValidator:3:0"
  のベースライン方式（実測根拠は out2/report/ac1/jacoco.csv）。
- AC5 と AC7 は一体。report.sh を3本出し（ac1 / gate=3除外 / gate-v2=5除外）にし、#50 の exec と今回の exec の
  両方に同じ report.sh を流すことで (a) 除外による分母縮小 と (b) 追加シナリオによる被覆増 を
  **手計算ゼロで分離**して報告する。

## ユーザーへの確認事項（Q1〜Q7・未回答）
Q1 R8b を ID-14 のままとし台帳へ注記を足すか／Q2 29/34 をレポートに明記するか／
Q3 W5 の編集対象をシナリオ自己完結方式にしてよいか（AC2 の解釈）／Q4 report.sh 3本出し／
Q5 AC-neg3 を != で fail にするか／Q6 productName・orderDate の正規化除外の明記／
Q7 spec/l2-parity-design.md §2・§6-2 の更新を本スプリントに含めるか
```

---

## 5. DEV Planning — Q1〜Q7 確定（2026-08-21）

> ユーザー確定3件（Q1・Q3・Q6 の productName）＋ SM 判断4件（Q2・Q4・Q5・Q6 の orderDate・Q7）で全件決着。
> 訂正A（R8b=403）・訂正B（上限 29/34）はいずれも SM が一次データで独立確認し、**DEV の指摘が正しいと確定**。
> 反映先: `memory/dev/short_term.md`（§0・§1・§2・§3・§4・§5・§8・§10・§12・§13）。

| # | 確定回答 | 判断者 |
| --- | --- | --- |
| Q1 | **R8b は `INTENDED_DIVERGENCE(ID-14)` のまま**。台帳 ID-14 に「注文詳細経路は ID-4 と重畳して 403」の注記＋関連Story に #51 追記 | ユーザー |
| Q2 | 到達可能上限 **29/34** をレポートに明記。**分母 34 は据え置く**（手計算での分母縮小は #50 §5-5 の drift を再導入するため） | SM |
| Q3 | W5 の編集対象は**シナリオ自己完結方式**（`parity_w5a/b/c` を各自登録・各自削除）。`j2ee` は不変 | ユーザー |
| Q4 | `report.sh` **3本出し**（`ac1`/`gate`=3除外/`gate-v2`=5除外）。DoD の「2本」は部分集合として充足 | SM |
| Q5 | AC-neg3 のベースライン判定は **`!=` で fail**。増（前提崩壊）と減（bean 定義の変化）で**メッセージを書き分ける** | SM |
| Q6 | **分割回答**。`orderDate` は正規化除外で可。**`productName` は除外せず R8a を `INTENDED_DIVERGENCE(ID-24)` の観測点にする**。`/api/auth/login` の訂正は採用 | orderDate=SM／productName=ユーザー |
| Q7 | `spec/l2-parity-design.md` §2 台帳への8行追加・§6 未決事項2 の解決反映を**本スプリントに含める** | SM |

### Q6 に伴う設計変更（当初 DEV 推奨からの変更点）

- `order-detail-own`（R8a）の expectation を `EQUIVALENT` → **`INTENDED_DIVERGENCE(ID-24)`** に変更。
  `divergentFields = ["lines[EST-1].productName"]`。
- `ParitySnapshot.Line` に `productName`（`@JsonInclude(NON_NULL)`）を追加。`entries` に畳まないのは、
  畳むと差分が単一の粗いフィールドにまとまり `divergentFields` の完全一致判定（Q4 確定）が他の差分を
  巻き込んで検知できなくなるため。W1/W2/W3 は両側とも DB から組むので productName は両側 null＝差分ゼロ。
- **ID-24 の前提を DEV が実コードで裏取り済み**: `dao/ibatis/maps/LineItem.xml:14-16` の
  `getLineItemsByOrderId` は `orderid, linenum, itemid, quantity, unitprice` しか読まず `LineItem.item` を
  一切埋めない（`domain/LineItem.java:14` の `item` は `LineItem(int, CartItem)` ＝注文確定時の構築経路でしか
  設定されない）。よって `ViewOrder.jsp` の description セルは全て空になる。
- **SM-3 を R8a にも適用**: 採取時に「旧の productName が空」を assert し、満たさなければ golden を書き出さず fail。
- `intended-diff-ledger.md` は **ID-14 の注記＋関連Story追記／ID-24 の関連Story追記** を1回の編集でまとめる。
- R8a が Issue スコープ表の「EQUIVALENT」から外れる点は、Sprint Review の AC 達成状況で **SM が PO へ明示報告**する。

### Q3 に伴う必須対応

`t_register_attempt` は **client_ip 単位・5回/15分・成功時リセット無し**（`V00_000_012__create_register_attempt.sql:35`）。
自己完結方式では W4＋W5a/b/c で同一IPから **4回**登録し上限5に肉薄するため、`setup()` の全行 DELETE に加えて
**429 を受けたら「レート制限に当たった（`t_register_attempt` の残存を疑え）」と分かるメッセージで fail** させる。

### SM が別途対応する項目

- `backlog/sprint_22/sprint_backlog.md` の **SM-2（30/34）を 29/34 へ訂正**。
- Sprint Review で **R8a の expectation 変更（スコープ表からの意図的逸脱）を PO へ明示報告**。

---

## 6. DEV Implementation（実装フェーズ・2026-08-21）

`#20-sprint` への投稿予定内容（Discord MCP 未接続のため本ファイルに記録。§0 参照）。

### 開始

`jpetstore-backend`＝`feature/51-l2-parity-account-orders`（`cb860a4`から分岐・SM作成済み）、
`migration-agent-base`＝`docs/sprint-22-l2-parity-account-orders`（SM作成済み）の両ブランチで、
`memory/dev/short_term.md` §1〜§13 の確定方針どおりTDDで実装。§12のQ1〜Q7は再質問せず確定回答のまま反映。

### TDD

RED（`ParitySnapshotSpec`/`ParityComparatorSpec`/`LegacyHtmlExtractorSpec`に20件追加・実行して
`MissingPropertyException`/`MissingMethodException`でfailすることを確認）→ GREEN（`ParitySnapshot`/
`ParityComparator`/`LegacyHtmlExtractor`を実装）→ Runner/Spec実装 → legacy起動 →
`captureGolden`（golden 8本を採取・コミット）→ legacy停止で`parityTest` green、の順で進めた。

### 実装中に見つかった3件の訂正（いずれもDEVが実コード/実測で発見・独立に裏取り済み）

1. **`accountEdit`のW5系登録ステップで`newAccountForm.do`のGETが抜けており500（`BeanUtils.populate`の
   `IllegalArgumentException: No bean specified`）になっていた。** `NewAccountFormAction`が
   `session.workingAccountForm.account`を空`Account`で初期化する処理を経ないと、POSTのネストプロパティ
   設定（`account.username`等）がbean未初期化で失敗する。`accountRegister`（W4）は元々GETしていたため
   顕在化せず、`accountEdit`（W5）だけ欠けていた。修正: `newAccount.do`POST前に`newAccountForm.do`GETを追加。
2. **HSQLDB列エイリアスの大文字小文字ドリフト。** `LegacyDbReader`の汎用`queryRow`/`queryRows`ヘルパーは
   列ラベルを`toLowerCase()`する実装（既存の`orderRow`等が前提とする挙動）だったため、新設した
   `accountRow`のSQLで`AS firstName`のようなcamelCaseエイリアスを使っても`firstname`に落ちてしまい、
   新側（MySQL・`NewDbReader#accountRow`はcamelCaseのまま返る）とキーが一致せず`account[firstName]`と
   `account[firstname]`が別キー扱いになって全アカウント系シナリオが偽の不一致でfailする状態だった
   （captureGoldenで実際に出力してから発覚）。修正: 両`accountRow`とも列ラベルに依存せずordinal位置で
   canonicalキーを直接組み立てる方式に変更（ドライバ非依存の防御的設計）。
3. **`Cart.addItem()`の`cartItem != null`false側も構造的に到達不能（`CartItem`と同型の新発見）。**
   計画フェーズのSM訂正「理論上限29/34」は、`cart-boundary`の2回目`addItemToCart.do`が
   `Cart.addItem()`のfalse側を踏む前提だったが、実コードを読むと`AddItemToCartAction`/
   `AddItemToCartController`はいずれも`containsItemId`で事前ガードしてから`addItem()`を呼ぶため、
   `addItem()`内部の`cartItem == null`判定は常にtrueで、2回目は`incrementQuantityByItemId`
   （分岐を持たないメソッド）に迂回するだけだった。実測（`out3/report/gate-v2/jacoco.csv`）でも
   `Cart`のbranch coverageは5/6（missed=1のまま）で理論と一致。**理論上限は29/34ではなく28/34が正**
   （30→29→28の3段階訂正。詳細は`reports/after/l2-parity-coverage.md` Sprint22追記S5）。

### インフラの落とし穴（新規発見）

Git Bash（MSYS）から`docker run -v <host>:/jacoco ...`を実行すると、MSYSのパス変換が`-v`引数中の
コンテナ側絶対パス`/jacoco`を誤ってホストパスとして解釈し、ボリュームが正しくバインドされず
`jacoco.exec`がホストに一切書き出されない（`docker inspect`の`Destination`が`\Program Files\Git\jacoco`
のような壊れた値になる）。`MSYS_NO_PATHCONV=1`を先頭に付けて回避した
（`tools/legacy-jacoco/README.md`に追記済み）。

### 実測結果（サマリ・詳細は`reports/after/l2-parity-coverage.md` Sprint22追記）

| 指標 | #50実測（旧9シナリオ・gate=3除外・分母1588/34） | 本Story実測（新18シナリオ・同分母） | 本Story実測（同・gate-v2=5除外・分母1424/34） |
| --- | --- | --- | --- |
| BRANCH | 16/34 (47.1%) | **28/34 (82.4%)** | 28/34 (82.4%・分母不変) |
| INSTRUCTION | 1144/1588 (72.0%) | 1366/1588 (86.0%) | **1360/1424 (95.5%)** |

(a)除外だけの効果＝旧シナリオ集合をgate-v2で再計算: 1138/1424 (79.9%)。
(b)追加シナリオの効果＝gate-v2同一分母での新−旧: 1360−1138=+222 instruction（+15.6pt）。
AC7暫定目標（BRANCH ≥ 24/34・PO合意済み）は実測28/34で達成。PO再合意案はレポートS6参照。

### 完了

`./gradlew test`・`./gradlew parityTest`（legacy停止状態）とも green（parityTest 19件・test内
`ParityScenariosSpec`3件含む）。`AC-neg3`の除外反証チェック（STRICT 3クラス・BASELINE 2クラス）も
`report.sh`実行時に自動passを確認。golden 8本コミット・`intended-diff-ledger.md`（ID-14注記+関連Story・
ID-24関連Story）・`spec/l2-parity-design.md`（§2に8行・§6未決事項2を解決済みに更新）・
`tools/legacy-jacoco/report.sh`（3本出し）・`reports/after/l2-parity-coverage.md`（Sprint22追記S1〜S9）
をいずれも更新済み。SMへ完了報告済み（コミットハッシュ等は報告メッセージ参照）。

---

## 7. `#30-sprint-review` へ投稿予定（Forum 新規スレッド）

> Discord MCP 未接続のため投稿できず。再起動後に本文をそのまま投稿する。

**スレッドタイトル**: `[JPS] Sprint 22 Review`

```
[SM] Sprint 22 Review

## スプリントゴール
L2 パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、
未踏として名指しされている分岐を実際に踏んで、ゲート値を再合意する。

## AC達成状況（#51）
| AC | 内容 | 結果 |
|----|------|------|
| AC1 | W4 アカウント新規登録 | ✅ |
| AC2 | W5 アカウント編集（**3ケース**・SM-1で2→3へ訂正） | ✅ |
| AC3 | R7 / R8a / R8b ＋ ID-14 台帳追記 | ✅（※R8a は意図的逸脱あり・下記） |
| AC4 | カート境界値 | ✅ |
| AC5 | バリデータ2クラスの配線調査 | ✅ 両クラスとも到達不能と確定・§3の誤記述も訂正 |
| AC6 | 先例規約の踏襲（仕組み無変更） | ✅ |
| AC7 | ゲート値の再合意 | ✅ 実測ベースで再合意案を提示（PO判断待ち） |
| AC8 | legacy 停止状態で parityTest green | ✅ SMが独立に --rerun で再実行し確認 |
| AC-neg1〜5 | 宣言不一致fail／legacy無改変・後始末／除外の機構担保／ID-2案A担保／Testcontainersフィクスチャ | ✅ すべて充足 |

## コードレビュー結果
- 規約: 指摘なし
- セキュリティ: 指摘なし
- パフォーマンス: 指摘なし
- SM独立verification: 2件検出 → 1件是正（R8bの前提assertが新側に無く旧側と非対称だった）・
  1件はSMの誤検出と判明（(a)/(b)は手計算ではなく機構出力だった）

## parityTest（legacy 停止状態・SM が --rerun で強制再実行）
23 tests / failures 0 / errors 0
（AccountParitySpec 6・CatalogParitySpec 6・OrderHistoryParitySpec 3・OrderParitySpec 3・
 CartParitySpec 1・NewHttpClientSpec 3・ParityIntegrationTestBaseSmokeSpec 1）
23 = シナリオSpec 19（＝17シナリオ＋AC-neg4の独立検証2）＋インフラSpec 4

## 計測結果（(a)/(b) を機構出力で分離）
|  | gate（3除外・分母1588） | gate-v2（5除外・分母1424） |
|---|---|---|
| 旧9シナリオ（#50 exec） | 1144/1588 = 72.0%・BRANCH 16/34 | 1138/1424 = 79.9% ←(a)除外のみ |
| 新17シナリオ（今回 exec） | 1366/1588 = 86.0%・BRANCH 28/34 = 82.4% | 1360/1424 = 95.5% ←(a)+(b) |

(b) 追加シナリオの効果 = 1360 − 1138 = +222 instruction（+15.6pt）
BRANCH の 16→28（+12）はすべて (b)（両除外クラスとも総分岐数0のため除外の影響なし）
実測 28/34 は到達可能な理論上限ちょうど。残る6＝SqlMapItemDao 3・SqlMapSequenceDao 1（スコープ外）／
Cart 1・CartItem 1（構造的に到達不能）

## ★ PO へ明示報告する2件

### (1) R8a の expectation 変更＝Issue スコープ表からの意図的逸脱
Issue の表では R8a = EQUIVALENT だったが、Q6（ユーザー判断）で
INTENDED_DIVERGENCE(ID-24) へ変更した。理由＝productName は平文PW vs ハッシュ（ID-2・確定2）と違い
値として比較可能で、除外すると台帳 ID-24 が観測点を持たないまま残るため（design §5 の狙いに反する）。
旧の実体も裏取り済み（LineItem.xml の getLineItemsByOrderId が LineItem.item を埋めないため
ViewOrder.jsp の description セルが空）。

### (2) ゲート値の再合意案
| 指標 | #50 合意フロア | 提案フロア |
|---|---|---|
| BRANCH | ≥ 16/34（47.1%） | ≥ 28/34（82.4%） |
| INSTRUCTION | ≥ 1144/1588（72.0%・gate） | ≥ 1360/1424（95.5%・gate-v2 へ分母切替） |
絶対数を正・%は可読形（#50 と同じ作法）。#50 の暫定目標 BRANCH ≥24/34 は達成済み。
分母を gate → gate-v2 に切り替える提案なので、#50 §5-2「分母の変更自体が再合意のトリガ」に該当する。

## 今スプリントで訂正された事実（5件）
| 項目 | 誤 | 正 | 検出 |
|---|---|---|---|
| W5 のケース数 | 2 | 3 | SM（Planning・実コード） |
| R8b の新側ステータス | 404 | 403 | DEV |
| AC-neg4 のログインパス | /api/login | /api/auth/login | DEV |
| 到達可能上限 | 30/34→29/34 | 28/34 | DEV（2段階とも・初出値はSM） |
| 「(a)/(b) が手計算」 | — | SM の誤検出（機構出力だった） | DEV |
※ Issue #51 本文そのものの訂正（上3件）は PO が次回 Refinement で一括対応する方針。

## Pull Request
https://github.com/ryokkon624/jpetstore-backend/pull/22 （closes #51・未マージ）
※ migration-agent-base 側は step12（Retro後）で PR を作成する。

## Sprint Review ファイル
backlog/sprint_22/review-#51.html

## ユーザーへ
Sprint Review ファイルをブラウザで開いて確認をお願いします。
指摘がある場合はこのスレッドにコメントをお願いします。指摘対応は次のスプリントで実施します。
確認完了後、Claude Code を再起動して Retro の指示をお願いします。
（再起動は Discord MCP の復旧も兼ねます。）
```

---

## 8. Discord バックフィル完了記録（2026-08-21・Retro セッション）

セッション再起動により Discord MCP の疎通が回復（`scrum-agent#2250` でログイン・読み書きとも成功）したため、
本ファイルに退避していた §1 / §2 / §7 の内容を**事後バックフィル投稿**した（各投稿に「事後投稿である」旨を明記）。

| 退避元 | 投稿先 | スレッドタイトル | スレッドID |
| --- | --- | --- | --- |
| §1 | `#10-planning` | `[JPS] Planning完了報告 Sprint 22` | `1540233360960524322` |
| §2 | `#20-sprint` | `[JPS] Sprint 22 作業スレッド` | `1540233513008369674` |
| §7 | `#30-sprint-review` | `[JPS] Sprint 22 Review` | `1540233566749720646` |
| （Retro） | `#40-retrospective` | `[JPS] Sprint 22 Retrospective` | `1540234475059941406` |

**判明した制約**:
- **1メッセージ 2000 文字上限**。§1 / §7 / Retro はいずれも超過したため、新規スレッド作成＋`discord_reply_to_forum` で分割投稿した。
- `discord_get_forum_channels`（ギルド単位のチャンネル一覧）は権限エラーになるが、**チャンネルID直指定の投稿・返信には影響しない**。

**未対応の潜在バグ（ユーザー判断待ち）**: `discord` MCP が2箇所で定義され env 変数名が食い違う。
プロジェクト `.mcp.json`=`DISCORD_TOKEN`（正・パッケージが読む名前）／ユーザー `~/.claude.json`=`DISCORD_BOT_TOKEN`（誤）。
ユーザースコープが優先されるとトークン無しで起動し、投稿前に `discord_login` が必須になる。
