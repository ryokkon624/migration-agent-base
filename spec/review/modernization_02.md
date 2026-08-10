# spec 敵対的レビュー — レンズ=モダン化整合 (modernization) / round 02（収束再レビュー）

- **対象**: `spec/behavior/order.md`（改訂）＋ `spec/backlog-map.md`（E3 改訂）＋ `spec/security-baseline.md`（★新規）
- **round**: 02
- **日付**: 2026-08-10
- **観点**: round01 指摘（`modernization_01.md`）の解決状況を1件ずつ判定＋新規 `security-baseline.md` の妥当性（before 紐付け・検証可能性・過大/抜け）を精査。追認せず、新規証拠も原典照合した。

---

## 0. 新規に追加された as-is 証拠の照合結果（rubber-stamp 回避のため原典を再確認）

改訂で spec は as-is 記述を大幅に精緻化した。**新規の証拠引用はすべて原典と一致**：

- ✅ **確定は GET リンク**（S5 の核心・§2.1/§5/SBD-3 が依拠）: `ConfirmOrder.jsp:76` = `<a href="…/shop/newOrder.do?confirmed=true">…` ＝ **insert＋在庫減算が GET で成立**。正確。
- ✅ **unitPrice = マスター価格**: `LineItem.java:25` = `this.unitPrice = cartItem.getItem().getListPrice();`。§3 の「"カート単価" という独立概念はない／listPrice を取り込む」は正確（round01 の私の曖昧点を spec 側が正しく解消）。
- ✅ **在庫無条件減算・充足チェック無し**: `Item.xml:72-74`＋`PetStoreImpl.insertOrder:147-150`。`isItemInStock` は存在するが確定パス未使用。正確。
- ✅ **sequence 非アトミック**: `SqlMapSequenceDao.java:16-26`（select→+1→update→旧値 return）。正確。
- ✅ **DAO 形状**: `SqlMapOrderDao.java` — insertOrder が orderstatus＋lineItem を反復 insert（:32-41）、getOrder は別クエリで明細ロード（:23-30）、getOrdersByUsername は明細を積まない（:19-21）。§2.2/§3 と一致。
- ✅ **checkout 公開＋ページング**: `ViewCartAction.java:10`（`BaseAction` 継承＝未認証到達）・`:15-29`（page=next/previous/nextCart/previousCart）。§1/§2.1 と一致。THREAT_MODEL 上カート/閲覧の公開は正常＝finding にしない校正も妥当。

→ 新規記述に**捏造・誇張は無し**。むしろ as-is の忠実度が上がっている。

---

## 1. round01 指摘の解決判定（9件）

| # | round01 指摘 | 判定 | 反映箇所 |
| --- | --- | --- | --- |
| R01-1 [高] listOrders IDOR 射程漏れ | **解決** | §2.2 ⚠callout・§5 S3 行「一覧・詳細の双方／一覧にも適用」・F3.3「一覧も identity-rebind 対象」＋否定AC種・SBD-1 |
| R01-2 [高] §2.2/§2.3 as-is 機構誤記（session と誤記） | **解決** | §2.2/§2.3 を「毎リクエスト再 populate される form」と正確化し §5 と整合 |
| R01-3 [中] S4「数量のみ受理」過剰簡略化 | **解決** | §5 S4 行を allowlist（住所/別配送/支払）× サーバ権威（username/unitPrice/totalPrice/itemId/linenum/orderDate/status）に再定義。数量は E2 工程と明記。SBD-2 |
| R01-4 [中] security-baseline 未作成 | **解決** | `security-baseline.md` 新規作成（SBD-1〜15）。order.md/backlog-map から参照 |
| R01-5 [中] 列挙オラクル | **解決** | §5「（新規NFR）列挙オラクル」・F3.4 否定AC種・SBD-8 |
| R01-6 [低] 在庫充足 NFR | **解決** | §3 ⚠callout・§6・F3.2「充足チェック付き原子的引当」＋否定AC種・PO論点① |
| R01-7 [低] 監査ログ NFR | **解決** | SBD-14（非before と明記） |
| R01-8 [低] 支払プレースホルダ検証不能 | **解決** | §5 情報行・F3.6「カード列/入力欄/必須バリデーション撤去・意図的非等価変更」 |
| R01-9 [低] S2 クロスEpic依存 未明示 | **解決** | §5「クロスEpic依存」段落（S2→order 認可は E4/E5/baseline 前提） |

**round01 は 9/9 解決。** 部分解決・未解決は無し。

---

## 2. 新規 `security-baseline.md` の精査（before 紐付け・検証可能性・過大/抜け）

**良い点**: SBD-1〜15 は「検証可能なアサーション＋before 由来＋Phase4 回帰の種」の3列で書かれ、before の finding ID と概ね正しく対応。過大評価回避の脚注（SBD-8/14 は非before）も適切。ID マッピングは大半が正確（S7→SBD-5、S9/R11→SBD-9、S17/R15→SBD-11、S20/R12・S21/R17→SBD-12 等）。

**残る問題は以下の 2 中・2 低（＝ order.md 本体ではなく横断NFR台帳の網羅性/整合）。**

---

## 3. 残存・新規の指摘（modernization レンズ）

### [中] 抜けているbefore finding ｜ S6「現在パスワード未確認でパスワード変更（＝機微変更の再認証欠如）」がどの SBD にもマップされていない

- **内容**: baseline は S6「現在パスワード未確認でパスワード変更」を確定 finding とし、**Top3 攻撃連鎖 #2（S3→S2→S6）**の一角に据えている。しかし SBD-5 は保存方式（ハッシュ）、SBD-6 はブルートフォース/列挙/GET資格情報で、**「機微変更（パスワード/メール変更等）に現在パスワード再確認・再認証（step-up）を要する」という制御が SBD に無い**。E4/E5 の Story がこの NFR を AC 化する拠り所を失う。
- **証拠**: baseline-summary §2「現在パスワード未確認でパスワード変更（S6）：CSRF・マスアサインと連鎖で遠隔乗っ取り」・§5 Top3 #2（S3→S2→S6）／security-baseline SBD-1〜15 に該当なし。
- **修正提案**: SBD 追加（例 SBD-16「機微変更の再認証：パスワード/メール等の変更は**現在パスワード再確認 or 再認証**を必須」）または SBD-6 を拡張。before 由来=S6、Phase4 種=「現在PW無しの変更が失敗」。

### [中] 抜けているNFR ｜ 「維持すべき clean 姿勢」＝SQLi パラメタライズ／XSS 出力エスケープの NFR が SBD に無い

- **内容**: baseline は SQLi・反射XSS を **clean（before の基準線）**とし、after で「**維持**」・Phase4 で確認する対象と明記。security-baseline は「消す」findings は網羅するが、**維持系（インジェクション対策・出力エンコーディング）の NFR が無い**。secure-by-default 台帳として、パラメタライズ SQL と文脈依存エスケープを NFR 化しないと、Phase4 で「clean が保たれた」ことを検証する種が存在しない（モダン化で MyBatis/Vue に載せ替える際の退行防止にも要る）。
- **証拠**: baseline-summary §4「SQLインジェクション無し／反射XSS無し（＝before の基準線・after で"維持"を確認）」・§6「パラメタライズ SQL 継続・出力エスケープ」／security-baseline に該当 SBD なし。
- **修正提案**: SBD 追加（例「インジェクション/出力対策：SQL は全面パラメタライズ、出力は文脈依存エスケープ。before clean 姿勢を**維持**」）。before 由来=baseline §4/§6（maintain）、Phase4 種=「代表 SQLi/XSS ペイロードが無害化」。非before の"消す"ではなく"維持"である旨を明示（過大評価回避）。

### [低] before 引用の誤記＋重複 ｜ SBD-4 の「S16/R16」は誤り、cookie フラグ要件が SBD-4/SBD-15 で二重化

- **内容**: SBD-4（セッション管理）の before 由来が「S8/R7, **S16/R16**」。**S16 は Axis EOL 露出**（R8/S16）であり、cookie フラグ欠落は **S19/R16**（baseline §2「平文HTTP＋Cookie フラグ欠落（R16/S19）」）。ID 誤記。加えて cookie Secure/HttpOnly/SameSite が **SBD-4 と SBD-15（トランスポート、正しく S19/R16 を引用）で重複**。トレーサビリティが台帳の主目的なので ID 齟齬は直すべき。
- **証拠**: baseline-summary §2（R8/S16=Axis、R16/S19=cookie フラグ）／security-baseline SBD-4（S16/R16）・SBD-15（S19/R16）。
- **修正提案**: SBD-4 の by-line を「S8/R7」（固定化）に絞り、cookie 属性は SBD-15 に一本化（または SBD-4 から SBD-15 を相互参照）。誤記 S16→S19 訂正。

### [低] 非before 免責の列挙漏れ ｜ SBD-13（金額 BigDecimal）も非before なのに脚注に未記載

- **内容**: 末尾脚注は「SBD-8/SBD-14 は before の直接 finding ではなく…過大評価しない」と記すが、**SBD-13（金額の正確性／by-line=「fidelity/completeness 指摘」）も同様に非before 派生**。一貫性のため脚注に併記すべき（by-line が既に fidelity と明示されているので実害は小、透明性向上のみ）。
- **証拠**: security-baseline SBD-13 by-line・脚注。
- **修正提案**: 脚注を「SBD-8/13/14 は before 直接 finding でない（8/14=モダン化追加、13=他レンズ fidelity 由来）」に更新。

---

## 4. 収束判定

**実質収束（minor 追補で収束）。** 追加のフルラウンドは不要。

- **order.md（§5/§6）・backlog-map E3** … modernization レンズとして **converged**。round01 の全指摘を解決し、新規 as-is 証拠も原典と一致。否定AC種（totalPrice 改ざん／listOrders 越権／他人 orderId 403／在庫超過／不存在ID 同一応答）が入り、Phase4 回帰の種として機能する水準。
- **security-baseline.md** … 骨格は妥当だが **2 中（S6 再認証の欠落・維持系 injection/XSS NFR の欠落）＋2 低（SBD-4 引用誤記/重複・SBD-13 免責漏れ）** が残る。これらは**横断NFR台帳への追補パッチ**で閉じられ、E3 ドメイン spec の作り直しは要さない。

→ 推奨: security-baseline に上記 2 NFR を追記し low 2 件を修正 → その**差分確認のみ**で収束確定。フル round 03 は不要。

**残指摘: 4 件（中 2 / 低 2）。すべて security-baseline.md に集中。order.md / backlog-map(E3) は残指摘なし。**
