## #15/#16/#17: E4アカウントセキュリティ完結（PW変更再認証・CSRF回帰・入力検証）

### 仕様外の判断・変更・妥協点

- **`HttpStatus.UNPROCESSABLE_ENTITY`はSpring Framework 7.0で非推奨化されていたため、`UNPROCESSABLE_CONTENT`
  （値=422は不変・RFC 9110の呼称変更に追随した改名）を使用した。** ACやbacklogには明記されていなかったが、
  `./gradlew compileJava`のコンパイルノートで発覚し即座に是正した（JSON応答の`code`フィールド自体は既存の
  `"UNPROCESSABLE_ENTITY"`文字列のまま維持・Java enum名の改名とは独立）。
- **PasswordChangeControllerSpecのm_signonフィクスチャ**は`AuthLoginLogoutSpec`と同型（テスト自身が
  `passwordEncoder.encode()`で生成した既知パスワードのbcryptハッシュを自己INSERT）で用意した。
- **`SignonCustomMapper.updatePassword`はPOJO（`SignonUpdateCustomEntity`）を単一パラメータとするアノテーション
  方式**を採用した。複数`@Param`スカラーではなくPOJOにした理由は、`AuditProgramInterceptor`のJavadocが警告する
  「paramがMapの場合、存在しないキーへの意図しないput」を構造的に回避するため（既存`AccountUpdateCustomEntity`
  と同じ設計判断）。
- **`@StrongPassword`のUTF-8バイト長判定はcode point走査ではなく`String#getBytes(UTF_8).length`を使用**した
  （backend）。frontend側`isStrongPassword`は`TextEncoder`でミラーしている。
- **frontend`accountValidation.ts`のemail検証・PW強度判定は正規表現の文字クラスを一切使わず実装**した
  （`long_term.md`記録済みの「正規表現の文字クラスリテラルが編集ツールで意図せず書き換わる」既知リスクの回避策。
  `redirectValidator.ts`と同じ方針）。
- **`auth.ts`の`RegisterErrorReason`を`PASSWORD_MISMATCH`→`VALIDATION_ERROR`へ一般化**した（#17により400の原因が
  パスワード不一致以外にもemail形式/最大長/PW強度等に拡大したため。既存`auth.spec.ts`のテスト名・アサーションを
  合わせて更新）。RegisterView自身のクライアント側パスワード一致プレチェック文言は
  `account.register.passwordMismatch`として別キーに分離し、backend由来の`VALIDATION_ERROR`と混同しないようにした。
- **`AddressForm.vue`へ`errors?`/`maxLengths?`のopt-inプロップを追加**した。checkout側（`CheckoutAddressStep.vue`）
  は未指定のままのため挙動不変（Sprint7共用フォーム教訓の踏襲）。
- **実機`bootRun`起動確認は省略**した。`SecurityConfig`は無変更（新規`permitAll`追加なし）であり、新規エンドポイント
  （`POST /api/account/password`）は`PasswordChangeControllerSpec`（Testcontainers＋MockMvc・実際のSecurity
  フィルタチェーン＝CSRF/JWT認証/例外ハンドリングを全経路通過）で401/403/404/405/422/400/204の全応答を実証済みの
  ため、`backend-conventions`§9の実機確認が主眼とする「Spring Securityの実際のフィルタ挙動の見逃し」リスクは
  統合テストで十分にカバーできていると判断した。
