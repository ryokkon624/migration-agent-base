## #29: [E6] Cart を参照実装に Repository 層導入＋集約化（Application Service の Mapper 直呼び解消・PoC）

### 仕様外の判断・変更・妥協点

- **`CartRepository` のメソッド面は AC1 が例示した `findByUserId`/`save(Cart)` ではなく、D2=案A（ユーザー承認済）どおり
  `findByUserId` / `findStock` / `upsertItem` / `removeItem` の単一行粒度にした**: `save(Cart)`（集約全体差分反映）は
  dirty-tracking・全行upsert・欠落delete検出が必要になり、現行の1ユースケース=1行書込という軽量な永続化パターンより
  余分な書込・実装コストが増える（AC1本文の「追加が要る場合もドメイン語彙で命名する」の解釈として、実装レベルでは
  ドメイン語彙の細粒度メソッドを選んだ）。
- **`Cart`/`CartItem` のコマンドメソッド（`addItem`/`updateItem`/`mergeLine`）は集約の内部状態（`this.items`）を
  参照せず、呼び出し元が `StockAvailability` を引数で注入する設計にした**（D3で確定済）。これにより「在庫コンテキストを
  持つ対象アイテムが必ずしもカートに存在するとは限らない」（例: 初回addItem・merge未知アイテム）ケースを、集約の
  内部状態を検索する分岐なしに統一的に扱える。
- **`CartItem` に表示用フィールド（`productId`/`productName`/`attribute1`/`listPrice`）を持たない書込み専用ファクトリ
  `CartItem.forWrite(itemId, quantity, stockQuantity)`（package-private）を新設した**: `CartRepository#upsertItem` が
  実際に永続化するのは `cartId`/`itemId`/`quantity` のみ（表示用フィールドはDB行に存在せずJOIN都度算出のため）。
  `Cart` のコマンドメソッドが返す `CartItem` は書込み専用インスタンスであり、呼び出し元（`CartApplicationService`）は
  書込み後に必ず `CartRepository#findByUserId` を再取得して表示用の完全な `CartItem` を得る（旧実装の `toCart(cartId)`
  再クエリと同じI/Oパターンを踏襲）。このインスタンスの `productName()`/`lineTotal()` 等は呼び出されない前提（型では
  強制していない実装上の妥協点。ドキュメントコメントで明記）。
- **監査WHOカラム（`create_user_id`/`update_user_id`）の解決責務を `CartApplicationService` から `MyBatisCartRepository`
  へ移した**: 旧実装はService層が`CurrentUserProvider`からuserIdを取得しEntityへ設定していたが、`CartRepository`の
  書込みメソッド（`upsertItem`/`findByUserId`のensure部分）はuserIdをメソッド引数に取らない設計（D2の細粒度メソッド
  面に`userId`を含めなかった）にしたため、`MyBatisCartRepository`が`CurrentUserProvider`（Domain層interface）を直接
  注入し自己解決する形にした。永続化アクセスの唯一の入口であるRepositoryがWHO解決も担うことで、Application層は
  「認可の主体（カートの持ち主）」と「監査の主体（操作者）」が同一ユーザーである事実をRepositoryへ都度渡す必要が
  なくなった（本Story範囲では両者は常に同一のため実質的な差異は無いが、責務の置き場所として一貫性がある）。
- **既存の `CartApplicationServiceSpec`（不変条件の境界値テスト・`CartCustomMapper`をMock）は全面書き換えし、不変条件
  自体の検証は新設 `CartSpec`/`CartItemSpec`（純ドメインUT・Repository/Mapper非依存）へ移設した**（AC5・C2）。
  `CartApplicationServiceSpec`は`CartRepository`をMockした薄いオーケストレーションUT（正しいRepositoryメソッドが
  正しい引数で呼ばれるか・ドメイン例外が伝播しRepositoryへの書込みを止めるか）に再ターゲットした。
- **`CartConverter`（Entity→Domain変換）はSpring Beanにせず、`infrastructure.mybatis.cart`パッケージ内に閉じた
  package-privateのstaticユーティリティクラスにした**: Repository実装からのみ呼ばれる薄い変換関数であり、DIコンテナへ
  登録する動機（テスト時の差し替え等）が無いため、過剰抽象を避けた（R3）。

### 退行ガード結果

- `CartCustomMapperSpec`（Testcontainers）・`CartControllerSpec`（Testcontainers E2E）はいずれも無変更のままグリーン
  （`./gradlew integrationTest`）。
- `CartApplicationService`から`infrastructure.*`のimportが消えたことをgrepで確認（AC2）。
- 全UT（`./gradlew test`）・全IT（`./gradlew integrationTest`）green。

### perf是正（SM ④ verification・ユーザー承認により同スプリントで修正・commit 2a06942）

- **書込4操作（addItem/updateItem/removeItem/merge）が`findByUserId`（=`ensureCart`+`selectCartItems`の合成・4テーブル
  JOIN込み）を冒頭（cartId取得用）と末尾（最新カート返却用）で2回呼んでおり、書込1操作あたり+2クエリの純増になっていた**
  （addItem例: 原実装4→旧実装6）。3観点reviewerは3人ともクリアだったが、SMがコア精読で「`Cart.addItem`/`updateItem`/
  `mergeLine`は集約state（`items`）を使わず注入`StockAvailability`＋quantityのみで動く（D3）ため、冒頭の`findByUserId`の
  `items`ロードは実質不要」という設計上の見落としを発見した。
- **是正**: `CartRepository`に`ensureCart(userId):Long`（cartIdのみ解決・items非ロード）と`findByCartId(cartId):Cart`
  （select-only・ensureは行わない）を追加。書込4操作を「冒頭`ensureCart`1回＋末尾`findByCartId`1回」へ書き換え、
  原実装のbaselineクエリ数（addItem/updateItem=4、removeItem=3、merge=2+2N）へ戻した。`findByUserId`はこの2メソッドの
  合成として実装し、`viewCart`（2クエリ）は不変。
- **`Cart.identity(cartId)`（軽量ハンドル）を新設**: `items`を読まずにcartIdだけで`Cart`のコマンドメソッド
  （`addItem`/`updateItem`/`mergeLine`）を呼べるようにした（D3の「集約stateを使わない」という既存の設計判断を型として
  裏付ける追加ファクトリ）。
- **クエリ数の裏取り方法**: 実DBでのクエリカウント計測用インフラ（query-count計測ツール等）が本コードベースに無いため、
  新設`MyBatisCartRepositorySpec`（`CartCustomMapper`をmockした純UT。`ensureCart`/`findByCartId`がそれぞれ`CartCustomMapper`
  の対応メソッドを正確に1回だけ呼ぶことを検証）と、再ターゲットした`CartApplicationServiceSpec`（各操作で
  `CartRepository#ensureCart`/`findByCartId`が正確に1回ずつ呼ばれることを明示検証）を組み合わせ、「Repository各メソッド
  =1 SQL文」×「Serviceが各メソッドを1回だけ呼ぶ」の合成でクエリ数をDB非依存かつ決定的に証明する方式を採った。
- **実装中のハマりポイント（本プロジェクト既知パターンの再発・2回目）**: `given:`ブロックの裸stub（`mock.method(_) >>
  {...}`）と`then:`ブロックの引数一致インタラクション（`N * mock.method({matcher})`）を同一メソッド呼び出しに対して
  分けて書くと、`then:`側が優先され`given:`側の戻り値/副作用クロージャが無視される（Sprint11 `OrderApplicationServiceSpec`
  で既知のSpock挙動）。`CartApplicationServiceSpec`の`ensureCart`/`findByCartId`スタブと`MyBatisCartRepositorySpec`の
  `cartCustomMapper.ensureCart`スタブで同じ罠を踏み、テストがNPE/比較失敗でRED化した。`then:`ブロックの1つの
  インタラクションにmatcherと`>>`をまとめて書く形に統一して解消した。
