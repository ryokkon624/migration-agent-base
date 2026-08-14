# DEV 長期記憶（過去スプリントの教訓）

## 繰り返し指摘されるパターン

### jpetstore-database
- [パフォーマンス] 外部キー列に明示セカンダリインデックスが無い非対称（例: `m_item.supplier_id` に
  無く `product_id` にはある）。InnoDBのFK自動生成でスキャン自体は偽陽性だが、基盤スキーマの
  一貫性・自己文書化のため明示索引を推奨。
  発生スプリント: Sprint1（#22）

### jpetstore-backend
（今スプリントが本リポジトリ初のDEV実装スプリントのため、繰り返し指摘はまだ無し。以下の指摘はいずれも
初出＝1回目のため、2回ルールに従い本セクションではなく「習得したこと」「技術的なハマりポイント」に
記録する。ただし一部は参照知識/実装パターンとして初出からSkillへ即時反映した（詳細は「Skills更新履歴」）。）

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

### jpetstore-backend
- **Spring Security の `permitAll` は springdoc のリダイレクトエントリポイント `/swagger-ui.html` を
  別途許可する必要がある。** `/swagger-ui/**` パターンだけでは一致しない（`/swagger-ui.html` は
  `/swagger-ui/index.html` への 302 リダイレクト用の別パスのため）。Sprint Review でユーザーが
  実際にSwagger UIへアクセスして発覚。発生スプリント: Sprint2（#23）
- **Spring Boot 4 で `server.error.*` は `spring.web.error.*`（`WebProperties` のネストプロパティ、
  prefix=`spring.web`）へ移動した。** 旧プレフィックスのままでも起動時エラーにはならず「設定したのに
  効いていない」状態で気づきにくい。発生スプリント: Sprint2（#23）
- **依存のバージョンを`build.gradle`で更新した直後、IDE（VSCode Java言語サーバ等）が
  クラスパスキャッシュを更新できず旧バージョンのシグネチャで警告を出すことがある。**
  切り分けは`./gradlew compileJava`が green かどうか（greenなら実装は正しくIDE表示のみの問題）。
  VSCodeでは `Java: Clean Java Language Server Workspace` またはGradle拡張の再読み込みで解消する。
  発生スプリント: Sprint2（#23、jjwt 0.11.5→0.12.6更新後に発生）

## 習得したこと

### jpetstore-database
- Groovy + Spock + Testcontainers(MySQL 8.4) による `information_schema` 表明テストで、Flyway
  マイグレーションの適用結果をTDD（RED→GREEN）で検証するパターンを確立。`SchemaMigrationSpecBase`
  （共有MySQLコンテナ・`flyway/sql`適用）を基底に、`AccountFixtureSpecBase`（`flyway/sql-test`を
  追加適用）で階層化し、フィクスチャ依存テストとスキーマのみのテストを分離した。
- `flyway_schema_history` は repeatable migration を `version IS NULL / type='SQL'` で記録する。
  この列を直接アサートすることでrepeatable migrationが意図通り適用されたことをテストで担保できる。

### jpetstore-backend
- **Spring Boot 4.1 が自動構成する `ObjectMapper` は Jackson 3系（`tools.jackson.databind.ObjectMapper`）。**
  `com.fasterxml.jackson.databind.ObjectMapper`（Jackson 2系）はSpring Bean未登録で
  `NoSuchBeanDefinitionException`になる。Jackson 2系はjjwt-jackson/springdoc等サードパーティの内部利用
  のみでクラスパスに残存する。例外型も`tools.jackson.core.JacksonException`（Jackson3で非チェック例外化）。
  reviewerがJackson2前提で誤指摘するパターンが実際に発生した（規約明文化で再発防止・Retro昇格）。
  発生スプリント: Sprint2（#23）→ backend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **JWTのaccess/refreshはTTL以外同一構造で発行すると種別を取り違えて悪用されうる。** `typ` claim
  （`"access"`/`"refresh"`）を発行時に埋め込み、消費箇所（認証フィルタ／refresh処理）で期待型と
  照合し不一致は検証失敗として拒否する。SecReviewerの実指摘により判明。
  発生スプリント: Sprint2（#23）→ backend-conventionsへ即時反映（secure-by-defaultパターンの例外）
- **監査ログ等のclient_ipはX-Forwarded-Forを無条件信頼せず`request.getRemoteAddr()`を既定にする。**
  信頼できるリバースプロキシ構成（プロキシがヘッダを上書きする設定）が無い限り、XFFはクライアントが
  自由に偽装できるため監査証跡の汚染に繋がる。SecReviewerの実指摘により判明。
  発生スプリント: Sprint2（#23）→ backend-conventionsへ即時反映（secure-by-defaultパターンの例外）
- **カスタム（MyBatis Generator非生成）entity/mapperは`infrastructure.mybatis.custom.{entity,mapper}`
  に`XxxCustomEntity`/`XxxCustomMapper`命名で置く。** 生成物（`infrastructure.mybatis.generated.*`）
  と明確に分離する。単純なCRUD（動的条件の無い単一SQL）はXMLではなくアノテーション（`@Insert`等）で
  簡潔に書いてよい（複雑な動的SQLはXML）。**純追記表**（update/delete を業務上許可しないテーブル。
  例: 監査ログ）はMyBatis Generatorの対象外とし、意図しないupdate/delete系メソッドを生成させない
  （architecture-conventions.md §4.4として新設・明文化）。ユーザーからの配置に関する質問で判明。
  発生スプリント: Sprint2（#23）→ backend-conventionsへ即時反映（配置規約はJIT調整の一環）

## Skills更新履歴

### Sprint 2（#23）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項（Spring Boot 4.x / Spring Security 7）`
  を新設し、以下を反映（初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映。
  Sprint 2 でSecReviewer/ユーザーからの実指摘があった内容）:
  - Spring Boot 4.1のObjectMapperはJackson3系（`tools.jackson.*`）
  - JWT access/refreshは`typ` claimで型区別（secure-by-default）
  - 監査ログ等のclient_ipはXFF無条件信頼せず`getRemoteAddr()`既定
  - カスタム（MBG非生成）entity/mapperの配置（`infrastructure.mybatis.custom.{entity,mapper}`）・
    命名（`XxxCustomEntity`/`XxxCustomMapper`）・実装方式（単純CRUDはアノテーション可、複雑な動的SQLはXML）
  - frontmatterの`description`と冒頭にjpetstore-backendも対象である旨を追記（§1〜8はhw-hub由来のまま維持）
  - Swagger UI permitAll・`server.error.*`→`spring.web.error.*`・IDE lint stalenessの3件は
    **今回は反映せず**（初出＝1回目のため2回ルールの原則どおりlong_term.md「技術的なハマりポイント」に留めた）
- **`developer-workflow`**: 「作業完了時（初回完了）」のコミット前チェックに、バックエンドで新規エンドポイント・
  Security設定・`application.yml`変更を伴う場合の実機起動＋主要エンドポイント疎通＋IDE警告ゼロ確認を追加。
  **2回ルールの例外的な即時反映**: 単一の指摘の繰り返しではなく、Sprint 2 Sprint Reviewで判明した
  指摘8件中6件（Swagger UI permitAll漏れ・`server.error.*`廃止プロパティ・metadata未定義等）が
  この一手順で防げたという定量的根拠が強く、かつSMから即時反映の要否を明示的に検討するよう指示があったため。
- `#skills-changelog` へ `[DEV]` で投稿済み。

## 卒業済みルール

（該当なし。棚卸し対象となるルールが直近15スプリント基準に達していない。
  jpetstore-backendはSprint2が初実装スプリント、jpetstore-databaseもSprint1のみのため対象外）
