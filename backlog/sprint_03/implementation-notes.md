# Sprint 3 実装ノート（DEV / Sonnet）

## スコープ

backend REST＋Spring Security のみ（フロントは #24 へ持ち越し済）。
実装順: #19（PasswordEncoder＋bcryptハッシュ照合基盤＋デモシード）→ #18（login/logout エンドポイント＋UserDetailsService）。

## ブランチ

`feature/18-signon-auth`（#18/#19 包含）を `jpetstore-backend` と `jpetstore-database` の両方に main から新規作成。

## 実装中に確認した既存設計（実装への影響）

- `jpetstore-backend/src/test/resources/flyway/sql/README.md` により、**`flyway/sql-test` は backend の統合テストへ同期しない方針が既に確立済み**（統合テストは各テストが自己完結でフィクスチャを INSERT する）。
  → 計画メモにあった「新規 gradle `syncTestSeed` タスク」は見送り、既存方針に合わせる。
  → #19 のデモシード（`demo_user`）自体の検証テストは `jpetstore-database` 側（`AccountFixtureSpecBase` 系）に置く。
  → #18 の login/logout 統合テスト（backend）は、テスト自身が `JdbcTemplate` + 実 `PasswordEncoder` bean で account/signon を INSERT する自己完結フィクスチャ方式にする（既存 `SecurityEndToEndSpec` 等の流儀を踏襲）。
- `JwtAuthenticationFilter` は `Authentication#getPrincipal()` に `AuthenticatedUser` を直接セットする設計。今回追加する `UserDetailsService`/`DaoAuthenticationProvider` 経路（login 時のみ使用）は `AuthenticatedUserDetails`（`UserDetails` 実装）を principal にするが、これは `AuthenticationManager.authenticate()` の戻り値からユーザ情報を取り出して JWT を発行するためだけに使い、`SecurityContextHolder` へ最終的にセットする principal 型には影響しない（保護リソースへのその後のアクセスは従来どおり `JwtAuthenticationFilter` 経由で `AuthenticatedUser`）。

## コミット構成（予定）

- #19: `jpetstore-backend`（PasswordEncoderConfig + テスト）／`jpetstore-database`（R__test_user.sql に demo_user 追加 + 検証テスト）
- #18: `jpetstore-backend`（AccountAuthCustom{Entity,Mapper}・AuthenticatedUserDetails・JdbcUserDetailsService・SecurityConfig・AuthApplicationService・AuthController + 統合テスト）

## stale コメント是正

`AuthController`/`AuthApplicationService`/`SecurityConfig` の「login API は #21 の範囲」を #18 に是正。

## 実装結果

- コミット: `jpetstore-backend` 6618bf5(#19)・03edd6b(#18) / `jpetstore-database` 7285d21(#19)。ブランチ `feature/18-signon-auth`。
- テスト: `PasswordEncoderConfigSpec`（単体）・`DemoUserFixtureSpec`（database, Testcontainers）・`AuthLoginLogoutSpec`（backend, Testcontainers/MockMvc, 11ケース）。いずれも RED→GREEN で実装。
- `jpetstore-backend`: `./gradlew check`（UT+IT+spotlessCheck）green。`jpetstore-database`: `./gradlew test` green。
- 実機起動＋疎通確認（ローカル docker MySQL + `demo_user`（実bcryptハッシュ）でログイン）: login(200)→secured/ping(401 未ログイン→200系Cookie取得後は403=ADMIN限定のため認証は通り role不足で拒否、認証チェーン自体は疎通確認済み)→logout(204, Cookie失効)→secured/ping(401)の一連を curl で確認。IDE警告ゼロ（`compileJava` green、起動ログにも想定外WARN無し）。

### 実装中に見つけたバグ修正（#18 スコープ内で対応）

`GlobalExceptionHandler` に `HttpRequestMethodNotSupportedException` 専用ハンドラが無く、GET等の未マッピングメソッドへのアクセスが `Exception` の catch-all に落ちて 500 に丸められていた（AC-neg2 の 405 期待値と不整合）。専用ハンドラを追加し 405 に正規化するよう修正（このバグは #18 の新規テストで顕在化したため #18 コミットに含めた）。

### 実装中に見つけた既存(#23)の挙動・フロント(#24)への申し送り事項

CSRF（`XSRF-TOKEN`）Cookieは、状態変更（非GET）リクエストが成功するたびにサーバー側で失効し、次のGETリクエストで新しいトークンが再発行される（consume-then-regenerate。手動 curl 検証で確認。`/api/auth/refresh`(#23) でも同一現象を確認済みのため #18/#19 で新規に混入したものではない）。SPA実装（#24）側は、連続してPOST/PUT/DELETEする場合に毎回最新の `XSRF-TOKEN` Cookie値をヘッダへ載せる、または各POST前にGETでトークンを再取得する設計が必要。#24 の実装時に要考慮（本 Sprint のスコープ外のため今回は対応しない）。
