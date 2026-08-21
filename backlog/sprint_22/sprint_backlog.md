# Sprint 22 バックログ

- **期間**: 2026-08-21 〜
- **スプリントゴール**: **L2 パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、未踏として名指しされている分岐を実際に踏んで、ゲート値を再合意する。**
- **対象 Issue**: `ryokkon624/jpetstore-manage#51`（5SP・label: `foundation`・Ready）
- **ブランチ**: `feature/51-l2-parity-account-orders`（`jpetstore-backend`・**新規**／`main` = `cb860a4` から分岐）
- **リポジトリ**: `jpetstore-backend` の **test スコープ単独**（＋ `migration-agent-base` のレポート・spec 更新）。**cross-repo なし**。`legacy-jpetstore` は**起動のみ・無改変**。

| Issue | タイトル | SP | ラベル |
| --- | --- | --- | --- |
| #51 | [L2] パリティのシナリオをアカウント系（W4/W5）・注文履歴照会へ広げ、ゲート値を引き上げる | 5 | foundation |

---

# Issue #51 本文（全文転記）

## ユーザーストーリー

**As a** JPetStore 移行のステークホルダー（および PO/SM）
**I want to** L2 パリティのシナリオを**アカウント系（登録・編集）と注文履歴照会**まで広げたい
**So that** 現状ゲート値（BRANCH 16/34）で未踏として名指しされている分岐を実際に踏み、「保存すべき業務ロジックを踏めている」範囲を説明可能な形で広げられる

## トレース

- **前提 Story**: #48（基盤・先例規約）／#49（横展開）／#50（計測とゲート値合意）— **いずれも Sprint 21 で完了**
- **設計**: `spec/l2-parity-design.md` §2（シナリオ台帳）・§6-2（アカウント系は次イテレーション）・§4.4（ループとゲート）
- **実測レポート**: `reports/after/l2-parity-coverage.md` §3（到達不能分岐の除外）・§4（次に足すべきシナリオ）・§5（PO 合意ゲート値）
- **意図差分台帳**: `spec/intended-diff-ledger.md` **ID-2**（→ 案A で確定・下記 確定2）／**ID-14**（→ R8b の観測点・下記 AC3）／**ID-7**（→ `Account` の未踏4分岐・下記 確定3-④）
- **実行環境の制約**: `.claude/rules/database.md`「**R__ は Testcontainers ベースの自動テスト実行経路に届かない**」節（Sprint 21 Retro で追加）→ AC-neg5

本Storyは #48 が確立し #49 が実証した**先例規約に沿った横展開**であり、新しい仕組みは作らない。

---

# Refinement 確定事項（2026-08-21 / NotReady → Ready）

## 確定1: 旧新のアカウント系テーブルの対応づけ

**導出の一次情報源は #13（登録）・#14（アカウント編集）の実装**（`AccountRegistrationCustomMapper.xml` / `AccountEditCustomMapper.xml` / `AccountRegistrationCustomEntity` / `AccountUpdateCustomEntity` / `ProfileRegistrationCustomEntity` / `ProfileUpdateCustomEntity` / `SignonRegistrationCustomEntity`）。**DDL からの再導出はしていない**（二重の分析コストを避けるため・PO 補足のとおり）。

### canonical に含める（比較する）

| canonical | 旧 | 新 | 備考 |
| --- | --- | --- | --- |
| `username` | `account.userid`（=`signon.username`） | `m_account.username` | 旧 `signon.username` が **varchar(25)** ＝実質の上限 |
| `email` | `account.email` | `m_account.email` | |
| `firstName` / `lastName` | `firstname` / `lastname` | `first_name` / `last_name` | |
| `status` | `account.status` | `m_account.status` | 両側とも `"OK"` 固定（旧＝`AccountActionForm` L81／新＝`MyBatisAccountRepository` の `STATUS_OK`） |
| `address1` / `address2` | `addr1` / `addr2` | `address1` / `address2` | |
| `city` / `state` / `country` / `phone` | 同名 | 同名 | |
| `postalCode` | `account.zip` | `m_account.postal_code` | 列名のみ相違 |
| `languagePreference` | `profile.langpref` | `m_profile.language_preference` | |
| `favoriteCategoryId` | `profile.favcategory` | `m_profile.favorite_category_id` | |
| `accountsCreated` | `account` の行数増分 | `m_account` の行数増分 | W1 の `ordersCreated` と同じ「**1件増えた**」比較 |

### 正規化で除外する

| 対象 | 側 | 理由 |
| --- | --- | --- |
| `signon.password` / `m_signon.password_hash` | 両 | **ID-2**（下記 確定2・案A）。代わりに **AC-neg4** で独立検証する |
| `m_account.user_id` | 新 | 代理キー。採番機構が違う（**ID-23** と同じ作法＝識別子の値そのものは比較しない） |
| `version` | 新 | 既存規約（構造列・design §1.2） |
| WHO 6列（`create_user_id`/`create_program`/`created_at`/`update_user_id`/`update_program`/`updated_at`） | 新 | 既存規約（design §1.2） |
| `profile.mylistopt` / `profile.banneropt` | 旧 | **ID-7**（MyList/バナー廃止） |
| `bannerdata.bannername` | 旧 | **ID-7** |
| `m_profile.color_scheme_preference` | 新 | **ID-31**（新規UX・旧に対応概念が存在しない） |

## 確定2: ID-2（平文PW → ハッシュ）は **案A（比較対象外＋新側の独立検証）**

- canonical 比較から `password` / `password_hash` を**除外**する（WHO 列と同じ正規化扱い）。
- **理由**: 平文とハッシュは**値として比較不能**であり、案B（`INTENDED_DIVERGENCE(ID-2)`）にしても「差分がある」としか言えず観測点として機能しない。#48/#49 **Q4 で確定した `divergentFields` 完全一致判定**の枠組みとも整合しない。
- **`spec/intended-diff-ledger.md` の ID-2 への追記は不要**（案A のため）。
- ただし除外しっぱなしにすると資格情報まわりの観測点がゼロになるため、**AC-neg4（新側でのログイン成功／ハッシュ化の独立検証）で担保**する。

## 確定3: Refinement で判明した事実（ドラフト AC の前提の訂正）

### ① `AccountValidator` も `OrderValidator` と同型の到達不能 → AC5 の対象は2クラス

`web.xml` **L134-145** で `petstore`（Spring MVC DispatcherServlet）の `servlet-mapping` が**コメントアウト**されており、`*.do` は Struts の `action` に割り当てられている。両バリデータは `applicationContext.xml` **L42/L45** で bean 定義され**インスタンス化はされる**が、唯一の呼び出し元が `petstore-servlet.xml` **L37/L98/L108** の Spring MVC コントローラであり、**そこへ URL が到達しない**。

→ `reports/after/l2-parity-coverage.md` §3 の「`AccountValidator` はアカウント系シナリオ未実装（W4/W5）のため未踏」という記述は**誤り**。W4/W5 は Struts 経路（`AccountActionForm.doValidate`）を通るため、**シナリオを足しても `AccountValidator` は踏めない**。AC5 でこの記述も併せて訂正する。

> `SendOrderConfirmationEmailAdvice`（一度も生成されない）とは**別型の到達不能**である点に注意：こちらは**生成はされるが `validate()` の呼び出し元が到達不能**。この違いが AC-neg3 に効く（下記③）。

### ② その結果、ドラフトの「INSTRUCTION ≥ 80%」が暫定目標として成立しない

`tools/legacy-jacoco/out2/report/gate/jacoco.csv` の実測から：

| | 分母 | covered | % |
| --- | --- | --- | --- |
| 現行（#50 合意値） | 1588 | 1144 | 72.0% |
| 2クラス除外後（**追加シナリオ0本**） | **1424**（−`OrderValidator` 111・−`AccountValidator` 53） | **1138**（−3・−3） | **79.9%** |

→ ドラフトの「INSTRUCTION ≥ 80%」は**除外による分母縮小だけでほぼ達成**されてしまい、ゲートとして機能しない。**BRANCH 側は影響を受けない**（両バリデータとも総分岐数0）ため「≥ 24/34」は据え置ける。**AC5 と AC7 は同じ判断として扱う**（AC7 に明記）。

### ③ 除外反証チェック（`==0`）をそのまま適用できない

現行の `report.sh` の除外反証チェックは「除外クラスの `INSTRUCTION_COVERED`／`BRANCH_COVERED` が 0 を超えたら fail」。**`OrderValidator`（instruction 3/111）・`AccountValidator`（instruction 3/53）は既にインスタンス化分の被覆を持つ**ため、この `==0` 形では即 fail する。→ AC-neg3 で拡張の形を規定する。

### ④ 未踏分岐の実体が判明 → シナリオの分割が必要（design §4.4「未踏分岐から逆算」）

| 未踏分岐 | 実体（実コードで確認） | 必要なシナリオ |
| --- | --- | --- |
| `SqlMapAccountDao` **4** | `updateAccount()` の `if (account.getPassword() != null && account.getPassword().length() > 0)`（`&&` の2条件×2アウトカム） | **W5 を「PW変更なし」「PW変更あり」の2ケースに分割**。**W4（登録）では1分岐も踏めない** ／ ⚠️ **SM verification で訂正（下記 SM-1）** |
| `SqlMapOrderDao` **2** | `getOrder()` の `if (order != null)` の2アウトカム（残り2の既踏は `insertOrder` の for ループ） | **R8a（存在する注文）と R8b（存在しない orderId）の両方**が必要 |
| `Account` **4** | `getListOptionAsInt()` の `listOption ? 1 : 0` と `getBannerOptionAsInt()` の `bannerOption ? 1 : 0` | **ID-7 由来**（`mylistopt`/`banneropt` を書くためだけの分岐）。→ **PO 判断: 分母に残したまま踏みにいく** |

**`Account` の4分岐についての PO 判断（2026-08-21）**: これらは canonical でも除外する `mylistopt`/`banneropt` を書くためだけの分岐であり、**踏んでもパリティの観測点にはならない（カバレッジ数値のみが動く）**。それでも **分母に残したまま踏みにいく**方針とする。理由＝除外機構は `--classfiles` の**クラス粒度**でしか効かず、クラス内の4分岐だけを手計算で分母から引くと **#50 §5-5 が防ごうとした「手計算の派生値の drift」（「36 vs 34」の取り違え）が再発する**ため。**レポートには「ID-7 由来・カバレッジのみでパリティ観測点ではない」と明記**する（AC7）。

---

## スコープ（未踏分岐から逆算したシナリオ）

| # | シナリオ | 駆動経路（旧 → 新） | 期待 | 対象の未踏分岐 |
| --- | --- | --- | --- | --- |
| 1 | **W4: アカウント新規登録** | `newAccountForm.do` → `newAccount.do` ／ `POST /api/register` | `EQUIVALENT` | `Account` の2アウトカム・`SqlMapAccountDao` の instruction |
| 2 | **W5a: アカウント編集（PW変更なし）** | `editAccountForm.do` → `editAccount.do`（password 空） ／ `PUT /api/account` | `EQUIVALENT` | `SqlMapAccountDao` 4 のうち PW 判定 false 側 |
| 3 | **W5b: アカウント編集（PW変更あり）** | 同上（password あり→`updateSignon` が走る） ／ `PUT /api/account` ＋ `POST /api/account/password`（現PW必須・**ID-13**） | `EQUIVALENT`（比較対象列について。password は確定2により比較対象外） | `SqlMapAccountDao` 4 のうち PW 判定 true 側・`Account` の残2アウトカム |
| 4 | **R7: 注文一覧** | `listOrders.do` ／ `GET /api/orders` | `EQUIVALENT` | `getOrdersByUsername`（分岐寄与なし・instruction 寄与） |
| 5 | **R8a: 注文詳細（自分の注文）** | `viewOrder.do?orderId=<自分の注文>` ／ `GET /api/orders/{orderId}` | ~~`EQUIVALENT`~~ → **`INTENDED_DIVERGENCE(ID-24)`**（Q6 で変更） | `SqlMapOrderDao` の `order != null` **true 側** |
| 6 | **R8b: 注文詳細（存在しない orderId）** | 同上（存在しない ID） ／ 同上 | **`INTENDED_DIVERGENCE(ID-14)`**（新側は **404 ではなく 403**・Q1 で確定） | `SqlMapOrderDao` の `order != null` **false 側** |
| 7 | **カート境界値**（優先度: 最後） | 空カートでの `removeItemFromCart.do` 等 | `EQUIVALENT` | `Cart` の残3・`CartItem` の残1（**名指し10分岐の外**） |

> **R8b が `INTENDED_DIVERGENCE(ID-14)` になる理由**: 旧 `ViewOrderAction` は `getOrder(orderId)` の戻りを null チェックせず `order.getUsername()` を呼ぶため **NPE → 500＋スタックトレース**（ID-14「stale-session/不正 ID で 500＋スタックトレース露出」）。新側は 404。
> なお旧 `ViewOrderAction` は `acctForm.getAccount().getUsername().equals(order.getUsername())` で**所有者チェックをしている**ため、この経路は ID-4（IDOR）の観測点にはならない（ID-4 は remoting / Spring MVC 経路の話）。**ID-4 のシナリオは本Storyのスコープ外**。

---

## Acceptance Criteria

- [ ] **AC1（W4: アカウント新規登録）**: 台帳に `account-register` を追加し、**確定1 の canonical**（＋`accountsCreated`）で `EQUIVALENT` を比較する。フィクスチャは以下の制約を満たすこと（**両側で通る値を1つ選ぶ**）：
  - `favoriteCategoryId` は **`FISH` / `DOGS` / `CATS` / `REPTILES` / `BIRDS` のいずれか**。理由＝旧 `getAccountByUsername` が `bannerdata` と **INNER JOIN** しており（`Account.xml`）、`bannerdata` に無い値だと登録直後の `NewAccountAction` 内 `getAccount()` が null を返す。新側は `m_profile.favorite_category_id` が `m_category` への FK。
  - `username` は **25文字以下**（旧 `signon.username varchar(25)`）
  - `password` は**新側の検証（ID-16: 8文字以上・複数文字種）を満たす値**（旧は「非空かつ再入力一致」のみなので、強い方に合わせれば両側で通る）
  - `email` は新側の形式検証を満たす値
- [ ] **AC2（W5: アカウント編集 — 2ケース）**: **W5a（PW変更なし）**と **W5b（PW変更あり）**の2シナリオを追加する（確定3-④のとおり `SqlMapAccountDao` の未踏4分岐は `updateAccount` の PW 判定に集中しており、1ケースでは全アウトカムを踏めない）。**編集対象は W4 が作ったアカウント**とし、**`j2ee`（`USER_PRIMARY`）は編集も削除もしない**（W1〜W3 が依存するため）。
  - ⚠️ **SM-1 により本 AC は「3ケース」へ更新**（下記「SM verification と計画フェーズ確定事項」参照）
- [ ] **AC3（注文履歴照会 — 3ケース）**: **R7 / R8a / R8b** を追加する（スコープ表のとおり）。**R8b は `INTENDED_DIVERGENCE(ID-14)` として宣言し、`divergentFields` を宣言して Q4 の完全一致判定に載せる**。あわせて **`spec/intended-diff-ledger.md` の ID-14 の「関連Story」欄に本Issue（#51）を追記**する（R8b が ID-14 の観測点になるため。#49 が ID-1 に追記したのと同じ作法）。
- [ ] **AC4（カート境界値）**: `Cart` / `CartItem` の未踏分岐を踏む境界値シナリオを追加する。**優先度は最後**（名指し10分岐の外のため、AC7 の暫定目標には算入しない）。
- [ ] **AC5（`domain.logic` バリデータの配線調査 — 対象は `OrderValidator` と `AccountValidator` の2クラス）**: 実コードで配線状況を確認し、**未配線／呼び出し元が到達不能なら除外対象として `reports/after/l2-parity-coverage.md` に根拠（ファイル名＋行番号）つきで記録**する（#50 §3 と同じ作法）。**シナリオを足して解決しようとしないこと。** 根拠の在り処は確定3-① に先渡し済み（`web.xml` L134-145 ／ `petstore-servlet.xml` L37,L98,L108 ／ `applicationContext.xml` L42,L45）。§3 の `AccountValidator` に関する既存記述（「アカウント系シナリオ未実装のため未踏」）の**訂正も本ACに含む**。**最終的に除外するか否かの判断は AC7 と一体で行う**。
- [ ] **AC6（先例規約の踏襲）**: #48 の canonical モデル・golden スキーマ・コンパレータ・gradle タスクの**仕組みは変更しない**。追加するのは台帳の行・両側 Runner のメソッド・Spec・golden のみ。ただし**アカウント系 canonical は既存 canonical に無い形のため、`ParitySnapshot` へのフィールド追加は可**（仕組みを変えないことと、フィールドを足すことは別）。
- [ ] **AC7（ゲート値の再合意 — AC5 と一体の判断）**:
  - **AC5 の結論（除外する／しない）を反映して分母を確定してから、その分母に対して再合意する。AC5 と AC7 を別々に処理しない**（レポート §5-2「**分母の変更自体が再合意のトリガ**」）。
  - **BRANCH**: 分母は AC5 の結論に**影響されない**（両バリデータとも総分岐数0）。暫定目標は据え置き＝**名指し10分岐（`Account` 4・`SqlMapAccountDao` 4・`SqlMapOrderDao` 2）のうち8以上を踏む＝BRANCH ≥ 24/34（70.6%）**。
  - **INSTRUCTION**: 分母は AC5 の結論に**影響される**（確定3-②）。**ドラフトの「≥ 80%」は暫定目標として取り下げる**（除外だけで 79.9% に達してしまうため）。**実測後に絶対数で再合意**し、%を先に固定しない。
  - **再合意時は (a) 除外による分母縮小の効果 と (b) 追加シナリオによる被覆増の効果 を分離して報告する。除外だけで上がった数値を「カバレッジが向上した」と報告しない。**
  - `Account` の4分岐については「**ID-7 由来・カバレッジのみでパリティ観測点ではない**」とレポートに明記する（確定3-④）。
  - 合意値は #50 と同じく**絶対数を正・%は可読形**とする。
- [ ] **AC8（legacy 不要で走る）**: **legacy を停止した状態で `parityTest` が green**。
- [ ] **AC-neg1（宣言と実測の不一致は失敗）**: `EQUIVALENT` の不一致 → 失敗／`INTENDED_DIVERGENCE` の一致 → 失敗（#48 AC4・#49 AC-neg1 の踏襲）。
- [ ] **AC-neg2（legacy 無改変・後始末）**: 採取のために legacy のソース・WAR・`run/` を変更しない。**アカウント系は書き込みシナリオ**のため、後始末を W3 と同じ規律（#48 AC-neg2）で明記・実施する：
  - **旧**: W4/W5 が作った `account` / `profile` / `signon` の行を採取後に削除して復元する。**`j2ee` の行は編集も削除もしない**。
  - **新**: `m_account` / `m_signon` / `m_profile` の当該行に加え、**`t_register_attempt` / `t_login_attempt`** の当該行も後始末する（**ID-11** の登録・ログインレート制限に再実行で引っかからないため）。既存 `OrderParitySpec` の cleanup と同じ作法。
- [ ] **AC-neg3（除外の機構的担保を壊さない）**: `report.sh` の除外反証チェックを**維持**する。AC5 で `OrderValidator` / `AccountValidator` を除外対象とする場合は、確定3-③ のとおり **現行の `==0` 形をそのまま適用できない**ため、**クラスごとに期待ベースライン（現行実測＝`OrderValidator` instruction 3・`AccountValidator` instruction 3・branch はいずれも 0）を持たせ、それを超えたら fail する形へ拡張**する（＝「呼び出し元が到達不能」という前提が崩れたことを機構的に検知できる状態を保つ）。**ベースライン値は実測を根拠としてレポートに記録**する。**既存3クラス（advice / `MsSqlOrderDao` / `OracleSequenceDao`）の `==0` 検査はそのまま維持**する。
- [ ] **AC-neg4（ID-2 案A の担保 — 新側の独立検証）**: canonical から password を除外する代わりに、**新側で以下を検証**する（旧側には置かない＝旧は平文で自明）。**canonical 比較の外側の独立検証**として置き、**golden には含めない**：
  - W4: 登録した PW で**ログインが成功する**（`POST /api/login` 200）／`m_signon.password_hash` が**平文PWと一致しない**（SBD-5 の証跡）
  - W5b: 変更後の新PWで**ログイン成功**・**旧PWで失敗（401）**
- [ ] **AC-neg5（Testcontainers フィクスチャ前提）**: 新側の実行系は Testcontainers であり、**`R__`（`flyway/sql-test`）は `syncTestSchema` の同期対象外＝自動テスト DB に届かない**（`.claude/rules/database.md`）。したがって**必要なフィクスチャはテスト側で直接 INSERT する**（`R__` を test resources に同期する運用は導入しない）。特に：
  - **`m_profile` も必ず INSERT する**。`AccountEditCustomMapper.findByUserId` が `m_account JOIN m_profile` のため、既存 `OrderParitySpec` のように `m_account` + `m_signon` だけを入れると `GET`/`PUT /api/account` が成立しない。
  - パスワードは `PasswordEncoder#encode` 経由で投入する（既存 `OrderParitySpec` と同作法）。
  - 背景: Sprint 21 の D3（`demo_user` が Testcontainers 経路に存在しないという実行環境の事実誤認）と同型の手戻りを避けるため。

## 備考

- **優先順位の根拠**: #50 の実測で**未踏の到達可能分岐18のうち10が `Account`・`SqlMapAccountDao`・`SqlMapOrderDao` に集中**していることが分かっている。「あと何本必要か」を印象論でなく未踏分岐から名指しできる状態（設計 §4.4 のループ）になったため、次の一手が明確。
- **依存関係**: #48・#49・#50（すべて完了）。cross-repo なし（`jpetstore-backend` の test スコープ単独／legacy は起動のみ・無改変）。
- **スコープ外**: 新側（`jpetstore-backend`）のカバレッジゲート（既存 `jacocoTestReport` の運用を変えない）。CI 昇格（GitHub Actions 未導入のため手動ゲートのまま）。**ID-4（IDOR）のシナリオ**（スコープ表の注記のとおり、Struts の `viewOrder` 経路は所有者チェック済みのため観測点にならない）。
- **DoD 補足**: `parityTest` は `check` に載せない方針（#48 AC11）のため、**明示実行して green であること**を完了条件に含める。カバレッジ計測は `tools/legacy-jacoco/report.sh` で行い、**2本のレポート（AC1 分母／ゲート分母）が出ること・除外反証チェックが pass すること**を確認する。
- **意図差分台帳の更新**: **ID-2 への追記は不要**（確定2・案A）。**ID-14 の「関連Story」欄に #51 を追記する**（AC3）。

---

# SM verification と計画フェーズ確定事項（Sprint 22 Planning・2026-08-21）

> Planning 時に SM が一次データ（`legacy-jpetstore` 実コード／`tools/legacy-jacoco/out2/report/gate/jacoco.csv`／`jpetstore-backend` の Controller 実装）で検算した結果。
> **Refinement の記述と食い違う箇所は以下が正**。DEV は「確定3-④」の文言をそのまま鵜呑みにしないこと。

## SM-1【AC2 の訂正 — W5 は「3ケース」／ユーザー承認済み 2026-08-21】

**確定3-④ の「W5 を2ケースに分割すれば `SqlMapAccountDao` の未踏4分岐を踏める」は成立しない。2ケースでは最大 3/4。**

根拠（一次データ）:

- `SqlMapAccountDao.updateAccount()` の `if (account.getPassword() != null && account.getPassword().length() > 0)` は
  JaCoCo 上 **2分岐 × 2アウトカム = 4**（`gate/jacoco.csv`: `SqlMapAccountDao,51,27,4,0,...` ＝ `BRANCH_MISSED=4`）。
- 4アウトカムの到達には **3通りの入力**が要る:

  | 入力 | 到達するアウトカム |
  | --- | --- |
  | `password == null` | 分岐1-false（1） |
  | `password == ""` | 分岐1-true ＋ 分岐2-false（2） |
  | `password == "<新PW>"` | 分岐2-true（1） |

- `Account.xml` の `getAccountByUsername` の resultMap は **password 列を写さない**（`userid/email/firstname/lastname/status/addr1/addr2/city/state/zip/country/phone/langpref/favcategory/mylistopt/banneropt/bannername` のみ）。
  よって `EditAccountFormAction` が `getPetStore().getAccount(username)` で組んだ session 上の `Account` は **`password == null`**。
- `EditAccountForm.jsp` は `<html:password property="account.password"/>` を描画するため**ブラウザは常に空文字を送る**＝ null 側は通常UI経路では到達しない。
  **`account.password` パラメータ自体を送らない POST** でのみ到達する（パリティ採取ハーネスは直接フォーム POST するため実行可能）。
- ⚠️ `workingAccountForm` は **`scope="session"`**（`struts-config.xml` L31-38）。一度 `account.password` に値が入ると session 上の `Account` に残る。
  **null ケースは `editAccountForm.do` 直後（＝DB から読み直した直後）に実行するか、セッションを分けること。**

**確定（ユーザー承認）: W5 は 3ケース。**

| シナリオID（案） | 旧側の駆動 | 新側 | 期待 | 踏むアウトカム |
| --- | --- | --- | --- | --- |
| `account-edit-nopw`（W5a） | `account.password=`（空文字） | `PUT /api/account` | `EQUIVALENT` | 分岐1-true ＋ 分岐2-false |
| `account-edit-pw`（W5b） | `account.password=<新PW>` | `PUT /api/account` ＋ `POST /api/account/password` | `EQUIVALENT` | 分岐2-true |
| `account-edit-pwfield-absent`（W5c） | `account.password` パラメータを**送らない** | `PUT /api/account`（W5a と同一リクエスト） | `EQUIVALENT` | 分岐1-false |

- **W5c は新側に対応概念が無い**（`PUT /api/account` は password を一切扱わない）ため、新側リクエストは W5a と同一になる。
  → **`Account` の4分岐と同じ「カバレッジ専用・パリティ観測点ではない」扱い**とし、**レポート（AC7）にその旨を明記**する。
- これにより `SqlMapAccountDao` は **4/4** 到達可能。

## SM-2【到達可能な上限の見積り（一次データ）】

`gate/jacoco.csv` の `BRANCH_MISSED` 内訳（未踏18 / ゲート分母34・現行 covered 16）:

| クラス | 未踏 | 本Storyで踏めるか |
| --- | --- | --- |
| `Account` | 4 | ✅ W4（listOption/bannerOption とも false）＋ W5（とも true）で 4 |
| `SqlMapAccountDao` | 4 | ✅ SM-1 の3ケースで 4 |
| `SqlMapOrderDao` | 2 | ✅ R8a（true 側）＋ R8b（false 側） |
| `Cart` | 3 | ⭕ **うち2のみ到達可能**（`removeItemById` の2アウトカム）。`addItem` の false 側は**到達不能**（下記の訂正を参照） |
| `CartItem` | 1 | ❌ **構造的に到達不能**（下記の訂正を参照） |
| `SqlMapItemDao` | 3 | ❌ 本Storyのシナリオでは踏まない |
| `SqlMapSequenceDao` | 1 | ❌ 同上 |

> ⚠️ **【SM 自身の誤りの訂正・2026-08-21／2段階で訂正された】**
> 初出時「理論上限 = 16 + 4 + 4 + 2 + 4 = **30/34**」と書いたが誤り。**最終的に正しいのは 28/34（82.4%）**
> ＝ 16 + `Account` 4 + `SqlMapAccountDao` 4 + `SqlMapOrderDao` 2 + `Cart` **2**。
> **2段階とも DEV が検出し、SM が一次データで確認した**（30 → 29 → 28）。
>
> **訂正1（30→29）: `CartItem` の1分岐は到達不能。** 未踏1分岐は `getTotalPrice()` の `if (item != null)` の
> **false 側**。`CartItem` の唯一の生成箇所は `Cart.java:38` の `new CartItem()` で、直後の L39 が必ず
> `setItem(item)` を呼ぶ（`new CartItem()` は全リポジトリでこの1箇所のみ・`CartItem` 内の `if` もこの1箇所のみ）。
>
> **訂正2（29→28）: `Cart.addItem` の false 側も到達不能。** 呼び出し元の `AddItemToCartAction` が
> `if (cart.containsItemId(workingItemId)) { incrementQuantityByItemId(...) } else { addItem(...) }` と
> **事前ガード**しているため、`addItem` は「カートに無いとき」しか呼ばれず `itemMap.get()` は必ず null。
> よって AC4 で踏めるのは `Cart` の**2のみ**（`removeItemById` の2アウトカム）。
> （もう一方の呼び出し元 `AddItemToCartController` は Spring MVC 経路で `web.xml` の servlet-mapping により
> そもそも到達不能。）
>
> **分母34は据え置く**（クラス粒度の `--classfiles` 除外では `CartItem`/`Cart` を落とせず、クラス内の一部分岐
> だけを手計算で引くと #50 §5-5 が防いだ drift を再導入するため。`Account` 4分岐と同じ判断）。
> レポートには「**到達不能だがクラス粒度では除外できない分岐**」として根拠つきで明記する（Q2 で SM 確定）。

→ **理論上限 = 28/34（82.4%）。実測も 28/34 で、上限にちょうど到達した**（`report.sh` の
`out3/report/gate/jacoco.csv` を SM が独立にパースして確認）。AC7 の暫定目標 **24/34** は達成。
**（この訂正自体が「派生値は書いた側が誰であれ一次データで検算される」＝Sprint 21 の教訓が効いた実例。
初出値を書いたのは SM で、2回とも DEV が反証した。）**

## SM-3【R8b の証拠を「資産として耐久性のある形」で固定する（Sprint 21 所見①の適用）】

Sprint 21 の SM verification 所見①（W3 の ID-1 証拠が golden に固定されておらず、前提が崩れても `parityTest` が green のままだった）と**同型のリスクが R8b にある**。

- ID-14 の中身は「**500 ＋ スタックトレース露出**」。`outcome` だけを canonical に載せると、旧が将来 500 を返さなくなったときに気づけるのは「INTENDED_DIVERGENCE なのに差分ゼロ → fail」（AC-neg1）だけで、**「スタックトレースが露出している」という観測点そのものは資産に残らない**。
- **要件**: 旧側レスポンスの **HTTP ステータス**と**スタックトレース露出の有無**（例: 本文に例外クラス名／`at org.springframework.samples...` フレームが含まれるか）を canonical フィールドとして golden に固定し、`divergentFields` に載せること。
- 自己点検の問い（DEV は各シナリオについてこれに答えること）: **「この前提が満たされなくなったとき、`parityTest` は落ちるか？」** 落ちないなら前提そのものを assert する形に直す。

## SM-4【新側実装の先渡し（`jpetstore-backend` 実コードで確認済み）】

DEV が踏みやすい落とし穴。**Refinement には書かれていない**が実装上必ず当たる。

1. **`PUT /api/account` の `AccountEditRequest` は `colorSchemePreference` が `@NotBlank @Pattern("^(system|light|dark)$")` ＝必須**。
   canonical からは ID-31 で除外するが、**リクエストには値を入れないと 400**。`version` も必須（`GET /api/account` が返した値を往復させる楽観ロックトークン）。
   → W5 の新側は **`GET /api/account` → `PUT /api/account`** の2ステップが必須。
2. **`POST /api/account/password` は成功時にトークンをローテートする**（`AuthApplicationService#issueTokensFor` が `HttpServletResponse` に新 Cookie を書く・`@ResponseStatus(NO_CONTENT)`）。
   → W5b の `NewHttpClient` は **PW 変更後の新 Cookie を拾い直さないと以降のリクエストが 401 になる**。`PUT` を先・`POST /password` を後にする順序が安全。
3. **`POST /api/register` は成功時に自動ログインする**（201 ＋ fresh JWT Cookie）。W4 の直後は**新規ユーザーとしてログイン済み**なので、W5 の前に別途ログインし直す必要はない。
4. `RegisterRequest` は `languagePreference`（`@Size(max=80)`・任意）と `favoriteCategoryId`（`@Size(max=10)`・任意）を**受理する**。canonical のこの2列は W4 で比較可能。
5. `AccountEditRequest.address2` は `@Size(max=40)`（`m_account.address2` 由来）。旧 `account.addr2` との**列幅の非対称**に注意（フィクスチャは 40 文字以下に収める）。
6. `GET /api/orders` は **1-index ページング・既定 size=12・cap=100**（`PageResponse`）。旧 `listOrders.do` は全件返す。
   → design §2 の読み取り系規約どおり **全ページを辿ってから集合比較**すること（ID-20・F5 の踏襲）。

## SM-5【旧側の駆動で確認済みの事実】

- `NewAccountAction` / `EditAccountAction` はいずれも `request.getParameter("account.listOption") != null` で boolean を決める
  ＝ **チェックボックスのパラメータを送らなければ false・送れば true**。`Account` の4アウトカムはこれで制御する。
- `newAccount.do` / `editAccount.do` は `validate` パラメータ（`newAccount` / `editAccount`）が一致しないと **failure forward** に落ちる（`AccountActionForm.VALIDATE_NEW_ACCOUNT` / `VALIDATE_EDIT_ACCOUNT`）。
- `AccountActionForm.doValidate` の必須項目: `account.username`（新規時）・`firstName`・`lastName`・`email`・`phone`・`address1`・`city`・`state`・`zip`・`country`。
  新規時は `password` 非空 かつ `repeatedPassword` 一致 が必須。編集時は password 非空のときのみ一致チェック。
- `listOrders.do` / `viewOrder.do` は **`accountForm`（session）** を使い `SecureBaseAction` 配下＝**サインオン済みセッションが前提**。
- `ViewOrderAction` は `getOrder()` の戻りを null チェックせず `order.getUsername()` を呼ぶ → **NPE**（R8b の ID-14 経路。確認済み）。

## SM-6【環境メモ（ユーザー指示）】

- legacy イメージ `jpetstore-legacy` は**無改変で維持**。計測用 overlay は `jpetstore-legacy-jacoco`。手順は `tools/legacy-jacoco/README.md`。
- **採取用 legacy は別ポートで起動する**（新 backend と 8080 が衝突するため）。
- **JaCoCo は `docker stop -t 30` の graceful 停止**でないと exec が書かれず計測が消える（Sprint 21 と同じ）。

## SM-7【計画フェーズ Q1〜Q7 の確定（2026-08-21）】

DEV の計画フェーズで挙がった論点。**全件決着済み。実装フェーズは再質問しない。**
DEV の詳細方針は `memory/dev/short_term.md` §1〜§13。

| # | 確定回答 | 判断者 |
| --- | --- | --- |
| Q1 | R8b は **`INTENDED_DIVERGENCE(ID-14)` のまま**。台帳 ID-14 に「注文詳細経路は ID-4 と重畳して 403」の注記＋関連Story に #51 を追記 | ユーザー |
| Q2 | 到達可能上限 **29/34** を根拠つきでレポートに明記。**分母34は据え置き** | SM |
| Q3 | W5 は**自己完結方式**（`parity_w5a/b/c` を各自登録・各自削除）。`j2ee` は不変 | ユーザー |
| Q4 | `report.sh` は **3本出し**（`ac1`/`gate`=3除外/`gate-v2`=5除外）。DoD の「2本」は部分集合として充足 | SM |
| Q5 | AC-neg3 のベースライン判定は **`!=` で fail**（増＝前提崩壊／減＝bean 定義の変化 をメッセージで区別） | SM |
| Q6 | `orderDate` は正規化除外で可。**`productName` は除外せず R8a を `INTENDED_DIVERGENCE(ID-24)` の観測点にする**。AC-neg4 の実パスは **`/api/auth/login`**（`/api/login` は Issue 本文の誤り） | orderDate=SM／productName=ユーザー |
| Q7 | `spec/l2-parity-design.md` §2 台帳への追加・§6 未決事項2 の解決反映を**本スプリントに含める** | SM |

### Q1 に伴う訂正（Issue 本文の誤り・SM が一次データで確認）

**スコープ表の「R8b の新側は 404」は成立しない。実際は 403。**
`OrderApplicationService.getOrder` が `findHeaderById(...).orElseThrow(() -> new AccessDeniedException(...))` で
**不存在・非所有を同一例外**にし、`GlobalExceptionHandler.java:102-108` が
`build(HttpStatus.FORBIDDEN, "FORBIDDEN", "Access is denied", request)` へ正規化する（ID-4/SBD-8 の列挙封じ）。
ID-14 の趣旨（旧＝500＋スタックトレース露出 → 新＝露出なし）は 403 でも成立するため期待は据え置く。
副次: この 403 は `recordAuthzFailure` が `t_audit_log` を1行書くため**後始末対象に追加**（AC-neg2）。

### Q6 に伴う派生タスク

- `intended-diff-ledger.md` の **ID-24 の関連Story にも #51 を追記**（ID-14 と同じ作法）。
- **SM-3 を R8a にも適用**: 「旧の注文詳細で `productName` が空」という前提を**採取時 assert し、
  満たさなければ golden を書き出さず fail**。（旧の根拠＝`dao/ibatis/maps/LineItem.xml` の
  `getLineItemsByOrderId` が `LineItem.item` を一切埋めないため `ViewOrder.jsp` の description セルが空になる。）
- **R8a が `EQUIVALENT` だという Issue スコープ表からの意図的な逸脱**である点は、
  **Sprint Review の AC 達成状況で SM が PO へ明示報告**する。

### Q3 に伴う注意

`t_register_attempt` は **PK=`client_ip`・5回/15分・成功時リセット無し**（`V00_000_012__create_register_attempt.sql:35`）。
自己完結方式では W4＋W5a/b/c で**同一IPから4回**登録するため上限5に肉薄する。`setup()` の全行 DELETE に加え、
**429 を受けたら「レート制限に当たった」と分かるメッセージで fail** させる（黙って落ちると切り分けに時間を取られる）。

### その他 DEV が実コードで拾った訂正

- **AC-neg4 の `POST /api/login` は誤り。実パスは `POST /api/auth/login`**（`AuthController` の `@RequestMapping("/api/auth")` ＋ `@PostMapping("/login")`）。
- 旧側フォームのパラメータ名は **`account.favouriteCategoryId`（英国綴り）**。canonical 名（`favoriteCategoryId`）と綴りが違う。

---

# タスク分割（SM 案・DEV は計画フェーズで調整可）

| # | タスク | 対応 AC | 備考 |
| --- | --- | --- | --- |
| T1 | アカウント系 canonical の `ParitySnapshot` 拡張＋台帳3行（W4/W5a/W5b）＋W5c | AC1・AC2(SM-1)・AC6 | フィールド追加は可（AC6）。Testcontainers フィクスチャは `m_profile` 込み（AC-neg5） |
| T2 | 注文履歴照会 R7 / R8a / R8b ＋ ID-14 台帳追記 | AC3・SM-3 | R8b の証拠固定化（SM-3）を必ず入れる |
| T3 | AC-neg4（新側の PW 独立検証）＋ AC-neg2（両側の後始末） | AC-neg2・AC-neg4 | `t_register_attempt`/`t_login_attempt` の後始末を忘れない（ID-11） |
| T4 | カート境界値シナリオ | AC4 | **優先度は最後** |
| T5 | AC5 配線調査（2クラス）＋ AC-neg3 の除外反証チェック拡張 | AC5・AC-neg3 | 既存3クラスの `==0` は維持。2クラスはベースライン方式 |
| T6 | legacy 再採取（overlay・別ポート・graceful stop）＋ `report.sh` 実行＋レポート更新＋**AC7 のゲート値再合意案の提示** | AC7・AC8 | **AC5 と AC7 は一体**。(a) 除外効果 と (b) 追加シナリオ効果 を**分離して**報告 |

---

# 完了条件（DoD）

1. **legacy を停止した状態**で `./gradlew parityTest` を**明示実行して green**（AC8）。
2. `tools/legacy-jacoco/report.sh` が **2本のレポート（AC1 分母 `ac1/` ／ ゲート分母 `gate/`）を出力**する。
3. **除外反証チェックが pass** する（既存3クラス `==0` ＋ AC5 で除外した2クラスのベースライン方式・AC-neg3）。
4. `reports/after/l2-parity-coverage.md` が更新され、以下が明記されている:
   - AC5 の結論と根拠（ファイル名＋行番号）／§3 の `AccountValidator` 記述の訂正
   - **(a) 除外による分母縮小の効果 と (b) 追加シナリオによる被覆増の効果の分離**（AC7）
   - `Account` の4分岐・W5c が「ID-7 由来・カバレッジのみでパリティ観測点ではない」こと
   - AC-neg3 のベースライン値の実測根拠
5. **ゲート値を実測に基づいて PO と再合意**し、レポート §5 に記録（**数値を先に決めない**）。
6. `spec/intended-diff-ledger.md` の **ID-14 の「関連Story」に #51 を追記**（AC3）。
7. legacy が**無改変**であること・両側の**後始末が完了**していること（AC-neg2）。

---

# リスク・チャレンジ

| # | 内容 | 対応 |
| --- | --- | --- |
| R1 | **AC5 と AC7 を別々に処理してしまう**（分母が動くため成立しない） | T5 と T6 を同一タスク束として扱う。レポートで効果を分離して報告することを DoD に明記 |
| R2 | **除外だけで上がった数値を「カバレッジが向上した」と報告**してしまう | AC7 に厳格な要求あり。SM が Sprint Review 前に一次データ（`gate/jacoco.csv`）で検算する |
| R3 | Testcontainers に `R__` が届かず `GET/PUT /api/account` が 500/404 になる | AC-neg5・**`m_profile` 必須**を先渡し済み |
| R4 | `t_register_attempt`/`t_login_attempt` の後始末漏れで再実行時に ID-11 のレート制限に阻まれる | AC-neg2 に明記・T3 |
| R5 | `docker stop` を graceful にせず JaCoCo exec が書かれない | SM-6・Sprint 21 と同じ |
| R6 | 採取用 legacy と新 backend の 8080 衝突 | 別ポート起動（SM-6） |
| R7 | `workingAccountForm` が session scope のため W5c（null）が W5a/W5b の後だと再現しない | SM-1 に明記（`editAccountForm.do` 直後に実行 or セッション分離） |
| R8 | `POST /api/account/password` のトークンローテーションで以降 401 | SM-4-2（`PUT` を先・`POST /password` を後） |
| C1 | **チャレンジ**: 本Storyは「未踏分岐から逆算 → シナリオ化 → 実測 → 再合意」という design §4.4 のループを**2周目**として回す初回。ループが機構として回ることを実証する | — |
