# spec 敵対的レビュー — レンズ=完全性 (completeness) / E1・E2・E4・E5 round 01

- **対象**: `spec/behavior/{catalog,cart,account,auth}.md` ＋ `spec/backlog-map.md`（E1/E2/E4/E5 節）
- **round**: 01
- **日付**: 2026-08-10
- **方針**: 各 spec 冒頭「参照 legacy」のコード（Struts 稼働構成）を一次情報に突合。spec に無い挙動/業務ルール/画面/エラー分岐/バリデーション/状態/データ、backlog の Feature 抜けを列挙。catalog/cart は before clean のため「維持」漏れも見る。追認せず・濫造せず。証拠は file:line。

---

## E1 カタログ（catalog.md）

### [重大度 中] エラー分岐（欠落・アクション間で不統一）｜ ページング系の stale/no-session 時の挙動が3アクションで割れており spec が拾えていない
`viewCategory` は `categoryId` 無し＋セッション無しで **`throw new IllegalStateException("Cannot find pre-loaded category and product list")`**（ViewCategoryAction.java:29-31）＝未捕捉 500＋trace。`viewProduct` は同状況で session の itemList が null のまま `itemList.nextPage()` ＝ **NPE**（ViewProductAction.java:27-34、null ガード無し）。`search` だけは graceful に「Your session has timed out…」（SearchProductsAction.java:31-34）。catalog §2 は search の graceful 分岐のみ記し、§5 の SBD-10 行は `viewItem` の NPE だけを挙げる。**viewCategory/viewProduct の "セッション前提が崩れたページング" エラーパスが欠落**し、SBD-10（正規化）の対象が不完全。

- **証拠**: ViewCategoryAction.java:29-31 / ViewProductAction.java:27-34 / SearchProductsAction.java:31-34 vs catalog.md §2, §5(SBD-10 行)
- **修正提案**: §2/§5 に3アクションの stale-session 挙動（throw / NPE / message）を明記し、after は一律 404 or 空リストへ正規化（F1.3）。

### [重大度 中] 業務ルール／XSS（欠落・矛盾）｜ product.description は表示用 HTML を内包し `escapeXml="false"` で描画＝SBD-18「全エスケープ」と挙動等価が衝突
商品説明はシードで `<image src="../images/fish1.jpg">Salt Water fish...` の**HTML を含む**（dataload.sql:25-40）。`Item.jsp:16` と `SearchProducts.jsp:14` は `<c:out value="${product.description}" escapeXml="false"/>` で描画し、**画像表示が非エスケープに依存**。catalog §5 の SBD-18「escape を無効化しない」を一律適用すると `<image>` がリテラル化し画像が壊れる＝**挙動非等価**。この「HTML-by-design なマスタ列を維持しつつ XSS を消す」矛盾を spec が扱っていない。

- **証拠**: dataload.sql:25-40 / Item.jsp:16 / SearchProducts.jsp:14 vs catalog.md §5(SBD-18 行)
- **修正提案**: §5 に「product.description は表示 HTML を内包する as-is。after は sanitize して安全な HTML のみ許可、または画像URL列を分離してテキストはエスケープ」を明記し、意図的な非等価変更として扱う。

### [重大度 低] 正確性（維持の過剰記載）｜ SearchProducts.jsp は検索語を反射しない（§5 の「検索語エコー」は as-is に存在しない面）
`SearchProducts.jsp` は `productList` のみ描画し keyword を反射しない（baseline でも反射 XSS は REFUTED）。§5 が after エスケープ対象に挙げる「検索語エコー」は as-is に無い面で、維持対象の誤認を招く。

- **証拠**: SearchProducts.jsp 全体（keyword 反射なし）vs catalog.md §5(SBD-18 行「検索語エコー」)
- **修正提案**: 「検索語エコー」を削除、または「as-is に反射面は無い（clean 維持）」と明記。

**E1 Feature 抜け**: F1.3 に上記 C1（stale-session 正規化）と C2（HTML 説明のエスケープ方針）を明示的に含める。それ以外の Feature（F1.1 階層閲覧・F1.2 検索）は legacy 挙動（複数語 space 分割＋`%kw%` の LIKE を name/category/descn に OR。Product.xml:26-33, SqlMapProductDao.ProductSearch:30-44。パラメタライズ＝SQLi clean）を正しく抽象化できており抜けなし。

---

## E2 カート（cart.md）

### [重大度 低] 業務ルール（欠落・"削除" の実態が不整合）｜ 数量0での削除は表示リストからのみで itemMap に残る
`UpdateCartQuantitiesAction` は quantity<1 で `cartItems.remove()` を呼ぶが、これは `Cart.itemList` の source からの削除だけで、**`Cart.itemMap` には CartItem が残る**（UpdateCartQuantitiesAction.java:22-27／`Cart.removeItemById` を通らない、Cart.java:15,49-63）。結果 `containsItemId` は true のままで、**同一 item を再追加すると "既存扱い" で itemMap 上の（非表示の）CartItem が increment されるだけ＝カートに戻らない**幽霊状態になる。cart §2「数量<1 は行削除」はこの不整合を捨象しており、"挙動等価で残す" を字義通り移植すると legacy バグを再現する。

- **証拠**: UpdateCartQuantitiesAction.java:22-27 / Cart.java:15,49-63 vs cart.md §2, §6(挙動等価で残す)
- **修正提案**: §2/§3 に「as-is の 0-削除は表示リストのみで itemMap に残る不整合」を注記。after は map/list 双方から一貫削除（clean 実装＝軽微な非等価）。

### [重大度 低] エラー分岐（欠落）｜ 不正 `workingItemId` での追加は NPE
`AddItemToCartAction` は未存在 itemId で `isItemInStock`→false、`getItem` が null を返し `cart.addItem(null, …)` → `Cart.addItem` 内 `item.getItemId()` で **NPE**（AddItemToCartAction.java:26-28, Cart.java:35-36）。cart §2 は正常系のみ記載。

- **証拠**: AddItemToCartAction.java:26-28 / Cart.java:35-36 vs cart.md §2
- **修正提案**: §2 に不正 itemId 追加のエラー挙動を追記。after は 404/バリデーションで正規化（+ SBD-10）。

**E2 Feature 抜け**: なし。F2.1〜F2.3（数量のみ受理・価格サーバ権威・CSRF・冪等整理）は as-is（`getSubTotal` サーバ計算、パラメータ名=itemId の暗黙規約の明示 API 化）を正しく捉えている。数量上限/在庫切れ表示/未ログインカート永続化は §6 論点で適切に PO 送り。

---

## E4 アカウント（account.md）

### [重大度 中] 業務ルール／データ（欠落・重大な結合）｜ account 取得が bannerdata と INNER JOIN → favcategory に対応する bannerdata 行が無いと account が取れない（＝ログイン不可・プロフィール取得不可）
`getAccountByUsername` / `getAccountByUsernameAndPassword` は `from account, profile, signon, bannerdata … and profile.favcategory = bannerdata.favcategory` の **inner join**（Account.xml:45-50, 71-77）。SqlMapAccountDao 経由で **ログイン**（getAccount(username,password), :32-37）と **アカウント表示**（getAccount(username), :28-30）の両方に効く。シードは全5カテゴリに bannerdata 行がある（dataload.sql:13-17,19-23）ため現状は成立するが、**bannerdata 行の無い favcategory を持つユーザは account 取得が null＝ログイン失敗/プロフィール取得不能**になる。account §6 論点①（bannerdata/MyList/バナー機能の要否）で bannerdata を廃止/未移行にすると、この取得クエリが壊れログインが死ぬ、という結合リスクが account/auth 双方で未記載（auth.md §4 は4表結合に触れるが consequence なし）。

- **証拠**: Account.xml:45-50, 71-77 / SqlMapAccountDao.java:28-37 / dataload.sql:13-23 vs account.md §3,§4, auth.md §4
- **修正提案**: account §3/§4・auth §4 に「account/login 取得は bannerdata と inner join。bannerdata 廃止（論点①）時は LEFT JOIN 化 or プロフィール取得とバナー取得のクエリ分離が必須（さもなくばログイン破壊）」を明記。after は banner をプロフィール取得から分離。

### [重大度 低] データ（欠落）｜ `signon.password varchar(25)` はハッシュ格納に不足（移行時のカラム拡張が未記載）
schema は `signon.password varchar(25)`（schema.sql:34）。SBD-5 のハッシュ（bcrypt=60 / argon2 はさらに長い）は 25 桁に収まらない。account §4/auth §4 はカラム幅拡張に触れず、DB 移行（Flyway/E6）で見落とすとハッシュが切詰められる。

- **証拠**: jpetstore-hsqldb-schema.sql:32-36 vs account.md §4, auth.md §4
- **修正提案**: account/auth の DB 移行メモに「password カラムをハッシュ長へ拡張（例 varchar(255)）」を明記。

### [重大度 低] バリデーション（欠落・as-is の実態）｜ 登録/編集の検証は「非空＋PW一致」のみ（形式・最大長・PW 強度は未検証）
`AccountActionForm.doValidate` は required（非空）と password==repeatedPassword のみ（AccountActionForm.java:77-104）。**email 形式検証なし**、桁数超過（例 zip varchar(20) 超）→ DB エラー/切詰め、PW 強度なし。account §2 は「各必須」と記すが「非空のみ」である点が曖昧で、after の検証範囲（形式/長さ/強度）を決める材料が不足。

- **証拠**: AccountActionForm.java:77-104 vs account.md §2,§3
- **修正提案**: §2/§3 に「as-is 検証は非空＋PW一致のみ（形式・最大長・強度は未検証）」を明記し、after の入力検証方針を Feature 化。

### [重大度 低] XSS シーム（欠落）｜ `bannerName`（bannerdata.bannername＝HTML）を `escapeXml="false"` で描画
`IncludeBanner.jsp:7` は `<c:out value="${accountForm.account.bannerName}" escapeXml="false"/>`。bannerdata.bannername は `<image ...>` の HTML（dataload.sql:13-17）。E1 の C2 と同型（HTML-by-design vs 全エスケープ）だが、account §5 には XSS/HTML シームの記載が一切ない。

- **証拠**: IncludeBanner.jsp:7 / dataload.sql:13-17 vs account.md §5
- **修正提案**: account §5 に bannerName の HTML 描画 seam（SBD-18）を追加。MyBanner 廃止/存置（論点①）に応じ sanitize またはデータ分離を明記。

**E4 Feature 抜け**: F4.1〜F4.3（登録・本人固定編集・PW 再認証）は S2/S3/S6/S12 を的確にマップ。ただし **入力検証（形式/長さ/強度）を扱う Feature が明示されていない**（Ac3）。bannerdata 結合リスク（Ac1）は論点①に紐づく Feature/注記として拾うべき。

---

## E5 認証（auth.md）

### [重大度 低] 挙動（欠落）｜ ログイン失敗は global-forward "failure" 経由で Error.jsp に遷移（サインオン画面に戻さない）
`SignonAction` は資格情報不一致で `findForward("failure")`（SignonAction.java:27-29）。signon アクションにはローカル "failure" 転送が無く（struts-config.xml:73-76 は success のみ）、**global-forward `failure` → `/WEB-INF/jsp/struts/Error.jsp`**（struts-config.xml:17）に落ちる。＝失敗時は汎用エラーページ表示で、SignonForm には戻らない。auth §2 はメッセージ文言のみ記し遷移先（Error.jsp）が未記載。

- **証拠**: SignonAction.java:27-29 / struts-config.xml:17, 73-76 vs auth.md §2
- **修正提案**: §2 に「失敗は Error.jsp へ遷移（as-is）」を明記。after(SPA) はフォーム再表示＋インラインエラー（一律メッセージ＝列挙不可を維持）。

### （再掲・重複計上しない）[中] ログインの bannerdata inner-join 依存 ＝ Ac1
`getAccountByUsernameAndPassword` の inner join（Account.xml:71-77）は**ログイン成否そのもの**に効くため、認可土台である本ドメインの完全性に直結。詳細・修正提案は E4 の Ac1 参照。auth.md §4 にも同じ結合リスク注記を入れること。

**E5 Feature 抜け**: なし。F5.1〜F5.4（セッション再生成・ハッシュ化・レート制限/既定資格情報廃止・GET 認証廃止・リダイレクト検証・プリンシパル基準認可）は S7/S8/S9/S10/S11/S5 と "clean 維持（列挙不可・SQLi無）" を網羅。唯一 Au1（失敗遷移先）と Ac1（bannerdata 依存）の反映を要する。

---

## 総評・ドメイン別収束見込み

4ドメインとも E3 見本の水準を踏襲し、before findings のマッピング（S2/S3/S6/S7/S8/S9/S10/S11/S12）と横断 NFR（security-baseline）への trace は良好。残る穴は主に **(a) as-is のエラー/例外パスの取りこぼし、(b) before clean 資産の "維持" と secure 化の衝突（HTML-by-design 列 × 全エスケープ）、(c) 非自明な結合（account/login × bannerdata inner join）** の3系統で、いずれも behavior/データの追記と1判断で埋まる範囲。新規 behavior の作り込みや設計やり直しは不要。

| ドメイン | 残指摘 | 収束見込み |
| --- | --- | --- |
| **E1 catalog** | 中2・低1（計3） | round02 で収束見込み。C1(stale-session 正規化)・C2(HTML 説明の扱い) を §2/§5/F1.3 に反映すれば十分 |
| **E2 cart** | 低2（計2） | ほぼ収束。Ca1/Ca2 は as-is 注記の追記のみ。round02 で確実に収束 |
| **E4 account** | 中1・低3（計4） | round02 で収束見込み。Ac1(bannerdata 結合)が実質論点で、他3件は追記。Ac1 を PO 論点①と結線すること |
| **E5 auth** | 低1（＋Ac1 継承）（計1） | near-converged。Au1 追記＋Ac1 反映で収束。認可土台として最も完成度が高い |

**全体判定**: 4ドメインとも **もう1周（round02）で収束見込み**。フルな多周レビューを要するドメインは無い。優先度は E4（Ac1 の結合リスク）＞ E1（C1/C2）＞ E2/E5（追記主体）。
