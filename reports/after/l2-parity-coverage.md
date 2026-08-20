# Phase 4 L2 — legacyカバレッジ実測（jpetstore-legacy / #50）

> **目的**: L2パリティ（`jpetstore-backend`の`parity`シナリオ）が legacy の「保存すべき業務ロジック」を
> どれだけ踏めているかを、定義済みの分母に対する実測値で示す。「テストの本数は十分か」に印象論ではなく
> 数値で答える（設計: [`spec/l2-parity-design.md`](../../spec/l2-parity-design.md) §4・決定P3）。
> **担当**: DEV（Sprint 21・#50）／**日付**: 2026-08-20／**計測対象**: `#48`(W1) + `#49`(R1〜R6・W2・W3) の
> 全9シナリオ実行後の legacy カバレッジ。
> **手順**: [`tools/legacy-jacoco/README.md`](../../tools/legacy-jacoco/README.md)（overlayイメージ
> `jpetstore-legacy-jacoco`・`jpetstore-legacy`イメージ自体は無改変）。

---

## 全体結論（サマリ）

**PO とのゲート値合意が完了しました（AC5）。** 合意内容は §5 参照。

| 指標 | spike時点（読み取り系一部＋W1のみ・§7.2） | **本実測（#48+#49・全9シナリオ・AC1分母）** | 増分 |
| --- | --- | --- | --- |
| **BRANCH** | 16/42 = 38.1% | **16/42 = 38.1%** | ±0（詳細は§2） |
| LINE | 297/452 = 65.7% | **304/452 = 67.3%** | +7 lines |
| INSTRUCTION | 1119/1765 = 63.4% | **1144/1765 = 64.8%** | +25 instructions |
| CLASS | 19/22 = 86.4% | **19/22 = 86.4%** | ±0 |

分母の定義（29クラス・うちJaCoCoが解析対象とするのは22クラス。`web.struts`/`web.spring`はID-6、
`service`/`service.client`はID-5によりそれぞれ除外）は下記§1のとおり（Issue #50 AC1で確定済み・変更なし）。

> **【差し替え】到達不能分岐を除いた「ゲート分母」での再計算**（実コード裏取りで確定・§3参照。
> ※初出時「36分岐」と報告したが、`MsSqlOrderDao`のBRANCH 2を除外計算に反映し忘れていた誤りがあり
> **34分岐が正**。訂正の経緯は§5参照）:
> BRANCH分母42のうち**8分岐（`SendOrderConfirmationEmailAdvice`6＋`MsSqlOrderDao`2）は
> Spring設定でコメントアウトされ一度もインスタンス化されない=構造的に到達不能**と判明した
> （`OracleSequenceDao`はBRANCH総数0のためbranch分母には影響しない）。
> **ゲート分母は34分岐、実測は16/34 = 47.1%**（AC1の分母定義29クラス自体は変更しない。
> AC5が求める「到達不能な分岐の除外理由」を明記したうえでの、PO合意済みのゲート判定用の値）。

---

## §1 分母（変更なし・Issue #50 AC1のとおり）

| パッケージ | クラス数 | 分母 | 理由 |
| --- | --- | --- | --- |
| `domain` | 8 | 含む | 業務ロジックの中核 |
| `domain.logic` | 6 | 含む | 同上 |
| `dao` | 5 | 含む | 永続化（クエリの意味を保存）。インタフェースのみのため分岐なし |
| `dao.ibatis` | 10 | 含む | 同上（内部クラス1を含む） |
| `web.struts` | 24 | 除外 | SPA+REST へ置換（ID-6） |
| `web.spring` | 18 | 除外 | 同上（ID-6） |
| `service` / `service.client` | 2 | 除外 | remoting 廃止（ID-5） |

`--classfiles`には`domain`/`dao`配下（`dao`含む29クラス中、JaCoCoが解析対象とするのは22クラス。
`dao`パッケージの5クラスは全てインタフェースのため解析対象外）だけを渡す
（`tools/legacy-jacoco/report.sh`が`docker cp`で自動抽出）。

---

## §2 パッケージ別の実測（BRANCH/LINE 中心）

| パッケージ | BRANCH（AC1分母） | BRANCH（**ゲート分母**） | LINE（ゲート分母） | INSTRUCTION（ゲート分母） | 所見 |
| --- | --- | --- | --- | --- | --- |
| `domain` | 6/14 = 42.9%（spike同値） | 同左（到達不能分岐なし） | 211/253 = 83.4% | 746/909 = 82.1% | `Order`はbranch 100%（2/2）。`Account`はbranch 0%（0/4） |
| `dao.ibatis` | 10/22 = 45.5%（spike同値） | **10/20 = 50.0%**（`MsSqlOrderDao`のBRANCH 2を除外） | 67/85 = 78.8% | 310/409 = 75.8% | Category/Product/Sequence系DAOは軒並み100%。`SqlMapAccountDao`は0%（§3） |
| **`domain.logic`** | 0/6 = 0.0%（spike同値） | **6分岐全て到達不能（§3）＝ゲート分母0（n/a）** | 26/69 = 37.7% | 88/270 = 32.6% | **branch 0%は死んだコード(未配線advice)を分母に数えていた見かけ上のギャップ。§3参照** |
| `dao` | n/a | n/a | n/a | n/a | インタフェースのみ（分岐なし・解析対象外） |
| **合計（AC1分母）** | **16/42 = 38.1%** | — | 304/452 = 67.3% | 1144/1765 = 64.8% | — |
| **合計（ゲート分母）** | — | **16/34 = 47.1%** | **304/407 = 74.7%** | **1144/1588 = 72.0%** | 到達不能8分岐（advice 6・`MsSqlOrderDao` 2）＋到達不能177 instruction（advice 111・`MsSqlOrderDao` 46・`OracleSequenceDao` 20） |

（ゲート分母の数値は`tools/legacy-jacoco/report.sh`が機構的に生成した`gate/jacoco.csv`の実測値。§6参照）

**CLASS（参考・ゲートにしない）**: AC1分母19/22=86.4% → ゲート分母**19/19=100%**（除外3クラス＝未カバー3クラスが
完全一致。**除外の妥当性そのものの傍証**として残す。PO合意§5参照）。

\* `domain.logic`のLINE分母がspike計測時（§7.2記載）と本実測でわずかに異なって見えるのは、
spikeが読み取り系の一部（カテゴリ5・商品3・アイテム3）のみを対象にした暫定計測であるのに対し、
本実測は#48+#49で確立した正式な9シナリオ全件を対象にしているため（母数となるクラス構成自体は不変）。

---

## §3 `domain.logic`のBRANCH 0%の原因（実コードで確定・当初の推測を訂正）

spike時点から**全9シナリオ（読み取り系6本＋状態変更系3本）に拡張してもなお`domain.logic`のbranch
coverageは16/42のまま変化しなかった**。当初は「メールサーバ接続不能等でadvice冒頭からリターンして
いる可能性」と推測したが、**`legacy-jpetstore`の実コードを確認した結果、原因は別（かつ確定的）**
であることが判明したため、以下のとおり訂正する。

### 確定した原因（`applicationContext.xml`の実物）

`SendOrderConfirmationEmailAdvice`は、**bean定義とadvisor設定の両方がコメントアウトされており、
一度もインスタンス化されない**（`src/main/webapp/WEB-INF/applicationContext.xml`）:

```xml
<aop:config>
    <!--
    <aop:advisor pointcut="execution(* *..PetStoreFacade.insertOrder(*..Order))" advice-ref="emailAdvice"/>
    -->
</aop:config>

<!-- AOP advice used to send confirmation email after order has been submitted -->
<!--
<bean id="emailAdvice" class="org.springframework.samples.jpetstore.domain.logic.SendOrderConfirmationEmailAdvice">
    <property name="mailSender" ref="mailSender"/>
</bean>-->
```

**傍証**: このクラスは`InitializingBean`を実装し`afterPropertiesSet()`に`if (this.mailSender == null)`
という分岐を持つ。bean が配線されていれば eager singleton として**アプリ起動時に必ず1回は実行され最低
1分岐は踏まれるはず**だが、実測は0/6（instruction・branchとも0%）。これは「一度も生成されていない」
という推論と完全に整合する。CLASS 19/22の未カバー3クラス（`SendOrderConfirmationEmailAdvice`・
`MsSqlOrderDao`・`OracleSequenceDao`）も、いずれも「Spring設定上インスタンス化されない」という同一の
理由で辻褄が合う。

branch数の内訳（6の由来）: `afterPropertiesSet()`の`mailSender == null`判定（1分岐＝2アウトカム）＋
`afterReturning()`の`account.getEmail() == null || account.getEmail().length() == 0`という複合条件
（OR演算子の左右2条件＝2分岐×2アウトカム=4アウトカム）＝計6アウトカム。ソース
（`SendOrderConfirmationEmailAdvice.java`）のこの構造と実測の「6 of 6」が一致する。

**結論**: `domain.logic`のbranch 0%は「シナリオ本数が足りない」ためではなく、**未配線（=構造的に
到達不能）な単一クラスの6分岐を分母に数えていたことによる見かけ上のギャップ**だった。W2/W3を追加しても
動かなかったのは、そもそも到達可能な分岐が存在しなかったため（シナリオを何本足しても解消しない）。

| クラス | branch coverage | 所見 |
| --- | --- | --- |
| `SendOrderConfirmationEmailAdvice` | **0%（0/6）＝構造的に到達不能（上記）** | AC5の除外対象。追加シナリオでは解消しない |
| `OrderValidator` | branch: n/a（総分岐数0）・instruction 2% | validate()メソッド自体がほぼ未実行。REST経由の駆動ではStruts ActionForm検証の入口を通らないため構造的に踏めない可能性（advice同様、配線状況の追加調査候補） |
| `AccountValidator` | branch: n/a・instruction 5% | アカウント系シナリオ未実装（W4/W5・下記§4）のため未踏 |
| `PetStoreImpl` | branch: n/a（分岐なし）・instruction 77% | ファサードクラス。9シナリオでよく踏めている |

`dao.ibatis`の`MsSqlOrderDao`（instruction 0%・**branch 0/2**）・`OracleSequenceDao`（instruction 0%・
branch総数0）も、HSQLDBデプロイでは**Spring設定上インスタンス化されない別DB向け実装**であり、シナリオ追加
では**到達不能**（AC5「到達不能な分岐の除外理由」に該当）。分母定義（Issue #50 AC1）は変更しない。

> **【訂正】`MsSqlOrderDao`のBRANCH 2を当初の集計から見落としていた。** 初出時は「到達不能な分岐は
> `SendOrderConfirmationEmailAdvice`の6のみ・到達可能分母36」と報告したが、`MsSqlOrderDao`が
> **BRANCH 0/2を持つ**ことが§2の集計に反映されていなかった（instruction 46のみ記載しbranchを落としていた）。
> PO が`jacoco.csv`を直接パースして発見・SMが検算で確認した（未踏18分岐の内訳
> ＝`SqlMapAccountDao` 4・`Account` 4・`SqlMapItemDao` 3・`Cart` 3・`SqlMapOrderDao` 2・
> `SqlMapSequenceDao` 1・`CartItem` 1 → 16+18=34で整合）。**正しい到達不能分岐は8（advice 6＋
> `MsSqlOrderDao` 2）、ゲート分母は34**（§5・§6の機構的チェックで今後同種のdriftを防ぐ）。

到達不能な3クラスの根拠（設定ファイルの実物・行番号つき）:

| クラス | 根拠ファイル:行 | 内容 |
| --- | --- | --- |
| `SendOrderConfirmationEmailAdvice` | `applicationContext.xml` L74-89 | `aop:advisor`（L80-82）・bean定義（L86-89）とも丸ごとコメントアウト |
| `MsSqlOrderDao` | `dataAccessContext-local.xml` L68-73 | `orderDao` bean定義（MS SQL Server向け代替実装）がコメントアウト |
| `OracleSequenceDao` | `dataAccessContext-local.xml` L83-87 | `sequenceDao` bean定義（Oracle向け代替実装）がコメントアウト |

**除外根拠はactiveな設定に基づく**: `web.xml` L36の`contextConfigLocation`が実際に読み込むのは
`dataAccessContext-local.xml`（L38の`-jta`版は丸ごとコメントアウトされ未使用）。念のため`-jta`版
（`dataAccessContext-jta.xml`）も確認したが、`MsSqlOrderDao`（L79-84）・`OracleSequenceDao`（L96-100）
とも同様にコメントアウトされており、**いずれの設定を採用しても結論は不変**。

---

## §4 次に足すべきシナリオ（AC6・未踏分岐からの名指し）

`SendOrderConfirmationEmailAdvice`は§3のとおり**構造的に到達不能（未配線）と確定した＝調査対象ではなく
除外対象**のため、候補から外し、W4/W5（アカウント系）・注文履歴照会の優先度を繰り上げる。

| # | 候補 | 対象 | 根拠 |
| --- | --- | --- | --- |
| 1 | **W4: アカウント新規登録**（`newAccountForm.do`→`newAccount.do`） | `Account`（branch 0/4）・`AccountValidator`（instruction 5%）・`SqlMapAccountDao`（instruction 34%・branch 0/4） | 最も明確な未踏クラス群。design.md §6-2で「次イテレーション」と位置付け済み。ゲート分母（34分岐）に対する寄与も最大 |
| 2 | **W5: アカウント編集**（`editAccountForm.do`→`editAccount.do`） | 同上（更新系分岐の追加） | 同上 |
| 3 | **注文履歴照会**（`listOrders.do`/`viewOrder.do`） | `SqlMapOrderDao`（branch 50%・2/4未踏） | `dao.ibatis`の残存ギャップ最大手 |
| 4 | **カート境界値**（空カートでの`removeItemFromCart.do`等） | `Cart`/`CartItem`（branch 50%） | W1〜W3で未踏の分岐が残る |
| 5（調査候補・優先度低） | **`OrderValidator`の配線状況確認** | `domain.logic`・instruction 2% | `SendOrderConfirmationEmailAdvice`と同様、Spring設定で無効化されていないか確認する価値はあるが、`branch: n/a`（総分岐数0）のためbranch coverageへの寄与は無い。W4/W5着手後に余力があれば調査 |

---

## §5 PO合意ゲート値（AC5・確定）

PO とのゲート値合意が完了した。合意時に提示した「到達可能分母36」は誤りで、`MsSqlOrderDao`のBRANCH 2を
除外集計に反映し忘れていたため**正しくは34**（§3の訂正参照。PO が`jacoco.csv`を直接パースして発見）。
以下は訂正後の値で確定した合意内容。

### 1. 指標: BRANCH（主）＋ INSTRUCTION（副）の二本立て

- **LINE はゲートにしない**（INSTRUCTIONと冗長・報告のみ）。
- **CLASS もゲートにしない**（除外後19/19=100%で弁別力ゼロ。ただし**除外集合と未カバークラス集合が
  完全一致する＝除外の妥当性の傍証**として有用なのでレポートには残す＝§2）。
- **INSTRUCTION併用の理由**: 除外後の`domain.logic`に残る3クラス（`PetStoreImpl`・`OrderValidator`・
  `AccountValidator`）は**総分岐数0**で、BRANCH単独では踏めているか否かを原理的に観測できない
  （`OrderValidator`はinstruction 3/111=2.7%という明確な実ギャップがある＝§3参照）。

### 2. 分母: AC1（計測の分母）とゲート分母の二層構成

- **AC1（29クラス/解析22）は変更せず「計測の分母」として維持**する（§1）。
- その上に**ゲート分母＝AC1 − 到達不能3クラス**を新たに定義する（AC1の変更ではなく1層足す扱い）。
- **両方の数値を必ず併記する**（§2）。片方だけにすると、含めれば理論上限34/42=81.0%の天井に対する
  判定になり（AC1分母では到達不能8分岐が最初からBRANCH分母に混ざり満点を阻むため）、消せば
  silentな打ち切りになる。

### 3. ゲート値: 実測値そのものを非退行フロアに置く

| 指標 | ゲート値 | 根拠 |
| --- | --- | --- |
| **BRANCH** | **≥ 16/34（47.0%）** | 実測そのもの |
| **INSTRUCTION** | **≥ 1144/1588（72.0%）** | 実測そのもの |

- **絶対数を正とし%は可読形**（丸めの議論を封じ、分母が動いたら即座に気づけるように）。
  **分母の変更自体が再合意のトリガ**。
- 根拠: 実測より上は#50にスコープクリープを強いる帳尻合わせ、下は無意味なゲート。
- **現在値ちょうど＝「十分」ではなく「ここから下げない」という非退行フロア**（次イテレーションで
  上げる方向のみを想定）。

### 4. 運用: シナリオ集合が変わったときに評価

- 評価契機は**コミット単位ではなく「シナリオ集合が変わったとき」**（＝`captureGolden`再実行時）。
  legacyは凍結アーティファクトのためシナリオが変わらない限り数値は動かない。
- 判定は当該Storyの**DoD**に載せ、SMがSprint Reviewで確認する。**フロア割れはDoneにしない**。
- GitHub Actions導入時は`parityTest`のCIゲート化を進めてよいが、**カバレッジ計測はDocker legacy起動が
  要るためper-PRジョブにしない**（シナリオ変更契機のジョブに留める）。
- **フロアの引き上げはPO/SM確認のうえ手動**（**自動ラチェットはしない**＝計測ブレでの誤ラチェット防止）。

### 5. 除外を機構で担保する（`report.sh`の2本出し＋除外反証fail）

**手計算の派生値はdriftする**（今回の「36 vs 34」の取り違えがまさにその実例）。`tools/legacy-jacoco/report.sh`
を、1つのexecから **(a) AC1分母のレポート**と**(b) ゲート分母のレポート**の**2本を出力**し、
**除外3クラスのカバレッジが1つでも0を超えたらfailする**よう変更した（実装・実行確認は§6）。

### 次イテレーション候補（暫定目標・#50の合否には影響しない）

§4で名指しした10分岐（`Account` 4・`SqlMapAccountDao` 4・`SqlMapOrderDao` 2）のうち**8以上**を踏む＝
**BRANCH ≥ 24/34（70%）・INSTRUCTION ≥ 80%**が次イテレーションの暫定目標（PO合意）。%を先に決めたのでは
なく未踏分岐リストから逆算した値（design.md §4.4のループそのもの）。**暫定であり完了時に実測で再合意する**。

---

## §6 `report.sh`の2本出し＋除外反証チェック（実装・実行確認）

PO合意§5-5への対応として、`tools/legacy-jacoco/report.sh`を変更した。

- `--classfiles`に渡す分母ツリーを2種類用意する:
  - **AC1ツリー**: 従来どおり`domain`/`dao`配下をまるごと抽出（29クラス中解析対象22クラス）
  - **ゲートツリー**: AC1ツリーから到達不能3クラスの`.class`を削除したもの
    （`domain/logic/SendOrderConfirmationEmailAdvice.class`・`dao/ibatis/MsSqlOrderDao.class`・
    `dao/ibatis/OracleSequenceDao.class`）
- `jacococli report`を2回実行し、`<out_dir>/ac1/`・`<out_dir>/gate/`へそれぞれ
  `index.html`/`jacoco.xml`/`jacoco.csv`を出力する。
- **除外反証チェック**: AC1レポートの`jacoco.csv`（`GROUP,PACKAGE,CLASS,INSTRUCTION_MISSED,
  INSTRUCTION_COVERED,BRANCH_MISSED,BRANCH_COVERED,...`）から到達不能3クラスの行を取り出し、
  `INSTRUCTION_COVERED`または`BRANCH_COVERED`が1でも0を超えていたら**即座にfailする**
  （「未配線だから到達不能」という前提が崩れたことを検知する）。ゲートレポートの生成は
  この検査をパスした後にのみ行う。

### 実行確認（実測）

全9シナリオを`jpetstore-legacy-jacoco`（overlayイメージ・legacy無改変）に対して再実行し、
`docker stop -t 30`（graceful）で停止後に`report.sh`を実行した:

```
[report] extracting denominator classfiles (domain/dao) from container 'jpetstore-legacy-jacoco-measure' ...
[report] generating AC1-denominator report -> .../out2/report/ac1
[INFO] Analyzing 22 classes.
[report] verifying excluded classes remain unreachable (0 coverage) ...
[report] OK: all excluded classes remain at 0 coverage (exclusion premise holds).
[report] generating gate-denominator report (AC1 minus 3 unreachable classes) -> .../out2/report/gate
[INFO] Analyzing 19 classes.
[report] done:
[report]   AC1分母(計測の分母) : .../out2/report/ac1/index.html
[report]   ゲート分母(判定用)  : .../out2/report/gate/index.html
```

- **AC1レポート**: 22クラス解析、合計値は本レポート§2の「合計（AC1分母）」と一致（BRANCH 16/42・
  INSTRUCTION 1144/1765）。
- **ゲートレポート**: 19クラス解析（22−3）、合計値は§2の「合計（ゲート分母）」と一致
  （**BRANCH 16/34=47.1%・INSTRUCTION 1144/1588=72.0%・LINE 304/407=74.7%・CLASS 19/19=100%**）。
  §5で合意したゲート値と完全に一致することを確認した（=このレポートの数値は`report.sh`が機構的に
  算出したものであり、手計算ではない）。
- **除外反証チェックの動作確認（fail-path）**: legacyの設定を変更することは禁止されているため、
  `jacoco.csv`の`MsSqlOrderDao`行を一時的に書き換えた合成データ（`instruction_covered=2`）を用意し、
  チェックロジック単体を実行したところ、**期待どおり`FAIL: excluded class MsSqlOrderDao now has
  coverage ...`で終了コード1になる**ことを確認した（legacy自体は無改変・実データは変更していない）。

---

## §7 採取後の後始末（AC-neg1）

- `jpetstore-legacy`イメージは無改変（計測用は別タグ`jpetstore-legacy-jacoco`のみビルド）。
- 採取用コンテナ`jpetstore-legacy-jacoco-measure`は`docker stop -t 30`（graceful）で停止後、
  レポート生成（`docker cp`でclassfiles抽出。§6）を経てから削除済み。
- 採取に使用したHSQLDBは計測専用コンテナのボリューム内のみに存在し、`jpetstore-legacy`本体のデータには
  影響しない（採取用コンテナ削除により消滅）。
