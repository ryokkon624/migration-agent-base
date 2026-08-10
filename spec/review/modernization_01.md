# spec 敵対的レビュー — レンズ=モダン化整合 (modernization)

- **対象**: `spec/behavior/order.md`（特に §5 secure-by-default 表・§6 スコープ）＋ `spec/backlog-map.md`（E3 注文）
- **round**: 01
- **日付**: 2026-08-10
- **観点**: before findings（`reports/before/baseline-summary.md`）が secure-by-default な要件/AC に**正しく変換**されているか。捨てる/残すスコープの妥当性、抜けている NFR、Factory 方針（挙動等価＋モダン＋セキュア）との齟齬、宣言止まりで検証不能な箇所。
- **凡例**: `[重大度] カテゴリ ｜ 内容 ｜ 証拠 ｜ 修正提案`

---

## 指摘リスト

### [高] IDOR射程漏れ / 認可の実施層 ｜ `listOrders` の identity-rebind IDOR が spec に落ちていない（S3 の射程が「詳細閲覧」だけに矮小化）

- **内容**: §5 の S3 行は「所有者判定の元がフォーム束縛可能」を**注文詳細（ViewOrder）の owner-check だけ**の話として書いている。しかし一覧側 `ListOrdersAction` も同じ穴を持つ。struts-config で `/shop/listOrders` は `name="accountForm" scope="session"`、`/shop/viewOrder` も同じ `accountForm`。Struts は毎リクエストこのセッション form を request パラメータで populate するため、`listOrders.do?account.username=victim` で**他人の注文履歴を一括取得**でき、同時にセッションの `accountForm.account.username` が汚染される（S3 の「セッション属性を同一リクエストで差し替え」そのもの）。一覧は PII＋注文履歴の**バルク**開示で、詳細1件より被害が大きい。F3.3 は「本人スコープ」とだけ書き、§2.2 は「セッションのユーザー名で」と**安全そうに**誤記しているため、この経路が secure 要件から漏れる。
- **証拠**: `ListOrdersAction.java:13-14`（`acctForm.getAccount().getUsername()` を認可元に使用）／`struts-config.xml:43-46`（listOrders = accountForm/session）・`:97-100`（viewOrder = accountForm/session）／before S3（identity-rebind IDOR）・S15/R2（getOrder 認可不在）。
- **修正提案**: §5 S3 行の要件を「注文詳細・一覧の**双方**」に明示適用。かつ「**認可はサービス/ドメイン層で、呼び出しチャネル非依存に強制**（controller/form ではなく認証プリンシパル基準）」を S15 行のローカル要件から**一般 NFR に格上げ**し、F3.3/F3.4 の両方にひも付ける（レガシーの根本欠陥は「認可が Web 層にしか無い」こと。REST 化後も同じ轍を踏ませない）。F3.3 用の否定 AC 種（`listOrders?username=他人 → 自分の履歴のみ`）を追加。

### [高] as-is 記述の誤り（内部矛盾） ｜ §2.2/§2.3 が脆弱性メカニズムを「session username」と誤記し、§5 と矛盾。壊れた AC を生む恐れ

- **内容**: §2.3 は owner-check を「`session.account.username == order.username`」、§2.2 は一覧を「セッションのユーザー名で `getOrdersByUsername`」と記す。実際の認可元は**セッションではなく、リクエストで populate される form 束縛の `accountForm.account.username`**。§5 の S3 行は正しく「フォーム束縛可能」と書いており、**同一 spec 内で as-is 記述（§2）と secure 表（§5）が矛盾**している。この見本を入力に AC を書く担当が §2 だけ読むと「レガシーは既にセッション username で判定している＝軽微」と誤解し、「セッション username と order.username を比較する」という**現行の壊れた挙動を再実装する AC** を書きうる。セキュリティ上クリティカルな機構の内部矛盾なので高。
- **証拠**: `ViewOrderAction.java:15,18`（`AccountActionForm acctForm = (AccountActionForm) form;` → `acctForm.getAccount().getUsername().equals(order.getUsername())`。`form` はマッピングの session form で毎リクエスト再 populate される）／order.md §2.3・§2.2 と §5 S3 行の記述差。
- **修正提案**: §2.2/§2.3 の as-is を「認可元は**リクエストで再束縛可能な** form 属性（＝so 脆弱）」と正確に書き換え、§5 と整合させる。as-is が「なぜ壊れているか」を正しく描くことで、secure 要件が「認証プリンシパルは**リクエストから populate しない**」という**検証可能な差分**に落ちる。

### [中] Factory方針齟齬 / マスアサインメント要件の過剰簡略化 ｜ 「数量のみ受理」は挙動等価を壊し、正当な入力（配送/請求先）を落とす

- **内容**: §5 S4/R4 行の secure 要件が「**数量のみ受理**」。しかしレガシーの注文確定は、配送先/請求先住所・「別住所へ配送」・カード（プレースホルダ）欄を**正規にユーザーから受け取る**（`OrderActionForm.doValidate` が必須検証）。「数量のみ受理」に文字通り従うと**別配送先入力という挙動が消える**（挙動等価の毀損）。加えて数量は本来**カート工程**（updateCartQuantities）で確定するもので、注文確定エンドポイントの入力ではない。要件の言い回しが不正確。
- **証拠**: `OrderActionForm.java:57-79`（配送/請求先・カード各項目を必須検証＝正規入力）／`NewOrderFormAction.java:20-21`＋`Order.java:126-162`（住所はアカウントからプリフィルだが上書き可能）／§6「配送先入力」を残すと明記。
- **修正提案**: 「数量のみ受理」を撤回し、**クライアント編集可フィールドの allowlist**として再定義：受理＝ship/bill 住所・別配送フラグ・支払プレースホルダ入力のみ。**サーバ権威（クライアント値を無視）＝ `username`（認証プリンシパル）・`unitPrice`・`totalPrice`・`itemId`・`linenum`・`orderDate`・`status`**。この allowlist/denylist を否定 AC 種にする（例: `order.totalPrice=0.01` 改ざん → 永続値はサーバ再計算合計）。

### [中] 横断NFRの受け皿が存在しない ｜ `security-baseline.md` 未作成で CSRF/セッション再生成が宙に浮く（宣言止まり）

- **内容**: §5 の S5/S8 行と backlog-map（2 箇所）が `spec/security-baseline.md` に横断 NFR（CSRF 対策・ログイン時セッション再生成、および本レビューで求める監査等）を委譲しているが、**当該ファイルは存在しない**。受け皿が無いため、これらの secure 要件は「宣言」のままで**検証可能な AC の種にならない**。E3 の見本としては、参照先が空だと横断要件のトレースが切れる。
- **証拠**: `Glob spec/**` に `security-baseline.md` なし（現存は order.md / backlog-map.md / README のみ）／order.md §5「横断NFR（`security-baseline.md`）」・backlog-map.md 冒頭と E6 の 2 参照。
- **修正提案**: E6 で `security-baseline.md` を先行作成し、各 NFR を**検証可能な文**で定義（例: 「状態変更は CSRF トークン必須・Origin/SameSite 検証」「サインオン成功時に session id を再生成」）。または当面 order.md §5 に具体アサーションをインライン化し、後で baseline に集約。順序依存（baseline が Story/AC の前提）を backlog-map に明記。

### [中] 抜けているNFR（enumeration対策） ｜ 認可修正後も残る「連番 orderId ＋ 弁別メッセージ」の列挙オラクル

- **内容**: §4 の通り `orderId` は `sequence` テーブルの**連番**。ViewOrder は他人の既存注文には「You may only view your own orders.」、不存在には別のエラー、と**応答が弁別可能**。IDOR 自体を認可で塞いでも、連番 ID は**注文総量の漏洩**と**存在推測（enumeration）**を許し、弁別応答が oracle になる。secure-by-default のモダン化としては要件化すべきだが §5 に無い。
- **証拠**: order.md §4（`sequence` で orderId 採番）／`ViewOrderAction.java:16,23`（`orderId` を素の連番前提でパース、not-owned/失敗で弁別メッセージ）／`Order.xml:35-44`（getOrder は orderid 直参照）。
- **修正提案**: §5 に NFR 追加「注文の外部識別子は**非連番/不透明**（UUID 等）にする、**または** not-owned と not-found を**同一 403/404 応答**に統一して存在オラクルを消す」。F3.4 の AC 種に「他人 ID と存在しない ID の応答が区別不能」を入れる。

### [低] 抜けているNFR（整合性） ｜ 在庫充足チェック不在（無条件減算 → 在庫マイナス/oversell）

- **内容**: 注文確定の在庫引当は**無条件の減算**で、数量充足の検証が無い（同時実行/多重確定で在庫マイナス＝oversell）。§3・F3.2 は「1トランザクション（原子性）」までは要求するが、**充足検証**は未要求。before finding 由来ではないが、モダン化で secure/correct-by-default として足すべき整合性 NFR。
- **証拠**: `Item.xml:72-74`（`update inventory set qty = qty - #increment#`、`qty >= #increment#` ガード無し）／`PetStoreImpl.java:147-150`（insertOrder が無条件 updateQuantity）。
- **修正提案**: F3.2 に「在庫は**充足チェック付きで原子的に**引当（不足なら注文失敗、負数化させない）」を追加。before 派生ではない旨を注記し過大評価を避ける。

### [低] 抜けているNFR（監査） ｜ 認可失敗・注文確定の監査ログが要件化されていない

- **内容**: IDOR 多発の before と Phase 4 回帰テスト方針（「無認証 getOrder が 401/403」「他人注文が 403」を自動検証）を踏まえると、**認可拒否イベント（viewOrder/listOrders の他人アクセス試行）と注文状態変更**の監査ログは secure-by-default の妥当な追加。§5・backlog-map に監査 NFR が無い（タスクが例示する「監査」）。
- **証拠**: baseline §6（Phase 4 で 403 化を自動検証）／order.md §5・backlog-map に監査記述なし。
- **修正提案**: `security-baseline.md`（上記 [中]）側に横断 NFR として「認可失敗と注文作成を監査ログに記録（誰が/何を/結果）」を定義し、F3.2/F3.4 の AC からトレース。

### [低] 支払プレースホルダの検証不能 ｜ 「実カードを保存しない/プレースホルダ維持」が具体化されておらず AC 化できない

- **内容**: §5（情報行）と F3.6 は「実カード番号は保存しない／スコープ外・プレースホルダを維持」と宣言するのみ。レガシーは `orders.creditcard/exprdate/cardtype` 列を**実際に永続化**し、`doValidate` はカード欄を**必須**にしている。モダン化で (a) 列を削除するのか、(b) 固定リテラルにするのか、(c) UI/API からカード入力を除くのか、(d) カード必須バリデーションを廃止するのか、が未定義＝挙動差分が検証不能。
- **証拠**: `Order.xml:57-59`（creditcard/exprdate/cardtype を insert）／`OrderActionForm.java:60-62`（カード欄必須）／`Order.java:150-152`（ダミー既定値をハードコード）。
- **修正提案**: F3.6 を具体化「カード列は**保持しない**（DTO/API/DB から除外）、カード入力欄と必須バリデーションも撤去、支払は明示的プレースホルダ状態」等、検証可能な形に。挙動等価をあえて外す**意図的な変更**である旨を Factory 方針として明記。

### [低] クロスEpic依存の未明示 ｜ S2（editAccount 乗っ取り）の注文ドメインへの波及が前提として書かれていない

- **内容**: 注文ドメインの認可は「認証プリンシパルの完全性」に依存する。S2（editAccount のマスアサインメントで他人アカウント上書き＋PW リセット）で**アカウント自体が乗っ取られる**と、攻撃者は victim として**正規に**注文を閲覧でき、order 側の認可強化だけでは防げない。order.md はこの**クロス Epic 依存**（E4 の editAccount 修正・E5 の認証完全性が前提）を明示していない。
- **証拠**: before S2（editAccount 乗っ取り、R3/S2）／order.md §5 は S3 を扱うが S2 波及・プリンシパル完全性の前提に言及なし。
- **修正提案**: §5 か F3.3/F3.4 に依存注記を追加「本ドメインの認可は**認証プリンシパルの不変性・完全性**（E5/E4/`security-baseline.md` が保証）に依存する」。order 側だけで完結しない旨をトレースに残す。

---

## 総評

E3 見本は骨格として妥当で、看板 finding（S4/R4 価格・名義マスアサインメント、S15/R2 remoting getOrder IDOR、S5/S8 横断）は §5 に拾えており、remoting/WS 撤廃（F3.5）と「認可はサービス層で」という**モダン化の核**も押さえている。**確認して問題なかった点**として、`OrderService.java:20` は `getOrder(int)` のみを宣言しており、§6 の「捨てる＝OrderService.getOrder（S13-15）」という命名は過大でも過小でもない（remoting は getOrder 単一面）。

一方で、**認可の射程**に穴がある。最重要は (1) `listOrders` が viewOrder と同じ identity-rebind IDOR を持つのに secure 要件が詳細閲覧だけに矮小化していること、(2) §2 の as-is 記述が機構を「session username」と誤記して §5 と矛盾し、**壊れた AC を再生産しかねない**こと。この 2 点は「見本」が下流（PO の Story/AC・Phase 4 回帰）を誤誘導するため高とした。加えて (3) 「数量のみ受理」は挙動等価を壊す言い回しで、編集可フィールドの allowlist に直すべき。横断 NFR は受け皿の `security-baseline.md` が未作成で宣言が宙に浮いており（enumeration 対策・監査も含め）、secure 要件を**検証可能なアサーション**へ落とす作業がまだ残っている。

総じて「rubber-stamp 不可・要改訂」。特に §5 表に「before PoC → after 期待アサーション」列を足し、baseline の Top3（無認証 getOrder→401/403、他人注文→403）を各要件のトレースに結び付ければ、Phase 4 の回帰テスト種として機能する。

**指摘件数**: 9 件（高 2 / 中 3 / 低 4）
