# backlog-map — Epic → Feature（Phase 2）

Pronghorn 4階層（Epic → Feature → User Story → Acceptance Criteria）のうち、**Epic → Feature までが本書（くろ担当）**。
**Feature → Story → AC は PO が GitHub Project #2（`jpetstore-manage` の Issue）に**起票する。
各 Story 本文に `Epic / Feature` をトレースとして明記。secure-by-default の横断要件は `spec/security-baseline.md` にまとめ、PO が各 Story の AC に落とす。

## Epic 一覧（全体像・順次詳細化）

- **E1** カタログ閲覧（Catalog：カテゴリ/商品/在庫アイテム/検索）
- **E2** カート（Cart：追加/更新/削除/表示）
- **E3** **注文（Checkout & Orders）** ← 本書で詳細化（**見本**）
- **E4** アカウント（Account & Profile：登録/編集/プロフィール）
- **E5** 認証（Auth / Signon：サインオン/サインオフ/保護）
- **E6** 横断：secure-by-default（NFR）／基盤（ターゲットアーキ・DB 移行）

---

## E3 注文（Checkout & Orders）  ※詳細化の見本
挙動 spec: [`spec/behavior/order.md`](./behavior/order.md)／横断NFR: [`spec/security-baseline.md`](./security-baseline.md)

- **F3.1 チェックアウト・ウィザード**
  カート確認 → 注文情報入力（配送/請求先はアカウントからプリフィル・上書き可）→（任意）別配送先入力 → 内容確認、の一連。JSP マルチステップ postback を **Vue3 SPA ウィザード＋REST** に置換。
- **F3.2 注文確定・在庫引当・整合性**
  確定時にサーバが **合計・単価をマスター価格から再計算**（client 値無視）、`username` は**認証プリンシパル**。**在庫は充足チェック付きで原子的に引当**（不足なら注文失敗・負数化させない＝as-is の過剰販売を是正）。在庫減算＋注文永続化を**1トランザクション**、orderId は DB 原子採番。確定は**非冪等 POST＋CSRF**（as-is は GET）。
  ↳ 否定AC種: `order.totalPrice=0.01` → 永続値はサーバ再計算合計 ／ 在庫超過数量 → 注文失敗（負数にならない）。
- **F3.3 注文履歴一覧（本人スコープ）**
  認証ユーザー**本人の注文のみ**。**認可はサービス層でプリンシパル基準**（一覧も identity-rebind 対象＝before S3）。
  ↳ 否定AC種: `listOrders?account.username=他人` → 自分の履歴のみ。
- **F3.4 注文詳細閲覧（所有者限定）**
  `orderId` 指定で**自分の注文のみ**。**認可はサービス層で所有者判定**（フォーム束縛値でなく認証プリンシパル）。**not-owned と not-found を同一 403/404 に統一**（連番ID の存在推測を封じる／or 不透明ID）。
  ↳ 否定AC種: 他人の orderId → 403 ／ 存在しない orderId → 同一応答（現状は NPE 500）。
- **F3.5 注文取得のセキュア化 ＋ remoting 廃止**
  無認証 remoting/WS の `OrderService.getOrder`（before S13–S15、getOrder 単一面）を**撤廃**し、**認証必須＋所有者スコープの REST** に置換。
- **F3.6 支払プレースホルダ（意図的な非等価変更）**
  **カード列・入力欄・必須バリデーションを撤去**（DTO/API/DB から除外）。支払は明示的プレースホルダ。実カード番号は保存しない。

> **意図的な非等価変更（要ユーザー承認）**: 過剰販売防止（在庫充足チェック）・支払カード撤去(F3.6)・金額 `BigDecimal`(SBD-13)。
> **PO へ送る論点（判断待ち）**: ①注文確認メール（`SendOrderConfirmationEmailAdvice`＝legacy 同梱・現状 config 無効：明示ドロップ or 将来Feature）／②`status` 遷移運用（現状 "P" 固定・1行）／③courier・locale の扱い／④一覧ページング要否／⑤注文詳細の商品名表示（as-is は履歴経由で空）。

---

## E1 カタログ（Catalog）
挙動 spec: [`spec/behavior/catalog.md`](./behavior/catalog.md)（全公開・読み取り専用・before clean）

- **F1.1 カタログ階層閲覧**：カテゴリ→商品→在庫アイテムの閲覧（サーバ側ページング）。JSP→Vue3 SPA＋REST。
- **F1.2 商品検索**：複数語 LIKE の部分一致検索（パラメタライズ維持＝SBD-17）、ページング。
- **F1.3 参照の堅牢化・出力安全化**：不正 ID・**stale-session ページング**（viewCategory=throw/viewProduct=NPE/viewItem=NPE）を 404/空へ正規化・trace 非露出（SBD-10）。出力エスケープ維持＋**`product.description` は plaintext 化・商品画像は新規アセット（nano banana 生成）**（SBD-18・意図的非等価。レガシーHTML継承せず）。
> **PO 論点**：検索一致仕様の踏襲／ページサイズ(4)/在庫表示仕様。

## E2 カート（Cart）
挙動 spec: [`spec/behavior/cart.md`](./behavior/cart.md)（全公開・セッションのみ・before clean）

- **F2.1 カート操作**：追加/数量更新（0で削除）/削除/表示。セッションカート→SPA状態＋カートREST（数量更新は明示 {itemId, quantity} API に）。
- **F2.2 価格権威・数量のみ受理**：小計はサーバ計算（`Item.listPrice`）、クライアントは数量のみ（正整数検証）＝SBD-2 維持。
- **F2.3 カート変更の CSRF・冪等整理**：add/update/remove の状態変更に CSRF（SBD-3）、REST 冪等性を整理。
> **PO 論点**：未ログインカートの永続化/マージ／在庫切れの表示・追加可否／数量上限。

---

## E4 アカウント（Account & Profile）
挙動 spec: [`spec/behavior/account.md`](./behavior/account.md)（before findings 集中）

- **F4.1 ユーザー登録**：公開・account/signon/profile 3表・登録後自動ログイン（**セッション再生成**＝SBD-4）。JSP→SPA＋REST。列挙対策は**レート制限＋メール検証**（SBD-6）。
- **F4.2 アカウント/プロフィール編集（本人固定）**：**更新対象を認証プリンシパルに固定**（`username` をクライアントから受けない）＋マスアサインメント allowlist ＝ **S2/S3 是正**（SBD-1/SBD-2）。
  ↳ 否定AC種: `account.username=他人` で editAccount → 他人は更新されない（自分のみ）。
- **F4.3 パスワード変更の再認証**：現在PW確認/再認証必須（SBD-16）＝S6 是正。
- **F4.4 状態変更の CSRF**：登録/編集/PW変更に CSRF トークン・非冪等 POST（SBD-3）＝before Top3 #3（CSRF 乗っ取り）の起点遮断。
- **F4.5 入力検証**：email 形式・最大長・PW 強度（as-is は非空＋一致のみ）。
> **PO 論点**：bannerdata/MyList 機能の要否（**廃止時は login/account 取得クエリの INNER JOIN→LEFT JOIN 化 or 分離が必須**）／status 運用／言語設定／入力検証範囲。

## E5 認証（Auth / Signon）
挙動 spec: [`spec/behavior/auth.md`](./behavior/auth.md)（全 Epic の認可土台）

- **F5.1 サインオン/サインオフ**：ログイン成功時**セッション再生成**（S8）・CSRF（S5）・元URL復帰。
- **F5.2 パスワードのハッシュ化**：ハッシュ＋ソルト保存・照合（SBD-5）＝S7 是正。
  ↳ 否定AC種: DB に平文パスワードが存在しない。
- **F5.3 認証堅牢化**：レート制限/ロックアウト（S10）・既定資格情報プリフィル廃止・**GET 認証廃止**（S11）・**リダイレクト先検証**（S9）。
- **F5.4 保護ゲート＋認可土台**：認証プリンシパル基準の認可（SBD-1）を全ドメインへ提供（identity の完全性が注文/編集の前提）。
> **PO 論点**：認証方式（セッション or JWT）／元URL復帰UX／多言語ログイン。

---

（E6 基盤＝ターゲットアーキ・DB 移行(Flyway)・`security-baseline.md` の適用順序は実装フェーズ E6 で詳細化。**DB 移行の要点**：`signon.password` をハッシュ長へ拡張〔例 varchar(255)〕／account・login 取得の bannerdata **INNER JOIN → LEFT JOIN 化 or クエリ分離**〔さもなくば bannerdata 廃止でログイン破壊〕。**フロント/デザイン方針**：UI は **Claude Design** で新規デザイン、画像は **nano banana** で新規生成〔レガシーの JSP/埋め込み画像・HTML は継承しない〕）
