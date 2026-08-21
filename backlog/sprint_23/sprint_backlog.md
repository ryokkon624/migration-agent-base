# Sprint 23 バックログ

- **期間**: 2026-08-21 〜
- **スプリントゴール**: **意図差分台帳31件すべてに「どう検証したか／なぜ検証しないか」の判定と根拠を与え、Phase 4 の最終成果物 `reports/after/verification-report.md` を作る（＝Phase 4 完走・Phase 0〜4 の一気通貫の完成）。**
- **対象 Issue**: `ryokkon624/jpetstore-manage#52`（8SP・`foundation`/`documentation`・Ready）／`#53`（1SP・`refactor`・Ready）
- **ブランチ**: `docs/52-l4-ledger-verification`（`migration-agent-base`・**新規**／`main` = `8d5e71f` から分岐。**SM が事前に作成済み**）
- **リポジトリ**: `migration-agent-base` **単独**（`reports/after/` ＋ `spec/` ＋ `tools/`）。`jpetstore-backend` / `jpetstore-frontend` は**読み取りとテスト実行のみ**（1行も変更しない）。`legacy-jpetstore` は**起動もしない**。

| Issue | タイトル | SP | ラベル |
| --- | --- | --- | --- |
| #52 | [L4] 意図差分台帳31件 × 検証手段の対応表を作り、Phase 4 verification-report を完成させる | 8 | foundation / documentation |
| #53 | [chore] tools/legacy-jacoco の採取事故ディレクトリを掃除し .gitignore で再発防止する | 1 | refactor |

---

## このスプリントの性格（Sprint 21・22 に続く「プロダクトコードを1行も変えない」3回目）

Sprint 21（#50 計測とゲート値合意）・Sprint 22（#51 シナリオ拡張と再合意）は**検証基盤**を作るスプリントだった。
Sprint 23 は**その検証基盤が「台帳のどの項目を、どこまで見ているのか」を突き合わせる**スプリント。

**L2 のカバレッジ軸は正しく枯れた**（BRANCH 28/34 ＝ 到達可能な理論上限ちょうど）。
残6分岐は `SqlMapItemDao` 3・`SqlMapSequenceDao` 1（スコープ外）／`Cart` 1・`CartItem` 1（構造的に到達不能）で、
**シナリオを何本足しても動かない**。よって次の一手は「分岐を増やす」ではなく「**観測点の質**」＝
**台帳 ID に対して観測点があるか**へ軸を移す（Sprint 22 Retro C2）。それが L4 の評価尺度そのもの。

> **Phase 4 の価値は「正しく再現したと言える範囲を、言えない範囲と一緒に明示すること」にある。**
> **観測点が無いことを隠さない。「穴」は穴として書く。**

---

# Issue #52 本文（全文転記）

## ユーザーストーリー

**As a** JPetStore 移行の説明責任を負うステークホルダー（および PO / SM）
**I want to** 意図差分台帳（ID-1〜ID-31）の**全項目**について「どう検証したか／なぜ検証しないか」を確定した対応表がほしい
**So that** 「旧を正しく再現できたと**言える範囲**」を、「**言えない範囲**」と一緒に提示でき、Phase 4 の合否ゲート（`verification-strategy.md` §5）を判定できる

## 位置づけ

**Phase 4 の締め＝L4（台帳照合）**。Phase 4 の検証4レイヤのうち L1（AC準拠）・L2（パリティ）・L3（セキュリティ回帰）は完了済み。

- **L2 は BRANCH 28/34 で理論上限に到達**（残6分岐は構造的に到達不能／スコープ外）。**カバレッジ軸は正しく枯れた＝分岐数を増やす方向にはもう伸びない**。
- Sprint 22 Retro で SM が「次は**観測点の質**（台帳 ID に対する観測点の有無）へ軸を移すべき」と提起した。これは **L4 の評価尺度そのもの**なので、新しい L2 イテレーションを立てず **L4 として実施する**。
- 本 Story が完了すれば **Phase 0〜4 の一気通貫が完成**する。

## トレース

- `spec/verification-strategy.md` §1（4レイヤ）・§4（意図差分台帳）・§5（合否ゲート）・§6（使いどころ）
- `spec/intended-diff-ledger.md`（ID-1〜ID-31・**PO 所有**）
- `reports/after/l2-parity-coverage.md`（#50 §5 ＋ #51 S1〜S10。到達点と理論上限の根拠）
- `reports/after/l3-security-regression-backend.md`（S1〜S21 回帰表）／`-frontend.md`／`-sprint20-delta.md`
- `jpetstore-backend`: `src/test/groovy/.../parity/ParityScenarios.groovy`（expectation 宣言の実体）／`src/test/resources/parity/golden/*.json`（17本）

## 現状の把握（**参考値。DEV/PO が一次データで確認し直すこと**）

SM が Planning 時に一次データで確認した暫定値。**これを転記して対応表を作ってはならない**（AC3）。

- **L2 の明示宣言は4件**: `ParityScenarios.groovy` の `INTENDED_DIVERGENCE` は **ID-1 / ID-14 / ID-24 / ID-29**（残り13シナリオは `EQUIVALENT`）。golden は17本。
- **L3 の回帰表が触れている ID**（3レポートの和集合・grep 実測）: ID-2・4・5・6・8・9・10・11・12・13・14・15・22・25・26・29・31（＋ ID-1）
- **L2 にも L3 にも出てこない ID**（＝L1 か「観測不能／不要／穴」に落ちるはずの群）: **ID-3・7・16・17・18・19・20・21・23・27・28・30**（12件）
  - このうちテスト内に ID 番号が明示されているのは ID-7・17・20・21・23・28 程度で、**ID 番号を書いていない L1 AC テストが観測点になっている可能性が高い**（例: ID-16 → `StrongPasswordValidatorSpec`、ID-28 → `StockStatusCalculatorSpec`）。**grep だけで「穴」と断じないこと。**

## Acceptance Criteria

### AC1: 台帳ID × 検証手段の対応表（31行）

`reports/after/verification-report.md` に対応表を作る。

- **ID-1 〜 ID-31 の31件すべてに独立した行がある**（「ID-16〜19 はまとめて L1」のような集約行は**不可**）。
- 各行の列: **ID** / **何をどう変えたか**（台帳からの1行要約） / **検証手段**（L1 / L2 / L3 / なし） / **根拠** / **判定**
- **根拠は名指し**であること:
  - L2 → シナリオ ID（例 `order-insufficient-stock`）＋ `ParityScenarios.groovy` の宣言＋ golden ファイル名
  - L3 → レポート名と行（例 `l3-security-regression-backend.md` §1 の **S7**）
  - L1 → **実在する Spec クラス名 + 実在するテストメソッド名**（例 `StrongPasswordValidatorSpec#...`）／frontend は `*.spec.ts` のテスト名
  - コード位置は `file:line` 形式

### AC2: 判定は4分類。**全 ID に観測点を作る必要はないが、分類の根拠は必ず書く**

| 判定 | 意味 |
| --- | --- |
| **観測点あり** | L2 の expectation 宣言 / L3 の回帰表 / L1 の AC テスト のいずれかで検証済み |
| **構造的に観測不能** | 比較対象が存在しない（例 ID-6 JSP→SPA は UI 総取替） |
| **観測不要** | もはや差分でない（例 ID-27 多言語は #25 で実装完了） |
| **穴** | 観測点が無く、作るべき ← **ここだけが次の作業になる** |

- 「構造的に観測不能」「観測不要」は**そう言い切れる根拠**を書く（「比較対象が無い」と書くだけは不可）。
- **穴は穴として書く**。観測点が無いことを隠さない。

### AC3: 一次データで裏取りする（レポートの転記禁止）

対応表の各セルは**現物を開いて**確認する。

- L2 → `ParityScenarios.groovy` と `src/test/resources/parity/golden/*.json` の実体
- L3 → 各回帰レポートの当該行
- L1 → 実在する Spec / spec.ts の実在するテスト名（**存在しないテスト名を書かない**）
- 「本 Issue の“現状の把握”に書いた参考値」「他レポートの記述」を**そのまま転記しない**

### AC4: 合否ゲート判定（`verification-strategy.md` §5）

`verification-report.md` に4ゲートの PASS/FAIL と根拠を書く。

| ゲート | 判定基準 | 必要な根拠 |
| --- | --- | --- |
| **L1** | 全 AC テストが green | `./gradlew test` / frontend `npm run test:unit` の**実行結果**（件数・failures） |
| **L2** | **BRANCH 28/34 非退行** ＋ `parityTest` green | `parityTest` 実行結果 ＋ ゲート値の出典（`out3/report/gate-v2/jacoco.csv`） |
| **L3** | before の PoC が**すべて** after で失敗 | S1〜S21 の 21/21 解消（回帰表）＋ 未対応0件 |
| **L4** | **実測された差分がすべて台帳に載っている** | AC1 の対応表そのもの ＋ 未台帳差分の有無 |

### AC5: 「穴」の起票

- 「穴」と判定した ID を一覧化し、**次イテレーションの L2 シナリオ候補として GitHub Issue を起票**する（＝**L2 の次の一手は L4 の結果から導出する**）。
- 起票前に `mcp__github__list_issues`（state: open）で**重複が無いことを確認**する。
- **穴が0件だった場合は「0件である根拠」を明記**する（そのほうが疑わしいので、根拠を厚く書く）。

### AC6: 台帳の ID 順整列

- `spec/intended-diff-ledger.md` の並びが ID 順でない（**ID-31 が ID-28〜30 の前にある**）ので整列する。
- **行の内容は1文字も変更しない**（並べ替えのみ）。並べ替えだけであることを確認できる形にする（例: 並べ替え前後で行集合が一致することを確認した旨を記す）。

### AC-neg1: L2 のゲート値 **28/34 を引き上げない**

理論上限に到達済み。**据え置き＝非退行フロア**（シナリオを壊したら気づくための検知器）として扱う。「まだ 82.4% だから上げよう」としないこと。

### AC-neg2: 「穴」を**埋めない**

穴に対する L2 シナリオ追加・テスト実装は本 Story のスコープ**外**。**起票までがスコープ**。

### AC-neg3: 台帳への新規 ID 追加は「実測した未台帳差分」のみ

L4 で**実際に観測された**未台帳の差分があった場合に限り台帳へ追記する（`verification-strategy.md`「台帳に無い差分＝要調査」）。**憶測で ID を足さない。**

### AC-neg4: legacy は起動しない・無改変

本 Story は**既に採取済みのデータのみ**を使う（golden 17本・`out2`/`out3` の jacoco 実測）。legacy の再起動・再採取は不要（必要になったらそれ自体が発見なので報告する）。

### AC-neg5: `verification-report.md` は**新規作成**

既存の L2/L3 レポートを書き換えて代用しない。L2/L3 レポートは根拠として**参照**する（リンク）。

## 備考

- **ブランチ**: `docs/52-l4-ledger-verification`（`migration-agent-base`・新規／`main` から分岐）
- **リポジトリ**: `migration-agent-base` が主（`reports/after/` ＋ `spec/`）。`jpetstore-backend` / `jpetstore-frontend` は**読み取りとテスト実行のみ**（プロダクトコード・テストコードを変更しない）
- 対応表は **PO と一緒に作る**（台帳は PO 所有）
- 完了条件: `reports/after/verification-report.md` が存在し、**台帳31件すべてに判定と根拠がある**

---

# Issue #53 本文（全文転記）

## ユーザーストーリー

**As a** リポジトリを保守する開発者
**I want to** `tools/legacy-jacoco/` 配下に溜まった**採取事故の残骸**を掃除し、再発を `.gitignore` で防ぎたい
**So that** 一次データ（`out2/` / `out3/`）と**事故で出来たゴミ**が見分けられ、次に採取する人が迷わない

## 背景

Sprint 21/22 の JaCoCo 採取で、Git Bash（MSYS）のパス変換や `docker cp` の相対パス指定により、意図しないディレクトリが生成された。

| 対象 | 状態 | 原因 |
| --- | --- | --- |
| `tools/legacy-jacoco/out3;C` | 空ディレクトリ | 引数のパス変換事故（`out3` の後ろに `;C` が付いた） |
| `tools/legacy-jacoco/tools/legacy-jacoco/out/report` | 空ディレクトリの入れ子 | ホスト側の相対パス指定が二重に解決された |

いずれも**追跡はされていない**（`git status` はクリーン）が、ローカルに残り続けて紛らわしい。

## Acceptance Criteria

### AC1: 事故ディレクトリの削除

- `tools/legacy-jacoco/out3;C` を削除する
- `tools/legacy-jacoco/tools/`（入れ子の `tools/legacy-jacoco/out/report` を含む）を削除する
- 削除前に **中身が空である（＝一次データを含まない）ことを確認**してから消す

### AC2: `.gitignore` に再発防御を追加

- 入れ子生成物（`tools/legacy-jacoco/tools/`）を無視するパターンを追加する
- 既存の `/tools/legacy-jacoco/out*/` が `out3;C` のような事故ディレクトリも捕捉することを `git check-ignore -v` で確認し、コメントに残す
- 追加パターンには**何を防いでいるか**をコメントで書く（次に見た人が消してよいと分かるように）

### AC3: README への申し送り

`tools/legacy-jacoco/README.md` に、上記2つの事故の**再現条件と回避策**を1節として残す（`MSYS_NO_PATHCONV=1` の記述が既にあるので、その近傍に足す）。

### AC-neg1: **`out/` `out2/` `out3/` は削除しない**（2026-08-21 ユーザー判断）

- `out2/report/gate/` `out2/report/gate-v2/` `out3/report/ac1|gate|gate-v2/` は **`reports/after/l2-parity-coverage.md` が一次データとして名指しで参照している実測物**（例: BRANCH 28/34・INSTRUCTION 1360/1424 の出典）。
- gitignore 済みで**コミットされていない**ため、消すとゲート値の裏取り経路がローカルから失われる。
- `out/`（#50 spike 世代）も同レポート §7.2 の spike 値の生成元なので残す。
- **世代整理をするなら別 Story でユーザー判断を仰ぐ**。

### AC-neg2: `report.sh` / `Dockerfile` / `fetch-jars.sh` / `entrypoint-jacoco.sh` を変更しない

本 Story は**掃除と `.gitignore`・README のみ**。採取機構のロジックには触れない。

## 備考

- **ブランチ**: #52 と同一（`docs/52-l4-ledger-verification`）。`migration-agent-base` 単独・1SP の雑務のため独立ブランチは切らない
- **リポジトリ**: `migration-agent-base` のみ

---

# Planning での SM verification（一次データで検算）

SM long_term ④「**数値は一次データで検算する**」に従い、Planning 時点で現物を開いて確認した。
**下記はいずれも DEV/PO が実施時に再確認すること**（本ファイルの記述を転記して対応表を作らない＝#52 AC3）。

## SM-1【要訂正】`l2-parity-coverage.md` の「全18シナリオ」は **17 が正**（off-by-one）

一次データ3系統がすべて **17** で一致する。

| 一次データ | 実測 |
| --- | --- |
| `ParityScenarios.groovy` の `ALL` 要素数 | **17**（`new Scenario(` の出現数） |
| `jpetstore-backend/src/test/resources/parity/golden/*.json` | **17 ファイル** |
| 内訳の足し算 | #48+#49 の **9** ＋ #51 の **8**（W4・W5a・W5b・W5c・R7・R8a・R8b・cart-boundary）＝ **17** |

`reports/after/l2-parity-coverage.md` は Sprint 22 追記部の **6 箇所**（L289・291・308・342・356・361・504）で「18シナリオ」と書いている。
**ゲート値そのもの（BRANCH 28/34・INSTRUCTION 1360/1424）は実 exec に対する `report.sh` の機構出力なので影響しない**が、
`verification-report.md` が L2 を根拠として引用する以上、**引用元の数え誤りは持ち込まないこと**。

- **対応**: #52 の作業中に `l2-parity-coverage.md` の「18シナリオ」を「17シナリオ」へ訂正する（訂正した旨を1行残す）。
- なお §S9 の「計19件すべてpass」は**シナリオ数ではなく Spock のテストケース数**（`AccountParitySpec` 6 + `OrderHistoryParitySpec` 3 + `CartParitySpec` 1 + `OrderParitySpec` 3 + `CatalogParitySpec` 6）なので**19 のままで正しい**。17シナリオ ≠ 19テストケース を混同しないこと。

## SM-2 L2 の `INTENDED_DIVERGENCE` 宣言は **4件**（現物確認済み）

`ParityScenarios.groovy` の実物で確認。

| シナリオ ID | expectation | `divergentFields` |
| --- | --- | --- |
| `search-wildcard` | `INTENDED_DIVERGENCE(ID-29)` | `entries` |
| `order-detail-own` | `INTENDED_DIVERGENCE(ID-24)` | `lines[EST-1].productName` |
| `order-detail-missing` | `INTENDED_DIVERGENCE(ID-14)` | `httpStatus`, `stackTraceExposed` |
| `order-insufficient-stock` | `INTENDED_DIVERGENCE(ID-1)` | `outcome`, `inventoryDelta[EST-1]`, `ordersCreated`, `orderTotal`, `lines[EST-1].quantity`, `lines[EST-1].unitPrice` |

残り13シナリオは `EQUIVALENT`。**つまり L2 が観測点を持つ台帳 ID は ID-1・ID-14・ID-24・ID-29 の4件だけ**。

## SM-3 L3 の3レポートが言及している ID（grep 実測・和集合）

| レポート | 言及 ID |
| --- | --- |
| `l3-security-regression-backend.md` | ID-1, 2, 4, 5, 8, 9, 10, 11, 12, 13, 14, 22, 25, 26, 29 |
| `l3-security-regression-frontend.md` | ID-6, 15, 31 |
| `l3-security-regression-sprint20-delta.md` | ID-1, 11, 14, 22, 25 |
| **和集合** | **ID-1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 22, 25, 26, 29, 31（18件）** |

⚠️ **「レポート内に ID-N の文字列がある」＝「その ID の観測点がある」ではない**。
L3 backend は S1〜S21 の各行の「対応 SBD / ID」列に ID を書いているだけの行もある。
**対応表では「どの S 番号の、どの根拠（`live` / `code`）が、その ID の何を観測しているか」まで書くこと**（#52 AC1）。
frontend の ID-6・ID-31 は特に注意（ID-6 は「SPA 化そのもの」なので観測点というより前提、ID-31 は正規化ロジックの話）。

## SM-4 L2 にも L3 にも出てこない ID = **12件**

**ID-3・7・16・17・18・19・20・21・23・27・28・30**

このうち `jpetstore-backend/src/test/` 内に ID 番号が文字列として現れるのは ID-7・17・20・21・23・28 のみ（うち ID-7・21・23 は Flyway SQL のコメント）。
**残りは「ID 番号を書いていない L1 AC テストが実質の観測点になっている」可能性が高い**。

| ID | L1 観測点の当たり（**未確認・要実測**） |
| --- | --- |
| ID-3（`BigDecimal`） | 金額計算の Spec（`OrderApplicationServiceSpec` の合計再計算 等） |
| ID-16（入力検証強化） | `StrongPasswordValidatorSpec` / `RegistrationControllerSpec` |
| ID-18（在庫切れ追加不可・数量上限） | `CartControllerSpec` / `StockStatusCalculatorSpec` |
| ID-19（カートマージ＝加算＋在庫クランプ） | `CartApplicationServiceSpec` / frontend cart store |
| ID-27（i18n・#25 完了） | frontend `ja.ts` / 言語切替の spec |
| ID-30（下書きを Pinia メモリ保持） | frontend checkout store の spec |

> **grep だけで「穴」と断じないこと。** 逆に「たぶんあるだろう」で「観測点あり」にもしないこと。
> **実在する Spec の実在するテスト名を名指しできたときだけ「観測点あり」**（#52 AC1・AC3）。

## SM-5 `verification-strategy.md` §4 の台帳（ID-1〜7）は**雛形**で、実体は `intended-diff-ledger.md`（ID-1〜31）

`verification-strategy.md` §4 の表は ID-1〜7 しか載っていないが、これは策定時の雛形。
**正典は `spec/intended-diff-ledger.md`**（同§4 冒頭にも「PO 所有」と明記）。対応表の分母は **31**。

## SM-6 台帳の並び順（AC6 の対象）

`intended-diff-ledger.md` の現在の並び: ID-1 … ID-27 → **ID-31** → ID-28 → ID-29 → ID-30。
**ID-31 だけが ID-28〜30 の前**にある。整列は**並べ替えのみ**（本文は1文字も変えない・#52 AC6）。

## SM-7 掃除（#53）の一次確認

| 対象 | 実測 |
| --- | --- |
| `tools/legacy-jacoco/out3;C` | **空ディレクトリ**（`find` でファイル0件）。`git check-ignore -v` → `.gitignore:24:/tools/legacy-jacoco/out*/` で**既に無視対象** |
| `tools/legacy-jacoco/tools/legacy-jacoco/out/report` | **空ディレクトリの入れ子**（ファイル0件）。**無視対象ではない**（`.gitignore` にパターン無し）→ AC2 で追加 |
| `git status --short` | **クリーン**（＝どちらも追跡されていない。誤コミットは起きていない） |
| `out/` `out2/` `out3/` | それぞれ 509K / 2.8M / 1.5M。`jacoco.exec` と `report/{ac1,gate,gate-v2}` を含む**一次データ** → **削除しない**（#53 AC-neg1・2026-08-21 ユーザー判断） |

---

# リスク・チャレンジ

## リスク

| # | リスク | 対策 |
| --- | --- | --- |
| R1 | **「観測点あり」の水増し** — それらしいテストを見つけて全部「観測点あり」にすると、L4 が何も検証していないのと同じになる | #52 AC1 で**実在するテスト名の名指し**を必須にする。SM は verification で**名指しされたテストを実際に開いて、その ID の振る舞いを実際に見ているか**を確認する |
| R2 | **「穴」を穴と書けない圧力** — Phase 4 完走をゴールにすると、穴を「観測不要」へ寄せたくなる | ゴールは「完走」ではなく「**範囲の明示**」。穴0件なら**むしろ根拠を厚く**要求する（#52 AC5） |
| R3 | **数値の drift** — `l2-parity-coverage.md` の「18シナリオ」誤記（SM-1）を verification-report が引き継ぐ | SM-1 のとおり引用前に訂正。**引用元レポートの記述ではなく一次データ（`ParityScenarios.groovy` / golden / `jacoco.csv`）に当たる**（#52 AC3） |
| R4 | **L2 ゲートを上げたくなる** — 28/34=82.4% は「まだ伸ばせる」ように見える | **理論上限に到達済み**（残6は構造的到達不能・スコープ外）。#52 AC-neg1 で明示的に禁止。据え置き＝**非退行フロア**（シナリオを壊したら気づくための検知器） |
| R5 | **スコープクリープ** — 穴を見つけたらその場で埋めたくなる | #52 AC-neg2「起票までがスコープ」。埋めるのは次イテレーション |
| R6 | **一次データ（`out2`/`out3`）の消失** — 掃除でゲート値の裏取り経路を失う | #53 AC-neg1 で削除対象から除外（ユーザー判断済み） |

## チャレンジ

| # | 内容 |
| --- | --- |
| C1 | **L2 の次の一手を L4 から導出する**（Sprint 22 Retro C2 の実行）。従来「カバレッジが低いから足す」だった駆動を「**台帳 ID に観測点が無いから足す**」へ切り替える。#52 AC5 の起票がその実証になる |
| C2 | **PO と SM の共同作業**（台帳は PO 所有・ゲート判定は SM）。対応表は PO、ゲート判定と穴の起票は SM が主で分担する |
