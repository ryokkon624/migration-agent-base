## #7: [E3] チェックアウト・ウィザード（カート確認→配送/請求先→確認）を提供する

### 仕様外の判断・変更・妥協点

- **`canProceedFromAddress`の必須項目定義**: AC/仕様に住所必須項目の明示が無かったため、`m_account`の
  `NOT NULL`列（firstName/lastName/email/phone/address1/city/state/postalCode/country）を必須、
  `address2`（DB上NULL許容）のみ任意とした。billing・別配送時はshippingも同じ基準で判定する。
- **プリフィルの再実行ガード**: `CheckoutView`のonMountedで毎回`prefillFromAccount()`を呼ぶと、
  ウィザード内を行き来した際にユーザーの上書き済み入力が上書きされ直してしまうため、`billing`が
  全項目空文字（＝初回入場）の場合のみプリフィルする実装にした。ACに明記が無いための実装判断。
- **checkoutストアの自動リセットは行わない**: `/checkout`への再入場（SPA内遷移での戻り）時に
  ストアを自動リセットしない。計画フェーズ確定③「揮発」はページリロードで消えることを指しており、
  SPA内の一時離脱までは保持する方が自然と判断した（`reset()`は明示アクションとしてのみ提供）。
- **AC-neg1の実装層**: 空カート判定は既存`stores/cart.ts`に`isEmpty`getterを追加する形で実装した
  （新規ストアを作らず、計画どおり既達cartストアへ切り出し）。`CheckoutView`のonMountedで
  `cartStore.fetchCart()`→`isEmpty`判定→`router.replace('/cart?reason=empty-checkout')`、
  `CartView`側は`route.query.reason==='empty-checkout'`を読んで正規化エラー文言
  （legacy「An order could not be created because a cart could not be found.」相当）を表示する
  だけに留め、別画面は新設しなかった（計画フェーズ確定C）。
- **checkoutドメインのAddress型はAccountContactと同形**: billing/shipping共通の`Address`型に
  email/phoneを含めた（住所そのものというより「連絡先込みの配送/請求先」として扱う）。プリフィル時の
  変換をコピーだけで完結させるための単純化。
- **`/checkout`は単一ルート・内部3ステップ**（計画フェーズ確定④）。per-stepルートは作らず、
  `stores/checkout.ts`の`currentStep`で画面を出し分けた。
- **確認ステップの「注文確定」ボタン**: 現行`CartView`の disabled+"Coming soon" と同型のステージング
  ボタンとして実装した（計画フェーズ確定②：実送信・在庫原子引当・永続化は#8）。`orderApi`は#7では
  作成していない。
