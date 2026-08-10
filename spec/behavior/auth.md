# 挙動 spec — 認証ドメイン（Auth / Signon）

> Phase 2 spec ドラフト（round01 未レビュー）。`legacy-jpetstore`（Struts 稼働構成）as-is。横断NFR: [`security-baseline.md`](../security-baseline.md)。[`account.md`](./account.md)（E4）と密結合。
> 参照 legacy: `web/struts/{SignonAction, SecureBaseAction, BaseAction, AccountActionForm}.java` / `domain/logic/PetStoreImpl.java` / `dao/ibatis/maps/Account.xml`（getAccountByUsernameAndPassword, updateSignon）/ `jsp/struts/SignonForm.jsp` / `db/hsqldb`（signon）

## 1. 概要・認証境界

サインオン／サインオフ、および**保護アクションのゲート**（`SecureBaseAction`）。認証済み identity（session `accountForm`）が、注文・編集・履歴の認可の土台になる（＝本ドメインの完全性が全 Epic の前提）。

## 2. as-is 挙動

- **サインオン** `/shop/signon`（`SignonAction`, 公開）：まず session の `workingAccountForm`/`accountForm` を除去。`signoff` パラメータ有り → **`session.invalidate()`**（＝サインオフ）。無し → `username`/`password`（`AccountActionForm`）で `getAccount(username, password)` → null なら「Invalid username or password. Signon failed.」（**成否一律メッセージ＝ユーザ列挙 clean**。ただし失敗は global-forward `failure`→`Error.jsp` へ遷移し、SignonForm には戻らない＝`SignonAction.java:27-29`, `struts-config.xml:17`）→ 成功時は新 `AccountActionForm` を作り `account` セット・**`account.setPassword(null)`**（session にPWを残さない）・session に `accountForm` セット。
- **サインオン後遷移**：`forwardAction` が空 → index、非空 → **`response.sendRedirect(forwardAction)`**。
- **保護ゲート** `SecureBaseAction`：session に `accountForm.account` が無ければ、要求URL(＋query)を `signonForwardAction` に退避してサインオン画面へ誘導。

## 3. 業務ルール

- 認証は `getAccountByUsernameAndPassword`：`where account.userid=#username# and signon.password=#password#`（`Account.xml:52-77`）＝**平文パスワードの直接比較**。SQL はパラメタライズ（SQLi なし）。
- 成功時の identity は session `accountForm`。PW は session に保持しない（`setPassword(null)`）。
- サインオフは `signon.do?signoff=...` で `session.invalidate()`（専用アクションは無い）。
- ログインフォーム（`SignonForm.jsp`）は**既定資格情報 j2ee/j2ee をプリフィル**。

## 4. データモデル（as-is）

`signon`（username PK, **password varchar(25)＝平文**）。認証は signon×account×profile×**bannerdata** の結合で account を取得。
⚠ **重大な結合**：認証クエリ `getAccountByUsernameAndPassword` は bannerdata と **INNER JOIN**（`profile.favcategory = bannerdata.favcategory`, `Account.xml:71-77`）＝**該当 favcategory の bannerdata 行が無いと account 取得が null＝ログイン失敗**。bannerdata 廃止（account.md 論点①）時は **LEFT JOIN 化 or バナー取得のクエリ分離が必須**（さもなくばログイン破壊）。
⚠ **移行メモ**：`password varchar(25)` はハッシュ格納に不足 → Flyway 移行で列拡張（例 `varchar(255)`）（SBD-5）。

## 5. secure-by-default 要件（before findings → after）

| before | as-is | after（secure-by-default）| SBD |
| --- | --- | --- | --- |
| **S7/R5 平文パスワード** | signon.password 平文保存・平文比較 | **ハッシュ＋ソルト**（bcrypt/argon2）で保存・照合 | SBD-5 |
| **S8/R7 セッション固定** | ログイン成功時に session を再生成しない（invalidate は signoff のみ） | ログイン成功時に**セッションID 再生成**、signoff で無効化 | SBD-4 |
| **S9/R11 オープンリダイレクト** | `sendRedirect(forwardAction)` を無検証（認証成功時のみ発火＝フィッシング補助） | リダイレクト先は**allowlist/相対のみ** | SBD-9 |
| **S10/R10 ブルートフォース＋弱い既定資格情報** | レート制限/ロックアウト無し・j2ee/j2ee プリフィル | レート制限/ロックアウト、既定資格情報のプリフィル廃止 | SBD-6 |
| **S11/R13 資格情報を GET でも受理** | getParameter ＝メソッド非依存 | 資格情報は POST body のみ | SBD-6 |
| **S5/R6 CSRF** | 状態変更に CSRF 対策なし（ログイン/ログアウト含む） | CSRF トークン・状態変更は非冪等 POST | SBD-3 |
| **clean 維持** | ログイン失敗は一律メッセージ（列挙不可）・SQL パラメタライズ | 維持（列挙不可・SQLi無） | SBD-6, SBD-17 |

> **本ドメインは全 Epic の認可の土台**：identity の完全性（S2/S3 で汚染されない）が注文・編集の認可前提。SBD-1（プリンシパル基準の認可）と一体で担保する。

## 6. スコープ（Factory 方針）

- **挙動等価で残す**：サインオン/サインオフ、保護アクションのサインオン誘導（＋元URL復帰）。
- **変える（モダン化）**：平文PW→ハッシュ、ログイン時セッション再生成、リダイレクト検証、レート制限、既定資格情報プリフィル廃止、GET認証廃止。認証機構は Spring Security 等の標準に載せ替え（session `accountForm` 手組み→標準の認証プリンシパル）。JSP→Vue3 SPA＋REST（トークン/セッション方式は E6 で決定）。
- **PO へ送る論点**：①認証方式（セッション or JWT 等）②「元URL復帰」UX の踏襲 ③多言語ログイン画面の扱い。
