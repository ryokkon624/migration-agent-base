# nano banana 画像生成プロンプト一覧 — JPetStore モダン版

> 全画像を**同一スタイル**で生成するためのプロンプト集。各プロンプトの先頭に「共通スタイル」を付けて（or 一括指定して）生成する。
> 生成物は `spec/design/images/` に、下記ファイル名で保存 → frontend アセットに流用。

## 共通スタイル（全画像に適用）
```
Style: clean, friendly, modern studio product photo. Single subject centered.
Soft even studio lighting, gentle shadow. Plain warm off-white seamless background (#EFE8DE).
Square 1:1 framing. High detail, photorealistic but approachable. No text, no logo, no watermark, no border.
Consistent look across the whole set (same background, lighting, angle).
```
※ 写真調でなく統一イラスト調にしたい場合は「studio product photo」→「flat vector illustration, soft pastel」に差し替え（全画像で統一）。

---

## A. 商品画像（16枚）— `images/product_<itemId的なproductId>.png`

| ファイル名 | プロンプト（共通スタイル＋以下） |
|---|---|
| `product_FI-SW-01.png` | a bright tropical **angelfish** (saltwater, Australia) |
| `product_FI-SW-02.png` | a small **tiger shark** (saltwater, Australia), friendly not scary |
| `product_FI-FW-01.png` | a colorful **koi** carp (freshwater, Japan) |
| `product_FI-FW-02.png` | a **goldfish** (freshwater, China) |
| `product_K9-BD-01.png` | an English **bulldog**, friendly |
| `product_K9-PO-02.png` | a cute **poodle** |
| `product_K9-DL-01.png` | a **dalmatian** dog |
| `product_K9-RT-01.png` | a **golden retriever**, family dog |
| `product_K9-RT-02.png` | a **labrador retriever** |
| `product_K9-CW-01.png` | a **chihuahua**, companion dog |
| `product_RP-SN-01.png` | a **rattlesnake**, coiled, friendly stylized |
| `product_RP-LI-02.png` | a green **iguana** |
| `product_FL-DSH-01.png` | a **Manx cat** (tailless) |
| `product_FL-DLH-02.png` | a fluffy **Persian cat** |
| `product_AV-CB-01.png` | an **Amazon parrot**, colorful |
| `product_AV-SB-02.png` | a small **finch** bird |

## B. カテゴリ画像（5枚）— `images/category_<CATID>.png`
カテゴリカード/ヒーロー用。代表動物を"少し引き"で、同じ共通スタイル。
| ファイル名 | プロンプト |
|---|---|
| `category_FISH.png` | a group of colorful tropical fish, aquarium vibe |
| `category_DOGS.png` | a friendly happy dog (mixed breed), welcoming |
| `category_CATS.png` | a calm cute cat |
| `category_REPTILES.png` | a friendly green lizard/reptile |
| `category_BIRDS.png` | a colorful pet bird on a perch |

## C. ブランド/ヒーロー
| ファイル名 | プロンプト |
|---|---|
| `hero.png` | wide banner (16:9) — cheerful modern pet shop scene with a few pets (dog, cat, bird, fish bowl), warm inviting, lots of soft empty space for overlay text. No text. |
| `logo.png` | minimal flat logo mark for a modern pet store "JPetStore", a friendly paw/pet motif, simple, works at small size. Transparent background. |

（※ ロゴ・プレースホルダは SVG でも用意可＝くろが作成できる）

## D. その他（任意）
- `placeholder.png` … 商品画像欠落時のフォールバック（淡色・シンプルなペットシルエット）
- `empty-cart.png` / `empty-search.png` … 空状態イラスト（任意）
- `favicon` … ロゴの小サイズ

---

## 使い方
1. 共通スタイル＋各行のプロンプトで nano banana に生成させる（1枚ずつ or バッチ）。
2. 上記ファイル名で `spec/design/images/` に保存。
3. アイテム(28)は商品画像を流用（`itemId` → その `productId` の画像）。
4. Phase 3 の frontend で `product_<id>` / `category_<id>` を参照。
