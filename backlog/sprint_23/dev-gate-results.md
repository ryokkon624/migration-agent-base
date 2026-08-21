# Sprint 23 / #52 — DEV 実測: 合否ゲート（`verification-strategy.md` §5）の実行結果

- **担当**: DEV（実測担当）／**実行日**: 2026-08-21／**ブランチ**: `docs/52-l4-ledger-verification`
- **原則**: 「green のはず」は書かない。**実行できたものは出力の実数**を、**実行できなかったものは「できなかった」と理由**を書く。
- **legacy（`legacy-jpetstore`）は起動していない**（#52 AC-neg4）。`docker ps -a` 上も `jpetstore` コンテナは `Exited (255) 8 days ago` のまま。L2 は commit 済み golden JSON とだけ比較する設計（`build.gradle:117-125` の `parityTest` javadoc: "legacy NOT required"）。

## サマリ

| ゲート | 判定基準（§5） | 結果 | 一言 |
| --- | --- | --- | --- |
| **L1** | 全 AC テストが green | **PASS** | backend UT 362 + IT 225 / frontend 267 / （補足）database 97 ＝ **951 テスト・failures 0・errors 0・skipped 0** |
| **L2** | BRANCH 28/34 非退行 ＋ `parityTest` green | **PASS** | `parityTest` **23 テスト・0 failure**。ゲート値は `out3/report/gate-v2/jacoco.csv` を**自分で合算**して BRANCH **28/34**・INSTRUCTION **1360/1424** を検算・一致 |
| **L3** | before の PoC がすべて after で失敗（未対応 0件） | **PASS** | `l3-security-regression-backend.md` §1 の **S1〜S21 を1行ずつ数えて 21行**。判定は「消滅」9・「是正」12（S15 は消滅＋是正の両側）で、**「未対応（脆弱性が残っている）」は 0行** |
| **L4** | 実測差分がすべて台帳に載っている | **DEV 担当外** | SM が対応表から判定（DEV の入力は `dev-observation-points.md`） |

---

## L1 ゲート

### backend（`C:\work\java-migration\jpetstore-backend`）

**⚠️ 最初の実行（`./gradlew test integrationTest parityTest`）では `:test` と `:parityTest` が `UP-TO-DATE` でスキップされた**ため、
「実行結果」と言えるようにするため **`--rerun-tasks` を付けて全タスクを強制再実行**した。以下はその再実行の結果。

```
$ cd C:\work\java-migration\jpetstore-backend
$ ./gradlew test integrationTest parityTest --rerun-tasks --console=plain
BUILD SUCCESSFUL in 3m 57s
8 actionable tasks: 8 executed
```

`build/test-results/{test,integrationTest,parityTest}/*.xml` を集計した実数:

| タスク | 対象 | XMLファイル数 | tests | failures | errors | skipped |
| --- | --- | --- | --- | --- | --- | --- |
| `test`（UT・`integration` タグ除外） | plain Spock | 45 | **362** | **0** | **0** | **0** |
| `integrationTest`（`integration` タグ・`parity` 除外） | Testcontainers MySQL | 26 | **225** | **0** | **0** | **0** |
| `parityTest`（`parity` タグ） | L2（下記） | 7 | **23** | **0** | **0** | **0** |
| **合計** | | **78** | **610** | **0** | **0** | **0** |

> `integrationTest` の **225** は `l3-security-regression-sprint20-delta.md` §1 に記録されている 225 と一致した（同レポートは Sprint 20 時点の実行結果）。

### frontend（`C:\work\java-migration\jpetstore-frontend`）

**⚠️ 指示にあった `npm run test:unit` というスクリプトは `package.json` に存在しない**（定義されているのは `test`・`build`・`type-check`・`format`・`dev`・`preview`・`build-only`）。
実体は `"test": "vitest run"` なので **`npm run test` を実行**した。

```
$ cd C:\work\java-migration\jpetstore-frontend
$ npm run test

 Test Files  26 passed (26)
      Tests  267 passed (267)
   Duration  34.57s
```

| 項目 | 実数 |
| --- | --- |
| Test Files | **26 passed / 26** |
| Tests | **267 passed / 267** |
| failed | **0** |
| skipped | **0**（vitest は skip があれば `Tests 267 passed | N skipped` と出すが出力に無し） |

> `l3-security-regression-frontend.md` §1 付録は「セキュリティ関連 spec 4本を実行し **55/55 green**」と記録している。
> 今回は**全 26 ファイル 267 テスト**を実行し、その 4 ファイル（`ItemDetailView.spec.ts` 7・`auth.spec.ts` 18・`redirectValidator.spec.ts` 21・`httpClient.spec.ts` 9 ＝ **55**）も含めて green だった（内訳の一致も確認）。

### （補足）database（`C:\work\java-migration\jpetstore-database`）

**§5 の L1 ゲートに明記されていないが**、`dev-observation-points.md` で ID-3/7/8/21/22/23/28/31 の観測点として名指ししているため、
根拠が実際に green であることを示す目的で実行した（**指示された2リポジトリ外・読み取りのみ**）。

```
$ cd C:\work\java-migration\jpetstore-database
$ ./gradlew test --rerun-tasks --console=plain
BUILD SUCCESSFUL in 47s
3 actionable tasks: 3 executed
```

| tests | failures | errors | skipped |
| --- | --- | --- | --- |
| **97** | **0** | **0** | **0** |

### L1 判定

**PASS**。3リポジトリ合計 **951 テスト**（backend 587＋frontend 267＋database 97。backend の 587 は UT 362＋IT 225 で、L2 の 23 はここに含めず L2 で数える）が failures 0・errors 0・skipped 0。

---

## L2 ゲート

### (1) `parityTest` の実行

```
$ cd C:\work\java-migration\jpetstore-backend
$ ./gradlew test integrationTest parityTest --rerun-tasks --console=plain
> Task :parityTest
BUILD SUCCESSFUL in 3m 57s
```

`build/test-results/parityTest/*.xml` の内訳（実数）:

| Spec | tests | failures | errors | skipped |
| --- | --- | --- | --- | --- |
| `parity.AccountParitySpec` | 6 | 0 | 0 | 0 |
| `parity.CatalogParitySpec` | 6 | 0 | 0 | 0 |
| `parity.OrderParitySpec` | 3 | 0 | 0 | 0 |
| `parity.OrderHistoryParitySpec` | 3 | 0 | 0 | 0 |
| `parity.CartParitySpec` | 1 | 0 | 0 | 0 |
| `parity.verify.NewHttpClientSpec` | 3 | 0 | 0 | 0 |
| `parity.verify.ParityIntegrationTestBaseSmokeSpec` | 1 | 0 | 0 | 0 |
| **合計** | **23** | **0** | **0** | **0** |

> **`l2-parity-coverage.md` §S9 の「計19件すべてpass」を実測で再確認した**: golden 比較を担う5 Spec の合計＝6+6+3+3+1＝**19**。
> `parityTest` タスク全体の 23 は、これに検証ハーネス自身の spec（`NewHttpClientSpec` 3・`ParityIntegrationTestBaseSmokeSpec` 1）を足した数。
> **17シナリオ ≠ 19テストケース ≠ 23 タスク内テスト** の3者を混同しないこと（`ParityScenariosSpec` の3ケースは plain Spock なので `test` タスク側で走る）。

### (2) ゲート値の検算（レポートの記述を使わず CSV を自分で合算）

出典: `tools/legacy-jacoco/out3/report/gate-v2/jacoco.csv`（17行・クラス単位）。全行の `BRANCH_MISSED`/`BRANCH_COVERED`/`INSTRUCTION_MISSED`/`INSTRUCTION_COVERED` を合算した。

| 指標 | covered | missed | total | 率 | レポート記載 | 一致 |
| --- | --- | --- | --- | --- | --- | --- |
| **BRANCH** | **28** | **6** | **34** | **82.4%** | 28 / 34 = 82.4% | ✅ |
| **INSTRUCTION** | **1360** | **64** | **1424** | **95.5%** | 1360 / 1424 = 95.5% | ✅ |

> **二重の裏取り**: SM も `backlog/sprint_23/sm-verification.md` V1/V2 で同じ CSV を独立にパース・合算し **BRANCH 28/34・INSTRUCTION 1360/1424** を得ている。
> **DEV の合算（本節）と SM の合算は完全に一致した**（残6の内訳 `SqlMapItemDao` 3・`SqlMapSequenceDao` 1・`CartItem` 1・`Cart` 1 も一致）。
> DEV は `python csv.DictReader` で17行を全件合算、SM は独立に同じ CSV をパース。**レポートの記述を経由していない経路が2本とも同じ値に着地**した。

未踏 BRANCH 6 の内訳（CSV から `BRANCH_MISSED > 0` の行を抽出）:

| クラス | BRANCH_MISSED |
| --- | --- |
| `SqlMapItemDao` | 3 |
| `SqlMapSequenceDao` | 1 |
| `CartItem` | 1 |
| `Cart` | 1 |
| **計** | **6** |

→ `l2-parity-coverage.md` 370行目の記述（`SqlMapItemDao`3・`SqlMapSequenceDao`1・`Cart`1・`CartItem`1＝6、28+6=34）と**完全一致**。
**⚠️ 残6の性質は「すべて構造的に到達不能」ではない — DEV が legacy 実ソースを開いて4種類に分類した**（SM verification V3 の指摘を受けて独立確認）:

| 分岐 | 実ソース（DEV 確認） | 性質 |
| --- | --- | --- |
| `Cart.addItem` の `cartItem != null` 側 | `legacy-jpetstore/.../domain/Cart.java:35-38` | **構造的に到達不能**（呼び出し元が `containsItemId` で事前ガード。Sprint22 S5 で確定） |
| `CartItem.getTotalPrice` の `item != null` false 側 | `legacy-jpetstore/.../domain/CartItem.java:29` | **構造的に到達不能**（同上） |
| `SqlMapSequenceDao.getNextId` の `sequence == null` 側 | `legacy-jpetstore/.../dao/ibatis/SqlMapSequenceDao.java:19` | **seed 前提で到達不能**（SEQUENCE 行を壊さないと踏めず、legacy 無改変の原則で不能） |
| `SqlMapItemDao.getItem` の `item == null` 側 | `SqlMapItemDao.java:39` `if (item != null)` | **到達可能（現行シナリオ集合のスコープ外）** — 不存在 itemId で `viewItem.do` |
| `SqlMapItemDao.isItemInStock` の未踏2アウトカム | `SqlMapItemDao.java:30` `return (i != null && i.intValue() > 0);` | **到達可能（同スコープ外）** — `i == null`（不存在 itemId）／`i <= 0`（在庫0への `addItemToCart.do`） |

→ 正確な言い方は「**28/34 は現行シナリオ集合のスコープ内での上限**」であって「**理論上限**」ではない。
→ **ゲート値は引き上げない**（#52 AC-neg1）。28/34 は**据え置き＝非退行フロア**（シナリオを壊したら気づくための検知器）のまま。
→ この到達可能な3アウトカムは **ID-14（`viewItem` 経路）・ID-18（在庫0追加）の未観測経路とちょうど一致する**ので、次の一手は `dev-observation-points.md` の「次イテレーションの L2/L1 シナリオ候補」に整理した。

参考（同じ exec の別分母。こちらも自分で合算）:

| レポート | rows | BRANCH | INSTRUCTION | `l2-parity-coverage.md` 記載 | 一致 |
| --- | --- | --- | --- | --- | --- |
| `out3/report/gate/jacoco.csv` | 19 | 28 / 34 | 1366 / 1588 = 86.0% | 1366 / 1588 = 86.0% | ✅ |
| `out3/report/gate-v2/jacoco.csv` | 17 | 28 / 34 | 1360 / 1424 = 95.5% | 1360 / 1424 = 95.5% | ✅ |

### L2 判定

**PASS**（`parityTest` green ＋ BRANCH 28/34 非退行を一次データで検算・一致）。

---

## L3 ゲート

**実行ではなく回帰表の集計**（指示どおり）。対象は `reports/after/l3-security-regression-backend.md` §1（23〜50行目の表）。

### S1〜S21 を1行ずつ数えた結果

`grep -c '^| \*\*S[0-9]*\*\* |'` = **21行**。S1〜S21 が欠番・重複なく揃っていることも列挙して確認した
（`S1 S2 S3 S4 S5 S6 S7 S8 S9 S10 S11 S12 S13 S14 S15 S16 S17 S18 S19 S20 S21`）。

| S | 「after の状態」列の判定 |
| --- | --- |
| S1 | 消滅（設計変更） |
| S2 | 是正 |
| S3 | 消滅（設計変更） |
| S4 | 是正 |
| S5 | 是正 |
| S6 | 是正 |
| S7 | 是正 |
| S8 | 消滅（設計変更） |
| S9 | 消滅（設計変更） |
| S10 | 是正 |
| S11 | 是正 |
| S12 | 是正（ログイン）＋設計判断（登録） |
| S13 | 消滅（攻撃面除去） |
| S14 | 消滅（攻撃面除去） |
| S15 | 消滅＋是正 |
| S16 | 消滅（設計変更） |
| S17 | 消滅 |
| S18 | 是正 |
| S19 | 是正（コード） |
| S20 | 是正 |
| S21 | 是正 |

- **判定凡例（同レポート21行目）にある「未対応（脆弱性が残っている）」および「不明（判定不能）」に該当する行は 0件**。
- 内訳: 消滅/設計変更 **9**（S1・S3・S8・S9・S13・S14・S16・S17＋S15の消滅側）／是正 **12**（S2・S4・S5・S6・S7・S10・S11・S12・S15の是正側・S18・S19・S20・S21）＝ 同レポートの「集計」行と一致。
- **根拠種別の内訳（DEV が「根拠」列を1行ずつ機械的に数えた）**:

  | 根拠 | 行数 | S 番号 |
  | --- | --- | --- |
  | `live` を含む | **17** | S1・S3・S5・S6・S7・S8・S9・S10・S11・S12・S13・S14・S15・S16・S17・S18・S19 |
  | `code` を含む | **14** | S2・S3・S4・S6・S7・S8・S9・S10・S12・S17・S18・S19・S20・S21 |
  | 両方を含む | **10** | S3・S6・S7・S8・S9・S10・S12・S17・S18・S19 |
  | `code` のみ | **4** | S2・S4・S20・S21 |

  > **⚠️ 同レポートの全体結論（15行目）は「うち 10件をライブ実測で確証、残りはコード位置で確証」と書いているが、
  > §1 表の「根拠」列を機械的に数えると `live` 表記のある行は 17 行ある**（`code` のみは S2・S4・S20・S21 の 4 行だけ）。
  > 「10」は**両方を含む行の数（10）**と一致するので、集計時に `live`+`code` 併記行だけを「ライブ実測」と数えた可能性が高い。
  > **L3 ゲートの判定（未対応 0件）には影響しない**が、`verification-report.md` が「10件をライブ実測」という数字を引用する場合は
  > **この数え方の曖昧さを持ち込まないこと**（SM-1 と同種の drift 候補）。
- **他2レポートの位置づけ（L3 ゲートの分母には入らない）**: §5 の L3 ゲートは「**before の PoC がすべて after で失敗**」なので、分母は before findings ＝ backend レポートの S1〜S21。
  - `l3-security-regression-frontend.md:23` は「**未対応（残存脆弱性）: 0件**」（確定 findings は F1 = CSP 不在・Low の1件のみ）。
  - `l3-security-regression-sprint20-delta.md` は **before findings ではなく「after 側で新たに作り込まれた差分」の検証**。全体結論は「**Critical / High は 0件**・確定は **Low 4件**（S20-1〜S20-4）と Informational 群」で、同レポート自身が「**完全な clean とは書けない所見が4件（Low）残る**」と明記している。**「残存脆弱性 0」ではない**ので、`verification-report.md` で L3 を PASS と書く際は「before PoC 21/21 解消（＝ゲート基準）」と「after 側の Low 4件が残っている（＝ゲート基準外の残件）」を分けて書くこと。

### L3 判定

**PASS**（S1〜S21 の 21/21 が解消・未対応 0件）。

---

## L4 ゲート

**DEV 担当外**。SM が `dev-observation-points.md`（DEV）＋ PO の仕様側判定から対応表を組み、
「実測された差分がすべて台帳に載っているか」を判定する。

DEV から SM への入力として、実測で分かった L4 関連の事実を挙げる:

1. **台帳は作業中に 31件 → 33件に増えた**（L4 の結果として ID-32〔認証状態の保持方式＝ステートレス〕・ID-33〔カート一覧のページング廃止〕が追記された）。**33件中「観測点なし」は ID-30 と ID-33 の2件**（`jpetstore-database` の Spec を根拠として認める場合）。認めない場合は ID-7・ID-21・ID-23 が加わり **5件**。
2. **部分観測が6件ある**（ID-6・ID-14・ID-22・ID-23・ID-26・ID-32）。詳細は `dev-observation-points.md` の「部分観測」表。特に **ID-14 は L1 で3経路とも観測済みだが L2 は `order-detail` 経路の1本のみ**、**ID-22 は観測点はあるが S20-4 が「無言の後退」を Low で受容**、**ID-32 は `live`+`code` の観測はあるが自動回帰検知器が 0件**。
3. **L2 が見ている範囲では未台帳差分 0件**。`parityTest` 23/23 green ＝ 17シナリオすべてが golden と「宣言どおり」に一致しており、`ParityComparator` は**宣言外の差分があれば fail する**設計（`ParityScenariosSpec.groovy:36` `def "INTENDED_DIVERGENCE宣言のシナリオはgolden側のdivergentFieldsと台帳の宣言が一致する"` で宣言と golden の一致自体も固定）。ただしこれは **17シナリオが触れた範囲に限る**（BRANCH 28/34 の範囲＝しかも上記のとおり「スコープ内の上限」であって理論上限ではない）。
4. **レポート本文には「台帳に無い」と明記された差分が既にある**（L2 の外側）。`dev-observation-points.md` の「未台帳差分の候補」節に A-1〜A-4 として出所つきで列挙した。**台帳へは追記していない**（#52 AC-neg3）。実測で生きていると判断できたのは **A-1（`mysql-connector-j` が backend 9.5.0 / database 26.7.0 の2版で固定されている版乖離。両 `build.gradle` を DEV が現物確認）** のみ。A-3（注文の二重送信）は**ユーザー判断で台帳追記せず**と決まっており、**DEV の実測でも反証は出なかった**（同一カートの並行 POST を観測しているテストは 0件。`OrderConcurrencyIntegrationSpec.groovy:101` は2ユーザーの別カートを競合させる設計）。

---

## 実行できなかったもの

**なし。** 4ゲートのうち DEV 担当の3つ（L1・L2・L3）はすべて実行・集計できた。

補足として、以下は**意図的に実行していない**:

| 対象 | 理由 |
| --- | --- |
| `legacy-jpetstore` の起動・golden 再採取 | #52 AC-neg4。既採取の golden 17本・`out2`/`out3` の jacoco 実測のみを使う |
| JaCoCo の再計測（`report.sh` の再実行） | 同上。`out3/report/gate-v2/jacoco.csv` の**既存 CSV を読んで合算**することでゲート値を検算した |
| L3 PoC の再実行（ライブ攻撃） | 指示が「実行ではなく回帰表の集計」。稼働 backend/frontend への攻撃実行は SEC の担当かつユーザー承認が必要 |
