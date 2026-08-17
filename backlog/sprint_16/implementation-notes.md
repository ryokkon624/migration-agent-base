## #13: [E4] ユーザー登録（自動ログイン・セッション再生成）を提供する

### 仕様外の判断・変更・妥協点

- **登録レート制限（`RegisterAttemptService`）は成功/失敗を問わず必ず1回`recordAttempt`する設計にした**:
  既存`LoginAttemptService`は「失敗のみ記録・成功でリセット」だが、登録は1回の試行自体がIP由来の資源消費
  （アカウント大量作成の温床）であるため、結果に関わらずカウントする方が抑止として妥当と判断した。ただし
  レート制限ゲート自体（`assertNotRateLimited`）で短絡した場合は記録しない（`LoginAttemptService`の
  `assertNotLocked`短絡時と同じ設計）。
- **`recordAttempt`に`@Transactional(propagation=REQUIRES_NEW)`を付与した**: `RegistrationApplicationService
  .register`はusername重複等でメインの`@Transactional`をロールバックすることがあるが、レート制限カウンタは
  業務データの成否と独立して必ずコミットされる必要があるため、`AuditLogRecorder
  .recordStateChangeIndependently`と同じ設計判断を踏襲した。
- **`RegisterAttemptProperties`の閾値既定値（5回/15分）は`LoginAttemptProperties`と同じ値を流用した**:
  バックログでは「閾値既定はDEV調整」とされていたため、既存の実証済みデフォルトをそのまま採用した。
  `auth.register-rate-limit.*`で運用時に個別調整可能。
- **`AccountRepository.register()`は1メソッドでm_account/m_signon/m_profileの3件INSERTを行う設計にした**:
  Order（`insertHeader`/`insertLine`を分離）とは異なり、登録は「1回の業務アクションで3表へ常に一緒に書く」
  性質のため、Repositoryインタフェースを1メソッドに集約した（呼び出し元Serviceを薄く保つ）。
- **`MyBatisAccountRepository`は`CurrentUserProvider`に依存しない**: `MyBatisCartRepository`/
  `MyBatisOrderRepository`は認証済みユーザー操作のため`CurrentUserProvider`からWHO列を解決するが、登録は
  未認証guestによる操作のため`create_user_id`/`update_user_id`は常に`null`を明示設定する（E7）。
- **`IntegrationTestBaseSmokeSpec`のマイグレーション件数アサーション（11→12）を更新した**: `V00_000_012`
  追加に伴う既存テストの機械的な追従（判断を伴う変更ではないが記録として残す）。
- **frontend: `RegisterPayload`型は`Address`（`domain/checkout.ts`）を継承する形にした**: backendの
  `RegisterRequest`が氏名/連絡先/住所でチェックアウトの`Address`と完全に同じ形（firstName/lastName/email/
  phone/address1/address2/city/state/postalCode/country）だったため、`Address`を継承し
  username/password/repeatedPasswordのみ追加する設計にした。これにより既存`AddressForm.vue`を無改造で
  `RegisterView.vue`に再利用できた（新規CSSも住所欄は書いていない）。
- **frontend: 登録失敗理由の分類（`RegisterErrorReason`）はHTTPステータスコード起点にした**（`order.ts`の
  `PlaceOrderErrorReason`と同じ設計）。409→USERNAME_TAKEN・429→RATE_LIMITED・400→PASSWORD_MISMATCH・
  それ以外→default。backendがエラーコードをbody（`ErrorResponse.code`）に持つが、既存のcart/order storeも
  ステータスコードのみで分類しておりcode文字列を消費していないため、既存パターンを踏襲した。
- **frontend: パスワード一致検証をクライアント側でも先取りして行う**（`RegisterView.vue`の
  `passwordsMismatch`算出プロパティ）: サーバ側検証（400）が権威だが、送信前にUXとして即座にフィードバック
  する方が体験が良いと判断した。サーバ検証は後方互換のフォールバック（JS無効・バイパス等）として維持する。

## #14: [E4] アカウント/プロフィール編集を本人固定・allowlist バインドにする

### 仕様外の判断・変更・妥協点

- **`m_profile.version`列は編集で一切触らない(SETにもWHEREにも含めない)**: DDL上は3表(account/signon/
  profile)ともversion列を持つが、E2決定「m_account.versionが編集アグリゲート単一の楽観ロックトークン」に
  従い、m_profile.versionは更新のたびにインクリメントもしない（将来profile単独の楽観ロックが必要になった
  場合は別途検討する前提の割り切り）。
- **`AccountUpdate`/`AccountEditCommand`の2段レコード変換パターンを採用**: #13の
  `RegisterAccountCommand`→`NewAccountRegistration`と同型（Controller入力用コマンド→
  CurrentUserProvider解決後のRepository入力用コマンド）。userIdを持たないクライアント入力から、
  サーバ側解決後のuserId込みモデルへ変換する一貫パターンとして踏襲した。
- **`AccountApplicationService.updateAccount`は更新成功後に再SELECTしない**: 更新後の`AccountEditDetail`
  はDBへ再問い合わせせず、`command`の入力値＋`expectedVersion+1`から直接組み立てて返す。UPDATE成功時点で
  永続化された値は送信した入力値そのものであるため、追加SELECTは不要と判断した（Sprint12/13の
  「識別子解決用と最終応答用の読取を同一の集約全体読み込みで済ませない」教訓をさらに進め、そもそも
  再読取り自体をしない設計とした）。
- **`AccountRepository.updateAccount`はm_accountのversion競合(affected=0)時、m_profileのUPDATE自体を
  発行しない**: Repository内で早期return（`if (affected == 0) return 0;`）することで、無駄なSQL発行を
  避けつつ「account更新が成功した場合のみprofileも更新する」という順序保証をコードで表現した。
- **`MyBatisAccountRepository`は`updateAccount`でも`CurrentUserProvider`に依存しない**: 本人による
  自己編集のため、呼び出し元（`AccountApplicationService`）がCurrentUserProviderから解決済みのuserIdを
  `AccountUpdate.userId()`としてそのまま`update_user_id`に転用できる（登録時の「guestなのでCurrentUser
  Providerを使わない」という既存判断と、依存を増やさないという結論は同じだが理由が異なる点に注意）。
- **`AccountEditControllerSpec`はAccountControllerSpec（#7・`/me`）とは別ファイルにした**: `LoginLockoutSpec`
  /`AuthLoginLogoutSpec`の前例（関連するが独立したフィクスチャ管理を要する機能は別Specに分離する）を踏襲。
  m_profileフィクスチャの追加やAC-neg3の並行テスト用クリーンアップが#7側のテストに影響しないようにした。
- **frontend: `AccountEditDetail`型は`Address`を継承しない**: `RegisterPayload`（#13）は`Address`を継承
  できたが、`AccountEditDetail`はサーバから読み取った値（`address2`が未設定なら`null`。#7の
  `AccountContact`と同じ思想）を表すため`address2: string | null`が必要で、`Address.address2: string`
  （AddressFormのフォーム値・空文字許容）とは非互換。継承すると型矛盾になるため独立した型にし、View側で
  `checkout` store の`toAddress`と同じ橋渡し変換（null↔''）を行う設計にした。
- **frontend: 409競合とそれ以外の失敗を`hasConflict`/`hasSaveError`の別フラグに分離した**: 既存
  `order.ts`は409を専用理由（`INSUFFICIENT_STOCK`）として`placeError`1本にまとめているが、#14は
  「409だけ再読込を促す」UXが仕様上明確に異なる（バックログ計画確定事項）ため、判定を分離し
  `shouldPromptReload`ゲッターとして独立させた（Sprint10教訓＝判定をstore getterへ切出しVitest固定）。
- **frontend: 編集フォームは全編集可フィールド（langpref/favcategory含む）を表示する**: backendのPUTは
  部分更新ではなく全項目置換のため、フォームに表示しないフィールドがあると意図せずNULL/既定値へ
  巻き戻ってしまう。#13登録フォームがlangpref/favcategoryを意図的に非表示にした（E5・サーバ既定）のとは
  対照的に、#14編集フォームでは両方とも表示・編集可能にする必要があると判断した。favcategoryの選択肢は
  新規APIを作らず既存`catalogStore.fetchCategories()`を再利用した（土台再利用）。
