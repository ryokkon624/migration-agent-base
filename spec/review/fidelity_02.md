# spec 敵対的レビュー — レンズ: コード忠実性 (fidelity) / round 02（収束再レビュー）

- **対象**: `spec/behavior/order.md`（改訂）＋ `spec/backlog-map.md`（E3 改訂）＋ `spec/security-baseline.md`（新規）
- **round**: 02
- **日付**: 2026-08-10
- **方針**: round01 指摘の是正を1件ずつ判定（過剰修正・新誤記も見る）＋ 改訂で新規に入った不正確を legacy コードと突き合わせて検出。追認しない・濫造しない。

---

## 1. round01 指摘（fidelity_01.md）の是正確認 — 9件すべて是正済み

| # | round01 指摘 | 是正判定 | 反映箇所（改訂後）／再確認したコード |
| --- | --- | --- | --- |
| A（中） | 認可元が「session」でなく再 populate される form | ✅ 是正・過剰修正なし | `order.md` §2.2:30・§2.3:34・§5 S3行:63 で「session スコープだが Struts が毎リクエスト再 populate する `(AccountActionForm) form`」と正確化。§5 S3 と本文の矛盾も解消。コード再確認: `ListOrdersAction.java:13-14` / `ViewOrderAction.java:15,18` / `struts-config.xml:43-46`（listOrders name=accountForm scope=session）。exploit 例 `listOrders.do?account.username=<victim>` も妥当（`AccountActionForm.reset():106-111` は `account` を null 化せず nested populate 可）。 |
| B（中） | 「全操作サインオン」の誇張 | ✅ 是正 | §1:12-13 で「サインオン必須= newOrderForm/newOrder/listOrders/viewOrder」「公開= カート/チェックアウト表示（`ViewCartAction=BaseAction`）」に分離。コード一致（`ViewCartAction.java:10`）。 |
| C（低） | unitPrice=カート単価 → Item.listPrice | ✅ 是正 | §3:39「unitPrice は Item のマスター価格 `listPrice` を initOrder 時点で取り込む（`LineItem.java:25`）」。 |
| D（低） | orderstatus linenum=orderId / 1行 | ✅ 是正 | §3:43・§4:52「1行のみ・linenum 列に orderId・timestamp 列に orderDate」。`Order.xml:71-73` 一致。 |
| E（低） | @Transactional はクラスレベル | ✅ 是正 | §3:41「クラスレベル＝`:52`」。加えて `applicationContext.xml:72` の `tx:annotation-driven` が有効＝**トランザクションが実際に適用される**ことも確認（「1トランザクション」の主張が裏取りできた）。 |
| F（低） | 在庫は無条件減算（充足チェック無し） | ✅ 是正 | §3:42「無条件減算・充足チェックも負数ガードも無い・過剰販売可」。`Item.xml:72-74` / `SqlMapItemDao.java:16-25` 一致。PO論点①・F3.2 にも接続。 |
| G（低） | S4 は描画欄でなく自動 populate 経路 | ✅ 是正 | §5 S4行:65「JSP に描画されない totalPrice/username/unitPrice も Struts 自動 populate で注入束縛」。`NewOrderForm.jsp:11-51` 一致。 |
| H（低） | 確定 submit は GET | ✅ 是正 | §2.1:25・§5 S5行:66「最終確定は GET（`ConfirmOrder.jsp:76`）」。 |
| I（低） | getOrder は明細を別クエリで取得 | ✅ 是正 | §3:46「join（status1件）＋明細別クエリ `getLineItemsByOrderId`（`SqlMapOrderDao.java:23-30`）」。 |

→ **過剰修正（逆方向の誤記）・是正漏れは検出されず。**

---

## 2. 改訂で新規追加された記述の検証 — 主要点はコードと一致（＝反証できず）

新規追記が多いため、load-bearing なものを一次情報で確認した。以下は **正確**：

- §2.1:18 「checkout は viewCart と同一 Action、page/nextCart 等のページング分岐を引き継ぐ」→ `ViewCartAction.java:12-31`・`struts-config.xml:27-30,85-88` 一致。
- §2.1:19 「cartForm 無しで『An order could not be created…』failure」→ `NewOrderFormAction.java:24-27` 一致。
- §2.2:29 「ListOrders はヘッダのみ＝orderId/date/totalPrice、明細なし」→ `ListOrders.jsp:7,11,13,14`（3列のみ）＋ `SqlMapOrderDao.java:19-21`（getOrdersByUsername は明細を積まない）で**両面確認**。正確。
- §2.3:35 「非数値 orderId→NumberFormatException／存在しない orderId→getOrder が null→`order.getUsername()` で NPE→trace 露出」→ `ViewOrderAction.java:16-18`＋`SqlMapOrderDao.java:23-30`（0件で null）で成立。正確。not-owned（明確メッセージ）と not-found（NPE/500）が弁別可能＝列挙オラクルも整合。
- §3:44 「orderId は select→+1→update（`SqlMapSequenceDao.java:16-26`）」→ コード一致（SELECT getSequence → nextId+1 → updateSequence → 旧値 return）。※後述の軽微な精度注記あり。
- §4:55 / SBD-13 「金額はドメイン `double` vs DB `decimal(10,2)`」→ `Order.java:29`・`LineItem.java:13` が `double`、`schema:86,111` が `decimal(10,2)`。正確。
- §6:75 「`OrderService` は getOrder のみ宣言」→ `OrderService.java:18-22` 一致。
- backlog-map / §6 PO論点② 「注文確認メール `SendOrderConfirmationEmailAdvice` は legacy 同梱・現状 config 無効」→ **正確**。`applicationContext.xml` で `mailSender`（33-36）・`emailAdvice` bean（86-89）・`aop:advisor`（80-82）が**すべてコメントアウト**。petStore（54-60）は素の POJO に tx advice のみ。よって確定時にメール送信の副作用は無く、as-is フローの記述に副作用漏れはない。

---

## 3. 残存／新規の指摘

### [低] トレーサビリティ ｜ security-baseline SBD-4 の before 由来 ID 誤記（`S16/R16` → 正は `S19/R16`）

- **spec の記述**: `security-baseline.md:19` SBD-4（セッション管理／Cookie Secure/HttpOnly/SameSite）の「before 由来」＝ **`S8/R7, S16/R16`**。
- **実際**: Cookie フラグ欠落の finding は baseline で **`R16/S19`**（`baseline-summary.md:67`「平文 HTTP＋Cookie フラグ欠落（R16/S19）」）。**`S16` は別物＝Apache Axis 1.4(EOL) 無認証露出**（`baseline-summary.md:65`「（R8/S16）」）。SBD-4 は R 側（R16）は正しいが **S 側を S19 と取り違えて S16 と記載**している。実際、同じ Cookie 由来を扱う **SBD-15（`security-baseline.md:30`）は正しく `S19/R16` と引用**しており、SBD-4 だけ不整合。
- **なぜ問題か**: 本書は「NFR→before finding→Phase 4 回帰テストの種」を紐づける台帳。ID 誤記は Phase 4 の回帰テスト対応付けを誤らせ、S16(Axis) と S19(Cookie) の追跡を取り違える。
- **証拠**: `security-baseline.md:19`（誤）｜対比 `baseline-summary.md:65`(S16=Axis)・`:67`(S19=Cookie)・`security-baseline.md:30`(SBD-15 は S19/R16 と正記)
- **修正提案**: SBD-4 の由来を **`S8/R7, S19/R16`** に訂正（セッション固定=S8/R7、Cookie フラグ=S19/R16）。Cookie 項は SBD-15 と重複するため、SBD-4 は「session 再生成/無効化」に絞り Cookie フラグは SBD-15 に一本化するのも可。

### （精度注記・非指摘 / 参考）§3:44 sequence「非アトミック」の文脈

- 「select→+1→update の非アトミック＝並行で重複採番リスク」は **read-modify-write が 2 文＝アプリ層でアトミックでない**点は正しく、race の指摘も妥当（`リスク` と適切にヘッジ済み）。ただし当該 `getNextId` は `insertOrder`（クラスレベル `@Transactional`, tx:annotation-driven 有効）**の同一トランザクション内**で走るため、厳密には「原子性の欠如」ではなく **分離レベル依存の lost-update / 旧値 return による PK 衝突リスク**。現状記述で誤りではないので**指摘化しない**が、精緻化するなら「単一トランザクション内だが `SELECT … FOR UPDATE` 相当のロックが無く、分離レベル次第で重複採番/PK 衝突」と書ける。リビルドの「DB 原子採番（IDENTITY/sequence）」方針（§6:76・F3.2）は妥当。

---

## 4. 収束判定

- **収束: converged（コード忠実性レンズ）。追加ラウンド不要。**
- 根拠: round01 の 9 指摘はすべて正確に是正され、過剰修正・是正漏れ・新規の「存在しない挙動の記述」は検出されなかった。改訂で追加された多数の新記述（checkout=viewCart 同一 Action、ListOrders のヘッダのみ表示、viewOrder の NPE 経路、sequence 採番、email advice 無効、double vs decimal、OrderService 単一メソッド 等）は一次情報（コード/JSP/Spring config/schema）と一致。
- **残指摘は 1 件（[低]・SBD-4 の before-由来 ID 誤記）のみ**で、これは behavior spec のコード忠実性ではなく横断NFR 台帳のトレーサビリティ表記の訂正。次ラウンドを回すまでもなく **その場修正で足りる**（`S16/R16`→`S19/R16`）。
- 参考の精度注記（sequence の tx 文脈）は任意の精緻化であり、収束判定には影響しない。
