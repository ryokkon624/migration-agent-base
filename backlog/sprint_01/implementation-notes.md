## #22: [E6] DB移行基盤（Flyway・MySQL 8.4）を整備しスキーマを移行する

### 仕様外の判断・変更・妥協点

- **列名を legacy の省略形からフルワードへ拡張**: `descn`→`description`、`addr1/2`→`address1/2`、
  `zip`→`postal_code`、`suppid/catid/productid/itemid`→`supplier_id/category_id/product_id/item_id`、
  `listprice/unitcost`→`list_price/unit_cost`、`qty`→`quantity`、`orderid`→`order_id`、
  `orderdate`→`order_date`、`totalprice`→`total_price`、`unitprice`→`unit_price`、
  `linenum`→`line_num`、`attr1〜5`→`attribute1〜5` 等。ACに明記は無いが、memory/dev/short_term.md
  の AC2/AC4 対象列（`password_hash`/`total_price`/`unit_price`/`list_price`/`unit_cost`）が
  既にフルワード表記だったため、命名の一貫性を優先し全カラムに適用した。
  spec/intended-diff-ledger.md の「構造スキーマ差分は行動差分ではない」に該当（台帳非対象）。
- **t_audit_log.actor_user_id に外部キー制約を付けない**: ①存在しないusernameへのログイン失敗は
  実在user_idを持たない、②アカウント削除後も監査証跡は保持する必要がある、の2点からFKでライフ
  サイクルを縛らない方針とした。代わりに `actor_username` を非正規化して保持し追跡可能にした。
- **flyway/sql-test のフィクスチャは repeatable migration（`R__test_user.sql`）で実装**
  （Sprint Review ユーザー指摘対応・当初は `V01_000_001` の versioned として採番していたが変更）:
  versioned migration はバージョン順序に組み込まれるため、`V01_000_001` のように sql-test 側で
  独自レンジを新設しても、将来 flyway/sql 側に `V01_xxx` 以上の version が追記されると
  out-of-order で migrate が壊れるリスクがあった。repeatable migration は versioned 適用後に
  必ず実行される仕様のため flyway/sql の version 採番と衝突・干渉しない。repeatable は
  checksum 変更時に再適用される仕様のため、各 INSERT を `WHERE NOT EXISTS (...)` で
  冪等化している（再実行してもユニーク/PK制約に違反しない）。
- **m_profile.favorite_category_id は m_category への FK（ON DELETE SET NULL）を付与**：
  legacy の favcategory は bannerdata との結合キーだったが、廃止後は category との緩やかな関連
  （カテゴリ削除時はNULL化し利用者側のプロフィールを壊さない）として設計した。
- **【重要・build.gradle の既存バグを修正】** `seedDevData` タスクの `locations` が
  `flyway/sql-test` のみを指していたため、flyway/sql 側マイグレーションが1本でも実在すると
  Flyway の validate が `Detected applied migration not resolved locally` で失敗し、
  README記載の `flywayClean → flywayMigrate → seedDevData` フローが壊れることが判明した
  （AC-neg1テスト実装中に発覚。Testcontainersテストのハーネスでも同じ問題を確認）。
  `locations = ["filesystem:flyway/sql", "filesystem:flyway/sql-test"]` に修正し、
  実際に `./gradlew flywayClean flywayMigrate seedDevData` をローカルDockerのMySQLに対して
  実行して復旧を確認済み。

### 仕様確認事項（ユーザー承認不要・実装ルーチンの一部）
- テスト基盤: Groovy + Spock 2.3-groovy-4.0 + Testcontainers(mysql:8.4.0) を新規追加
  （JVM内でMySQLコンテナ1個を共有するSingletonパターン、`SchemaMigrationSpecBase` 経由）。
  `backend-conventions` スキルの「Groovy + Spock + Testcontainers」統合テスト方針を database
  repo にも踏襲した。

### レビュー指摘対応（performance・1件）
- **m_item.supplier_id に明示セカンダリインデックスを追加**: `fk_m_item_supplier_id` により
  InnoDB がFK索引を自動生成するためスキャン自体の懸念は偽陽性だったが、兄弟の `product_id` は
  明示 `KEY idx_m_item_product_id` を持つのに `supplier_id` だけ明示索引が無い非対称があった。
  基盤スキーマの一貫性・自己文書化のため `KEY idx_m_item_supplier_id (supplier_id)` を追加
  （V00_000_003は未マージのため直接編集・Flyway checksum制約に非該当）。
  `CatalogTablesSpec` に索引存在の表明テストを追加してTDD対応（RED→GREEN、51テスト全GREEN）。
