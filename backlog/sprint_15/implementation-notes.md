## #28: [E2] カートマージの N+1 クエリをバッチ取得に改善する（refactor）

### 仕様外の判断・変更・妥協点

- **`CartRepository#findStocks(cartId, itemIds)` の空リスト短絡**: `itemIds.isEmpty()` の場合は
  `CartCustomMapper#selectItemsForCart` を一切呼ばず `Map.of()` を即返す（`MyBatisCartRepository`）。`IN ()`
  という不正SQLを避けるための実装上の必須処理であり、AC本文には明記が無いが「マージ処理のクエリ回数がカート行数に
  比例しない」というACの精神（余分な空クエリを飛ばさない）にも合致する。
- **重複 itemId の coalesce（合算）方式で挙動不変を担保した**: バックログ前提の訂正（DEV計画フェーズで発見）により、
  localStorage は itemId キーの map ではなく `StoredCartLine[]` 配列で、dedup はクライアント側の書込ロジックが
  担保し読込時はしない。正規UI経由では重複 itemId は生じないが、localStorage 改竄で重複を仕込むと単純なバッチ版
  （coalesce せず itemId ごとに最後の行だけ処理する等）は逐次 accumulate と異なる結果（last-write-win 化）になり
  得る。`CartApplicationService#merge` 冒頭で `clientLines` を itemId 単位に合算してから 1 回だけ
  `Cart#mergeLine` を適用する設計にし、逐次処理との厳密パリティを担保した。
- **coalesce の合算自体にもオーバーフロー保護を入れた**: 単純な `quantity + quantity` は生の int 加算のため、
  攻撃者が同一 itemId に 2 行以上の巨大な quantity（例: 各々 `Integer.MAX_VALUE` 近傍）を送ると、合算段階で
  サイレントに負値へ wrap しうる。これを `mergeLine` に渡すと `requestedQuantity<=0` として誤って
  `IllegalArgumentException`（400）になってしまい、逐次処理（`Cart#mergeLine` 内の
  `Math.addExact`＋オーバーフロー時は在庫数へクランプ）と異なる挙動になる。そのため coalesce の加算は
  `Math.addExact` を使い、オーバーフロー時は `Integer.MAX_VALUE`（事実上無制限の需要）へ飽和させる
  `addSaturating` を新設した。`Cart.mergeLine` 自体は無改修。
- **挙動パリティの数学的根拠（クランプの単調性）**: 在庫クランプは `min(combined, stockQuantity)` という単調非減少
  関数のため、二重の逐次適用（1個ずつ加算→都度クランプ）と一括適用（合算してから1回だけクランプ）は同じ最終値に
  収束する。具体的には、逐次処理の途中でクランプが発動した場合（`combined1 > stock` で `clamped1 = stock`）、
  以降の行を加算しても `stock + q2 > stock`（`q2>0`）のため次のクランプも常に `stock` に張り付き、coalesce 側の
  最終合算値も同じ理由で `stock` を超えるため結果は一致する。クランプが未発動の場合は両者とも単純な合計値になり
  自明に一致する。オーバーフロー（`Math.addExact` の例外捕捉）についても、逐次側・coalesce 側のいずれで発生しても
  最終的に `stock.stockQuantity()` へ収束することを個別ケース分析で確認済み（新設テスト
  `#28: 重複itemIdの合算が在庫を超える場合は在庫数にクランプする` 等で境界値を検証）。
- **quantity≤0 の fail-fast 検証は coalesce・findStocks より前**: `merge` 冒頭で `clientLines` の全行を検証し、
  1行でも `quantity<=0` があれば例外を投げて `findStocks`/`upsertItem` を一切呼ばない（既存挙動を維持。#5
  AC2・計画フェーズ確定②）。合算後の値ではなく個々のクライアント入力行を検証する点は変更していない（合算後は
  正の値になり得る不正入力も、個々の行の時点で拒否する）。

### 退行ガード結果

- `CartApplicationServiceSpec`（Mock・N行 merge で `findStocks` 1回・`findStock`(単数) 0回・重複合算パリティ・
  quantity≤0→400・未知itemId無視）、`MyBatisCartRepositorySpec`（`selectItemsForCart` 1回・空リスト非呼出）、
  `CartCustomMapperSpec`（実DB・複数itemIdの一括取得・存在しないitemIdの除外）、`CartControllerSpec`
  （既存E2Eテスト無改修のままグリーン）をすべて追加/更新し、`./gradlew test`・`./gradlew integrationTest`
  いずれもgreen。
- 単一 `CartRepository#findStock` は add/update ユースケースが引き続き使用するため残置（バッチ化対象外）。
  `Cart.mergeLine` は無改修。

---

## #11: [E3] 無認証 remoting/WS の getOrder を廃止し認証必須REST に置換する（security）

### 仕様外の判断・変更・妥協点

- **リファクタ/削除対象コードは存在しない（構造的解消）**: `build.gradle` に Hessian/Burlap/HttpInvoker/Axis/
  spring-remoting/JAX-WS 依存は無く、`src` 全体を grep しても remoting/WS 系クラス・アノテーションは一切出現しない
  （Refinement 時点で既に不在）。よって本Storyの成果物は新規実装・削除ではなく「回帰テストによる固定」と
  「明文化」の2点のみ。
- **Spring 6+ で `org.springframework.remoting.*` のエクスポータ階層自体が撤去済みのため、
  「Springコンテキストに該当Beanが登録されていないこと」を assert する方式は使えない**（型参照ができない）。
  代わりに `Class.forName(fqcn)` が `ClassNotFoundException` になることを直接 assert する plain Spock
  （Spring context 不要）を採用した。これは Sprint4 の SBD-9（sink 不在を回帰テストで固定）と同型のパターン。
- **明文化は `presentation/rest/package-info.java` を新規追加する形にした**（ADR形式ではなくJavadocパッケージ
  コメント）。既存コードベースに ADR ディレクトリの慣習が無く、パッケージ境界の説明としてはpackage-infoが
  最も自然な置き場所と判断した。

### 退行ガード結果

- `RemotingSurfaceAbsenceSpec`（7クラス×`Class.forName`→`ClassNotFoundException`）は `./gradlew test` でgreen。
  将来これらのクラスが依存追加等でclasspathに混入した場合、本specが赤化し退行を検知する。
- 新規実装・`SecurityConfig` の変更は無し。AC2（channel-independent 認可）・AC-neg2（IDOR不可）は既に #9/#10
  （`OwnershipAuthorizationService`・`CurrentUserProvider`）で実証済みのため、今回はテスト・明文化の追加のみ。

---

## #12: [E3] 支払をプレースホルダ化し実カード情報を保持しない（feature、frontend主+backend従）

### 仕様外の判断・変更・妥協点

- **孤立カード型残骸（backend `domain/enums/CardType.java`・frontend `constants/code.constants.ts` の
  `CARD_TYPE`/`CardTypeCode`/`CODE_TYPE.CARD_TYPE:'0002'`）は撤去せず両 repo とも温存に確定した
  （計画時点の初期方針=撤去から、DEV精読を経て第2ラウンドで温存へ改定）。**
  - backend: `CardType.java` は `EnumGenerator` が `m_code` の `code_type=0002` から自動生成する生成物。
    m_code 0002 自体は温存確定（database ノータッチ・cross-repo回避）のため、`CardType.java` を手で削除しても
    `./gradlew generateEnums`（手動タスク）の次回実行で再生成され、削除が非永続かつ「生成物を手編集した」
    という誤解を招く。
  - frontend: `constants/code.constants.ts` の `CARD_TYPE` 等も同様に `jpetstore-database` の
    `MultiEnumGenerator`（`generateEnums`）が m_code 0002 から生成する生成物。`src/constants/README.md` が
    「手編集しない・再生成で上書きされる」旨を明記しており、`jpetstore-database/build/generated/frontend/
    code.constants.ts` と実ファイルがバイト一致することも確認した。手編集での撤去は README の運用規約
    （手編集禁止）に反するうえ、次回生成で復活し撤去が意味を成さない。
  - 結果、**両 repo ともカード型の実削除はゼロ**。カード情報は実際には一切保持/処理しない（backend の
    DTO/API/DB にカード列・項目は存在しない。#22 完了時点で既達）ため、残存する型/定数自体は単なる区分マスタの
    生成物であり実害は無い。`EnumGenerator`/`MultiEnumGenerator` 側に0002除外ロジックを新設することも
    「新機構の追加」でスコープ外のため行っていない。
- **frontend のプレースホルダ文言**: `checkout.confirmStep.paymentPlaceholder` を
  `"Payment details will be added in a future update."`（将来追加のニュアンス）から
  `"This demo does not collect or store card details."`（実カード情報を扱わないことの明示）へ変更した。
  ID-8（意図差分台帳）の「実カード情報を保持/処理しない意図的な非等価変更」という意図に文言を一致させるための
  変更で、ロケールは `en.ts` の1つのみ（`ja` ロケールファイル自体が存在しないため追随不要）。
- **独立した payment ステップ/画面は新設しない**（計画確定）: `CheckoutConfirmStep.vue` の確認ステップ内に
  既にプレースホルダ表示（#7/#8 で既達）があり、カード入力欄・DTO/API/DBのカード項目も元々存在しないため、
  今スプリントの追加実装は文言変更と回帰テストのみに留めた。

### 退行ガード結果

- frontend: `CheckoutConfirmStep.spec.ts` 新規（pinia/i18n/memory routerでマウント）。新プレースホルダ文言の
  描画と、payment セクション（`.checkout-confirm-step__payment-placeholder` の祖先 `<section>`）に
  `<input>` が存在しないことを assert。`npx vitest run` で全19ファイル166テストgreen。
- backend: `OrderControllerSpec` に2件追加。(1) `creditCard`/`cardNumber`/`cardType`/`expiryDate` を
  余分なJSONフィールドとして送っても 201 で成功すること（Jackson3の未知プロパティ無視既定＋DTOにカード項目が
  無い構造で自動的に無視される）。(2) 応答JSON文字列に `card`/`credit` を含む文字列が一切出現しないこと
  （小文字化した生レスポンスボディを走査）。既存の `totalPrice`/`username` 注入無視テストと同じ
  `placeOrderBody(extraJson)` ヘルパーパターンを踏襲した。`./gradlew test integrationTest` green。

---

## 横断

- cross-repo 2-repo（backend・frontend）。database は完全ノータッチ（m_code 0002 温存によりマイグレーション
  追加不要）。
- ブランチ `feature/12-e3-hardening-cart-perf` を backend・frontend 両 repo に同名で作成し、Issue単位のコミット
  （#28→#12 frontend→#11→#12 backend、TDD/実装順）を1ブランチに集約した（Sprint55確立の1ブランチ集約方針）。
