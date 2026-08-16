# Sprint 7 バックログ

## スプリントゴール

**E1 カタログの残り 2 Feature（F1.2 商品検索・F1.3 参照堅牢化/出力安全化）を、Sprint 6 で確立したカタログ土台（1-index ページング DTO・カードグリッド/在庫バッジ/ページネーション部品・m_code・カスタム XML マッパー・例外正規化基盤）の上に載せ、Epic E1 を完成させる。**

- **#2 商品検索（F1.2・SP5・feature）**：複数語を語分割し各語を LIKE 部分一致（name/category/description の OR）＝as-is 踏襲。**カテゴリフィルタ付き**（ユーザー決定 2026-08-16）・サーバページング 12件/頁（ID-20）・全 SQL パラメタライズ維持（SBD-17）・**LIKE メタ文字 `%`/`_` はリテラル化＝ハードニング**（ユーザー決定 2026-08-16／新規 intended-diff ID-29）。backend REST（検索 API 新規）＋ Vue3 SPA（ヘッダ検索バー＋結果カードグリッド）で提供。
- **#3 参照堅牢化・出力安全化（F1.3・SP3・security）**：不正/存在しない categoryId/productId/itemId・**非数値/巨大値の page/size**・stale-session 頁送りを **404 / 空 / 4xx に正規化**し、スタックトレース/内部パス/版数を露出しない（SBD-10）。`product.description` の plaintext 化・全動的出力の文脈エスケープ（SBD-18）は **#1 で大半達成済**、本スプリントは**残る穴の集約ハードニング＋回帰テストによる実証**が主眼。

Sprint 6（#1 F1.1）で本プロジェクト初のドメイン機能（カタログ階層閲覧）を実装し、**一覧 API・ページング DTO・カードグリッド/在庫バッジ部品・m_code・例外正規化基盤**を確立した。Sprint 7 はこの**先例の実効性を検証**する初のスプリントであり、#2/#3 はこれらをどれだけ再利用して手戻りなく完走できるかが焦点（＝チャレンジ）。E1 完成をもってカタログドメインが一区切りとなる。

---

## 対象Issue

| Issue | タイトル | ラベル | SP | リポジトリ | 実装順 |
|-------|---------|-------|----|-----------|-------|
| [#3](https://github.com/ryokkon624/jpetstore-manage/issues/3) | [E1] カタログ参照の不正入力・stale-session を正規化し出力を安全化する | `security` / `E1` | 3 | `jpetstore-backend`（主）＋`jpetstore-frontend`（従・回帰テスト） | ①（土台ハードニングを先に） |
| [#2](https://github.com/ryokkon624/jpetstore-manage/issues/2) | [E1] 商品をキーワード検索できるようにする | `feature` / `E1` | 5 | `jpetstore-frontend`（主）＋`jpetstore-backend`（従・検索 API） | ② |

**合計 8 SP**。Project #2 で **Sprint=7 / Ready / Story Points（#2=5・#3=3）**。依存 **#22（Sprint1 Done）・#1（Sprint6 Done）はいずれも完了済み**。

> **実装順の根拠**：#3 の例外正規化ハードニング（`MethodArgumentTypeMismatchException` → 4xx 等）は、**#2 検索のページ送りエッジケース（AC-neg2＝stale/セッション切れ頁送りで 500/trace を出さない）を満たす前提**でもある（両者が同じグローバル例外ハンドラを共有）。よって **#3 の backend ハードニングを先に入れてから #2 検索を積む**と手戻りがない。ただし両 Issue は同一カタログスライスで密結合のため、1 ブランチ／1 スプリントで一括実装する。

> **リポジトリは 2-repo cross-repo（SM 実地調査で確定・重要）**：
> - **database は追加不要**：カタログ seed（`m_category`/`m_product`/`m_item`/`t_inventory`）は Sprint 6（`V00_000_008`/`V00_000_009`）で投入済み。**検索対象の name/description は plaintext で揃っており、#2/#3 のための追加 seed は無い**（SM 調査で確認）。→ Sprint 6 の 3-repo と異なり **Sprint 7 は backend＋frontend の 2-repo**。
> - **backend**＝検索 API（`GET /api/catalog/search` 等）・検索 XML マッパー（語分割＋各語 LIKE の OR、`ESCAPE` 併用）・Application 層・permitAll への検索パス追加（#2）／`MethodArgumentTypeMismatchException` 等の 4xx 正規化ハンドラ追加・回帰テスト（#3）。
> - **frontend**＝ヘッダ検索バー・検索結果 View・route・api/store・i18n・カテゴリフィルタ UI（#2）／不正入力・stale 頁送りの回帰テスト（#3・SBD-18 実装本体は #1 で完了済）。
> - **主/従リポジトリと closes の割り当て（DEV 計画フェーズで最終確定）**：**#2 は frontend 主**（検索 UI＝ユーザー価値の capstone。Sprint 5/6 と同型）→ `closes ryokkon624/jpetstore-manage#2` は frontend PR。**#3 は backend 主**（例外正規化＝本スプリントの実質新規作業）→ `closes ryokkon624/jpetstore-manage#3` は backend PR。各 repo の他方 PR は `Related:` に留める。両 PR は同一ブランチ／スプリント末に同時マージ。
> - 2 repo に**同名ブランチ `feature/2-catalog-search-hardening`**（各 `main` から分岐・git.md 命名規約準拠。複数 Issue は 1 ブランチにまとめる＝Sprint 55 方針）。**#2・#3 の変更は Issue 単位のコミットで 1 ブランチに積む**。
> - **bug ラベルなし**（#2=`feature`・#3=`security`）＝計画フェーズでの Issue Body 更新（根本原因調査）は不要。
> **参考**：この migration-agent-base 側の Planning/Review 成果物は `feature/sprint7` ブランチにコミットし、Retro 完了時に PR＆マージする（ユーザー指示 2026-08-16）。実装コードの PR は各 repo（backend／frontend）で SM が作成する。

---

## トレース（E1 の位置づけ）

E1 カタログは 3 Feature で構成され、Sprint 7 で残り 2 Feature を完成させ E1 をクローズする：

| Feature | Issue | Sprint | スコープ | 状態 |
|---|---|---|---|---|
| F1.1 カタログ階層閲覧 | #1 | 6 | カテゴリ→商品→item→詳細の閲覧・サーバページング・在庫バッジ・plaintext description | **Done（Sprint6）** |
| **F1.2 商品検索** | **#2（本スプリント）** | **7** | 複数語 LIKE 部分一致検索・カテゴリフィルタ・ページング（SBD-17 維持・LIKE ハードニング） | 実装 |
| **F1.3 参照の堅牢化・出力安全化** | **#3（本スプリント）** | **7** | 不正ID/stale-session/非数値param の 404/空/4xx 正規化・trace 非露出（SBD-10）＋出力安全化（SBD-18）の**集約ハードニング** | 実装 |

- **挙動 spec**：`spec/behavior/catalog.md` §2（as-is 挙動・⚠stale-session 3経路）・§3（業務ルール＝語分割 OR LIKE）・§5（secure-by-default 要件）
- **横断NFR**：`spec/security-baseline.md` **SBD-10**（情報漏えい防止＝trace 非露出）・**SBD-17**（SQLi 対策維持＝パラメタライズ）・**SBD-18**（XSS 出力エスケープ）
- **意図差分**：`spec/intended-diff-ledger.md` **ID-6**（JSP→Vue3 SPA＋REST）・**ID-15**（description plaintext＋新規画像・SBD-18／#1 で達成済）・**ID-20**（4→12件/頁・API ページング）・**ID-29〔新規・本スプリント〕**（LIKE メタ文字 `%`/`_` のリテラル化＝ハードニング／後述）
- **デザイン**：`spec/design/design-brief.md`（検索バー・検索結果グリッド）

---

## ユーザー確定事項（SM 計画フェーズ・AskUserQuestion 2026-08-16）

spec/AC が PO/仕様に委譲していた 2 論点を、計画フェーズで確定（Sprint 5/6 の「spec が委譲した論点は SM が計画で承認取得」に準拠）：

1. **LIKE メタ文字（`%`/`_`）の扱い → ハードニング（リテラル化）**
   - 検索語中の `%`/`_` を LIKE ワイルドカードとして扱わず**リテラル**として一致させる（MyBatis 側で `ESCAPE '\'` を併用し入力の `%`/`_`/`\` をエスケープ）。`generatorConfig.xml` に `LIKE ... ESCAPE '\\'` の先例あり。
   - 根拠：予測可能・意図せぬ全件マッチ防止。SQLi は `#{}` パラメタライズで元々不成立（AC-neg1 は両案で満たす）。
   - **[L2] 旧同値との関係**：厳密には旧同値（レガシーはエスケープなし）と乖離するが、差が出るのは `%`/`_` を含む病的入力のみで、seed 16 商品の name/description には `%`/`_` を含む語がなく **[L2] 旧同値テストには影響しない**。
   - **→ 新規 intended-diff `ID-29` として `spec/intended-diff-ledger.md` に登録**（Retro で PO が追加。台帳文言案：「検索語の `%`/`_` を LIKE ワイルドカードとして機能（旧）→ リテラルとして一致（ESCAPE 併用・新）／根拠＝予測可能性・意図せぬ全件マッチ防止／SBD-17 維持」）。

2. **カテゴリフィルタ（AC1「任意・PO決定」）→ 今スプリントで実装**
   - キーワード検索の結果を**カテゴリで絞り込む**機能を #2 に含める。**API に categoryId（任意）パラメータ**を追加し、指定時はそのカテゴリ配下の商品に限定して LIKE 検索。**UI にカテゴリ選択**（ドロップダウン等）を追加。
   - スコープ増を認識：SP5 に対しカテゴリフィルタ分の作業が上乗せ（下記リスク参照）。既存カテゴリ一覧 API（#1）を選択肢ソースに再利用できるため増分は限定的。

> 補足の実装既定（SM 判断・ユーザー確認不要）：
> - **空キーワード**（AC2）＝frontend は空送信をガードして明示メッセージ（i18n）を表示。backend も防御的に空/空白キーワードは**空結果 200**へ正規化（500/trace を出さない）。HTTP は既存 `PageRequest` の「クランプ（400 にしない）」思想に合わせ、範囲外ページも空 200・型不一致のみ 400（#3 と統一）。
> - **検索ページサイズ**＝`PageRequest.DEFAULT_SIZE=12`（ID-20）をそのまま使用。

---

## Issue #3 本文（転記）— 実装順①

### ユーザーストーリー

**As a** サイト運営者 / 訪問者
**I want to** 不正ID・stale-session ページング・HTML内包データを安全に扱いたい
**So that** 500やXSSでユーザー体験とセキュリティを損なわない

### トレース

- **Epic**: E1 カタログ閲覧（Catalog）
- **Feature**: F1.3 参照の堅牢化・出力安全化
- **挙動spec**: spec/behavior/catalog.md §2(⚠stale-session), §5
- **横断NFR**: spec/security-baseline.md（SBD-10, SBD-18）

### Acceptance Criteria

- [ ] **AC1 (SBD-10)**: 不正/存在しない categoryId/productId/itemId は 404 または空へ正規化。as-is の trace露出3経路（viewCategory=IllegalStateException／viewProduct=NPE／viewItem=NPE）を全て解消し、スタックトレース/内部パス/版数を露出しない。
- [ ] **AC2 (SBD-18)**: `product.description` は plaintext 化（HTML非継承）、商品画像は新規アセット。全動的出力を文脈エスケープ。
- [ ] **AC-neg1 (否定AC / SBD-10)**: 非数値/巨大値/存在しないID・セッション切れ頁送りを与えても、500・trace が発生しない（正規化4xx/空）。
- [ ] **AC-neg2 (否定AC / SBD-18)**: 格納データ由来の HTML/スクリプトが実行されない（生HTML描画面が消える）。

### 備考

- 優先順位の根拠: F1.1/F1.2 の受け皿となる横断品質。SBD-10/18 の catalog 具体化。
- 依存関係: #1（F1.1）／#2（F1.2）。

### SM 実地調査メモ（#3・既達 vs 未実装）

**既達（Sprint 6 の土台で達成済み・再利用/実証で足りる）**：
- **not-found→404 正規化**：`CatalogApplicationService`（`getCategory`/`listProductsByCategory` 親存在チェック/`getProduct`/`listItemsByProduct`/`getItem` が `ResourceNotFoundException`）＋`GlobalExceptionHandler`（→404）。テスト `CatalogControllerSpec.groovy`。
- **ID 型による堅牢性**：`CatalogController` は `@PathVariable String` で受けるため「非数値/巨大値/存在しないID」でも型変換例外は起きず→DB 未ヒット→404（500 にならない）。**AC-neg1 の ID 系は既に達成**。
- **trace 非露出土台**：`GlobalExceptionHandler` catch-all（固定文言）・`ErrorResponse`（stacktrace/内部パス/版数を含まない）・`application.yml` `include-stacktrace: never`。
- **description の plaintext 化（SBD-18 格納面）**：seed `V00_000_008`（HTML 非継承・実データ plaintext）＋テスト `CatalogSeedSpec.groovy`。
- **出力の文脈エスケープ（SBD-18 描画面）**：frontend 全体で **v-html/innerHTML 使用ゼロ**（description は `{{ }}` 補間）。回帰テスト `ItemDetailView.spec.ts`（HTML/script を与えても生描画されない）。→ **AC2/AC-neg2 は #1 で実質達成済**、本スプリントは**回帰テストで実証**し「解消済み」を固定する。
- **商品画像＝新規アセット**（DB は画像パスを持たない）・**範囲外ページのクランプ/空200**（`PageRequest`）。

**未実装（本スプリントで作る・#3 の実質コア）**：
- **型不一致→4xx 正規化（最重要・trace 露出の残り穴）**：`GlobalExceptionHandler` に **`MethodArgumentTypeMismatchException` ハンドラが無い**。`?page=abc` / `?size=<Integer 範囲外>` は catch-all `Exception`→**500**。→ **400 正規化ハンドラを追加**。あわせて `MissingServletRequestParameterException`・`NoResourceFoundException` 等の未捕捉 500 リスクを棚卸しし、必要な明示ハンドラを追加。
- **回帰テスト**：`CatalogControllerSpec` に「非数値 page/size→4xx（500 でない）」「巨大値→4xx」「stale 相当の頁送り→200 空 or 4xx」を追加（AC-neg1 実証）。frontend にも不正入力/stale 頁送りの回帰。
- 方針統一：**型不一致のみ 400／範囲はクランプ維持**（既存 `PageRequest` 思想）を DEV 計画で明文化。

**要注意/設計論点（DEV 計画フェーズで整理）**：
- 「trace 露出3経路（viewCategory/viewProduct/viewItem）」は as-is（Struts）の経路。after では ID を String 受けするアーキで**既に解消**しているため、#3 は「as-is 3経路の after 版が解消済であることの実証＋残る型不一致 500 の封じ込め」と読み替える（spec §5 の 3経路と after 実装の対応を Review で明示）。
- 「404 か 空へ正規化」の使い分け（詳細不存在=404／検索0件・範囲外ページ=空200）を明文化。

---

## Issue #2 本文（転記）— 実装順②

### ユーザーストーリー

**As a** サイト訪問者（未認証を含む全ユーザー）
**I want to** キーワードで商品を検索したい
**So that** 目的の商品に素早くたどり着ける

### トレース

- **Epic**: E1 カタログ閲覧（Catalog）
- **Feature**: F1.2 商品検索
- **挙動spec**: spec/behavior/catalog.md §2, §3
- **横断NFR**: spec/security-baseline.md（SBD-17, SBD-10）

### Acceptance Criteria

- [ ] **AC1**: ヘッダの検索バーからキーワード検索し、結果をカードグリッドで表示（サーバページング 12件/頁）。複数語は語分割し各語を LIKE で部分一致（name/category/description の OR）＝as-is の一致仕様を踏襲。**カテゴリフィルタは実装する（ユーザー決定 2026-08-16）。**
- [ ] **AC2**: 空キーワードは「キーワードを入力してください」相当の明示メッセージ（500やtraceを出さない）。
- [ ] **AC3 (SBD-17)**: 検索SQLは全てパラメタライズ（プレースホルダ）。文字列連結でクエリを組まない。
- [ ] **[L2] 旧同値**: 複数語 keyword 検索のヒット商品集合・件数が旧同値（OR・name/category/description 部分一致）。※LIKE メタ文字ハードニング（ID-29）による差は `%`/`_` を含む入力のみで seed には影響しない。
- [ ] **AC-neg1 (否定AC / SBD-17)**: 検索語に SQL メタ文字（`' OR 1=1 --` 等）を入れても注入が成立せず、通常の文字列一致として扱われる。
- [ ] **AC-neg2 (否定AC / SBD-10)**: stale/セッション切れの頁送りで 500・スタックトレースが出ず、正規化された空結果/4xx になる（**#3 の例外ハードニングに依存**）。

### 備考

- 優先順位の根拠: F1.1 と同時期。カタログの主要導線。
- 依存関係: #22（E6.1）／#1（F1.1）。
- PO決定（Refinement 2026-08-11）: 検索UX＝ヘッダ検索バー＋結果カードグリッド＋サーバページング、カテゴリフィルタ任意。
- **追加確定（ユーザー 2026-08-16）**: カテゴリフィルタ＝実装する／LIKE メタ文字＝ハードニング（ID-29）。

### SM 実地調査メモ（#2・既達 vs 未実装）

**既達（再利用できる資産）**：
- **ページング DTO（12件/頁）**：`domain/common/PageRequest.java`（`DEFAULT_SIZE=12`・`MAX_SIZE=100`・1-index・クランプ）／`Page.java`／`presentation/rest/dto/PageResponse.java`（javadoc に「#2 が再利用する先例」明記）。
- **カスタム XML マッパー方式**：`mapper/custom/CatalogCustomMapper.xml`（LIMIT/OFFSET＋COUNT・全 `#{}` パラメタライズ＝SBD-17 先例）／`application.yml` の `mapper-locations`（新規 select を同 XML に追記すればロード）。
- **Product DTO**：`CatalogController` の `ProductResponse`（検索結果＝商品カードにそのまま流用）。
- **frontend カードグリッド/ページング**：`components/catalog/ProductCard.vue`／`views/catalog/ProductListView.vue`（grid＋Pagination）／`components/catalog/Pagination.vue`／`utils/pagination.ts`／`api/catalogApi.ts`（`pageQuery`）／`stores/catalog.ts`／`domain/catalog.ts`（`PageResult<T>`・「#2 が再利用」明記）。
- **検索バー CSS（未配線の既製品）**：`assets/main.css` の `.jps-search`／`.jps-search input`（マークアップを載せるだけ）。
- **商品画像アセット**：`assets/catalog/product_*.png`（全16商品）＋`utils/catalogImage.ts`。
- **seed**：検索対象の name/description（plaintext）は投入済み（追加不要）。

**未実装（本スプリントで作る）**：
- backend：**検索エンドポイント**（現状ゼロ。`GET /api/catalog/search?q=&categoryId=&page=&size=` を新規／パス設計は DEV 計画で確定）／**検索 SQL**（`CatalogCustomMapper.xml` に語分割＋各語 LIKE の OR・`ESCAPE '\'`・categoryId 任意フィルタの `searchProducts`＋`countSearchProducts`。`<foreach>` で語リストをバインド）／**語分割ロジック**（空白分割）／**Application 層** `searchProducts(keyword, categoryId, page, size)`／**permitAll に検索パスを追加必須**（未追加だと 401）。
- frontend：**ヘッダ検索バー**（`AppHeader.vue`・`.jps-search` 使用）／**検索結果 View**（`views/catalog/SearchResultView.vue` 等）＋ **route**（`/catalog/search` 等）／**api/store**（`catalogApi.searchProducts()`・`stores/catalog.ts` の検索 state/action）／**カテゴリフィルタ UI**（カテゴリ選択・既存カテゴリ一覧 API を選択肢に）／**i18n**（プレースホルダ・空キーワードメッセージ・結果見出し・0件文言）。

**要注意/設計論点（DEV 計画フェーズで整理）**：
- **検索 API パス設計**：`/api/catalog/search` か `/api/products/search`（後者は既存 `/api/products/**` permitAll に含まれる利点／`/api/products/{id}` と衝突しない順序に注意）。DEV が 1 案に確定。
- **LIKE `ESCAPE` の実装**：`CONCAT('%', #{kw}, '%')` の前段で `%`/`_`/`\` をエスケープ（Service で前処理 or SQL 関数）。ID-29 の担保点。
- **空キーワード**：frontend ガード＋backend 防御的空200（上記「補足の実装既定」）。

---

## リスク・チャレンジ

**リスク**：
- **R1〔スコープ〕カテゴリフィルタの上乗せ**：ユーザー決定で #2 にカテゴリフィルタ（API `categoryId`＋UI 選択）が加わり、SP5 に対し作業が増える。緩和＝既存カテゴリ一覧 API（#1）を選択肢ソースに再利用し増分を限定。DEV 計画で工数感を提示し、逼迫時は「フィルタ UI は最小（ドロップダウン）」に留める。
- **R2〔#2⇔#3 依存〕**：#2 の AC-neg2（頁送りで 500/trace を出さない）は #3 の `MethodArgumentTypeMismatchException` 4xx ハンドラに依存。緩和＝**実装順①で #3 の例外ハードニングを先に入れる**。
- **R3〔intended-diff の完全性〕LIKE ハードニングの旧同値乖離**：ID-29 が [L2] 旧同値 AC と表面的に矛盾。緩和＝seed に `%`/`_` 含む語が無いことを確認済（差は病的入力のみ）。Review で「[L2] は通常語の一致集合、ID-29 は `%`/`_` の解釈」と切り分けて明示。Retro で PO が ID-29 を台帳登録。
- **R4〔SBD-18 の"既達"誤認〕**：#3 の AC2/AC-neg2 は #1 で実質達成済だが、「テストが無い＝未実証」。緩和＝**回帰テストで実証**して「解消済み」を固定（Sprint 2 の"テスト green≠実機"の裏返しで、ここは"既達を回帰で固定"）。

**チャレンジ**：
- **C1〔先例の実効性検証〕**：Sprint 6 が確立した先例（ページング DTO・カードグリッド/ページネーション部品・カスタム XML マッパー・例外正規化基盤）を #2/#3 でどれだけ再利用して**手戻りゼロ・レビュー churn ゼロ**で完走できるかを検証。うまくいけば「ドメイン機能の先例再利用パターン」を Retro で明文化。
- **C2〔tier 分離 7 連続〕**：計画=Opus（論点確定）／実装=Sonnet（TDD）の tier 分離を 7 スプリント連続で適用。E1 完成という区切りで、2-repo・2-Issue（feature＋security 混在）でも手戻りゼロを狙う。
- **Claude モデル更新**：現行 Opus 4.8／Sonnet 5／Haiku 4.5 から新規リリースは確認されず＝新モデルのチャレンジは今回なし（エイリアス `opus`/`sonnet` で各 tier 最新へ自動解決）。

---

## Definition of Done（本スプリント）

- 全 AC（#2：AC1-3・[L2]・AC-neg1/2／#3：AC1-2・AC-neg1/2）を満たす。
- backend：`./gradlew build`（Spock）green。新規 EP・Security 設定変更を伴うため **DoD の実機起動＋主要 EP 疎通＋IDE 警告ゼロ**を確認（developer-workflow DoD／Sprint 2 教訓）。検索 API・不正入力/型不一致/stale 頁送りの正規化を統合テストで実証。
- frontend：`npm run test`（Vitest）green・`npm run format`／`npm run lint` クリーン。検索フロー・カテゴリフィルタ・空キーワード・SBD-18 回帰。
- 3 観点レビュー（convention/security/performance）で指摘なし（or 対応済み）。
- PR：frontend（`closes #2`＋`Related: #3`）／backend（`closes #3`＋`Related: #2`）。
