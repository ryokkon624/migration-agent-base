# Sprint 9 バックログ

## スプリントゴール

**Epic E2「カート」の secure-by-default ハードニングとして、価格改ざん（マスアサインメント）と CSRF を「攻撃が失敗すること」まで実証する。** Sprint 8（#4）で実装済みのカート REST（価格サーバ権威・BigDecimal・SQL パラメタライズ・CSRF トークン・冪等メソッド割当）を土台に、残る穴を塞ぎ否定AC 回帰テストで固める：

- **#5（F2.2 価格権威）**: 価格系フィールド注入が無視される（AC-neg1）ことを明示回帰テスト化し、数量の明示バリデーションを add/update/merge の全経路で統一する（SBD-2 / SBD-17 の「維持」を実証）。
- **#6（F2.3 CSRF・冪等）**: XSRF-TOKEN Cookie 自体に SameSite=Strict/Secure を付与し（SBD-15）、外部オリジンからの状態変更が拒否されること（AC-neg1）を否定AC 回帰テスト化する。REST 冪等性の明示セマンティクスを固定する（SBD-3）。

- **性格**: 両 Story とも `security` ラベル。**Sprint 4 と同型で「既達の割合が大きい」ハードニング Story**（before で clean だった SBD-2/17 の"維持"実証＋#23 CSRF 基盤の上に積む）。成果物は主に **(a) 未実装の微ハードニング＋(b) 否定AC 回帰テスト**。過剰実装（新規 Origin フィルタ・DTO の破壊的変更）はしない。
- **スコープ**: 変更はほぼ **backend 集中**（SecurityConfig / DTO 検証 / Groovy+Spock テスト）。frontend は既に CSRF 自動ヘッダ・サーバ権威値表示を充足済＝原則ノータッチ（必要なら httpClient/cart のテスト追記のみ）。database は無変更。**1-repo 主体（backend）**の見込み。

---

## 対象Issue

| Issue | タイトル | Epic/Feature | SP | ラベル |
|-------|---------|--------------|-----|--------|
| #5 | [E2] カートの価格はサーバ権威・クライアントは数量のみ受理する | E2 / F2.2 | 3 | `security`, `E2` |
| #6 | [E2] カート状態変更に CSRF 対策を施し REST 冪等性を整理する | E2 / F2.3 | 3 | `security`, `E2` |

- GitHub Issue: `ryokkon624/jpetstore-manage#5`, `#6`（いずれも Sprint=9, SP=3, Ready）
- ブランチ（backend・複数Issue1ブランチ方針＝Sprint55確立）: `feature/5-cart-price-csrf-hardening`
- 挙動spec: `spec/behavior/cart.md` §3, §5 ／ 横断NFR: `spec/security-baseline.md`（SBD-2, SBD-3, SBD-15, SBD-17）
- 台帳（維持項目・**差分でない**）: カート価格サーバ権威（SBD-2）／SQLi 無（SBD-17）は台帳 補足の「維持項目」＝Phase 4 で"維持"を検証。**今スプリントは台帳追記なし**（計画フェーズ確定事項②で 0=削除セマンティクスを維持＝非等価変更なし）。

---

## Issue #5 Body（全文転記）

### ユーザーストーリー

**As a** サイト運営者
**I want to** 価格をサーバのマスター値で決定し、クライアントからは数量のみ受理したい
**So that** 価格改ざん（マスアサインメント）を防ぐ

### トレース

- **Epic**: E2 カート（Cart）
- **Feature**: F2.2 価格権威・数量のみ受理
- **挙動spec**: spec/behavior/cart.md §3, §5
- **横断NFR**: spec/security-baseline.md（SBD-2, SBD-17）

### Acceptance Criteria

- [ ] **AC1 (SBD-2)**: 小計・単価はサーバが `Item.listPrice`（マスター価格）から算出。クライアントは価格/itemId 以外の権威値を送れない。受理するのは数量のみ。
- [ ] **AC2**: 数量は正の整数として検証（as-is の `<1` 削除・非数値無視という緩い挙動を、明示バリデーションに）。
- [ ] **AC-neg1 (否定AC / SBD-2)**: リクエストに listPrice/subTotal 等の価格フィールドを注入しても無視され、永続/表示値はサーバ算出値になる。

### 備考

- 優先順位の根拠: before clean の姿勢を SBD-2 として明文化・維持。
- 依存関係: #4（F2.1）。

---

## Issue #6 Body（全文転記）

### ユーザーストーリー

**As a** 買い物客
**I want to** カートの状態変更が正規のリクエストのみ受理されるようにしたい
**So that** CSRF による意図しないカート操作を防ぐ

### トレース

- **Epic**: E2 カート（Cart）
- **Feature**: F2.3 カート変更の CSRF・冪等整理
- **挙動spec**: spec/behavior/cart.md §5
- **横断NFR**: spec/security-baseline.md（SBD-3, SBD-15）

### Acceptance Criteria

- [ ] **AC1 (SBD-3)**: add/update/remove の状態変更に CSRF トークン必須＋Origin/SameSite 検証。GET で状態変更しない。
- [ ] **AC2**: REST 冪等性を整理（例: update/remove は冪等、add は明示セマンティクス）。
- [ ] **AC-neg1 (否定AC / SBD-3)**: 外部オリジンからの add/update/remove が拒否される。GET でのカート変更リンクが存在しない。

### 備考

- 優先順位の根拠: 横断 SBD-3 のカート具体化。
- 依存関係: #4（F2.1）／#23（E6.2 CSRF基盤）。

---

## 計画フェーズ確定事項（SM 計画フェーズ AskUserQuestion・2026-08-16）

> spec/AC が**実装レベルに委譲・かつ #4/cart.md と衝突**していた2論点を、SM が計画前 Explore 調査（下記「既達 vs 未実装」）を踏まえてユーザー承認で確定。reviewer churn とスコープ後出しを防ぐ。

**① #6 Origin/SameSite 検証の充足方針 = SameSite＋トークンで充足（新規 Origin フィルタは追加しない）**
- XSRF-TOKEN Cookie（現状 `CookieCsrfTokenRepository.withHttpOnlyFalse()` で SameSite/Secure 未付与）に **SameSite=Strict＋Secure** を付与（`setCookieCustomizer`）。JWT Cookie（access/refresh）は既に Strict/Secure/HttpOnly。
- 既存の CSRF token double-submit（cookie-to-header 非XOR）＋ SameSite=Strict を「Origin/SameSite 検証」の充足とする。**明示 Origin/Referer 検証フィルタ・allowlist は追加しない**（Spring Security 推奨防御そのもの・secure-by-default・低複雑度）。
- 外部オリジン拒否（AC-neg1）は、攻撃者が XSRF-TOKEN Cookie を読めず `X-XSRF-TOKEN` ヘッダに載せられない＝403 になることを **否定AC 回帰テスト**で実証する。
- **根拠**: 攻撃者(evil.com)は SOP で被害者の XSRF-TOKEN Cookie を読めない→ヘッダ照合に失敗。SameSite=Strict＋Secure が Cookie 上書き（サブドメイン乗っ取り・HTTP MITM）経路を塞ぎ、double-submit の古典的弱点を解消。JWT Cookie も同じ same-site 前提のため整合。

**② #5 数量の明示バリデーション統一 = update の「0=削除」は維持・緩い黙殺だけを明示400化**
- **update**: `quantity=0` は「行削除」の**明示 REST セマンティクスとして維持**（#4 AC2・cart.md §2「数量 <1 は行削除」準拠＝意図挙動）。ただし **負数・非数値・欠落は 400 で明示拒否**（現状 `int quantity` に @Min なし・緩い扱い）。
- **merge**: `quantity<=0` の**黙殺を廃止し 400 拒否**（merge 行は正の数量のみ受理）。現状 `<=0` を無視している緩い挙動を明示検証に置換。
- **add**: `@Min(1)`＋`<=0` を 400 拒否は**既達（Sprint 8 sec 修正）**。維持。
- **台帳追記なし**: 意図的な 0=削除セマンティクスは spec 準拠で残す＝外部挙動の非等価変更なし。緩い黙殺の明示化は"堅牢化"であり差分ではない。

**③ #5 unknown フィールドの扱い（ユーザー確認不要・SM 判断）**
- typed record DTO（itemId/quantity のみ）＋ Jackson 既定で**未知フィールドは無視**。AC-neg1 の「注入しても**無視され**」に literal 準拠。**グローバルな `FAIL_ON_UNKNOWN_PROPERTIES` は導入しない**（他 EP を破壊し得る）。価格注入が無視されサーバ算出値が返ることを回帰テストで実証する。

---

## 既達 vs 未実装（計画前 実地調査・Explore／backend 主体）

> Sprint 8（#4）実装は3リポジトリ全て `main` にマージ済（backend `04eed38` / frontend `0d14e33` / database `1152cf2`）。カート価格サーバ権威・CSRF 基盤は概ね完成しており、本スプリントは残る穴の充足＋否定AC 回帰テストが主。

### Story #5（価格サーバ権威・SBD-2/17）

| 状態 | 内容 | 根拠 |
|---|---|---|
| ✅ 既達 | リクエスト DTO に価格系フィールドなし（itemId/quantity のみ・typed record・Jackson 既定で未知フィールド無視） | `CartController.java`（`AddCartItemRequest(@NotBlank itemId, @Min(1) quantity)` 他） |
| ✅ 既達 | 単価・小計はマスター価格由来のサーバ算出・BigDecimal（SBD-13） | `CartCustomMapper.xml` `selectCartItems`（`m_item.list_price` JOIN）・`CartApplicationService`・`Cart.java` |
| ✅ 既達 | add 経路の数量下限（`<=0`→400）＋オーバーフロー（`Math.addExact`）＋在庫上限拒否 | `CartApplicationService`（Sprint 8 sec 修正 `ea9102b`） |
| ✅ 既達 | SQL 全パラメタライズ（SBD-17・`${}` 連結なし） | `CartCustomMapper.xml` |
| ✅ 既達 | 小計サーバ計算・add 数量下限・オーバーフロー・在庫上限の回帰テスト | `CartControllerSpec.groovy` / `CartApplicationServiceSpec.groovy` |
| 🔨 未実装 | **AC-neg1: 価格フィールド注入が無視される明示回帰テスト**（新規） | 価格注入ケースが既存テストに無い。`{itemId,quantity,listPrice,subtotal,...}` POST→レスポンスの単価/小計がマスター値になることを assert |
| 🔨 未実装 | **AC2: update/merge の数量バリデーション統一**（確定事項②） | update=`int`（@Min なし・負数/非数値が緩い）・merge=`<=0` 黙殺。→ update は負数/非数値/欠落を 400、merge は `<=0` を 400（0=削除は update のみ維持） |

### Story #6（CSRF・冪等・SBD-3/15）

| 状態 | 内容 | 根拠 |
|---|---|---|
| ✅ 既達 | CSRF 有効・cookie-to-header 非XOR・`/api/cart/**` 認証必須＆非GET は CSRF 必須 | `SecurityConfig.java`（`CookieCsrfTokenRepository.withHttpOnlyFalse()`＋`CsrfTokenRequestAttributeHandler`）・`CsrfCookieFilter.java` |
| ✅ 既達 | 冪等メソッド割当（view=GET・add=POST `/items`・update=PUT `/items/{itemId}`・remove=DELETE `/items/{itemId}`・merge=POST `/merge`）。**GET で状態変更なし** | `CartController.java`・frontend `CartView.vue`/`cartApi.ts` |
| ✅ 既達 | frontend が CSRF ヘッダを自動付与（非冪等メソッドに `X-XSRF-TOKEN`） | `httpClient.ts` |
| ✅ 既達 | JWT Cookie（access/refresh）の SameSite=Strict/Secure/HttpOnly（SBD-15） | `AuthCookieSupport.java` |
| ✅ 既達 | CSRF 欠落拒否の回帰テスト（カート・403） | `CartControllerSpec.groovy`・`CsrfCookieFilterSpec.groovy`・`AuthCookieSupportSpec.groovy` |
| 🔨 未実装 | **SBD-15: XSRF-TOKEN Cookie 自体に SameSite=Strict/Secure を付与**（確定事項①） | `CookieCsrfTokenRepository.withHttpOnlyFalse()` は既定で SameSite/Secure を付けない。`setCookieCustomizer` で付与＋Set-Cookie 属性を assert |
| 🔨 未実装 | **AC-neg1: 外部オリジン拒否の回帰テスト**（新規・確定事項①） | 現状は「CSRF トークン欠落→403」のみ。トークンを載せられない外部オリジンシナリオ（Origin 付き cross-origin）が 403 になることを assert |
| 🔨 未検証（任意） | AC2 冪等性の明示回帰テスト（PUT/DELETE 2回で同結果）・GET 変更リンク不在の担保 | 実装済みだがテスト観点なし。冪等性テストは追加推奨、GET リンク不在はコンポーネント/実装レビューで担保 |

**総括**: #5 は残 2 点〔価格注入テスト新規・update/merge 検証統一〕、#6 は残 3 点〔XSRF Cookie の SameSite/Secure・外部オリジン拒否テスト新規・冪等性テスト任意〕。いずれも backend 集中で小さい。**否定AC 回帰テスト（Phase 4 の種）が本スプリントの主成果物**。

---

## リスク・チャレンジ

### リスク

1. **「既達が大きい＝過剰実装しやすい」**（Sprint 4 教訓）: AC 文言に literal 準拠しようと新規 Origin フィルタ・グローバル `FAIL_ON_UNKNOWN_PROPERTIES` 等を足すとスコープ逸脱＆他 EP 破壊のリスク。計画フェーズ確定事項①②③で「足さない範囲」を明示済。DEV は確定範囲を超えない。
2. **update の 0=削除セマンティクスと #5 AC2 の衝突**: 確定事項②で「0=削除維持・緩い黙殺のみ明示400化」に決定済。DEV は既存 `updateItem`/`merge` の分岐を壊さず、負数/非数値/欠落だけを 400 化する（`update` の 0→削除パスは温存）。
3. **XSRF-TOKEN Cookie 属性変更の副作用**: `setCookieCustomizer` で SameSite/Secure を付けると、既存の frontend CSRF prime（`httpClient` の `/api/ping` prime）や統合テストの Cookie 読取に影響し得る。統合テストで Set-Cookie 属性と CSRF フロー（欠落→prime→リトライ）の双方を green に保つ。
4. **否定AC 回帰テストの「攻撃再現」の忠実性**: 外部オリジン拒否は「XSRF Cookie を読めない＝ヘッダ照合失敗で 403」を再現する。MockMvc で Cookie 無し/不一致ヘッダのケースを組み、"実際に攻撃が失敗する"ことを assert（Phase 4 の種として流用可能な形に）。

### チャレンジ

- **C1（否定AC 回帰テスト＝Phase 4 の種の先取り）**: これまでの feature/domain Story は「機能実装＋肯定AC」が主だったが、本スプリントは **security Story で否定AC（攻撃が失敗する）が主成果物**。価格注入無視・外部オリジン拒否を、Phase 4 verify でそのまま流用できる回帰テストとして書けるか（Sprint 8 の addItem sec 修正で書いた否定テストの発展）。
- **C2（tier 分離 9 スプリント連続）**: 計画=Opus（論点洗い出し→ユーザー承認）／実装=Sonnet（TDD）を継続（8スプリント連続で手戻りゼロ）。現行 Opus 4.8 が最新のため新モデル提案はなし。
- **C3（先例再利用・security 土台）**: #23 で固めた CSRF 基盤（`CookieCsrfTokenRepository`・`CsrfCookieFilter`・`AuthCookieSupport`）と Sprint 8 の否定テスト作法を無改造で活かせるか。

---

## Definition of Done（このスプリント）

- **#5**: AC1（既達を回帰テストで固定）・AC2（add 既達＋update/merge を確定事項②どおり明示検証）・AC-neg1（価格注入無視の新規回帰テスト green）。
- **#6**: AC1（既達 CSRF＋XSRF Cookie の SameSite/Secure 付与）・AC2（冪等メソッド割当を維持＋冪等性テスト）・AC-neg1（外部オリジン拒否の新規回帰テスト green・GET 変更リンク不在）。
- 3観点レビュー（規約/セキュリティ/パフォーマンス）で指摘なし（または対応済）。**runtime/security に触れるため sec レビューは必須**。
- backend: 統合テスト green・`./gradlew compileJava` green・`./gradlew spotlessApply` 済・IDE 警告ゼロ。CSRF フロー（欠落→prime→リトライ）が回帰で壊れていないこと。
- frontend: 変更した場合のみ Vitest green・`npm run format` 済（原則ノータッチ）。
- 台帳追記なし（確定事項②＝非等価変更なし）を Sprint Review で明示。
- ブランチ `feature/5-cart-price-csrf-hardening`（backend）＋ PR。**`closes ryokkon624/jpetstore-manage#5` と `closes #6` を同一 backend PR に集約**（両 Story とも backend capstone）。frontend を変更した場合は同名ブランチ＋従 PR（`Related:`）。
