# Sprint 6 バックログ

## スプリントゴール

**E1 カタログ階層閲覧（#1・F1.1）を、#24 フロント土台・#23 backend 土台・#22 DB の上に載せ、本プロジェクト初のドメイン機能を実装する。カテゴリ→商品→在庫アイテム→アイテム詳細の階層閲覧を REST API（backend 新規）＋Vue3 SPA（frontend 新規）で提供し、サーバサイドページング（12件/頁・ID-20）・在庫状況バッジ（在庫数を直接露出しない）・読み取り専用/全公開・`product.description` の plaintext 化（SBD-18・ID-15）＋新規画像アセットを secure-by-default で実現する。**

Sprint 2（#23=backend 土台）・Sprint 5（#24=frontend 土台）で認証/認可とアーキ土台を固め、Sprint 1（#22=catalog/product/item/inventory の DB 移行）でマスタデータを整えた上に、**初のドメイン機能 Story** を積む。

**これは本プロジェクト初の「ドメイン機能」スプリント。** これまでの 5 スプリントは土台（DB/backend認証・認可/frontend土台）だったが、#1 は土台の上に載る**実ユーザー価値の機能**（カタログ閲覧）を初めて実装する。ここで確立する **一覧API＋ページング DTO・カードグリッド/ページネーション部品・在庫バッジ表現** は、後続の #2（検索・F1.2）・#3（参照堅牢化・F1.3）・#9（注文履歴一覧）等が再利用する先例となる。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | 実装順 |
|-------|---------|-------|----|-----------|-------|
| [#1](https://github.com/ryokkon624/jpetstore-manage/issues/1) | [E1] カタログ階層（カテゴリ→商品→在庫アイテム）を閲覧できるようにする | `feature` / `E1` | 8 | `jpetstore-database`＋`jpetstore-backend`＋`jpetstore-frontend`（**3-repo cross-repo**） | ① |

**合計 8 SP**。Project #2 で **Sprint=6 / Ready / Story Points=8**。依存 **#22（Sprint1 Done）・#24（Sprint5 Done）はいずれも完了済み**。

> **リポジトリは 3-repo cross-repo（SM 実地調査で確定・重要）**:
> - **database**＝**カタログのシードデータ（マスタ）が皆無**（DDL は #22 で作成済だが `m_supplier/m_category/m_product/m_item/t_inventory` への INSERT がリポジトリ全体で 0 件）。→ **カタログ閲覧を動かすにはシード投入マイグレーション（`V00_000_00X__insert_catalog_*.sql`）を新規作成が必須**。plaintext description・在庫3状態（在庫あり/残少/在庫切れ）を作り分ける qty シードが要る。**[L2] 旧同値**（categoryX→商品件数・productY→item 一覧）を満たすため**レガシーの階層データに忠実**に作る。
> - **backend**＝カタログ REST API（category/product/item の一覧・詳細・ページング・在庫status）を**ゼロから新規実装**（catalog の domain/mapper/service/controller は現状皆無）。
> - **frontend**＝カタログ画面（カテゴリ一覧・商品一覧・item一覧・item詳細）を**ゼロから新規実装**。ただし CSS 部品（カード/グリッド/バッジ/ページネーション）・画像アセット・i18n 一部は既達（SM 調査メモ参照）。
> **主/従リポジトリの確定は計画フェーズ**: full-stack ドメイン機能で 3 repo すべてに実質的な新規作業がある。`closes ryokkon624/jpetstore-manage#1` を置く主リポジトリを DEV が計画フェーズで確定（Sprint 5 は frontend 主・従は `Related:`／Sprint 3/4 は backend 主）。**backend が database の Flyway を test resources に同期する場合は `./gradlew syncTestSchema` の確認が必要**（Sprint 4 教訓）。3 repo に同名ブランチ `feature/1-catalog-browsing`（各 `main` から分岐）を推奨。
> **bug ラベルなし**（`feature` / `E1`）＝計画フェーズでの Issue Body 更新（根本原因調査）は不要。
> **参考**: この migration-agent-base 側の Planning/Review 成果物は `feature/sprint6` ブランチにコミットし、Retro 完了時に PR＆マージする（ユーザー指示・2026-08-15）。実装コードの PR は各 repo（backend／frontend）で SM が作成する。

---

## トレース（E1 の位置づけ）

E1 カタログは 3 Feature で構成され、#1 はその先頭（階層閲覧）：

| Feature | Issue | Sprint | スコープ |
|---|---|---|---|
| **F1.1 カタログ階層閲覧** | **#1（本スプリント）** | **6** | カテゴリ→商品→item→詳細の閲覧・サーバページング・在庫バッジ・plaintext description |
| F1.2 商品検索 | #2 | 7 | 複数語 LIKE 部分一致検索・ページング（SBD-17 維持） |
| F1.3 参照の堅牢化・出力安全化 | #3 | 7 | 不正ID/stale-session の 404/空正規化・trace 非露出（SBD-10）の**集約ハードニング**＋出力安全化 |

- **挙動 spec**: `spec/behavior/catalog.md` §2（as-is 挙動）・§3（業務ルール）
- **横断NFR**: `spec/security-baseline.md` SBD-10（情報漏えい防止）・SBD-18（XSS 出力エスケープ）
- **意図差分**: `spec/intended-diff-ledger.md` **ID-6**（JSP→Vue3 SPA＋REST）・**ID-15**（description plaintext＋新規画像・SBD-18）・**ID-20**（4→12件/頁・API ページング）。参考: ID-14（stale/不正ID 正規化＝主に #3）・ID-18（在庫切れ追加不可＝主に #4）
- **デザイン**: `spec/design/design-brief.md` §3(1-4)（ホーム/カタログトップ・カテゴリ→商品一覧・商品→item一覧・item詳細）／`spec/design/JPetStore UI (standalone).html`

---

## Issue #1 本文（転記）

### ユーザーストーリー

**As a** サイト訪問者（未認証を含む全ユーザー）
**I want to** カテゴリ→商品→在庫アイテムの階層をたどって閲覧したい
**So that** 買いたいペット/商品を探せる

### トレース

- **Epic**: E1 カタログ閲覧（Catalog）
- **Feature**: F1.1 カタログ階層閲覧
- **挙動spec**: spec/behavior/catalog.md §2, §3
- **横断NFR**: spec/security-baseline.md（SBD-10, SBD-18）

### Acceptance Criteria

- [ ] **AC1**: カテゴリ一覧／カテゴリ内商品一覧／商品内在庫アイテム一覧／アイテム詳細を REST API＋Vue3 SPA で閲覧できる（JSP廃止）。
- [ ] **AC2**: 一覧はサーバサイドページング。ページサイズは **12件/頁**（as-is 4→12・PO決定）。ページは API パラメータ（page/size）で指定し、セッション保持ページングは廃止。
- [ ] **AC3**: アイテム詳細に在庫状況を「在庫あり／残少／在庫切れ」バッジで表示（PO決定・在庫数の直接露出はしない）。
- [ ] **AC4**: カタログは読み取り専用（GETのみ・状態変更なし）。全アクセス未認証で到達可能（公開が正常）。
- [ ] **AC5 (SBD-18)**: 動的出力はフレームワーク既定でエスケープ。`product.description` は HTML を継承せず **plaintext 表示**（承認済の非等価変更）。商品/カテゴリ画像は spec/design/images 配下の新規アセット（nano banana 生成）を使用し、レガシーの `<image>` 埋め込みHTMLは継承しない。
- [ ] **[L2] 旧同値**: categoryX→商品件数／productY→item一覧が旧同値（階層マッピング）。※4→12件/頁は ID-20 の意図差分
- [ ] **AC-neg1 (否定AC / SBD-18)**: description に HTML/スクリプトを含むデータを与えても、画面に生HTMLが描画されず（plaintext表示）、スクリプトが実行されない。

### 備考

- 優先順位の根拠: カタログは全ドメインの入口。E1 は before clean で機能価値が高い。
- 依存関係: #22（E6.1 DB移行: category/product/item/inventory）／#24（E6.3 フロント土台）／spec/design。
- PO決定（Refinement 2026-08-11）: ページサイズ12・在庫バッジ表示。
- デザイン参照: spec/design/design-brief.md §3(1-4)、spec/design/JPetStore UI (standalone).html。

---

## ⚠️ 計画フェーズで DEV が確定すべき論点（→ ユーザー承認）

初のドメイン機能 Story のため、以下をOpusでのPlanningで整理しユーザー承認を得ること。

1. **主/従リポジトリと `closes` の置き場（3-repo）**: full-stack で **database（シード新規）＋backend（API 新規）＋frontend（画面新規）の 3 repo すべてに新規作業**。主リポジトリ（`closes #1` を置く方）を確定し、従 repo は `Related: #1`。同名ブランチ `feature/1-catalog-browsing` を 3 repo に作成。backend が database の Flyway を test resources に取り込むなら `./gradlew syncTestSchema` の同期を確認（Sprint 4 教訓）。
2. **在庫バッジの status 算出と閾値（AC3・在庫数非露出）**: 「在庫あり／残少／在庫切れ」を **backend が status enum を算出して返す**（qty をレスポンスに載せない＝在庫数非露出を構造的に担保）方針を推奨。**「残少」の閾値**（例 `0 < qty <= N`、N を何にするか）を確定する。frontend で qty から変換する案は qty がネットワークに露出するため非推奨。
3. **ページング DTO の形**（AC2・ID-20）: `page`/`size`（size 既定 12）と、頁コントロール用の総件数/総頁を含むレスポンス形（例 `{ content, page, size, totalElements, totalPages }`）。**#2/#9 が再利用する先例になる**ため命名・形を規約化する前提で決める。1-index か 0-index かも確定。
4. **item 詳細の「カート追加」導線の扱い（スコープ境界）**: design-brief §3(4) は item 詳細に「カート追加」を含むが、**カート追加の実挙動は #4（E2）**。#1 は AC4 で読み取り専用（GETのみ・状態変更なし）。→ item 詳細のカート追加ボタンは **#1 では非表示 or 非活性プレースホルダ**とし、実装は #4 に委譲する線引きを確定（在庫切れ時の追加不可＝ID-18 も #4）。
5. **#1 に含める not-found の最小範囲 vs #3（F1.3）の集約ハードニングの線引き**: 不正ID・stale-session の **網羅的な 404/空正規化・trace 非露出（SBD-10）は #3（F1.3・Sprint7）**。ただし **#1 が機能するための最低限の not-found（存在しない category/product/item → 500/trace ではなく 404）** は #1 で実装が必要。どこまでを #1 に含めるかを確定（PO記録では「#3を#1/#2から単独後続に切り離さない」とあるが、Sprint 割当は #1=S6・#3=S7 に分離済＝ユーザー決定。#1 は自機能の happy path＋自身の SBD-18〔AC5/AC-neg1〕に集中）。
6. **画像アセットの取り込み範囲（AC5）**: `spec/design/images/` の category 5枚/product 16枚を frontend assets へ取り込む（生成済・SM 調査メモで実在確認済）。#24 は hero/logo に限定していたため、**本スプリントで category/product 画像を初めて取り込む**。item は対応 productId 画像を流用・欠落は `placeholder.svg`。参照解決（import/public 配置）の方式を確定。
7. **catalog の MyBatis 実装方式（Generator vs カスタム Mapper）**: 現状 generatorConfig の `<table>` は `m_code` のみで catalog 未登録。カタログは**読み取り専用＋階層クエリ＋ページング**（category→products／product→items＋inventory JOIN・N+1 回避）。単純 CRUD ではないため、**カスタム Mapper（手書き XML）を推奨**（既存 `custom/mapper` パターン踏襲）。Generator に catalog テーブルを追加して生成物を土台にする案と比較し確定（backend-conventions §9 の使い分け準拠）。
8. **カタログシードの設計（database・[L2] 旧同値／在庫3状態）**: 新規シードマイグレーション（`V00_000_00X__insert_catalog_*.sql`）で、**レガシー JPetStore の階層データに忠実**な category/product/item を投入（[L2] 旧同値＝categoryX→商品件数・productY→item 一覧の担保）。**description は plaintext**（`<image>` 埋め込み継承せず）。**`t_inventory.quantity` を在庫3状態が出るように作り分け**（在庫あり＝十分／残少＝閾値以下 1件以上／在庫切れ＝0）。レガシーシードの参照元（`legacy-jpetstore` の HSQLDB シード）を計画フェーズで特定。

---

## 承認済み計画（計画フェーズ・2026-08-16 ユーザー承認）

計画=Opus で DEV が 3 repo・spec・conventions・レガシー seed を精読し実装方針を整理。SM が §3.1 等を verification のうえ、下記をユーザー承認で確定（**tier分離6連続・初のドメイン機能**）。

**ユーザー承認 3 決定:**

| 論点 | 決定 |
|---|---|
| ① 残少バッジ閾値 N（論点2・新規UX値） | **N=5**（`0<qty≤5`=残少 / `qty>5`=在庫あり / `qty≤0`=在庫切れ）。レガシーは全 qty=10000 で残少概念なし＝純粋な新 UX 値。閾値は定数/config 化 |
| ② 在庫ステータスの実装方式（論点2/7） | **m_code 区分値として登録**（**DEV 推奨の手書き enum をユーザーがオーバーライド**）。ユーザー方針＝「**区分値は基本的に m_code に登録する**」。architecture-conventions §3.1 が在庫ステータスを m_code 候補に例示し「確定は PO/仕様で」としていた点を、**PO/仕様の確定として m_code 採用**。→ code_type 新設＋`display_name_ja/en`（D4・日英のみ）／既存ジェネレータで生成（D5・TS は database→frontend／Java 区分値 enum は backend 手書きで m_code に整合）。**在庫 status は算出値**（qty から `of(qty)`）で格納列は持たないが、区分値レジストリは m_code に載せる。**qty はレスポンス非露出を維持**（R3・在庫数を出さない） |
| ③ 一覧 API のページ採番（論点3・#2/#9 の先例規約） | **1-index**（`page=1` 始まり・URL/UI と自然一致・公開 REST 向き）。レスポンス `PageResponse<T> { content, page, size, totalElements, totalPages }` |

**SM 確定（技術/プロセス判断・ユーザー承認前提の既定）:**

| 論点 | 決定 |
|---|---|
| 主/従リポジトリ・closes（論点1） | **主＝frontend（`closes #1`）**（Sprint5 踏襲・ユーザー価値の実現層＝capstone）／**従＝database・backend（`Related: #1`）**。3 repo 同名ブランチ `feature/1-catalog-browsing`（各 main から新規分岐）。backend は database の seed 追加後に `./gradlew syncTestSchema` で test resources 同期 |
| ページング size パラメータ化（論点3の重要事実） | **size を API パラメータ化（既定12・client override 可・上限 cap=100）**。**理由: [L2] 忠実 seed だと最大 DOGS=6商品・最大 product=4item で全て12未満＝size=12固定では多頁ページングを実証できない**。AC2「page/size で指定」に合致。テストは `size=2` で多頁を強制（DOGS 6商品→3頁）。categories は5件固定＝非ページング（単純 list）・products/items のみページング |
| item 詳細のカート追加導線（論点4） | **#1 では非活性プレースホルダ（disabled "Add to Cart"）**。クリックハンドラ/store/API なし＝AC4（GET only・状態変更なし）を壊さない。実挙動・在庫切れ追加不可（ID-18）は **#4 へ委譲** |
| not-found 最小範囲 vs #3（論点5） | **#1 は get-by-id 3経路（category/product/item 詳細）で該当行なし→ `ResourceNotFoundException`→ 既存 `GlobalExceptionHandler` で 404**（trace 非露出は #23 で既達＝自動担保）。list-by-parent も親 ID 存在チェックで 404。**不正フォーマットID・stale・空正規化の集約ハードニング＋否定AC 網羅は #3（F1.3・Sprint7）へ** |
| MyBatis 実装方式（論点7） | **カスタム手書き XML マッパー**（Generator 非登録）。読み取り専用＋階層＋ページング(LIMIT/OFFSET)＋JOIN(item×inventory／item×product)＋COUNT＝backend-conventions §9「複雑な動的SQL・JOIN は XML」。配置 `infrastructure.mybatis.custom.{entity,mapper}`・XML `resources/mapper/custom/*.xml`。※在庫 status を m_code 化する②の決定により、区分値 enum 生成（Generator/ジェネレータ）は m_code 分のみ発生（catalog 参照系は手書きのまま） |
| カタログ seed 配置（論点8） | **本番相当 `flyway/sql/V00_000_008__insert_catalog_master.sql`**（m_supplier→m_category→m_product→m_item→t_inventory の FK 順・1ファイル・plaintext・WHO 列は m_code 踏襲でリテラル明示）。参照元＝`legacy-jpetstore/db/mysql/jpetstore-mysql-dataload.sql`。**[L2] 階層**: category5→product16→item28。**qty を3状態が出るよう作り分け**（大半=100=IN・数点=1〜5=LOW・数点=0=OUT）。※在庫 status の m_code seed（code_type 新設）も database 側で投入 |
| 画像取り込み（論点6） | `spec/design/images` の category5+product16+placeholder を frontend `src/assets/catalog/` へコピー＋`import.meta.glob(eager)` で bundling。`resolveCatalogImage(kind,id)` で解決＋欠落 placeholder。item は productId 画像流用・`<img loading="lazy">`（Perf） |

> **②の m_code 化に伴うスコープ調整（DEV へ明示）**: 手書き enum 案（frontend i18n `catalog.*` にバッジ文言）から **m_code 区分値**へ変更。含意＝(a) database で在庫ステータスの **code_type を新設し display_name_ja/en 付きで seed 登録**（既存 m_code 命名規約・`0012` ProgramType は §2 で廃止済のため衝突回避して採番）、(b) **既存ジェネレータで TS 定数を生成→frontend 取り込み**（D5・§3／バッジ文言は生成された m_code 表示名を使い、既存の `home.tokens.stockIn/stockLow/stockOut` i18n キーと重複するなら reconcile）、(c) **backend は区分値 enum を手書きで m_code に整合**（line31「区分値 enum は backend に手書き」）し `StockStatus.of(qty)` で算出、(d) **qty 非露出は不変**（R3 維持）。日英表示名は #25（日本語）へ自然に接続。

---

## SM調査メモ（既達 vs 未実装）

SM が 3 repo ＋デザインアセットを実地調査した結果（Sprint 4/5 で確立した「既達 vs 未実装」事前調査）。**カタログ機能のアプリコードは backend/frontend ともに完全ゼロ**だが、載せる先の土台（3層・セキュリティ・API クライアント・Pinia・i18n・CSS 部品・画像）は整備済み。**唯一の想定外は database のシード皆無**（下記）。

### backend（jpetstore-backend）

**既達（再利用可）**
- 3層 DDDライク骨格（`presentation/rest`・`application/service`・`domain`・`infrastructure/mybatis`・`config`）
- REST GET の最小パターン: `presentation/rest/PingController.java`（`@RestController`＋`@RequestMapping("/api")`＋`@GetMapping`）
- **例外→HTTP 正規化基盤（SBD-10 の 404 に流用可）**: `domain/exception/ResourceNotFoundException.java`／`presentation/rest/exception/GlobalExceptionHandler.java`・`ErrorResponse.java`
- `config/SecurityConfig.java`: `permitAll` は `/api/ping`・`/actuator/health`・swagger・`/v3/api-docs/**`・`/api/auth/{refresh,login,logout}` のみ／既定 `anyRequest().authenticated()`／CSRF Cookie 方式・`@EnableMethodSecurity`
- MyBatis Generator 設定 `resources/generator/generatorConfig.xml`（出力 `infrastructure.mybatis.generated.{entity,mapper}`・XML は `resources/mapper.generated`・underscore→camel 有効）／カスタムマッパー実装例 `infrastructure/mybatis/custom/mapper/AccountAuthCustomMapper.java`
- テスト基盤（Spock/Groovy・Testcontainers MySQL 8.4＋Flyway）: `support/IntegrationTestBase.groovy`（`test/resources/flyway/sql` を適用・**カタログ DDL `V00_000_003` も含む**）／参照 Spec: `SecurityEndToEndSpec`・`AuthMeSpec`・`GlobalExceptionHandlerSpec`
- `application.yml`（MySQL・`mybatis.map-underscore-to-camel-case: true`）

**未実装（新規）**
- **catalog の domain/mapper/service/controller は一切なし**（`src/main` にヒットゼロ）
- **MyBatis 生成物が空**（`generated/` は `.gitkeep` のみ・generatorConfig の `<table>` は `m_code` **だけ**）→ **catalog テーブル（m_category/m_product/m_item/m_supplier/t_inventory）は Generator 登録 or カスタム Mapper で新規**（→ 論点7）
- **ページング実装は前例ゼロ**（page/size/limit/offset 全て新規・PageHelper 等の依存なし）
- **SecurityConfig の permitAll にカタログ GET パス追加が必須**（未追加だと `GET /api/categories` 等が `authenticated()` に落ち **401**）
- カタログ用 Spec（Controller/Service/Mapper）新規

### frontend（jpetstore-frontend）

**既達（再利用可）**
- ディレクトリ: `src/{api,components,domain,i18n/locales,router,stores,utils,views,assets,constants}`
- API クライアント `api/httpClient.ts`（fetch・`credentials:'include'`・CSRF cookie→header・**401 silent refresh＋retry**・`HttpError`・`request<T>()`）／`api/authApi.ts`（DTO→domain 変換の型パターン）
- Pinia `stores/auth.ts`（options-style `defineStore`）
- Router `router/index.ts`（`home`/`signon`・`meta.requiresAuth` 基盤＝**カタログは公開なので付けない**）／`router/authGuard.ts`
- i18n `i18n/locales/en.ts`（英語のみ・`domain.context.key`）。**既に `app.header.nav.catalog`・`home.hero.browseCatalog`・`home.tokens.stockIn/stockLow/stockOut` を定義済**（`catalog.*` 名前空間のみ新規）
- 共通レイアウト `components/AppLayout.vue`・`AppHeader.vue`（Catalog/Cart は現状 `href="#"` ダミー＝**実ルート接続待ち**）
- **デザイントークン＆CSS 部品（Tailwind v4・`assets/main.css`）がクラスとして完備**: `.jps-product-card`・`.jps-media`（画像スロット）・`.jps-price`・`.jps-badge`＋`.badge-jps-stock-in|low|back|out`（在庫バッジ）・`.jps-pagination`＋`.jps-page`・`.jps-table`・`.jps-breadcrumb`・`.jps-chip`・`.jps-empty`・`.jps-skeleton`／在庫ステータス色・カテゴリ別色（fish/dogs/cats/reptiles/birds）
- `views/HomeView.vue`（在庫バッジ3種を「トークン確認」で既に描画・"Browse Catalog" は `href="#"` ダミー）

**未実装（新規）**
- **カタログの View/store/api は一切なし**（View は Home/Signon のみ・store は auth のみ・api は auth のみ）→ CategoryList/ProductList/ItemList/ItemDetail View・`catalogApi.ts`・catalog store すべて新規
- **再利用可能な Vue コンポーネント未作成**（**CSS クラスはあるが `.vue` 化されていない**）→ `ProductCard.vue`・`Pagination.vue`・`StockBadge.vue` 等は新規（**スタイルは既達なので薄いラッパで済む**）
- ルート未定義（`/catalog`・`/categories/:id`・`/products/:id`・`/items/:id` 等）＋ヘッダ/ヒーローのダミー `#` を実ルートへ接続
- i18n `catalog.*` 名前空間 新規
- **商品/カテゴリ画像がフロント未取り込み**（`assets/` は hero.png/logo.svg/main.css のみ）→ `spec/design/images` の `product_*.png`/`category_*.png` を frontend へ配置・参照解決
- description の plaintext 表示（`v-html` 不使用）＝否定AC 対応の新規実装

### database（jpetstore-database）— ⚠️ 想定外の新規作業

**既達（再利用可）**
- **カタログ4テーブル DDL は #22 で作成済**: `flyway/sql/V00_000_003__create_catalog_tables.sql`（`m_supplier`・`m_category`・`m_product`・`m_item`）／`V00_000_005__create_order_tables.sql`（`t_inventory`＝`item_id` PK・`quantity`）
- 特性: 参照マスタ（読取専用・version 列なし）・自然キー維持（`FI-SW-01` 等の公開 business code）・`m_{category,product}.description` は `VARCHAR(255)`・`m_item.{list_price,unit_cost}` は `DECIMAL(10,2)`・FK 完備
- スキーマ表明テスト: `schema/CatalogTablesSpec.groovy`・`OrderInventoryTablesSpec.groovy`

**未実装（新規・重要）**
- **カタログのシードデータ（マスタ）が皆無**（`flyway/sql` の INSERT は `V00_000_001`（m_code系）・`V00_000_002__insert_m_code.sql` のみ・catalog テーブルへの INSERT は**全リポジトリ 0 件**）→ **シード投入マイグレーション（`V00_000_00X__insert_catalog_*.sql`）を新規作成が必須**（これが無いとカタログ閲覧が動かない）
- 新規シードは**plaintext で作る**（SBD-18・レガシー `<image>` 埋め込み継承せず）。**`t_inventory.quantity` を在庫3状態（在庫あり/残少/在庫切れ）が出るように作り分ける**。**[L2] 旧同値**のためレガシーの階層データ（category→product 件数・product→item）に忠実に

### デザインアセット（migration-agent-base\spec\design）— すべて生成済み

- **`spec/design/images/` に画像生成完了（2026-08-10）**: カテゴリ5枚（`category_{BIRDS,CATS,DOGS,FISH,REPTILES}.png`）・商品16枚（`product_<productId>.png`・**item は対応 productId 画像を流用**）・`hero.png`・`logo.svg`・`placeholder.svg`（欠落フォールバック）
- 標準デザイン HTML `spec/design/JPetStore UI (standalone).html`（カタログ全画面デザインの参照元）／画像対応表 `spec/design/nano-banana-prompts.md`（生成完了・命名 `product_<id>`/`category_<id>`）／デザイントークン原本 `spec/design/main.css`

---

## ⚠️ スコープ境界（DEV が計画フェーズで線引きしユーザー承認を得ること）

**#24（frontend 土台）・#23（backend 土台）の規律を踏襲＝#1 は「カタログ階層閲覧」に必要な範囲に絞り、検索・集約ハードニング・カート・後続ドメインは各 Story へ委譲する。**

| 含む（本スプリント #1） | 含まない（各 Story へ委譲） |
|---|---|
| **カタログシードの新規投入（database・[L2] 旧同値・在庫3状態・plaintext）** | 商品検索（#2・F1.2） |
| カテゴリ一覧／カテゴリ内商品一覧／商品内item一覧／item詳細の閲覧（AC1・REST＋Vue3 SPA） | 注文/在庫減算のための書き込み系シード・トランザクション（E3・#8） |
| サーバサイドページング 12件/頁・page/size（AC2・ID-20） | 不正ID/stale-session の集約的 404 正規化・否定AC網羅（#3・F1.3・SBD-10）※#1 は最低限の not-found のみ |
| 在庫状況バッジ・在庫数非露出（AC3） | カート追加の実挙動・在庫切れ追加不可・数量上限（#4・E2・ID-18）※item詳細のカート追加ボタンは #1 では非活性/非表示 |
| plaintext description＋新規画像アセット（AC5・ID-15・SBD-18） | チェックアウト/注文履歴/注文詳細（E3・#7〜#12） |
| 読み取り専用/全公開・最低限の not-found（AC4） | アカウント/認証（E4・#13〜#17） |
| 一覧API＋ページング DTO・カードグリッド/ページネーション部品の確立（#2/#9 の先例） | 日本語ローカライズ（#25・i18n は英語のみ・#24 で英語基盤確立済） |

> **土台の上に載せる初のドメイン機能＝過剰実装を回避**（#23/#24 の教訓を継承）。カタログ閲覧に必要な最小の API/画面/部品に絞り、検索（#2）・集約ハードニング（#3）・カート（#4）は本 Story の上に各 Story で積む。

---

## リスク・チャレンジ

| # | 種別 | 内容 | 対応 |
|---|------|------|------|
| R1 | リスク | **初のドメイン機能＝土台部品の実適用検証**。#24 の one-system（`AppHeader`/`AppLayout`・`.jps-card`/`.jps-badge`/`.jps-btn`）が実ドメイン画面（カードグリッド・ページネーション）を支えられるか。再利用可能なグリッド/ページネーション部品が未整備なら新規作成が要る | SM 調査メモで既存部品の充足度を確認。土台を壊さず積む。不足部品は #1 で新規作成し #2/#9 の先例化（C2） |
| R2 | リスク | **SBD-18/AC-neg1（ID-15）＝description の生HTML描画**。`v-html` でレガシー HTML を注入すると格納XSS 面が復活 | backend は description を素の文字列で返し、frontend は `{{ }}`/テキストバインドで描画（**`v-html` 禁止**）。**「HTML/scriptを与えても生描画されず・実行されない」を否定ACとして Vitest 固定**。旧 `<image>` 埋め込みHTMLは継承せず画像は新規アセット |
| R3 | リスク | **在庫数の直接露出（AC3）**。qty をそのまま API/画面に出すと在庫数が漏れる | **backend が status enum（在庫あり/残少/在庫切れ）を算出して返し、qty はレスポンスに載せない**。「残少」閾値を計画フェーズで確定（論点2）。frontend は status を badge に写像するのみ |
| R4 | リスク | **ページング仕様の不統一（AC2・ID-20）**。#1 で決める page/size DTO が #2（検索）・#9（注文履歴）と食い違うと後続で手戻り | **総件数/総頁を含む一覧 DTO を規約化前提で確定**（論点3）。1-index/0-index・既定 size=12 を明示。frontend-conventions/backend-conventions への反映を C2 で計画 |
| R5 | リスク | **#3（F1.3）との SBD-10 分担漏れ**。不正ID/stale の網羅正規化は #3 だが、#1 が最低限の not-found を実装しないと存在しない ID で 500/trace が出る | 論点5で「#1 に含める not-found の最小範囲」を確定。#1 は存在しない category/product/item → 404（trace 非露出）まで。集約ハードニング・否定AC網羅は #3 へ |
| R6 | リスク | **N+1 クエリ（Perf）**。カタログ階層（category→products／product→items＋inventory）で一覧ごとに件数分の追加クエリ | 一覧 API は JOIN/バッチ取得で N+1 回避。inventory 参照も item 一覧に含めてまとめて取得。画像は遅延ロード・サイズ最適化 |
| R7 | リスク | **カタログシードが皆無＝想定外の 3-repo 化＋[L2] 旧同値リスク**（SM 調査で判明）。DDL（#22）はあるが `m_category/m_product/m_item/m_supplier/t_inventory` の INSERT が全リポジトリ 0 件。シードが無いと画面が動かず、かつ [L2] 旧同値（categoryX→商品件数・productY→item 一覧）を満たすにはレガシー階層に忠実な投入が要る | **database に新規シードマイグレーションを作成**（論点8）。レガシー `legacy-jpetstore` の HSQLDB シードを参照元にし、plaintext description・在庫3状態（qty 作り分け）で投入。schema/seed テストで件数を固定 |
| R8 | 好材料（非リスク） | **土台・CSS 部品・画像が揃っている**。#23（backend 土台・MyBatis/Flyway/Security/例外正規化）・#24（frontend 土台・API クライアント/401 silent refresh/Pinia/Router/i18n/**カード/グリッド/バッジ/ページネーションの CSS 部品完備**）・デザイン画像（category5/product16・生成済）が完了済 | 新規作業をシード／カタログ API／カタログ画面（**CSS 済みの薄い .vue ラッパ**）／在庫 status／ページングに集中できる。`v-html` 不使用の否定AC・404 は既存 `GlobalExceptionHandler`/`ResourceNotFoundException` を流用 |
| C1 | チャレンジ | 計画フェーズを **Opus 4.8（1M context）** で実施し、#1 全AC＋`catalog.md`＋#23/#24 土台＋#22 DB スキーマ/シードを一括読解してスコープ境界（土台 vs ドメイン・#3/#4 との分担・在庫status・ページング DTO）を先に確定 → 実装 Sonnet で手戻りなく完走。**初のドメイン機能 Story で tier 分離・土台規律がドメイン機能でも通用するか検証**（backend 4連続＋frontend 1回で実証済） | 計画フェーズを Opus で起動（tier分離6連続の挑戦） |
| C2 | チャレンジ | **ページング＋一覧API＋カードグリッド/ページネーション部品の規約化**。#1 で確立したパターンを backend-conventions/frontend-conventions に反映し、#2（検索）・#9（注文履歴）が再利用できる先例にする | Retro で規約反映を判断（2回ルール＝初出は long_term 止まり／#2 で再利用時に昇格判定） |
| C3 | チャレンジ | **reviewer 観点の先回り**＝Sec に AC-neg1（`v-html`禁止/plaintext）・SBD-10（not-found 正規化・trace非露出）・AC4（公開GETのみ・状態変更なし）を否定AC で；Conv に backend-conventions §9（custom mapper/entity 配置・アノテーション/XML 使い分け・Generator 除外）＋frontend-conventions §7（Flux・カラートークン・i18n `domain.context.key`）準拠を；Perf に N+1・画像遅延ロード・初回バンドルを検証依頼 | レビュー段で観点を具体指定（`backend-conventions`/`frontend-conventions` skill 参照） |

**モデル**: Opus 4.8（1M context）が現行最上位 tier。計画=`opus`／実装=`sonnet` のエイリアスで各 tier 最新へ自動解決。新規モデル提案なし。

---

## Definition of Done

- 全 AC（AC1〜AC5・[L2] 旧同値・AC-neg1）を満たす。
- **database（Flyway＋schema/seed テスト green）**: カタログシード投入マイグレーション（`V00_000_00X__insert_catalog_*.sql`）を追加。レガシー階層に忠実（[L2] 旧同値）・plaintext description・在庫3状態（在庫あり/残少/在庫切れ）の qty。**backend の test resources（`test/resources/flyway/sql`）へ同期**（`./gradlew syncTestSchema` 相当）し Testcontainers で適用される状態にする。件数/在庫状態の表明テストを追加。
- **backend（Spock green）**: カタログ一覧 API（category/product/item・ページング12件/頁・page/size）・item 詳細（在庫 status バッジ・qty非露出）・最低限の not-found（404・trace非露出）を Spock で固定。**カタログ GET パスの permitAll 追加**（未認証到達＝AC4）。**実機起動＋主要 EP 疎通**（カテゴリ一覧・item 詳細等）＋IDE 警告ゼロ（Sprint 2 DoD）。`./gradlew spotlessApply` 実行。
- **frontend（Vitest green）**: 在庫 status→badge 写像・ページング算出・store/composable/utils を Vitest で固定。**description の否定AC**（HTML/script を与えても生描画されない・実行されない）を Vitest で固定。`npm run build`（vue-tsc 型チェック）green・`npm run format` 実行（`.claude/rules/git.md` のコミット前必須作業）。
- **[L2] 旧同値**: categoryX→商品件数・productY→item 一覧が旧同値（`catalog.md`／#22 シードの階層マッピング）を確認（Phase 4 L2 の種）。
- `backend-conventions`（§9 含む）／`frontend-conventions`（§7 含む）準拠。
- 3観点レビュー（規約/セキュリティ/パフォーマンス）指摘なし。
- **レガシー由来の生HTML描画面が存在しない**（AC-neg1・`v-html` 不使用）。読み取り専用・全公開（GETのみ・未認証到達可）。
