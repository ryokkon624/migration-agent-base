# Sprint 10 バックログ

## スプリントゴール

**E3 注文導線の入口を開通する。** カート確認 →（アカウントからプリフィル・上書き可の）配送/請求先入力 →（任意）別配送先入力 → 内容確認、の一連を **Vue3 SPA ウィザード＋REST** で提供する。**確定前段まで**（注文送信・在庫原子引当・永続化は #8/F3.2）を、secure-by-default（**認証必須・CSRF・GET での状態変更なし・空カートでは進入不可**）で成立させる。

## 対象Issue

| Issue | タイトル | ラベル | SP | ブランチ |
|-------|---------|--------|----|---------|
| #7 | [E3] チェックアウト・ウィザード（カート確認→配送/請求先→確認）を提供する | feature / E3 | 8 | `feature/7-checkout-wizard`（**cross-repo: frontend 主 + backend 従、同名ブランチ**） |

---

## 計画フェーズ確定事項（AskUserQuestion 2026-08-16 / ユーザー承認済）

spec/AC が実装レベルで委譲していた 3 論点を計画で確定（E4 プロフィール #13/#14 未着手のため住所プリフィルの上流提供者が不在＝cross-repo 化の分岐）。

1. **住所プリフィル源 = cross-repo で住所API新設**
   - backend に**読み取り専用**の住所/氏名返却API（例 `GET /api/account/me`）を新設し、frontend で配送/請求先を初期表示。**#7 = 2-repo（frontend 主 + backend 従）**。
   - 実装: **custom mapper/entity で `m_account` を SELECT**（`AccountAuthCustomMapper` と同方式・手書き。MyBatis Generator は m_account 非対象）→ application service → controller → レスポンスDTO（氏名・住所各項目・email・phone）。
   - **SecurityConfig 無変更**（`anyRequest().authenticated()` で GET が自動保護。permitAll に足さない。GET のみゆえ CSRF 追加設定も不要）。
   - **read-only に厳格に絞る**（E4/F4.2 の編集側と重複させない。E4 は後日この custom entity 上に update を足せる）。
   - 台帳: プリフィルはレガシー（session account からのプリフィル）と**挙動等価**＝新規 intended-diff なし。支払/courier は既存 ID-8/ID-21 で被覆済。

2. **#7/#8 スコープ境界 = 確定前段まで・送信は #8 で配線**
   - #7 は**内容確認画面まで**実装。『注文確定』ボタンは**無効/プレースホルダ表示**（現行 CartView の "Coming soon" と同型のステージング）。
   - **実際の送信（POST /api/orders）・在庫原子引当・永続化は #8/F3.2 で配線**。**#7 で order 送信 API は作らない**。
   - 根拠: Feature 境界（F3.1=ウィザード／F3.2=確定）＋ AC4「**確定前段**の遷移」。DEV は #8 のスコープ（t_order 書き込み・在庫減算）に食い込まないこと。

3. **ウィザード下書き保持 = Pinia のみ（揮発）**
   - 入力途中の下書き（入力済み住所・別配送フラグ・現在ステップ）は **Pinia ストアにインメモリ保持**。リロードで消失してよい（カートはサーバ永続＝再入場でカート再取得＋住所再プリフィル）。
   - サーバ権威は確定時（#8）に集約。**backend に下書きテーブルは作らない**。

### その他の計画方針（既存規約・調査から確定・質問不要）

- **AC-neg1 の実施層 = frontend**: 注文フォーム進入前に**カート非空をステップ/ルートガードで検証**し、空/不在なら正規化エラー（as-is failure 文言相当）→ カートへ誘導。backend での強制は #8。
- **認証復帰の再利用**: 注文フォーム以降のルートに `meta.requiresAuth: true` を足すだけで、**元URL退避→サインオン誘導→復帰**が効く（Sprint5 #24 完成済・新規配線不要）。カート表示/カート確認は公開でよい（spec §1）。
- **在庫警告の表示流用**: cart データの `stockStatus`/`exceedsStock` を確認ステップで警告表示に流用可（表示のみ。在庫の実強制は #8）。

---

## Issue #7 本文（転記）

### ユーザーストーリー

**As a** 認証済みの購入者
**I want to** カート内容の確認から配送/請求先入力、内容確認まで一連で進めたい
**So that** 迷わず注文を完了できる

### トレース

- **Epic**: E3 注文（Checkout & Orders）
- **Feature**: F3.1 チェックアウト・ウィザード
- **挙動spec**: `spec/behavior/order.md` §1, §2.1
- **横断NFR**: `spec/security-baseline.md`（SBD-3, SBD-15）

### Acceptance Criteria

- [x] **AC1**: カート確認→注文情報入力（配送/請求先はアカウントからプリフィル・上書き可）→（任意）別配送先入力→内容確認、の一連を Vue3 SPA ウィザード＋REST で提供（JSPマルチステップpostback廃止）。
- [x] **AC2**: newOrderForm 相当は **サインオン必須**。未認証は元URLを退避のうえサインオン誘導し、成功後に復帰（E5 と連携）。
- [x] **AC3**: 支払は **カード入力欄を置かず** 明示プレースホルダ表示（承認済 F3.6）。courier/locale の入力欄は撤去（PO決定）。
- [x] **AC4 (SBD-3/SBD-15)**: 確定前段の遷移は CSRF 前提、状態変更は GET リンクで行わない。
- [x] **AC-neg1 (否定AC)**: カートが空/存在しない状態で newOrderForm に進めない（正規化エラー、as-is の failure 文言相当）。

### 備考

- 優先順位の根拠: 注文導線の入口。E2 完了後。
- 依存関係: #4-#6（カート）／#8（F3.2）／#18（認証）／#13-#14（プロフィール）／#24（E6.3）。
- PO決定（Refinement 2026-08-11）: courier/locale 入力撤去・支払プレースホルダ。

---

## 事前実地調査（既達 vs 未実装）サマリ

### 既達（再利用でスコープを絞る）

- **カート確認ステップ**: `GET /api/cart`（`CartController`）で items・サーバ計算 subtotal・数量・単価(listPrice)・行合計(lineTotal)・商品名・在庫ステータスを取得可能。**backend 追加不要**。プリンシパル導出（IDOR 面ゼロ）。
- **認証ゲート＋元URL退避/復帰**: `authGuard.ts` + `redirectValidator.ts`（相対のみ・制御文字排除）+ `SignonView`。route に `meta.requiresAuth:true` を足すだけ。
- **httpClient**: CSRF cookie-to-header（`XSRF-TOKEN`→`X-XSRF-TOKEN`・非冪等自動付与・consume-then-regenerate）＋ silent refresh。将来の送信 POST も自動 CSRF。
- **Pinia cart ストア**: `displayItems`/`subtotal`/`itemCount`・server/anon マージ済。ステップ1のデータ源。
- **CSS**: `main.css` に **checkout stepper**（`.jps-steps`/`.jps-step`/`.jps-step-done`/`.jps-step-current`）＋フォーム一式（`.jps-field`/`.jps-label`/`.jps-input`/`.jps-select`/`.jps-required`/`.jps-error-text`）・ボタン・カード・alert・table・empty/error。**新規CSSほぼ不要**。
- **定数**: `code.constants.ts` に `ORDER_STATUS`/`CARD_TYPE`。i18n は `cart.*` あり（`cart.checkout` ボタンは現在 disabled＝入口フック）。
- **DB**: `m_account`（住所全項目：first_name/last_name/address1/address2/city/state/postal_code/country/phone/email）・`t_order`/`t_order_line`/`t_inventory` は作成済（テストフィクスチャに住所実データあり）。
- **SecurityConfig**: `anyRequest().authenticated()`＝新 GET は自動保護・無変更で成立。

### 未実装（#7 の新規作業）

- **backend（従）**: プリフィル用の**住所/氏名返却 read-only API 1本**（custom mapper/entity で m_account SELECT → service → controller → DTO）。
- **frontend（主）**: ウィザード container＋3ステップ（カート確認 / 配送・請求先入力 / 内容確認）・住所入力フォーム部品・**order/checkout Pinia ストア**（下書き揮発）・`orderApi`/`accountApi` クライアント・order/account domain 型・i18n `checkout.*`/`order.*` キー（ステップ・住所/支払各ラベル・検証/確認文言）・ウィザードのルート追加・CartView の checkout ボタン活性化。

---

## リスク・チャレンジ

- **cross-repo（frontend 主 + backend 従）**: 各 repo に同名ブランチ `feature/7-checkout-wizard`＋各 PR。`closes ryokkon624/jpetstore-manage#7` は**主=frontend PR に集約**、従=backend PR は `Related:`（Sprint5/6 の frontend 主パターン）。
- **スコープ規律**: backend 作業は「read-only 住所API 1本」に厳格に限定（E4 編集側・#8 送信/在庫を先取りしない）。「既達が大きい」ため過剰実装を避ける（Sprint4/9 型）。
- **否定AC 先回り**: AC-neg1（空カート進入不可）・AC4（GET 状態変更なし・確定前段 CSRF）・AC3（カード欄なし・courier/locale 撤去）を reviewer 起動プロンプトで具体指定し churn を防ぐ。
- **チャレンジ（C1 先例再利用）**: CSS stepper・フォーム kit・cart ストア・httpClient CSRF・api-module/Vitest パターンを無改造再利用できるかを実証（Sprint7-9 の先例再利用成功の継続）。
- **チャレンジ（モデル tier 分離）**: 計画=Opus 4.8（最上位）／実装=Sonnet（最新・高速）。tier 分離 10 連続の継続。新モデルのリリースは現時点なし。
