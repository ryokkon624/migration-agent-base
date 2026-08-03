---
name: frontend-conventions
description: HwHubフロントエンド（hw-hub-frontend）の設計規約・実装方針。Vueファイル・TypeScriptファイル・Piniaストア・i18nファイルを新規作成・編集するときは必ずこのスキルを参照すること。Flux構造・カラートークン・i18nキー構造・テスト方針など、実装の判断に必要な規約をすべてここに集約している。
---

# Frontend Conventions

hw-hub-frontendの設計規約・実装方針。

---

## 1. 基本記述スタイル

- コンポーネントは `<script setup lang="ts">` を使用し、`defineProps` / `defineEmits` を活用する
- `any` の使用は一切禁止。必ず適切な型定義（interface / type）を行う
- テキストは `vue-i18n` を使用し、`ja` / `en` / `es` を並行してメンテナンスする
- i18nキー構造: `domain.context.key`

```
例:
  housework.list.title
  shopping.add.button
```

- アイコンは Lucide を使用し、各ファイルで使うアイコンだけ named import する

```ts
// ✅ 正しい: named import
import { Plus, Trash2 } from "lucide-vue-next";

// ❌ 禁止: 全量import
import * as LucideIcons from "lucide-vue-next";
```

### バックエンドから返されるコード値の表示変換（必須）

バックエンドが返すコード値（m_code 管理の区分値など）をテンプレートにそのまま表示してはならない。必ず i18n キーに変換してから表示すること。

```ts
// NG: コード値 'web' / 'mobile' をそのまま表示
<span>{{ inquiry.uiClient }}</span>

// OK: マッピング関数または computed で i18n キーに変換して表示
function uiClientLabel(code: string): string {
  const map: Record<string, string> = {
    web: t('inquiry.detail.uiWeb'),
    mobile: t('inquiry.detail.uiMobile'),
  };
  return map[code] ?? code; // 未知のコードはコード値をフォールバック表示
}
<span>{{ uiClientLabel(inquiry.uiClient) }}</span>
```

適用すべき場面:
- m_code テーブルで管理されている区分値（UIクライアント・カテゴリ・ステータス等）を画面に表示するとき
- バックエンドの enum の `code` 値（例: `'web'`・`'1'` 等）を一覧・詳細画面に表示するとき

> **背景（Sprint 63 convention-reviewer 指摘）**: InquiryDetailPage・AdminInquiryDetailPage で `uiClient` の値 `'web'`/`'mobile'` を翻訳せずそのまま表示していた。

---

## 2. アーキテクチャ & データフロー（Flux構造）

```
View（Component / Page）
  ↓ ユーザー操作
Store Action（Pinia）
  ↓ APIコール
api/xxxApi.ts
  ↓ レスポンス
State更新
  ↓ リアクティブ
View（再描画）
```

**重要ルール**

- APIコールは必ず Store の Action 内から API クライアントを経由して行う
- Component / Page / Composable から直接 API を呼ぶことは禁止
- `api/xxxApi.ts` 内で Request/Response DTO を定義し、フロントエンド用 Domain に変換して返却する

---

## 3. ディレクトリ構成

```
src/
  api/          APIクライアント（DTO定義・Domainへのマッピング）
  components/   共通コンポーネント
  views/        ページコンポーネント（Pageサフィックス）
  stores/       Pinia Store
  domain/       フロントエンド用Domainモデル
  utils/        ユーティリティ
  i18n/         多言語定義
```

---

## 4. スタイリング

- 色定義などの共通設定は `main.css` の utilities を優先して使用する
- その他のスタイルは Tailwind CSS クラスを直接記述する
- `border-gray-*` / `text-gray-*` などの生クラスは使用禁止。必ずカラートークンを使う

### カラートークン一覧

| トークン                    | 値          | 用途                          |
| --------------------------- | ----------- | ----------------------------- |
| `bg-hwhub-primary`          | emerald-600 | メインアクション・ボタン      |
| `bg-hwhub-sidebar`          | #1a2e1a     | PC/SPサイドバー背景           |
| `bg-hwhub-surface`          | #f7f8f6     | ページ背景                    |
| `bg-hwhub-surface-subtle`   | green-50    | カード内サブ背景・hover       |
| `bg-hwhub-accent-soft`      | amber-50    | 未割当・要注意カード背景      |
| `bg-hwhub-accent-badge`     | amber-100   | 未割当バッジ                  |
| `bg-hwhub-danger-soft`      | rose-50     | 期限切れ・エラー背景          |
| `bg-hwhub-info-soft`        | blue-50     | 買い物・情報系背景            |
| `border-hwhub-border`       | slate-200   | 汎用ボーダー（input・カード） |
| `text-hwhub-sidebar-nav`    | green-200   | サイドバー非アクティブ文字    |
| `text-hwhub-sidebar-active` | white       | サイドバーアクティブ文字      |

### アイコン色ルール（Lucide）

役割ごとに色をつけること。単純に黒のままにしない。

| 用途                 | 色                                                  |
| -------------------- | --------------------------------------------------- |
| ナビ・ホーム系       | `text-hwhub-primary`                                |
| 未割当・要注意       | `text-amber-500`                                    |
| 買い物カート         | `text-blue-500`                                     |
| 期限切れ・警告       | `text-rose-500`                                     |
| 設定メニュー         | 役割別にバッジ風ラップ（`bg-*-100` + `text-*-600`） |
| 通知ベル（未読あり） | `text-amber-500`                                    |

---

## 5. テスト方針（Vitest）

- テストコードは Vitest で記述する
- `it` の第一引数（テスト名）およびコード内のコメントは日本語で記述する
- カバレッジは `npm run test:unit -- --coverage` で確認し、限りなく100%を目指す

### テスト対象の分類

| 種別 | テスト | 備考 |
|------|--------|------|
| Store / Composable / utils | **必須** | ロジックを持つため Vitest で先に書く（TDD） |
| View / Component（見た目の変更） | **不要** | テンプレート・スタイルのみの変更はテスト対象外 |

---

## 6. 開発・デバッグ用テストアカウント

パスワード共通: `admin`

```
home.owner@example.com
home.member@example.com
parent.owner@example.com
parent.member1@example.com 〜 parent.member4@example.com
```

ユーザー間の詳細な関係性は `hw-hub-database/flyway/sql-test/R__test_household.sql` を参照。
