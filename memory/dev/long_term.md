# DEV 長期記憶（過去スプリントの教訓）

## 繰り返し指摘されるパターン

### jpetstore-database
- [パフォーマンス] 外部キー列に明示セカンダリインデックスが無い非対称（例: `m_item.supplier_id` に
  無く `product_id` にはある）。InnoDBのFK自動生成でスキャン自体は偽陽性だが、基盤スキーマの
  一貫性・自己文書化のため明示索引を推奨。
  発生スプリント: Sprint1（#22）
- Sprint6（#1・カタログseed新規投入。本プロジェクト初のフルスタックドメイン機能・3-repo cross-repo）も
  3観点レビュー指摘0件だった。要因は下記「横断（database＋backend＋frontend）」参照。

### jpetstore-backend
Sprint2（#23）・Sprint3（#18/#19）・Sprint4（#21/#20）・Sprint6（#1）・Sprint7（#2/#3）・Sprint9（#5/#6）とも
実装スプリントを終えたが、3観点レビュー（規約/セキュリティ/パフォーマンス）での**指摘は今のところ0件の
繰り返しも無し**（Sprint3はレビュー指摘自体が0件、Sprint4は規約/パフォーマンスが0件・セキュリティは
非ブロッキング2件、Sprint6は3観点とも0件、Sprint7はconvention/securityが0件・performanceのみ非ブロッキング
1件で再修正不要、Sprint9は3観点とも指摘0件でクリーン）。
以下の発見はいずれもDEV自身がTDD・実機検証中に見つけたもので初出＝1回目のため、2回ルールに従い本セクション
ではなく「習得したこと」「技術的なハマりポイント」に記録する。ただし一部は参照知識/実装パターンとして
初出からSkillへ即時反映した（詳細は「Skills更新履歴」）。

Sprint7の`@RestControllerAdvice`catch-all問題（後述「技術的なハマりポイント」）はSprint3に続く2回目の
発生のため、本スプリントでSkill（`backend-conventions`§9）へ昇格した（唯一の2回ルール昇格ケース）。

Sprint4のセキュリティ非ブロッキング2件（`AuthApplicationService.login`のタイミング副次チャネル／
ロックアウトのcheck-then-act非原子性）はレビュー指摘そのものではあるが、SMが実コードで検証のうえ
ユーザー承認を得て「コード修正不要の受容リスク」と判断した設計トレードオフであり、防ぐべき実装ミスの
再発パターンではないため本セクションでは追跡しない（根拠は「習得したこと」に記録。詳細は
`backlog/sprint_04/implementation-notes.md`）。

- [セキュリティ] **同種のミューテーションメソッド群のうち1つだけ数量（状態変更値）の下限バリデーション・
  intオーバーフロー検証が漏れていた**。`CartApplicationService`の`addItem`/`updateItem`/`merge`/
  `checkOrderable`は全て数量を扱うが、`updateItem`（quantity<=0で削除）・`merge`（quantity<=0を無視）・
  `checkOrderable`（quantity<=0を`INVALID_QUANTITY`扱い）は下限を処理済みだったのに対し、`addItem`だけ
  `requestedQuantity<=0`のチェックが無く、かつ既存数量との加算がintをオーバーフローすると負の巨大な値に
  ラップし`newQuantity > stockQuantity`の上限チェックを迂回して負の数量が永続化されうる状態だった
  （SBD-2違反。SMが実コードでCONFIRMED）。DTO`@Min(1)`＋サービス層`<=0`拒否（400）＋`Math.addExact`による
  オーバーフロー検出で修正した（`backlog/sprint_08/implementation-notes.md`参照）。新しい数量/状態変更値を
  受け取るメソッド群を実装する際は、**同じ入力（quantity等）を扱う兄弟メソッド全体で下限・上限・オーバー
  フローの検証方針が揃っているかを横断的に棚卸しする**必要がある（1メソッドだけ実装パターンを流用し忘れる
  形で漏れが生じた）。
  発生スプリント: Sprint8（#4、SecReviewer/SM指摘。初出のため2回ルールに従い本Skillには未反映）

- [パフォーマンス][スコープ外・技術的負債として記録] **`CartApplicationService#merge`のループ内で
  `cartCustomMapper.selectItemForCart`を1行ずつ呼び出しており（N+1）、backend-conventions §4a
  「N+1問題の防止」に抵触する。** Sprint9（#5/#6）でperformance-reviewerが指摘したが、この実装は
  Sprint8（#4）時点で導入済みの既存コードであり、Sprint9のスコープ（価格権威・数量検証統一／CSRF
  ハードニング）はこのメソッドの`quantity<=0`ガードを追加しただけでクエリパターン自体には触れていない
  ため、SMが「Sprint8由来の既存問題・本スプリントのスコープ外」と判定した（3観点レビュー指摘0件の
  実績にはこの1件を数えない）。§4a自体は既にSkill化済みの汎用ルールのため新規チェックリスト項目は
  不要だが、次に`CartApplicationService#merge`（または同メソッド群）へ着手するStoryで一括クエリ化
  （例: `selectItemsForCart(List<String> itemIds, cartId)`でN行分をまとめて取得しMapへ変換してから
  ループ処理する）を検討する必要がある未解消の技術的負債として記録する。
  発生スプリント: Sprint9（#5/#6、performance-reviewer指摘・SMがスコープ外判定。根本原因はSprint8（#4）由来）

### jpetstore-frontend
Sprint5（#24）が初のフロントエンド実装スプリント。3観点レビューでパフォーマンス1件・セキュリティ1件の
指摘があった（規約は指摘なし）。いずれも初出（1回目）のため、2回ルールに従いSkillのチェックリストへは
まだ昇格させず、本セクションで発生スプリントを記録して待機する。

- [パフォーマンス] **互いに独立した非同期初期化処理を直列awaitしていた**。`main.ts`で
  `primeCsrfToken()`→`fetchCurrentUser()`を直列に`await`していたが、両者は依存関係が無い
  （`/me`はGETでCSRF非依存）ため`Promise.all([...])`で並列化すべきだった。
  発生スプリント: Sprint5（#24）
- [セキュリティ] **オープンリダイレクト対策バリデータの制御文字判定が先頭1文字目のみだった**。
  `sanitizeRedirectTarget`が`codePointAt(0)`のみで制御文字を判定していたため、`/\t/evil.com`
  （2文字目にタブ）のように先頭以外に制御文字が混入するケースを素通りさせていた
  （WHATWG URLパーサはタブ/改行を位置問わず除去して正規化するため将来的なバイパス経路になりうる）。
  文字列全体をcode point走査する`containsControlCharacter`に拡張して解消した。
  発生スプリント: Sprint5（#24）
- Sprint6（#1・カタログ画面新規実装。2回目のフロントエンド実装スプリント）は、Sprint5より実装規模が
  大きいにもかかわらず3観点とも指摘0件だった。Sprint5の2件（上記）はいずれも1回目のままで2回目の再発が
  無いため、本セクションでの待機を継続する（次回同種発生時に2回目→Skill昇格を判定）。要因は下記
  「横断（database＋backend＋frontend）」参照。

### 横断（database＋backend＋frontend）
- **Sprint6（#1）は3観点レビュー（規約/セキュリティ/パフォーマンス）が3-repoすべてで指摘0件だった。**
  Sprint5（frontend初実装）ではパフォーマンス1件・セキュリティ1件の指摘があったのに対し、Sprint6は
  規模がより大きい（3-repo cross-repo・カタログ階層API＋画面一式のフルスタック新規実装）にもかかわらず
  全指摘0件で完走した。要因を次スプリント以降に活かせる形で整理する:
  1. **secure-by-defaultな土台の上に積んだ**: #22（DB）・#23（backend認証/認可）・#24（frontend認証/CSRF）
     で確立済みの土台（例外→404正規化・permitAllの限定列挙・CSRF自己修復・trace非露出）をそのまま再利用し、
     カタログ機能側で新たなセキュリティ機構を自作しなかった。土台を薄いうちに固めておくほど、後続の
     ドメイン機能実装でレビュー指摘の芽自体が減る。
  2. **計画フェーズでレビュー観点を先回りしてACに落とし込んだ**（`backlog/sprint_06/sprint_backlog.md` C3
     参照）: 計画時点で「qtyをレスポンスに一切出さない」（在庫数非露出・R3）・「`v-html`を使わない」
     （AC-neg1・SBD-18）・「permitAllは`HttpMethod.GET`スコープで限定し非GETは405のまま維持」（AC4）を
     明文化しAC・テストへ落とし込んでいたため、実装段階で規約・セキュリティ違反が生まれる余地自体が無かった。
  3. **設計上の曖昧さを計画フェーズでユーザー承認により確定した**: 在庫ステータスの実装方式（m_code区分値
     採用）・ページングDTOの形（1-index・`Page`/`PageRequest`/`PageResponse<T>`）を実装開始前にユーザー
     承認まで得て確定していたため、実装中に規約から外れた自己流の設計判断をする必要が無かった。

  **次に活かす教訓**: レビュー指摘を減らす最も効果的な手段は「実装後にレビューで直す」ことではなく、
  **計画フェーズでレビュー観点（規約/セキュリティ/パフォーマンス）を先回りしてACに明文化し、設計論点を
  ユーザー承認で確定してから実装に入る**ことである。#2（検索）・#3（参照堅牢化）・#4（カート）等の
  後続Storyでも、計画フェーズのAC整備でこの3点（土台再利用の徹底／レビュー観点の先回りAC化／設計論点の
  事前確定）を意識する。
  発生スプリント: Sprint6（#1）
- **Sprint7（#2/#3）はSprint6の3点（土台再利用／レビュー観点の先回りAC化／設計論点の事前確定）を
  そのまま適用し、convention/securityは指摘0件・performanceのみ軽微な非ブロッキング1件（再修正不要）で
  完走した。** 加えてSprint7固有の要因として、**Sprint6で新設した再利用資産（`Page`/`PageRequest`/
  `PageResponse<T>`・カスタムXMLマッパー方式・`ProductCard`/`Pagination`/`CatalogBreadcrumb`等のUI部品・
  `.jps-search`未配線CSS）を#2/#3が計画通り再利用し、手戻りゼロで実装できた**（Sprint6時点で「#2/#9が
  再利用する先例規約」と明記していた設計が実際に機能した＝C1チャレンジの実証）。2スプリント連続の
  クリーン実装により、「secure-by-defaultな土台の上に積む」「先例を再利用する」パターンが偶然ではなく
  再現可能な設計原則であることが確認できた。
  発生スプリント: Sprint7（#2/#3）
- **Sprint8（#4・カート）はSprint6/7の読み取り専用ドメインと異なり、初のwrite（状態変更・在庫ガード）
  ドメインでのC1チャレンジ再検証だった。土台再利用（`CurrentUserProvider`・`GlobalExceptionHandler`・
  `StockStatusCalculator`・CSRF/認証既定・`SecurityConfig`変更ゼロ）は成功したが、conv/perfは指摘0件・
  secのみ1件（`addItem`の数量下限バリデーション欠落）発生し、Sprint6/7の「3観点とも0件」の連続記録は
  途切れた。** 要因は、土台（認可・例外正規化・CSRF等の横断的関心事）の再利用だけでは、**ストーリー固有の
  ドメインロジック（今回は「数量」という新しい入力の妥当性検証）まではカバーされない**こと。土台再利用が
  防げるのは「車輪の再発明で作り込む新規バグ」であり、「新しいドメイン値に対する検証の作り込み漏れ」は
  ストーリーごとに個別に注意する必要がある。計画フェーズでレビュー観点を先回りしてAC化する際、「新しく
  受け取る値（数量・金額等）の妥当性検証（下限/上限/型/オーバーフロー）を全ての受理経路で横断的に洗い出す」
  観点をAC/実装チェックリストに含めることが今後の再発防止に有効（Sprint6/7で確立した3点＝土台再利用・
  レビュー観点先回りAC化・設計論点事前確定、に「新規入力値の受理経路横断チェック」を加える形で次スプリント
  以降に活かす）。
  発生スプリント: Sprint8（#4）

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
- **`m_code.code_value` は `VARCHAR(10)` のため、意味のある英語コード値でも10文字を超えると登録できない。**
  在庫ステータスの区分値として`OUT_OF_STOCK`（12文字）を登録しようとしたが列幅超過のため`OUT_STOCK`
  （9文字）に短縮した。Javaのenum定数名は生成ルール上`display_name_en`（`Out of Stock`）から導出されるため
  `OUT_OF_STOCK`のまま生成され、DB上の`code_value`とJava定数名が完全一致しない非対称が生じる（意図した
  仕様であり不具合ではないが、新規`code_type`追加時は先に`code_value`の文字数を確認すること）。
  発生スプリント: Sprint6（#1）

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
- **`@RestControllerAdvice` の catch-all（`@ExceptionHandler(Exception.class)`）は、専用ハンドラの無い
  フレームワーク例外を意図しないステータスに丸めてしまう。** `HttpRequestMethodNotSupportedException`
  （未マッピングHTTPメソッドへのアクセス）は本来 405 だが、専用ハンドラが無いと catch-all に落ちて 500 に
  なっていた。AC-neg2（GETでの状態変更不可＝405期待）の自動テストで顕在化。`GlobalExceptionHandler` に
  `@ExceptionHandler(HttpRequestMethodNotSupportedException.class)` を追加して 405 に正規化した。
  catch-all を持つ例外ハンドラを書く/レビューする際は、Spring MVC が個別ステータスに自動マッピングする
  はずの例外（405/415等）を横取りして握りつぶしていないか確認する必要がある。
  発生スプリント: Sprint3（#18）→ **Sprint7で2回目発生**（`MethodArgumentTypeMismatchException`＝
  `?page=abc`等の型不一致／`MissingServletRequestParameterException`＝必須パラメータ欠落／
  `NoResourceFoundException`＝未知パスへのアクセス、の3例外が同じ理由で500に落ちていた）ため、
  backend-conventionsへ即時反映（2回ルール昇格。既知の該当例外一覧としてSkillに表化）。
- **Spring Security の CSRF（`XSRF-TOKEN` Cookie・`CookieCsrfTokenRepository`）は、状態変更（非GET）
  リクエストが成功するたびにサーバー側で Cookie を失効させ、次の GET リクエストで新しいトークンが
  再発行される（consume-then-regenerate）。** `/api/auth/login`（新規）だけでなく `/api/auth/refresh`
  （#23由来・未変更）でも同一現象を確認したため、#18/#19 で新規に混入した挙動ではなく Spring Security 7
  の既存動作。手動での実機疎通確認（curlでの連続POST）で初めて気づいた。自動テスト（`.with(csrf())`
  postprocessor でトークンを直接注入）ではこの挙動を経由しないため検知できなかった。フロント実装時は
  連続する状態変更リクエストのたびに最新の `XSRF-TOKEN` Cookie 値を再取得してヘッダに載せる設計が必要
  （#24 への申し送り事項。`backlog/sprint_03/implementation-notes.md` 参照）。
  発生スプリント: Sprint3（#18、実機疎通確認時に発見）
- **セキュリティ上意味のある日時比較（ロック期限・有効期限等）はJava側ではなくDB側（`NOW(6)`等）で
  行うこと。** ロックアウト機能の当初実装（`LoginAttemptCustomEntity`で`lock_until`をJava側に取得し
  `LocalDateTime.now()`と比較）は、JVM実行環境（JST）とTestcontainers/Docker上のMySQL（UTC）間の
  クロックスキューによりロック判定が常にfalseになり機能しなかった（IT実行で発覚）。
  `WHERE lock_until > NOW(6)`のように比較そのものをSQL側（DB自身の時刻基準）で完結させる
  `LoginAttemptCustomMapper#countActiveLock`に置き換えて解消した。タイムゾーン設定を揃える対症療法
  ではなく、時刻比較をDB側に寄せる方が環境間のクロックスキューに対して恒久的に頑健。
  発生スプリント: Sprint4（#20、IT実行で発見）
- **MySQLの`ON DUPLICATE KEY UPDATE`のSET句は左から右へ評価され、後続の式が同一文内で既に代入済みの
  列の新しい値を参照できる（ドキュメント化された挙動）。** 単文アトミックな失敗カウンタ更新
  （`failed_attempt_count = failed_attempt_count + 1, lock_until = IF(...)`）で、`lock_until`の閾値判定式が
  `failed_attempt_count`のSET句と独立に同じ加算式を再計算していたところ、この評価順の影響で
  「実際の失敗回数より1回分前倒しでロックする」ズレが生じた（IT実行で発覚）。`lock_until`のSET句を、
  直前のSET句で更新済みの`failed_attempt_count`（新しい値）をそのまま参照する形に単純化して解消した。
  複数列を同一`INSERT ... ON DUPLICATE KEY UPDATE`文で更新する際は、この評価順依存の二重計算・
  ズレに注意する。
  発生スプリント: Sprint4（#20、IT実行で発見）
- **本プロジェクト初のMyBatisカスタムXMLマッパー導入時、`application.yml`に`mybatis.mapper-locations`を
  明示しないとXMLが一切ロードされない。** それまではMyBatis Generator生成物（`resources/mapper.generated`）
  しか無くマッパーXMLの読み込み設定自体が不要だったため気づきにくい。`classpath:mapper/**/*.xml`を
  `application.yml`へ追加して解消した（起動時エラーにはならず、該当SQLが見つからない実行時失敗になる
  ため発見しづらい）。
  発生スプリント: Sprint6（#1）→ backend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **`./gradlew generateEnums`（EnumGenerator）は全`m_code` `code_type`を一括で`domain/enums/*.java`に
  再生成し、既存ファイルへの手書き追記は次回実行で消える。** 在庫ステータスの閾値算出`of(qty)`を生成対象の
  `StockStatus.java`に直接書くと再生成のたびに消失するため、非生成の別クラス`StockStatusCalculator`
  （`domain`パッケージ）に分離して解消した。
  発生スプリント: Sprint6（#1）→ backend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **`./gradlew syncTestSchema`は`flyway/sql`（versioned migration）のみをbackendのtest resourcesへ同期し、
  `flyway/sql-test`（repeatable migration・フィクスチャ）は対象外。** 今回はdatabase側のカタログseedを
  `flyway/sql`（本番相当）に追加したため問題化しなかったが、`flyway/sql-test`側だけに変更を加えた場合
  `syncTestSchema`を実行してもbackendのTestcontainersには反映されない点に注意（Sprint4での
  `syncTestSchema`確認手順の教訓の続き）。
  発生スプリント: Sprint6（#1）
- **Spring SecurityのCSRF Cookie属性（`SameSite`/`Secure`等）をテストで直接検証する場合、MockMvc経由の
  統合テストは使えない。** 理由は2つ: (1) `SecurityMockMvcRequestPostProcessors.csrf()`は呼ばれた時点で
  共有Springコンテキストの`CsrfTokenRepository`をセッションベースへ**恒久的に**差し替える（テストスイート
  全体でリークする既知の挙動）ため、同一コンテキストで実行される他のCSRFテストがCookieを発行しなくなる。
  (2) `MockHttpServletResponse`のSet-Cookieヘッダ再構築は`SameSite`属性を`MockCookie`型のオブジェクトのみ
  見るため、`CookieCsrfTokenRepository`が発行する素の`jakarta.servlet.http.Cookie`のSameSite属性はヘッダ
  文字列に反映されず、統合テストのレスポンスヘッダからは検証できない。回避策として、対象の
  `CsrfTokenRepository` Beanを`SecurityConfig`のpublicファクトリメソッド（`csrfTokenRepository(boolean
  secure, String sameSite)`）として切り出し、Springコンテキストを起動しないplain `Specification`
  （`CsrfCookieFilterSpec`と同型）でリポジトリを直接構築し、`MockHttpServletRequest`/
  `MockHttpServletResponse`に対して`saveToken`を呼んでCookieオブジェクトの属性（`getAttribute("SameSite")`・
  `getSecure()`・`isHttpOnly()`）を直接assertする。
  発生スプリント: Sprint9（#6、`SecurityConfigCsrfTokenRepositorySpec.groovy`実装時。初出のため2回ルールに
  従い本Skillには未反映）

### jpetstore-frontend
- **vue-i18n（v11・Composition API）のメッセージ文字列中の`@`はlinked message構文（`@:key`形式）として
  解釈される。** `home.tokens.desc`に含めていた`@layer`（main.cssのCSS層を指す技術用語）がメッセージ
  コンパイラに誤解釈され、Vitest実行時に`SyntaxError: Message compilation error: Invalid linked format`
  で落ちた。`\@layer`とエスケープして解消。実行時ではなくビルド/テスト実行時に初めて顕在化するため、
  `@`を含む文言をi18nメッセージに書く際は要注意（`frontend-conventions`へ即時反映済み・参照知識の
  例外のため2回ルール対象外）。
  発生スプリント: Sprint5（#24）
- **正規表現の文字クラス表現（`\s`・`\uXXXX`範囲指定等）を含むコードを編集ツールで書くと、書き込み後の
  内容が意図しない別の文字列に置き換わる現象が本セッションで複数回発生した。** 例:
  `/^[\s -]/`のような表現を書いたつもりが、実際にファイルへ書き込まれた内容は`/^[ -]/`のような
  別物になっていた（原因不明。Write/Editツール側かエディタ層の問題と推測）。1回目はcode point比較
  （`codePointAt(0) <= 32`）で回避したが、2回目（セキュリティレビュー対応で制御文字判定を拡張した際）
  にも同じ現象が再発した。正規表現の文字クラスを使わず、`for (const char of value)`で1文字ずつ
  code pointを走査するループに統一して最終的に回避した。**同種の編集をする際は、正規表現リテラルを
  含む変更を書いた直後に必ずReadツールで実際の書き込み内容を確認すること**（テストが green でも
  意図と異なるロジックがコミットされるリスクがあるため、テストケースの網羅性だけに頼らない）。
  発生スプリント: Sprint5（#24。1回目・2回目とも同一セッション内で発生）
- **`import.meta.glob(..., { eager: true })`はViteのビルド時静的解析でファイルパスパターンを解決するため、
  パターン文字列を変数化・動的生成すると対象を拾えなくなる。** カタログ画像（category5枚・product16枚）を
  1つずつimportせず`import.meta.glob('../assets/catalog/*.png', { eager: true })`で一括取り込みし、
  `resolveCatalogImage(kind, id)`で解決・未存在はplaceholderへフォールバックする実装で採用した
  （実装パターン自体はfrontend-conventions §7へ即時反映）。
  発生スプリント: Sprint6（#1）→ frontend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **共通レイアウトコンポーネント（`AppHeader.vue`等）に新規のインタラクティブ要素（`<form>`等）を
  追加すると、そのレイアウトを使う既存Viewのテストで汎用セレクタが意図しない要素にヒットする。**
  ヘッダに検索用`<form class="jps-search">`を追加したところ、`SignonView.spec.ts`の
  `wrapper.find('form').trigger('submit.prevent')`が（DOM順序上先に現れる）検索フォームにヒットし、
  signonフォームの送信テストが誤動作した（`router.push`が未定義routeへ飛びエラーになり顕在化）。
  `wrapper.find('form.signon__form')`のようにView固有のクラス名でセレクタを明示化して解消した。
  共通レイアウト（`AppHeader`/`AppLayout`等）へ新規のフォーム・ボタン等を追加する際は、そのレイアウトを
  使う既存View群のテストで`find('form')`/`find('button')`のような汎用セレクタが使われていないか
  確認すること。
  発生スプリント: Sprint7（#2、ヘッダ検索バー追加時に発覚）

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
- **パスワードの `PasswordEncoder` は Spring Security 標準の `PasswordEncoderFactories.
  createDelegatingPasswordEncoder()`（既定bcrypt）を使い、ハッシュ値には `{bcrypt}` 等のアルゴリズムID
  プレフィックスを含めて保存する。** プレフィックス無しの生bcrypt文字列（`$2a$10$...`）を
  `matches()` に渡すとアルゴリズムIDが解決できず失敗する（`DelegatingPasswordEncoder` は既定で
  `defaultPasswordEncoderForMatches` が未設定のため）。DB seed・テストフィクスチャで bcrypt ハッシュを
  直接書く場合も必ずこのプレフィックスを含めること。
  発生スプリント: Sprint3（#19）→ backend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **`DaoAuthenticationProvider` は `UserDetailsService#loadUserByUsername` が投げた
  `UsernameNotFoundException` を、既定（`hideUserNotFoundExceptions=true`）で誤パスワードと同一の
  `BadCredentialsException` に正規化する。** 未知ユーザーと誤パスワードのログイン失敗を同一の401
  （SBD-6・列挙不可）にするための Spring Security 標準機能であり、カスタム `UserDetailsService` 側で
  この既定動作を壊す実装（例外を個別にキャッチして別メッセージを返す等）をしないよう注意する。
  発生スプリント: Sprint3（#18）→ backend-conventionsへ即時反映（secure-by-defaultパターンの例外）
- **cross-repo（`jpetstore-backend`＋`jpetstore-database`）で同名の feature ブランチを切り、
  1つの Issue の実装を Issue単位のコミットとして両リポジトリに分けて積むパターンを実際に運用し、
  問題なく機能することを確認した。** #19（PasswordEncoder=backend／デモシード=database）・#18
  （login/logout=backend）のように、1 Story が DB seed とそれを消費するロジックの両方にまたがる
  場合の標準的な進め方として確立（計画段階でSMが事前に線引きを明示していたため実装時の迷いは無かった）。
  発生スプリント: Sprint3（#18/#19。初のcross-repo実装スプリント）
- **列挙耐性のあるログインロックアウトは、ロック状態を「username文字列キーの対称テーブル」で持ち、
  既存のダミーbcryptタイミング均等化（`DaoAuthenticationProvider`の未知ユーザー扱い）と組み合わせることで、
  タイミングサイドチャネルを列挙オラクル化させずに設計できる。** `t_login_attempt`のPKをFK無しの
  `username VARCHAR`にし失敗時は実在/非実在を問わず対称に行を作ることで、ロック判定（高速SELECT）が
  `authenticate()`（低速bcrypt）より前に走ってもタイミングが割れる軸は「ロック中(速い) vs 非ロック(遅い)」
  のみに閉じ、「ユーザー存在 vs 非存在」の軸とは直交する（ロック状態は攻撃者自身が誘発するもので新情報を
  与えない）。SecReviewerのレビューで構造的検証を受け、SMがコード修正不要の受容リスクと判断した
  （`backlog/sprint_04/implementation-notes.md` Finding 1）。
  発生スプリント: Sprint4（#20）
- **既存の一律401経路（`BadCredentialsException`→`GlobalExceptionHandler`）は、認証ロジックそのものを
  変更しなくても前段ゲート（ロックアウト等）から同じ例外型をthrowして再利用できる。** ロックアウトの
  `assertNotLocked`は独自の例外型・専用ハンドラを新設せず、既存の誤資格ログインと同一の
  `BadCredentialsException`をauthenticate前に短絡してthrowする設計にした。これにより一律401（SBD-6）・
  監査記録（SBD-14）の両方が新規コードなしで自動的に適用される（`GlobalExceptionHandler`・監査経路は不変
  のまま）。認証フローに前段ゲートを追加する際は、新しい失敗系統を作るより既存の失敗経路に正しく合流させる
  方がsecure-by-defaultの担保（一律応答・監査モレなし）を機械的に維持できる。
  発生スプリント: Sprint4（#20）
- **チェック→書き込みが別文（非原子）なゲートは、競合時の失敗モードが「フェイルセーフ（制限が伸びるだけ）」
  であると確認できれば、悲観ロック等で原子性を強制しなくてよいと判断できる。** `assertNotLocked`と
  `recordFailure`が別SQL文のため高並列バーストで`lock_until`が都度再計算されロック期限が後ろ倒しに
  延長され得るが、これはbypass不可（ロックが緩む方向には振れず延びる方向にのみ振れる）フェイルセーフな
  非原子性であり、DoSモデルの許容範囲内としてSMが受容した（`backlog/sprint_04/implementation-notes.md`
  Finding 2）。原子性を厳密に守るための悲観ロック導入は軽量設計を損なうため見送った。将来同種の
  スロットリング/カウンタ機構を非原子ゲートで実装する際、失敗モードの向き（fail-safe/fail-open）を
  先に評価する判断軸として使える。
  発生スプリント: Sprint4（#20）
- **本人スコープ認可の再利用可能ガード（`OwnershipAuthorizationService`）は`CurrentUserProvider`起点で
  「リソース所有者userId == 現在プリンシパルuserId」のみを判定する薄い部品とし、リソースIDから所有者を
  DBで解決する処理は各ドメインStory側に委ねる設計にした。** #21実証（`SecuredPingController#myResource`）
  では対象ドメイン未実装のためパス変数を「サーバー側解決済みの所有者」とみなす形にとどめ、過剰実装を
  回避した。今後実ドメインへ適用するStoryでは、「リソースIDから所有者を解決する」処理（ドメイン固有）と
  「解決済み所有者を`CurrentUserProvider`と突き合わせる」処理（`OwnershipAuthorizationService`・再利用）を
  分離する形で組み込む（`backend-conventions` §9へ即時反映済み。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint4（#21）
- **カタログのような読み取り専用・階層・ページングを伴う一覧系は、カスタム手書きXMLマッパー
  （`infrastructure.mybatis.custom.{entity,mapper}`）でJOIN・LIMIT/OFFSET・COUNTを1SQLにまとめ、Service層
  でのN+1を構造的に避けるパターンを確立した。** category→products一覧・product→items一覧はそれぞれ
  `item×inventory`（在庫）・`item×product`（商品名）のJOINをXML側で行い、Service層はページング済みの
  結果をそのまま変換するだけにした（ループ内クエリなし）。今後カタログに類する参照系一覧（#2検索・
  #9注文履歴等）を実装する際の型として再利用できる。
  発生スプリント: Sprint6（#1）
- **汎用ページングDTO（`domain.common.Page`/`PageRequest`（VO）→`presentation.rest.dto.PageResponse<T>`）を
  1-index（`page=1`始まり）で確立し、#2（検索）・#9（注文履歴一覧）が再利用できる先例規約とした。**
  Application層はDomainの`Page<T>`のみを扱い、Presentation層のController側で`PageResponse<T>`へ変換する
  分離を維持している（backend-conventions §9へ即時反映。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint6（#1）→ backend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **Sprint6で「#2/#9が再利用できる」と見込んで設計した資産（ページングDTO3型構成・カスタムXMLマッパー
  方式・`CatalogController`のDTOレコード）が、実際に#2（商品検索）で無改造のまま再利用でき、手戻りが
  一切発生しなかった。** `searchProducts`/`countSearchProducts`は既存の`CatalogCustomMapper.xml`に
  追記するだけで済み、新規マッパーファイル・新規Application層パターンを起こす必要が無かった。一覧系
  APIを設計する際、将来の類似機能（検索・履歴一覧等）を見込んで「先例規約」を明文化しておくと、後続
  StoryのDEV計画フェーズでの設計論点が実質ゼロになる（確認すべき論点が「再利用するか／差分は何か」に
  縮小する）。
  発生スプリント: Sprint7（#2）
- **`HttpMethod.GET`スコープでワイルドカード（例: `/api/products/**`）のpermitAllを設計しておくと、
  同じリソース配下に新設する新規サブエンドポイント（検索等）も自動的にカバーされ、`SecurityConfig`の
  変更が不要になる。** #2（`GET /api/products/search`）は新規エンドポイントだが、Sprint6で確立済みの
  `/api/products/**`（GETスコープpermitAll）にそのまま含まれたため、新規APIを追加したにもかかわらず
  `SecurityConfig`の変更ゼロで完結した。新規エンドポイントを追加する際は、まず既存のpermitAll
  ワイルドカードパターンでカバーされていないかを確認してから追加要否を判断すると、Security設定の
  肥大化・レビュー対象の増加を避けられる。
  発生スプリント: Sprint7（#2）
- **数量・カウンタ等の状態変更値を受け取るミューテーションメソッドは、既存値との加算を`Math.addExact`で
  行いオーバーフローを例外化するのが安全側の既定パターンとして再利用できる。** cart（#4）の`addItem`修正で
  採用。上限チェック（`newQuantity > stockQuantity`）だけでは、intのオーバーフローでラップした負の値が
  チェックを迂回してしまう（`current + requested`が`Integer.MAX_VALUE`を超えると負に反転し、負の値は
  常に正のstockQuantityより小さいため上限判定を素通りする）。**「非拒否（クランプのみ）」方針のメソッド
  （merge等）では、オーバーフロー時に例外化せず上限値へ直接クランプすることで既存の非拒否ポリシーを保った
  まま安全化できる**（`catch (ArithmeticException e) { clamped = stockQuantity; }`のように、例外を握り
  つぶして安全な既定値にフォールバックする）。同じ数量入力を複数メソッドで扱うドメイン（今後の注文数量・
  在庫調整等）でこの型を再利用できる。
  発生スプリント: Sprint8（#4）
- **構造的な整合性制約（DBのUNIQUE制約等）は、アプリケーションロジックでの個別バリデーションより
  堅牢にバグクラス全体を排除できる。** legacyのCart（Struts1）は`itemMap`/`itemList`という2つの独立した
  コレクションでカート内容を保持しており、削除処理の実装ミス（片方のコレクションからしか消さない）が
  「幽霊行」バグ（ID-17）を生んでいた。afterでは単一表`t_cart_item`＋`UNIQUE(cart_id, item_id)`という
  スキーマ制約自体で「同一アイテムの重複行」というバグクラスをそもそも作れない設計にした（アプリ側の
  削除ロジックが将来どう変わっても、DB制約が最後の防波堤として機能する）。二重構造（map+list等）で状態を
  保持する既存/将来のドメインを見直す際、「削除経路を正しく実装する」より「重複を構造的に作れなくする」
  設計を優先できないか検討する価値がある。
  発生スプリント: Sprint8（#4）
- **匿名（未認証）でもserver-side検証を効かせたいが機微な内部値（在庫数等）は露出したくない場合、
  「真偽値＋安定した理由コードのみ」を返す専用の判定APIを公開するパターンが有効。** cart（#4）の
  `GET /api/items/{itemId}/orderable?quantity=N`（D1）で採用。既存の`/api/items/**`（GETスコープ
  permitAll）にそのまま収まるため`SecurityConfig`変更ゼロで実現できた。qty非露出（ID-28）と匿名での
  在庫上限強制（AC-neg1）という一見両立しにくい要件を、「露出するのは判定結果（orderable/reason）のみ」
  という薄いAPI設計で両立させた。同種の「機微値に基づく判定だけを匿名にも公開したい」ケース（与信判定・
  権限チェック等）で再利用できる考え方。
  発生スプリント: Sprint8（#4）
- **リクエストボディの型不一致（非数値文字列等でのJSONデシリアライズ失敗）を400に正規化する
  `HttpMessageNotReadableException`ハンドラは、既存のcatch-all横取り問題（`backend-conventions`§9の
  該当例外テーブル）と同じ原因（専用ハンドラが無いと`handleUnexpected`に落ちて500になる）で必要になった。**
  `UpdateCartItemRequest.quantity`に文字列`"abc"`を送るケースがAC2「非数値→400」の穴になっていたため
  追加した。既存の型不一致ハンドラ群（`MethodArgumentTypeMismatchException`＝クエリ/パスパラメータ、
  `MissingServletRequestParameterException`＝必須パラメータ欠落）とは発生段階（リクエストボディの
  JSONデシリアライズ時）が異なるが、原因（catch-all横取り）と対処（専用ハンドラ追加）は同型のカテゴリ
  のため、新規パターンの2回ルール判定は経ずに`backend-conventions`§9の既存テーブル（「見つかり次第
  このリストへ追記する」と明記済み）へ直接追記した。
  発生スプリント: Sprint9（#5、AC2非数値ケースで発覚）→ backend-conventionsへ即時反映（既存の
  昇格済みテーブルへの追加行のため2回ルール対象外）
- **DTOで『値が明示的に0』と『値自体が欠落』を区別したい場合、プリミティブ`int`ではなくboxed
  `Integer`＋`@NotNull`を使う。** `UpdateCartItemRequest`は当初`int quantity`（Bean Validationの
  `@Min`のみでは欠落時にJSONデシリアライズがデフォルト値0を埋めてしまい『明示的な0=削除』と『未指定』を
  区別できない）だったが、`Integer quantity`（`@NotNull @Min(0)`）へ変更し、欠落は400・明示0は許容
  （削除セマンティクス維持）・負数は400、という3値の区別を実現した。数量に限らず『0/false/空文字と
  null(未指定)を区別する必要があるフィールド』を持つDTO全般で再利用できる型。
  発生スプリント: Sprint9（#5、計画フェーズ確定②）
- **CSRFトークン受け渡し用のXSRF-TOKEN Cookie自体（値ではなく属性）にSameSite/Secureを付与する場合、
  `CookieCsrfTokenRepository#setCookieCustomizer`で`ResponseCookie.Builder`をカスタマイズし、既存の
  JWT Cookie属性値（`jwt.cookie.secure`/`jwt.cookie.same-site`）をそのまま再利用して統一する設計が
  有効。** 新しいプロパティキーを増やさず、全Cookie（JWT access/refresh＋XSRF-TOKEN）の属性を単一の
  設定源で環境ごとに揃えられる（`SecurityConfig`に`@Value`2つを注入するだけで済み、`application.yml`
  への新規プロパティ追加が不要）。
  発生スプリント: Sprint9（#6、計画フェーズ確定①）

### jpetstore-frontend
- **backendのSpring Security 7 CSRF設定（非XOR `CsrfTokenRequestAttributeHandler`・consume-then-
  regenerate）とフロントのAPIクライアントは対で設計しないと機能しない。** backendが非XORを選んで
  いる以上、フロント側でXORマスク等の「独自の安全策のつもりの実装」を足すと即座に全POSTが403になる
  （マスクの有無はプロトコルの一致・不一致の話であり、フロント単独の判断で強化できるものではない）。
  加えて、Sprint3で判明していたCSRF Cookieのconsume-then-regenerate挙動（状態変更成功のたびに失効し
  次のGETまで再発行されない）を踏まえ、APIクライアント層に「送信直前にCookieが無ければ自己prime」の
  自己修復ロジックを持たせる設計とした。呼び出し側（store等）にprime処理を書かせない一箇所集約により、
  2回目以降の状態変更（signon成功後のsignoff等）でもCSRFヘッダの欠落を防げる。
  発生スプリント: Sprint5（#24）
- **httpOnly Cookie認証のSPAでは、「Piniaストアはメモリ保持のみ・リロードで揮発」と「Cookieはリロード
  後も自動送信される」の非対称を、backendの`/me`相当エンドポイント＋起動時fetchで埋める設計パターンが
  再利用可能。** CSRF prime（`GET /api/ping`）と`/me`取得は依存関係が無い独立処理のため`Promise.all`で
  並列化してよい（直列にすると起動が不必要に遅延する。パフォーマンスレビュー指摘で気づいた観点だが、
  今後は独立な起動時初期化を書く時点で最初から並列化を検討すべき一般則として意識する）。
  発生スプリント: Sprint5（#24）
- **オープンリダイレクト対策バリデータは、ライブの保護画面が無くても純関数として単体でAC実証できる。**
  `router.beforeEach`ガード自体・復帰先バリデータ（`sanitizeRedirectTarget`）をどちらも独立した
  純関数として実装し、Pinia storeやVue Routerの実インスタンスへの依存を最小化した状態でVitestの
  否定ケース網羅（`//evil`・`https://evil`・`/\evil`・制御文字混入等）を書けた。保護対象のドメイン画面
  が実装されていない土台スプリントでも、メカニズム自体は先に作り切り検証できる（消費側は
  `meta.requiresAuth: true`を付けるだけで接続できる設計）。
  発生スプリント: Sprint5（#24）
- **backend+frontendのcross-repo（主=frontend／従=backend）を実運用し、従リポジトリの変更を
  「1エンドポイント追加のみ」に最小化する設計判断が機能した。** 既にbackend+database間のcross-repo
  パターン（Sprint3）は確立済みだったが、今回はfrontendが主体となる初のパターン。backend側の変更を
  `GET /api/auth/me`追加のみに絞り、`SecurityConfig`は無変更で済ませたことで、cross-repoでも
  レビュー対象・コンフリクトリスクを小さく保てた。
  発生スプリント: Sprint5（#24）
- **ドメイン一覧/カード/ページネーション/在庫バッジ等のUI部品は、既に`main.css`で整備済みの`.jps-*`
  ユーティリティクラス（#24で確立）を適用するだけの薄い`.vue`ラッパとして実装できた。** 独自スタイルを
  新設せずCSSクラスを貼るだけで済んだため、カタログ画面（`ProductCard.vue`・`Pagination.vue`・
  `StockBadge.vue`等）はロジック（props/イベント）に集中して実装できた。#2（検索）・#9（注文履歴）でも
  同じ既達クラスを再利用できる見込み（frontend-conventions §7へ即時反映。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint6（#1）→ frontend-conventionsへ即時反映（参照知識の例外・2回ルール対象外）
- **Sprint6見込み通り、`ProductCard.vue`/`Pagination.vue`/`CatalogBreadcrumb.vue`/画像アセット解決
  （`resolveCatalogImage`）を#2（検索結果画面）にそのまま再利用でき、`SearchResultView.vue`の実装は
  検索固有ロジック（キーワード/カテゴリフィルタのquery同期・空ガード）だけに集中できた。** 加えて
  Sprint5（#24）で先行して用意されていた未配線CSS（`.jps-search`）も、マークアップを載せるだけで
  意図通りのヘッダレイアウト（`flex:1;max-width`と`margin-left:auto`の組み合わせで検索バーがナビ/
  アカウント欄を右寄せに保つ）になった。**将来使う想定のCSS/コンポーネントを先行スプリントで
  「未配線のまま」用意しておく設計は、実装コストをほぼゼロで後続Storyに前借りできる。**
  発生スプリント: Sprint7（#2）
- **本プロジェクト初のlocalStorage導入（`utils/cartStorage.ts`）で、`stores/auth.ts`が確立していた
  「Piniaはメモリのみ・永続化しない」方針とは別に、未ログインカート専用の限定的なlocalStorage利用パターンを
  確立した。** 要点は3つ: (1) `load/save/clear`いずれも`try/catch`で例外を握りつぶし空配列/no-opへ
  フォールバックする（破損JSON・非配列・プライベートブラウジング等の書き込み拒否のいずれでもアプリを
  落とさない）、(2) 保存前に配列要素の形（`{itemId: string, quantity: number}`）を型ガード関数で検証し、
  不正な要素だけを`filter`で除外する（配列全体を捨てない）、(3) `window.addEventListener('storage', ...)`
  で他タブでの変更を検知できるようにする（同一タブ内の変更ではブラウザ仕様上発火しないため、呼び出し側が
  自タブの変更は自前で反映する前提）。今後localStorageを使う機能（下書き保存等）が出た場合の型として
  再利用できる（frontend-conventionsへ即時反映。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint8（#4）→ frontend-conventionsへ即時反映（初のlocalStorage導入パターン・
  2回ルール例外＝Sprint5 CSRF/Sprint6 MyBatisXMLマッパー等と同じ位置づけ）

### 横断（database＋backend＋frontend）
- **区分値をm_codeに新規登録する際の3-repo横断フロー**を在庫ステータスで実地確認した:
  (1) database: `flyway/sql`のseedで新規`code_type`（`display_name_ja`/`display_name_en`付き）を登録。
  (2) database→frontend: `./gradlew generateEnums`（MultiEnumGenerator）で生成された`code.constants.ts`を
  frontendへコピー。
  (3) database→backend: `./gradlew generateEnums`（EnumGenerator）で`domain/enums/*.java`にJava enumを
  生成（**全`code_type`を一括生成するため既存enumも道連れで再生成される**点に注意＝上記「技術的な
  ハマりポイント」参照）。
  (4) frontendの生成定数の表示文言と既存i18nキー（例: `home.tokens.stockIn/stockLow/stockOut`）が重複する
  場合はreconcile（統合）する。
  今後の区分値追加（ユーザー方針「区分値は基本的にm_codeに登録する」）で同じ手順を辿れる。
  発生スプリント: Sprint6（#1）

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

### Sprint 3（#18/#19）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に以下2点を追記
  （初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映）:
  - `PasswordEncoder` は `PasswordEncoderFactories.createDelegatingPasswordEncoder()`（既定bcrypt）を使い、
    ハッシュ値に `{bcrypt}` 等のアルゴリズムIDプレフィックスを含めて保存する
  - `DaoAuthenticationProvider` の `hideUserNotFoundExceptions` 既定動作（未知ユーザーも誤PWと同一の
    `BadCredentialsException` に正規化＝SBD-6列挙不可）を壊さない
  - `HttpRequestMethodNotSupportedException→500問題` と `CSRF consume-then-regenerate挙動` の2件は
    **今回は反映せず**（前者は同一の共有 `GlobalExceptionHandler` 内で既に修正済みのため再発リスクが無く、
    後者はSpring Security自体の既存挙動でありbackend側の実装パターンとして「書き方」を変える性質のもの
    ではないため。いずれも long_term.md「技術的なハマりポイント」に留めた）
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 4（#21/#20）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に
  「本人スコープ（所有者一致）認可は `OwnershipAuthorizationService` に集約する」を新設し、
  `assertOwner(Long resourceOwnerUserId)` の使い方（呼び出し元は対象リソースIDからサーバー側で解決した
  真の所有者userIdを渡す・クライアント入力をそのまま渡さない＝IDOR防止）を追記した。
  **2回ルールの対象外（即時反映）**: 再発防止のためのチェックリスト項目ではなく、#21で新設した
  再利用可能コンポーネントを今後のドメインStory（各Story側で対象リソースへ適用）が正しく使うために
  必要な参照知識・実装パターンのため（hw-hub-backend §5の「リソース認可でクライアント入力の
  householdIdを信頼しない」と同じ位置づけ）。
- **`backend-conventions`へ反映しなかったもの**: 実装中に発見した2件の技術的ハマりポイント
  （日時比較はDB側`NOW(6)`で行う／`ON DUPLICATE KEY UPDATE`のSET句左→右評価順依存の二重計算）は
  「注意すれば防げる系」の初出（1回目）のため、2回ルールに従い今回はSkillに反映せず
  `memory/dev/long_term.md`「技術的なハマりポイント」に留めた。Sprint4のセキュリティレビュー
  非ブロッキング2件（受容リスク）も同様にチェックリスト化はせず「習得したこと」に設計判断の根拠として
  記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 5（#24・初のフロントエンド実装スプリント）

- **`frontend-conventions`**: `## 7. jpetstore-frontend 固有の注意事項（Vue 3 / vue-i18n / Spring
  Security 7 backend連携）` を新設し、以下を反映（初出だが「知らないと書けない参照知識・実装パターン」
  の2回ルール例外として即時反映。`backend-conventions` §9の運用を踏襲）:
  - CSRF cookie-to-header は非XOR・生値をそのまま送る（+ 送信直前の自己修復prime）
  - トークンはhttpOnly Cookie前提。Piniaストアは非機密な識別情報のみメモリ保持
  - 認証状態のリロード再水和（`/me`パターン）と独立初期化処理の`Promise.all`並列化
  - 401時のsilent refreshは「1回だけ・オプトアウト可能」に設計する
  - ログイン失敗は一律メッセージ（HTTPステータス・エラー内容をUIへ生で渡さない）
  - オープンリダイレクト対策バリデータは制御文字を文字列全体で走査する
  - i18n（vue-i18n v11・`domain.context.key`・メッセージ内`@`のエスケープ）
  - frontmatterの`description`と冒頭にjpetstore-frontendも対象である旨を追記（§1〜6はhw-hub由来のまま維持）
  - レビュー指摘2件（初期化の直列実行・バリデータの制御文字判定漏れ）は**今回は反映せず**（初出＝1回目
    のため2回ルールの原則どおりlong_term.md「繰り返し指摘されるパターン」に留めた。ただし対応後の
    「あるべき実装パターン」自体は上記の参照知識としてSkillへ前向きに反映した）
- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に「『現在の自分』を返す自己識別
  エンドポイント（`/me`パターン）は`permitAll`に入れない」を追記した。**2回ルールの対象外（即時反映）**:
  再発防止のためのチェックリスト項目ではなく、フロント側の認証状態再水和という具体的なユースケースに
  対応するための実装パターン（今後同種のエンドポイントを作る際に必要な参照知識）のため。
- 正規表現の文字クラス表現が編集ツールで意図せず置き換わる現象（技術的なハマりポイント参照）は、
  Skillのチェックリストではなくツール利用時の作業手順の注意点のため、Skillには反映せず
  `memory/dev/long_term.md`に留めた。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 6（#1・初のドメイン機能・3-repo cross-repo）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に以下3点を追記
  （初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映）:
  - 初のMyBatisカスタムXMLマッパー導入時は `mybatis.mapper-locations` の明示設定が必須
  - 区分値をm_code化する場合、`generateEnums`が全`code_type`を上書き生成するため、算出ロジック
    （閾値判定等）は生成enumに書かず非生成の別クラス（例: `XxxCalculator`）に分離する
  - 一覧APIの汎用ページングDTOは `Page`/`PageRequest`/`PageResponse<T>` の3型構成・1-indexに統一する
    （#2/#9が再利用する先例規約）
  - `syncTestSchema`が`flyway/sql`のみを同期し`flyway/sql-test`を対象外とする点・`m_code.code_value`の
    VARCHAR(10)制約は、いずれも「注意すれば防げる系」の初出（1回目）のため2回ルールに従い今回はSkillに
    反映せず`memory/dev/long_term.md`「技術的なハマりポイント」に留めた
- **`frontend-conventions`**: `## 7. jpetstore-frontend 固有の注意事項` に以下2点を追記
  （同じく2回ルール例外の参照知識・実装パターンとして即時反映）:
  - ドメイン一覧/カード/ページネーション/バッジは既達`.jps-*` CSSクラスの薄い`.vue`ラッパで実装する
  - ドメイン画像は `import.meta.glob(eager)` で一括取り込み＋`resolveXxxImage`によるplaceholderフォールバック
  - `m_code`生成定数と既存i18nキーの重複reconcileは「注意すれば防げる系」の初出（1回目）のため
    今回はSkillに反映せず`memory/dev/long_term.md`に留めた
- 3観点レビュー全指摘0件の要因分析（secure-by-default土台の再利用／レビュー観点の先回りAC化／設計論点の
  計画フェーズ確定）は、チェックリスト項目ではなくプロセス上の教訓のためSkillには反映せず
  `memory/dev/long_term.md`「繰り返し指摘されるパターン」の「横断」に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 7（#2/#3・E1完成・Sprint6先例の再利用検証）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に以下2点を追記:
  - **catch-allの`@ExceptionHandler(Exception.class)`はフレームワーク例外を横取りする**（新規エンドポイント
    追加時は都度棚卸し）。**2回ルールによる昇格**: Sprint3で`HttpRequestMethodNotSupportedException`の
    catch-all混入が初出（当時は1回目のためSkill未反映）。Sprint7で`MethodArgumentTypeMismatchException`・
    `MissingServletRequestParameterException`・`NoResourceFoundException`の3例外が同じ理由で500に落ちる
    穴が見つかり2回目の発生と判断、Skillへ昇格した（既知の該当例外を表で明文化）。
  - **LIKE等のSQL用サニタイズ・エスケープ処理はSQL文字列非依存の純VOに隔離する**（`ProductSearchTerms`の
    実装パターン）。初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映
    （Sprint6のMyBatisカスタムXMLマッパー導入時と同じ位置づけ）。
- **`frontend-conventions`へは反映しなかったもの**: 共通レイアウトコンポーネントへの新規フォーム追加が
  既存Viewテストの汎用セレクタと衝突する問題（`SignonView.spec.ts`）は「注意すれば防げる系」の初出
  （1回目）のため、2回ルールに従い今回はSkillに反映せず`memory/dev/long_term.md`「技術的なハマりポイント」
  に留めた。
- Sprint6先例（ページングDTO・カスタムXMLマッパー・UI部品・未配線CSS）の再利用が#2/#3で手戻りゼロ・
  レビュー指摘ほぼゼロ（perfのみ軽微1件）で完走した要因分析は、チェックリスト項目ではなくプロセス上の
  教訓のためSkillには反映せず`memory/dev/long_term.md`「繰り返し指摘されるパターン」の「横断」に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 8（#4・カート・初のwriteドメイン・3-repo cross-repo）

- **`frontend-conventions`**: `## 7. jpetstore-frontend 固有の注意事項` に「localStorageを新規導入する
  場合は『破損耐性』『タブ間同期』をセットで設計する」を追記した（初出だが「知らないと書けない参照知識・
  実装パターン」の2回ルール例外として即時反映。Sprint5 CSRF・Sprint6 MyBatisXMLマッパー/import.meta.glob
  と同じ位置づけ＝本プロジェクト初のlocalStorage導入という具体的な新規パターン導入時の実装指針）。
- **`backend-conventions`へは反映しなかったもの**: sec指摘（`addItem`の数量下限バリデーション欠落・
  SBD-2）は「同種メソッド群での検証一貫性の棚卸し漏れ」という**注意すれば防げる系**の初出（1回目）のため、
  2回ルールに従い今回はSkillに反映せず`memory/dev/long_term.md`「繰り返し指摘されるパターン」（backend）
  に留めた。次回同種（新しい数量/状態変更値を受け取るメソッド群で下限/上限/オーバーフロー検証が一部漏れる）
  の発生でSkill昇格を検討する。ただし修正で採用した`Math.addExact`によるオーバーフロー安全化の実装技法
  自体は、再利用可能な参照パターンとして`memory/dev/long_term.md`「習得したこと」（backend）に記録した
  （チェックリストではなく設計技法の記録のため、2回ルールの対象外の扱い）。
- 単一表+UNIQUE制約による構造的整合性強制（幽霊行=ID-17是正）・orderable EPによるqty非露出のまま匿名でも
  在庫上限を検証するパターン（D1）・C1チャレンジ（初のwriteドメインでの土台再利用検証、conv/perf 0件・
  sec 1件という結果分析）は、いずれも本Story固有の設計判断/プロセス上の教訓のためSkillには反映せず
  `memory/dev/long_term.md`「習得したこと」「繰り返し指摘されるパターン」の該当セクションに記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 9（#5/#6・カート価格権威・CSRF ハードニング・backend単独）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項`のcatch-all横取り例外テーブルに
  `HttpMessageNotReadableException`（400・リクエストボディの型不一致/JSON不正）を追記した。**2回ルールの
  対象外**: 新規パターンの初出ではなく、Sprint3→Sprint7で既に2回ルール昇格済みの既存テーブル
  （「見つかり次第このリストへ追記する」と明記済み）へ、同カテゴリの新規発見例外を1行追加しただけのため。
- **`backend-conventions`へは反映しなかったもの**: 以下2件はいずれも「初出（1回目）」かつ新規の
  再発防止/実装パターンのため、2回ルールに従い今回はSkillに反映せず`memory/dev/long_term.md`に
  留めた（発生スプリント欄で待機）:
  - MockMvc経由でCSRF Cookie属性（SameSite等）を検証できない制約（`SecurityMockMvcRequestPostProcessors.
    csrf()`のコンテキストリーク・`MockHttpServletResponse`のSameSite反映が`MockCookie`型限定）と、
    bean切り出し＋コンテキスト無しユニットテストによる回避策 → 「技術的なハマりポイント」に記録。
  - performance-reviewerが指摘した`CartApplicationService#merge`のN+1（Sprint8由来・本スプリントの
    スコープ外とSMが判定） → 「繰り返し指摘されるパターン」に技術的負債として記録。§4a自体は既存の
    汎用N+1防止ルールのため新規チェックリスト項目は不要（次にmergeへ着手するStoryでの一括クエリ化検討
    事項として記録のみ）。
- **`memory/dev/long_term.md`「習得したこと」に記録し、Skill反映は見送ったもの**: XSRF-TOKEN Cookie
  自体への`setCookieCustomizer`によるSameSite/Secure付与（既存`jwt.cookie.*`属性値の再利用）は、
  Story固有の設計判断・具体的な実装技法の記録という位置づけで、Sprint8の`Math.addExact`オーバーフロー
  安全化と同様にチェックリスト化はせず記録のみとした。
- 3観点レビュー指摘0件（クリーン）は、#5/#6ともCSRF基盤（#23）・価格サーバ権威（#4）という既達の上に
  積むハードニングStoryであり、Sprint4/6/7と同型の「土台再利用が効く」パターンの再確認のため、
  プロセス上の教訓としては新規性が無くチェックリスト化しなかった。
- `#skills-changelog` へ `[DEV]` で投稿済み。

## 卒業済みルール

（該当なし。棚卸し対象となるルールが直近15スプリント基準に達していない。
  jpetstore-backendはSprint2・3・4・6・7・8・9の7スプリントのみ、jpetstore-databaseはSprint1・3・6の
  3スプリントのみ、jpetstore-frontendはSprint5・6・7・8の4スプリントのみのため、いずれも対象外。
  Sprint4・Sprint5・Sprint6・Sprint7・Sprint8・Sprint9 Retroでも棚卸しを実施したが同様の理由で卒業候補なし）
