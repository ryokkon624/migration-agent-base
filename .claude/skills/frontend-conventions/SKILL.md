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
  - ⚠️ **`test:unit` は hw-hub-frontend の script 名。`jpetstore-frontend` には存在しない**（実体は `npm run test` = `vitest run`）。§7「テスト実行コマンド」参照

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

### テスト実行コマンドは `npm run test`（`test:unit` は存在しない）

`jpetstore-frontend/package.json` の scripts は以下がすべて。**hw-hub-frontend 由来の `test:unit` は無い**ので、
指示や他ドキュメントに `npm run test:unit` と書かれていても、そのまま実行するとエラーになる。

| script | 実体 | 用途 |
| --- | --- | --- |
| `test` | `vitest run` | **ユニットテスト一括実行（これを使う）** |
| `format` | `prettier --write "src/**/*.{ts,vue,json,css}"` | コミット前フォーマット |
| `type-check` | `vue-tsc --build` | 型チェック |
| `build` | `run-p type-check build-only` | 型チェック＋ビルド |
| `dev` / `preview` / `build-only` | `vite` 系 | 開発サーバ・プレビュー・ビルドのみ |

- 実行結果は `Test Files N passed (N)` / `Tests N passed (N)` の行を読む。**skipped があれば `Tests N passed | M skipped` の形で出る**ので、その表記が無ければ skipped=0。
- カバレッジを取る場合は `npx vitest run --coverage`（`test:unit -- --coverage` は使えない）。
- **コマンド名は実行前に `package.json` で実在確認する**（`developer-workflow`「数値・判定を成果物に書くときは…」参照）。

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

### ドメイン一覧/カード/ページネーション/バッジは既達`.jps-*` CSSクラスの薄い`.vue`ラッパで実装する

`main.css`の共通ユーティリティ（`.jps-product-card`・`.jps-pagination`・`.jps-badge`系＋
`.badge-jps-stock-*`等）が既に定義されている場合、新規ドメイン画面のコンポーネント（`ProductCard.vue`・
`Pagination.vue`・`StockBadge.vue`等）は独自スタイルを新設せず、既存クラスを適用するだけの薄いラッパとして
実装する。ロジック（props/イベント）に専念でき、スタイルの重複・カラートークンからの逸脱も防げる。

> **背景（Sprint 6 #1）**: `.jps-product-card`・`.jps-pagination`・`.badge-jps-stock-*`は#24（土台）で
> 既に整備済みだったため、カタログ画面のVueコンポーネントは薄いラッパで完結した。#2（検索）・#9（注文履歴）
> でも同じ既達クラスを再利用する想定。

### ドメイン画像は`import.meta.glob(eager)`で一括取り込み＋placeholderフォールバック

`spec/design/images`等の静的な商品/カテゴリ画像をfrontendへ取り込む場合、個別importを列挙せず
`import.meta.glob(pattern, { eager: true })`でディレクトリ単位に一括読み込みし、`resolveXxxImage(kind, id)`
のような解決関数で「該当画像が無ければplaceholder」にフォールバックさせる。

```ts
const images = import.meta.glob('../assets/catalog/*.png', { eager: true })
function resolveCatalogImage(kind: 'category' | 'product', id: string): string {
  const path = `../assets/catalog/${kind}_${id}.png`
  return (images[path] as { default: string } | undefined)?.default ?? placeholderUrl
}
```

`import.meta.glob`はViteのビルド時静的解析でパターン文字列を解決するため、パターン自体を変数化・動的生成
すると対象を拾えなくなる点に注意（グロブ対象のパスは常にリテラルで書く）。

> **背景（Sprint 6 #1）**: カタログ画像（category5枚/product16枚）の取り込みで採用。itemは対応productIdの
> 画像を流用し、欠落時は`placeholder.svg`にフォールバックする。

### i18n（vue-i18n v11・`domain.context.key`）

キー構造は`domain.context.key`（例: `auth.signon.error`）。

- **メッセージ文字列中の`@`はlinked message構文（`@:key`）として解釈される。** 技術用語で`@`を含む
  場合（例: `@layer`）は`\@`とエスケープしないとメッセージのコンパイルが構文エラーになる
- `legacy: false`（Composition API・`useI18n()`）で構成する
- 生HTMLを含む可能性のあるメッセージは`v-html`で描画しない（`{{ t(...) }}`の自動エスケープのみを使う）

> m_code由来の生成表示定数（例: `code.constants.ts`の在庫ステータス表示名）と既存i18nキーが重複する場合の
> reconcile（統合）は、初出（1回目・Sprint6 #1）のため2回ルールに従い本Skillには未反映
> （`memory/dev/long_term.md`「習得したこと」参照）。2回目の発生でSkill昇格を検討する。

### localStorageを新規導入する場合は「破損耐性」「タブ間同期」をセットで設計する

`stores/auth.ts`はトークンをhttpOnly Cookie前提とし、Piniaは非機密な識別情報のみメモリ保持する方針
（localStorage/sessionStorageへは一切書き込まない）だが、**未ログイン中もクライアント側で状態を保持し
たい機能**（カート等）では、この方針の対象外として限定的にlocalStorageを導入してよい。導入する際は
以下3点をセットにする。

1. **`load`/`save`/`clear`いずれも`try/catch`で例外を握りつぶし、安全なフォールバック値（空配列等）を
   返す**。破損したJSON・想定外の型（非配列等）・書き込み不可な環境（プライベートブラウジング等）の
   いずれでもアプリを落とさない。
2. **保存前に配列要素の形を型ガード関数（`value is T`）で検証し、不正な要素だけを`filter`で除外する**
   （配列全体を捨てず、壊れた要素だけを無害化する）。
3. **`window.addEventListener('storage', ...)`で他タブでの変更を検知できるようにする**。同一タブ内の
   変更ではブラウザ仕様上`storage`イベントは発火しないため、呼び出し側が自タブの変更は自前で状態に
   反映する前提で設計する。

```ts
// OK: 破損耐性 + 型ガードで要素単位フィルタ
export function loadCart(): StoredCartLine[] {
  try {
    const raw = window.localStorage.getItem(CART_STORAGE_KEY)
    if (raw === null) return []
    const parsed: unknown = JSON.parse(raw)
    if (!Array.isArray(parsed)) return []
    return parsed.filter(isStoredCartLine)
  } catch {
    return []
  }
}
```

> **背景（Sprint 8 #4）**: フロント初のlocalStorage導入（`utils/cartStorage.ts`・未ログインカートの
> クライアント状態保持）で採用。

### 多段階入力フロー（ウィザード）は単一ルート＋内部ステップ＋揮発Piniaで実装する

チェックアウトのように複数ステップにまたがる入力フローは、ステップごとに個別ルートを切らず、単一ルート
（例: `/checkout`・`meta.requiresAuth: true`）配下でコンテナ側がステップコンポーネントを切り替える構成に
する。

- **per-stepルートにしない**。単一ルートにすることで、既達の`authGuard`/`redirectValidator`（未認証時の
  元URL退避→サインオン→復帰）が新規配線ゼロでそのまま機能する（per-stepルートだと各ルートに
  `meta.requiresAuth`を付与し直す必要がある）
- **下書き状態（住所等）はsessionStorage/DBに永続化せず、Piniaストアのメモリ保持のみ（揮発）とする。**
  `reset()`は明示的なアクション呼び出し時のみ実行し、SPA内の通常遷移では自動リセットしない
- 既達のステッパーCSS（`.jps-steps`/`.jps-step*`）・フォームkit（`.jps-field`等）をそのまま再利用し、
  新規スタイルを増やさない

```ts
// OK: 単一ルート + 内部ステップ。meta.requiresAuthはこの1ルートに付けるだけでよい
{ path: '/checkout', component: CheckoutView, meta: { requiresAuth: true } }
```

> **背景（Sprint 10 #7）**: `/checkout`（カート確認→住所→確定の3ステップ）で採用。既達の`GET /api/cart`・
> カートストア・認証復帰の仕組みを一切変更せず再利用でき、ウィザード固有の実装（ステップ管理・住所フォーム・
> 下書き状態）だけに集中できた。今後の多段階フロー（例: 注文確定ウィザードの拡張）でも再利用する想定。

### View非テスト方針下での否定ACはPiniaストアのtestableなgetterに切り出す

View/Component（見た目の変更）はVitestテスト不要という方針だが、Viewが依存する判定ロジック（否定AC等）を
View内に直接書いてしまうと、そのACはテストで担保できなくなる。View側の判定はPiniaストアの**testableな
getter**に切り出し、Viewはそのgetterの結果を参照するだけにする。

```ts
// stores/cart.ts: getterとして切り出し、Vitestで固定できる
export const useCartStore = defineStore('cart', {
  getters: {
    isEmpty: (state) => state.displayItems.length === 0,
  },
})
```

```ts
// View側は判定結果を参照するだけ（Viewのロジック自体はテスト不要）
onMounted(async () => {
  await cartStore.fetchCart()
  if (cartStore.isEmpty) router.replace('/cart?reason=empty-checkout')
})
```

> **背景（Sprint 10 #7）**: AC-neg1（空カート進入不可）で採用。`isEmpty`getterを`cart.spec.ts`で固定し、
> `CheckoutView.vue`自体は無テストのままACの正しさを担保した。

### コミット前は選択addを徹底する（`npm run format`のCRLFノイズ対策・2回ルール昇格）

`npm run format`（Prettier）はワーキングツリー全体を走査するため、**今回編集していないファイルの
改行コード（LF→CRLF）まで意図せず書き換え**、`git status`に無関係な差分として大量出現することがある。
format実行後は必ず以下の手順でコミット対象を絞ること。

```bash
# 既定の core.autocrlf=true 設定では、改行コードのみの差分は自動的に正規化されて
# diffstatに出てこない。これで「本当に内容が変わったファイル」だけを特定できる。
git diff --stat
git add <実際に変更したファイルのみ>
```

`git add -A` / `git add .` は使わない。`git status`に大量のファイルが並んでいても、`git diff --stat`の
出力に無いファイルは改行コードのみの差分（内容差分ゼロ）なので、addせず放置してよい。

> **背景（Sprint 14・15・17・18で4回連続発生）**: 恒久対策（`.gitattributes`による改行コード正規化の
> 強制）は別途Issue化を検討中。本項目はそれまでの運用面の緩和策として、コミット前チェックの必須手順に
> 昇格した。

### jsdom/Vitestで再現できないブラウザ固有挙動は、headless Chrome + 生CDPで実機検証する

Vue Routerのinstall時初期ナビゲーションの順序問題（#33）のように、**jsdom/Vitestでは完全に再現できない
実ブラウザ固有の挙動**を検証する必要がある場合、Playwright/Puppeteer等のパッケージインストールなしで、
headless ChromeをChrome DevTools Protocol（CDP）経由で直接操作できる。

```bash
# 1. headless Chromeをリモートデバッグポート付きで起動
chrome.exe --headless=new --remote-debugging-port=9333 --user-data-dir=<tmp-profile-dir>
```

```js
// 2. Node.js 22+ のネイティブ WebSocket でCDPに直接接続する（追加パッケージ不要）
const tab = await (await fetch('http://127.0.0.1:9333/json/new?about:blank', { method: 'PUT' })).json()
const ws = new WebSocket(tab.webSocketDebuggerUrl)
// Page.enable / Runtime.enable / Network.enable → Page.navigate + Page.loadEventFired待ち →
// Runtime.evaluate(awaitPromise: true) でDOM操作（フォーム入力・click・location確認）まで行える
```

**検証の妥当性は「修正前のコードに戻して同じ手順を実行し、Issue記載の再現手順どおりにバグが再現すること」
を先に確認してから「修正後は解消すること」を確認する2段構えで担保する**（`git stash`で一時的に元へ戻す）。
これにより、テスト自体が意図通りバグを検出できることを裏取りしてから回帰ガードとして採用できる。

> **背景（Sprint 18 #33）**: PO傾向メモ「SPA保護ルートの実機到達性がAC/受入検証から漏れやすい」に対応する
> 技法として即時反映。ログイン→保護ルートへのハード直リンク/リロード→リンククリックまで、実ブラウザの
> V8エンジン上で検証できた。

### 共通レイアウトへ新規のインタラクティブ要素を追加する際はfind('button')/find('form')衝突を確認する（2回ルール昇格）

`AppHeader.vue`/`AppLayout.vue`等の共通レイアウトコンポーネントへ新規の`<button>`/`<form>`を追加すると、
そのレイアウトを使う**既存View群のテストが汎用セレクタ（`wrapper.find('button')`/`wrapper.find('form')`）で
意図しない要素にヒットする**ことがある（DOM順序上、新しく追加した要素が対象Viewの要素より先に現れる場合に
発生）。新規のフォーム・ボタン等を共通レイアウトへ追加する際は、そのレイアウトを使う既存View群のテストで
汎用セレクタが使われていないか確認し、見つかった場合は対象View固有のクラス名でセレクタを明示化する。

```ts
// NG: 複数のbuttonが存在する画面で意図しない要素にヒットしうる
const button = wrapper.find('button')

// OK: View固有のクラス名でスコープを明示する
const button = wrapper.find('button.item-detail-view__add-to-cart')
```

```vue
<!-- 対象コンポーネント側にも明示クラスを付与しておく -->
<button type="button" class="jps-btn jps-btn-primary item-detail-view__add-to-cart">
  {{ t('catalog.item.addToCart') }}
</button>
```

> **背景（2回ルールによる昇格）**: Sprint7（#2）でヘッダに検索用`<form class="jps-search">`を追加した際、
> `SignonView.spec.ts`の`wrapper.find('form')`が検索フォームにヒットし誤動作した（`form.signon__form`で
> 解消）のが初出。Sprint19（#36）で、`AppHeader.vue`にテーマ設定ドロップダウンのtriggerボタンを追加した際、
> `ItemDetailView.spec.ts`の`wrapper.find('button')`が新しいtriggerボタンにヒットし、Add to Cartボタンの
> クリック・disabled判定テストが複数誤動作した（`item-detail-view__add-to-cart`で解消）のが2回目の発生。
> 新規のインタラクティブ要素を共通レイアウトへ追加する作業の**チェックリスト項目**として昇格した。

### 複数の横断設定値を扱う共有Piniaストアはapply primitiveを個別化し、FOUC対策は必要な項目にのみ適用する

テーマ・言語のように「同じ永続化・DB権威再水和の仕組みを共有するが、適用先（DOM操作 / リアクティブ参照）が
異なる」複数の設定値を扱う場合、**永続化・DB同期のロジックは1本の共有Pinia storeに集約**しつつ、
**各値をどう画面へ適用するか（apply primitive）は値ごとに個別の関数として分離**する。

```ts
// stores/preferences.ts: 共有部分(state/localStorage/hydrateFromDb)は1本、適用は値ごとに分離
function applyColorScheme(value: ColorScheme): void {
  document.documentElement.classList.remove('dark', 'light') // DOM操作
  if (value === 'light' || value === 'dark') document.documentElement.classList.add(value)
}
function applyLanguage(value: Language): void {
  i18n.global.locale.value = value // vue-i18nのリアクティブ参照
}
```

**FOUC（Flash of Unstyled/Unlocalized Content）対策も値ごとに要否が異なる**。CSSクラス切替のように
「初回描画が終わってから適用すると一瞬デフォルト状態が見える」項目は`index.html`の同期インラインhead
scriptで初回描画前に適用する。一方、`createI18n()`の`locale`オプション自体をlocalStorageからseedできる
項目（i18nのlocaleのように、値がテキスト描画に反映されるのがVueマウント後のみ）はhead script無しでも
ちらつきが起きないため、モジュール初期化時のseedのみで足りる。

```ts
// i18n/index.ts: createI18n時にlocalStorageからseed（head script不要）
const i18n = createI18n({ locale: loadLanguage(), messages: { en, ja }, ... })
```

新規の共通dropdown/menu部品（open/close・click-outside・aria/keyboard対応）を設計する際は、選択肢
（`{value, label}[]`）とmodelValueを受け取る汎用propsにし、複数の設定項目（テーマ・言語等）で同一部品を
再利用する。挙動はVitestで直接検証する（`attachTo: document.body`でmountしdocumentへの実クリック/keydown
イベントでclick-outside・Escapeを検証できる）。

> **背景（Sprint19 #36/#25、初出だが「知らないと書けない参照知識・実装パターン」の2回ルール例外として
> 即時反映）**: テーマ（`.dark`/`.light`クラス切替・FOUC対策あり）と言語（`i18n.global.locale`・FOUC対策
> 不要）を`usePreferencesStore`（単一ソース）に共存させた際に確立した設計。新規共通部品`SettingsDropdown.vue`
> はテーマ3択・言語2択の両方でそのまま再利用できた。詳細は`memory/dev/long_term.md`「習得したこと」
> （jpetstore-frontend）参照。

---
