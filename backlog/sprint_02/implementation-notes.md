## #23: [E6] バックエンド・アーキ土台（Spring Boot 4 / 3層 / Spring Security JWT / CSRF / 監査ログ）を整備する

### 仕様外の判断・変更・妥協点
（実装中に随時追記）

- **`@PreAuthorize`由来のAccessDeniedExceptionはGlobalExceptionHandler(DispatcherServlet内)が先に捕捉し、Security側のAccessDeniedHandlerには届かない**: 実機のMockMvc end-to-endテストで発覚。`authorizeHttpRequests`（URLパターン単位）の拒否はSecurityフィルタチェーンの`ExceptionTranslationFilter`→`AccessDeniedHandler`/`AuthenticationEntryPoint`が捕捉するが、`@PreAuthorize`（メソッドセキュリティ）由来の拒否はDispatcherServletのディスパッチ内で発生し、Spring MVCの例外解決（`@RestControllerAdvice`）が先に処理してしまいフィルタチェーン側へ伝播しない。そのため監査ログ記録（AC7）は両方の経路（`GlobalExceptionHandler.handleAccessDenied/handleAuthentication`と`AuditingAccessDeniedHandler`/`AuditingAuthenticationEntryPoint`）に二重で結線した。
- **Spring Boot 4.1でSpringが自動構成するObjectMapperはJackson 3系（`tools.jackson.databind.ObjectMapper`）**: `com.fasterxml.jackson.databind.ObjectMapper`（Jackson 2系）はSpring Bean未登録で`NoSuchBeanDefinitionException`になる（実機検証で確認）。Jackson 2系はjjwt-jackson/springdoc等サードパーティ内部利用のためクラスパスに残存するだけで、アプリコードでSpring管理のObjectMapperを使う場合は`tools.jackson.*`パッケージを使うこと（`AuditLogRecorder`で採用）。例外型も`tools.jackson.core.JacksonException`（Jackson3で非チェック例外=RuntimeExceptionに変更）。後続ドメインStoryがJSON処理する際に踏襲すべき知見。
- **Spring Boot 4.1 / Spring Security 7でのパッケージ移動（実機ビルドで判明。ドキュメント記載が追いついていない箇所）**: `DataSourceAutoConfiguration`→`org.springframework.boot.jdbc.autoconfigure`、`UsernamePasswordAuthenticationFilter`→`org.springframework.security.web.authentication`、`@AutoConfigureMockMvc`/`@WebMvcTest`→`org.springframework.boot.webmvc.test.autoconfigure`（アーティファクトも`spring-boot-webmvc-test`に分離・`spring-boot-starter-test`だけでは入らないため明示的にtestImplementation追加が必要）。後続Storyで同種のimportエラーが出たら、まずこの手のパッケージ再編を疑うこと。
- **DB資格情報のfail-fastは`@Value`強制解決の専用Bean（`RequiredSecretsValidator`）で担保**: `spring.datasource.username/password`は`@ConfigurationProperties`（Binder）経由でバインドされるため、`${DB_USERNAME}`が未解決でも例外を投げずリテラル文字列のまま素通りすることを実機検証で確認した（`ApplicationBootFailFastSpec`で実証）。`@Value`によるプレースホルダ解決（未解決なら`PlaceholderResolutionException`で即座に失敗）とは挙動が異なるため、`config.RequiredSecretsValidator`（`@Value`で強制解決するだけの薄いBean）を追加し、DB資格情報もJWT鍵と同様に起動時点で確実にfail-fastするようにした。AC5には明記されていない追加コンポーネントだが、「未設定なら起動失敗」という要件を実際に満たすために必須と判断した。

### AC6: 依存の版棚卸し（実施結果）

`./gradlew dependencies` で compile/runtime/test 各classpathの依存木を実際に解決して確認（オフライン監査。ライブCVEデータベースへの接続は本環境に無いため、既知の保守状況・EOL傾向の知識ベースでの判断）。

| 依存 | 版 | 判定 |
| --- | --- | --- |
| Spring Boot | 4.1.0 | 現行。Spring Framework 7 / Jackson 3系ベース |
| Java | 21 (LTS) | 2029年まで長期サポート |
| MyBatis Spring Boot Starter | 4.1.0 | 現行 |
| MySQL Connector/J | 9.5.0 | 現行9.x系 |
| Spring Security | 7.1.0（BOM経由） | 現行 |
| jjwt | 0.11.5 → **0.12.6 に更新**（本Storyで対応） | 0.11系は旧API・保守終息傾向のため更新 |
| springdoc-openapi | 3.0.2 | Boot4/Spring7対応の現行メジャー系列 |
| MyBatis Generator | 1.4.2（ビルド時ツールのみ・実行時依存に含まれない） | 現行 |
| Testcontainers | 1.21.4 | 現行 |
| Flyway | 12.4.0（Boot BOM経由・flyway-core） | 現行メジャー系列 |
| Jackson | 3.1.4（`tools.jackson`。Spring管理）＋2.21.4（サードパーティ内部利用のみ・BOM管理） | いずれも現行系列 |

版固定はBOM（`io.spring.dependency-management`）経由の推移的ピンを許容しつつ、直接依存は明示バージョンを指定（レンジ指定は使用していない）。既知の重大CVEが指摘されている版の使用は確認されなかった。

### AC-neg1: 平文秘密のgrep確認と既知の例外

`src/main` を grep 確認した結果、アプリ本体（`application.yml`・`JwtProperties`等）に平文秘密は無い
（`${DB_USERNAME}`/`${DB_PASSWORD}`/`${JWT_SECRET}`のプレースホルダのみ）。

**既知の例外（本Story対象外・スコープ外として維持）**: `tool/EnumGenerator.java`（`JDBC_USER`/`JDBC_PASSWORD` =
`"jpetstore"`固定）と`resources/generator/generatorConfig.xml`（`password="jpetstore"`）。scaffold(`09ec431`)由来の
既存資産で、SM調査メモに「既存を尊重（本スプリント対象外）」と明記されている。`localhost`固定のローカル専用開発ツール
（`main()`を持つだけでSpringコンテキストに組み込まれず、デプロイされるアプリの起動経路に含まれない）であり、値も
`jpetstore-database`のdocker-compose既定値（`.env.example`と同じ、非秘匿のローカル開発規約値）と同一のため、
リスクは限定的と判断し本Storyでは変更しない。後続でこのツール自体に手を入れる際は同様に環境変数化を検討すべき。
（恒久課題）`EnumGenerator`/`generatorConfig.xml`のJDBC資格情報も、他の設定と同様に環境変数化（`${DB_USERNAME}`/`${DB_PASSWORD}`）することを将来の改善候補として記録する。

### レビュー指摘対応（SM verification 経由・2件）

- **【中・確定】JWT access/refresh トークンの型混同**: `JwtService.buildToken`がaccess/refreshでTTL以外完全同一構造・`typ` claim無しだったため、`parseToken`/`JwtAuthenticationFilter`/`AuthApplicationService.refreshAccessToken`が種別を区別できず、refresh tokenをACCESS_TOKEN Cookieに入れると保護エンドポイントに直接認証できてしまう問題があった。`typ` claim（`"access"`/`"refresh"`）を発行時に埋め込み、`parseToken`を`parseAccessToken`/`parseRefreshToken`に分離して期待型と不一致なら`Optional.empty()`（検証失敗）を返すよう修正。`JwtAuthenticationFilter`=access専用、`AuthApplicationService.refreshAccessToken`=refresh専用に消費箇所を修正。Spockで型混同拒否テストを4箇所に追加（`JwtServiceSpec`双方向2件、`JwtAuthenticationFilterSpec`、`SecurityEndToEndSpec`各1件）。
- **【低→secure-by-defaultで対応】`AuditLogRecorder#clientIp`のX-Forwarded-For無条件信頼**: 信頼プロキシ設定が無い現状でXFFを無条件信頼すると偽装により監査証跡が汚染される問題があった。既定を`request.getRemoteAddr()`のみに変更し、信頼プロキシ前提のXFF採用は将来のinfra対応としてTODOコメントを残した。`AuditLogRecorderSpec`にXFF偽装を無視することを実証するテストを追加。

### Sprint Reviewユーザー指摘6件への対応

- **①Swagger UI起動しない（実機再現・修正）**: `jpetstore-database`のDocker MySQLを起動し`DB_USERNAME`/`DB_PASSWORD`/`JWT_SECRET`を与えて`./gradlew bootRun`で実際に再現。`curl http://localhost:8080/swagger-ui.html`が401、`/swagger-ui/index.html`は200であることを確認し、仮説どおり`SecurityConfig`のpermitAllが`/swagger-ui/**`のみで`/swagger-ui.html`（springdocのリダイレクトエントリポイント。`/swagger-ui/index.html`へ302リダイレクトする別パス）を許可していないことが根本原因と特定。`permitAll`に`/swagger-ui.html`を追加して解消（修正後は302→200で正常にUIが開ける。`/v3/api-docs`のOpenAPI定義内容も正常に取得できることを確認）。springdoc 3.0.2とSpring Boot 4.1の組み合わせ自体に互換性問題は無かった。回帰防止としてSpockテスト2件（`/swagger-ui.html`が302・`/v3/api-docs`が200）を追加。
- **②application.ymlのdeprecatedプロパティ**: `server.error.*`はSpring Boot 4で`spring.web.error.*`（`org.springframework.boot.autoconfigure.web.WebProperties`の`error`ネストプロパティ、prefix=`spring.web`）へ移動していることをバイトコード解析で確認しリネーム。実機で`/swagger-ui/nonexistent-resource.js`等の未マップパスにアクセスしても内部詳細が漏れないことを確認（実際にはGlobalExceptionHandlerの汎用`Exception`ハンドラが大半のケースを先に捕捉するため、`spring.web.error.*`はフィルタチェーン等ディスパッチ外で発生した例外に対する多層防御として機能する）。
- **③`Unknown property 'jwt'`**: `jwt.*`は`@Value`バインドのためSpring Bootの自動生成メタデータが無くIDE警告が出る。hw-hub-backend（`META-INF/spring-configuration-metadata.json`手書き）と同形式で`src/main/resources/META-INF/spring-configuration-metadata.json`を新規作成し、`jwt.secret`/`jwt.access-token-ttl`/`jwt.refresh-token-ttl`/`jwt.cookie.same-site`/`jwt.cookie.secure`を型・description付きで列挙。
- **④⑤ null型安全警告**: `SecurityConfig`の`AbstractHttpConfigurer::disable`、`AuthCookieSupport`の`Cookie::getValue`のメソッド参照をラムダ化（`form -> form.disable()`等）。JDTのnull解析はメソッド参照だと型情報の伝播が弱く警告を出すことがあるため、ラムダの方が安全側に倒せる。挙動は不変（既存テスト全green）。
- **⑥AuditLogMapper/Entityの配置**: `backend-conventions`スキルとhw-hub-backendの実装（`infrastructure/mybatis/custom/{entity,mapper}`・`XxxCustomEntity`/`XxxCustomMapper`命名）を確認し、`AuditLogEntity`/`AuditLogMapper`（`infrastructure.audit`直下）を`infrastructure.mybatis.custom.{entity,mapper}`へ`AuditLogCustomEntity`/`AuditLogCustomMapper`に改名して移設。`@MapperScan`もhw-hub-backendと同じ`infrastructure.mybatis.{generated,custom}.mapper`の2エントリ構成に統一。`AuditLogRecorder`（ファサード）自体は監査という横断関心のため`infrastructure.audit`に留めた。
  - **なぜ手書き（MyBatis Generator生成対象外）か**: `t_audit_log`は追記専用の監査証跡（architecture-conventions §4.3「純追記表」）であり、Generatorを適用すると本来持たせたくないupdate/delete系メソッドまで生成されてしまい「追記専用」という制約をコードで表現できなくなる。また生成には稼働中DB接続が必要で、本テーブルは書き込み専用の単機能（INSERT 1本）のため生成コストに見合わない。以上の理由から配置は規約に合わせつつ、生成せず手書きで維持する方針とした（Sprint Review `#30-sprint-review`スレッドにも同内容を回答）。
  - **アノテーション vs XML**: hw-hub-backendのcustom mapperはXML中心だが、本Mapperは単純なINSERT1本のみで動的条件が無いため、アノテーション（`@Insert`）のまま維持した（配置・命名規約は合わせたが実装方式まではXMLに統一しなかった、という判断をここに明記する）。
