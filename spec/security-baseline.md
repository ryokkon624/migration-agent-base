# security-baseline — secure-by-default 横断NFR（E6）

> before ベースライン（[`reports/before/baseline-summary.md`](../reports/before/baseline-summary.md)、run `_01`/`_02` の 17〜21 findings）から導いた、**全 Epic 横断の secure-by-default 非機能要件**。
> 各ドメインの Feature/Story は本書の NFR を参照し、**PO が各 Story の AC に落とす**。各 NFR は「検証可能なアサーション」＋「before 由来」＋「Phase 4 回帰テストの種」で書く。
> リビルド（`jpetstore-backend`/`frontend`）は**これらを設定し忘れても安全（secure-by-default）**な形で作る。

## 使い方
- ドメイン spec（例 `behavior/order.md` §5）は**ドメイン固有の穴**を書き、横断部分は本書を参照。
- PO は Story 作成時、該当する SBD-x を **AC 化**（否定AC＝「攻撃が失敗すること」を含める）。
- Phase 4（verify）は「回帰テストの種」を自動テスト化し、before の PoC が **消えたこと**を実証。

## 横断NFR

| ID | 要件（検証可能なアサーション） | before 由来 | Phase 4 回帰テストの種 |
| --- | --- | --- | --- |
| **SBD-1 認可はサービス層・チャネル非依存・プリンシパル基準** | 認可判定は**認証プリンシパル**から行い、**リクエストで束縛される値（form/param）を認可に使わない**。REST/内部呼び出しなど**呼び出しチャネルに依らず**サービス/ドメイン層で強制。 | S3, S15/R2 | `?account.username=他人`/無認証 API → 自分の資源のみ・他人は403 |
| **SBD-2 マスアサインメント防止（allowlist バインド）** | 受理するのは**編集可フィールドの allowlist のみ**。サーバ権威フィールド（価格・合計・所有者・ID・状態 等）は**クライアント値を無視**しサーバが決定。 | S4/R4, S2/R3 | `totalPrice=0.01`/`username=他人` 注入 → 永続値はサーバ決定 |
| **SBD-3 CSRF 対策・状態変更は非冪等POST** | 状態変更は **CSRF トークン必須**＋Origin/SameSite 検証。**GET で状態変更しない**。 | S5/R6（＋確定GET） | 外部オリジンからの state 変更 → 拒否／GET 確定リンクは存在しない |
| **SBD-4 セッション管理** | ログイン成功時に**セッションID 再生成**（固定化防止）、ログアウトで無効化。（Cookie フラグは SBD-15 に集約） | S8/R7 | ログイン前後で session id が変わる |
| **SBD-5 パスワード保護** | パスワードは**ハッシュ＋ソルト**（bcrypt/argon2 等）で保存・比較。平文保存/平文比較しない。 | S7/R5 | DB 内に平文が無い・既定弱資格情報を排除 |
| **SBD-6 認証の堅牢化** | レート制限/ロックアウトあり。**弱い既定資格情報をプリフィルしない**。資格情報は POST body のみ（GET/URL で受理しない）。認証エラーは**一律メッセージ**（ユーザ列挙不可、登録含む）。 | S10/R10, S11/R13, S12/R14 | 総当り抑止・`?username&password` GET 不可・存在弁別不可 |
| **SBD-7 逆シリアライズ/リモーティング面の廃止** | 無認証ネイティブ逆シリアライズ・WS デモ面（Hessian/Burlap/HttpInvoker/Axis）を**残さない**。外部 API は REST・認証必須。 | S1(CVE-2014-0114), S13/S14, S16 | 旧 remoting/axis エンドポイントが 404・deser 経路なし |
| **SBD-8 識別子・列挙対策** | 外部識別子は**非連番/不透明**、**または** not-owned と not-found を**同一 403/404**に統一し存在推測を封じる。 | 新規NFR（連番 orderId＋弁別応答） | 他人ID と不存在ID の応答が区別不能 |
| **SBD-9 オープンリダイレクト対策** | リダイレクト先は**allowlist/相対のみ**。生パラメータを `sendRedirect` しない。 | S9/R11 | `forwardAction=//evil` → 外部遷移しない |
| **SBD-10 エラー処理・情報漏えい防止** | 例外で**スタックトレース/内部パス/版数を露出しない**。not-found/不正入力は正規化した 4xx に。 | S18/R9 | 不正 orderId 等で 500+trace が出ない |
| **SBD-11 秘密管理** | 認証情報・鍵を**ソース/リポジトリに置かない**（環境/シークレットストア）。 | S17/R15 | ソースに平文 admin PW 等が無い |
| **SBD-12 依存の健全化** | **保守された現行版**を使い EOL を排除、**版固定**（レンジ非固定にしない）。 | S20/R12, S21/R17 | 既知重大 CVE のある版・EOL が無い |
| **SBD-13 金額の正確性** | 金額は `BigDecimal`/`decimal` で扱う（`double` を使わない）。 | fidelity/completeness 指摘 | 丸め誤差が出ない |
| **SBD-14 監査ログ** | **認可失敗**と**状態変更（注文作成等）**を監査ログに記録（誰が/何を/結果）。 | 新規NFR（IDOR 多発） | 認可拒否・注文作成が記録される |
| **SBD-15 トランスポート** | TLS 前提、機微 Cookie に **Secure/HttpOnly/SameSite**。 | S19/R16 | 平文 HTTP・Cookie フラグ欠落が無い |
| **SBD-16 機微操作の再認証** | パスワード変更等の機微操作は**現在パスワード確認/再認証**を必須にする。 | S6 | 現在PW 無しでの PW 変更 → 拒否 |
| **SBD-17 SQLi 対策の維持** | 全 SQL を**パラメタライズ**（プレースホルダ）で発行。文字列連結でクエリを組まない。 | before clean（維持） | 入力に SQL メタ文字 → 注入不成立 |
| **SBD-18 XSS 対策（出力エスケープ）** | 動的出力を**文脈に応じてエスケープ**（フレームワーク既定を無効化しない）。**レガシーの HTML 内包列**（`product.description`・`bannerdata.bannername`＝as-is は `escapeXml=false`）は **HTML を継承せず plaintext 化**し、画像は**新規アセットに分離**（生 HTML を出さない＝sanitize 不要）。 | before clean（維持）＋ L1 seam | 反射/格納 XSS が実行されない（HTML 描画面が消える）|

> 注: **SBD-8 / SBD-13 / SBD-14** は before の直接 finding ではなくモダン化で足す correct/secure-by-default 追加（過大評価しない）。**SBD-17 / SBD-18** は before で clean だった姿勢の**維持**（Phase 4 で"維持"を検証）。支払（実カード非保持）は各ドメイン（例 F3.6）でドメイン固有に具体化。
> **認証トークン方針（決定）**: JWT を **httpOnly Cookie** に保管（**localStorage 不使用**＝XSS でトークンを盗ませない）＋短命＋refresh で失効を担保。Cookie 方式ゆえ CSRF（SBD-3）必須。SBD-4（セッション/認証状態管理）と一体で担保。
