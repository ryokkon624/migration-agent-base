# 挙動 spec — アカウントドメイン（Account & Profile）

> Phase 2 spec ドラフト（round01 未レビュー）。`legacy-jpetstore`（Struts 稼働構成）as-is。横断NFR: [`security-baseline.md`](../security-baseline.md)。認証は [`auth.md`](./auth.md)（E5）と密結合。
> 参照 legacy: `web/struts/{NewAccountAction, NewAccountFormAction, EditAccountAction, EditAccountFormAction, AccountActionForm}.java` / `domain/Account.java` / `domain/logic/PetStoreImpl.java` / `dao/ibatis/maps/Account.xml` / `jsp/struts/{NewAccountForm,EditAccountForm,IncludeAccountFields}.jsp` / `db/hsqldb`（account, signon, profile, bannerdata）
> ※ `AccountValidator.java` は存在せず、入力検証は `AccountActionForm.doValidate` に実装。

## 1. 概要・認証境界

ユーザー登録（新規）・アカウント/プロフィール編集。データは **account / signon / profile** の3表に分かれ、`favcategory` 経由で bannerdata を参照。
- **公開**：新規登録 `/shop/newAccount`・`/shop/newAccountForm`（`BaseAction`）。
- **要サインオン**：編集 `/shop/editAccount`・`/shop/editAccountForm`（`SecureBaseAction`）。

## 2. as-is 挙動

- **登録** `/shop/newAccount`（`NewAccountAction`）：`validate=="newAccount"` のとき、`account.listOption/bannerOption` をパラメータ有無で設定 → `insertAccount(account)`（account＋signon＋profile の3表 insert）→ `getAccount(username)` を session `accountForm` に格納 → index。検証NG時は failure。
- **編集** `/shop/editAccount`（`EditAccountAction`, 要サインオン）：`validate=="editAccount"` のとき、listOption/bannerOption 設定 → `updateAccount(account)`（account＋profile を update、**signon(password) は password 入力時のみ** update・空なら据え置き＝`SqlMapAccountDao.java:48-50`）→ 再取得 → session 更新。
- **フォーム初期化** `newAccountForm`/`editAccountForm`（`*FormAction`）→ 各 JSP。編集は session の `workingAccountForm` を使う。
- 入力検証（`AccountActionForm.doValidate`）：新規は username・password==repeatedPassword・氏名/email/phone/住所 各必須、status="OK" を設定。編集は password 入力時のみ一致チェック。※検証は**非空＋PW一致のみ**（email 形式・最大長・PW 強度は**未検証**＝as-is）。

## 3. 業務ルール

- **3表構成**：`insertAccount`＝account/signon/profile を各 insert（`Account.xml:87-105`、`SqlMapAccountDao`）。`updateAccount`＝account/profile/**signon(password)** を update。username(userid) が全表の結合キー。
- listOption/bannerOption は**パラメータの有無**で真偽化（`NewAccountAction:18-19`）。`favouriteCategoryId` から MyList（おすすめ商品）を構築。
- 登録直後に自動ログイン状態（session `accountForm` セット）。
- **SQL は全てパラメタライズ**（`#username#` 等）＝SQLi なし。

## 4. データモデル（as-is）

- `signon`（username PK, **password varchar(25)＝平文**）
- `account`（userid PK, email, firstname, lastname, status, addr1/2, city, state, zip, country, phone）
- `profile`（userid PK, langpref, favcategory, mylistopt, banneropt）
- `bannerdata`（favcategory, bannername）

⚠ **取得の結合リスク**：`getAccountByUsername` / `getAccountByUsernameAndPassword` は上記4表を **INNER JOIN**（`profile.favcategory = bannerdata.favcategory`, `Account.xml:45-50,71-77`）→ **該当 favcategory の bannerdata 行が無いと account/ログイン取得が null**（＝ログイン失敗・プロフィール取得不能）。bannerdata 廃止（§6 論点①）時は **LEFT JOIN 化 or バナー取得のクエリ分離が必須**（さもなくばログイン破壊）。
⚠ **移行メモ**：`signon.password varchar(25)` はハッシュ格納に不足 → Flyway 移行で列拡張（例 `varchar(255)`）（SBD-5）。

## 5. secure-by-default 要件（before findings → after）

| before | as-is | after（secure-by-default）| SBD |
| --- | --- | --- | --- |
| **S2/R3 editAccount 乗っ取り** | `account.username` がフォーム束縛で、`updateAccount … where userid=#username#`＋`updateSignon(password)` により**他人アカウントを更新＋PWリセット** | 更新対象は**認証プリンシパル本人に固定**（username をクライアントから受けない）。マスアサインメント allowlist。 | SBD-1, SBD-2 |
| **S6 PW変更の再認証欠如** | 現在PW未確認で新PW上書き | パスワード変更は**現在PW確認/再認証必須** | SBD-16 |
| **S3 identity-rebind** | 認可/本人性が再populateされる `accountForm.account.username` 由来 | 本人性は認証プリンシパルから | SBD-1 |
| **S7/R5 平文パスワード** | signon.password を平文保存・平文比較（→ auth.md） | ハッシュ＋ソルト保存 | SBD-5 |
| **S12/R14 登録のユーザ名列挙** | 登録重複エラーで存在推測（ログイン本体は clean） | **レート制限＋メール検証**（登録の一律メッセージ化は非現実的） | SBD-6 |
| **S5 CSRF（要接続）** | 状態変更（newAccount/editAccount/PW変更）に CSRF 対策なし＝before Top3 #3「CSRF 駆動の遠隔乗っ取り(S5+S2+S6)」の起点＝editAccount | 状態変更に CSRF トークン・非冪等 POST | SBD-3 |
| **S8 登録の自動ログイン** | 登録直後の自動ログインでセッション再生成なし | 登録/ログイン時にセッション再生成 | SBD-4 |
| **XSS seam（bannerName）** | `IncludeBanner.jsp:7` が `account.bannerName`（HTML）を `escapeXml=false` 描画（catalog の description と同型） | bannerName の HTML も**継承せず**（バナーは新 UI・新規画像で再設計）＝全エスケープ | SBD-18 |
| **clean 維持（SQLi）** | 全パラメタライズ | 維持 | SBD-17 |

> newAccount で他人 username を指定しても account PK 衝突で **insert 失敗＝上書き不可（before で clean 確認済）**。乗っ取りベクトルは editAccount（update）。

## 6. スコープ（Factory 方針）

- **挙動等価で残す**：登録・編集・プロフィール（言語/おすすめカテゴリ/リスト・バナー設定）。
- **変える（モダン化）**：3表 CRUD を MyBatis に、更新対象を**本人固定**、パスワードは**ハッシュ**、PW変更は**現在PW確認**。JSP→Vue3 SPA＋REST。
- **決定（2026-08-10）**：**bannerdata/バナー・MyList は廃止** → login/account 取得クエリから **bannerdata を除外**（INNER JOIN 依存が解消）。`favouriteCategoryId` は任意のプロフィール設定として残す（バナー/リスト表示はしない）。`bannerName` seam も消滅。
- **PO へ送る論点**：①status 列（"OK"）の運用 ②言語設定(english/japanese)の扱い ③**入力検証の範囲**（email 形式・最大長・PW 強度＝as-is は非空＋一致のみ）。
