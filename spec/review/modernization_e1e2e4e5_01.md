# spec 敵対的レビュー — レンズ=モダン化整合 (modernization) / E1・E2・E4・E5 round 01

- **対象**: `spec/behavior/{catalog,cart,account,auth}.md`＋ `spec/backlog-map.md`（E1/E2/E4/E5 節）
- **突合基準**: `reports/before/baseline-summary.md`（findings 一次ソース）＋ `spec/security-baseline.md`（SBD-1〜18）
- **日付**: 2026-08-10
- **観点**: before findings（特に E4/E5＝S2/S3/S6/S7/S8/S9/S10/S11/S12）が secure-by-default 要件/AC に漏れなく変換されているか。SBD 紐付けの正確性、clean 維持系（SBD-17/18）の要件化、捨てる/残すスコープ、Factory 方針齟齬、宣言止まりで検証不能な箇所。
- **凡例**: `[重大度] カテゴリ ｜ 内容 ｜ 証拠 ｜ 修正提案`

---

## 0. 新規 as-is 証拠の原典照合（rubber-stamp 回避）

4 spec の主要な証拠引用を原典で確認。**すべて一致・捏造/誇張なし**：

- ✅ **S2 editAccount 乗っ取り**（account）: `EditAccountAction.java:16,20-21`（`account=(form).getAccount()`＝username フォーム束縛→`updateAccount(account)`）＋ `Account.xml:83-85`（`update account … where userid=#username#`）＋ `SqlMapAccountDao.java:45-51`（updateAccount→updateProfile→**password 非空なら updateSignon**）＋ `Account.xml:99-101`（`update signon set password=#password# where username=#username#`）。**他人行の更新＋条件付き PW リセットが成立**。account.md の記述は正確。
- ✅ **newAccount は乗っ取り不可**（account §5 の校正）: `NewAccountAction.java:22`（`insertAccount`）＋ `Account.xml:87-89`（account PK=userid への insert）→ 既存 username は PK 衝突で失敗。「乗っ取りベクトルは editAccount」の校正は妥当（過大評価していない）。
- ✅ **S7 平文比較 / clean 一律メッセージ / S8 / S9 / S10 / S11**（auth）: `getAccountByUsernameAndPassword`＝`signon.password=#password#` 直接比較（`Account.xml:52-77`）／`SignonAction.java:27-28` 成否一律メッセージ／`:33-40` 新 form 生成のみで**session 再生成なし**（S8）／`:45` `sendRedirect(forwardAction)` 無検証（S9・成功時のみ発火）／`SignonForm.jsp:20,24` **j2ee/j2ee プリフィル**（S10）／`:24-25` `getParameter` はメソッド非依存（S11）。全一致。
- ✅ **cart clean**（cart）: `Cart.java:70-81` `getSubTotal=Σ(item.getListPrice()×qty)`＝価格サーバ権威／`UpdateCartQuantitiesAction.java:21-31` **リクエストパラメータ名＝itemId** を数量に、`<1` で削除、`NumberFormatException` 握り潰し。全一致。
- ✅ **catalog XSS seam**（catalog）: `Item.jsp:16` / `SearchProducts.jsp:14` = `<c:out value="${product.description}" escapeXml="false"/>`（**description のみ** escape 無効・name 等は既定エスケープ）。DB シード由来・管理 UI 無し（THREAT_MODEL）で書込経路なし＝Latent という校正は妥当。

→ 事実関係は堅い。以下は**変換の抜け/齟齬**に絞る。

---

## E1 カタログ（catalog.md）

before で clean（SQLi/反射XSS 無）。読み取り専用・全公開の整理は正確で、CSRF 行が無いのも正しい（状態変更なし）。

### [中] Factory方針齟齬 / XSS要件の過剰一般化 ｜ `product.description` は legacy が意図的に HTML レンダリングしており、「全出力エスケープ」は挙動を壊す（sanitize か plaintext かの判断が要る）

- **内容**: §5 の SBD-18 行は「全出力を文脈エスケープ（escape を無効化しない）。商品名/**説明**/検索語エコーを含む」。しかし legacy は `product.description` を**意図的に** `escapeXml="false"` で出力＝**説明文に HTML（画像タグ等）を埋め込んで描画する仕様**。モダン側で説明を一律エスケープすると**リッチ表示という挙動が消える**（挙動等価の毀損）。逆に HTML を残すなら**サニタイズ（許可タグ allowlist）**が必要で、SBD-18 の「エスケープ」だけでは XSS を塞げない。要件が二者択一を曖昧にしたまま。
- **証拠**: `Item.jsp:16` / `SearchProducts.jsp:14`（description に `escapeXml="false"`。name/ID は既定エスケープ）／catalog.md §5 SBD-18 行。
- **修正提案**: description の扱いを明示決定し検証可能化：(a) **plaintext 化してエスケープ**（＝リッチ HTML 廃止・意図的非等価変更として明記）、または (b) **HTML を許可するがサーバでサニタイズ**（許可タグ/属性 allowlist）。後者を採るなら SBD-18 に「信頼できないリッチテキストはサニタイズ（生 HTML を無検証出力しない）」を追補。否定AC種: `description=<script>…` → 実行されない・かつ (a)/(b) の期待描画。

### [低] トレーサビリティ ｜ 「L1 格納XSS」ID が curated baseline から辿れない（seam 自体は原典で確認済）

- **内容**: §5 が before として「**L1** 格納XSS の seam」を挙げるが、`baseline-summary.md` は run_01 の "Latent 2" を件数で記すのみで **L1 の内容/ID を明示していない**。seam（escapeXml=false）は原典で確認できるが、finding ID の参照が宙に浮く。
- **証拠**: baseline-summary §1（run_01 "＋Latent 2"）に L1 の記載なし／catalog.md §5「L1 格納XSS の seam」。
- **修正提案**: 「L1」表記を `Item.jsp:16`/`SearchProducts.jsp:14`（file:line）＋SBD-18 直参照に置換、または baseline 側の Latent 明細を curated に一行追加して ID を実在させる。

---

## E2 カート（cart.md）

before で clean（価格サーバ権威・数量のみ受理）。CSRF（SBD-3）・在庫整合の E3 委譲・「param 名=itemId の暗黙規約を明示 {itemId,quantity} へ」は的確。**中以上の指摘なし。**

### [低] 挙動等価の明示 ｜ 新 `{itemId, quantity}` API の削除セマンティクスを定義しないと as-is 挙動（数量<1 で行削除）が落ちる

- **内容**: as-is は `updateCartQuantities` で数量 `<1` を**行削除**として扱う（`UpdateCartQuantitiesAction.java:25-26`）。§5/§6・F2.1 は「0で削除」と括弧書きするが、明示 REST 化に際し **quantity=0（or 負）→ 削除**という規約を AC 化しないと、正整数バリデーション（§5「正の整数として検証」）と**衝突**して削除経路が失われうる。
- **証拠**: `UpdateCartQuantitiesAction.java:23-27`／cart.md §5「数量は正の整数として検証（as-is は `<1` で削除・非数値無視）」・F2.1「（0で削除）」。
- **修正提案**: 「数量 API は正整数のみ受理、**削除は明示 DELETE（または quantity=0 を削除と定義）**」と規約を分離し検証可能化。

---

## E4 アカウント（account.md）  ※before findings 集中・重点

S2/S3/S6/S7/S12 の変換は概ね良好（F4.2 の否定AC種 `account.username=他人 → 自分のみ` は的確、SBD-16 で S6 も接続）。ただし **CSRF の接続漏れ**が重い。

### [中] before findings 変換漏れ ｜ 状態変更（newAccount/editAccount/PW変更）に CSRF（SBD-3）が接続されていない — Top3 攻撃連鎖 #3 の一角

- **内容**: account.md §5 には **CSRF 行が無く**、F4.1/F4.2/F4.3 も CSRF に言及しない。しかし newAccount/editAccount は状態変更で、baseline S5/R6「CSRF 全域で不在」の対象（THREAT_MODEL も `editAccount`/`newAccount` を CSRF 対象アクションに明記）。かつ baseline Top3 #3＝「**CSRF 駆動の遠隔乗っ取り（S5＋S2＋S6）**」で、**editAccount への CSRF は看板攻撃連鎖の起点**。order.md §5・auth.md §5 は CSRF 行を持つのに account だけ欠落＝一貫性のある接続漏れ。
- **証拠**: account.md §5（CSRF 行なし）・F4.1-4.3／baseline-summary §2「CSRF 全域で不在（R6/S5）」・§5 Top3 #3／THREAT_MODEL §「状態変更 Struts アクション（… editAccount / newAccount）」。
- **修正提案**: §5 に S5/SBD-3 行を追加し、F4.2/F4.3（および F4.1）に「状態変更は CSRF トークン必須・非冪等 POST」を接続。否定AC種: 外部オリジンからの editAccount → 拒否。

### [低] before findings 変換漏れ ｜ 登録直後の自動ログインにセッション再生成（SBD-4/S8）が適用されていない

- **内容**: `NewAccountAction.java:27` は登録後に session へ `accountForm` をセット＝**自動ログイン**するが、session 再生成をしない（=S8 セッション固定の同型）。auth.md F5.1 は「ログイン成功時」だけを対象にし、**登録経由の権限遷移**が漏れる。
- **証拠**: `NewAccountAction.java:22-27`（insert→session セット、再生成なし）／auth.md F5.1・SBD-4（対象がログインに限定）。
- **修正提案**: SBD-4 を「**認証状態が確立する全遷移（ログイン＋登録自動ログイン）**でセッション再生成」に一般化し、F4.1 から接続。

### [低] 検証可能性 ｜ 「登録の応答を列挙不能に（一律メッセージ）」は登録では非現実的で AC 化できない

- **内容**: §5 S12 行＋SBD-6 は「登録含む 一律メッセージで列挙不可」とするが、**登録は username 重複を利用者に伝える必要**があり「一律メッセージ」は成立しにくい（PK 衝突＝重複は本質的に露出）。宣言のままでは検証可能な AC にならない。
- **証拠**: account.md §5 S12 行「登録の応答を列挙不能に（or レート制限）」／SBD-6「一律メッセージ（… 登録含む）」。
- **修正提案**: 登録の列挙対策は「**レート制限＋（採用時）メール検証**で総当り列挙を抑止」と現実的に再定義し、"一律メッセージ" はログイン系に限定。否定AC種: 短時間の大量登録試行 → レート制限で遮断。

> 補足（低・任意）: §5 の「S3 identity-rebind」行は、account ドメインでは実体として **S2 と同じ form 束縛 username が更新対象を決める**根であり、S3 の正準位置（order の viewOrder/listOrders 認可）とは異なる。是正（SBD-1/プリンシパル基準）は共通なので害はないが、トレース精度としては「S2 と同根」と注記すると混乱が減る。

---

## E5 認証（auth.md）

**残指摘なし（converged）。** S7/S8/S9/S10/S11/S5 と clean 維持（一律メッセージ・SQLi）がそれぞれ SBD-5/4/9/6/6/3 と SBD-6/17 に正確に接続され、否定AC の芽（DB に平文なし・GET 認証不可・`forwardAction=//evil` 遮断・login 前後で session id 変化）も妥当。「本ドメインが全 Epic 認可の土台（identity 完全性）」の位置付けと SBD-1 一体化も適切。sendRedirect が成功時のみ発火＝影響限定という校正も過大でない。ログアウト（`signon.do?signoff`＝GET）も §5 CSRF 行「ログアウト含む」で拾えている。

---

## 総評・収束判定

4 spec とも as-is 忠実度が高く（原典照合で全一致）、before→SBD の変換は大半が正確。**auth（E5）は converged、cart（E2）は実質 converged**。焦点の E4/E5 では **E5 は穴なし**、**E4 は CSRF 接続漏れ（中）が実質的**で、これが Top3 攻撃連鎖 #3 の起点に直結するため 1 点だけ確実に潰す価値がある。catalog（E1）は description のリッチ HTML 挙動と「全エスケープ」要件の齟齬（中）を sanitize/plaintext のどちらかに確定すれば締まる。

- **catalog (E1)**: 中1・低1 → **1 ラウンドで収束見込み**（description 方針確定＋トレース修正）。
- **cart (E2)**: 低1 → **収束（軽微追補のみ）**。
- **account (E4)**: 中1・低2 → **CSRF 追加が実質的、1 ラウンド追加が妥当**。
- **auth (E5)**: **収束（残指摘なし）**。

いずれも**ドメイン spec の作り直しは不要**、§5 表と Feature への追補パッチ＋（catalog は）SBD-18 への一文追加で閉じられる。フル追加ラウンドは E4/E1 の差分確認で足りる。

**残指摘: 6 件（中 2 / 低 4）。ドメイン別 — catalog 2 / cart 1 / account 3 / auth 0。**
