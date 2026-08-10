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

（E1/E2/E4/E5/E6 は、この E3 と同じ粒度で順次詳細化する）
