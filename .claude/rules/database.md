---
description: HwHubのDB操作・Flyway・m_code・MBG（MyBatis Generator）・generateEnumsの手順と規約。マイグレーションファイル・generatorConfig.xmlを作成・編集するとき、またはm_codeへのレコード追加・テーブル変更を行うときは必ずこのルールに従うこと。
paths:
  - "flyway/**/*.sql"
  - "**/generatorConfig.xml"
---

# Database 規約・操作手順

## リポジトリ構成

```
hw-hub-database/         # C:\work\hw-hub\hw-hub-database
├── flyway/
│   ├── sql/             # 本番相当マイグレーション（スキーマ・マスターデータ）
│   └── sql-test/        # 開発・テスト用データ（seedDevData で適用）
```

---

## ローカル MySQL の起動・停止

コマンドはすべて `C:\work\hw-hub\hw-hub-database` で実行する。

```bash
docker compose up -d    # 起動
docker compose down     # 停止
```

---

## Flyway コマンド（hw-hub-database で実行）

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

## 既存テーブルへの ALTER 時の注意

本番・STG 環境には既存データが存在するため、ALTER の内容によっては SQL を複数行に分けて記述する必要がある。**1ファイル内に複数 SQL を書いてよい**（Flyway は順序を保証して実行する）。

### NOT NULL カラムを追加する場合

`ADD COLUMN col NOT NULL` を一行で実行すると既存行でエラーになる。1ファイル内で以下のように段階的に記述する。

```sql
-- V00_001_015__add_column_theme.sql
ALTER TABLE m_user ADD COLUMN theme_code VARCHAR(10) NULL;
UPDATE m_user SET theme_code = 'SYSTEM' WHERE theme_code IS NULL;
ALTER TABLE m_user MODIFY COLUMN theme_code VARCHAR(10) NOT NULL;
```

### DEFAULT 値ありで追加する場合

`ADD COLUMN col VARCHAR(10) NOT NULL DEFAULT 'VALUE'` は既存行に DEFAULT が埋まるため1行で完結できる。

### カラムの追加位置を指定する場合（AFTER 句）

`ADD COLUMN` のデフォルト動作はテーブルの末尾にカラムを追加する。DB設計上カラムの順序（配置）が重要な場合は `AFTER 既存カラム名` を必ず指定すること。

```sql
-- NG: AFTER 句なし → カラムが末尾に追加される
ALTER TABLE t_inquiry
  ADD COLUMN ui_client VARCHAR(10) NULL;

-- OK: AFTER 句で配置位置を指定
ALTER TABLE t_inquiry
  ADD COLUMN ui_client VARCHAR(10) NULL AFTER user_id;
```

注意:
- テーブル定義コメント（`-- カラム定義`）や ER 図でカラム順が決まっている場合は必ず `AFTER` 句を使う
- NOT NULL カラムを段階的に追加する場合（3ステップ）でも、`ADD COLUMN` の段階で `AFTER` 句を指定しておくこと
- カラム位置を後から変更するには `MODIFY COLUMN ... AFTER ...` が必要になり、追加のマイグレーションファイルが必要になる

> **背景（Sprint 63 Sprint Review 指摘）**: t_inquiry への `ui_client/ui_version/api_version` カラム追加時に `AFTER` 句を省略したため、カラムが末尾に追加された。user_id と category の間に配置すべき設計だったため、別途 `AFTER` 句付きのマイグレーションで修正が必要になった。

### カラム削除・型変更の場合

データ損失リスクがあるため、影響範囲を確認してからユーザーに相談すること。

---

## m_code（コードマスター）

### 目的

アプリケーション内の列挙値（ステータス・種別等）を DB で一元管理するマスターテーブル。
Java 側は `./gradlew generateEnums` で自動生成した enum を使う。

### テーブル構造

| カラム                  | 説明                                         |
| ----------------------- | -------------------------------------------- |
| `code_type`             | コード種別（4桁数字文字列）                  |
| `code_type_name`        | 種別名（日本語）                             |
| `code_type_name_en`     | 種別名（英語）※ Java enum のクラス名になる   |
| `code_value`            | コード値                                     |
| `name`                  | 値の識別名（英語）※ Java enum の定数名になる |
| `display_name_ja/en/es` | 多言語表示名                                 |
| `display_order`         | 表示順（`10001` 刻みを推奨）                 |

### 現在割り当て済み code_type（主要）

| code_type  | code_type_name_en    |
| ---------- | -------------------- |
| 0001       | RecurrenceType       |
| 0002       | Weekday              |
| 0003       | NthWeek              |
| 0004       | Category             |
| 0010       | PurchaseLocationType |
| 0011       | NotificationStatus   |
| 0012       | ProgramType          |
| 0013       | FavoriteFlag         |
| 0014       | TaskRecalcStatus     |
| 0017〜0019 | 通知関連             |
| 0020〜0023 | 通知関連             |
| 0024〜0025 | 権限関連             |

> 新規採番前に `flyway/sql` 内の INSERT 文をすべて確認し、重複しない番号を使うこと。

### INSERT テンプレート

```sql
INSERT INTO m_code (
    code_type, code_type_name, code_type_name_en, code_value, name,
    display_name_ja, display_name_en, display_name_es,
    remarks, display_order,
    create_user_id, create_program, created_at,
    update_user_id, update_program, updated_at
) VALUES
    ('XXXX', '種別名', 'EnumClassName', 'VALUE1', 'ConstantName',
     '日本語表示名', 'English Name', 'Nombre en español',
     NULL, '10001',
     1, 'INIT_DATA', NOW(6),
     1, 'INIT_DATA', NOW(6));
```

---

## generateEnums（hw-hub-backend で実行）

```bash
./gradlew generateEnums    # C:\work\hw-hub\hw-hub-backend で実行
```

- **実行タイミング**: `m_code` にレコードを追加・変更したとき
- DB から直接読み込んで enum クラスを自動生成するため、**flywayMigrate 後に実行すること**
- 出力先: `com.hwhub.backend.domain.enums`
- 生成パターン:

```java
public enum ThemeMode implements CodeEnum {
  LIGHT("LIGHT"),
  DARK("DARK"),
  SYSTEM("SYSTEM");

  private final String code;
  ThemeMode(String code) { this.code = code; }

  @Override public String getCode() { return code; }

  public static ThemeMode fromCode(String code) {
    for (ThemeMode v : values()) {
      if (v.code.equals(code)) return v;
    }
    throw new IllegalArgumentException("Invalid ThemeMode code: " + code);
  }
}
```

> 生成後に `spotlessApply` でフォーマットすること。

---

## MyBatis Generator（MBG）（hw-hub-backend で実行）

```bash
# resources/mapper/generated/ 配下の XML を先に削除してから実行する（重複定義防止）
rm -rf src/main/resources/mapper/generated
./gradlew mybatisGenerator    # C:\work\hw-hub\hw-hub-backend で実行
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
<table tableName="m_xxx"
    enableCountByExample="false" enableUpdateByExample="false"
    enableDeleteByExample="false" enableSelectByExample="true"
    selectByExampleQueryId="false">
  <generatedKey column="xxx_id" sqlStatement="JDBC" identity="true"/>
</table>

<!-- 複合 PK など AUTO_INCREMENT なし -->
<table tableName="m_yyy"
    enableCountByExample="false" enableUpdateByExample="false"
    enableDeleteByExample="false" enableSelectByExample="true"
    selectByExampleQueryId="false">
</table>
```

> 対象テーブルを一覧するには generatorConfig.xml 内のコメントに記載の SQL を実行して結果を貼り付ける。

---

## 変更種別ごとの作業フロー

### カラム追加（例: m_user にカラム追加）

1. `flyway/sql/` に ALTER SQL を追加（NOT NULL 追加の場合は段階分割。「既存テーブルへの ALTER 時の注意」を参照）
2. `hw-hub-database` で `./gradlew flywayClean && ./gradlew flywayMigrate && ./gradlew seedDevData`
3. `hw-hub-backend` で `rm -rf src/main/resources/mapper/generated` を実行
4. `hw-hub-backend` で `./gradlew mybatisGenerator`

### m_code にレコード追加

1. `flyway/sql/` に INSERT SQL を追加
2. `hw-hub-database` で `./gradlew flywayClean && ./gradlew flywayMigrate && ./gradlew seedDevData`
3. `hw-hub-backend` で `./gradlew generateEnums`
4. 生成された enum に `spotlessApply` を適用

### 新規テーブル追加

1. `flyway/sql/` に CREATE TABLE SQL を追加
2. `generatorConfig.xml` に `<table>` 要素を追加
3. `hw-hub-database` で `./gradlew flywayClean && ./gradlew flywayMigrate && ./gradlew seedDevData`
4. `hw-hub-backend` で `rm -rf src/main/resources/mapper/generated` を実行
5. `hw-hub-backend` で `./gradlew mybatisGenerator`
