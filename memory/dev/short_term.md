# DEV 短期記憶

## Sprint 23（#52 / #53・`docs/52-l4-ledger-verification`）— DEV 実測担当

PO が仕様側の判定、DEV が実測を担当する分担。プロダクトコードは1行も変更していない（3スプリント連続）。

### 成果物

| # | ファイル | 内容 |
| --- | --- | --- |
| 1 | `backlog/sprint_23/dev-observation-points.md` | 台帳 ID-1〜**33** × 観測点の対応（**33行・集約行なし**）。**L1 14／L2 4／L3 13／なし 2**（当初31件時点は L1 14／L2 4／L3 12／なし 1）。＋「未台帳差分の候補 A-1〜A-4」節・「次イテレーションの L2/L1 シナリオ候補」節。**33行すべての「検証手段」列に `根拠の所在` タグ（`be`/`fe`/`db`/`rep`）を付与**（SM 依頼・観測点がどのリポジトリ/資産に在るかを読み手が判別できるように） |
| 2 | `backlog/sprint_23/dev-gate-results.md` | 合否ゲート L1・L2・L3 の実行結果（L4 は DEV 担当外） |
| 3 | #53 掃除 | 事故ディレクトリ2つ削除＋`.gitignore` 追加＋`tools/legacy-jacoco/README.md` に「採取事故と回避策（#53）」節 |
| 4 | SM-1 訂正 | `reports/after/l2-parity-coverage.md` の「18シナリオ」7箇所 → 「17シナリオ」＋訂正根拠の注記 |

### 実測結果（数値）

- **L1**: backend `test` **362**／`integrationTest` **225**／frontend `npm run test` **267**（26ファイル）／（補足）database `test` **97**。**すべて failures 0・errors 0・skipped 0**（合計 951）。
- **L2**: `parityTest` **23テスト 0 failure**（うち golden 比較5 Spec が **19**＝レポート §S9 の「計19件」と一致）。
  ゲート値は `out3/report/gate-v2/jacoco.csv` を自分で合算し **BRANCH 28/34（82.4%）**・**INSTRUCTION 1360/1424（95.5%）** を検算・一致。未踏BRANCH6の内訳（`SqlMapItemDao`3・`SqlMapSequenceDao`1・`CartItem`1・`Cart`1）も一致。
- **L3**: backend §1 の **S1〜S21 = 21行**、「未対応」「不明」は **0行**。

### 次スプリント以降に効く発見（Retro 候補）

1. **`./gradlew test` は `UP-TO-DATE` でスキップされる**。「実行結果」を求められたら **`--rerun-tasks`** を付けないと、前回結果を実行結果として報告してしまう。今回は最初の実行で `:test` と `:parityTest` が UP-TO-DATE になり、気づいて再実行した。
2. **frontend に `npm run test:unit` は存在しない**（`package.json` の script は `test`＝`vitest run`）。指示の script 名を鵜呑みにせず `package.json` を見ること。
3. **台帳 ID の観測点は `ID-N` の grep では見つからない**。`jpetstore-backend/src/test` に ID 番号が文字列で現れるのは ID-1/2/8/11/14/17/20/22/23/24/28/29 だけで、**大半は ID 番号を書いていない AC テストが実質の観測点**だった。台帳の「新の振る舞い」を読んで、**振る舞い側からテストを探す**順序が必須。
4. **ID-7・ID-21・ID-23 の観測点は `jpetstore-database` にしか無い**（`information_schema` 表明テスト）。指示の対象リポジトリ（backend/frontend）だけを見ると、実在する観測点を見落として「穴」を3件水増しすることになる。読み取り専用で含めたうえで SM/PO に採否を確認中。
5. **`l3-security-regression-backend.md` の「うち10件をライブ実測」は数え方が曖昧**。§1 表の根拠列を機械的に数えると `live` 表記は **17行**、`code` のみは 4行（S2・S4・S20・S21）、両方併記が **10行**。「10」は**両方併記行の数**と一致する。SM-1（18→17）と同種の drift 候補として `verification-report.md` へ持ち込まないよう申し送った。
6. **`l3-security-regression-sprint20-delta.md` は「残存脆弱性0」ではない**（Low 4件が残る・レポート自身が「完全な clean とは書けない」と明記）。L3 ゲートの分母は before findings＝S1〜S21 なのでゲート判定には影響しないが、`verification-report.md` では分けて書く必要がある。

### 実測で判明した「穴」候補（#52 AC5 の入力）

- **`なし` は2件**: **ID-30**（チェックアウト下書きの非永続性。`checkout.spec.ts` 16ケースに `localStorage`/`sessionStorage` の言及が0件）と **ID-33**（カート一覧のページング廃止。backend/frontend とも `page`/`Pagination` の出現が0件で、「4件超が1レスポンスで返る」を観測しているテストが無い）。
- **部分観測6件**: ID-6（新＝SPA+REST の肯定側が未観測・§1 の S1 の ID 列は `ID-5`）／**ID-14**（L1 は3経路とも観測済みだが L2 は `order-detail` 経路の1本のみ）／**ID-22**（観測点はあるが S20-4 が「ID-22 の無言の後退」を Low で受容）／ID-23（`t_order.order_id` の AUTO_INCREMENT を assert する自動テストが無い・`m_account.user_id` だけ）／ID-26（`jpetstore-database` の `mysql-connector-j` 更新を観測しているレポート行が無い）／**ID-32**（`live`+`code` の観測はあるが `STATELESS` を assert する自動テストが 0件＝回帰検知器なし）。

### Sprint 23 後半（SM verification を受けた追加実測）

7. **「レポートに `ID-N` がある」は3種類ある**。`l3-security-regression-backend.md` の §1 回帰表が「対応 SBD / ID」列で ID を張っているのは **11件**（ID-2,4,5,9,10,11,12,13,14,25,26）だけで、**ID-1・ID-29 は §2.3（堅牢と確認した領域）**、**ID-22 は §2.1 の N3（ID-22 への「違反」として起票→Sprint20 で修正・回帰 spec 化）**、**ID-8 は §3-5（残件・PO 判断待ち）** が出所。**出所が §1 か §2 か §3 かで「観測点」「違反」「未解決事項」と意味が全く違う**ので、和集合 grep で数えてはいけない。
8. **「残り6分岐はすべて構造的に到達不能」は言い過ぎ**（SM V3 の指摘を legacy 実ソースで独立確認）。実際は4種類: 構造的到達不能2（`Cart.addItem` / `CartItem.getTotalPrice`）＋ seed 前提で到達不能1（`SqlMapSequenceDao.getNextId:19`）＋ **到達可能・スコープ外3**（`SqlMapItemDao.getItem:39` の `item == null` 側／`isItemInStock:30` の `i == null`・`i <= 0`）。正しくは「**現行シナリオ集合のスコープ内での上限**」。**ゲート値 28/34 は据え置き（AC-neg1）。**
9. **その到達可能な分岐が ID-14／ID-18 の未観測経路とちょうど一致した**。`spec/behavior/catalog.md:37` の3経路（`viewItem`/`viewCategory`/`viewProduct`）のうち L2 は1本も観測しておらず、`viewItem` 経路＝`SqlMapItemDao.getItem` の未踏分岐そのもの。**「カバレッジが低いから足す」ではなく「台帳 ID に観測点が無いから足す」で次シナリオを導出できた実例**（Sprint 22 Retro C2 の実行）。
10. **ゲート値は SM と DEV が独立に CSV を合算して完全一致した**（BRANCH 28/34・INSTRUCTION 1360/1424・残6の内訳）。レポートの記述を経由しない経路が2本とも同じ値に着地。
11. **SM も「レポートの記述どうしを突き合わせて」誤った**（V11: 台帳 ID-26 の CVE 根拠が誤りとした指摘を、PO の反証を受けて取り下げ。台帳＝`jpetstore-database` の 8.0.33→26.7.0、L3 §2.2＝`jpetstore-backend` の 9.5.0 で**対象アーティファクトが別**だった）。**座標（どのリポジトリのどの依存か）まで一次データで確認してから食い違いと呼ぶ**。生きているのは版乖離（同一ライブラリが 9.5.0 と 26.7.0 の2版で固定）のほう。
