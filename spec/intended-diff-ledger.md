# intended-diff-ledger — 意図差分台帳（旧と"違ってよい／違うべき"の宣言）

> **所有**: PO（レビュー承認を経て確定）。**生きた文書** — Story 起票/Refinement で「振る舞いを変える」と判断したら**必ず追記**する。
> **役割**: AI Factory は 1:1 再現ではなく仕様源からの作り直し。ゆえに「旧と違う＝バグ」の誤解を断つため、**変える差分をここで宣言**する。
> **判定規範**: Phase 4 L4 で実測された差分は**すべて本台帳に載っていること**が合否ゲート（[`verification-strategy.md`](./verification-strategy.md) §4・§5）。**台帳に無い差分＝要調査（欠陥候補）**。
> **由来**: [`verification-strategy.md`](./verification-strategy.md) §4 雛形（ID-1〜7）＋本 Refinement の決定＋[`reports/before/baseline-summary.md`](../reports/before/baseline-summary.md) findings（R#=Spring MVC run / S#=Struts run）。
> **関連**: [`architecture-conventions.md`](./architecture-conventions.md)（D6 並行制御）／[`security-baseline.md`](./security-baseline.md)（SBD）／[`backlog-map.md`](./backlog-map.md)。

## 台帳（intended diffs）

| # | 旧の振る舞い（as-is） | 新の振る舞い（after） | 理由 | 由来 | 関連Story |
| --- | --- | --- | --- | --- | --- |
| **ID-1** | 在庫ガード無し減算（`qty=qty-n` 無条件）＝売り越し・マイナス在庫可 | `qty>=n` ガード付きアトミック減算・在庫不足で注文失敗（**受容済みの帰結 2026-08-21**: 本ガードにより在庫0が他顧客の注文をブロックしうる〔denial-of-inventory。`reports/after/l3-security-regression-backend.md` §3-5〕。旧はガードが無くマイナス在庫でも注文が通るため枯渇が他者をブロックせず、**本帰結は ID-1 の副作用であって ID-8〔決済ゲート撤去〕の帰結ではない**〔旧のカード必須検証は `domain/logic/OrderValidator.java#validateCreditCard` の非空チェックのみ＝任意の1文字で通過し、しかも Struts 経路は `NewOrderAction` が検証を挟まず `insertOrder` を直呼びするため実行すらされない。参照は Spring MVC 経路の `web/spring/OrderFormController.java:87` のみ〕。状態変更 API のレート制限は ID-11 の適用範囲外。**現時点で受容**し、本番デプロイ基盤/本番プロファイルの整備決定時に #45・#43・#46 と束ねて再評価する〔PO 判断 2026-08-21〕） | 売り越し防止 | D6 / SBD-2 | #8, #49 |
| **ID-2** | パスワード平文保存・平文比較 | ハッシュ＋ソルト保存・照合 | 資格情報保護 | SBD-5 / S7,R5 | #19, #13, #15 |
| **ID-3** | 金額 `double`（丸め誤差の余地） | `BigDecimal` / `decimal` | 丸め正確性 | SBD-13 | #8, #10, #22 |
| **ID-4** | 連番 orderId で他人注文参照可（IDOR）＋ identity-rebind でセッション汚染 | サービス層認可（プリンシパル基準）＋ not-owned/not-found を同一応答（or 不透明ID） | アクセス制御・列挙封じ | SBD-1 / SBD-8 / S3,S15,R2 | #9, #10, #14, #21 |
| **ID-5** | Hessian/Burlap/HttpInvoker/Axis remoting 面（無認証 `getOrder` 総当り含む） | 廃止（REST・認証必須のみ） | 攻撃面除去 | SBD-7 / S1,S13,S14,S16 | #11, #23, #50 |
| **ID-6** | JSP / サーバサイドレンダリング | Vue3 SPA＋REST | モダン化 | D1 | 全ドメイン (#1–#24), #50 |
| **ID-7** | banner 広告 / MyList（bannerdata INNER JOIN 依存） | 廃止（bannerdata 除外＝JOIN 依存解消） | スコープ決定 | backlog-map / 決定 2026-08-10 | #13, #22 |
| **ID-8** | 実カード列を永続化・カード欄必須（ダミー処理） | カード列/入力欄/必須検証を撤去・支払プレースホルダ（文言はカード情報を「扱わない/保持しない」旨を明示。孤立したカード型残骸〔frontend enum/定数〕も撤去、DBのm_code区分値0002は温存） | 機微データ非保持 | F3.6 決定 / Sprint15 決定 2026-08-17 | #12, #22 |
| **ID-9** | 注文確定が GET リンクで成立（状態変更 GET）・CSRF 全域不在 | 非冪等 POST＋CSRF トークン | CSRF 防止 | SBD-3 / S5,R6 | #8, #6, #16, #18 |
| **ID-10** | ログイン/登録成功時にセッションID 非再生成（固定化） | ログイン/登録時に認証状態を再発行し、**認証前の識別子を通用させない**（**訂正 2026-08-21**: 新は `SessionCreationPolicy.STATELESS`〔`jpetstore-backend/src/main/java/com/example/jpetstore/backend/config/SecurityConfig.java:87`〕で HTTP セッション自体を作らないため、実体は「セッション再生成」ではなく**ログイン時の新規 JWT 発行**。趣旨＝**セッション固定化が成立しない**ことは不変。旧記述は §訂正履歴 参照） | 固定化防止 | SBD-4 / S8,R7 | #18, #13 |
| **ID-11** | 資格情報を GET でも受理・`j2ee/j2ee` プリフィル・ロックアウト無し（ログイン）／登録試行に列挙対策なし（メール検証は #32 へ分離） | POST body 限定・プリフィル廃止・レート制限/ロックアウト（ログイン=`t_login_attempt`・登録=`t_register_attempt`、いずれも DB-backed。architecture-conventions D7）。ゲートは「照合前にスロットを原子確保」する方式のため、成功ログインも枠を1つ消費する意味論を伴う（同一usernameへの高並行「成功」ログインが`max-attempts`超で一過性401になり得るが、`recordSuccess`のDELETEで即自己回復する受容済みトレードオフ・Sprint20決定） | 認証堅牢化 | SBD-6 / S10,S11,R10,R13,S12,R14 | #20, #13, #41 |
| **ID-12** | `forwardAction` を無検証 `sendRedirect`（オープンリダイレクト） | リダイレクト先は allowlist/相対のみ | フィッシング防止 | SBD-9 / S9,R11 | #20 |
| **ID-13** | 現在PW 未確認で PW 変更 | 現在PW 確認/再認証を必須 | 機微操作保護 | SBD-16 / S6 | #15 |
| **ID-14** | stale-session/不正 ID で 500＋スタックトレース露出（3経路） | 404/空へ正規化・trace 非露出（**注文詳細経路（`GET /api/orders/{orderId}`）は ID-4 と重畳して 403** ＝ `OrderApplicationService#getOrder` が不存在/非所有を同一の `AccessDeniedException` にするため。trace 非露出という ID-14 の趣旨は 403 でも成立する。#51 R8b で実測確認済み） | 情報漏えい防止 | SBD-10 / S18,R9 | #3, #2, #10, #23, #51 |
| **ID-15** | `product.description` の HTML 内包を `escapeXml=false` で描画（格納XSS seam） | plaintext 化＋商品画像は新規アセット（nano banana） | XSS 面除去 | SBD-18 / L1 seam | #1, #3, #24 |
| **ID-16** | 入力検証＝非空＋PW一致のみ | email 形式・最大長・PW 強度（8字以上・複数文字種）を検証 | データ健全性・資格情報強度 | F4.5 決定 / SBD-5 | #17, #15 |
| **ID-17** | カート数量 0/負で `itemMap` desync（幽霊行バグ・再追加で increment） | map/list 一貫の単一削除に正規化 | バグ是正 | cart.md 決定 | #4 |
| **ID-18** | 在庫切れでもカート追加可・数量上限なし | 在庫切れは追加不可・数量上限＝在庫数 | 在庫整合 UX | 細部決定 2026-08-11 | #4, #1 |
| **ID-19** | 未ログインカートはセッションのみ（離脱で消失） | クライアント保持＋ログイン時にサーバーカートへマージ（client+server 数量を**加算**し、在庫数で上限**クランプ**。例: client 2個＋server 3個→在庫≥5なら5個・在庫3なら3個） | カート永続 UX | E2①/② 決定 2026-08-11/2026-08-16 | #4 |
| **ID-20** | カタログ一覧 4件/頁・セッション保持ページング | 12件/頁・API ページングパラメータ | UX/モダン化 | 細部決定 2026-08-11 | #1, #2, #9 |
| **ID-21** | `courier=UPS`/`locale=CA` を保持 | courier/locale 撤去（プレースホルダ） | スコープ簡素化 | E3 決定 2026-08-11 | #7, #8, #22 |
| **ID-22** | `status="P"` 固定1行（orderstatus: linenum=orderId 等の異形） | 固定プレースホルダ・状態変更は監査ログに記録（注文作成は成功・失敗いずれも `ORDER_CREATE` イベントとして記録し、失敗時は `result=FAILURE`） | スコープ簡素化 | E3 決定 / SBD-14 | #8, #22 |
| **ID-23** | orderId 採番が select→+1→update（非アトミック・重複リスク） | DB 原子採番 | 正確性/並行安全 | D6 | #8, #22 |
| **ID-24** | 注文詳細（履歴経由）で明細の商品名が空 | 商品名を表示（非等価改善） | UX 改善 | E3 決定 2026-08-11 | #10, #51 |
| **ID-25** | Axis 管理PW/認証情報をソースに平文・HTTP 平文・Cookie フラグ欠落 | シークレットストア・TLS 前提・Secure/HttpOnly/SameSite。JWT 署名鍵は起動時 fail-fast を denylist（既知 placeholder・弱リテラルの恒久収録）→最小鍵長 32byte（既存維持）→ユニーク文字数 24 以上（補助）の3段に強化し、`.env.example` 配布値のままでは起動不能化（Sprint20決定。将来値を変更しても過去配布値は denylist から削除しない） | 設定衛生 | SBD-11 / SBD-15 / S17,S19,R15,R16 | #23, #24, #38 |
| **ID-26** | EOL/脆弱依存（Struts1.2.9/Axis1.4/Spring3.1/hsqldb1.8…）・版レンジ未固定 | 保守された現行版・版固定（`jpetstore-database`: `mysql-connector-j` はCVE-2023-22102〔HIGH〕確認のため`8.0.33→26.7.0`へ更新。他5依存〔Flyway/Spock/Testcontainers等〕は重大CVE・EOLとも未確認のため据え置き。更新判断基準＝「EOLまたは重大CVE確認時のみ更新」）。**版乖離の据え置き記録 2026-08-21**: 同一ライブラリが `jpetstore-backend` = `mysql-connector-j:9.5.0`〔`build.gradle:65,68`〕／`jpetstore-database` = `26.7.0`〔`build.gradle:30,38`〕の**2版で固定**されている。各リポジトリ単位では「版固定」を満たすが、ライブラリ単位では版が割れている。**据え置きの理由は未記録・要確認**（backend の 9.5.0 は CVE-2023-22102 が 8.2.0 で修正済のため非該当＝上記の更新基準を適用した結果である可能性が高いが、そう判断した記録が残っていない。`reports/after/l3-security-regression-backend.md` §2.2・§3-7） | 依存健全化 | SBD-12 / S20,S21,R12,R17 | #23, #26 |
| **ID-27** | 多言語は**アカウント設定だけで実体が無い**（`profile.langpref` に english/japanese を保存するが描画に一切影響しない。日本語 JSP ツリーもリソースバンドルも存在せず〔`src/main/webapp/WEB-INF/jsp/` は `spring`/`struts` の2本のみ・`src` 配下の `*.properties` は `jdbc`/`log4j`/`mail` の3本のみ〕、`getLanguagePreference()` を読む描画実装も無い〔`web/spring/AccountFormController.java:25` の `LANGUAGES` はセレクトの選択肢・`jsp/struts/IncludeAccountFields.jsp:41` で選ばせて保存するだけ〕）。**訂正 2026-08-21**: 旧記述「多言語＝english/japanese（日英 JSP 同梱）」は誤り＝§訂正履歴 参照 | i18n 基盤（文言外部化）を実装。日本語ローカライズは **#25 で完了**（`ja.ts` 全キー翻訳・ヘッダー言語切替UI・DB権威〔`m_profile.language_preference`〕での跨デバイス追従）。数値・日付フォーマットは、日付を `datetimeFormats.ja` 新設＋OrderHistory/OrderDetailの2箇所へ適用、通貨は既存の全画面インラインIntl（`style:'currency'`）がlocale連動済みのため維持し名前付きnumberFormatsは追加せず（m_code は日英データ保有済＝D4） | スコープ決定（段階的ローカライズ・#25で完結） | E4②/E5① 決定 / backlog #25 / Sprint19決定 2026-08-18 | #24, #13, #25 |
| **ID-28** | アイテム詳細が**生の在庫数をそのまま表示**（`item.quantity <= 0` なら `Back ordered.`、それ以外は `<数値> in stock.` ＝ `jsp/struts/Item.jsp:37-43`・`jsp/spring/Item.jsp:37-42`）。全アイテム qty=10000 固定のため残少/在庫切れの概念自体は無い。**訂正 2026-08-21**: 旧記述「アイテム詳細に在庫状況表示なし」は誤り。差分は「表示の有無」ではなく**生の在庫数の露出 → status のみ**＝§訂正履歴 参照 | 在庫状況を3段階バッジ表示（在庫あり／残少 `0<qty≤5`／在庫切れ `qty≤0`）。qty 自体はレスポンス非露出（status のみ算出返却） | 新規UX（在庫数非公開のまま状況を伝達）・在庫数直接露出の防止 | R3 / 論点2 決定 2026-08-16 | #1 |
| **ID-29** | 検索語の `%`/`_` が LIKE ワイルドカードとして機能（意図せぬ部分一致・想定外の全件マッチの余地） | 検索語の `%`/`_` をリテラルとして一致（ESCAPE 併用） | 予測可能性・意図せぬ全件マッチ防止（SBD-17 維持） | SBD-17 / 決定 2026-08-16 | #2, #49 |
| **ID-30** | チェックアウト・ウィザードの下書き状態（配送先/請求先等）を HTTP セッションの `workingOrderForm` に保持（`insertOrder` 成功まで破棄されず、ウィザード途中のブラウザリロードでも残る） | Pinia（メモリのみ）で保持。ブラウザリロードで下書きが消失（`/checkout` 単一ルート＋deep-link 非対応で整合） | ウィザード状態管理のモダン化・単純化（stateless backend／SPA 設計上の意図的トレードオフ） | E3 決定 2026-08-16 | #7 |
| **ID-31** | テーマ/配色の切替機能なし（固定配色・legacyに比較対象概念自体が無い） | ライト/ダーク/システム連動のテーマ切替UIをヘッダーに新設。ヘッダーで即時切替（localStorage）＋アカウント保存時にDB永続化（`m_profile.color_scheme_preference`）・DB権威で跨デバイス追従。AccountEditにも同等のテーマ/言語selectを追加（ヘッダーと対称・preferences store単一化で二重ソース回避） | 新規UX（配色パーソナライズ・OS追従） | Sprint19決定 2026-08-18 | #36, #25 |
| **ID-32** | 認証状態をサーバサイド HTTP セッションで保持（`web/struts/SignonAction.java:40` が `session.setAttribute("accountForm", …)`／サインオフは `session.invalidate()`＝同`:19`）。カート・ウィザード下書き・ページング位置も同一セッションに同居 | **完全ステートレス**（`jpetstore-backend/src/main/java/com/example/jpetstore/backend/config/SecurityConfig.java:87` の `SessionCreationPolicy.STATELESS` ＋ httpOnly JWT Cookie／refresh Cookie）。サーバは認証状態を保持しない | SPA＋REST 化に伴う stateless backend（水平スケール前提・ID-6 の帰結）。セッションに同居していた個別状態は ID-19〔カート〕・ID-30〔下書き〕・ID-20〔ページング〕で各々宣言済みだったが、**方式そのものが未宣言だった** | D1 / SBD-4 ／ 実装で確立・**L4(#52) で未記録が判明し追記 2026-08-21** | #18, #23, #24 |
| **ID-33** | カート一覧を 4件/頁でページング（`domain/Cart.java:22` の `itemList.setPageSize(4)`・`jsp/struts/Cart.jsp:22` が `cartItemList.pageList` を描画・同`:57-61` に `viewCart.do?page=previousCart` ／ `nextCart` のリンク）。ページ位置はセッション保持の `PagedListHolder` が持つ | カートは**全件表示**（ページング無し。`jpetstore-frontend/src/views/CartView.vue` にページング要素なし・`GET /api/cart` にページングパラメータなし） | 明細数が少なくページングの UX 価値が無い／SPA 側で全件保持するほうが単純。**ID-20 は「カタログ一覧」限定でカートを対象外としている**ため本行を独立させた | 実装で確立・**L4(#52) で未記録が判明し追記 2026-08-21** | #4 |

## 補足（台帳の対象外）

- **構造スキーマ差分は行動差分ではない**（台帳非対象）: WHO 6列・`version` 列・自動採番ID・`created_at`/`updated_at`・HSQLDB→MySQL は [`verification-strategy.md`](./verification-strategy.md) §3 で L2 比較から**正規化除外**する。意味デルタ（金額/数量/在庫増減/ステータス/関連レコード件数）で比較する。
- **維持項目（＝差分でない・"clean を保つ"）**: SQLi 無（全パラメタライズ・SBD-17）／稼働 JSP 反射XSS 無（SBD-18 の反射面）／カート価格サーバ権威（SBD-2）／ログアウトでセッション無効化／ソース内に実効的秘密なし。→ [`reports/before/baseline-summary.md`](../reports/before/baseline-summary.md) §4 基準線として Phase 4 で「維持」を検証（L2/L3）。台帳には載せない（差分ではないため）。

## 運用

- 追記トリガ: Refinement/起票で「旧と振る舞いを変える」と判断した時。理由と由来（SBD-x / D# / 決定日）と関連 Story を必ず埋める。
- Phase 4: SM/PO が L4 で「実測差分 ⊆ 本台帳」を確認し `reports/after/verification-report.md` に反映。

## 訂正履歴（台帳の記述そのものを直した記録）

> **なぜ残すか**: 本台帳は「旧の as-is」を根拠に差分を宣言する文書なので、**as-is の誤りは差分判断そのものを誤らせる**（例: ID-27 は誤った as-is のままだと「#25 で実装完了＝もう差分でない」という誤った結論が成立してしまう）。訂正の事実・根拠・発見経路を残さないと同じ誤りが再導入される。
> **凡例**: legacy のパスは `legacy-jpetstore/` 配下（Java は `src/main/java/org/springframework/samples/jpetstore/` を、JSP は `src/main/webapp/WEB-INF/` を起点に省略）。

### 記述の訂正（2026-08-21・訂正者 PO・発見＝Phase 4 L4 台帳照合 #52・ユーザー承認済み）

| 対象 | 旧記述（訂正前） | 訂正後の要点 | 根拠（`file:line`） |
| --- | --- | --- | --- |
| **ID-27** as-is | 多言語＝english/japanese（日英 JSP 同梱） | 日本語資産は存在しない。`profile.langpref` は保存されるだけで描画に一切影響しない | `src/main/webapp/WEB-INF/jsp/`（`spring`/`struts` の2本のみ）・`src` 配下の `*.properties`（`jdbc`/`log4j`/`mail` の3本のみ）・`web/spring/AccountFormController.java:25`・`jsp/struts/IncludeAccountFields.jsp:41`・`domain/Account.java:73-74`（getter/setter のみで読み手なし） |
| **ID-28** as-is | アイテム詳細に在庫状況表示なし（全アイテム qty=10000 固定・残少/在庫切れ概念なし） | 旧は**生の在庫数を表示している**。差分は「表示の有無」ではなく「**生の在庫数の露出 → status のみ**」。「qty=10000 固定・残少概念なし」は正しいので維持 | `jsp/struts/Item.jsp:37-43`・`jsp/spring/Item.jsp:37-42` |
| **ID-10** after | ログイン/登録時にセッション再生成 | 新は STATELESS で HTTP セッションを作らないため、実体は**ログイン時の新規 JWT 発行**。趣旨（セッション固定化が成立しない）は不変 | `jpetstore-backend/src/main/java/com/example/jpetstore/backend/config/SecurityConfig.java:87` |

### 追記・行内追記（2026-08-21・同上）

| 対象 | 内容 | 位置づけ |
| --- | --- | --- |
| **ID-32**（新規） | 認証状態の保持方式: サーバサイド HTTP セッション → 完全ステートレス（JWT Cookie） | 決定自体は実装時に済んでおり**記録だけが抜けていた**。L4 で未記録が判明したため追記 |
| **ID-33**（新規） | カート一覧のページング廃止: 旧4件/頁・セッション保持 → 新は全件表示 | 同上。ID-20 が「カタログ一覧」限定でカートを対象外としているため独立行にした |
| **ID-1**（行内） | denial-of-inventory を**受容済みの帰結**として記録 | 新規 ID は起こさない（**旧にも決済ゲートが無く旧新差分ではない**ため）。在庫ガード導入の副作用なので ID-1 に帰属させた |
| **ID-26**（行内） | `mysql-connector-j` の版乖離（backend 9.5.0 / database 26.7.0）を据え置き記録 | 新規 ID は起こさない（旧新差分ではなく**新側内部の整合性**の話のため）。据え置き理由は**未記録・要確認** |

### 見送った候補（記録のみ）

- **注文の二重送信**（冪等キー無しで並行 POST が注文2件。`reports/after/l3-security-regression-backend.md` §3-6）は**台帳に載せない**（2026-08-21 ユーザー判断）。旧の `domain/logic/PetStoreImpl.java:147-150` にも冪等制御が無く、旧は注文確定が GET リンク（ID-9）＋在庫ガード無し（ID-1）でより二重送信しやすいため、**旧新差分として成立しない公算が高い**。**実測で「旧は二重送信で1件しか作らない」等の反証が出た場合は台帳行に切り替える**（条件付き保留）。
