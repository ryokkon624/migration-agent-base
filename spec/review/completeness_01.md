# spec 敵対的レビュー — レンズ=完全性 (completeness)

- **対象**: `spec/behavior/order.md` ＋ `spec/backlog-map.md`（E3 注文 の節）
- **round**: 01
- **日付**: 2026-08-10
- **レビュー方針**: legacy（Struts 稼働構成）の struts-config / 各 Action / iBATIS SqlMap / DB schema / 各 JSP を一次情報として突合し、spec が拾えていない as-is 挙動・業務ルール・画面・エラー分岐・入力バリデーション・状態遷移・データを列挙する。結論（before サマリ）には引きずられず自分で確認した。追認しない。

---

## 指摘リスト

### [重大度 高] 業務ルール／整合性 ｜ 所有者・本人性チェックの as-is 記述が「セッション由来」と誤記され、実機構（リクエストで再バインドされる ActionForm）が欠落

`order.md` §2.2 は一覧を「**セッションのユーザー名**で `getOrdersByUsername`」、§2.3 は詳細を「**所有者チェック（`session.account.username == order.username`）**」と記す（order.md:25, order.md:28）。しかし実コードはいずれも **リクエストにバインドされる ActionForm から username を取る**：`ListOrdersAction` は `AccountActionForm acctForm = (AccountActionForm) form; acctForm.getAccount().getUsername()`（ListOrdersAction.java:13-14）、`ViewOrderAction` も `AccountActionForm acctForm = (AccountActionForm) form; ... acctForm.getAccount().getUsername().equals(order.getUsername())`（ViewOrderAction.java:15-18）。struts-config でこの form は `name="accountForm" scope="session"`（struts-config.xml:43-44, 97-98）だが、Struts は毎リクエスト `BeanUtils.populate` で form を再投入するため、`?account.username=<victim>` で username を差し替え可能。これが §5 の S3 identity-rebind IDOR（order.md:50）そのもので、**§2（as-is）と §5（findings）が矛盾**している。as-is 記述が「session 由来の信頼値」を示唆することで、リビルド側が「session 起点の所有者判定を等価移植」と誤読し、一覧（listOrders）も同じ再バインド攻撃面である事実（§2.2 は完全に隠している）を見落とすリスクがある。

- **証拠**: ListOrdersAction.java:13-14 / ViewOrderAction.java:15-18 / struts-config.xml:43-44,97-98 vs order.md:25, order.md:28, order.md:50
- **修正提案**: §2.2/§2.3 の as-is 記述を「username は**リクエストで再バインドされる ActionForm（`(AccountActionForm) form`）**から取得しており、session の信頼値ではない」に訂正。listOrders も identity-rebind の対象であることを明記し、§5 の S3 行と一覧を明示的に紐付ける。

### [重大度 高] 業務ルール（欠落）｜ チェックアウト時に在庫availabilityチェックが無い（過剰販売＝在庫マイナスが as-is 挙動）

`order.md` §3 は確定処理を「`itemDao.updateQuantity(order)`（在庫引当＝減算）」とだけ記し（order.md:34）、backlog-map F3.2 も「在庫減算と注文永続化を1トランザクション」（backlog-map.md:23-24）とアトミック性のみ述べる。しかし実装は **在庫残数を一切チェックせずに減算する**：`update inventory set qty = qty - #increment# where itemid = #itemId#`（Item.xml:72-74）。`isItemInStock`（SqlMapItemDao.java:28-31）は存在するが `PetStoreImpl.insertOrder`（PetStoreImpl.java:147-150）でも `updateQuantity`（SqlMapItemDao.java:16-26）でも**呼ばれない**。結果、在庫を超える数量・在庫0のitemでも注文が通り qty がマイナスになる（過剰販売）。「挙動等価で残す」対象（order.md:57）に対して、この重要な業務ルールの欠如（availability 検証なし）が spec 未記載で、リビルドが「在庫チェックを足す／足さない」を判断する材料が無い。

- **証拠**: Item.xml:72-74 / SqlMapItemDao.java:16-31 / PetStoreImpl.java:147-150 vs order.md:34, backlog-map.md:23-24
- **修正提案**: §3 に「as-is は在庫残数チェック無しで減算＝過剰販売可能（マイナス在庫を許容）」を明記。F3.2 に「availability 検証を新設するか（as-is 非等価の改善）／挙動等価で無検証を維持するか」を PO 論点として追加。

### [重大度 中] データ（欠落）｜ 注文確定が書き込む `inventory` テーブルが §4 データモデルに無い

§4 は as-is データモデルとして `orders` / `lineitem` / `orderstatus` / `sequence` のみを列挙する（order.md:39-43）。しかし注文確定トランザクションは `inventory`（itemid, qty）を更新する（Item.xml:72-74, schema:156-160）。注文ドメインが変更する唯一の「注文4表以外」のテーブルであり、原子性（F3.2）の対象に含まれるのに data model から漏れている。

- **証拠**: schema:156-160 / Item.xml:72-74 vs order.md:39-43
- **修正提案**: §4 に `inventory`（itemid PK, qty）を追加し、「確定トランザクションが lineitem 各行の itemId に対し qty を減算」と明記。

### [重大度 中] 状態遷移／データ（欠落・誤り）｜ `orderstatus` の実挙動（linenum=orderId・timestamp=orderDate・実質1行）が spec と食い違う

§3 は「`orderstatus` に (orderId, linenum, timestamp, status) を1件」（order.md:34）、§4 は「`orderstatus`（orderid+linenum PK, timestamp, status）」（order.md:41）と、linenum を通常の明細行番号のように記す。しかし `insertOrderStatus` は **linenum 列に `#orderId#` を入れ、timestamp 列に `#orderDate#`（注文日）を入れる**：`values (#orderId#, #orderId#, #orderDate#, #status#)`（Order.xml:71-73）。さらに schema の PK は (orderid, linenum) で 1:N を許すが（schema:98-104）、実際は注文ごとに1行しか作らない。`getOrder`/`getOrdersByUsername` は orders と orderstatus を inner join するため（Order.xml:35-55）、**orderstatus 行が無い注文は一覧・詳細に一切現れない**。status は常に "P"（Order.java:155）。status 遷移運用の要否（order.md:60 で PO 送り）を判断するうえで、この 1:1 実態・linenum の異常値・inner join 依存は必須情報だが未記載。

- **証拠**: Order.xml:71-73 / Order.xml:35-55 / schema:98-104 / Order.java:155 vs order.md:34, order.md:41
- **修正提案**: §3/§4 に「as-is は注文ごと orderstatus 1行のみ・linenum 列に orderId を格納・timestamp=orderDate・status='P' 固定」「getOrder/getOrdersByUsername は orderstatus と inner join（status 行が無いと取得0件）」を明記。status 履歴を N 行で持つかは §6 の PO 論点に接続。

### [重大度 中] 画面／機能（欠落）｜ 注文確認メール（`SendOrderConfirmationEmailAdvice`）が spec・E3 Feature から完全に欠落

legacy には注文確定後にメール送信する AOP アドバイス `SendOrderConfirmationEmailAdvice`（insertOrder への after-returning、注文番号入り確認メール）が存在する（SendOrderConfirmationEmailAdvice.java:20, 52-72）。現状 `applicationContext.xml` で advisor/bean/mailSender がコメントアウトされ**無効**（applicationContext.xml:80-89, 31-36）だが、codebase 上は注文ドメインの1機能。spec は §2〜§6 で一切触れておらず、backlog-map E3 にも該当 Feature が無い。remoting 層は「デモ層として明示的に捨てる」（order.md:58, F3.5）と方針化されているのに、メール機能は言及すら無く、リビルドで暗黙にドロップ／暗黙に再実装のどちらにも倒れうる。

- **証拠**: SendOrderConfirmationEmailAdvice.java:20,52-72 / applicationContext.xml:80-89 vs order.md（記載なし）, backlog-map.md:21-32（Feature なし）
- **修正提案**: §6 スコープに「注文確認メール＝legacy 同梱・現状 config 無効。スコープ外として明示的にドロップ or 将来 Feature 化」を1行追記し、判断を宙に浮かせない。

### [重大度 中] 業務ルール（誤り）｜ secure 要件 S4 の「数量のみ受理」が注文確定ステップの実入力と一致しない

§5 の S4/R4 行は after 要件を「**数量のみ受理**」とする（order.md:49）。しかし注文確定（newOrder）で client が送るのは支払（ダミー）＋請求先＋配送先＋「別住所配送」フラグであり（NewOrderForm.jsp:11-51, ShippingForm.jsp:12-33）、**数量は注文フォームに存在しない**——数量は cart 段階で確定し、`Order.initOrder`/`LineItem` で cart スナップショットから複製される（Order.java:157-162, LineItem.java:21-27）。したがって「数量のみ受理」は誤り。リビルドが注文確定 API で quantity パラメータを受理する設計を誘発しかねない（本来 quantity は E2 カート側の入力）。

- **証拠**: NewOrderForm.jsp:11-51 / ShippingForm.jsp:12-33 / Order.java:157-162 / LineItem.java:21-27 vs order.md:49
- **修正提案**: S4 行を「サーバが受理する注文入力は**配送先/請求先/支払プレースホルダのみ**。合計・単価・username・数量はサーバ（数量は cart スナップショット）から確定し client 値を信用しない」に修正。

### [重大度 低] エラー分岐（欠落）｜ 主要エラー／例外パスが as-is フローに無い

§2 は正常系＋所有者不一致（order.md:28）と null order（order.md:20）に触れるが、以下の as-is 分岐が欠落: (1) newOrderForm で session に cartForm が無いと「An order could not be created because a cart could not be found.」で failure（NewOrderFormAction.java:24-27）、(2) viewOrder で `orderId` が非数値だと `Integer.parseInt` が NumberFormatException（ViewOrderAction.java:16）、(3) 存在しない orderId（または orderstatus 行欠落）で `getOrder` が null を返し `order.getUsername()` で NPE→スタックトレース露出（ViewOrderAction.java:17-18、S18 と連鎖）。

- **証拠**: NewOrderFormAction.java:24-27 / ViewOrderAction.java:16-18
- **修正提案**: §2 に上記エラーパスを追記。特に (3) は「存在しない/他人の orderId は 404/403 に正規化」を after 要件へ（現状は NPE 500）。

### [重大度 低] 挙動（欠落）｜ 注文確定（状態変更）が GET リンクで発火する

最終確定は `ConfirmOrder.jsp` の `<a href="/shop/newOrder.do?confirmed=true">`（ConfirmOrder.jsp:76）＝**GET ハイパーリンク**で insertOrder＋在庫減算に到達する（NewOrderAction.java:22-29）。§2.1/§F3.2 は「CSRF 対策下で実行」（backlog-map.md:24）とするが、as-is が**状態変更を GET で行う**点が未記載。CSRF ベースライン適用・REST 設計（冪等性・POST 化）の前提情報として欠けている。

- **証拠**: ConfirmOrder.jsp:76 / NewOrderAction.java:22-29 vs backlog-map.md:24
- **修正提案**: §2.1 に「as-is は確定を GET（`newOrder.do?confirmed=true`）で実行」と明記し、after で POST＋CSRF トークン必須へ。

### [重大度 低] 業務ルール（欠落）｜ orderId 採番が非アトミック（select→update、ロックなし）

`SqlMapSequenceDao.getNextId` は sequence を **SELECT してから +1 で UPDATE** する（SqlMapSequenceDao.java:16-26）ため、並行注文で同一 orderId を採番し orders PK 衝突・重複の可能性がある。§3 は「orderId は sequence テーブル採番」（order.md:34）とだけ書き、非アトミック性・並行時の破綻に触れない。F3.2 は「在庫減算と注文永続化のアトミック性」を掲げるが、orderId 割当のアトミック性は射程外。

- **証拠**: SqlMapSequenceDao.java:16-26 vs order.md:34
- **修正提案**: §3 に「as-is の採番は非アトミック（並行で重複採番リスク）」を注記し、after は DB の AUTO_INCREMENT / シーケンス等で原子的採番に置換する旨を F3.2 か基盤（E6）へ。

### [重大度 低] データ（欠落）｜ 金額が `double`、DB は `decimal(10,2)`

`Order.totalPrice` と `LineItem.unitPrice` は **`double`**（Order.java:29,91-92 / LineItem.java:13,40-41,53-55）だが DB は `decimal(10,2)`（schema:86, schema:111）。§5 は「サーバがマスター価格から再計算」とするが数値型に言及がなく（order.md:49）、リビルドが double を踏襲すると丸め誤差が残る。

- **証拠**: Order.java:29,91-92 / LineItem.java:13,40-41 / schema:86,111 vs order.md:49
- **修正提案**: §5 か §6 に「金額は `BigDecimal`/`decimal(10,2)` で扱い double を踏襲しない」を明記。

### [重大度 低] データ形状（欠落）｜ 一覧と詳細で lineItems の取得有無が異なる

`getOrder` は line items を第2クエリで積む（SqlMapOrderDao.java:23-30, LineItem.xml:14-16）が、`getOrdersByUsername` は line items を**積まない**（SqlMapOrderDao.java:19-21）。ListOrders.jsp も orderId/date/totalPrice しか表示しない（ListOrders.jsp:8-15）。§2.2/§2.3・§4 はこの一覧＝サマリ／詳細＝明細付きの差を記さず、REST DTO 設計（一覧レスポンスに明細を含めるか）の判断材料が欠ける。

- **証拠**: SqlMapOrderDao.java:19-30 / ListOrders.jsp:8-15 vs order.md:25-28
- **修正提案**: §2/§4 に「一覧はヘッダのみ（明細なし）、詳細は明細付き」を明記。

### [重大度 低] 画面／挙動（欠落）｜ チェックアウト入口は viewCart と同一 Action でページング処理を持つ

§2.1 step1 は「`/shop/checkout`（`ViewCartAction`）→ Checkout.jsp（確定前のカート確認）」と静的確認画面のように書く（order.md:14）。実際は `checkout` は `viewCart` と同じ `ViewCartAction`（struts-config.xml:27-30, 85-88）で、`page=nextCart/previousCart`（カート）と `page=next/previous`（MyList）のページング分岐を持ち（ViewCartAction.java:12-31）、Checkout.jsp も prev/next リンクを描画する（Checkout.jsp:53-58）。SPA ウィザード置換（F3.1）で、確認画面がカートのページング状態に依存する点が抜けている。

- **証拠**: ViewCartAction.java:12-31 / Checkout.jsp:53-58 / struts-config.xml:27-30 vs order.md:14
- **修正提案**: §2.1 に「checkout は viewCart と同一 Action・カート/MyList のページングを引き継ぐ」を注記（ページング要否は既に §6 論点にあり）。

---

## 総評

order.md は「見本」を名乗るだけあり、正常系ウィザード（checkout→newOrderForm→shipping/confirm→insert）・在庫引当のトランザクション・所有者スコープ・secure-by-default マッピング（S3/S4/S15/S5/S8）といった**幹は概ね押さえている**。粒度も Feature レベルとして妥当。

一方で完全性の観点では、**as-is 挙動の記述精度と、業務ルール／データの網羅に穴がある**。最も重いのは (1) 所有者・本人性チェックを「session 由来」と誤記し実機構（リクエスト再バインドされる ActionForm）を隠している点で、§2 と §5 が自己矛盾し、リビルドが等価移植で S3 を作り込む／一覧の攻撃面を見落とすリスクがある。(2) チェックアウトに在庫 availability チェックが無い（過剰販売可）という基幹業務ルールの欠落は、「挙動等価で残す」対象なのに判断材料が spec に無い。加えて `inventory` テーブル欠落・orderstatus の実挙動（linenum=orderId, 実質1行, inner join 依存）・確認メール機能の完全欠落は、DB 移行（MySQL/Flyway）と E3 Feature 分解の完全性に直接効く。

残る主要リスク: **as-is 記述の正確性（特にセキュリティ機構）を findings と一致させること**、**在庫・確認メール・採番アトミック性・金額型といった "静かに落ちやすい" 挙動を PO 論点として明示すること**。これらを補えば、この spec は behavior-equivalence の基準として十分に機能する。E3 Feature には最低限「在庫 availability 方針」と「確認メールの扱い」の2判断を追加すべき。
