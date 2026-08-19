# DEV 長期記憶（過去スプリントの教訓）

## 繰り返し指摘されるパターン

### jpetstore-database
- [パフォーマンス] 外部キー列に明示セカンダリインデックスが無い非対称（例: `m_item.supplier_id` に
  無く `product_id` にはある）。InnoDBのFK自動生成でスキャン自体は偽陽性だが、基盤スキーマの
  一貫性・自己文書化のため明示索引を推奨。
  発生スプリント: Sprint1（#22）
- Sprint6（#1・カタログseed新規投入。本プロジェクト初のフルスタックドメイン機能・3-repo cross-repo）も
  3観点レビュー指摘0件だった。要因は下記「横断（database＋backend＋frontend）」参照。
- Sprint18（#26・依存版currency棚卸し。mysql-connector-jのCVE-2023-22102対応更新）も3観点レビュー指摘0件
  だった。
- [Sprint Review指摘・ユーザー実機観測] **NOT NULL DEFAULT付きで新規列を追加した場合でも、依存する
  dev-seedフィクスチャ（`flyway/sql-test/R__*.sql`）のINSERT列リストを明示更新すべき、という指摘を
  受けた。ただしDEVが実機で再現を試みても失敗を再現できなかった。** `V00_000_013`で
  `m_profile.color_scheme_preference`をNOT NULL DEFAULT 'system'で追加した際、既存の`R__test_user.sql`の
  m_profile INSERT（列リスト省略・DEFAULT依存）は据え置いた。ユーザーがローカルdevスタックでseed投入の
  失敗を観測したと報告されたが、DEVが`dev-jpetstore-db`コンテナに対し`flywayClean→flywayMigrate→
  seedDevData`をdocumented flow通りに2回（通常実行・完全クリーンからの再実行）実施したところ、いずれも
  BUILD SUCCESSFUL・seed投入成功で、報告された失敗を再現できなかった（他に紛らわしいMySQLコンテナも
  存在しなかった）。依頼どおり修正（列リスト＋値を明示し暗黙DEFAULT依存を排除）は適用し、修正後の実機
  再確認・Spockテストは全green。**真因が特定できていないため、次に同種の指摘・再発が起きた場合は
  本エントリを参照し2回目として2回ルール昇格を検討すること**（backend-conventionsの「新規エンドポイント等
  での実機起動確認」ルールと同種の教訓になりうるが、今回は再現できなかった1件のみのため見送った）。
  発生スプリント: Sprint19（#36、Sprint Review指摘対応・⑦b。初出のため2回ルールに従い本セクション止まり）

### jpetstore-backend
Sprint2（#23）・Sprint3（#18/#19）・Sprint4（#21/#20）・Sprint6（#1）・Sprint7（#2/#3）・Sprint9（#5/#6）・
Sprint10（#7）とも実装スプリントを終えたが、3観点レビュー（規約/セキュリティ/パフォーマンス）での
**指摘は今のところ0件の繰り返しも無し**（Sprint3はレビュー指摘自体が0件、Sprint4は規約/パフォーマンスが
0件・セキュリティは非ブロッキング2件、Sprint6は3観点とも0件、Sprint7はconvention/securityが0件・
performanceのみ非ブロッキング1件で再修正不要、Sprint9は3観点とも指摘0件でクリーン、Sprint10
（read-only住所API・既達custom mapper/entityパターンの再利用）も3観点とも指摘0件でクリーン、Sprint13
（#30・Repository層をCatalog/Account/Orderへ全展開）も3観点とも指摘0件かつSMコア精読でも指摘0件でクリーン、
Sprint14（#9/#10・注文履歴一覧/詳細。`OwnershipAuthorizationService`の初の実ドメイン適用）も3観点とも
指摘0件でクリーン、Sprint15（#11/#12/#28。既達Story群のハードニング＝回帰テスト＋明文化＋カートマージ
N+1バッチ化retrofit）も3観点とも指摘0件かつSM独立verificationでも指摘0件でクリーン、Sprint16（#13/#14・
E4ユーザー登録＋アカウント編集・version楽観ロック初実装。Sprint16 Retro時点ではPRマージ前で未確定のため
本行への反映を次回Retroへ持ち越していた）も3観点とも指摘0件かつSM verificationでも指摘0件でクリーン、
Sprint17（#15/#16/#17・E4アカウントセキュリティ完結＝PW変更再認証・CSRF・入力検証）も3観点とも指摘0件
かつSM verificationでも指摘0件でクリーン、Sprint18（#31・null type safety警告のラムダ化。既存Spockを
回帰ガードに使う純リファクタ）も3観点とも指摘0件でクリーン、Sprint19（#36/#25・共有preferences設定基盤）
も3観点・SM verificationとも指摘0件でクリーン＝**tier分離19連続クリーン**が続いていた）。
**Sprint20（#38/#39/#40/#41・L3セキュリティ回帰Find-and-Fix）でtier分離クリーン記録が19連続で途切れた**
（performance 1件＋SM verification確定所見1件、計2件。1ラウンドに束ねて対応し往復ゼロで解消。詳細は下記
「[performance] LoginAttemptServiceのtx伝播属性の兄弟クラス非対称」「[SM verification]
best-effort保護境界の呼び出し元遡り漏れ」参照。convention・securityの自動reviewerは指摘0件のまま）。
以下の発見はいずれもDEV自身のTDD・実機検証中またはレビューでの初出＝1回目のため、2回ルールに従い本セクション
ではなく「習得したこと」「技術的なハマりポイント」に記録する。ただし一部は参照知識/実装パターンとして
初出からSkillへ即時反映した（詳細は「Skills更新履歴」）。

**Sprint12（#29・初のRepository層導入PoC）は、3観点reviewer自体は全員クリア（Conv/Sec/Perfとも指摘0件）
だったが、SMがコア精読で3reviewer全員が見落としたperf純増（書込4操作の`findByUserId`二重呼び・+2クエリ/
操作）を独立発見し、同スプリントで是正した。** reviewerのクリア判定を鵜呑みにせずSMが実コードを読む
verificationプロセスが機能した事例（3reviewer自動判定＋SM精読の二重チェックの価値を実証）。詳細は下記
「Sprint12」バレットと`backlog/sprint_12/implementation-notes.md`参照。

**Sprint13（#30・Repository層をCatalog/Account/Orderへ全展開）は、Sprint12でSMが発見したperf純増パターン
（識別子解決用と最終応答用の読取を同一の集約全体読み込みメソッドで済ませる誤り）が最も再発しやすい
Story（Order・Sprint12と同型のRepository新規導入）だったにもかかわらず、DEVが`ensureCart`/`findByCartId`の
使い分けを自発的に踏襲し、3reviewer・SMコア精読とも指摘0件で完走した。** Sprint12の教訓が「一度指摘されて
是正した個別修正」で終わらず、後続の類似実装（#30 Order）へ実装者自身の判断として転移したことを示す初めての
実例（発見→是正→翌スプリントでの自発的再発防止、のサイクルが1周した）。詳細は下記「習得したこと」参照。

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

- [パフォーマンス] **Repository層導入（Service→Mapper直呼びの解消）の際、「識別子解決用の読取」と
  「最終応答用の読取」を同じ集約全体読み込みメソッドで済ませてしまい、書込操作あたりのクエリ数が
  リファクタ前より純増した。** `CartApplicationService`の書込4操作（addItem/updateItem/removeItem/merge）が、
  冒頭（cartId取得目的）と末尾（最新カート返却目的）で`CartRepository#findByUserId`（`ensureCart`+
  `selectCartItems`の合成・4テーブルJOIN込み）を2回呼んでおり、冒頭の`items`ロードが実質不要（`Cart`の
  コマンドメソッドは集約state=`items`を使わず注入された`StockAvailability`のみで動く設計だったため）
  だったにもかかわらず、+2クエリ/操作の純増になっていた（addItem例: 原実装4→リファクタ後6）。**convention/
  security/performanceの3reviewerは全員この差分を見落とし「クリーン」と判定したが、SMがコア精読で発見・
  確定した**（`backend-conventions`§9の「Application ServiceはRepository経由」パターンをCart PoC（#29）で
  初適用した際に発生。是正では`ensureCart(userId):Long`（cartIdのみ・items非ロード）と
  `findByCartId(cartId):Cart`（select-only）に分割し、baselineクエリ数（4/4/3/2+2N）へ復帰した）。
  今後Repository層を新規導入するStory（#30のCatalog/Account/Order展開）で「識別子解決」と「最終応答」を
  同じ集約全体読み込みメソッドで済ませていないか棚卸しする必要がある。
  発生スプリント: Sprint12（#29、3reviewer全員見落とし・SM精読で発見。初出のため2回ルールに従い本Skillには
  未反映。ただし具体的な回避パターン＝`ensureCart`/`findByCartId`分割自体は`backend-conventions`§9の
  Cart PoCテンプレへ即時反映済み。詳細は「Skills更新履歴」）→ **Sprint13（#30・Order展開）では再発しなかった**。
  `OrderApplicationService`が既存の`ensureCart`（cartId解決のみ）と`findByCartId`（明細読取）を初めから
  使い分けて実装し、識別子解決用と最終応答用の読み取りを同一の集約全体読み込みメソッドで済ませる誤りを
  DEV自身が事前に回避した（3reviewer・SM verificationとも指摘なしでクリーン）。Skillへ即時反映済みの回避
  パターンが後続Storyで実際に機能した実例（2回ルール対象外のまま・再昇格不要）。→ **Sprint14（#9/#10）でも
  3例目として再発しなかった**。`OrderApplicationService#getOrder`が所有者解決用の`findHeaderById`（ヘッダ）
  と最終応答用の読取を同一メソッドで済ませ（ヘッダは1回だけ読み、応答にもそのまま使い回す）、明細
  （`findLinesByOrderId`）は認可通過後にのみ呼ぶ設計をDEVが自発的に採用した（3reviewer指摘0件）。Cart（#29）
  ・Order書込（#30）に続き、集約の形が異なるread系（header+lines）でも同じ設計原則（識別子解決と最終応答を
  同じ全体読み込みで済ませない）が転移することを確認できた。

- [規約][DEV自己発見・reviewer指摘ではない] **CQRS射影read系メソッドの`@Transactional(readOnly = true)`
  付与がコードベース内で不統一。** `backend-conventions`§4の既存ルール「参照系メソッドは
  `@Transactional(readOnly = true)`」に対し、`AccountApplicationService#getMyContact`（Sprint10・#7）は
  付与済みだが、`CatalogApplicationService`の一覧系4メソッド（Sprint6・#1／Sprint7・#2）と
  `OrderApplicationService#listOrders`/`getOrder`（Sprint14・#9/#10、Catalogの前例をそのまま踏襲）は
  いずれも無指定のままで、3観点reviewerもSprint6・7・13・14を通じて一度も指摘していない。Order/Catalogの
  読取対象（注文ヘッダ・カタログseed）は書込操作でほぼ更新されないため実害は今のところ確認されていないが、
  `listOrders`（list+count）・`getOrder`（header+lines）はいずれもRepository呼び出しが複数回にまたがる
  read系であり、`@Transactional(readOnly = true)`が無いと各呼び出しが独立したMyBatis
  SqlSession/コネクションになりうる（強い一貫性が必要になった場合にスナップショットがずれるリスクの芽）。
  Skillのルール自体は既存（§4）のため新規チェックリストは不要だが、**「複数Repository呼び出しにまたがる
  read系メソッド」への適用漏れ**という具体的な発生パターンとしては初出（reviewerが一度も検出できていない
  点も含め、次にこの種のCQRS read系Serviceメソッドを実装/レビューする際は§4の既存ルールを能動的に
  再確認する）。
  発生スプリント: Sprint14（#9/#10、Retroでの自己発見。初出のため2回ルールに従い本セクション止まり。
  reviewerの見落としが4回連続（Sprint6・7・13・14）である点は、reviewerプロンプト側でこの既存ルールの
  チェック観点が弱い可能性を示唆するが、DEV側の実装ミス再発パターンではないためSkill昇格の対象外とし、
  SMへの申し送り事項として記録するにとどめる）。

- [設計判断][DEV/ユーザー訂正・reviewer指摘ではない] **セキュリティ関連の試行カウンタ/レート制限を新設する
  際、計画フェーズの初期案がin-memoryに寄りがちで、ユーザーがDB-backedへ訂正する場面が2回連続した。**
  Sprint4（#20・ログインロックアウト`t_login_attempt`）に続き、Sprint16（#13・登録レート制限）でも計画
  フェーズの当初案はin-memoryだったが、ユーザーが「in-memoryではなくDB-backed登録試行テーブル」を明示的に
  確定した（`backlog/sprint_16/sprint_backlog.md` E1。3-repo化の要因にもなった）。再起動でのカウンタ消失・
  将来のマルチインスタンス構成でのバイパスという実害がin-memory案では見過ごされやすいため、2回ルールに
  従い`backend-conventions`§9へ「セキュリティ関連の試行カウンタ/レート制限はDB-backedを第一候補とする」
  一般ルールとして昇格した（詳細は「Skills更新履歴」）。
  発生スプリント: Sprint4（#20）→ **Sprint16（#13）で2回目発生・2回ルール昇格**

- [パフォーマンス] **同型（同じ「DB-backedカウンタで枠を確保するゲート」パターン）のサービスクラスを
  新設・改修する際、`@Transactional`の伝播属性（`REQUIRES_NEW`）が兄弟クラス間で非対称になっていた。**
  `RegisterAttemptService`/`AuditWriteQuotaService`はいずれも`@Transactional(propagation =
  REQUIRES_NEW)`を付与済みだったが、同一スプリントで新設した`LoginAttemptService
  .acquireAttemptSlotOrThrow`（#41・check-then-actのTOCTOU是正で新設）だけこれを欠き、`ensureRow`/
  `acquireSlot`が個別autocommitでコミット2回発生していた（performance-reviewer指摘・SMがCONFIRMED）。
  `REQUIRES_NEW`付与で是正し、ロールバック安全性の不変条件（枠確保成功後は例外を投げない＝レート制限
  バイパス防止）をjavadocに明記した。同種のカウンタ系サービス（DB-backedレート制限）を新設・改修する際は、
  **既存の同型クラスとtx伝播属性が揃っているかを突き合わせる**必要がある（`backend-conventions`§9の
  DB-backedレート制限節へ、この教訓を踏まえた実装レシピの追記を即時反映済み。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint20（#41、performance-reviewer/SM指摘。初出のため2回ルールに従い本セクション止まり。
  ただし実装レシピの明確化自体は既存の§9昇格済みエントリへの追記のため2回ルール対象外で即時反映した）。

- [SM verification・#39 AC2未達] **best-effort化（例外を握り潰し記録処理を継続させる）を要求するACがある
  場合、TDDの否定ACテストが「主要な失敗注入経路」1つしか固定していないと、同じメソッドが依存する別の
  外部呼び出しが同じ失敗モードを別トリガで再導入してしまう。** `AuditLogRecorder.recordAuthzFailure`は
  `mapper.insert`の例外はtry/catchで保護していたが、直前に呼ぶ`auditWriteQuotaService.tryAcquire`
  （`@Transactional(REQUIRES_NEW)`・新規コネクション取得）の例外は保護境界の外にあり、未認証フラッド時の
  コネクションプール枯渇等で例外が飛ぶと4経路（`AuditingAccessDeniedHandler`/
  `AuditingAuthenticationEntryPoint`/`GlobalExceptionHandler`2箇所）へ素通りし、**#39自身が修正対象にして
  いるN2（監査抑止・403→401化）と同一の失敗モードを、トリガを変えて再現してしまう**状態だった（SMのコア
  精読で発見。TDDの否定ACテストが`mapper.insert`失敗ケースしか固定しておらず実装時には検出できなかった）。
  `isWithinQuota`ヘルパーへ切り出しfail-open（例外時は枠ありとみなし記録へ進む・ERRORログは残す）で是正。
  同種のbest-effort ACを実装・レビューする際は、**「主要な失敗注入経路」だけでなく、同じメソッドが依存する
  全ての外部呼び出しそれぞれが失敗した場合も網羅する**必要がある。
  発生スプリント: Sprint20（#39、SM verification指摘。初出のため2回ルールに従い本セクション止まり）。

- [convention・非ブロッキング] **既に`backend-conventions`§9へ昇格済みのルール（Spring AOP自己呼び出しの
  javadoc注記＝Sprint11昇格）が、新設したまさに同型のクラスへの適用漏れとして再発した。** `LoginAttemptService`
  （#41で`acquireAttemptSlotOrThrow`に統合）のjavadocにSpring AOP自己呼び出しの注記が無く、同型3クラス
  （`RegisterAttemptService`/`AuditWriteQuotaService`/是正後の`LoginAttemptService`自身）で不揃いだった
  （convention reviewerが非ブロッキング指摘として検出・是正済み）。ルール自体は既にSkillに存在するため
  新規昇格の対象ではないが、**同型クラス群を新設・改修する際は§9の既存チェックリスト項目を能動的に
  再確認する**必要がある点を実例として記録する（上記の「tx伝播属性の非対称」と根は同じ＝同型クラス間の
  横断棚卸し漏れ）。
  発生スプリント: Sprint20（#41、convention reviewer指摘。既存ルールの適用漏れのため新規昇格対象外）。

- [javadocの`{@link}`宙吊り参照] **クラス名変更・API統合でjavadocの`{@link}`参照先が実在しなくなっても
  コンパイルは通るためCIで検出されない。** 同一スプリント内で2件発生した: #38 `JwtPropertiesSpec`の
  `{@link SecretFailFastSpec}`（設計段階で実クラス名を`ApplicationBootFailFastSpec`に確定する前の仮称が
  残存）／#41 `{@link #ensureRow}`（旧`assertNotLocked`等の削除・`acquireAttemptSlotOrThrow`への統合で
  自クラスに存在しないメソッドを指す形に）。いずれもDEV自身が実装中に気づき是正した（javadocの実クラス名/
  メソッド名を実在確認して修正）。**同一スプリント内の2件は「異なるレビュー時点で2回」という2回ルールの
  昇格要件を満たさないと判断し**（Sprint5の正規表現置換ツールの罠と同型の判断＝同一セッション内の複数回は
  1回目としてカウントする）、`backend-conventions`§9への新規チェックリスト項目追加は見送った。javadoc
  lint（`-Xdoclint`のビルド時有効化）によるCI検出自体は有効な恒久対策候補だが、「注意すれば防げる系」の
  チェックリスト項目ではなくビルド設定の変更（SM/インフラ判断）にあたるため、DEV側Skillへは反映せず
  SMへ申し送り事項として提起する。
  発生スプリント: Sprint20（#38・#41、DEV自己発見。同一スプリント内2回のため2回ルール未充足と判定）。

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
- Sprint10（#7・チェックアウト・ウィザード。cross-repo backend従／frontend主）も3観点とも指摘0件・
  手戻りゼロで完走した。Sprint5の2件（上記）は依然2回目の再発が無いため、本セクションでの待機を継続する。
  要因は下記「横断（database＋backend＋frontend）」参照。
- Sprint18（#33/#34/#27・保護ルート認証ガードのレース修正/ナビ導線追加/tsconfig baseUrl削除）も3観点とも
  指摘0件でクリーン。Sprint5の2件（上記）は依然2回目の再発が無いため待機を継続する（別パターンである
  `npm run format`CRLFノイズ＝下記「技術的なハマりポイント」参照はSprint14/15/17/18の4回連続発生で
  本Retroにて`frontend-conventions`§7へ昇格済み）。

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
- **Sprint10（#7・チェックアウト・ウィザード。確定前段まで）はSprint6/7/9で確立した「secure-by-defaultな
  土台の再利用」パターンを、初の多段階UIフロー（ウィザード）でも維持できることを確認した。** backend側は
  新規エンドポイント1本（`GET /api/account/me`）のみで`SecurityConfig`無変更、既達`AccountAuthCustom*`と
  同じcustom mapper/entity方式をそのまま踏襲した。frontend側は認証復帰（`authGuard`/`redirectValidator`）・
  カート確認（`GET /api/cart`・カートストア）・ステッパーCSS（`.jps-steps`）をいずれも新規配線ゼロで
  再利用し、ウィザード固有の実装（ステップ管理・住所フォーム・下書き状態）だけに集中できた。Sprint8で
  提起した「ドメイン固有ロジック（新しい入力値の検証等）は個別に注意が必要」という教訓についても、本Story
  はミューテーションを一切含まない設計（GET専用・確定前段まで）だったため該当リスクが構造的に存在せず、
  3観点レビュー指摘0件・手戻りゼロの完走につながった。
  発生スプリント: Sprint10（#7）
- **Sprint11（#8・注文確定・在庫の原子的引当。backend主・frontend従）は、Sprint6以来の「secure-by-default
  土台再利用」パターンが本プロジェクト最難関の難度クラス（初の書込み系トランザクション×並行制御）でも
  通用することを実証し、3観点レビュー指摘0件を達成した（6回目の3観点クリーン）。** 新規に導入した機構
  （`@Transactional`のall-or-nothing・item_id昇順固定順減算・`AffectedRows`のsupplier拡張点・
  `AuditLogRecorder`の`REQUIRES_NEW`失敗監査）はいずれも既存の設計方針（Sprint4で用意された拡張点・
  Sprint2で用意されたWHO自動付与AOP）の上に積む形で実装でき、新規のセキュリティ機構を自作しなかった。
  Sprint4以来「モデルtier分離（計画=Opus・実装=Sonnet）」を11スプリント連続で運用しているが、並行制御を
  伴う書込みドメインという最も難度の高いクラスでも計画フェーズでのAskUserQuestion確定（在庫不足時の
  ステータス・監査粒度・完了画面スコープ）が実装フェーズでの手戻りを事前に防いだ。
  発生スプリント: Sprint11（#8）
- **[DEV自己発見・reviewer指摘ではない] 撤去/リファクタ対象のコードが「孤立している＝未参照に見える」だけで
  実削除すると、それがcodegen（コード生成）の生成物だった場合、削除が非永続（次回生成タスク実行で復活）かつ
  「生成物を手編集した」という規約違反になりうる。** #12（支払プレースホルダ化）で、backlog計画時点では
  backend `domain/enums/CardType.java`・frontend `constants/code.constants.ts`の`CARD_TYPE`等を「孤立enum/定数の
  撤去」としてACに含めていたが、DEVが撤去前にコードベースを確認したところ、両者ともそれぞれ`EnumGenerator`
  （backend）・`MultiEnumGenerator`（frontend）が`m_code`の`code_type=0002`から自動生成する生成物であること
  （frontend側は`constants/README.md`の「手編集禁止・再生成で上書き」宣言＋`jpetstore-database/build/generated/
  frontend/code.constants.ts`とのバイト一致で確認）が判明し、撤去方針を「両repoとも温存」へ計画修正した。
  **撤去/削除系のACに着手する際は、対象が本当に手書きコードか、それとも生成タスク（`generateEnums`等）の
  生成物かを、README・生成元コマンド・生成物ディレクトリとの比較で撤去前に必ず確認する**必要がある。
  発生スプリント: Sprint15（#12、backend/frontend両repoで同時発生。初出のため2回ルールに従い本セクション止まり）

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
- **Groovyの`GString`は`equals(String)`が常に`false`を返すため、MockMvcの`jsonPath(...).value(gstring)`は
  GString型の期待値を渡すと（実際の値と等しくても）一致しない。** Spockのテストコードで文字列展開
  （`"${variable}"`）した値をそのまま`jsonPath("$.field").value(expected)`のexpected引数に渡すと、内部的
  には文字列に見えても実体はGStringのため`equals`比較が常にfalseになりテストが落ちる。`expected.toString()`
  のように明示的にStringへ変換してから渡すことで解消する。GStringを`jsonPath().value()`やその他の
  `equals`ベースの比較APIに渡す箇所全般で同じ注意が必要。
  発生スプリント: Sprint10（#7、`AccountControllerSpec`実装時。初出のため2回ルールに従い本Skillには未反映）
- **Spockの`Stub`はインターフェースのデフォルトメソッド実装へスタブ呼び出しを委譲しない。**
  `CurrentUserProvider`の`currentUser()`（抽象）と`requireCurrentUser()`（`currentUser()`を呼ぶデフォルト
  メソッド実装）のうち、`currentUser()`のみをStubしても`requireCurrentUser()`はStubされた`currentUser()`の
  戻り値を経由せず、実際のデフォルトメソッド本体（インターフェースの生実装）がそのまま実行される。未認証系
  のテストケースで`requireCurrentUser()`が例外を投げることを期待する場合は、`requireCurrentUser()`自体を
  直接Stubする必要がある。インターフェースのデフォルトメソッドをStubで検証する際は、呼び出されるメソッド
  自体を直接指定すること（委譲元の抽象メソッドだけをStubしても効果が及ばない）。
  発生スプリント: Sprint10（#7、`AccountApplicationServiceSpec`実装時。初出のため2回ルールに従い本Skillには
  未反映）
- **Spockの`Mock()`で同一メソッド呼び出しに対し`given:`ブロックの裸stub（`mock.method(_) >> {...}`）と
  `then:`ブロックの引数一致インタラクション（`1 * mock.method({matcher})`）を両方宣言すると、`then:`側が
  優先され`given:`側の返り値/副作用クロージャは無視される。** `OrderApplicationServiceSpec`で
  `orderCustomMapper.insertOrderHeader(_)`を`given:`で「呼ばれたらorderIdを補完する」よう裸stubしつつ、
  `then:`で「正しい引数で呼ばれたこと」を別途検証しようとしたところ、`then:`側のインタラクションが
  マッチした呼び出しでは`given:`側のクロージャ（`h.orderId = ...`の副作用）が実行されず、後続コードが
  `header.getOrderId()`から`null`を受け取り`NullPointerException`になった（テスト実行で発見）。
  同一メソッド・同一引数パターンに対して返り値/副作用の設定と呼び出し内容の検証を両方行いたい場合は、
  `then:`ブロックの1つのインタラクションに引数マッチャーと`>>`（返り値/副作用クロージャ）を両方まとめて
  書く（`1 * mock.method({matcher}) >> { args -> ... }`）ことで解消する。
  発生スプリント: Sprint11（#8、`OrderApplicationServiceSpec`実装時。初出）→ **Sprint12（#29）で2回目発生**
  （perf是正で新設した`CartApplicationServiceSpec`の`ensureCart`/`findByCartId`スタブと
  `MyBatisCartRepositorySpec`の`cartCustomMapper.ensureCart`スタブの両方で同じ罠を踏み、NPE/比較失敗で
  RED化した）→ **2回ルールにより`backend-conventions`§9へ昇格**（詳細は「Skills更新履歴」）→ **Sprint13（#30）で
  3回目発生**（新設`CatalogApplicationServiceSpec`の`categoryIdが指定されていれば`テストで同じ罠を踏みNPE化）も、
  §9昇格済ルール（1つの`then:`にmatcherと`>>`をまとめる）を参照して即座に解消できた。**2回ルール昇格の効果が
  実証された初のケース**（昇格後に3回目が発生してもSkill参照だけで解決でき、long_term.mdの再調査は不要だった）。
  再昇格・チェックリスト追加は不要（既に§9に記載済のため）。
- **`VARCHAR(10)`の自然キー列（`m_item.item_id`等）へテスト用に新規IDを設計する際、業務的にわかりやすい
  長い文字列にすると桁数超過でINSERTが失敗する。** 並行安全性テスト用に`ZZ-ORDER-CONC-1`（15文字）という
  アイテムIDを新設しようとしたところ`MysqlDataTruncation`で失敗し、`ZZ-ORD-C1`（9文字）へ短縮して解消した。
  `m_code.code_value`のVARCHAR(10)制約（Sprint6・既知）と同種の「列幅を確認せずにIDを命名する」ミスだが、
  対象列（`m_item.item_id`）が異なるため本セクションでは初出として記録する。テスト専用の自然キーを新設する
  際は、命名前に対象列のDDL（`CREATE TABLE`文）で桁数を確認する習慣が必要。
  発生スプリント: Sprint11（#8、`OrderConcurrencyIntegrationSpec`実装時。初出のため2回ルールに従い本Skillには
  未反映）
- **Spring Framework 7.0で`HttpStatus.UNPROCESSABLE_ENTITY`が`UNPROCESSABLE_CONTENT`へ改名されていた
  （値422自体は不変・RFC 9110の呼称変更への追随）。** ACやbacklogには明記されていなかったが、
  `./gradlew compileJava`のコンパイルノート（非推奨警告）で発覚し、`GlobalExceptionHandler`側の参照を
  即座に是正した（JSON応答の`code`フィールド文字列自体は既存の`"UNPROCESSABLE_ENTITY"`のまま維持・
  Java enum定数名の改名とは独立）。`server.error.*`→`spring.web.error.*`（Sprint2）と同種のSpring本体側
  リネームだが対象箇所が異なるため本セクションでは初出として記録する。
  発生スプリント: Sprint17（#15、`GlobalExceptionHandler`実装時のコンパイル警告で発覚。初出のため2回ルールに
  従い本Skillには未反映）
- **bcryptは入力を72バイトまでしか使わず、それを超えるバイト列は暗黙に切り詰められる（文字数ではなく
  UTF-8バイト長で判定する必要がある）。** 新設`@StrongPassword`制約の上限バリデーションを当初「72文字
  以下」で実装しかけたが、マルチバイト文字（日本語等）を含むパスワードは72文字未満でも72バイトを超え
  うるため、`value.getBytes(StandardCharsets.UTF_8).length <= 72`のようにバイト長で判定する形に修正した
  （ASCIIのみのパスワードでは文字数=バイト数のため従来の直感と一致し見過ごしやすい。frontend側の
  `isStrongPassword`も`TextEncoder`でバイト長判定をミラーした）。既存の`backend-conventions`§9
  「PasswordEncoderは...」節（Sprint3・bcrypt関連の参照知識）へ追記した（新規チェックリスト項目ではなく
  同一トピックの既存参照知識セクションへの追記のため2回ルール対象外）。
  発生スプリント: Sprint17（#15、`StrongPasswordValidator`実装時にDEVが自己発見）
- **`@Transactional(REQUIRES_NEW)`を使う処理を20並列でIT実行すると、1リクエストあたり2本（主tx＋
  REQUIRES_NEWの別tx）のDB接続を同時に要求するため、既定のHikariCPプール上限（10）では容易に枯渇し
  `TimeoutException`になる。** `RateLimitBurstConcurrencySpec`の登録側20並列テスト（`RegisterAttemptService`
  が`REQUIRES_NEW`で枠確保）で発生。テストの並列度そのものは意図どおりだが、プール枯渇は「レート制限が
  効いている」という意図した振る舞いとは別の偽陽性/偽陰性要因になりうるため、本specにのみ
  `@DynamicPropertySource`でプール上限を50へ引き上げて解消した（本番プールサイジング自体はスコープ外）。
  今後`REQUIRES_NEW`を伴う処理の高並列ITを書く際は、並列度×tx本数がHikariCPの既定プール上限を超えないか
  事前に見積もる必要がある。
  発生スプリント: Sprint20（#41、`RateLimitBurstConcurrencySpec`実装時。初出のため2回ルールに従い本Skillには
  未反映）

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
  発生スプリント: Sprint7（#2、ヘッダ検索バー追加時に発覚）→ **Sprint19（#36）で2回目発生**（`AppHeader.vue`
  にテーマ設定ドロップダウンのtriggerボタンを追加したところ、`ItemDetailView.spec.ts`の
  `wrapper.find('button')`が新しいtriggerボタンにヒットし、Add to Cartボタンのdisabled判定・クリック
  テストが複数誤動作した。`item-detail-view__add-to-cart`のようにView固有クラスでセレクタを明示化して
  解消。**2回ルールにより`frontend-conventions`§7へ昇格した**（詳細は「Skills更新履歴」）。
- **`npm run format`（Prettier）実行時、意図せず編集していない多数のファイルがLF→CRLFへ改行コード変換
  されノイズとして`git status`に出現する。** backendの`V00_000_001`/`V00_000_002`マイグレーションファイルで
  確認済みの既知パターンと同種。`git diff --stat`（既定の`core.autocrlf=true`設定下）は改行コードのみの
  差分を自動的に正規化して除外するため、実際に意図した差分があるファイルのみを正しく特定できる。この
  結果に基づき該当ファイルのみを`git add`する選択addで、無関係な改行コード変更を誤ってコミットすることを
  回避する。
  発生スプリント: Sprint14→Sprint15→Sprint17→**Sprint18（#33/#34/#27、`npm run format`実行で52ファイルに
  再発）で4回連続発生**のため2回ルールにより`frontend-conventions`§7へ昇格した（詳細は「Skills更新履歴」）。
  恒久対策（`.gitattributes`導入）はSM側で別Issue化を検討中のため、本Skill昇格は「選択addの徹底」という
  運用面の緩和策にとどめている。

## 習得したこと

### jpetstore-database
- Groovy + Spock + Testcontainers(MySQL 8.4) による `information_schema` 表明テストで、Flyway
  マイグレーションの適用結果をTDD（RED→GREEN）で検証するパターンを確立。`SchemaMigrationSpecBase`
  （共有MySQLコンテナ・`flyway/sql`適用）を基底に、`AccountFixtureSpecBase`（`flyway/sql-test`を
  追加適用）で階層化し、フィクスチャ依存テストとスキーマのみのテストを分離した。
- `flyway_schema_history` は repeatable migration を `version IS NULL / type='SQL'` で記録する。
  この列を直接アサートすることでrepeatable migrationが意図通り適用されたことをテストで担保できる。
- **既存の単一列索引を複合索引へ置き換える場合、`ADD INDEX`と`DROP INDEX`を同一の`ALTER TABLE`文にまとめる
  ことで、重複索引が一瞬たりとも残らない置換ができる。** `t_order`の`idx_t_order_user_id (user_id)`を
  `(user_id, order_id)`複合索引へ統合する際、複合索引の左端prefixが単一列索引と同じ検索能力を持つ
  （かつFK`fk_t_order_user_id`のバッキングも左端prefixで引き続き成立する）ことを確認したうえで、
  `ALTER TABLE t_order ADD INDEX idx_t_order_user_id_order_id (user_id, order_id), DROP INDEX
  idx_t_order_user_id;`のように1文でADD+DROPを行った。2文に分けてDROP→ADDの順で実行すると
  一時的に索引が存在しない期間が生じ、ADD→DROPの順でも一時的に重複索引が残る期間が生じるが、
  同一ALTER文にまとめることでどちらのリスクも避けられる。索引テストは複合索引の存在と単一列索引の
  消滅の両方をアサートして置換の完全性を担保した（`information_schema.STATISTICS`）。
  発生スプリント: Sprint14（#9、`V00_000_011__add_t_order_user_order_index.sql`）
- **依存の版currency（EOL/重大CVE）棚卸しは、モデルの学習知識に頼らず`curl`でMaven Central metadata
  （`repo1.maven.org/.../maven-metadata.xml`で`<latest>`/`<versions>`を確認）と
  [OSV.dev](https://osv.dev) API（`POST https://api.osv.dev/v1/query`に`{"package":{"name","ecosystem":
  "Maven"},"version"}`を渡す）を直接クエリすることで、当日時点の実データに基づいて確定できる。**
  `mysql-connector-j:8.0.33`についてOSV.devが実在の重大CVE（CVE-2023-22102・HIGH・GHSA-m6vm-37g8-gqvh）を
  返したことで「学習知識では『やや古い』としか言えない依存」が「fixed-in版が明確な確定的な更新トリガ」に
  変わった。現行最新版がMaven Central上に本当に存在するかは`curl -o /dev/null -w "%{http_code}"`でPOM URLを
  直接叩いて200を確認してから採用する（バージョン番号の記憶違いによる存在しないバージョン指定を防ぐ）。
  この技法は`jpetstore-database`に限らずGradle/Mavenエコシステムの依存を持つ`jpetstore-backend`でも
  そのまま使える汎用技法だが、E6棚卸し系Issue自体の発生頻度が低い（database実装スプリントは本Story含め
  6スプリントのみ）ため、今回はSkillへの新規反映は見送りlong_term.mdでの技法記録にとどめた。
  発生スプリント: Sprint18（#26、初出。ネットワークアクセス可能な実行環境が前提）

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
- **同一ドメインリソースに対し、先にread-only（GET専用）の参照APIをcustom mapper/entity/serviceで実装し、
  update系は後続Storyへ段階的に追加する設計が機能した。** チェックアウトのプリフィル用`GET /api/account/me`
  （`AccountContactCustomEntity`/`AccountContactCustomMapper`/`AccountApplicationService`/`AccountController`）
  は、Sprint2（#23）で確立した`AccountAuthCustom*`と同じ配置・命名規約（`infrastructure.mybatis.custom.
  {entity,mapper}`・単一SELECTはアノテーション方式）をそのまま踏襲し、mapper/service/controllerをSELECT
  のみに厳格限定した（POSTは405）。E4（住所編集）で同じcustom entity上にUPDATEを追加する計画とし、本Story
  では意図的にスコープを絞った。既存の配置規約（`backend-conventions`§9）を変更せずに再利用できたため
  新規のSkill反映は不要だった。
  発生スプリント: Sprint10（#7）
- **Sprint4で先回りして用意した拡張点（`AffectedRows.requireUpdated(rows, supplier)`の
  `Supplier<RuntimeException>`オーバーロード）が、設計から3スプリント後に実際の2つ目の利用者（在庫ガード
  付き減算）で無改造のまま機能することを確認した。** 当初は`version`楽観ロック（`OptimisticLockConflictException`
  固定）1パターンのみの実績だったが、`InsufficientStockException`という全く異なる例外型を
  `() -> new InsufficientStockException(itemId)`として渡すだけで対応でき、`AffectedRows`側の変更は一切
  不要だった。「affected rows==0を判定する」という共通の関心事を、失敗時の意味づけ（楽観ロック競合 or
  在庫不足）から分離する設計が有効に機能した実例。今後同種の「ガード付きUPDATEでTOCTOUを避ける」ドメイン
  （予約枠・ポイント残高等）でもこのヘルパーをそのまま再利用できる見込み。
  発生スプリント: Sprint11（#8）
- **`ExecutorService`+`CountDownLatch`で2スレッドを完全同期させてからMockMvc経由で同時リクエストを送る
  並行安全性テストのパターンを確立した。** `readyLatch`（両スレッドがリクエスト直前まで到達したことを
  確認）→`startLatch`（両スレッドを同時解放）の2段ラッチにより、「たまたま順番に実行されて両方成功する」
  という偽陰性を排除できる。MockMvcは非同期ディスパッチを使わない限り、呼び出しスレッド自身の中で
  フィルタチェーン全体（JWT認証含む）を同期実行するため、各ワーカースレッドの`SecurityContextHolder`
  （デフォルトはThreadLocalスコープ）にそのスレッド専用の認証情報が正しくセットされる。今後の並行制御
  AC（在庫以外の排他制御ドメイン）でもこのテスト型をそのまま再利用できる。
  発生スプリント: Sprint11（#8、`OrderConcurrencyIntegrationSpec`）
- **既存カタログseed（`EST-*`）に依存するテストが多数ある状態で、初めて対象テーブル（`t_inventory`）を
  実際に書き換えるテストを追加する際は、専用のテストデータ（本Storyでは`ZZ-ORDER-*`/`ZZ-ORD-C1`/
  `ZZ-INV-1`）を都度INSERT/DELETEして隔離するのが安全である。** `IntegrationTestBase`は
  Testcontainers・Spring契約を全spec間で共有し、Flywayは通常スイート全体で1回しか実行されないため、
  あるspecが共有seedの状態を永続的に変更すると、実行順序に依存する形で他specが偽の失敗を起こしうる。
  カート機能（#4〜#6）は在庫を一切更新しなかったためこれまで問題化しなかったが、注文確定（#8）が
  本プロジェクトで初めて`t_inventory`を書き換えるドメインだったため、この隔離方針を新たに導入した。
  今後も「既に共有seedへ依存する既存specがある状態で、初めてそのテーブルを書き換えるテストを足す」
  局面では同じ隔離方針を踏襲する。
  発生スプリント: Sprint11（#8）
- **失敗監査を呼び出し元txのロールバックから独立させる`@Transactional(propagation=REQUIRES_NEW)`パターンは
  `backend-conventions`§9へ即時反映した**（Spring AOPの自己呼び出し限定という古典的な落とし穴を含む
  「知らないと書けない参照知識」のため2回ルールの対象外。詳細はSkill本文参照）。
  発生スプリント: Sprint11（#8）
- **コードベース初のRepository層導入（Cart PoC・#29）で、#30（Catalog/Account/Order全体展開）が踏襲できる
  3つの実装パターンを確立した。** いずれも`backend-conventions`§9へ即時反映済み（詳細は「Skills更新履歴」）:
  1. **record→class＋private ctor＋`reconstruct()`**: 集約（`Cart`/`CartItem`）はrecordのままだと不変条件
     コマンドメソッドを持てない・外向き射影を型で強制できないため、classへ変換しprivateコンストラクタ＋
     用途別static工場メソッド（読取再構築用`reconstruct()`／書込専用`forWrite()`）に分離した。
  2. **軽量identityハンドル（`Cart.identity(cartId)`）**: 集約のコマンドメソッド（`addItem`等）が
     集約state（`items`）を使わず注入されたVOのみで動く設計（D3）の場合、`items`を空のまま持つ軽量な
     `Cart`インスタンスを生成するだけでコマンドメソッドを呼べる。これにより「識別子解決」のためだけに
     集約全体（明細JOIN込み）を読み込む必要が無くなる（perf是正の核）。
  3. **Repositoryモック合成によるDB非依存クエリ数証明**: 実DBのクエリカウント計測インフラが無い場合でも、
     「Repository各メソッド＝1 SQL文」（`MyBatisCartRepositorySpec`・Mapper mock）×「Serviceが各
     Repositoryメソッドを正確に1回だけ呼ぶ」（`CartApplicationServiceSpec`・Repository mock・`N *
     mock.method(...)`の明示カウント検証）の2つのSpock UTを組み合わせることで、書込1操作あたりの
     SQL発行数をDB接続なしかつ決定的に裏取りできる。
  発生スプリント: Sprint12（#29、3reviewer全員クリア後にSMが発見したperf差分の是正で確立。§9のCart PoC
  テンプレへ即時反映済み＝参照知識・実装パターンの位置づけのため2回ルール対象外）
- **Sprint13（#30・Catalog/Account/Order全体展開）で、#29 Cart PoCテンプレが無改造で3 bounded context横断に
  再利用できることを実証した。** Catalog/Account（読取専用）はテンプレの「CQRS射影は record 返し・reconstruct
  不要」の面をそのまま適用（rich集約化は不要と判断・型1のパターンは適用対象外と明確に線引きできた）。Order
  （書込集約）は当初#29と同じ「record→class＋reconstruct」を踏襲する想定だったが、DEVが計画フェーズで
  「#8の並行制御（トランザクション境界・item_id固定順・ガード減算・監査）はpersistence/txの関心でありCartの
  ような item 単位の不変条件が薄い」と分析し、rich な `Order` 集約を作らず薄い書込record（`NewOrder`/
  `OrderLine`）＋Application層へのorchestration残置（O1=案A）という**意図的にテンプレの型1から逸脱する設計**を
  ユーザー承認のうえ採用した。型3（Repositoryモック合成によるDB非依存クエリ数証明UT）は3 context 全てで
  無改造適用できた。**テンプレは「機械的に3パターンを踏襲する」のではなく「集約の不変条件の濃さに応じて
  型1(rich集約)と型1'(薄いorchestration残置)を使い分ける判断軸」として機能した**ことが#30で実証された
  （§9の「#29 PoCで確立した実装パターン」は型1の前提が薄いwrite systemには過剰適用しないよう、今後同種の
  Story計画時に「集約の不変条件はどれだけ濃いか」を最初に問う観点として活かせる）。加えて、Sprint12のperf
  教訓（識別子解決用の読取と最終応答用の読取を同じ集約全体読み込みメソッドで済ませない）をDEVが`ensureCart`/
  `findByCartId`の使い分けとして自発的に適用し、Sprint12のような3reviewer見落とし・SM精読での事後発見なしに
  一発でクリーンな実装ができた（3reviewer・SM verificationとも指摘0件）。
  発生スプリント: Sprint13（#30。§9記載のテンプレ自体は変更不要と判断＝Skill未更新。テンプレの適用範囲の
  判断軸としてlong_term.mdに記録するにとどめた）
- **Sprint14（#9/#10・注文履歴一覧/詳細）は、Sprint4（#21）で用意し「各ドメインへの適用は各Storyへ委譲」と
  申し送っていた`OwnershipAuthorizationService`を、コードベース初めて実ドメイン（Order）へ適用した。**
  `getOrder`は「orderIdからサーバー側で`findHeaderById`により真の所有者userIdを解決→`assertOwner`で
  照合」という§9記載の設計どおりに実装でき、認可土台側の設計変更は一切不要だった（3.5スプリント越しで
  土台の設計が実ドメインでもそのまま機能した実証）。加えて、`OwnershipAuthorizationService`単体では
  「所有者不一致」しか判定しないため、**「不存在」も同じ`AccessDeniedException`（403）に正規化して
  列挙オラクルを封じる判断（SBD-8）はService側の責務として実装した**（`OwnershipAuthorizationService`
  自体は変更していない＝薄い部品のまま）。この設計判断は`backend-conventions`§9へ即時反映した
  （詳細は「Skills更新履歴」）。
- **カタログ（Sprint6・#1）で確立した「一覧はカスタムXMLマッパーでJOIN・LIMIT/OFFSET・COUNTを1SQLに
  まとめる」「明細JOINは`CatalogCustomMapper.selectItemById`型（`m_item ⋈ m_product`でproduct_name補完）」
  の2先例が、Order（#9/#10）へ無改造の設計判断で転用できた。** 一覧（`selectOrdersByUserId`）は
  `WHERE user_id=? ORDER BY order_id DESC LIMIT/OFFSET`、明細（`selectOrderLinesByOrderId`）は
  `t_order_line ⋈ m_item ⋈ m_product`の2段JOINで、Sprint6時点で「#2/#9が再利用する先例」と明記していた
  設計が3スプリント越しで実際に機能した（Sprint7の#2に続く2例目の再利用実証）。
  発生スプリント: Sprint14（#9/#10）
- **型自体が撤去/非依存のフレームワーク機能（Spring 6+で撤去済みのremoting系エクスポータ等）の構造的不在は、
  `Class.forName(fqcn)`→`ClassNotFoundException`のclasspath不在UTで固定する技法を確立した。** Springコンテキスト
  へのBean不在assertは型参照自体ができないため使えない場面（型がそもそもクラスパスに存在しない）での代替技法。
  Sprint4のSBD-9（オープンリダイレクトsink不在の回帰固定）と同じ「不在の実証」哲学を、「削除対象コードが元々
  存在しない既達判定Story」に適用する具体的な実装パターンとして`backend-conventions`§9へ即時反映した（詳細は
  「Skills更新履歴」）。
  発生スプリント: Sprint15（#11、`RemotingSurfaceAbsenceSpec`。初出だが参照知識のため2回ルール対象外で即時反映）
- **refactorの「挙動不変」ACは、バックログが仮定するデータ構造をそのまま信じず、実装着手前に実コードで裏取り
  する習慣が手戻りを防いだ。加えて、逐次処理をバッチ化する際の挙動パリティは、対象の集約関数が単調
  （monotonic）であることを示せれば数学的に証明できる。** #28（カートマージN+1バッチ化）で、バックログは
  「localStorageはitemIdキーのmap（dedup済み）」と仮定していたが、DEVが計画フェーズで実コード
  （`utils/cartStorage.ts`/`stores/cart.ts`）を読み直し、実体は`StoredCartLine[]`**配列**でdedupはcartストアの
  書込ロジック（find→更新 or push）が担保し、`loadCart()`自体はdedupしないことを発見した（バックログ前提の
  誤りを実装前に訂正）。この訂正を踏まえ、`CartApplicationService#merge`を「①quantity≤0をfail-fastで検証
  →②clientLinesをitemId単位でcoalesce（`Math.addExact`＋オーバーフロー時`Integer.MAX_VALUE`飽和）→③findStocks
  1回のバッチ取得→④ループ適用」へ再設計した。**coalesce-then-clampが逐次accumulate-then-clampと厳密パリティを
  持つ数学的根拠**: 在庫クランプは`min(合算値, 在庫数)`という単調非減少関数のため、一度クランプが発動すると
  以降どれだけ加算しても結果は在庫数に張り付き、クランプ未発動なら単純合計が一致する（オーバーフロー分岐も
  同様に収束することを個別ケース分析で確認）。この「単調関数でクランプする処理は、逐次適用でも一括適用でも
  結果が変わらない」という一般原則は、今後同種のN+1解消retrofit（ループ内の逐次クランプ処理を1回のバッチ処理へ
  まとめる場面全般）で再利用できる証明の型として記録する。
  発生スプリント: Sprint15（#28。初出のため2回ルールに従い本セクション止まり。coalesce技法自体は
  `CartApplicationService.merge`のJavadocにも根拠を明記済み）
- **Sprint4（#20/#21）で用意したversion楽観ロックUPDATE足場（`AffectedRows.requireUpdated`→
  `OptimisticLockConflictException`→409）が、Sprint12/13/14（Repository層展開・
  `OwnershipAuthorizationService`実適用）を経てもUPDATE自体の実利用例ゼロのまま3スプリント放置されて
  いたが、Sprint16（#14・アカウント編集）で初めて実UPDATEに使われ、無改造のまま機能した。** 確立した
  実装パターン（GET/PUTでのversion往復・単一集約ルートversionトークンでの複数テーブル横断ガード・
  依存UPDATEのaffected>0条件付き発行・UPDATE成功後の再SELECT省略）は`backend-conventions`§9へ即時
  反映した（詳細は「Skills更新履歴」）。並行安全性（AC-neg3・同一readVersionへの2並行PUT）はSprint11
  （#8）の2段ラッチテスト手法（`CountDownLatch`×2）をそのまま応用し、初回実装で一発green化できた
  （C1チャレンジ実証成功。Sprint11確立から5スプリント越しでの初再利用）。「足場を先回りして用意し、
  実際のドメインでの検証は後続Storyに委ねる」設計（`OwnershipAuthorizationService`のSprint4→Sprint14と
  同型のパターン）が、version楽観ロックでも同様に機能したことを確認できた。
  発生スプリント: Sprint16（#14）
- **共有のパスワード強度制約は、Bean Validationのカスタムアノテーション（`@StrongPassword`＋
  `ConstraintValidator`）として1本化し、新規登録（`RegisterRequest.password`）とパスワード変更
  （`PasswordChangeRequest.newPassword`）の両方のDTOへ同一の制約を付与するだけで済む設計にした。**
  文字種（英大/英小/数字/記号）の判定・長さ上限（bcrypt 72バイト制約・上記「技術的なハマりポイント」参照）
  といったロジックを`ConstraintValidator`側に1箇所集約したことで、2つのDTOへ`@StrongPassword`を付けるだけで
  済み、DTOごとに同じ検証ロジックを重複実装せずに済んだ。今後パスワードを新規に受け取るDTO（パスワード
  リセット等）が追加された場合も、同じ制約を付与するだけで一貫した強度検証を適用できる。
  発生スプリント: Sprint17（#15/#17）
- **認証隣接の失敗系統を、既存の401/403のセマンティクスと衝突しない専用ステータス（422）へ意図的に分離
  する設計判断を、ユーザー確認のうえ計画フェーズで確定した。** パスワード変更APIの「現在パスワード誤り」を
  素朴に401や403で返すと、httpClientの401→silent refresh+retry経路（`httpClient.ts:77`）が誤発火したり、
  403がCSRF欠落の意味と衝突したりする（既存語彙との衝突）。422（Unprocessable Entity。現状のAPI語彙で
  未使用）を新設`InvalidCurrentPasswordException`用に割り当て、既存の400（弱PW/不正入力＝Bean Validation）・
  401（真の未認証）・403（CSRF欠落）と完全に分離した三系統＋αのステータス設計にした。新しいドメインエラーの
  HTTPステータスを設計する際は、意味的に近い既存ステータス（401/403等）がフロント側の横断的な処理
  （silent refresh等）にフックされていないかを先に確認し、衝突する場合は未使用の専用ステータスを割り当てる、
  という判断軸として再利用できる（`backend-conventions`§9へ即時反映。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint17（#15、計画フェーズのユーザー確認事項Q1で確定）
- **アカウントの機微な変更（パスワード変更）後のトークンローテートを、新規実装せず既存の
  `AuthApplicationService.issueTokensFor(currentUser, response)`（`RegistrationApplicationService`が登録直後の
  トークン発行に使っていたメソッド）へそのまま委譲する設計にした。** `AccountApplicationService`に
  `AuthApplicationService`を注入するだけで済み（`RegistrationApplicationService`が既に同じ構成を取っていた
  ため循環依存の懸念がないことも計画時点で確認済み）、新しいトークン発行経路を増やさずに済んだ。アカウントの
  機微操作（メールアドレス変更・二要素認証設定変更等）後にセッション/トークンのローテートが必要になる将来の
  Storyでも、専用の発行ロジックを新設せずこのメソッドへ委譲できないかまず検討する価値がある。既存メソッドの
  新規コンテキストでの再利用でありパターン自体は既存のため`backend-conventions`は変更していない。
  発生スプリント: Sprint17（#15、計画フェーズのユーザー確認事項Q3で確定）
- **Eclipse JDT（VS Code redhat.java拡張）の"Null type safety"警告は、JDK標準関数型インターフェース
  （`Function`/`BiFunction`等）へのメソッド参照（`Type::method`）に対してfalse-positive寄りに出やすく、
  同じ処理をラムダ式（`(a, b) -> a.method(b)`）へ書き換えるだけで警告が解消できる（挙動・パフォーマンスとも
  実質差なし）。** `Gradle`自体はこの種のnull解析ツールを導入していないためビルドは通り続け、CI/ビルドを
  止めない**IDE専用の診断**である点に注意（`./gradlew compileJava`が greenでもIDE上は警告が出続ける）。
  対処の選択肢（ラムダ化／局所`@SuppressWarnings("null")`／nullnessアノテーション付与／診断severity調整）の
  うち、既存の関数シグネチャ・呼び出し側を一切変えずに済む「ラムダ化」が最も低リスクな第一候補になる。
  IDE警告の消失自体はCLIから検証できないため、AC化する際は「挙動不変（既存テストGREEN）」を必須ゲートに
  据え、警告消失の最終確認はレビュー/ユーザーのIDE目視に委ねる設計にした。今後同種の"Null type safety"
  警告に遭遇した場合の第一選択肢として記録する（発生頻度が読めないため今回はSkill未反映）。
  発生スプリント: Sprint18（#31）
- **stateless JWTの制約下でlogin()実行中に自分自身のDBデータを読みたい場合、`CurrentUserProvider`依存の
  read methodとは別に`Long userId`を明示的に受け取るオーバーロードを用意し、login()が返した
  `AuthenticatedUser.userId()`をそのまま渡す設計が機能した。** `AccountApplicationService.getPreferences
  (Long userId)`を新設し、`/api/auth/login`（login()実行中はJWTフィルタ未通過のためSecurityContext未
  populated＝`currentUserProvider`不可）は返却userIdを、`/api/auth/me`（既存の認証済みリクエスト）は
  `currentUserProvider.requireCurrentUser().userId()`を、それぞれ渡す形で両エンドポイントを同一メソッドで
  まかなえた。**加えて、`/api/auth/login`と`/api/auth/me`が共有する応答DTO（`AuthController.LoginResponse`
  record）を1箇所拡張するだけで両エンドポイントに新フィールド（テーマ/言語設定）が反映される**ことも
  確認できた（呼び出し側ごとに個別DTOを作る必要がない）。今後「ログイン直後に本人データを読んで応答へ
  含めたい」Story全般で再利用できる設計（`backend-conventions`§9へ即時反映。詳細は「Skills更新履歴」）。
  発生スプリント: Sprint19（#36/#25。初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外
  として即時反映）
- **既存のcheck-then-act（非原子）ゲートを、条件付きUPDATEで原子化する汎用イディオムを確立した。**
  「(1) no-op `ON DUPLICATE KEY UPDATE`で行の存在を保証する（`ensureRow`）→ (2) 既存のcheck判定式を
  そのまま`WHERE`句へ移植した条件付き`UPDATE`を発行し、`affected rows`で可否を判定する（`acquireSlot`）」
  の2文構成にすると、`affected rows==0`の意味が「(1)で行の存在は保証済みのため、条件不一致（枠切れ/
  ロック中）以外にはなり得ない」という一意な意味に構造的に閉じる（「初回はINSERTが無いため0行」といった
  曖昧さが生じない）。**加えて、既存のSET句/WHERE句を移植する際は一字も変えないことが重要**（MySQLの
  `ON DUPLICATE KEY UPDATE`のSET句は左→右評価という既知挙動（Sprint4の教訓）に暗黙依存しており、
  独立に書き直すと評価順ズレの再発リスクがある）。#41（ログイン/登録レート制限のTOCTOU是正）で確立し、
  #39（未認証監査writeのquota）でも同じ2文構成を無改造で再利用できた（`AuditWriteQuotaService`も
  `ensureRow`→条件付きUPDATEの同型）。今後同種の「既存の非原子ゲートを原子化する」Story全般で再利用できる
  設計イディオムとして`backend-conventions`§9（DB-backedレート制限節）へ即時反映した（詳細は
  「Skills更新履歴」）。
- **セキュリティ統制そのもの（fail-closed）と、その統制を支える可用性のための緩和策（fail-open）を
  区別する判断軸を確立した。** #39（未認証監査writeのquota）で、quota自体は「無制限write成長を防ぐ
  可用性のための緩和策」であり、quotaチェック（`tryAcquire`）が例外を投げた場合にfail-closed（例外伝播＝
  監査記録が止まる）にすると、**quota障害という新しい経路でSBD-14の監査記録という統制そのものを止めて
  しまう**（守るべき主目的の統制が緩和策のバグで倒れる本末転倒）。fail-open（例外時は「枠あり」とみなし
  記録処理へ進む・ERRORログは残す）を採用し、判断根拠をjavadocに明記した。新しい緩和策/補助機構を設計する
  際は、それが「守っている主目的の統制」より弱い可用性で失敗するとどちらに倒すべきか（統制自体はfail-closed、
  統制を支える補助機構はfail-open）を最初に切り分ける判断軸として今後も使える。`backend-conventions`§9へ
  即時反映した（詳細は「Skills更新履歴」）。
- **ApplicationContext起動失敗の固定は、実ブート経路のSpec（`ApplicationBootFailFastSpec`）に足すのではなく、
  `ApplicationContextRunner`で分離したSpecに書く方がFlyway/DataSource初期化順のflakinessを避けられる。**
  `ApplicationContextRunner`は`withUserConfiguration(...)`＋`withPropertyValues(...)`だけでBean生成時
  例外ではなく**コンテキスト起動失敗そのもの**を高速・DB不要でassertできるが、`Duration`型`@Value`のような
  型変換を伴うプロパティを使う場合は`conversionService`（`ApplicationConversionService`）を明示登録しない
  と変換失敗により別理由の起動失敗で偽陽性GREENになる罠がある（#38・`JwtSecretContextFailFastSpec`実装時に
  発覚し明示登録で解消）。実ブート経路での確認自体は別途DoD（実機1回）で担保し、否定ACの主固定は
  `ApplicationContextRunner`側に寄せる設計を`backend-conventions`§9へ即時反映した（詳細は
  「Skills更新履歴」）。
- **interfaceのみのMyBatis Mapper（実装クラスがフレームワーク生成のプロキシ）へ「1回だけ例外を注入する」
  e2e回帰テストは、`@MockitoSpyBean`＋`doThrow(...).when(...)`で実現できる。** `doCallRealMethod()`は
  具象クラスが必要なためinterfaceのみのMapperには使えないが、spyの既定delegate（実Beanへの委譲）に
  任せれば`doThrow`で指定した1呼び出しだけ例外化しつつ他の呼び出しは実処理のまま通せる。テスト間の波及を
  防ぐため`cleanup:`で`Mockito.reset()`を必ず呼ぶ。`OrderFailureAuditL3RegressionSpec`（#40 N3 e2e）・
  `AuditSuppressionL3RegressionSpec`（#39 AC-neg2 e2e）の両方で採用した。今後「実装層に1回だけ障害を注入して
  e2eの否定ACを固定したい」Story全般で再利用できる技法として記録する（発生頻度が読めないため今回はSkill
  未反映）。
  発生スプリント: Sprint20（#38/#39/#40/#41。原子化イディオム・fail-open/fail-closed判断軸・
  ApplicationContextRunner分離はいずれも「知らないと書けない参照知識・実装パターン」の2回ルール例外として
  即時反映。`@MockitoSpyBean`単発例外注入技法は発生頻度未知のため今回はlong_term.md止まり）

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
- **複数ステップにまたがる入力フロー（チェックアウト等）は、ステップごとに個別ルートを切らず単一ルート＋
  内部ステップ管理として実装するパターンを確立した。** `/checkout`（`meta.requiresAuth: true`）配下で
  `CheckoutView.vue`がステップコンポーネント（カート確認/住所/確定）を切り替える構成にしたことで、Sprint5
  で確立済みの`authGuard`/`redirectValidator`（未認証時の元URL退避→サインオン→復帰）が新規配線ゼロで
  そのまま機能した（per-stepルートにしていた場合は各ルートに`meta.requiresAuth`を付与する必要があった）。
  下書き状態（住所等）はsessionStorage/DB永続化を持たない揮発Piniaストアとし、`reset()`は明示的なアクション
  呼び出し時のみ実行してSPA内の通常遷移では自動リセットしない設計にした。既達の`.jps-steps`/`.jps-step*`
  （ステッパーCSS）・`.jps-field`系フォームkitを再利用し新規スタイルを増やさなかった。今後の多段階フロー
  （例: #8の注文確定ウィザード拡張）で再利用できる型として`frontend-conventions`§7へ反映した（詳細は
  「Skills更新履歴」）。
  発生スプリント: Sprint10（#7）
- **View/Componentはテスト不要という方針下でも、Viewが依存する否定AC判定ロジックはPiniaストアのtestable
  なgetterに切り出せばVitestで固定できる。** AC-neg1（空カート進入不可）の判定を`CheckoutView`内に直接
  書かず、`stores/cart.ts`に`isEmpty`getterを追加してテストし、Viewは`onMounted`でその結果を参照して
  `router.replace('/cart?reason=empty-checkout')`するだけにした。View自体はVitest対象外のままでも、AC
  の正しさはストア側のテストで担保できる。`frontend-conventions`§7へ反映した（詳細は「Skills更新履歴」）。
  発生スプリント: Sprint10（#7）
- **Sprint5で確立した「一律メッセージ（HTTPステータス・エラー内容をUIへ生で渡さない）」を、ログイン以外の
  ドメイン（注文詳細の所有者限定取得）へ初めて転用した。** `stores/order.ts#fetchDetail`は403（非所有）と
  不存在相当のいずれも`HttpError`の種別を分岐させず、単一の`detailUnavailable`フラグに握りつぶす実装にした
  （backendのAC-neg2＝不存在/非所有を区別不能にする要求と対で機能する）。既存ルールの新規ドメインへの
  転用であり新しいSkillパターンではないため`frontend-conventions`は変更していない。
  発生スプリント: Sprint14（#10）
- **Sprint10で確立した「View非テスト方針下の否定AC判定はPiniaストアのtestableなgetterへ切り出す」パターンを、
  #14（アカウント編集の409競合UX）で再利用しつつ、Sprint14の`order.ts`（403/不存在を単一フラグへ握りつぶす）
  とは意図的に異なる設計（`hasConflict`/`hasSaveError`を別フラグに分離し`shouldPromptReload`ゲッターで
  「再読込を促す」新UXを表現）を採用した。** 既存ルールの機械的な再適用ではなく、Story固有の要件（409だけ
  再読込を促す・その他エラーとは文言も遷移も異なる）に応じてパターンの中身（フラグの分割粒度）を調整した
  判断であり、新しいSkillパターンではないため`frontend-conventions`は変更していない。
  発生スプリント: Sprint16（#14）
- **専用のブラウザ自動化ツールが実行環境に無い場合でも、headless Chrome（`chrome.exe --headless=new
  --remote-debugging-port=N --user-data-dir=<tmp>`）とNode.js 22+のネイティブ`WebSocket`グローバルだけで、
  Chrome DevTools Protocol（CDP）を直接叩く最小限のE2E検証ハーネスを自作できる。**
  `http://127.0.0.1:<port>/json/new`でタブを開き、返る`webSocketDebuggerUrl`へ接続、`Page.enable`/
  `Runtime.enable`/`Network.enable`した上で`Page.navigate`＋`Page.loadEventFired`待ち・`Runtime.evaluate`
  （`awaitPromise: true`でDOM操作を待機）でフォーム入力・クリック・`window.location`確認まで行える。
  jsdom/Vitestでは再現できない実ブラウザ固有の挙動（Vue Routerのinstall時初期ナビゲーション順序＝#33等）を、
  外部パッケージのインストール（Playwright/Puppeteer等のダウンロード）なしで検証できる。**検証の妥当性は
  「修正前のコードに戻して同じ手順を実行し、Issueの再現手順どおりにバグが再現すること」を確認してから
  「修正後は解消すること」を確認する2段構えで担保した**（テスト対象コードを一時的に元に戻す
  `git stash`往復で実施）。SPA保護ルートの実機到達性検証（PO傾向メモで指摘済みの弱点）に直接効く技法のため
  `frontend-conventions`§7へ即時反映した（詳細は「Skills更新履歴」）。
  発生スプリント: Sprint18（#33、初出。Chrome/Node実行環境が前提）
- **テーマ・言語のように「永続化・DB権威再水和の仕組みは共有するが、画面への適用先（DOM操作 vs vue-i18nの
  リアクティブ参照）が異なる」複数の横断設定値は、共有Pinia store（`usePreferencesStore`）へ集約しつつ、
  各値の適用（apply primitive）だけを個別関数に分離する設計が機能した。** `applyColorScheme`（`<html>`の
  `.dark`/`.light`クラス切替）と`applyLanguage`（`i18n.global.locale.value`代入）を分離し、共有部分
  （state・localStorage 2キー・`hydrateFromDb`によるDB同期）は1本にまとめた。**FOUC対策の要否も値ごとに
  非対称**であることを確認した: CSSクラス切替（初回描画前に適用しないと一瞬デフォルト状態が見える）は
  `index.html`の同期インラインhead scriptが必要だが、`createI18n()`の`locale`オプション自体をlocalStorage
  からseedできる項目（テキスト描画がVueマウント後にしか起きない）はhead script無しでもちらつかない。
  加えて、新規共通dropdown/menu部品（`SettingsDropdown.vue`・open/close・click-outside・aria/keyboard
  対応）を`{value,label}[]`＋`modelValue`の汎用propsで設計したことで、テーマ3択・言語2択の両方でそのまま
  再利用できた。今後複数の横断設定値を扱う機能を追加する際の設計型として`frontend-conventions`§7へ即時
  反映した（詳細は「Skills更新履歴」）。
  発生スプリント: Sprint19（#36/#25。初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外
  として即時反映）

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
- **Sprint14（#9/#10・注文履歴一覧/詳細）は、既達土台（#8注文ドメイン・#21認可部品・#1/#2カタログの
  ページング/JOIN先例）を最大限再利用する設計で計画され、3-repo cross-repo（database複合索引＋backend
  read API＋frontend画面）を通じて3観点レビュー指摘0件・手戻りゼロで完走した。** Sprint6以来の
  「secure-by-defaultな土台の上に積む」「先例を再利用する」パターンの延長線上にあるが、本Storyは
  Sprint4（#21）で用意されたまま3.5スプリント未適用だった`OwnershipAuthorizationService`が初めて実
  ドメインで検証された点、およびSprint12で発見されたperfパターン（識別子解決read/最終応答readの分離）が
  Cart（#29）・Order書込（#30）に続き3例目のドメイン（Order read）でも自発的に踏襲された点で、
  「土台・教訓が時間を跨いで複数Storyへ確実に転移する」プロセスの再現性を追加で実証した。
  発生スプリント: Sprint14（#9/#10）

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

### Sprint 10（#7・チェックアウト・ウィザード・確定前段まで・backend従/frontend主 cross-repo）

- **`frontend-conventions`**: `## 7. jpetstore-frontend 固有の注意事項` に以下2点を追記した（初出だが
  「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映。今後の多段階フロー
  （#8の注文確定拡張等）で直接再利用が見込まれるため）:
  - 多段階入力フローは単一ルート＋内部ステップ＋揮発Piniaで実装する（per-stepルートにしない・既達
    `authGuard`/`redirectValidator`が新規配線ゼロで機能する・下書きは明示`reset()`のみ）
  - View非テスト方針下の否定AC判定は、Piniaストアのtestableなgetterに切り出しVitestで固定する
- **`backend-conventions`へは反映しなかったもの**: read-only参照API（`AccountContactCustom*`）は
  Sprint2（#23）で既にSkill化済みのcustom mapper/entity配置・命名規約（§9）をそのまま踏襲しただけで
  新規パターンではないため、追記不要と判断した。
- **Skillに反映しなかった技術的ハマりポイント**: 以下2件はいずれも初出（1回目）のため、2回ルールに従い
  今回はSkillに反映せず`memory/dev/long_term.md`「技術的なハマりポイント」に留めた:
  - GroovyのGStringは`equals(String)`が常にfalseを返すため`jsonPath(...).value(gstring)`が一致しない
    （`.toString()`変換で回避）
  - SpockのStubはインターフェースのデフォルトメソッドへ委譲しないため、デフォルトメソッド自体を
    直接Stubする必要がある
- 3観点レビュー指摘0件・手戻りゼロで完走した要因分析（Sprint6/7/9の「土台再利用」パターンが初の多段階
  UIフローでも機能した確認）は、チェックリスト項目ではなくプロセス上の教訓のためSkillには反映せず
  `memory/dev/long_term.md`「繰り返し指摘されるパターン」の「横断」に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 11（#8・注文確定・在庫の原子的引当・初の書込系トランザクション×並行制御・backend主/frontend従）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に「失敗監査等、呼び出し元txの
  ロールバックに影響されない独立監査記録は`@Transactional(REQUIRES_NEW)`の別beanメソッドで実装する」を
  新設した（初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映。Spring AOPの
  自己呼び出し限定という古典的な落とし穴を含み、本プロジェクト初の`REQUIRES_NEW`利用のため）。
  併せて既存の「Skillに未反映」注記リストへ、Sprint10で発生済みだった2件（GStringの`equals`問題・
  Spockのデフォルトメソッド委譲問題）とSprint11新出の2件（下記）を追記し一覧を最新化した。
- **`backend-conventions`へは反映しなかったもの（2回ルールに従いlong_term.md止まり）**: 以下4件は
  いずれも「初出（1回目）」のため、今回はSkillに反映せず`memory/dev/long_term.md`に留めた:
  - Spockの`Mock()`で`given:`の裸stubと`then:`の引数一致インタラクションを同一メソッドに両方宣言すると
    `then:`側が優先され`given:`の副作用が無視される（「技術的なハマりポイント」参照）
  - `VARCHAR(10)`自然キー列（`m_item.item_id`）へテスト用IDを設計する際の桁数超過（同上）
  - `ExecutorService`+`CountDownLatch`によるMockMvc並行安全性テストのパターン（「習得したこと」参照。
    Sprint9のMockMvc CSRF Cookieテスト制約と同様、テスト技法の発見のため2回ルール対象）
  - 既存共有seedに依存するspecがある状態で初めて対象テーブルを書き換えるテストを足す際の専用データ隔離
    方針（同上）
- 3観点レビュー指摘0件（6回目の3観点クリーン。初の書込系トランザクション×並行制御という最難関クラスでの
  達成）は、チェックリスト項目ではなくプロセス上の教訓のためSkillには反映せず`memory/dev/long_term.md`
  「繰り返し指摘されるパターン」の「横断」に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 12（#29・コードベース初のRepository層導入PoC・Cart参照実装）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項`の「Application ServiceはRepository
  経由で永続化にアクセスする」セクション（Sprint12冒頭でSMが規約明文化済み）に、以下2点を追記した:
  1. **2回ルールによる昇格**: Spockの`Mock()`で`given:`の裸stubと`then:`ブロックの引数一致インタラクション
     を同一メソッド呼び出しに両方宣言すると、`then:`側が優先され`given:`の返り値/副作用クロージャが無視
     される問題。Sprint11（`OrderApplicationServiceSpec`）が初出、Sprint12（`CartApplicationServiceSpec`
     の`ensureCart`/`findByCartId`スタブ・`MyBatisCartRepositorySpec`の`cartCustomMapper.ensureCart`スタブ）
     で2回目発生したため、§9へ「同一呼び出しへの`given:`/`then:`分離を避け、1つの`then:`インタラクションに
     matcherと`>>`をまとめて書く」ルールとして新設した（bad/good例付き）。
  2. **初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映**: #29 Cart PoC
     で確立した3パターン（record→class＋`reconstruct()`／軽量identityハンドル／Repositoryモック合成による
     DB非依存クエリ数証明）を、#30（Catalog/Account/Order全体展開）が踏襲すべき先例テンプレとして§9へ
     追記した（詳細は`memory/dev/long_term.md`「習得したこと」参照）。
  - 併せて、§9末尾の「未反映の技術的ハマりポイント一覧」注記から、昇格したSpockの罠の記載を除去し
    一覧を最新化した。
- **`backend-conventions`へは反映しなかったもの**: Repository層導入時に「識別子解決用の読取」と「最終応答用
  の読取」を同じ集約全体読み込みメソッドで済ませてしまいクエリ数が純増する問題（3reviewer全員見落とし・
  SM精読で発見）は「初出（1回目）」のため、2回ルールに従い今回はSkillのチェックリストとしては追加せず
  `memory/dev/long_term.md`「繰り返し指摘されるパターン」に留めた（ただし回避パターン自体＝`ensureCart`/
  `findByCartId`分割は上記1のCart PoCテンプレに含まれているため、#30がテンプレを踏襲すれば同じ問題は
  構造的に再発しない見込み）。
- 3reviewer全員クリア後にSMのコア精読で新規perf差分が見つかった一件（reviewerプロセスの限界とSM精読の
  価値の実証）は、チェックリスト項目ではなくプロセス上の教訓のためSkillには反映せず
  `memory/dev/long_term.md`「繰り返し指摘されるパターン」の「jpetstore-backend」冒頭に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 13（#30・Repository層をCatalog/Account/Orderへ全展開・#29テンプレの横展開実証）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項`の「#29 PoCで確立した実装パターン」
  直後に「書込集約の適用範囲（rich集約 vs 薄い書込record＋orchestration残置・#30で確定）」を新設した。
  **2回ルールの対象外（即時反映）**: 再発防止のためのチェックリスト項目ではなく、#29テンプレ（record→class＋
  `reconstruct()`）を機械的にすべての書込系Repositoryへ適用すべきではないという**適用範囲の判断軸**（集約の
  不変条件がitem単位で濃いか＝Cart型／tx・並行制御が支配的で薄いか＝Order型）を明文化した実装パターンのため。
  POからIssue本文の「#29集約パターンに準拠」という文言がrich集約と読めるとの指摘があり、今後同種の曖昧さが
  再発しないよう先回りして追記した。
- **`backend-conventions`へは反映しなかったもの**: Spockの`given:`裸stub×`then:`引数一致の罠がSprint13で
  3回目発生した（`CatalogApplicationServiceSpec`）が、既に§9へ2回ルール昇格済み（Sprint12）のルールと
  完全に同一パターンで即座に解消できたため、追加のSkill変更は不要と判断した（`memory/dev/long_term.md`
  「技術的なハマりポイント」に3回目発生と昇格ルールの実効性を記録するに留めた）。
- 3reviewer・SMコア精読とも指摘0件（クリーン）は、#29テンプレをCatalog/Account（CQRS射影）・Order
  （書込orchestration残置）の3 bounded context全てへ無改造〜設計判断込みで適用できた結果であり、
  チェックリスト項目ではなくプロセス上の教訓のため`memory/dev/long_term.md`「繰り返し指摘されるパターン」
  「習得したこと」（jpetstore-backend）に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 14（#9/#10・注文履歴一覧/詳細・`OwnershipAuthorizationService`の初の実ドメイン適用）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項`の「本人スコープ（所有者一致）認可は
  `OwnershipAuthorizationService`に集約する」直後に「所有者限定＋列挙対策のreadエンドポイントは、不存在も
  含めて同一の`AccessDeniedException`（403）に正規化する」を新設した。**初出だが「知らないと書けない
  参照知識・実装パターン」の2回ルール例外として即時反映**: 再発防止のためのチェックリスト項目ではなく、
  `OwnershipAuthorizationService`（#21で用意・本Storyが初の実ドメイン適用）を「連番IDで推測可能なリソース」
  と組み合わせる際の具体的な設計判断（不存在も403に含める・既存§5「認可チェックは存在確認の直後」ルールとの
  使い分け）を明文化した実装パターンのため。POからの要望検討時に「昇格候補か」を明示的に問われ、
  過去の`OwnershipAuthorizationService`関連追記（Sprint4）・`REQUIRES_NEW`（Sprint11）と同じ「参照知識」
  という位置づけで即時反映が妥当と判断した。
- **`backend-conventions`へは反映しなかったもの**: CQRS射影read系メソッドへの`@Transactional(readOnly =
  true)`付与がコードベース内で不統一（`AccountApplicationService`=付与済み／`CatalogApplicationService`・
  `OrderApplicationService`（#9/#10）=無指定）という、reviewerではなくDEV自身がRetroで発見した観点は、
  既存ルール（§4）自体は既に存在し新規の実装パターンではないため、`memory/dev/long_term.md`「繰り返し
  指摘されるパターン」（jpetstore-backend）に初出として記録するに留めた（2回ルールの通常適用。次に
  同種のCQRS read系Serviceを実装/レビューする際に再確認する）。
- 3reviewer指摘0件（クリーン）・Sprint12のperf教訓（識別子解決read/最終応答readの分離）が3例目のドメイン
  でも自発的に踏襲された点・カタログのページング/JOIN先例が2例目のドメインへ転用できた点は、いずれも
  チェックリスト項目ではなくプロセス上の教訓のため`memory/dev/long_term.md`「繰り返し指摘されるパターン」
  「習得したこと」（jpetstore-backend・横断）に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 15（#11/#12/#28・既達Story群のハードニング＋カートマージN+1バッチ化retrofit）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項`の「書込集約の適用範囲」直後に「型自体が
  撤去/非依存のフレームワーク機能の構造的不在は、Bean不在ではなくクラス不在（`Class.forName`）で回帰テスト
  固定する」を新設した。**初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映**:
  再発防止のためのチェックリスト項目ではなく、Spring 6+でremoting系エクスポータの型自体が撤去済みという
  前提知識が無いと書けない具体的なテスト技法（`RemotingSurfaceAbsenceSpec`）のため。あわせて、露出面をREST
  限定に明文化する`package-info.java`の置き場所（ADR不採用・パッケージJavadocコメント方式）も記載した。
- **`backend-conventions`へは反映しなかったもの**: 以下2件はいずれも「初出（1回目）」のため、2回ルールに
  従い今回はSkillに反映せず`memory/dev/long_term.md`に留めた:
  - 撤去対象コードがcodegen（`EnumGenerator`/`MultiEnumGenerator`）の生成物かどうかを撤去前に確認する
    習慣（#12） → 「繰り返し指摘されるパターン」（横断）に記録。
  - refactorの挙動不変ACでバックログ仮定のデータ構造を実コードで裏取りし、coalesce＋クランプ単調性で
    厳密パリティを数学的に証明する技法（#28） → 「習得したこと」（jpetstore-backend）に記録。
- 3reviewer・SM独立verificationとも指摘0件（tier分離15連続クリーン）は、チェックリスト項目ではなくプロセス上
  の教訓のためSkillには反映せず`memory/dev/long_term.md`「繰り返し指摘されるパターン」（jpetstore-backend冒頭）
  に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 16（#13/#14・E4 ユーザー登録＋アカウント編集・version楽観ロック初実装）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に以下2点を追記した:
  1. **2回ルールによる昇格**: セキュリティ関連の試行カウンタ/レート制限をDB-backedテーブルで永続化する
     一般ルール。Sprint4（#20・`t_login_attempt`）が初出、Sprint16（#13・登録レート制限で計画フェーズの
     当初案がin-memoryだったところをユーザーが`t_register_attempt`のDB-backed方式へ明示的に訂正）で
     2回目の発生と判断し、「新規に試行カウンタを設計する際はDB-backedを第一候補とする」ルールとして
     §9へ新設した（実装レシピ＝単文アトミックupsert・DB側`NOW(6)`比較・キー選定方針も併記）。
  2. **初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映**: #14で確立した
     version楽観ロックUPDATEの実装パターン（GET/PUT間のversion往復・単一集約ルートversionトークンでの
     複数テーブル横断ガード・依存UPDATEのaffected>0条件付き発行・UPDATE成功後の再SELECT省略）。Sprint4で
     用意した足場が3スプリント（Sprint12-14）実利用ゼロのまま維持された後の**コードベース初のUPDATE実装**
     であり、#29 Cart PoCテンプレ（Sprint12）・書込集約の適用範囲（Sprint13）と同じ「今後の同種Storyが
     踏襲すべき先例テンプレ」という位置づけのため即時反映が妥当と判断した。
- **`backend-conventions`/`frontend-conventions`へ反映しなかったもの**: 以下はいずれも既存ルールの
  Story固有の適用・再利用であり新規パターンではないため、`memory/dev/long_term.md`への記録に留めた:
  - frontend: #14の409競合UXを`hasConflict`/`hasSaveError`/`shouldPromptReload`に分離した設計判断
    （Sprint10のstore getter切出しパターンの再利用＋Sprint14 `order.ts`とは異なる粒度の意図的選択）
    → 「習得したこと」（jpetstore-frontend）に記録。
  - `RegisterPayload`が`Address`型を継承する設計・`AccountEditDetail`が`Address`を継承しない設計
    （nullable差異による非互換の判断）は`backlog/sprint_16/implementation-notes.md`に仕様外判断として
    記録済みのためlong_term.mdへの重複記録はしない。
- 3reviewer/SM verificationの結果は本Retro時点（PRマージ前）では未確定のため、「繰り返し指摘される
  パターン」（reviewer起因分）の更新は次回Retro以降に持ち越す。本Retroの更新はDEV自身のTDD・実装中の
  自己発見（設計判断の訂正・初実装パターンの確立）のみを対象にした。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 17（#15/#16/#17・E4アカウントセキュリティ完結＝PW変更再認証・CSRF・入力検証）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に以下2点を反映した:
  1. **既存節への追記（2回ルール対象外）**: 「PasswordEncoderはDelegatingPasswordEncoderを使い...」節へ、
     bcryptの72バイト上限はUTF-8バイト長で判定する必要がある（文字数ではない）という注意点を追記した。
     新規チェックリスト項目ではなく既存のbcrypt関連参照知識セクションの拡充のため。
  2. **初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映**: 認証隣接の
     失敗系統（現在パスワード誤り等）を既存の401（silent refresh誤発火）/403（CSRF欠落）と衝突しない
     専用ステータス（422）へ分離する設計判断・共有`@StrongPassword`制約によるDTO横断のパスワード強度検証
     1本化を新設した。今後パスワード変更に類する「認証隣接の新しい失敗系統」を設計するStoryが踏襲できる
     判断軸・実装パターンのため。
- **`backend-conventions`/`frontend-conventions`へ反映しなかったもの**: 以下はいずれも初出（1回目）または
  既存パターンのStory固有再利用であり、`memory/dev/long_term.md`への記録に留めた:
  - `HttpStatus.UNPROCESSABLE_ENTITY`→`UNPROCESSABLE_CONTENT`（Spring Framework 7.0改名）→
    「技術的なハマりポイント」（jpetstore-backend）に初出として記録。
  - `npm run format`（Prettier）実行時のfrontend初のCRLF EOLノイズと選択addでの回避→「技術的なハマり
    ポイント」（jpetstore-frontend）に初出として記録。
  - パスワード変更後のトークンローテートに既存`AuthApplicationService.issueTokensFor`を再利用した設計→
    新規パターンではなく既存メソッドの再利用のため「習得したこと」（jpetstore-backend）に記録。
  - `AddressForm.vue`（checkout共用）への後方互換opt-inプロップ（`errors?`/`maxLengths?`）拡張→ Sprint7で
    確立済みの「共通コンポーネント拡張時の既存利用箇所への影響配慮」の再適用でありStory固有判断のため、
    `backlog/sprint_17/implementation-notes.md`に記録済み・本ファイルへは重複記録しない。
- 3reviewer・SM verificationとも指摘0件（tier分離17連続クリーン）は、チェックリスト項目ではなくプロセス上
  の教訓のためSkillには反映せず`memory/dev/long_term.md`「繰り返し指摘されるパターン」（jpetstore-backend
  冒頭）に記録した（あわせてSprint16分の反映持ち越しも本Retroで解消した）。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 18（#33/#34/#27・#31・#26・出荷済み保護ルート機能の実機到達性回復＋低リスク技術的負債の焼却）

- **`frontend-conventions`**: `## 7. jpetstore-frontend 固有の注意事項` に以下2点を追記した:
  1. **2回ルールによる昇格**: `npm run format`（Prettier）実行時のCRLF/EOLノイズ。Sprint14→15→17で
     3回発生していたにもかかわらず、各Retro時点では「初出」として個別にlong_term.md止まりの扱いに
     なっていた（Sprint17 Retro時点の記録誤り）。Sprint18で4回目の発生が確認されたことを機に本Retroで
     経緯を訂正し、`git diff --stat`（既定の`core.autocrlf=true`）による選択addの徹底をコミット前チェック
     項目として`frontend-conventions`§7へ昇格した。恒久対策（`.gitattributes`）はSM側で別Issue化を検討中。
  2. **初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映**: headless
     Chrome＋Node.jsネイティブ`WebSocket`によるCDP直叩き実機検証技法（#33）。PO傾向メモ「SPA保護ルートの
     実機到達性がAC/受入検証から漏れやすい」に直接対応する技法であり、追加パッケージ導入なしで再現可能な
     ため、今後の類似検証（ブラウザ専用挙動・ハードナビゲーション系AC）で再利用が見込まれる。
- **`backend-conventions`/データベース関連へ反映しなかったもの**: 以下2件はいずれも発生頻度が読めない
  一回性の高いタスク種別のため、今回はSkillに反映せず`memory/dev/long_term.md`「習得したこと」に技法として
  記録するに留めた:
  - #31: JDT "Null type safety"警告（メソッド参照のfalse-positive）はラムダ化で解消できるという知見
    （backend）。
  - #26: 依存の版currency棚卸しをOSV.dev + Maven Central metadataの実データクエリで確定する技法
    （database。E6/foundation系Issueの発生頻度自体が低いため）。
- 3reviewer指摘0件（tier分離18連続クリーン。frontend/database側の初回クリーンスプリントも各セクションに
  追記）は、チェックリスト項目ではなくプロセス上の教訓のためSkillには反映せず`memory/dev/long_term.md`
  「繰り返し指摘されるパターン」の該当リポジトリ冒頭に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 19（#36/#25/#37/#35・共有preferences設定基盤＋日本語ローカライズ完全実装・cross-repo 3-repo）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項` に「login()実行中は`CurrentUserProvider`
  が使えない（stateless JWTの制約・userId明示引数のread method）」を新設した。**初出だが「知らないと書けない
  参照知識・実装パターン」の2回ルール例外として即時反映**: 再発防止のためのチェックリスト項目ではなく、
  login()実行中に本人データを読む必要がある今後のStory（本人向け初期表示値のログイン応答同梱等）が踏襲
  できる具体的な設計パターン（`getPreferences(Long userId)`型のオーバーロード・共有DTO1箇所拡張で複数
  エンドポイントに効かせる設計）のため。
- **`frontend-conventions`**: `## 7. jpetstore-frontend 固有の注意事項` に以下2点を追記した:
  1. **2回ルールによる昇格**: 共通レイアウト（`AppHeader`/`AppLayout`）へ新規のインタラクティブ要素を
     追加する際の`find('button')`/`find('form')`衝突。Sprint7（#2、検索フォーム追加時）が初出、Sprint19
     （#36、テーマ設定ドロップダウンのtriggerボタン追加時に`ItemDetailView.spec.ts`で再発）で2回目の
     発生と判断し、「新規のインタラクティブ要素を共通レイアウトへ追加する際は既存View群のテストで汎用
     セレクタが使われていないか確認する」をチェックリスト項目として§7へ昇格した。
  2. **初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として即時反映**: 複数の
     横断設定値（テーマ・言語）を扱う共有Piniaストアの設計パターン（apply primitiveの個別化・FOUC対策の
     値ごとの非対称・汎用dropdown/menu部品の設計）。今後複数の横断設定値を扱う機能全般で再利用が見込まれる。
- **Skillへ反映しなかったもの（2回ルールに従いlong_term.md止まり）**: Sprint Review指摘（NOT NULL DEFAULT
  列追加時のdev-seedフィクスチャ明示更新・ローカルdevスタックでのseed投入実機確認）は、真因が実機で
  再現できなかった1件のみのため、`backend-conventions`/`rules/database.md`/`developer-workflow`のDoDへの
  昇格は見送り、`memory/dev/long_term.md`「繰り返し指摘されるパターン」（jpetstore-database）に初出として
  記録するに留めた（次回同種発生時に2回目として再評価する）。
- 3reviewer・SM独立verificationとも指摘0件（tier分離19連続クリーン）は、チェックリスト項目ではなく
  プロセス上の教訓のためSkillには反映せず`memory/dev/long_term.md`「繰り返し指摘されるパターン」の該当
  リポジトリ冒頭に記録した。
- `#skills-changelog` へ `[DEV]` で投稿済み。

### Sprint 20（#38/#39/#40/#41・Phase 4 L3セキュリティ回帰の確定所見Find-and-Fix）

- **`backend-conventions`**: `## 9. jpetstore-backend 固有の注意事項`の「セキュリティ関連の試行カウンタ/
  レート制限はDB-backedテーブルで永続化する」節へ、以下を追記した。**既存の§9昇格済みエントリへの追記の
  ため2回ルール対象外**（Sprint17のbcrypt 72バイト追記と同じ位置づけ）:
  1. 枠確保の原子化トランザクションは`@Transactional(propagation = REQUIRES_NEW)`で統一し、**同型の
     カウンタ系サービス（`RegisterAttemptService`/`AuditWriteQuotaService`/`LoginAttemptService`）間で
     伝播属性が非対称にならないよう明示する**（Sprint20 performance-reviewer指摘の再発防止）。
  2. check-then-actを条件付きUPDATEで原子化する2文イディオム（no-op ODKUで行の存在を保証する`ensureRow`→
     既存check式をそのまま`WHERE`句へ移植した条件付きUPDATEの`affected rows`で可否判定する`acquireSlot`）
     を実装レシピとして追記。既存のSET句/WHERE句を一字も変えず移植することの重要性（左→右評価順依存の
     再発防止）も明記。
  さらに新規サブセクションとして以下2点を新設した。**初出だが「知らないと書けない参照知識・実装パターン」の
  2回ルール例外として即時反映**:
  3. **セキュリティ統制（fail-closed）と、統制を支える可用性のための緩和策（fail-open）を区別する判断軸**
     （#39・quotaチェック自体の障害で本来の統制＝監査記録を止めない設計）。
  4. **`ApplicationContextRunner`によるコンテキスト起動失敗の分離固定**（実ブート経路のSpecに足すと
     Flyway/DataSource初期化順でflakyになるため分離する・`Duration`型`@Value`変換には`conversionService`の
     明示登録が必要という罠を含む）。
- **`backend-conventions`/`frontend-conventions`へ反映しなかったもの**: 以下はいずれも初出（1回目。同一
  スプリント内の複数発生は2回ルールの「異なるレビュー時点で2回」を満たさないと判断）または発生頻度が
  読めない技法のため、`memory/dev/long_term.md`への記録に留めた:
  - performance指摘（`LoginAttemptService`のtx伝播属性の兄弟クラス非対称）・SM verification確定所見
    （`AuditLogRecorder`のbest-effort保護境界の呼び出し元遡り漏れ）→「繰り返し指摘されるパターン」
    （jpetstore-backend）に初出として記録。
  - convention非ブロッキング指摘（Spring AOP自己呼び出しjavadoc注記の適用漏れ）は既存§9ルールの適用漏れの
    実例のため新規昇格対象外→同上セクションに記録。
  - javadocの`{@link}`宙吊り参照2件（#38・#41）は同一スプリント内発生のため2回ルール未充足と判定し
    Skill未反映（javadoc lint導入はSM/インフラ判断のため申し送り事項として提起）→同上セクションに記録。
  - `@MockitoSpyBean`による単発例外注入技法（interfaceのみのMyBatis Mapperへの障害注入）→「習得したこと」
    （jpetstore-backend）に記録（発生頻度が読めないため見送り）。
- 3reviewer・SM独立verificationの結果は**tier分離19連続クリーン記録が途切れた**（performance 1件＋SM
  verification確定所見1件、計2件。1ラウンドに束ねて対応し往復ゼロで解消。convention・securityは指摘0件）。
  チェックリスト項目ではなくプロセス上の記録のため`memory/dev/long_term.md`「繰り返し指摘されるパターン」
  （jpetstore-backend冒頭）に記録した。
- `frontend-conventions`は本スプリントfrontend無変更のため対象外。
- `#skills-changelog` へ `[DEV]` で投稿済み。

## 卒業済みルール

（該当なし。棚卸し対象となるルールが直近15スプリント基準に達していない。
  jpetstore-backendはSprint2・3・4・6・7・8・9・10・11・12・13・14・15・16・17・18・19・20の18スプリント、
  jpetstore-databaseはSprint1・3・6・14・16・18・19・20の8スプリント、jpetstore-frontendはSprint5・6・7・8・
  10・11・14・15・16・17・18・19の12スプリント（Sprint20はfrontend無変更のため不算入）のみのため、いずれも
  対象外。§9/§7昇格済みルールの昇格後経過スプリント数（直近15スプリント基準の分子）は、catch-all例外横取り
  （Sprint7昇格）が13スプリント（Sprint8〜20）・Spockの`given:`裸stub×`then:`引数一致（Sprint12昇格）が
  8スプリント（Sprint13〜20）・DB-backedレート制限（Sprint16昇格）が4スプリント（Sprint17〜20。Sprint20は
  §9追記のみで新規逸脱ではないため「未発生」継続としてカウント）・frontend CRLFノイズ選択add（Sprint18昇格）
  が1スプリント（Sprint19。Sprint20はfrontend無変更のため不算入・据え置き）・frontend共通レイアウトへの
  新規要素追加時のfind('button')/find('form')衝突確認（Sprint19昇格）が0スプリント（昇格直後のまま・
  Sprint20はfrontend無変更のため不算入）で、いずれも15スプリントに満たない。
  Sprint4〜Sprint19 Retroに続きSprint20 Retroでも棚卸しを実施したが同様の理由で卒業候補なし）
