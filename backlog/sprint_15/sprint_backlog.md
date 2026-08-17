# Sprint 15 バックログ

## スプリントゴール

**E3（注文）の残セキュリティ/支払 Story を「回帰テストで固定＋明文化」で secure-by-default を実証し、E2 のカートマージ N+1 をバッチ取得へ retrofit する。既達資産を無改造再利用し、意図的設計を明記して 3観点＋SM verification クリーンを狙う（tier分離15連続）。**

- **#11 remoting/WS 面の廃止（実証）**: モダン backend には remoting/WS 面が構造的に不在・注文取得は認証必須 REST＋サービス層 channel-independent 認可（#9/#10/#21 で既達）。今スプリントは **remoting 面不在を assert する回帰テスト＋「REST のみ露出」の明文化**で、AC1/AC-neg1 の「実証」を満たし将来の退行を封じる（Sprint4 SBD-9〔sink 不在を回帰テストで固定〕と同型）。
- **#12 支払プレースホルダの確定**: backend はカード非保持が完全既達・frontend はプレースホルダ表示も既達（#7/#8）。今スプリントは **(a) カード項目非存在の回帰テスト（backend/frontend）、(b) プレースホルダ文言を ID-8 の意図に合わせて確定、(c) 孤立カード型残骸の撤去**。
- **#28 カートマージ N+1 → バッチ取得**: `CartApplicationService.merge` のループ内 N+1 を、バッチマッパー `selectItemsForCart` ＋ `findStocks` で1クエリに集約。挙動不変（加算・在庫クランプ・quantity≤0→400・overflow は `Cart.mergeLine` 集約済でノータッチ）。
- **cross-repo 2-repo**（backend＋frontend）。**database ノータッチ確定**（m_code 0002 温存）。規模は小〜中の「品質固め」スプリント。

## 対象Issue

| Issue | タイトル | ラベル | SP | スコープ | ブランチ |
|-------|---------|--------|----|---------|---------|
| #11 | [E3] 無認証 remoting/WS の getOrder を廃止し認証必須REST に置換する | security / E3 | ~2 | backend | `feature/12-e3-hardening-cart-perf`（**backend/frontend 同名**） |
| #12 | [E3] 支払をプレースホルダ化し実カード情報を保持しない | feature / E3 | ~3 | frontend＋backend | 同上 |
| #28 | [E2] カートマージの N+1 クエリをバッチ取得に改善する | refactor | 2 | backend | 同上 |

> **1ブランチ集約方針（Sprint 55 確立）**: 3 Issue を各 repo でスタックせず、Issue 単位のコミットを1ブランチに積む。ブランチ名はいずれかの Issue# でよい（ここでは #12 を採用）。
> **cross-repo（2-repo）**: backend・frontend に**同名ブランチ**を切る。database は変更なし。
> **closes 集約**: #11=backend 主（`closes #11`）／#28=backend 主（`closes #28`）／#12=**frontend 主（capstone=プレースホルダ表示・`closes #12`）＋backend 従（`Related: #12`）**。

---

## 計画フェーズ確定事項（ユーザー承認済 2026-08-17）

### 委譲論点 → AskUserQuestion 2026-08-17 で確定

- **Q1（#11 の進め方）= 回帰テスト＋明文化で固定**: remoting/WS エクスポータ Bean 不在を assert する回帰テストと、「露出面は REST（`presentation.rest`）のみ・remoting/WS 面を構造的に持たない」旨の明文化（`package-info.java` または README）を追加。コード削除対象は無い（構造的解消）＝Sprint4 SBD-9 型の「不在を回帰テストで固定」。
- **Q2（#12 支払プレースホルダ文言）= 『扱わない』明示に変更**: 現状 `"Payment details will be added in a future update."`（将来追加ニュアンス）を、ID-8 の意図（実カード情報を保持/処理しない意図的な非等価変更）に沿う文言 **`"This demo does not collect or store card details."`** 系へ差し替える（最終文言は DEV が i18n 規約に沿って調整可・意図＝「扱わない」を明示すること）。
- **Q3（#12 カード型残骸の撤去）= 孤立 enum/定数のみ撤去**（初期確定）→ **DEV 精読後に一部改定（下記 第2ラウンド Q3'）**。**DB の m_code 0002（CardType 区分マスタ雛形）は温存**（cross-repo=database を回避・実カード非保持で無害）＝ **database ノータッチ＝2-repo 維持**。

### DEV 計画報告後の確定（AskUserQuestion 2026-08-17・第2ラウンド／Sprint11 型2段階の後段）

DEV（Opus）が両 repo の実コードを精読し、バックログ前提の訂正と2つのエッジ論点を上げた。ユーザー確定：

- **Q3'（#12 CardType.java の扱い）= 削除しない（温存）**: DEV 精読で backend `domain/enums/CardType.java` は **`EnumGenerator` が m_code 0002（温存確定）から自動生成する生成物**と判明。削除しても `./gradlew generateEnums`（手動タスク・CI 非含）で再生成されるため、**削除は非永続で誤解を生む → 温存**。EnumGenerator に 0002 除外を足すのは新機構＝スコープ外で**やらない**。implementation-notes に「CardType.java は m_code 0002 の生成物ゆえ意図的に温存（カード情報は保持しない・単なる区分マスタ生成物）」と明記。
  - **frontend `constants/code.constants.ts` の `CARD_TYPE`/`CardTypeCode`＋registry `CODE_TYPE.CARD_TYPE:'0002'` も温存に確定（撤去しない）**: DEV が撤去前確認で、この定数群も `jpetstore-database` の `MultiEnumGenerator`（`generateEnums`）が m_code 0002 から生成する生成物と判明（`src/constants/README.md`「手編集禁止・再生成で上書き」＋`jpetstore-database/build/generated/frontend/code.constants.ts` とバイト一致）。手編集撤去は「手編集禁止」違反かつ非永続 → backend 同様に温存＋注記。**結果、#12 のカード型残骸は両 repo とも実削除ゼロ**＝残スコープは (a) card 欠如の回帰テスト（backend/frontend）＋ (b) frontend 文言変更のみ。EnumGenerator/MultiEnumGenerator は無変更。
- **Q2'（#28 重複 itemId の挙動差）= coalesce で厳密に挙動不変**: DEV がバックログ前提「localStorage は itemId キーの **map**」を**訂正**＝実体は `StoredCartLine[]` の**配列**で、dedup は cart ストアの**書込ロジック**（find→更新 or push）が担保し、`cartStorage.loadCart()` は読込時に dedup しない。正規 UI 経由では重複 itemId は構造的に生じないが、localStorage 改竄で重複を仕込むと単純バッチ版は accumulate→last-write-win に変わる（在庫クランプ済・自カートのみで security/正当性影響なし）。**refactor の AC「挙動不変」を厳守するため、`merge` 冒頭で clientLines を itemId で合算（coalesce）してからバッチ取得**する。在庫クランプは単調 min のため coalesce-then-clamp は逐次 accumulate と**厳密パリティ**が成立。`Cart.mergeLine` は無改修。これで改竄入力を含め挙動不変＋security-reviewer の挙動差指摘を先回りで封じる。

### 意図的設計（reviewer 起動プロンプトに「欠落として指摘しない」と明記する項目）

- **#11**: remoting 面は**新規に作らない**（撤去対象コードも無い＝構造的不在）。新規に Origin フィルタ等の追加機構は足さない。SecurityConfig 無変更。成果物は**回帰テスト＋明文化のみ**。
- **#12**: 独立した payment ステップ/画面は**新設しない**（確認ステップ内のプレースホルダで充足＝既達）。カード入力欄・DTO/API/DB のカード項目は**作らない/持たない**（既達）。m_code 0002 は**温存**（撤去対象外）。**backend `CardType.java`・frontend `code.constants.ts`（`CARD_TYPE` 等）とも温存**（いずれも m_code 0002 の codegen 生成物ゆえ・Q3' 確定＝両 repo で card 型の実削除ゼロ）。database 無変更。EnumGenerator/MultiEnumGenerator も無変更。
- **#28**: 単一取得 `findStock` は add/update ユースケースが使うため**残す**（バッチ版 `findStocks` は merge 専用に追加）。書込（`upsertItem`/`removeItem`）はアイテム単位で本質的に必要＝**バッチ化対象外**。ドメイン集約 `Cart.mergeLine`（加算・在庫クランプ・overflow・quantity≤0→400）は**無改修**。merge 冒頭の **coalesce（itemId 合算）は挙動不変を厳守するための意図的処理**（改竄重複入力の last-write-win 化を防ぐ）＝「新規挙動の追加」ではないと明記。

---

## 計画前の実地調査（既達 vs 未実装）サマリ

backend / frontend を Explore で並列調査。**3 Issue とも既達判定が付いており、残作業は「回帰テストで固定＋明文化＋小規模 retrofit」**（Sprint4/9/11/14 型のハードニング／既達が大きい Story パターン）。

### #11（backend）— 無認証 remoting/WS getOrder 廃止

| 項目 | 判定 | 証拠（jpetstore-backend 相対） |
|---|---|---|
| remoting/WS 依存 | **既達（不在）** | `build.gradle:32-86` に Hessian/Burlap/HttpInvoker/Axis/spring-remoting/JAX-WS 一切なし。単一モジュール（`settings.gradle:8`） |
| remoting/WS ソース | **既達（不在）** | `src` 全体 grep で `hessian/burlap/httpinvoker/jax-ws/@WebService/ServiceExporter/RemoteExporter/java.rmi` すべて No matches。露出は `presentation.rest` の `@RestController` のみ |
| 注文取得 REST | **既達** | `OrderController.java:43-73`（GET `/api/orders`・GET `/api/orders/{orderId}`） |
| 認証必須 | **既達** | `SecurityConfig.java:54-83`（permitAll 対象外→`anyRequest().authenticated()`）。実証 `OrderControllerSpec.groovy:415-419/469-476`（未認証→401） |
| サービス層 channel-independent 認可 | **既達** | `OrderApplicationService.java:159-167`→`OwnershipAuthorizationService.java:32-37`→`CurrentUserProvider.java:19-21`。Controller は委譲のみ（認可分岐なし） |
| 不存在/非所有→同一403 | **既達** | `OrderApplicationService.java:163`＋`GlobalExceptionHandler.java:68-75`。実証 `OrderControllerSpec.groovy:451-467` |
| **remoting 不在の回帰テスト** | **未実装（残作業A）** | 全 Spec（52 ファイル）に remoting エクスポータ不在を assert するテストなし |
| **remoting 面不在の明文化** | **未実装（残作業B）** | ADR/`package-info.java`/README いずれも remoting/WS を言及せず |

### #12（backend＋frontend）— 支払プレースホルダ化

| 項目 | 判定 | 証拠 |
|---|---|---|
| backend: DB/DTO/entity/mapper/service にカード項目 | **既達（不在）** | `V00_000_005:11,25-85`（「カード列は持たない（ID-8）」明記）／`OrderController.java:80-148`（DTO 群にカードなし）／`OrderApplicationService.java:96-134`（支払処理なし）。ダミー値 `999...` は本体に不在 |
| frontend: プレースホルダ表示 | **既達** | `CheckoutConfirmStep.vue:92-99`（Payment セクション＝プレースホルダ・カード入力欄なし）／`en.ts:168-170`（`paymentTitle`/`paymentPlaceholder`）。payment 独立ステップは無し（`checkout.ts:34-36`＝cart/address/confirm） |
| backend: カード非存在の回帰テスト | **未実装（残作業）** | Groovy テストにカード欠如の assertion なし |
| frontend: プレースホルダ表示のテスト | **未実装（残作業）** | `components/checkout/__tests__` なし・payment のテスト0件 |
| 文言（ID-8 意図一致） | **要変更（Q2 確定）** | `en.ts:170`「将来追加予定」→「扱わない」明示へ |
| 孤立 `CardType` enum（backend）/`CARD_TYPE` 定数（frontend） | **撤去（Q3 確定）** | `domain/enums/CardType.java:3-27`（未参照）／`constants/code.constants.ts:23-28`（未参照）。m_code 0002（`V00_000_002:47-57`）は温存 |

### #28（backend）— カートマージ N+1 → バッチ取得

| 項目 | 判定 | 証拠 |
|---|---|---|
| N+1 の現状 | **残存（要改善）** | `CartApplicationService.java:106-126`（ループ内 `cartRepository.findStock` を N 回）→`MyBatisCartRepository.java:59-62`（`selectItemForCart` 単発）→`CartCustomMapper.xml:42-50` |
| バッチ化 seam | **設計済** | `CartRepository.java:41-43` javadoc「#28 でバッチ化（`findStocks`）へ拡張できる seam」・`Cart.java:13-17`「#28 のバッチ化を妨げない構造」 |
| `<foreach>` 先例 | **あり** | `CatalogCustomMapper.xml:79-81`＋`CatalogCustomMapper.java:50-57`（`@Param List<String>`） |
| 不変条件（加算/クランプ/overflow/quantity≤0） | **既達（ノータッチ）** | `Cart.java:116-131`（`mergeLine`）＋`CartApplicationService.java:111-113`（quantity≤0 短絡は findStocks より前に維持） |
| クエリ回数証明の UT 先例 | **あり** | `MyBatisCartRepositorySpec.groovy:28-90`（Mapper mock でクエリ回数を `1 * ...` 検証）。「N行でも findStocks 1回」の回帰アサートは未追加 |

---

## Issue 全文（転記）

### #11 [E3] 無認証 remoting/WS の getOrder を廃止し認証必須REST に置換する（security / E3）

**ユーザーストーリー**: サイト運営者として、無認証で注文を取得できる経路を廃止したい。チャネル非依存に所有者スコープの認可を強制できるようにするため。

**トレース**: Epic E3 ／ Feature F3.5 注文取得のセキュア化＋remoting 廃止 ／ 挙動spec `spec/behavior/order.md §2.3(S15), §6` ／ 横断NFR `security-baseline.md（SBD-1, SBD-7）`

**Acceptance Criteria**
- [ ] AC1 (SBD-7): 無認証 remoting/WS（Hessian/Burlap/HttpInvoker/Axis 等）の `OrderService.getOrder` 面を**残さない**。外部APIは REST・認証必須のみ。
- [ ] AC2 (SBD-1): 注文取得の認可はサービス/ドメイン層で**呼び出しチャネル非依存**に強制（Web層チェックに依存しない）。
- [ ] AC-neg1 (否定AC / SBD-7): 旧 remoting/axis エンドポイントが 404（deser 経路が存在しない）。
- [ ] AC-neg2 (否定AC / SBD-1): いかなる無認証チャネルからも他人の注文PIIを総当りできない（before S13-S15 消滅）。

**備考**: 既達判定（Refinement 2026-08-16・確認済）＝新 backend には remoting/WS 面が構造的に存在しない（grep で不在確認）。本Storyは新規削除対象コードを持たず、AC1/AC-neg1 は「remoting 面が存在しないことの明文化＋回帰テストで固定」＝構造的解消（Sprint4 SBD-9 と同型）。AC2 は #9/#10 で注文取得認可をサービス層に置くことの channel-independent 実証に相当。スコープ=backend 専用。依存=#23（E6.2）／#10（F3.4・先行・Sprint14 完了）。

### #12 [E3] 支払をプレースホルダ化し実カード情報を保持しない（feature / E3）

**ユーザーストーリー**: サイト運営者として、実カード番号を扱わず支払を明示プレースホルダにしたい。カード情報の漏えいリスクを排除するため（承認済の非等価変更）。

**トレース**: Epic E3 ／ Feature F3.6 支払プレースホルダ（意図的な非等価変更）／ 挙動spec `order.md §3, §5（支払）` ／ 横断NFR `security-baseline.md（SBD-11 関連）`

**Acceptance Criteria**
- [ ] AC1: カード列・入力欄・必須バリデーションを DTO/API/DB から**除外**。支払は明示的プレースホルダ表示。
- [ ] AC2: 実カード番号を保存しない（as-is のダミー既定値 `999 9999 9999 9999` 等のハードコードも持たない）。
- [ ] AC-neg1 (否定AC): DB/API のどこにもカード番号・有効期限・種別の列/項目が存在しない。

**備考**: 承認済の非等価変更（要ユーザー最終承認済）。意図差分台帳 **ID-8**（登録済み）。既達判定（Refinement 2026-08-16）＝DB のカード列は #22（`V00_000_005`）で既に非保持。残スコープは (a) backend の DTO/API にカード項目が無いことの確認＋回帰テスト、(b) frontend の明示プレースホルダ表示（承認済 F3.6）。スコープ=frontend（プレースホルダ表示）＋backend（DTO/API 非保持の確認）。依存=#22（完了）／#7-#8（完了）。

### #28 [E2] カートマージの N+1 クエリをバッチ取得に改善する（refactor・SP2）

**背景**: Sprint 9（#5/#6）perf レビューで `CartApplicationService.merge(List<CartLine>)` がクライアント側カート各行についてループ内で在庫/価格を1件ずつ問い合わせる N+1 と指摘（Sprint 8=#4 由来の既存問題）。実影響は限定的（マージはログイン時1回・item 数有界）のため非ブロッキングで backlog 繰越。#29（Cart Repository PoC・Sprint12）が全面書き換えた対象と重なるため、**#29 完了後の新コード（`MyBatisCartRepository`）に対する retrofit** として実施。

**改善方針（案）**: バッチ版マッパー `selectItemsForCart(List<String> itemIds, Long cartId)` を追加し、マージ対象アイテムの在庫/価格を1クエリでまとめて取得。ループ内は取得済みマップ参照に変更（在庫クランプ・加算ロジックは現状維持）。既存の否定AC 回帰テスト（数量検証・在庫上限）を壊さない。

**Acceptance Criteria**
- [ ] マージ処理のクエリ回数がカート行数に比例しない（バッチ1回に集約）。
- [ ] 既存のマージ挙動（数量加算・在庫数クランプ・quantity≤0→400・オーバーフロー処理）が回帰しない。
- [ ] 統合テストで N+1 が解消されたことを確認（クエリ回数 or バッチ経路の検証）。

**備考**: 由来=Sprint 9 perf レビュー指摘（Sprint 8 由来の既存問題）。関連=#4（F2.1）／#29（Cart Repository PoC・本Issueの前提・完了）／Epic E2。優先度=低〜中（機能影響なし・login 時1回・item 数有界）。SP=2。

---

## 残作業（想定変更ファイル）

### backend（jpetstore-backend）
- **#11**: 回帰テスト新規（remoting エクスポータ Bean 不在 / classpath に remoting クラス不在を assert）＋明文化（`presentation/rest/package-info.java` 新規 または README 追記）。
- **#12**: カード項目非存在の回帰テスト（`OrderControllerSpec.groovy` 等に「DTO/レスポンスにカード項目なし・余分な `creditCard`/`cardNumber` JSON を送っても無視され応答に card キーなし」）。**`domain/enums/CardType.java` は温存（撤去しない・Q3' 確定）**＝implementation-notes に温存理由を明記。
- **#28**: `CartCustomMapper.java`/`CartCustomMapper.xml` に `selectItemsForCart`（`IN <foreach>`・空リスト短絡）追加／`CartRepository.java`＋`MyBatisCartRepository.java` に `findStocks(Long cartId, List<String> itemIds): Map<String,StockAvailability>` 追加／`CartApplicationService.merge` を「①全行 quantity≤0 検証→②clientLines を itemId で coalesce→③findStocks 1回→④map 参照ループ」へ／テスト（`CartApplicationServiceSpec`＝N行でも findStocks 1回・findStock 0回・coalesce の accumulate パリティ・`MyBatisCartRepositorySpec`＝selectItemsForCart 1回・空リストは mapper 非呼出・`CartCustomMapperSpec`＝実DB複数itemId・`CartControllerSpec` グリーン維持）。

### frontend（jpetstore-frontend）
- **#12**: `i18n/locales/en.ts` の `paymentPlaceholder` を「扱わない」明示文言（`This demo does not collect or store card details.`）へ変更／`components/checkout/__tests__/CheckoutConfirmStep.spec.ts` 新規（プレースホルダ表示・カード入力欄非存在の回帰テスト）。**`constants/code.constants.ts` の `CARD_TYPE` 等は温存（codegen 生成物と確定・撤去しない）**＝implementation-notes に温存理由を明記。

---

## リスク・チャレンジ

- **チャレンジ C1: tier分離15連続の継続**。計画=Opus で spec 委譲論点（Q1/Q2/Q3）を先に確定→実装=Sonnet で手戻りゼロ完走を狙う。現行最上位 tier は Opus 4.8（1M）＝新モデル更新なし。
- **チャレンジ C2: 「既達 Story を回帰テストで固定＋明文化」パターンの確立**。#11/#12 のように「セキュリティ/仕様目的は既達」の Story を、**将来の退行を封じる回帰テスト＋明文化**に振り切る（Sprint4 SBD-9・Sprint9 型ハードニングの発展）。過剰実装（remoting フィルタ新設・payment ステップ新設・m_code 撤去）は計画で禁止済。
- **リスク R1: #28 バッチ化の挙動差（重複 itemId）**。→ クライアント dedup 前提（localStorage が itemId キー map）を明文化し、`Cart.mergeLine` を無改修に保つ。DEV が計画で妥当性を再確認。
- **リスク R2: cross-repo（2-repo）の closes 集約と reviewer スコープ**。→ 各 repo 同名ブランチ・closes は Issue 単位で分散（#11/#28=backend 主・#12=frontend 主）。reviewer には各 repo の変更ファイルを絶対パスで列挙し「working dir は対象ブランチにチェックアウト済み・Read で直接読む」と明示（JPetStore 3 reviewer は Bash 非搭載）。
- **リスク R3: 既達が大きい Story の AC リテラル過準拠**（Sprint9 教訓）。→ 「足さない範囲」を計画で確定済（意図的設計として reviewer プロンプトに明記）。
- **フォロー継続（Sprint14 から）**: `@Transactional(readOnly)` の read メソッド不統一（Account=有／Catalog・Order=無）。今スプリントは read API 新設が無いため直接該当せず。次の同種発生で reviewer チェックリスト昇格 or rules 明確化を判定。
