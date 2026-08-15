# DEV 長期記憶（過去スプリントの教訓）

## 繰り返し指摘されるパターン

### jpetstore-database
- [パフォーマンス] 外部キー列に明示セカンダリインデックスが無い非対称（例: `m_item.supplier_id` に
  無く `product_id` にはある）。InnoDBのFK自動生成でスキャン自体は偽陽性だが、基盤スキーマの
  一貫性・自己文書化のため明示索引を推奨。
  発生スプリント: Sprint1（#22）

### jpetstore-backend
Sprint2（#23）・Sprint3（#18/#19）・Sprint4（#21/#20）とも実装スプリントを終えたが、3観点レビュー
（規約/セキュリティ/パフォーマンス）での**指摘は今のところ0件の繰り返しも無し**（Sprint3はレビュー指摘自体が
0件、Sprint4は規約/パフォーマンスが0件・セキュリティは非ブロッキング2件）。以下の発見はいずれもDEV自身が
TDD・実機検証中に見つけたもので初出＝1回目のため、2回ルールに従い本セクションではなく「習得したこと」
「技術的なハマりポイント」に記録する。ただし一部は参照知識/実装パターンとして初出からSkillへ即時反映した
（詳細は「Skills更新履歴」）。

Sprint4のセキュリティ非ブロッキング2件（`AuthApplicationService.login`のタイミング副次チャネル／
ロックアウトのcheck-then-act非原子性）はレビュー指摘そのものではあるが、SMが実コードで検証のうえ
ユーザー承認を得て「コード修正不要の受容リスク」と判断した設計トレードオフであり、防ぐべき実装ミスの
再発パターンではないため本セクションでは追跡しない（根拠は「習得したこと」に記録。詳細は
`backlog/sprint_04/implementation-notes.md`）。

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
- **`@RestControllerAdvice` の catch-all（`@ExceptionHandler(Exception.class)`）は、専用ハンドラの無い
  フレームワーク例外を意図しないステータスに丸めてしまう。** `HttpRequestMethodNotSupportedException`
  （未マッピングHTTPメソッドへのアクセス）は本来 405 だが、専用ハンドラが無いと catch-all に落ちて 500 に
  なっていた。AC-neg2（GETでの状態変更不可＝405期待）の自動テストで顕在化。`GlobalExceptionHandler` に
  `@ExceptionHandler(HttpRequestMethodNotSupportedException.class)` を追加して 405 に正規化した。
  catch-all を持つ例外ハンドラを書く/レビューする際は、Spring MVC が個別ステータスに自動マッピングする
  はずの例外（405/415等）を横取りして握りつぶしていないか確認する必要がある。
  発生スプリント: Sprint3（#18）
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

## 卒業済みルール

（該当なし。棚卸し対象となるルールが直近15スプリント基準に達していない。
  jpetstore-backendはSprint2・3・4の3スプリントのみ、jpetstore-databaseもSprint1・3の実装2スプリントのみ、
  jpetstore-frontendはSprint5の1スプリントのみのため、いずれも対象外。Sprint4・Sprint5 Retroでも棚卸しを
  実施したが同様の理由で卒業候補なし）
