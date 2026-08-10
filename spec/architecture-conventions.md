# architecture-conventions — モダン版 JPetStore 横断アーキ規約

> HwHub のアーキを**基本踏襲**しつつ、モダン版 JPetStore 向けに**差分を決定**した横断規約。
> PO は Story/AC 作成時、DB を伴う機能は本書の §2〜§3 を参照する。DEV（Phase 3）は本書を実装既定とする。
> 関連: [`security-baseline.md`](./security-baseline.md)（SBD-14 監査ログは本書 §2 の WHO カラムで担保）、[`backlog-map.md`](./backlog-map.md)。

## 決定ログ（要点）

| # | 決定 | HwHub との差分 |
| --- | --- | --- |
| **D1** | リポジトリは **polyrepo 3本**（frontend / backend / database）。batch・mobile はスコープ外、infra は将来 | 7 repo → 3 repo に縮約 |
| **D2** | WHO カラムは**残す**。機能識別子は `ProgramType` enum を**廃止**し **`ClassName#method` テキスト**に | enum/コード管理を廃止 |
| **D3** | WHO カラムは **AOP＋MyBatis Interceptor で自動付与**（最外の業務サービスが勝つ） | 各 Service の手渡しを廃止 |
| **D4** | 区分値 `m_code` は**残す**。多言語は**日英のみ**（`display_name_es` 列を廃止） | es 列を削除 |
| **D5** | enum 生成は **TS（database）・Java（backend）とも既存ジェネレータを流用**、entity/mapper は MyBatis Generator を流用。**Dart 生成は廃止**、`0012`(ProgramType) は生成対象外 | Dart 出力・0012 生成を廃止 |

---

## 1. リポジトリ構成（D1）

polyrepo。GitHub 作成はりょこさん、ローカル雛形は別途用意。

| repo | 役割 | 主要技術 |
| --- | --- | --- |
| **jpetstore-frontend** | SPA | Vue 3 / TypeScript / Pinia / Vite |
| **jpetstore-backend** | REST API | Java 21 / Spring Boot 4.x / MyBatis / MySQL 8.4 |
| **jpetstore-database** | スキーマ・マスタ・生成 | Flyway / MyBatis Generator / m_code→TS enum 生成 |

- **スコープ外**: batch（バッチ処理なし）・mobile（Web のみ）。**infra** は将来（Terraform/Compose）。当面の Docker Compose は database repo 直下に置く。
- **生成成果物フロー**: `jpetstore-database`（m_code）→ `MultiEnumGenerator` で TS 定数を生成 → `jpetstore-frontend` に取り込み。Java 側は entity/mapper を MyBatis Generator で生成、区分値 enum は backend に手書き。

> 命名は `legacy-jpetstore`（before）に対する `jpetstore-*`（after）。before↔after が名前で対比できる。

---

## 2. WHO カラム規約（D2・D3）

### 2.1 列定義（全業務テーブル共通ボイラープレート）

```sql
  , create_user_id BIGINT UNSIGNED NULL      COMMENT '作成者ユーザID'
  , create_program VARCHAR(100)    NOT NULL  COMMENT '作成機能(ClassName#method)'
  , created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '作成日時'
  , update_user_id BIGINT UNSIGNED NULL      COMMENT '更新者ユーザID'
  , update_program VARCHAR(100)    NOT NULL  COMMENT '更新機能(ClassName#method)'
  , updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                    ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時'
```

- `create_program` / `update_program` は **`ProgramType` enum を廃止**し、**論理機能名テキスト**（`ClassName#method`、例 `OrderService#placeOrder`）を格納。**m_code `0012` は作らない**。
- `create_user_id` / `update_user_id` は認証プリンシパル（SecurityContext）から取得（未認証操作は NULL 許容）。SBD-1/SBD-14 と整合。

### 2.2 自動付与ルール（set-once・最外の業務サービスが勝つ）

「共通サービスが INSERT しても、**それを呼び出した業務サービス名**を記録する」要件を満たすため、**最外の業務サービスが勝つ** set-once 方式を採る。

1. **AOP `@Around`**（サービス層 `..application.service..` を pointcut）
   - enter: `ProgramContext`(ThreadLocal) が**空なら** `SimpleClassName#method` をセットし「owner」を記憶。**既に入っていれば触らない**。
   - exit: owner のみ ThreadLocal をクリア（finally）。
2. **MyBatis `Interceptor`**（`Executor#update` を intercept）
   - INSERT/UPDATE 実行時、対象エンティティの `create_program`/`update_program` が**未設定なら** ThreadLocal の値で補完。既に明示設定があれば尊重。

これにより `OrderService#placeOrder` → `CommonWriteService.insert()` と潜っても、記録は**最外の `OrderService#placeOrder`**（＝機能の入口）になる。共通サービス名にはならない。

- **例外**: 共通サービスをコントローラが直接呼ぶ（業務サービスで包まれない）場合は、その共通サービスが最外＝記録対象になる（他に帰属先が無いため許容）。
- 原則 **Interceptor 任せ**（Service は WHO 値を手渡さない）。特殊ケースのみ明示 set を許可。

### 2.3 テーブル追加手順の新旧比較（摩擦の解消）

| 手順 | 旧（HwHub） | 新（本規約） |
| --- | --- | --- |
| テーブル定義＋WHO列 | ✔ | ✔（WHO列は固定ボイラープレート） |
| m_code `0012` に1行 INSERT | 必要 | **不要** |
| `ProgramType` enum に定数追加 | 必要 | **不要** |
| 各 mapper 呼び出しに `getCode()` 手渡し | 必要 | **不要**（Interceptor 自動） |

→ 新機能追加時の**三重管理（enum＋m_code＋手渡し）が消える**。

---

## 3. 区分値（m_code）と enum 生成（D4・D5）

### 3.1 m_code

- HwHub の `m_code` を踏襲（`code_type` 4桁 + `code_value` + 表示名）。
- **多言語は日英のみ** → 列は `display_name_ja` / `display_name_en`。**`display_name_es` は廃止**。
- 対象は**本物のドメイン区分のみ**（例: 注文ステータス・カード種別・在庫ステータス 等。確定は PO/仕様で）。**`0012`(ProgramType) は §2 で廃止のため作らない**。

### 3.2 生成ツール（流用の実態）

| ツール | 出所 | 本プロジェクトでの扱い |
| --- | --- | --- |
| **MultiEnumGenerator**（m_code→TS[＋Dart]） | hw-hub-**database** | **流用**。**Dart 出力（generateMobile）を削除**し TS のみに。`display_name_es` は元々不参照。出力は `build/generated/frontend/`（成果物）→ frontend へ |
| **EnumGenerator**（m_code→Java enum） | hw-hub-**backend** | **流用**（`./gradlew generateEnums`）。`code_type_name_en`→クラス名、`display_name_en`→定数、`code_value`→`getCode()`＋`fromCode()`、`CodeEnum` 実装。出力は `domain/enums/*.java` の**ソースツリー直下（コミット対象）**。`display_name_es` は元々不参照 |
| **MyBatis Generator**（スキーマ→entity/mapper） | hw-hub-**backend** | **流用**（設定移植） |

> 補足:
> - **domain/enums の enum 群は"生成物"**（EnumGenerator 出力）であり手書きではない。区分値を足す＝m_code に登録 →`generateEnums` 再実行、で TS/Java 両方が更新される。
> - 2ジェネレータとも **`display_name_es` を参照しない**ため、m_code から es 列を削除しても両生成は無影響。
> - `0012`(ProgramType) を廃止（§2）＝その code_type が存在しない → ProgramType enum も生成されない（WHO はテキスト自動付与）。
> - 移植時に変更するのは主に **JDBC 接続情報（DB 名 `jpetstore` 等）・パッケージ名・出力先パス**。

---

## 参照

- WHO カラム＝監査の担保: `security-baseline.md` **SBD-14**（認可失敗・状態変更を「誰が/何を/結果」で記録）。
- 金額・所有者などサーバ権威フィールドは WHO と別に SBD-2 で保護。
