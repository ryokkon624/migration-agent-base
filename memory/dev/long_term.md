# DEV 長期記憶（過去スプリントの教訓）

## 繰り返し指摘されるパターン

### jpetstore-database
- [パフォーマンス] 外部キー列に明示セカンダリインデックスが無い非対称（例: `m_item.supplier_id` に
  無く `product_id` にはある）。InnoDBのFK自動生成でスキャン自体は偽陽性だが、基盤スキーマの
  一貫性・自己文書化のため明示索引を推奨。
  発生スプリント: Sprint1（#22）

## 技術的なハマりポイント

### jpetstore-database
- **開発・テスト用シードデータ（`flyway/sql-test`）は versioned（`V__`）ではなく repeatable（`R__`）で
  採番すること。** versioned はバージョン順序に組み込まれるため、sql-test 側だけの別レンジ
  （例: `V01_000_001`）を新設しても、将来 `flyway/sql` 側に version がより高いマイグレーションが
  追記されると out-of-order となり migrate が壊れる。repeatable migration は versioned migration が
  すべて適用された後に実行される仕様のため、`flyway/sql` の version 採番と衝突・干渉しない。
  ただし repeatable は内容（checksum）が変わるたびに再適用される仕様のため、各 INSERT を
  `WHERE NOT EXISTS (...)` 等のガードで冪等に書く必要がある。
  （Sprint1 #22, ユーザー動作確認での指摘対応。採番規約自体の `rules/database.md` への
  明文化はSM側で対応済み/対応予定のため重複記載しない）
- Flyway の `locations` は「適用済みマイグレーションを含む全ロケーション」を毎回渡す必要がある。
  `seedDevData` タスクで `flyway/sql-test` のみを渡すと、`flyway/sql` 側が1本でも適用済みだと
  Flywayのvalidateが `Detected applied migration not resolved locally` で失敗する
  （`flywayMigrate → seedDevData` の実運用フローでも同じ問題を確認。Sprint1 #22）。

## 習得したこと

### jpetstore-database
- Groovy + Spock + Testcontainers(MySQL 8.4) による `information_schema` 表明テストで、Flyway
  マイグレーションの適用結果をTDD（RED→GREEN）で検証するパターンを確立。`SchemaMigrationSpecBase`
  （共有MySQLコンテナ・`flyway/sql`適用）を基底に、`AccountFixtureSpecBase`（`flyway/sql-test`を
  追加適用）で階層化し、フィクスチャ依存テストとスキーマのみのテストを分離した。
- `flyway_schema_history` は repeatable migration を `version IS NULL / type='SQL'` で記録する。
  この列を直接アサートすることでrepeatable migrationが意図通り適用されたことをテストで担保できる。

## Skills更新履歴

（今スプリントはSkills更新なし。`backend-conventions` はHwHub由来で未JIT調整
  （CLAUDE.md記載のとおりPhase 3実装時に調整予定）のため対象外。上記の学びは
  2回ルール未達（Sprint1が初出）のためlong_term.md記録に留めた）

## 卒業済みルール

（該当なし）
