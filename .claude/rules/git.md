---
description: JPetStore MigrationプロジェクトのGitコミット・ブランチ規約。コミットする・ブランチを作成するときは必ずこのルールに従うこと。
---

# Git規約

## ブランチ命名規則

### 基本形式

```
{種別}/{Issue番号}-{短い説明}
```

| Prefix      | 目的                                         | 例                                |
| ----------- | -------------------------------------------- | --------------------------------- |
| `feature/`  | 新しい機能の追加や大規模な改修               | `feature/123-user-profile-update` |
| `fix/`      | バグ修正や障害対応                           | `fix/45-login-redirect-error`     |
| `refactor/` | 動作を変えずにコードの改善やリファクタリング | `refactor/api-exception-handling` |
| `docs/`     | ドキュメントの修正や更新                     | `docs/update-readme-usage`        |
| `hotfix/`   | 本番環境で発見された緊急性の高いバグ修正     | `hotfix/critical-payment-bug`     |

- Issue番号はGitHubのIssue番号を含めて紐づける（例: `feature/123-xxx`）
- 短い説明は単語をハイフンつなぎ小文字（例: `update-user-profile`）
- プロダクトバックログにブランチ名が明示されている場合はそちらを優先する
- `hotfix/`は指示がない限り使用しないこと

---

## コミット規約

### コミットメッセージ形式

```
{prefix}: {説明} ({Issue参照})
```

### プレフィックス一覧

| プレフィックス | 用途                                                                   |
| -------------- | ---------------------------------------------------------------------- |
| `feat:`        | 機能の追加                                                             |
| `fix:`         | バグの修正                                                             |
| `docs:`        | ドキュメントのみの変更                                                 |
| `style:`       | フォーマット・セミコロン・コメント修正など（ロジックに関わらない変更） |
| `refactor:`    | リファクタリング（機能追加やバグ修正ではないコードの改善）             |
| `test:`        | テストコードの追加や修正                                               |
| `chore:`       | ビルドプロセスや外部ツールの変更                                       |

### Issue参照の形式

コミットメッセージの末尾に必ずGitHub Issue番号を付与する。

```
(ryokkon624/jpetstore-manage#N)
```

### コミットメッセージ例

```
feat: 商品カテゴリ一覧のREST APIを追加 (ryokkon624/jpetstore-manage#3)
fix: カート数量更新時の在庫チェック漏れを修正 (ryokkon624/jpetstore-manage#7)
refactor: OrderServiceのトランザクション境界をユースケース層へ集約 (ryokkon624/jpetstore-manage#7)
test: AccountControllerの登録バリデーションテストを追加 (ryokkon624/jpetstore-manage#12)
```

---

## コミット前の必須作業

コミット前に必ずフォーマットを実行すること。

| 対象           | コマンド                  | 実行ディレクトリ                            |
| -------------- | ------------------------- | ------------------------------------------- |
| フロントエンド | `npm run format`          | `C:\work\java-migration\jpetstore-frontend` |
| バックエンド   | `./gradlew spotlessApply` | `C:\work\java-migration\jpetstore-backend`  |

---

## 禁止事項

- `main` ブランチへの直接push
