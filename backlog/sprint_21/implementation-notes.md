# Sprint 21 実装ノート

## #48: L2パリティ検証基盤の確立（縦切り1本＝W1）

### D1スモーク確認（SM申し送り①）

`ParityIntegrationTestBase`（`IntegrationTestBase`のサブクラスで`@SpringBootTest(webEnvironment = RANDOM_PORT)`を再宣言）を
`ParityIntegrationTestBaseSmokeSpec`で実HTTP到達確認したところ、Tomcatが実ポートで起動することを確認できた
（`integrationTest`実行ログに `Tomcat started on port 51179 (http)` が出力・`GracefulShutdown`も実行された＝MOCK環境では
発生しない実サーバ起動の証跡）。**サブクラス再宣言はそのまま機能したため、フォールバック（独立基底＋同一Singletonコンテナ）は不要だった**。
`IntegrationTestBase`自体は無変更のまま（D1）。

### CSRFヘルパの罠（SM申し送り②・spikeで4回踏んだ落とし穴の実機再現）

`NewHttpClient.ensureCsrfToken()`の初版実装は、リトライループに Groovy の `(1..N).each { ... return token }` を使っていた。
**Groovyのクロージャ内`return`は`.each{}`のループを抜けず`continue`相当にしかならない**ため、トークンが早期に取得できても
ループは常に最後まで回り、その時点のCookie状態で成否が決まってしまう不具合だった。

`OrderParitySpec`実行時に実際に`IllegalStateException`で検出できた（トークン取得の試行履歴）:

```
XSRF-TOKEN Cookieが10回のGET /api/pingでも取得できなかった:
attempt 1: present, attempt 2: absent, attempt 3: present, attempt 4: absent,
attempt 5: present, attempt 6: absent, attempt 7: present, attempt 8: absent,
attempt 9: present, attempt 10: absent
```

この出力自体が「トークンCookieの有無が繰り返しトグルする」というF3（交互ローテーション）の実機再現にもなっている。
素の`for`ループへ書き換え（トークン取得次第で即`return`しメソッド自体を抜ける）て解消した。

### legacy HSQLDBスキーマの実機確認（design.md §7.1の追加実測）

`jpetstore-legacy`イメージのコンテナに対し`INFORMATION_SCHEMA.SYSTEM_TABLES`/`SYSTEM_COLUMNS`をJDBCで問い合わせ、
以下を実測した（推測ではなく実機確認）:

| テーブル | 列 |
| --- | --- |
| `INVENTORY` | `ITEMID VARCHAR`, `QTY INTEGER` |
| `ORDERS` | `ORDERID INTEGER`, `TOTALPRICE DECIMAL`, `SHIP*`/`BILL*`/`COURIER`/`CREDITCARD`/`EXPRDATE`/`CARDTYPE`/`LOCALE`（比較除外列） 等 |
| `LINEITEM` | `ORDERID`, `LINENUM`, `ITEMID`, `QUANTITY`, `UNITPRICE` |
| `ORDERSTATUS` | `ORDERID`, `LINENUM`, `TIMESTAMP`, `STATUS` |
| `SEQUENCE` | `NAME`（`linenum`/`ordernum`）, `NEXTID` |

初期シード実測（pristineコンテナ）: `EST-1`在庫=10000、`ORDERS`件数=2・`MAX(ORDERID)`=1001、
`SEQUENCE`は`linenum`=1000・`ordernum`=1002（design.md F1の記述と一致）。

### W1駆動フォームの実機確認

`legacy-jpetstore`の JSP（`Cart.jsp`/`NewOrderForm.jsp`/`SignonForm.jsp`）を確認し、POSTフォームフィールド名を実装に反映:

- `signon.do`: `username`/`password`
- `updateCartQuantities.do`: フィールド名が**itemIdそのもの**（例: `EST-1=2`）
- `newOrder.do`: `order.cardType`/`order.creditCard`/`order.expiryDate`/`order.billToFirstName`/`order.billToLastName`/
  `order.billAddress1`/`order.billAddress2`/`order.billCity`/`order.billState`/`order.billZip`/`order.billCountry`
  （`shippingAddressRequired`チェックボックスは未送信＝配送先は請求先と同一）
- `newOrder.do?confirmed=true`（GET）で確定

### golden採取・復元の実証（AC-neg2）

`jpetstore-legacy`（無改変）から一時コンテナ`jpetstore-legacy-parity`（`-p 8081:8080 -p 9002:9002`）を起動し
`captureGolden`でW1を採取。採取後、`docker stop -t 30`（graceful）→`docker rm`で後始末し、
legacy DBが採取前と完全に同一状態へ復元されたことをJDBCで確認した:

| 項目 | 採取前 | 採取後 |
| --- | --- | --- |
| `EST-1`在庫 | 10000 | 10000 |
| `ORDERS`件数 | 2 | 2 |
| `MAX(ORDERID)` | 1001 | 1001 |
| `SEQUENCE`(linenum/ordernum) | 1000/1002 | 1000/1002 |

golden JSON（`src/test/resources/parity/golden/order-single-item.json`）は正規化済みの値（scale(2)）で保存する方針とした
（`LegacyCaptureTool`が書き出し前に`ParitySnapshot#normalize()`を適用。design.mdのcanonical例と完全一致させ、
差分レビュー時に人が読んでそのまま信用できる状態にする）。

### AC-neg1の実証（台帳に無い不一致の検知）

golden `order-single-item.json`の`unitPrice`を `"16.50"` → `"16.99"` へ一時的に書き換え、
`./gradlew parityTest --tests "*OrderParitySpec"` を実行したところ、以下のとおり**失敗し、どのシナリオの
どのフィールドが食い違ったかが出力から判別できる**ことを確認した:

```
Condition not satisfied:

result.pass
|      |
|      false
scenario=order-single-item: EQUIVALENT宣言だが差分あり(台帳に無い差分=欠陥候補) ->
  field=lines[EST-1].unitPrice golden(legacy)="16.99" actual(new)="16.50"
```

（golden側を書き換えたため`golden(legacy)`欄に改変後の値`16.99`、`actual(new)`欄に実際の新側値`16.50`が出ている。
どちらを書き換えても同様にフィールド・両側の値が特定できる）。確認後、goldenを`"16.50"`へ戻し`parityTest`が
再びgreenになることも確認済み。

### 既存IT 26本の非干渉確認

`integrationTest`に`excludeTags 'parity'`を追加し、`./gradlew integrationTest`をフル実行。
結果ファイルは従来どおり26件（parityタグ付きの3 Spec＝`ParityIntegrationTestBaseSmokeSpec`/`NewHttpClientSpec`/
`OrderParitySpec`は含まれない）、全26件が`failures="0" errors="0"`でgreen。二重実行・取りこぼしいずれも無し。

### `parityTest`の実行結果（DoD）

`./gradlew parityTest`（legacy停止状態）: **BUILD SUCCESSFUL**（3 Spec dual-tag、全green）。

---

## #49: シナリオ台帳をR1〜R6・W2・W3へ横展開

### 実機で発覚した2つの発見（推測ではなく実測。#48の設計を訂正）

1. **legacy実機では`fmt:formatNumber`がフォーマットを適用しない。** design.md §7.1やJSPソース
   （`Product.jsp`/`Item.jsp`）は`pattern="$#,##0.00"`を指定しているが、**実際にcurlで叩いた応答は
   `$`無し・末尾ゼロ無しの生の数値（例: `16.5`）がそのまま出力される**（`Sub Total: 33.0`・
   `Total: 33.0`等、W1のスクラッチ観測とも整合）。当初`\$([0-9,]+\.[0-9]{2})`という`$`前提の正規表現で
   `extractItemRows`/R4のlistPrice抽出を実装したところ、`items-by-product`のentriesが空・
   `item-detail`のlistPriceがnullになる欠陥として即座に検出できた（golden採取直後の目視確認で発覚）。
   `<td>数値のみ</td>`という「セル内容が数値のみ」の形で価格セルを識別する
   `LegacyHtmlExtractor.extractPlainDecimal`へ是正した。
2. **`ordersCreated`をグローバル採番ID（`MAX(order_id)`）の差分で算出すると、複数シナリオを
   同一プロセス内で連続実行した際に誤った値になる。** legacy側の`ordernum`シーケンスは各シナリオ後に
   JDBCで復元しているため単体では問題にならないが、**新側（MySQL `t_order.order_id` AUTO_INCREMENT）は
   `DELETE`後もカウンタが戻らない**ため、2番目以降のシナリオで`MAX(order_id)`の差分が「新規作成件数」と
   一致しなくなる（`order-multi-item`実行時に`ordersCreated`が実測`2`になり、golden期待値`1`と不一致で
   検出）。旧新とも`COUNT(*)`の前後差分へ是正した（`LegacyDbReader#orderCount`/`NewDbReader#orderCount`）。

### W3（在庫不足）で発覚した新側固有のカートレベルガード（design.mdにも#49 ACにも無い新事実）

新側`POST /api/cart/items`は**カートへの追加時点で在庫超過を400 BAD_REQUESTとして拒否する**
（legacyには対応するガードが無い＝カート操作はセッション内で完結し在庫を一切見ない）。当初
「在庫を注文数未満へ先に下げてからカートへ追加」という設計（legacy側と同じ手順）を新側にも
適用したところ、カート追加自体が400で失敗し、意図していた「注文確定APIの409」に到達できなかった
（`addToCart失敗: status=400 ... Requested quantity exceeds available stock`）。

`OrderControllerSpec`の「在庫不足(競合負けを含む)」テストと同じ手順（**在庫があるうちにカートへ追加し、
その後に在庫を減らしてから注文確定する**＝同時発注による在庫減少の再現）へ設計を変更し、
`NewScenarioRunner#placeOrder`に`beforeOrderSubmit`フック（カート追加後・注文確定直前に実行）を追加して
解消した。あわせて、canonicalの`inventoryDelta`算出基準点（`qtyBefore`を捕捉するタイミング）を
「注文確定APIを呼ぶ直前」に統一した（新側はカート追加後に在庫を下げるため、カート追加前を基準にすると
無意味に大きな差分〔-99等〕になっていた）。

`order-insufficient-stock`の`divergentFields`は当初`["outcome", "inventoryDelta[EST-1]"]`のみだったが、
実測すると成功時専用フィールド（`ordersCreated`/`orderTotal`/`lines[EST-1].*`）も旧新で必然的に食い違う
ため、宣言外の差分としてfailした（Q4の効果を実地で確認できた一例）。実測に基づき全差分フィールドを
明示的に台帳へ列挙して解消した。

### 全9シナリオの`parityTest`実行結果（DoD）

`./gradlew parityTest`（legacy停止状態）: **BUILD SUCCESSFUL**（4 Spec・13テスト全green）。
内訳: `ParityIntegrationTestBaseSmokeSpec`(1)・`NewHttpClientSpec`(3)・`OrderParitySpec`(W1/W2/W3・3)・
`CatalogParitySpec`(R1〜R6・6)。`./gradlew integrationTest`も既存26本全green（非干渉を再確認）。

---

## レビュー対応: W3(ID-1)の証拠固定化（SM verification確定所見）

### 指摘の要旨

`LegacyScenarioRunner.orderInsufficientStock()`は在庫を1にしてから2個注文するが、**goldenに残るのは
delta `-2`と`outcome: SUCCESS`だけ**で、前提（在庫<注文数）も結果の絶対値（在庫がマイナス化したこと）も
記録・検証されていなかった。加えて`LegacyDbReader.restoreInventoryQty`はaffected rowsを検査しない
裸のUPDATEだった。**前処理UPDATEが黙って0行になっても（itemId不一致・表定義変更等）legacyは在庫10000の
まま注文成功→goldenは現状とバイト同一になり、`parityTest`はgreenのままID-1の観測点だけが静かに失われる**
という指摘（AC-neg1「台帳の形骸化を検知する」の趣旨に反する欠落）。

### 対応

- **(a)** `LegacyDbReader#update`をaffected rows（`int`）を返すよう変更し、`restoreInventoryQty`が
  **0行なら`IllegalStateException`でfail**するようにした。
- **(b)** `orderInsufficientStock()`で、前処理直後に**「事前在庫 < 注文数」**を、`placeOrder`実行後に
  **「事後在庫 < 0」**を実際にDBへ問い合わせて検証し、いずれかが満たされなければ**goldenを書き出さずに
  fail**するようにした（`LegacyScenarioRunner`の戻り値を`ParitySnapshot`から`CaptureResult`
  （snapshot+任意の`preconditions`）へ変更）。
- **(c)（推奨・採用）** 検証した実測値（`qtyBefore`/`qtyAfter`）を`ParityGolden.preconditions`
  （`capturedFrom`と同階層・`@JsonInclude(NON_NULL)`で未使用シナリオのJSON schemaは変えない）として
  goldenへ残した。`ParityComparator`は参照しない（canonical比較の対象外）。W3のgolden実例:

  ```json
  "preconditions" : { "EST-1" : { "qtyBefore" : 1, "qtyAfter" : -1 } }
  ```

### 実証（(a)(b)が実際に機能することを確認）

`orderInsufficientStock()`内の`restoreInventoryQty`呼び出しを一時的に存在しないitemId
（`EST-DOES-NOT-EXIST`）へ差し替えて`captureGolden`を実行したところ、**affected rows=0を検知して
即座に例外でfailし、goldenを書き出さないこと**を確認した:

```
Exception in thread "main" java.lang.IllegalStateException:
restoreInventoryQty(itemId=EST-DOES-NOT-EXIST, qty=1)の更新行数が0(期待値=1)。
itemIdの不一致や表定義の変更等でUPDATEが対象行に当たっていない可能性がある。
```

確認後、legacy DBの状態（`EST-1`在庫=10000・注文2件・sequence初期値）が変化していないことをJDBCで確認し
（例外は駆動前に発生するため実害なし）、修正を元に戻して**実golden 9本を再採取**した。

### その他のレビュー対応

- **②（軽微）**: `NewHttpClient`/`LegacyHttpClient`の`captureCookies`内`return`（`.each{}`内で
  continue相当・正しい実装）に、意図的な実装であることを示すコメントを1行追加した（挙動は変更なし）。
- **③（却下・対応不要）**: conv reviewerの「`captureCookies`も`for`へ統一すべき」提案はSM verification
  で却下済み。`ensureCsrfToken`（本物のバグ）と`captureCookies`（continueとして正しい）は同じ`return`
  でも意味論が逆であり、機械的統一は「不正ヘッダ1件でCookie取り込みが全停止」する実バグを招くため
  対応不要（コード変更なし）。

### 再確認結果

`./gradlew parityTest`（legacy停止状態・`--rerun`）: **BUILD SUCCESSFUL**（4 Spec・13テスト全green）。
`./gradlew test integrationTest`: 既存26本含め全green（非干渉を再確認）。
