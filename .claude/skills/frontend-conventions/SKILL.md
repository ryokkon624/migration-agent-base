---
name: frontend-conventions
description: HwHubフロントエンド（hw-hub-frontend）・jpetstore-frontendの設計規約・実装方針。Vueファイル・TypeScriptファイル・Piniaストア・i18nファイルを新規作成・編集するときは必ずこのスキルを参照すること。Flux構造・カラートークン・i18nキー構造・テスト方針など、実装の判断に必要な規約をすべてここに集約している。
---

# Frontend Conventions

hw-hub-frontend・jpetstore-frontendの設計規約・実装方針。

> §1〜§6 はhw-hub-frontend由来（カラートークン名`hwhub-*`等の実例を含む）。**§7はjpetstore-frontend固有**
> （Vue3 + vue-i18n + Spring Security 7 backend連携）。Flux構造・ディレクトリ構成・テスト方針の思想は
> プロジェクト共通だが、カラートークン名は各プロジェクトの実態に読み替えること
> （jpetstore-frontendは`--jps-*` CSSカスタムプロパティ・`.jps-*`ユーティリティクラス。
> CLAUDE.md記載のとおりPhase 3実装時にJIT調整中）。

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

---

## 7. jpetstore-frontend 固有の注意事項（Vue 3 / vue-i18n / Spring Security 7 backend連携）

jpetstore-frontendはVue 3 + TypeScript + Pinia + Vue Router + Vite + Vitest + vue-i18n。
backend（Spring Security 7・JWT httpOnly Cookie認証）との連携で必要な参照知識・実装パターンをまとめる。

### CSRF cookie-to-header は非XOR・生値をそのまま送る（マスク処理を書かない）

backendが`CsrfTokenRequestAttributeHandler`（非XOR）を採用している場合、フロントは`XSRF-TOKEN` Cookie
の生値をそのまま`X-XSRF-TOKEN`ヘッダへ載せる。XORマスク等の処理を実装すると全ての非冪等リクエストが
403で失敗する（backend側の採用ハンドラと不一致になるため）。

Spring SecurityのCSRFトークンは状態変更（非GET）成功のたびにCookieが失効し、次のGETで再発行される
（consume-then-regenerate）。起動時1回のprimeだけでは2回目以降の状態変更でヘッダが欠落しうるため、
APIクライアント層に「送信直前にCSRF Cookieが無ければ疎通エンドポイント（例: `GET /api/ping`）で
再primeしてから送る」自己修復ロジックを持たせること。

```ts
// OK: 送信直前にCookieが無ければ自己primeしてから付与する
if (NON_IDEMPOTENT_METHODS.has(method)) {
  let token = readCsrfCookie()
  if (token === null) {
    await primeCsrfToken() // GET /api/ping 等
    token = readCsrfCookie()
  }
  if (token !== null) headers['X-XSRF-TOKEN'] = token // 生値のまま。マスクしない
}
```

> **背景（Sprint 5 #24）**: `jpetstore-frontend`の`httpClient.ts`で採用。Sprint 3（#18）でbackend側の
> consume-then-regenerate挙動が判明していた申し送りを踏まえた実装。

### トークンは httpOnly Cookie 前提。Pinia store は非機密な識別情報のみメモリ保持する

アクセス/リフレッシュトークンはbackendがhttpOnly Cookieで保持するため、フロントのJSからは触れない
（設計上構造的に「トークンをJSに持たない」が担保される）。Piniaストアは`{username, roles}`等の
**非機密な識別情報のみ**をメモリ上に保持し、`localStorage`/`sessionStorage`には一切書き込まない。

- テストで担保する: `vi.spyOn(Storage.prototype, 'setItem')`でサインオン成功時に呼ばれないことを固定する
- ログインCookieの内容を推測できる情報（ロール名等）はUI表示に使ってよいが、それ以上の機微情報は
  ストアに持たせない

### 認証状態のリロード再水和（`/me`パターン）と起動時の並列初期化

httpOnly CookieはリロードしてもブラウザがCookieを自動送信するが、Piniaストアはリロードで揮発する。
backendに現在の認証プリンシパルを返すエンドポイント（`GET /api/auth/me`等）があれば、アプリ起動時
（`app.mount()`前）にそれを呼びidentityを再水和する。

CSRF prime（例: `GET /api/ping`）と `/me` 取得は互いに独立（`/me`はGETでCSRF非依存）なリクエストのため、
`Promise.all`で並列実行してよい（直列にすると起動が不必要に遅くなる）。

```ts
// OK: 独立した初期化処理はPromise.allで並列化する
await Promise.all([primeCsrfToken(), useAuthStore().fetchCurrentUser()])
app.mount('#app')
```

> **背景（Sprint 5 #24・パフォーマンスレビュー指摘）**: 初回実装は直列awaitだった。両者に依存関係が
> 無いことを確認し並列化した。

### 401時のsilent refreshは「1回だけ・オプトアウト可能」に設計する

APIクライアントは401を受けたらrefreshエンドポイントへのPOSTを1回だけ試み、成功すれば元のリクエストを
再試行する。**credential交換エンドポイント自体（ログイン等）の401はrefreshを試みても無意味**
（トークン失効ではなく認証失敗のため）なので、呼び出し側が明示的にrefresh試行を無効化できる
オプション（例: `skipAuthRetry: true`）を用意する。無限ループ防止のため、refresh自身の呼び出しにも
同じオプションを付けて再帰的なrefresh試行を防ぐこと。

### ログイン失敗は一律メッセージ（HTTPステータス・エラー内容をUIへ生で渡さない）

backend側でログイン失敗が一律401（未知ユーザー/誤PW問わず）に正規化されている場合、フロントの
Piniaストアも失敗理由を保持・分岐せず、boolean の成否フラグのみを持たせる。View層は常に固定文言
（例:「Invalid username or password.」）を表示し、エラーオブジェクト・HTTPステータスコードを
そのままUIへ渡さない（列挙不可の担保をフロント側で壊さない）。

### オープンリダイレクト対策バリデータ: 制御文字は文字列全体を走査する

認証後の復帰先（`?redirect=`等の未信頼な入力）を検証するバリデータは、次を満たすこと。

- 単一の`/`で始まり直後が`/`や`\`でないことを要求する（`//evil`・`/\evil`等のプロトコル相対URLを拒否）
- **C0制御文字（0x00-0x1F、タブ/CR/LF等）の判定は先頭文字だけでなく文字列全体を走査する。**
  WHATWG URLパーサはこれらの文字を位置に関わらず除去して正規化するため、先頭以外に混入していても
  （例: `/\t/evil.com`）最終的にプロトコル相対URLとして解釈されうる
- 純関数として実装し、Vitestで否定ケース（`//evil`・`https://evil`・`/\evil`・タブ/CR/LF混入・
  URLデコード相当）を網羅的に固定する。ライブの保護画面が無くても純関数単体でAC実証できる

> **背景（Sprint 5 #24・セキュリティレビュー指摘）**: 初回実装は制御文字判定が先頭1文字目のみだった
> ため、`/\t/evil.com`のようなバイパスを見逃していた。文字列全体をcode point走査する形に修正した。

### i18n（vue-i18n v11・`domain.context.key`）

キー構造は`domain.context.key`（例: `auth.signon.error`）。

- **メッセージ文字列中の`@`はlinked message構文（`@:key`）として解釈される。** 技術用語で`@`を含む
  場合（例: `@layer`）は`\@`とエスケープしないとメッセージのコンパイルが構文エラーになる
- `legacy: false`（Composition API・`useI18n()`）で構成する
- 生HTMLを含む可能性のあるメッセージは`v-html`で描画しない（`{{ t(...) }}`の自動エスケープのみを使う）

---
