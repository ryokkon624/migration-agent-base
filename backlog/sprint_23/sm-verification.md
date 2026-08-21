# Sprint 23 — SM verification（一次データによる独立検算）

> DEV/PO の成果物と突き合わせるために、**SM が自分で一次データを開いて確認した記録**。
> `scrum-master-workflow` ④「数値は一次データで検算する／ただし検算の前に機構出力か手計算かを生成元で確認する」に従う。
> **本ファイルは根拠の記録であり、`verification-report.md` の代替ではない。**

---

## V1. L2 ゲート値の再現（機構出力を SM が自分で合算）

`tools/legacy-jacoco/out3/report/gate-v2/jacoco.csv`（`report.sh` の機構出力）を SM が直接パースして各列を合算した。

| 出力 | クラス数 | BRANCH | INSTRUCTION |
| --- | --- | --- | --- |
| `out3/report/gate-v2/jacoco.csv` | 17 | **28 / 34** | **1360 / 1424** |
| `out3/report/gate/jacoco.csv` | 19 | 28 / 34 | 1366 / 1588 |
| `out2/report/gate-v2/jacoco.csv` | 17 | 16 / 34 | 1138 / 1424 |

→ `reports/after/l2-parity-coverage.md` §S3・§S6 の値と**完全一致**。**ゲート値は健全**。

## V2. 残存未踏 BRANCH 6 の内訳（メソッド粒度まで下ろした）

`out3/report/gate-v2/jacoco.xml` をメソッド粒度でパースした結果：

| クラス | メソッド | 行 | missed | covered |
| --- | --- | --- | --- | --- |
| `SqlMapItemDao` | `isItemInStock(String)` | 29 | **2** | 2 |
| `SqlMapItemDao` | `getItem(String)` | 38 | **1** | 1 |
| `SqlMapSequenceDao` | `getNextId(String)` | 17 | **1** | 1 |
| `CartItem` | `getTotalPrice()` | 29 | **1** | 1 |
| `Cart` | `addItem(Item, boolean)` | 36 | **1** | 1 |
| 合計 | | | **6** | |

28 + 6 = 34。整合。

## V3【重要】「残り6分岐はすべて構造的に到達不能」は**言い過ぎ**（4種類ある）

`legacy-jpetstore` の実ソースを読んで6分岐の性質を分類した。**同一視してはいけない。**

| 分岐 | 性質 | 根拠 |
| --- | --- | --- |
| `Cart.addItem` の `cartItem != null` 側 | **構造的に到達不能** | 呼び出し元2箇所とも `containsItemId` で事前排他（Sprint 22 S5 で確定・実測でも裏取り済み） |
| `CartItem.getTotalPrice` の `item != null` false 側 | **構造的に到達不能** | 唯一の生成箇所 `Cart.java:38` の直後 L39 が必ず `setItem(非null)`（Sprint 22 S5） |
| `SqlMapSequenceDao.getNextId` の `sequence == null` 側 | **seed 前提で到達不能** | `SEQUENCE` テーブルに行が無い場合のみ。**legacy のデータを壊さないと踏めない**（＝レガシー無改変の原則により到達不能） |
| `SqlMapItemDao.getItem` の `item == null` 側 | **到達可能（スコープ外）** | 不存在 `itemId` で `viewItem.do` を叩けば踏める。**シナリオを1本足せば踏める** |
| `SqlMapItemDao.isItemInStock` の未踏2アウトカム | **到達可能（スコープ外）** | `i == null`（不存在 itemId）／`i.intValue() <= 0`（在庫0アイテムへの `addItemToCart.do`）。いずれもシナリオで到達しうる |

**したがって正確な言い方は「28/34 は現行シナリオ集合のスコープ内での上限」であって「理論上限」ではない。**
Sprint 22 の SM 短期記憶も残6を「`SqlMapItemDao` 3・`SqlMapSequenceDao` 1（**スコープ外**）／`Cart` 1・`CartItem` 1（**構造的に到達不能**）」と
**区別して**書いており、「6分岐すべて構造的に到達不能」という要約はこの区別を落としている。

> ⚠️ **これはゲート値を上げる根拠ではない**（#52 AC-neg1）。28/34 は**非退行フロア＝検知器**として据え置く。
> L4 の役割は「言えることと言えないことを正確に書く」ことなので、**言い過ぎを直す**という一点で扱う。

## V4【重要】V3 の「到達可能な3分岐」は **ID-14 の未観測経路とちょうど同じ穴**

台帳 ID-14 の「as-is」は **stale-session/不正 ID で 500＋スタックトレース露出（3経路）**。
その3経路の実体は `spec/behavior/catalog.md:37` に明記されている：

| 経路 | legacy の壊れ方 |
| --- | --- |
| `viewItem` | 不正 itemId → `getItem` が null → `item.getProduct()` で **NPE** |
| `viewCategory` | stale-session → **IllegalStateException** |
| `viewProduct` | stale-session → **NPE** |

一方、**L2 が ID-14 に対して持っている観測点は `order-detail-missing`（R8b）＝ `ViewOrderAction` 経路の1本だけ**で、
**上記3経路はいずれも L2 で観測されていない**。

そして `viewItem`（不正 itemId）経路は、**V3 で「到達可能（スコープ外）」と判定した `SqlMapItemDao.getItem` の `item == null` 側そのもの**。

→ **L2 のカバレッジの穴と、L4 の観測点の穴が同一**。
→ **`item-detail-missing`（不存在 itemId で `viewItem.do`）を1本足すと、(a) ID-14 の2本目の観測点になり、(b) legacy の未踏分岐を1つ踏む。**
→ これが「**L2 の次の一手を L4 の結果から導出する**」（#52 AC5・Sprint 22 Retro C2）の具体例になる。

**ただし ID-14 は L1 では3経路とも観測済み**（`CatalogControllerSpec`）:

| テスト名（実在・現物確認済み） | 行 |
| --- | --- |
| `def "論点5: 存在しないcategoryIdは404に正規化される(trace非露出)"()` | `CatalogControllerSpec.groovy:135` |
| `def "論点5: 存在しないproductIdは404に正規化される"()` | `:148` |
| `def "論点5: 存在しないitemIdは404に正規化される"()` | `:154` |
| `def "#3 AC-neg1: stale頁送り相当(範囲外の有効なpage番号)はクランプされ空200を返す(500でない)"()` | `:202` |

→ ID-14 の判定は「**観測点あり**」だが、**手段が L1（新側の AC 準拠）に偏っており、旧新比較（L2）としては1経路のみ**。
この粒度まで書かないと「観測点あり」が水増しになる（#52 リスク R1）。

## V5. L3 回帰表（S1〜S21）が ID を張っているのは **11件**

`reports/after/l3-security-regression-backend.md` §1 の表を1行ずつ拾った（S行は **21行**・数え済み）。

S1→ID-5 / S2→ID-2,4 / S3→ID-4 / S4→ID-4 / S5→ID-9 / S6→ID-13 / S7→ID-2 / S8→ID-10 / S9→ID-12 /
S10→ID-11 / S11→ID-11 / S12→ID-11 / S13→ID-5 / S14→ID-5 / S15→ID-4,5 / S16→ID-5 / S17→ID-25 /
S18→ID-14 / S19→ID-25 / S20→ID-26 / S21→ID-26

**＝ {2, 4, 5, 9, 10, 11, 12, 13, 14, 25, 26} の11件のみ。**

ID-1・ID-8・ID-22・ID-29 は §1 の回帰表では**なく** §2/§3 に出てくる（＝**単純 grep の和集合18件は過大**）:

| ID | 出所 | 性質 |
| --- | --- | --- |
| ID-1 | §2.3 L126（在庫減算の並行安全・ガード付き単文アトミック減算・affected-rows==0 判定） | `code` 根拠の「clean と確認した領域」 |
| ID-29 | §2.3 L124（LIKE ESCAPE 実測有効） | **`live` 実測**。L2 `search-wildcard` と2系統 |
| ID-22 | §2.1 **N3**（L100）＝「ID-22 に**反する**」Medium CONFIRMED | 是正済み（下記 V6） |
| ID-8 | §3-5 残件（L141）＝ **PO 判断待ち**（台帳追記 or 受容明記） | **観測点ではない・未解決事項** |

> **教訓（対応表を作る側へ）**: 「レポートに `ID-N` の文字列がある」＝「観測点がある」ではない。
> **どの S 番号の、どの根拠種別（`live`/`code`）が、その ID の何を観測しているか**まで書かせる。

## V6. ID-22 は「観測点はあるが完全には守られていない」型

- **観測点は実在する**: `jpetstore-backend/src/test/groovy/.../presentation/rest/OrderFailureAuditL3RegressionSpec.groovy:96`
  `def "L3 N3 AC-neg3: 在庫不足以外の想定外の失敗でもORDER_CREATE/FAILURE監査行が1件残る(修正前は監査ゼロのまま伝播していた)"()`
- **ただし残余がある**: `l3-security-regression-sprint20-delta.md` の **S20-4** が
  「#39 AC2 の best-effort catch が共通経路に置かれたため成功系にも波及し fail-closed → fail-open に反転。**ID-22『成功・失敗いずれも記録』の無言の後退**」を **Low で受容**している。
- → 対応表の ID-22 行には**観測点と残余の両方**を書く。

## V7. 未台帳差分の候補（L4 ゲートに直撃）

`reports/after/l3-security-regression-backend.md` に、**台帳に無いと明記された差分**が既に存在する。

| # | 内容 | 出所 |
| --- | --- | --- |
| U1 | **注文の二重送信**: 冪等キー無しで同一カートの並行 POST が注文2件を生む（売り越しは起きない）。「**台帳に記載が無いため**、受容 or 冪等キー導入の判断」 | §3-6 |
| U2 | **mysql-connector 版乖離**: backend `9.5.0` vs database `26.7.0`。「**台帳に記録の無い据え置き差分**（ID-26 の版固定方針との整合を記録推奨）」 | §3-7 |
| U3 | **在庫枯渇（denial-of-inventory）**: ID-8 で決済ゲートを撤去した帰結。「**ID-8 の帰結として受容される可能性があり PO 判断を仰ぐ（台帳追記 or 受容明記）**」 | §3-5 |
| U4 | **同梱 creds**: `jpetstore/jpetstore` 平文が `EnumGenerator.java`・`generatorConfig.xml` にあり boot jar に同梱 →「台帳 §補足『ソース内に実効的秘密なし』への**部分未達**」 | §2.1 N9 |
| ~~U5~~ | ~~**台帳 ID-26 の根拠記述の誤り疑い**~~ → **SM の誤り。取り下げる**（下記 V11） | §2.2 |

**U1・U2 は L4 ゲート「実測された差分がすべて台帳に載っている」に直撃する。**

## V8. `l2-parity-coverage.md` の「18シナリオ」は **17 が正**（off-by-one）

一次データ3系統がすべて 17：

| 一次データ | 実測 |
| --- | --- |
| `ParityScenarios.groovy` の `ALL` 要素数 | **17** |
| `src/test/resources/parity/golden/*.json` | **17 ファイル** |
| 内訳の足し算 | #48+#49 の 9 ＋ #51 の 8 ＝ **17** |

「18シナリオ」は Sprint 22 追記部の L289・291・308・342・356・361・504 に出現。
**ゲート値そのものは実 exec に対する `report.sh` の機構出力なので影響なし**（V1 で再現済み）。
§S9 の「計19件」は**テストケース数**なので正しい（17シナリオ ≠ 19テストケース）。

## V9. 掃除（#53）の一次確認

| 対象 | 実測 |
| --- | --- |
| `tools/legacy-jacoco/out3;C` | 空ディレクトリ。`git check-ignore -v` → `.gitignore:24:/tools/legacy-jacoco/out*/` で**既に無視対象** |
| `tools/legacy-jacoco/tools/legacy-jacoco/out/report` | 空ディレクトリの入れ子。**無視対象ではない**（要 `.gitignore` 追加） |
| `git status --short` | クリーン（＝どちらも追跡されていない） |
| `out/` `out2/` `out3/` | 509K / 2.8M / 1.5M。`jacoco.exec` と `report/{ac1,gate,gate-v2}` を含む**一次データ** → 温存（ユーザー判断 2026-08-21） |

## V10. 台帳の並び（AC6 の対象）

現在の並び: ID-1 … ID-27 → **ID-31** → ID-28 → ID-29 → ID-30。**ID-31 だけが位置ずれ**。


---

## V11【SM の誤りを訂正】U5「台帳 ID-26 の根拠が誤り」は**成立しない**（PO が反証・SM が検算して確認）

SM は当初「台帳 ID-26 が挙げる CVE-2023-22102 は L3 §2.2 が『9.5.0 は非該当』としており食い違う」と書いたが、
**対象アーティファクトが違うだけ**で食い違いではなかった。PO の反証を受けて SM が一次データで検算した：

| 主体 | 座標 | 出典 |
| --- | --- | --- |
| 台帳 ID-26 が言っているもの | **`jpetstore-database`** の `mysql-connector-j` **8.0.33 → 26.7.0** | `jpetstore-database/build.gradle:30,38` = `26.7.0` |
| L3 §2.2 が「非該当」と言っているもの | **`jpetstore-backend`** の runtime jar **9.5.0** | `jpetstore-backend/build.gradle:65,68` = `9.5.0` |

§2.2 自身が「CVE-2023-22102 は **8.2.0 で修正済**」と書いているので、**8.0.33 はそれより前＝該当**。
台帳 ID-26 の更新根拠は成立している。**U5 は取り下げる。**

→ 実在する未記録は **§3-7 の版乖離**（同一ライブラリが `9.5.0` と `26.7.0` の **2版で固定**されているのに、
「版固定」を宣言した ID-26 にその事実も据え置き判断も無い）＝ **U2 のほう**。U2 は生きている。

> **教訓**: SM 自身も「レポートの記述どうしを突き合わせる」段階で誤った。**座標（どのリポジトリの、どの依存か）まで
> 一次データで確認してから食い違いと呼ぶこと。** ④「数値は一次データで検算する」は SM 自身の指摘にも適用される。

## V12. PO の「在庫枯渇は旧新差分ではない」を検算した — **PO が正しい**

`legacy-jpetstore/src/main/java/.../domain/logic/OrderValidator.java:25-27`:
```java
ValidationUtils.rejectIfEmpty(errors, "creditCard", "CCN_REQUIRED", "FAKE (!) credit card number required.");
ValidationUtils.rejectIfEmpty(errors, "expiryDate", "EXPIRY_DATE_REQUIRED", "Expiry date is required.");
ValidationUtils.rejectIfEmpty(errors, "cardType", "CARD_TYPE_REQUIRED", "Card type is required.");
```
**`rejectIfEmpty` ＝非空チェックのみ**。エラーメッセージが文字どおり `FAKE (!)`。**旧にも実質の決済ゲートは無い**。

さらに補強: Sprint 22 S1/S2 のとおり **`OrderValidator` は稼働 legacy（Struts 経路）では構造的に到達不能**
（`web.xml` L140-142 で Spring MVC の servlet-mapping がコメントアウト・`*.do` は Struts へ）。
つまり**稼働している旧では、この1文字チェックすら走らない**。PO の結論（差分ではない）は
実行経路まで含めても成立する（むしろ強まる）。
