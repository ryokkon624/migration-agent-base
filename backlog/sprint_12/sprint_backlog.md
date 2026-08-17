# Sprint 12 バックログ

## スプリントゴール

**jpetstore-backend に初の Repository 層を導入する（Cart 参照実装 PoC）。** Cart bounded context の
`CartApplicationService` から `infrastructure.mybatis.*`（`*CustomMapper` / `*CustomEntity`）への直依存を排除し、
**`domain.cart.CartRepository`（interface・ドメイン語彙）＋ `infrastructure.mybatis.cart.MyBatisCartRepository`（実装・Converter 保持）**
へ依存性逆転する。在庫上限・`Math.addExact` オーバーフロー・merge 在庫クランプ・数量0以下削除の不変条件を、
現状 anemic な `Cart` / `CartItem`（record）＋トランザクションスクリプト（Service）から**集約ドメインメソッドへ移設**する。
在庫qty（`stockQuantity`）は集約内では保持してよいが Application/Presentation の戻り値には出さない（**ID-28 維持**）。
**API・エンドポイント・レスポンス形状・挙動は不変**（内部リファクタのみ）、**3観点クリーン**。
コードベース初の Repository / Converter / `reconstruct()` 実装として、**#30 全体展開・#28 N+1・E4 以降の新規 Story が踏襲する先例テンプレート**を確定する。

## 対象Issue

| Issue | タイトル | ラベル | SP | ブランチ |
|-------|---------|--------|----|---------|
| #29 | [E6] Cart を参照実装に Repository 層導入＋集約化（Application Service の Mapper 直呼び解消・PoC） | E6 / **refactor** | 5 | `refactor/29-cart-repository-poc`（**単一 repo: backend のみ・新規ブランチ**） |

**関連する意図差分台帳**: ID-28（在庫qty 非露出・維持）／ID-17（幽霊行是正＝単一削除経路・維持）／ID-19（マージ加算＋在庫クランプ・維持）。
**いずれも既存の実装済み挙動であり、本 Story は挙動不変のリファクタ。新規 intended-diff の追加は不要**（PO確認事項）。

---

## リファクタ Story の性質（重要・スコープ規律）

- **挙動・API・レスポンス形状は一切変えない**（Issue 明記）。本 Story の成果は「振る舞いを変えない内部構造の是正」であり、
  **既存 Cart 系 AC（#4/#5）を退行させないこと**が完了条件。
- **退行ガード**: 既存の `CartControllerSpec`（Testcontainers E2E・MockMvc）と `CartApplicationServiceSpec`（純 Spock UT）を
  **グリーンのまま維持**する。挙動が変わればこれらが落ちる。
- **リファクタ Story のレビュー原則（scrum-master-workflow ④-3）**: reviewer が指摘したファイルの問題が
  **移動前（main 時点）から存在した既存問題**であれば「既存問題の移動」としてスコープ外と判定する（対応はしない）。
- **非対象**: Catalog / Account / Order の Repository 化（**#30**）／merge の N+1 クエリ解消（**#28**）。ただし
  **Repository 実装が #28 のバッチ化を阻害しない構造**にする（後述 R2）。

---

## 計画前の実地調査（既達 vs 未実装 / drift 実態）サマリ

backend 単一 repo を Explore で調査。結論: **Cart の挙動・不変条件は既に実装済み（#4/#5/#8 で構築）。本 Story は「振る舞いを保ったまま、Service→Mapper 直結合を Repository 経由＋集約へ組み替える」構造リファクタ**。DB スキーマ・API・テストの骨格は既達で、新規作成は Repository/Converter/集約メソッド＋テスト再ターゲットに集約される。

### 既達（現状・是正の対象）

- **`CartApplicationService`**（`application/service/CartApplicationService.java`）: `CartCustomMapper` を直注入し、
  `CartHeaderCustomEntity` / `CartItemCustomEntity` / `CartItemWriteCustomEntity` / `ItemForCartCustomEntity`（すべて infra 層）を
  直 import・使用（§1 違反のドリフト）。不変条件（在庫上限 L71-82/L106-108・`Math.addExact` L74-79/L146-152・
  merge クランプ L146-149・数量0以下削除 L99-102/L153-154/L64-66/L139-141）は**すべて Service 内に手続き的に実装**。
  entity→record 変換は private メソッド（`toCart`/`toCartItem` L193-211）。
- **ドメインモデル**: `Cart`（record・`of()` で subtotal 合算）／`CartItem`（record・qty非露出済＝`stockStatus`/`exceedsStock` のみ）／
  `CartLine`（record・merge 入力 VO）。**いずれも anemic**（不変条件ロジックを持たない）。
- **Mapper**: `CartCustomMapper`（XML・`resources/mapper/custom/CartCustomMapper.xml`）＝ `ensureCart` / `selectCartItems`（全行1クエリ）/
  `selectItemForCart`（単一 itemId 引き）/ `upsertCartItemQuantity` / `deleteCartItem` / `deleteCartItems`。
- **Controller / DTO**: `CartController`（`/api/cart` GET・POST /items・PUT /items/{itemId}・DELETE /items/{itemId}・POST /merge）＋
  Request/Response DTO は Controller 層に閉じている（`CartItemResponse` は在庫qty非露出済）。**変更不要**。
- **在庫系内部値**: `stockQuantity`（`CartItemCustomEntity` L22・`ItemForCartCustomEntity`）／`currentQuantity`（`ItemForCartCustomEntity`）＝
  不変条件判定の入力。現状は infra entity に生存し Service が直読み → **集約へ移設対象**。
- **既存テスト**（分類）:
  | ファイル | 分類 | 役割 |
  |---|---|---|
  | `application/service/CartApplicationServiceSpec.groovy` | **純 Spock UT**（`CartCustomMapper` を Mock・DB非依存） | 4不変条件を DB 無しで検証済み |
  | `infrastructure/.../CartCustomMapperSpec.groovy` | Testcontainers 統合（`IntegrationTestBase`） | SQL 実挙動 |
  | `presentation/rest/CartControllerSpec.groovy` | Testcontainers E2E（MockMvc） | **挙動退行ガード**（在庫超過400・オーバーフロー・merge クランプ・0削除） |

### 未実装（本 Story の新規作業）

1. **`domain.cart.CartRepository`（interface）新設**。ドメイン語彙のメソッドのみ公開（`findByUserId(userId): Cart`〔無ければ空集約〕/ `save(Cart)` を基本）。
   → **コードベース初の Repository interface**（`reconstruct()` / `Converter` も初）。
2. **`infrastructure.mybatis.cart.MyBatisCartRepository`（実装）新設**。`CartCustomMapper` と `CartConverter`（新規）を保持し、
   戻り値は Domain モデルのみ（`*CustomEntity` を Application 層へ出さない）。
3. **`Cart` / `CartItem` の集約化**（`private` コンストラクタ＋`reconstruct()`＋不変条件メソッド）。在庫上限・`Math.addExact`・
   merge クランプ・数量0以下削除を集約ドメインメソッドへ移設。`stockQuantity` を集約内で保持しつつ外向き表現では落とす。
4. **`CartApplicationService` を薄いユースケース調整へ**（Repository interface のみ注入・`infrastructure.*` import 消滅）。
5. **`CartConverter`（新規・infra 層）**: `*CustomEntity` → Domain（`reconstruct()` 経由）。Repository 実装内で呼ぶ（§2）。
6. **テスト再ターゲット**（AC5）: `CartApplicationServiceSpec` のモック対象を `CartCustomMapper` → `CartRepository` に切替、
   不変条件アサーションを集約ドメインメソッドの純 UT へ移設。既存 Testcontainers 統合テストは**グリーン維持**。

---

## Issue #29 本文（転記）

### 背景 / Why

jpetstore-backend の Application Service が MyBatis の `*CustomMapper` を直接注入し、`*CustomEntity`（Infrastructure層）を
Application 層で import・使用している（`CartApplicationService` / `CatalogApplicationService` / `AccountApplicationService` /
`OrderApplicationService`）。これは backend-conventions §1（Entity は Infrastructure 層に閉じる・Repository を直接呼ばない・
依存性逆転）/ §2（Infra→Domain は `XxxConverter#toModel` + `reconstruct()`）に違反したドリフト。規約の明文化は別途実施済み
（backend-conventions `SKILL.md` §1 / §2 / §9）。**domain 層の Repository interface はまだ1つも存在しない（本 Issue が初回）。**

本 Issue はその是正の **参照実装（PoC）** として **Cart bounded context** を Repository 経由＋集約化に作り替える。
以降の全体展開（#30）はこの実装をテンプレートにする。

**なぜ Cart から**: 在庫上限・加算オーバーフロー・merge クランプなど**業務不変条件が最も濃く**、セキュリティ機微
（在庫数非露出 = ID-28）もここに集中しているため、集約化の利益が最大で規約の実証価値が高い。

### スコープ

- 対象: `CartApplicationService` とその永続化（`CartCustomMapper` 周辺）。
- 非対象: Catalog / Account / Order（#30 で対応）。**API 仕様・エンドポイント・レスポンス形状は不変**（内部リファクタのみ）。
- 非対象: merge の N+1 クエリ解消（#28 で別途対応）。本 Issue では既存クエリ戦略を維持してよいが、
  **Repository 実装が #28 のバッチ化を阻害しない構造**にすること。

### Acceptance Criteria

- [ ] **AC1**: `domain.cart.CartRepository`（interface）を新設し、ドメイン語彙のメソッドのみを公開する。**メソッド面は最小で
  `findByUserId(userId): Cart`（無ければ空集約）/ `save(Cart)` を基本とし、追加が要る場合もドメイン語彙で命名する**
  （#30 が踏襲する先例規約）。`CartApplicationService` は Mapper / Entity ではなく本 interface のみを注入する。
- [ ] **AC2**: 実装 `infrastructure.mybatis.cart.MyBatisCartRepository` が `CartCustomMapper` と Converter を保持し、
  戻り値は Domain モデルのみ（`*CustomEntity` を Application 層へ出さない）。`CartApplicationService` から `infrastructure.*` の
  import が消える（`grep` で回帰確認）。
- [ ] **AC3**: 在庫上限・`Math.addExact` によるオーバーフロー検出・merge の在庫クランプ・数量0以下の削除といった不変条件を
  `Cart` / `CartItem` ドメインモデルのメソッドへ移設する（Service は薄いユースケース調整に留める）。挙動（数量加算・在庫クランプ・
  quantity<=0→400・オーバーフロー処理）は退行しない。
- [ ] **AC4**: 在庫qty（`stockQuantity`）は集約内では保持してよいが、Application / Presentation の戻り値（`CartItem` の外向き表現）には
  生 qty を含めない（ID-28 維持）。
- [ ] **AC5**: `CartApplicationService` の不変条件テストを、MyBatis / Testcontainers 非依存の純 Spock UT（`CartRepository` をモック）として
  追加 / 移行する。既存の統合テスト（Testcontainers）はグリーンのまま。
- [ ] **AC6**: 3観点レビュー（convention / performance / security）クリーン。挙動退行なし（既存の Cart 系 AC を維持）。

### 備考

- ブランチ: `refactor/29-cart-repository-poc`
- 規約: backend-conventions `SKILL.md` §1 / §2 / §9（本 Issue 着手前にマージ済み）
- 関連: 全体展開 #30 ／ N+1 perf #28（本Issue後の新コードに対して実施）
- **優先順位: E4（#13〜17）着手前にテンプレを確立するため、既存 Ready の E3（#9〜12）より前に割り込む（2026-08-17 ユーザー決定）。**
- 2026-08-17 ユーザー合意（A: 規約明文化 → B: Cart PoC → 全体展開 の順）
- SP: 5

---

## spec 委譲論点の洗い出し（既決 vs 実装レベル未確定）

scrum-master-workflow ① に従い、spec / AC / `intended-diff-ledger` / `architecture-conventions` / backend-conventions §9 から
委譲論点を洗い出した。

### 既決（Refinement 済＝AC/台帳/§9/memory 合意済・再確認不要）

- Repository の **interface=Domain 層・実装=Infra 層**（依存性逆転）／メソッドは `findByUserId`・`save` 中心のドメイン語彙（AC1）。
- 不変条件（在庫上限・オーバーフロー・merge クランプ・0削除）を **`Cart`/`CartItem` 集約メソッドへ移設**（AC3）。
- **在庫qty 非露出**（ID-28・AC4）／**API・挙動不変**（スコープ）。
- **書き込み側は集約／読み取り側は CQRS 射影**、`stockQuantity` はドメイン内で保持し外向き DTO で落とす
  （backend-conventions §9・memory `repository-layer-refactor-plan` に**ユーザー〔DDD 3層設計者〕合意済**）。
- **version 列は追加しない／`SELECT … FOR UPDATE` は使わない**（Sprint 11 #8 で確定済・Cart にも適用）。

### 実装レベルで未確定（DEV の Opus 計画で案出し→ユーザー承認、割れたら AskUserQuestion）

設計**方針**は既決だが、以下の**具体化**は DEV が現状コードの緊張点を分析したうえで案を出すべき技術設計。
SM 計画前の先出し AskUserQuestion は投げず（方針は memory/AC/§9 で合意済、抽象な先出しは DEV 分析前で時期尚早）、
**DEV の計画フェーズ（Opus）で具体案を提示→ユーザー承認**、genuine な分岐が出たら Sprint 11 型の2段階の後段で AskUserQuestion 確定する。

- **D1（型戦略・最大論点）**: 書込集約（`stockQuantity` を内部保持し不変条件メソッドを持つ）と、Application/Presentation が受け取る
  「qty 非露出の外向きモデル」の関係。現行 `record Cart`/`CartItem`（外向き read-model）を返却用に残すか／集約を rich 化して
  Application 層で射影変換して返すか／単一型が二役か。**#30 全体展開の先例テンプレになるため要確定**。
- **D2（`save` 粒度）**: 集約 `save(Cart)` を「集約全体の永続化差分反映」に寄せるか、現行の細粒度 upsert/delete
  （`upsertCartItemQuantity`/`deleteCartItem`）をドメイン語彙の補助メソッドとして残すか。AC1「追加が要る場合もドメイン語彙で命名」の解釈。
- **D3（在庫qty の再構築タイミング / #28 非干渉）**: `findByUserId` が在庫qty込みで Cart を再構築するか（現状 `selectCartItems` は
  カート内行の在庫を1クエリ取得）。merge は**カートに未存在の itemId の在庫**も要る（現状 `selectItemForCart` の単一引き＝N+1）。
  集約化で在庫参照を1本化する際、**#28 のバッチ化（複数 itemId → 1クエリ）を足せる構造**を残す（R2）。

---

## リスク・チャレンジ

- **R1（挙動退行リスク）**: 不変条件を Service→集約へ移設する過程で、在庫上限／`Math.addExact` オーバーフロー／merge クランプ／
  数量0以下削除の4挙動が退行しうる。→ 既存 `CartControllerSpec`（Testcontainers E2E）＋ `CartApplicationServiceSpec`（純UT）を
  **グリーン維持**することを退行ガードとする。移設後の集約メソッドは純 UT で境界値を直接検証する（AC5）。
- **R2（#28 非干渉リスク）**: merge の在庫参照（現状 `selectItemForCart` 単一引き×N＝N+1）を集約化する際、Repository メソッド面が
  `findByUserId`/`save` 中心だと **複数 itemId の在庫＋既存数量の一括取得が載らない**。#28 のバッチ化を阻害しないよう、
  ドメイン語彙のバッチ取得メソッドを**追加できる構造**にする（本 Story では N+1 解消自体は対象外）。
- **R3（テンプレ確定の戦略性）**: 本 Story はコードベース初の Repository / Converter / `reconstruct()` 実装。ここで決めた形が
  **#30（Catalog/Account/Order 全体展開）・E4 以降の新規 Story の先例規約**になる。**過剰抽象（YAGNI な DB 差し替え動機）を避け**つつ、
  書込集約＋CQRS 射影の型（backend-conventions §9）を実証する。
- **R4（型分離の設計難度＝D1）**: 集約が `stockQuantity` を内部保持しつつ Application/Presentation 戻り値では落とす（ID-28）。
  書込集約と外向き read-model の型戦略を DEV の計画フェーズで確定させる（割れたら AskUserQuestion）。
- **意図的設計の明記（churn 防止・Sprint9初出→10/11 で 3観点クリーン実証済）**: reviewer 起動プロンプトに以下を
  「**欠落・未実装として指摘しないこと**」と明示する:
  - **API・エンドポイント・レスポンス DTO は無変更**（内部リファクタのみ）／`CartController`・Request/Response DTO は変えない。
  - **merge の N+1 は解消しない**（#28 スコープ。Repository は #28 バッチ化を阻害しない構造にとどめる）。
  - **Catalog/Account/Order の Repository 化は本 Story で行わない**（#30 スコープ）。
  - **version 列不追加・`FOR UPDATE` 不使用・SecurityConfig 無変更・database 無変更**（挙動不変のため）。
- **リファクタ Story のスコープ判定（scrum-master-workflow ④-3）**: reviewer 指摘が **main 時点から存在した既存問題の移動**であれば
  `git show main:<path>` 相当で裏取りし「既存問題の移動」＝スコープ外と判定する。
- **チャレンジ C1（tier分離 12 連続）**: 計画=Opus（最上位）／実装=Sonnet（最新・高速）。**初のリファクタ Story かつ初の集約導入**という
  新種でも tier 分離が通用するかを実証（Sprint1-11 で feature/security/write/並行制御まで実証済、本 Story は「振る舞いを変えない構造変更」）。
  新モデルのリリースは現時点なし（エイリアス `opus`/`sonnet` が各 tier 最新へ自動解決）。
- **チャレンジ C2（純 UT テンプレ化）**: Repository モックで Service を DB 非依存 UT にする形（AC5）を確立し、#30 が踏襲できる
  先例にする。Testcontainers 依存を不変条件テストから外せることを実証する。
