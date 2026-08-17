## #8: [E3] 注文確定でサーバ再計算・在庫の原子的引当・整合性を保証する

### 仕様外の判断・変更・妥協点

- **OrderControllerのテストは`@WebMvcTest`スライスではなく`IntegrationTestBase`(Testcontainers)に統一した**: 計画メモは「OrderController `@WebMvcTest`」と想定していたが、本プロジェクトには`@WebMvcTest`スライスの前例が一件も無く（Cart/Account等の既存Controllerテストは全て`IntegrationTestBase`+`@AutoConfigureMockMvc`の実DB統合テスト）、CSRF/JWT認証フィルタチェーンをスライスで再現するための新規インフラ整備コストが見合わないため、既存の一貫したパターンをそのまま踏襲した。結果として`OrderControllerSpec`は住所欠落400・409・201・監査行・AC-neg1〜3を全て実DBで検証している。
- **注文確定で在庫を実際に減算するテスト(`OrderControllerSpec`/`OrderConcurrencyIntegrationSpec`/`InventoryCustomMapperSpec`)は、既存カタログseed（EST-*）を再利用せず専用アイテム（`ZZ-ORDER-*`/`ZZ-ORD-C1`/`ZZ-INV-1`）を都度INSERT/DELETEする設計にした**: `IntegrationTestBase`はTestcontainers MySQLコンテナ・Spring контекストをテストスイート全体で共有するため、EST-*の在庫を減算する実装がもし他specの前提（例: `CartControllerSpec`の「EST-2, stock=1」)を壊すと、テスト実行順序に依存した不安定な失敗を招く。カート機能(#4/#5/#6)は在庫を一切更新しないため今まで問題化しなかったが、注文確定(#8)が本プロジェクト初めて`t_inventory`を書き換えるため、この隔離方針を新たに導入した。
- **`InsufficientStockException`は在庫不足と空カートの両方に再利用した**（`itemId=null`＝空カート）: 計画フェーズ確定②「空カート=409（在庫不足と同系）」を、新しい例外型を増やさず1クラスで表現する設計とした。
- **`AuditLogRecorder.recordStateChangeIndependently`のtargetId引数は空カート・在庫不足いずれの失敗時もnull固定**とした（対象注文がそもそも成立していない=紐づけるorderIdが無いため）。detailの`itemId`（在庫不足時のみ非null・空カート時はnull）で失敗理由を判別できる。
- **`PlaceOrderCommand#effectiveShipping()`は`useSeparateShipping=true`かつ`shipping=null`の場合にbillingへフォールバックする防御的実装にした**: frontendのウィザードは`canProceedFromAddress`で到達不能なエッジケースだが、直接API POSTするクライアントに対してNPEではなくbillingへの安全なフォールバックとした（バリデーションエラーにはしない。ACに明記が無いための実装判断）。
- **`OrderController`の`PlaceOrderRequest.shipping`フィールドは`@Valid`を付与しない設計にした**: frontendの`checkoutStore.shipping`は`useSeparateShipping=false`のとき未入力（空文字列群）のまま送信されるため、`shipping`へ`@Valid`を付けて`billing`と同じ`@NotBlank`群を強制すると、別配送を使わない正常系が誤って400になってしまう。billingのみ`@NotNull @Valid`で厳格検証し、shippingは緩く受理してサービス層の`effectiveShipping()`が使う場合だけ実質的に使われる設計にした。
- **frontendの`domain/order.ts`（`OrderPlacementRequest`）はbackendの`OrderAddressRequest`が使わないemail/phoneも含む`Address`型をそのまま`billing`/`shipping`へ渡す設計にした**: backendは`t_order`に対応列が無いフィールドを受理しても無視するだけ（Jacksonの未知フィールド許容・既存`CartControllerSpec`の`#5 AC-neg1`で実証済みの挙動を踏襲）のため、frontend側でフィールドを削ぎ落とす追加のマッピング層を作らずシンプルさを優先した。
- **frontendの`stores/order.ts`は新規Piniaストアとして`checkout`ストアと分離した**: `checkout`ストアは下書き（住所入力等・揮発）専用の責務を保ち、確定結果（`result`/`isPlacing`/`placeError`）は別ストアに持たせることで、#10（注文詳細閲覧）等の後続Storyが`order`ストアを拡張しやすい構成にした。
- **`CheckoutCompleteView.vue`はVitestテスト対象外**（frontend-conventions: View/Componentは見た目のみの変更のためテスト不要）とし、否定AC相当の判定（`hasResult=false`時は`/`へredirect）は`orderStore.hasResult`（testableなgetter）で担保した（#7で確立したパターンをそのまま踏襲）。
