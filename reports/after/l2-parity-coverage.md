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

| 指標 | spike時点（読み取り系一部＋W1のみ・§7.2） | **本実測（#48+#49・全9シナリオ）** | 増分 |
| --- | --- | --- | --- |
| **BRANCH** | 16/42 = 38.1% | **16/42 = 38.1%** | ±0（詳細は§2） |
| LINE | 297/452 = 65.7% | **304/452 = 67.3%** | +7 lines |
| INSTRUCTION | 1119/1765 = 63.4% | **1144/1765 = 64.8%** | +25 instructions |
| CLASS | 19/22 = 86.4% | **19/22 = 86.4%** | ±0 |

**ゲート値は本レポートでは決めない**（backlog #50 AC5のとおり、実測を提示したうえでSMがPOを起動し合意する。
先に数値を決めると帳尻合わせになるため）。実測と分析は本レポートで完結させ、SMへ実測値を報告して
ゲート値合意のステップへ引き継ぐ。

分母の定義（29クラス・うちJaCoCoが解析対象とするのは22クラス。`web.struts`/`web.spring`はID-6、
`service`/`service.client`はID-5によりそれぞれ除外）は下記§1のとおり（Issue #50 AC1で確定済み・変更なし）。

> **【差し替え】到達不能分岐を除いた「到達可能分母」での再計算**（実コード裏取りで確定・§3参照）:
> BRANCH分母42のうち**6分岐（`SendOrderConfirmationEmailAdvice`）は`applicationContext.xml`で
> bean定義・advisorとも丸ごとコメントアウトされ一度もインスタンス化されない=構造的に到達不能**と判明した。
> 到達可能な分母は **36分岐**、実測は**16/36 = 44.4%**（AC1の分母定義29クラス自体は変更しない。
> あくまでAC5が求める「到達不能な分岐の除外理由」を明記したうえでの参考値）。

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

| パッケージ | BRANCH（AC1分母） | BRANCH（**到達可能分母**） | LINE | INSTRUCTION | 所見 |
| --- | --- | --- | --- | --- | --- |
| `domain` | 6/14 = 42.9%（spike同値） | 同左（到達不能分岐なし） | 211/253 = 83.4%（spike 81.4%から微増） | 746/909 = 82.1% | `Order`はbranch 100%（2/2）。`Account`はbranch 0%（0/4） |
| `dao.ibatis` | 10/22 = 45.5%（spike同値） | 同左（到達不能分岐なし） | 90/99 = 90.9% | 310/475 = 65.3% | Category/Product/Sequence系DAOは軒並み100%。`SqlMapAccountDao`は0%（§3） |
| **`domain.logic`** | 0/6 = 0.0%（spike同値） | **6分岐全て到達不能（§3）＝到達可能分母0** | 31/131 = 23.7%（spike 25.0%から微減\*） | 88/381 = 23.1% | **branch 0%は死んだコード(未配線advice)を分母に数えていた見かけ上のギャップ。§3参照** |
| `dao` | n/a | n/a | n/a | n/a | インタフェースのみ（分岐なし・解析対象外） |
| **合計** | **16/42 = 38.1%** | **16/36 = 44.4%** | 304/452 = 67.3% | 1144/1765 = 64.8% | 到達不能6分岐は全て`domain.logic`（advice）に集中 |

\* `domain.logic`のLINE分母がspike計測時（§7.2記載）と本実測でわずかに異なって見えるのは、
spikeが読み取り系の一部（カテゴリ5・商品3・アイテム3）のみを対象にした暫定計測であるのに対し、
本実測は#48+#49で確立した正式な9シナリオ全件を対象にしているため（母数となるクラス構成自体は不変・
`domain.logic`は4クラス360命令のうち94命令をカバー）。

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
<\aop:config>

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

`dao.ibatis`の`MsSqlOrderDao`（0%・46 instruction）・`OracleSequenceDao`（0%・20 instruction）も、
HSQLDBデプロイでは**Spring設定上インスタンス化されない別DB向け実装**であり、シナリオ追加では**到達不能**
（AC5「到達不能な分岐の除外理由」に該当）。分母定義（Issue #50 AC1）は変更しないが、ゲート値合意の際は
この2クラス（合計66 instruction）＋`SendOrderConfirmationEmailAdvice`（6分岐）が構造的に到達不能である
点を根拠として提示する（§5）。

---

## §4 次に足すべきシナリオ（AC6・未踏分岐からの名指し）

`SendOrderConfirmationEmailAdvice`は§3のとおり**構造的に到達不能（未配線）と確定した＝調査対象ではなく
除外対象**のため、候補から外し、W4/W5（アカウント系）・注文履歴照会の優先度を繰り上げる。

| # | 候補 | 対象 | 根拠 |
| --- | --- | --- | --- |
| 1 | **W4: アカウント新規登録**（`newAccountForm.do`→`newAccount.do`） | `Account`（branch 0/4）・`AccountValidator`（instruction 5%）・`SqlMapAccountDao`（instruction 34%・branch 0/4） | 最も明確な未踏クラス群。design.md §6-2で「次イテレーション」と位置付け済み。到達可能分岐（36分母）に対する寄与も最大 |
| 2 | **W5: アカウント編集**（`editAccountForm.do`→`editAccount.do`） | 同上（更新系分岐の追加） | 同上 |
| 3 | **注文履歴照会**（`listOrders.do`/`viewOrder.do`） | `SqlMapOrderDao`（branch 50%・2/4未踏） | `dao.ibatis`の残存ギャップ最大手 |
| 4 | **カート境界値**（空カートでの`removeItemFromCart.do`等） | `Cart`/`CartItem`（branch 50%） | W1〜W3で未踏の分岐が残る |
| 5（調査候補・優先度低） | **`OrderValidator`の配線状況確認** | `domain.logic`・instruction 2% | `SendOrderConfirmationEmailAdvice`と同様、Spring設定で無効化されていないか確認する価値はあるが、`branch: n/a`（総分岐数0）のためbranch coverageへの寄与は無い。W4/W5着手後に余力があれば調査 |

---

## §5 ゲート値合意への申し送り（SM→PO）

- **実測（AC1分母）**: BRANCH 16/42=38.1%・LINE 304/452=67.3%・INSTRUCTION 1144/1765=64.8%・
  CLASS 19/22=86.4%（全9シナリオ）。
- **実測（到達可能分母・参考値）**: BRANCH **16/36=44.4%**（§2/§3。AC1の29クラス分母自体は変更しない）。
- **到達不能な分岐/クラスの候補（計3クラス）**:
  - `SendOrderConfirmationEmailAdvice`（branch 6・instruction 111）: `applicationContext.xml`で
    bean定義・advisorとも丸ごとコメントアウトされ一度もインスタンス化されない。**実コードで確定
    （§3）**・調査ではなく除外対象
  - `MsSqlOrderDao`（instruction 46）・`OracleSequenceDao`（instruction 20）: 別DB向け実装で
    HSQLDBデプロイでは到達不能（従来どおり）
  - ゲート値合意の際、この3クラスの分母からの除外要否も含めて検討候補として提示する
    （**本レポート時点では分母を変更していない**＝Issue #50 AC1の29クラスを維持）。
- **`domain.logic`のbranch 0%**: シナリオ本数の問題ではなく、未配線advice（構造的に到達不能）を
  分母に数えていたことによる見かけ上のギャップだった（§3で確定）。**追加調査は不要・除外対象として
  扱う**。
- **次イテレーション候補**: §4のW4/W5（アカウント系）・注文履歴照会が最有力（優先度繰り上げ）。

---

## §6 採取後の後始末（AC-neg1）

- `jpetstore-legacy`イメージは無改変（計測用は別タグ`jpetstore-legacy-jacoco`のみビルド）。
- 採取用コンテナ`jpetstore-legacy-jacoco-measure`は`docker stop -t 30`（graceful）で停止後、
  レポート生成（`docker cp`でclassfiles抽出）を経てから削除済み。
- 採取に使用したHSQLDBは計測専用コンテナのボリューム内のみに存在し、`jpetstore-legacy`本体のデータには
  影響しない（採取用コンテナ削除により消滅）。
