# before ベースライン — legacy-jpetstore 脆弱性棚卸し（統合サマリ）

> JPetStore レガシー刷新プロジェクトの **"before"**。モダンな再構築（`jpetstore-backend` / `jpetstore-frontend`）で
> これらを **secure-by-default で消滅** させ、Phase 4 で再実行して「消えたこと」を実証する。その基準線。
>
> - 対象: [`legacy-jpetstore`](https://github.com/ryokkon624/legacy-jpetstore)（Apache Struts 1.2.9 + Spring 3.1 + iBATIS 2 + HSQLDB / JSP）
> - 手法: Anthropic「Using LLMs to secure source code」の Find-and-Fix ループ（**発見と検証を分離**・3ペルソナ多数決で反証）
> - 生成果物（file:line・PoC 手順・武器化の詳細を含む raw）は `security/20260803_01,_02/`（**git-ignore**）。本書はそこから危険な詳細を落とした curated 版。
> - 日付: 2026-08-03

---

## 0. この before の特徴 — 「両層を診断した」

JPetStore は 2000 年代の設計で、**Web 層を2つ同梱**していた（`web.xml` の `*.do` マッピングで切替）：

| 構成 | 稼働 Web 層 | 状態 |
| --- | --- | --- |
| サンプル既定 | **Spring MVC 3.1**（`petstore` DispatcherServlet） | run `_01` で診断 |
| 本題材で有効化 | **Struts 1.2.9**（`action` ActionServlet） | run `_02` で診断 |

`/remoting/*`（Hessian/Burlap/HttpInvoker）と `/axis/*` は**どちらの構成でも常時稼働**。
「Struts1 だから危ない」という単純な像ではなく、**両方の Web 層を実際に切り替えて2回診断**し、共有コア＋各層固有の穴を洗い出した ── これがこの before の起点。

**結論**: 素の状態で**既に脆弱性は"満載"**（下記）。よって *記事映えのための意図的な脆弱性注入は不要* と判断（本物のレガシー脆弱性で before/after を語る）。唯一 clean だった SQLi / 反射XSS が、逆に「注入前の基準線が保たれている」ことの証拠になっている。

---

## 1. 結果サマリ

| run | 稼働層 | CONFIRMED | 内訳 | 特記 |
| --- | --- | --- | --- | --- |
| `_01` | Spring MVC | **17** | Crit 2 / High 4 / Med 5 / Low 6（＋Latent 2 / Refuted 1） | **R2 をライブ PoC で実証** |
| `_02` | Struts 1.2 | **21** | 全 21 が 3/3 多数決 CONFIRMED（昇格 3） | **CVE-2014-0114 が到達可能に昇格** |

全 finding が **3ペルソナ（懐疑的監査者 / 保守者 / レッドチーム）の独立検証で過半数 CONFIRMED**。Issue 化はしていない（before 方針）。

---

## 2. 確定した弱点（テーマ別・両 run 統合）

> R# = run `_01`（Spring MVC）、S# = run `_02`（Struts）の finding ID。多くは共有コアで両 run に出現。

### 🔴 リモートコード実行の経路（無認証デシリアライズ）
- **無認証 Java ネイティブ逆シリアライズ**：`/remoting/*` の Hessian / Burlap / HttpInvoker exporter が**認証なしで到達**（R1 / S13 / S14）。到達性は CONFIRMED、**武器化 RCE は "要ライブ PoC・未実証"**（ガジェット組成と Tomcat9/JRE8 依存。CC1-7 ガジェットは classpath に不在＝即 RCE ではない、と校正）。
- **Struts1 CVE-2014-0114（ClassLoader 操作）**（S1）：Struts 有効化で **無認証 `*.do` から `class.classLoader.*` 束縛に到達可能に昇格**（`_01` では ActionServlet 未マップで到達不可＝REFUTED だった）。**武器化 RCE は未実証**（cyber safeguard によりライブ実証は行わず／Tomcat9 で通るとは限らない、と留保）。

### 🔴 認可バウンダリの崩壊 / IDOR
- **無認証 `getOrder` で全顧客 PII 総当り**（R2 / S15）── **ライブ PoC 実証済み**。Web 層の所有者チェックが remoting 経路に介在せず、`orderId` を単純インクリメントするだけで他人注文の氏名・住所・電話・注文内容を無認証取得（カード番号欄はチェックアウトのダミー入力）。**非破壊・成功率ほぼ100%＝before の看板 PoC**。
- **identity-rebind IDOR**（S3・Struts で新規昇格）：所有者判定元のセッション属性を同一リクエストで差し替え、他人の注文/PII を閲覧。*SEC 自身の「read-IDOR は clean」という校正の誤りを、独立 Discovery が 3/3 で訂正* ── 発見と検証を分離した設計の効用。

### 🟠 マスアサインメント / アカウント乗っ取り
- **editAccount 乗っ取り**（R3 / S2）：`account.username` のネスト束縛で他人プロフィール上書き＋パスワードリセット。Spring 無制限バインド（`_01`）→ Struts `BeanUtils.populate`（`_02`）と**機構は変われど結果は同じ**。
- **注文マスアサインメント**（R4 / S4）：`totalPrice` / `unitPrice` / `username` を束縛して価格改ざん・他人名義注文（サーバ側で再計算せず command 値を永続化）。

### 🟠 認証の弱点
- **平文パスワード保存・平文比較**（R5 / S7）：ハッシュ/ソルト無し。DB 読取が及べば全資格情報が即漏洩。
- **CSRF 対策が全域で不在**（R6 / S5）：token / Origin / SameSite 皆無 → 乗っ取り・注文発行を外部サイトから駆動可能。
- **現在パスワード未確認でパスワード変更**（S6）：CSRF・マスアサインと連鎖で遠隔乗っ取り。
- **セッション固定**（R7 / S8）：ログイン成功時にセッション ID を再生成しない。
- **ブルートフォース対策皆無＋弱い既定資格情報**（R10 / S10）：`j2ee/j2ee` をフォームにプリフィル、レート制限/ロックアウト無し。
- **資格情報を GET でも受理**（R13 / S11）／**登録画面でユーザ名列挙**（R14 / S12）／**オープンリダイレクト**（R11 / S9）。

### 🟡 露出面・依存・設定衛生
- **Apache Axis 1.4(EOL) を無認証露出**（R8 / S16）：WSDL / バージョン開示（AdminService RCE は `enableRemoteAdmin=false` で緩和）。
- **EOL / 脆弱依存スタック**（R12 / S20）：Struts1.2.9 / commons-beanutils1.7.0 / Spring3.1 / Axis1.4 / Hessian4.0.7 / hsqldb1.8 / xalan2.5.1 …（Struts 有効化で reachability 上昇）。
- **スタックトレース露出**（R9 / S18・error-page 不在）／**Axis 管理 PW をソースに平文**（R15 / S17）／**平文 HTTP＋Cookie フラグ欠落**（R16 / S19）／**版レンジ未固定でビルド非再現**（R17 / S21）。

---

## 3. 独立検証で "落とした" もの（濫造回避 ＝ この手法の価値）

「見つけて終わり」ではなく、3ペルソナが**反証**して過大主張を落としている：

- **Log4Shell 等 log4j 系 CVE** — log4j jar が classpath 不在 → 誤検知として除外。
- **commons-collections で即 RCE** — 同梱は 2.1 で InvokerTransformer 等の functors が不在（実測）→ 「CC ガジェットで即 RCE」は誤り。
- **反射 XSS**（`_01` の L3）— 属性抜けに要る生 `"` はブラウザが percent-encode して届かず**被害者配送不能** → REFUTED。
- **Struts CVE の HTTP 直接悪用**（`_01`）— ActionServlet 未マップで到達不可（＝ Struts を有効化して初めて S1 として昇格）。
- **RCE の "即時性"** — S1 / S13 / S14 は**到達性は確実**だが武器化は環境依存 → 「到達 CONFIRMED / RCE 未実証」に**明確に分離**。
- **getOrder の PII 範囲** — カード番号欄はチェックアウトのダミー（"FAKE"）入力であり、実在カード番号の流出とは誇張しない。

---

## 4. clean だった姿勢（＝ before の基準線）

素の JPetStore が**満たしていた**期待姿勢。after で「維持」を確認する対象でもある：

- **SQL インジェクション無し** — iBATIS は全面 `#param#` バインド（`$…$` 連結は非ユーザ入力の 1 箇所のみ）。
- **稼働 JSP に反射 XSS 無し** ／ **ログイン本体でユーザ名列挙無し** ／ **ログアウトでセッション無効化** ／ **カート価格はサーバ信頼**。
- **ソース内に実効的な秘密なし**（jdbc は HSQLDB 既定の `sa`/空）。

> → 「SQLi / 反射XSS を仕込んで満載に見せる」意図的注入は**不要**と確認できた。本物の穴で十分。

---

## 5. 最も実害の大きい攻撃連鎖 Top3（Phase 4 の回帰テスト第一候補）

1. **無認証 remoting `getOrder` 総当り → 全顧客 PII 一括流出**（R2/S15、+S13/S14 で RCE 昇格余地）── ガジェット不要で"動く"（ライブ実証済み）。
2. **自己登録した攻撃者による水平権限昇格 → セッション汚染 → 完全乗っ取り**（S3 → S2 → S6）。
3. **CSRF 駆動の遠隔乗っ取り**（S5 + S2 + S6）── 被害者の 1 クリック。

---

## 6. after（Phase 3/4）での解消方針

- **remoting/WS 層（Hessian/Burlap/HttpInvoker/Axis）は除去し REST 化**。注文取得は**認証必須＋所有者スコープ**をサービス層で強制。
- Spring Boot 4 / MyBatis / Vue3 のモダン構成で **secure-by-default**（パラメタライズ SQL 継続・出力エスケープ・CSRF 対策・パスワードハッシュ・認可チェック・依存は現行版）。
- Phase 4 で本 before の Top3＋主要 finding を **PoC 自動化（回帰テスト化）** し、新ビルドで「無認証 getOrder が 401/403」「他人注文が 403」等を自動検証＝**"消滅" の実証**。

---

## 付記

- **CVE-2014-0114（S1）のライブ RCE 武器化は実施していない**。理由: (1) 到達可能は既に静的＋多数決で CONFIRMED、(2) 3ペルソナが Tomcat9 での武器化成立に留保、(3) ライブ RCE 武器化は Anthropic の real-time cyber safeguard（Cyber Verification Program）の対象。→ before としては「到達可能 CONFIRMED・武器化未実証」で確定。
- 本書は curated サマリ。**具体的な悪用手順・ガジェット・file:line 詳細・PoC 再現コマンドは `security/` 配下（git-ignore）** にあり、public には載せない。
