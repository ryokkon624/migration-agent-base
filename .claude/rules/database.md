---
description: モダン版JPetStoreのDB操作・Flyway・WHOカラム・m_code・MBG（MyBatis Generator）・generateEnumsの手順と規約。flyway の SQL や generatorConfig.xml を作成・編集するとき、m_code へのレコード追加・テーブル追加/変更・WHOカラムの付与を行うときは必ずこのルールに従うこと。横断決定は spec/architecture-conventions.md を正とする。
paths:
  - "flyway/**/*.sql"
  - "**/generatorConfig.xml"
---

# Database 規約・操作手順（モダン版 JPetStore）

> 横断アーキ決定は [`spec/architecture-conventions.md`](../../spec/architecture-conventions.md) が正。本書はその DB 実務手順版。
> HwHub からの差分: **WHO カラムはテキスト自動付与（`ProgramType` enum / m_code `0012` 廃止）／m_code は日英のみ（es 列廃止）／Dart 生成廃止**。

## リポジトリ構成

polyrepo 3本。DB は `jpetstore-database`（作成後、下記パスへ clone 想定）。

```
C:\work\java-migration\
├── jpetstore-database/      # 本書の対象。Flyway・m_code・MBG設定・enum生成(TS)
│   ├── flyway/
│   │   ├── sql/             # 本番相当マイグレーション（スキーマ・マスターデータ）
│   │   └── sql-test/        # 開発・テスト用データ（seedDevData で適用）
│   └── (docker-compose.yml) # ローカル MySQL（infra repo は将来）
├── jpetstore-backend/       # generateEnums / mybatisGenerator を実行
└── jpetstore-frontend/      # m_code→TS enum 成果物の取り込み先
```

---

## ローカル MySQL の起動・停止

コマンドはすべて `C:\work\java-migration\jpetstore-database` で実行する。

```bash
docker compose up -d    # 起動
docker compose down     # 停止
```

---

## Flyway コマンド（jpetstore-database で実行）

| コマンド                  | 用途                                                                   |
| ------------------------- | ---------------------------------------------------------------------- |
| `./gradlew flywayMigrate` | `flyway/sql` の未適用マイグレーションを順番に適用する                  |
| `./gradlew seedDevData`   | `flyway/sql-test` の開発用データを追加適用する（flywayMigrate に依存） |
| `./gradlew flywayClean`   | DB 上の全オブジェクトを削除する。**ローカル環境のみ使用可**            |

> `flywayClean` は STG/PROD では絶対に実行しない。

### ローカル開発環境での適用手順

開発環境では `seedDevData` を常時適用しているため、`flywayMigrate` 単体では新規マイグレーションを適用できない（sql-test のバージョンと競合するため）。**ローカルでは必ず以下の順番で実行すること。**

```bash
./gradlew flywayClean
./gradlew flywayMigrate
./gradlew seedDevData
```

---

## マイグレーションファイル命名規則

```
V00_001_015__add_column_theme.sql   ← 例
```

- バージョン番号は `flyway/sql` 内の最新ファイルの次の番号を採番する
- 既存ファイルの編集は禁止。必ず新規ファイルを追加する
- 説明部分（`__` 以降）は英小文字・アンダースコア区切り

---

## WHO カラム規約（全業務テーブル共通）

詳細・決定背景は [`spec/architecture-conventions.md` §2](../../spec/architecture-conventions.md#2-who-カラム規約d2d3)。**テーブルを新規作成する際は、以下の6列を必ず末尾に付与する。**

```sql
  , create_user_id BIGINT UNSIGNED NULL      COMMENT '作成者ユーザID'
  , create_program VARCHAR(100)    NOT NULL  COMMENT '作成機能(ClassName#method)'
  , created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '作成日時'
  , update_user_id BIGINT UNSIGNED NULL      COMMENT '更新者ユーザID'
  , update_program VARCHAR(100)    NOT NULL  COMMENT '更新機能(ClassName#method)'
  , updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                    ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時'
```

- `create_program` / `update_program` には **`ClassName#method` のテキスト**（例 `OrderService#placeOrder`）が入る。**`ProgramType` enum も m_code `0012` も作らない。**
- 値は **AOP＋MyBatis Interceptor が自動付与**（最外の業務サービスが勝つ set-once 方式）。**Service 側で WHO 値を手渡ししない。**
  - 共通サービスが INSERT しても、記録されるのは呼び出した最外の業務サービス名。
- マスターデータの seed（Flyway の INSERT）では Interceptor が効かないので、**リテラル `'INIT_DATA'` を明示**する（下記 m_code テンプレート参照）。

> DEV 向け実装骨子（backend）: `ProgramContext`(ThreadLocal) ＋ サービス層 `@Around` アスペクト ＋ `Executor#update` Interceptor。雛形に同梱予定。

---

## 並行制御（在庫 / version 楽観ロック）

決定・背景は [`spec/architecture-conventions.md` §4](../../spec/architecture-conventions.md#4-並行制御d6)。**`updated_at` はロックに使わず監査専用**。

### 在庫引き当て＝ガード付きアトミック減算

- 在庫減算は**ガード付きの単一 UPDATE**で行い、影響行数で在庫不足を判定する（read→act 分離の TOCTOU を避ける）。

  ```sql
  UPDATE inventory SET qty = qty - #{n}
   WHERE item_id = #{itemId} AND qty >= #{n};
  ```

  - affected rows `== 0` → 在庫不足（or 競合負け）＝注文失敗。`version` 列・`SELECT ... FOR UPDATE` は不要。
  - 注文確定は `@Transactional` で 注文＋明細＋在庫減算を all-or-nothing。複数商品は `item_id` 昇順など**固定順で減算**しデッドロック回避。

### 編集系エンティティ＝`version` 楽観ロック

- **更新が発生するエンティティ表**には、WHO 6列に加えて **`version BIGINT NOT NULL DEFAULT 0`** を付ける（列は WHO の前・業務カラムの末尾あたり）。

  ```sql
  , version BIGINT NOT NULL DEFAULT 0 COMMENT '楽観ロック用バージョン'
  ```

- 更新 SQL は必ず `SET ..., version = version + 1 WHERE pk = #{id} AND version = #{version}`。affected rows `== 0` は競合 → アプリは **409 Conflict** を返す（MyBatis に `@Version` 相当は無いので affected rows を自前チェック）。
- **付けない表**: 純追記表（注文明細・履歴・ログ）、migration 管理の `m_code`。**在庫表**はガード付き減算が主機構のため必須ではない。

---

## m_code（コードマスター）

### 目的

アプリ内の**ドメイン区分値**（注文ステータス・カード種別 等）を DB で一元管理するマスター。
TS 側は `jpetstore-database` の generateEnums（TS）、Java 側は `jpetstore-backend` の `./gradlew generateEnums` で enum を自動生成する。**WHO の機能区分（旧 `0012` ProgramType）は m_code で管理しない**（§WHO 参照）。

### テーブル構造

| カラム                | 説明                                         |
| --------------------- | -------------------------------------------- |
| `code_type`           | コード種別（4桁数字文字列）                  |
| `code_type_name`      | 種別名（日本語）                             |
| `code_type_name_en`   | 種別名（英語）※ enum のクラス名になる        |
| `code_value`          | コード値                                     |
| `name`                | 値の識別名（英語）                           |
| `display_name_ja/en`  | 多言語表示名（**日英のみ**。es 列は持たない）|
| `display_order`       | 表示順（`10001` 刻みを推奨）                 |

> **HwHub からの差分**: `display_name_es` 列は廃止（多言語は日英）。2つの enum ジェネレータとも es を参照しないため影響なし。

### code_type の採番

- JPetStore のドメイン区分値は**未確定**（PO の Story/仕様で確定）。候補: 注文ステータス（OrderStatus）・カード種別（CardType）等。
- 採番は `0001` から。新規採番前に `flyway/sql` 内の INSERT 文をすべて確認し、重複しない番号を使うこと。
- **`0012`(ProgramType) は使わない**（WHO はテキスト自動付与のため）。

### INSERT テンプレート（es 列なし・WHO は INIT_DATA）

```sql
INSERT INTO m_code (
    code_type, code_type_name, code_type_name_en, code_value, name,
    display_name_ja, display_name_en,
    remarks, display_order,
    create_user_id, create_program, created_at,
    update_user_id, update_program, updated_at
) VALUES
    ('XXXX', '種別名', 'EnumClassName', 'VALUE1', 'ConstantName',
     '日本語表示名', 'English Name',
     NULL, '10001',
     1, 'INIT_DATA', NOW(6),
     1, 'INIT_DATA', NOW(6));
```

---

## generateEnums（enum 自動生成）

### Java enum（jpetstore-backend で実行）

```bash
./gradlew generateEnums    # C:\work\java-migration\jpetstore-backend で実行
```

- **実行タイミング**: `m_code` にレコードを追加・変更したとき
- DB から直接読み込むため、**flywayMigrate 後に実行すること**
- 出力先: backend の `domain/enums`（ソースツリー直下＝コミット対象・手動編集禁止）
- 生成パターン（`CodeEnum` 実装・`fromCode` 付き）:

```java
public enum OrderStatus implements CodeEnum {
  NEW("NEW"),
  PAID("PAID"),
  SHIPPED("SHIPPED");

  private final String code;
  OrderStatus(String code) { this.code = code; }

  @Override public String getCode() { return code; }

  public static OrderStatus fromCode(String code) {
    for (OrderStatus v : values()) {
      if (v.code.equals(code)) return v;
    }
    throw new IllegalArgumentException("Invalid OrderStatus code: " + code);
  }
}
```

> 生成後に `spotlessApply` でフォーマットすること。

### TS 定数（jpetstore-database で実行）

- m_code → TS 定数を生成（HwHub の `MultiEnumGenerator` を移植・**Dart 出力は削除**）。
- 成果物を `jpetstore-frontend` に取り込む。

---

## MyBatis Generator（MBG）（jpetstore-backend で実行）

```bash
# resources/mapper/generated/ 配下の XML を先に削除してから実行する（重複定義防止）
rm -rf src/main/resources/mapper/generated
./gradlew mybatisGenerator    # C:\work\java-migration\jpetstore-backend で実行
```

- **実行タイミング**: テーブルの追加・カラムの追加・変更時
- DB から直接読み込むため、**flywayMigrate 後に実行すること**
- XML 削除を省略すると Mapper XML に同一 SQL が重複定義されるため、必ず削除してから実行すること
- 生成物（手動編集禁止）:
  - `infrastructure/mybatis/generated/entity/` — Entity クラス
  - `infrastructure/mybatis/generated/mapper/` — Mapper インタフェース
  - `resources/mapper/generated/` — Mapper XML

### 新規テーブル追加時の追加作業

`src/main/resources/generator/generatorConfig.xml` に `<table>` 要素を追加してから実行する。

```xml
<!-- AUTO_INCREMENT の PK がある場合 -->
<table tableName="t_xxx"
    enableCountByExample="false" enableUpdateByExample="false"
    enableDeleteByExample="false" enableSelectByExample="true"
    selectByExampleQueryId="false">
  <generatedKey column="xxx_id" sqlStatement="JDBC" identity="true"/>
</table>

<!-- 複合 PK など AUTO_INCREMENT なし -->
<table tableName="t_yyy"
    enableCountByExample="false" enableUpdateByExample="false"
    enableDeleteByExample="false" enableSelectByExample="true"
    selectByExampleQueryId="false">
</table>
```

---

## 既存テーブルへの ALTER 時の注意

環境にデータが存在する段階では、ALTER の内容によって SQL を複数行に分ける必要がある。**1ファイル内に複数 SQL を書いてよい**（Flyway は順序を保証して実行する）。

### NOT NULL カラムを追加する場合

`ADD COLUMN col NOT NULL` を一行で実行すると既存行でエラーになる。1ファイル内で段階的に記述する。

```sql
ALTER TABLE t_order ADD COLUMN status_code VARCHAR(10) NULL;
UPDATE t_order SET status_code = 'NEW' WHERE status_code IS NULL;
ALTER TABLE t_order MODIFY COLUMN status_code VARCHAR(10) NOT NULL;
```

### DEFAULT 値ありで追加する場合

`ADD COLUMN col VARCHAR(10) NOT NULL DEFAULT 'VALUE'` は既存行に DEFAULT が埋まるため1行で完結できる。

### カラムの追加位置を指定する場合（AFTER 句）

`ADD COLUMN` の既定はテーブル末尾に追加する。設計上カラム順が重要な場合は `AFTER 既存カラム名` を必ず指定する（WHO カラムは常に末尾）。

```sql
-- OK: AFTER 句で配置位置を指定
ALTER TABLE t_order ADD COLUMN ship_note VARCHAR(255) NULL AFTER status_code;
```

- NOT NULL を段階追加する場合でも、`ADD COLUMN` の段階で `AFTER` 句を指定しておく
- 後からの位置変更は `MODIFY COLUMN ... AFTER ...` が必要になり、追加マイグレーションが要る

### カラム削除・型変更の場合

データ損失リスクがあるため、影響範囲を確認してからユーザーに相談すること。

---

## 変更種別ごとの作業フロー

### カラム追加（例: t_order にカラム追加）

1. `flyway/sql/` に ALTER SQL を追加（NOT NULL 追加は段階分割。「ALTER 時の注意」参照）
2. `jpetstore-database` で `./gradlew flywayClean && ./gradlew flywayMigrate && ./gradlew seedDevData`
3. `jpetstore-backend` で `rm -rf src/main/resources/mapper/generated`
4. `jpetstore-backend` で `./gradlew mybatisGenerator`

### m_code にレコード追加

1. `flyway/sql/` に INSERT SQL を追加（es 列なしテンプレート・WHO は `INIT_DATA`）
2. `jpetstore-database` で `./gradlew flywayClean && ./gradlew flywayMigrate && ./gradlew seedDevData`
3. `jpetstore-backend` で `./gradlew generateEnums` → `spotlessApply`
4. TS 定数を再生成し `jpetstore-frontend` に反映

### 新規テーブル追加

1. `flyway/sql/` に CREATE TABLE SQL を追加（**WHO カラム6列を末尾に付与**。**更新が発生するエンティティ表は `version` 列も付与**＝「並行制御」参照。m_code `0012`/enum 追加は不要）
2. `generatorConfig.xml` に `<table>` 要素を追加
3. `jpetstore-database` で `./gradlew flywayClean && ./gradlew flywayMigrate && ./gradlew seedDevData`
4. `jpetstore-backend` で `rm -rf src/main/resources/mapper/generated`
5. `jpetstore-backend` で `./gradlew mybatisGenerator`
