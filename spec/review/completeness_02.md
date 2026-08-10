# spec 敵対的レビュー — レンズ=完全性 (completeness) / round 02（収束）

- **対象**: `spec/behavior/order.md`（改訂）＋ `spec/backlog-map.md`（E3 改訂）＋ `spec/security-baseline.md`（新規）
- **round**: 02
- **日付**: 2026-08-10
- **方針**: round01（`completeness_01.md`）の12指摘を1件ずつ解決判定。改訂で入った新たな穴（記述抜け・矛盾の再発・baseline への丸投げで宙に浮いた項目・トレース切れ）を legacy を一次情報に検出。追認せず、残存/新規のみ列挙。

---

## 1. round01 指摘の解決判定（12件）

| # | round01 指摘 | 判定 | 反映箇所（証拠） |
| --- | --- | --- | --- |
| 1 | [高] 所有者・本人性チェックを「session 由来」と誤記（実は再 populate される form） | **解決** | §2.2 line30・§2.3 line34 で「session の信頼値ではなく毎リクエスト populate される `(AccountActionForm) form`」と訂正、一覧も S3 対象と明記。§5 S3 行が一覧＋詳細を統合 |
| 2 | [高] 在庫 availability チェック無し（過剰販売） | **解決**（ただし後述 N1） | §3 line42「無条件減算・充足/負数ガード無し・過剰販売＝在庫マイナス可」。F3.2・§6 で是正方針 |
| 3 | [中] `inventory` テーブルが §4 に無い | **解決** | §4 line53 に `inventory`(itemid PK, qty)＋「注文4表以外で唯一変更」。file 一覧(line6)にも追加 |
| 4 | [中] `orderstatus` 実挙動（linenum=orderId・timestamp=orderDate・1行・inner join） | **解決** | §3 line43,46・§4 line52 に全て記載（取得0件条件含む） |
| 5 | [中] 注文確認メール欠落 | **解決**（明示的 open decision 化） | §6 論点②・backlog 論点② に「legacy 同梱・config 無効：明示ドロップ or 将来Feature」 |
| 6 | [中] secure要件 S4「数量のみ受理」誤り | **解決** | §5 S4 行を allowlist 化（住所＋支払入力のみ）／数量は E2 工程・確定では受理しない、と訂正 |
| 7 | [低] エラー/例外パス欠落 | **解決** | §2.1 line19(no-cart failure)・§2.3 line35(parseの NumberFormatException／null→NPE→trace)。F3.4 否定ACに反映 |
| 8 | [低] 確定が GET | **解決** | §2.1 line25・§5 S5 行・F3.2「非冪等POST＋CSRF（as-is は GET）」・SBD-3 |
| 9 | [低] orderId 採番が非アトミック | **解決** | §3 line44「select→+1→update・並行重複採番リスク」・§6/F3.2「DB 原子採番」 |
| 10 | [低] 金額 double | **解決**（ただし後述 N2） | §4 line55・§6・SBD-13 |
| 11 | [低] 一覧/詳細の明細取得差 | **解決** | §2.2 line29「一覧=ヘッダのみ・明細なし」・§3 line46「詳細は別クエリで明細」 |
| 12 | [低] checkout=viewCart 同一 Action・ページング | **解決** | §2.1 line18 に明記 |

**round01 の12件は全て解決。** 反映の質・trace ともに高く、各 as-is 穴が「検証可能なアサーション」「否定AC種」「SBD-x」へ正しく落ちている。

---

## 2. 残存／新規の指摘

### [重大度 中] 整合性（矛盾の再発）｜ 過剰販売防止が「決定（変える）」と「判断待ち（PO論点）」で二重管理・状態矛盾

在庫充足チェックの追加が、**決定事項と未決事項の両方**に載っている。§6 line76「変える（モダン化）」に「**在庫充足チェック付き原子的引当**」（＝決定）、F3.2（backlog-map line24）も「**不足なら注文失敗…as-is の過剰販売を是正**」と確定。一方 §6 line77 論点① と backlog line37 論点① は「**過剰販売防止の要否**（as-is は無検証減算）」を**判断待ち**とする。過剰販売の是正は as-is 非等価の**意図的な挙動変更**（F3.6 の支払撤去と同格）なので、「もう決めた」のか「PO/ユーザー判断待ち」なのかが割れていると、PO が Story 化（充足チェック実装）してよいか判断できない。挙動等価が原則の移行で、非等価変更を未サインオフのまま決定扱いにするスコープ齟齬にもなる。

- **証拠**: order.md §6 line76 vs line77①／backlog-map.md line24(F3.2) vs line37①
- **修正提案**: どちらかに寄せる。是正を採るなら論点①を削除し「決定：過剰販売を是正（as-is 非等価・要ユーザー承認）」と1行化。判断を残すなら F3.2/§6 の断定を「候補（PO判断）」に緩める。

### [重大度 低] 整合性（矛盾の再発）｜ 金額 BigDecimal 化が「決定」と「判断待ち」で二重管理

同型の二重管理。§6 line76「変える」に「**金額は `BigDecimal`/`decimal`**」（決定）、かつ **SBD-13**（security-baseline line28）が「`double` を使わない」を**確定 NFR**として持つ。にもかかわらず §6 line77 論点⑥・backlog line37 論点⑥ が「**金額型（BigDecimal 移行）**」を**判断待ち**に残す。SBD-13 で決着済みの事項が open 論点として残存＝stale。

- **証拠**: order.md §6 line76／security-baseline SBD-13 vs order.md §6 line77⑥／backlog-map.md line37⑥
- **修正提案**: 論点⑥を削除（SBD-13 で decided）。金額型は PO 論点ではなく baseline 適用事項である旨を明記。

### [重大度 低] 完全性ギャップ（round01 未指摘の残存穴）｜ 履歴経由の注文詳細は明細の商品名/説明が空（LineItem.item 未ロード）

`getOrder` の明細取得 `getLineItemsByOrderId` は `orderid,linenum,itemid,quantity,unitprice` **のみ**を select し、`Item`（商品名/attribute）を join しない（LineItem.xml:14-16, resultMap は item を持たない）。よって履歴→`viewOrder` で表示する明細は `LineItem.item == null`。`ViewOrder.jsp:112-117` は `${lineItem.item.attribute1}` … `product.name` を描画するため、**注文詳細画面では商品説明列が空**になる。一方、**注文直後の Thank-you 画面**は insert 前のメモリ上 `order`（cart 由来で item 充足、`Order.java:157-162`/`LineItem.java:26`）を使うため説明が表示される。この「同じ ViewOrder.jsp でも入口で明細の中身が違う」as-is 差が spec に無い。REST の order-detail DTO が商品名/説明を返すか（as-is は返さない＝空）を決める材料が欠落。

- **証拠**: LineItem.xml:6-16 / SqlMapOrderDao.java:23-30 / ViewOrder.jsp:112-117 vs order.md §2.3, §3 line46
- **修正提案**: §2.3 か §3 に「履歴経由 detail は明細に商品名/説明を含まない（item 未ロード＝画面上は空）／Thank-you 画面のみ充足」を注記。after で detail に商品名を含める（as-is 非等価の改善）か等価維持かを §6 論点か F3.4 に。

### [重大度 低] トレース｜ order.md §5 が security-baseline を SBD-ID でなく散文で参照

§5 の各行は「security-baseline の横断NFR」「一般NFRへ格上げ、security-baseline」と**散文**で受け皿を指すが、**SBD-1/2/3/8 等の ID を明示していない**。対応は記述から一意に追えるものの、bidirectional trace の検証が手作業になり、baseline 改番時に切れやすい。

- **証拠**: order.md §5 line63-67（"security-baseline" と記すが ID 無し）vs security-baseline SBD-1〜SBD-15
- **修正提案**: §5 各行末に対応 SBD-ID を併記（例: S3→SBD-1、S4→SBD-2、S5→SBD-3、列挙→SBD-8）。低コストで trace 切れを予防。

---

## 3. 収束判定

**判定: converged（Phase 3 の入力として十分）。** もう1周のフル敵対レビューは不要。

- round01 の12指摘は**全件解決**、しかも as-is 穴 → 検証可能アサーション → 否定AC種 → SBD-x の縦の trace が通っており、spec としての完成度は Phase 2 見本として合格水準。
- 残る4件は **behavior/データの新規欠落ではなく、主に "決定 vs 判断待ち" の二重管理（N1/N2）と、軽微な残存注記（N3）・trace 表記（N4）**。いずれも Phase 3 実装の前提を覆すものではない。
- ただし **N1（過剰販売の決定状態矛盾）は Phase 3 着手前に PO/ユーザーで decided/open を確定すること**を条件に付す（是正は as-is 非等価のため）。N2/N4 は編集レベル、N3 は F3.4 詳細化時に PO が拾えば足りる。

> 総じて、この spec は「1発で100点は取れない」前提を2周で潰し切れており、残課題は編集・意思決定の明確化に収れんしている。Phase 3 へ進めてよい（N1 の decided/open 確定を並行タスクとする）。
