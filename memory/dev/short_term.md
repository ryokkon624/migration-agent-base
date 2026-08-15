# DEV 短期記憶

## Sprint 6 / #1 E1 カタログ階層閲覧（承認済み実装方針・2026-08-16）

初のドメイン機能。3-repo cross-repo。計画=Opus / 実装=Sonnet。**実装はSonnet再起動後**（本記録時点で未着手）。

### ユーザー承認3決定
1. **残少閾値 N=5**: `qty≤0`=在庫切れ / `0<qty≤5`=残少 / `qty>5`=在庫あり。定数/config化（マジックナンバー禁止）。
2. **在庫ステータス=m_code区分値で登録**（★DEV推奨「手書きenum」をユーザーがオーバーライド。方針=「区分値は基本的にm_codeに登録」。architecture-conventions §3.1が在庫ステータスをm_code候補に挙げ「確定はPO/仕様で」→ PO/仕様の確定としてm_code採用）。
3. **ページ採番=1-index**: `PageResponse<T>{ content, page(1始まり), size, totalElements, totalPages }`。#2/#9が再利用する先例規約。

### ②m_code化の実装フロー（生成の仕組みを実地確認済み）
- **database**: m_codeに新 code_type `0003`（既存: 0001=OrderStatus, 0002=CardType, 0012=ProgramType廃止済→0003が次番）。`code_type_name_en='StockStatus'`・値 IN_STOCK/LOW_STOCK/OUT_OF_STOCK・`display_name_ja`(在庫あり/残少/在庫切れ)/`display_name_en`(In Stock/Low Stock/Out of Stock)。WHOはInterceptor不効=リテラル`'INIT_DATA'`。
- **frontend生成取り込み**: database `./gradlew generateEnums`（MultiEnumGenerator）→`build/generated/frontend/code.constants.ts`→frontend `src/constants/code.constants.ts`へコピー（現状placeholder）。バッジ文言は生成表示名を使う。既存 `home.tokens.stockIn/stockLow/stockOut` i18nキー（HomeViewトークン確認表示）とreconcile。
- **backend生成**: backend `./gradlew generateEnums`（EnumGenerator）は**全m_code code_typeを`domain/enums/*.java`に生成**（OrderStatus.java/CardType.javaは生成物・再実行で上書き）。→ StockStatus.javaも**生成物**。
- ⚠**閾値算出`of(qty)`は生成enumに入れない**（再生成で消える）。非生成の別クラス `StockStatusCalculator`（domain）に`of(int quantity):StockStatus`を置く（N=5）。
- **qty非露出は不変**（R3）: レスポンスJSONに qty/quantity を一切出さない。IT で「qtyフィールド非存在」を表明。

### SM確定（技術/プロセス）
- **主/従・closes**: 主=frontend（`closes #1`）／従=database・backend（`Related: #1`）。3repo同名ブランチ **`feature/1-catalog-browsing`**（各mainから新規分岐）。backendはseed追加後 `./gradlew syncTestSchema`（flyway/sqlのみコピー＝V00_000_008も同期される。sql-testは対象外）。
- **ページング**: `size`をAPIパラメータ化（既定12・cap100）。**理由=[L2]忠実seedは最大DOGS6商品・最大K9-RT-02の4itemで全<12→size=12固定だと多頁を実証不能**。テストは`size=2`で多頁強制（DOGS6商品→3頁）。categoriesは5件固定=非ページング（単純list）。
- **item詳細カート追加**: #1は非活性プレースホルダ（disabledボタン・handler/store/API無し＝AC4のGET only維持）。実挙動・在庫切れ追加不可(ID-18)は#4。
- **not-found**: #1はget/list 3経路（category/product/item）で該当行無し→`ResourceNotFoundException`→既存GlobalExceptionHandlerで404（trace非露出はSBD-10基盤=#23既達で自動担保）。集約ハードニング・否定AC網羅は#3(F1.3/Sprint7)。
- **MyBatis**: カスタム手書きXMLマッパー（Generator非登録）。読み取り専用＋階層＋ページング(LIMIT/OFFSET)＋JOIN(item×inventory=在庫、item×product=商品名)＋COUNT。配置`infrastructure.mybatis.custom.{entity,mapper}`・XML`resources/mapper/custom/*.xml`・命名`XxxCustomEntity/Mapper`。
- **seed**: `flyway/sql/V00_000_008__insert_catalog_master.sql`（本番相当・m_code seed=V00_000_002と同格。FK順1ファイル: supplier→category→product→item→inventory・plaintext description〈旧`<image src=...>`継承せず・SBD-18/ID-15〉・[L2] category5/product16/item28）。qty3状態作り分け案: FI-SW-01の EST-1=100(IN)/EST-2=3(LOW)・FI-SW-02の EST-3=0(OUT)・他は原則100（正確なqty表は実装時確定・seed表明テストでIN/LOW/OUT件数固定）。
- **画像**: `spec/design/images`(category5/product16/placeholder.svg)→frontend `src/assets/catalog/`＋`import.meta.glob(eager)`＋`resolveCatalogImage(kind,id)`＋placeholderフォールバック。itemは対応productId画像流用。`<img loading="lazy">`（R6）。

### [L2] 階層（レガシー`legacy-jpetstore/db/mysql/jpetstore-mysql-dataload.sql`＝参照元）
- category5: FISH/DOGS/REPTILES/CATS/BIRDS
- product16: FISH4(FI-SW-01,FI-SW-02,FI-FW-01,FI-FW-02)/DOGS6(K9-BD-01,K9-PO-02,K9-DL-01,K9-RT-01,K9-RT-02,K9-CW-01)/REPTILES2(RP-SN-01,RP-LI-02)/CATS2(FL-DSH-01,FL-DLH-02)/BIRDS2(AV-CB-01,AV-SB-02)
- item28: EST-1〜EST-28（全16商品が1件以上のitemを持つ。最多=K9-RT-02の4件〈EST-22..25〉）

### TDD/DoD 要点
- database: schema/seed表明テスト先行（[L2]件数・IN/LOW/OUT件数・description無HTML）。`seedDevData`/schema spec green。
- backend(Spock): `StockStatusCalculatorSpec`(UT where:網羅)→mapper IT([L2]件数・LIMIT/OFFSET slice・COUNT)→controller IT(未認証200・size=2多頁・**qtyフィールド非存在**・404・非GET405)。`spotlessApply`・実機起動＋EP疎通・IDE警告0。
- frontend(Vitest): store/stockBadge/catalogImage/pagination＋**AC-neg1**（descriptionにHTML/script与え生描画されず実行されない・`v-html`不使用を`@vue/test-utils` mountで固定＝否定ACのためview相当を例外的にテスト）。`npm run build`(vue-tsc)・`npm run format`。

### エンドポイント設計（案・実装で確定）
GET `/api/categories`（非ページ）・`/api/categories/{id}`・`/api/categories/{id}/products?page&size`・`/api/products/{id}`・`/api/products/{id}/items?page&size`・`/api/items/{id}`（在庫status・qty非露出）。SecurityConfigはpermitAllを`HttpMethod.GET`スコープで追加（非GETは405維持＝AC4）。

### 参考: migration-agent-base側Planning/Review成果物は `feature/sprint6` ブランチ（実装コードPRは各repoでSMが作成）。
