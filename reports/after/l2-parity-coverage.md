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

| パッケージ | BRANCH | LINE | INSTRUCTION | 所見 |
| --- | --- | --- | --- | --- |
| `domain` | 6/14 = 42.9%（spike同値） | 211/253 = 83.4%（spike 81.4%から微増） | 746/909 = 82.1% | `Order`はbranch 100%（2/2）。`Account`はbranch 0%（0/4） |
| `dao.ibatis` | 10/22 = 45.5%（spike同値） | 90/99 = 90.9% | 310/475 = 65.3% | Category/Product/Sequence系DAOは軒並み100%。`SqlMapAccountDao`は0%（§3） |
| **`domain.logic`** | **0/6 = 0.0%（spike同値・未改善）** | 31/131 = 23.7%（spike 25.0%から微減\*） | 88/381 = 23.1% | **最大のギャップ。§3参照** |
| `dao` | n/a | n/a | n/a | インタフェースのみ（分岐なし・解析対象外） |

\* `domain.logic`のLINE分母がspike計測時（§7.2記載）と本実測でわずかに異なって見えるのは、
spikeが読み取り系の一部（カテゴリ5・商品3・アイテム3）のみを対象にした暫定計測であるのに対し、
本実測は#48+#49で確立した正式な9シナリオ全件を対象にしているため（母数となるクラス構成自体は不変・
`domain.logic`は4クラス360命令のうち94命令をカバー）。

---

## §3 `domain.logic`のBRANCH 0%が動かなかった理由（実測に基づく原因分析）

spike時点から**全9シナリオ（読み取り系6本＋状態変更系3本）に拡張してもなお`domain.logic`のbranch
coverageは16/42のまま変化しなかった**。パッケージ内訳（`tools/legacy-jacoco/out/report/`の該当クラス
詳細）で原因を特定した:

| クラス | branch coverage | 所見 |
| --- | --- | --- |
| `SendOrderConfirmationEmailAdvice` | **0%（0/6）** | 注文確定のAOP advice。W1/W2/W3で注文確定自体は実行しているが、advice内部の分岐は一切踏めていない。メール送信結果の分岐と思われ、**メールサーバ接続不能等でadvice冒頭からリターンしている可能性が高い**（追加シナリオでは解消しない・インフラ側の要因の可能性）。domain.logicのbranch 0%はほぼこの1クラス（6分岐）に起因する |
| `OrderValidator` | branch: n/a（総分岐数0）・instruction 2% | validate()メソッド自体がほぼ未実行。REST経由の駆動ではStruts ActionForm検証の入口を通らないため構造的に踏めない可能性 |
| `AccountValidator` | branch: n/a・instruction 5% | アカウント系シナリオ未実装（W4/W5・下記§4）のため未踏 |
| `PetStoreImpl` | branch: n/a（分岐なし）・instruction 77% | ファサードクラス。9シナリオでよく踏めている |

**含意**: `domain.logic`のbranch 0%は「シナリオ本数が足りない」だけでなく、**`SendOrderConfirmationEmailAdvice`
という単一クラスの6分岐に集中したギャップ**である。ここは新シナリオの追加だけでは解消しない可能性があり、
（a）advice内部の分岐条件を実機コード（`SendOrderConfirmationEmailAdvice.java`）で確認したうえで、
（b）メール送信を成立させる/失敗させる両方の環境条件を作り分けるテスト設計が必要になる。次イテレーションの
調査対象として明記する（§5）。

`dao.ibatis`の`MsSqlOrderDao`（0%・46 instruction）・`OracleSequenceDao`（0%・20 instruction）は、
HSQLDBデプロイでは**Spring設定上インスタンス化されない別DB向け実装**であり、シナリオ追加では**到達不能**
（AC5「到達不能な分岐の除外理由」に該当）。分母定義（Issue #50 AC1）は変更しないが、ゲート値合意の際は
この2クラス（合計66 instruction・全体の3.7%）が構造的に到達不能である点を根拠として提示する。

---

## §4 次に足すべきシナリオ（AC6・未踏分岐からの名指し）

| # | 候補 | 対象 | 根拠 |
| --- | --- | --- | --- |
| 1 | **W4: アカウント新規登録**（`newAccountForm.do`→`newAccount.do`） | `Account`（branch 0/4）・`AccountValidator`（instruction 5%）・`SqlMapAccountDao`（instruction 34%・branch 0/4） | 最も明確な未踏クラス群。design.md §6-2で「次イテレーション」と位置付け済み |
| 2 | **W5: アカウント編集**（`editAccountForm.do`→`editAccount.do`） | 同上（更新系分岐の追加） | 同上 |
| 3 | **注文履歴照会**（`listOrders.do`/`viewOrder.do`） | `SqlMapOrderDao`（branch 50%・2/4未踏） | `dao.ibatis`の残存ギャップ最大手 |
| 4 | **`SendOrderConfirmationEmailAdvice`の分岐調査** | `domain.logic`のbranch 0%の主因（§3） | シナリオ追加より先にadvice実装の分岐条件をコードで確認する調査タスクが必要 |
| 5 | **カート境界値**（空カートでの`removeItemFromCart.do`等） | `Cart`/`CartItem`（branch 50%） | W1〜W3で未踏の分岐が残る |

---

## §5 ゲート値合意への申し送り（SM→PO）

- **実測**: BRANCH 38.1%・LINE 67.3%・INSTRUCTION 64.8%・CLASS 86.4%（全9シナリオ）。
- **到達不能な分岐の候補**: `MsSqlOrderDao`・`OracleSequenceDao`（計66 instruction・別DB向け実装で
  HSQLDBデプロイでは到達不能）。ゲート値合意の際、分母からの除外要否も含めて検討候補として提示する
  （**本レポート時点では分母を変更していない**＝Issue #50 AC1の29クラスを維持）。
- **`domain.logic`のbranch 0%**: シナリオ本数の問題ではなく`SendOrderConfirmationEmailAdvice`という
  単一クラスへの集中。次イテレーションで実装調査が必要（§3/§4-4）。
- **次イテレーション候補**: §4のW4/W5（アカウント系）・注文履歴照会が最有力。

---

## §6 採取後の後始末（AC-neg1）

- `jpetstore-legacy`イメージは無改変（計測用は別タグ`jpetstore-legacy-jacoco`のみビルド）。
- 採取用コンテナ`jpetstore-legacy-jacoco-measure`は`docker stop -t 30`（graceful）で停止後、
  レポート生成（`docker cp`でclassfiles抽出）を経てから削除済み。
- 採取に使用したHSQLDBは計測専用コンテナのボリューム内のみに存在し、`jpetstore-legacy`本体のデータには
  影響しない（採取用コンテナ削除により消滅）。
