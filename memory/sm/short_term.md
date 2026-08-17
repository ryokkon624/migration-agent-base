# SM 短期記憶（今スプリント）

Sprint 12（#29 [E6] Cart を参照実装に Repository 層導入＋集約化＝refactor・SP5・backend 単一 repo）完了。次スプリント開始時にリセット済み。

- 実装: 新規ブランチ `refactor/29-cart-repository-poc`（backend 単一・database ノータッチ）。jpetstore-backend **初の Repository 層導入**（`domain.cart.CartRepository`＋`infrastructure.mybatis.cart.MyBatisCartRepository`＋`CartConverter`）。`Cart`/`CartItem` を record→class 化（`reconstruct()`＋不変条件コマンドメソッド）、`CartApplicationService` は Repository のみ注入で `infrastructure.*` 依存消滅。API・挙動不変・ID-28 型強制。
- 確定した設計（#30 先例テンプレ）: **D1=案A**（単一 rich 型・射影アクセサで stockQuantity 非露出）／**D2=案A**（細粒度 `upsertItem`/`removeItem`＋`findStock`）／**D3**（`findStock` 別解決で #28 バッチ化 seam）。設計方針は memory 合意済のため SM 計画前先出し AskUserQuestion は投げず、DEV 計画報告後に D1/D2 を確定（2段階の後段主体・初出）。
- **品質ハイライト**: 3観点 reviewer 全員クリア（初回 conv/sec、perf は reviewer「指摘なし」）だが、**SM verification（コア7ファイル精読）が perf 純増を独立発見**＝カート書込4操作が `findByUserId` を2回呼び（+2クエリ/操作・冒頭 items 未使用・`ensureCart` 二重）。ユーザー承認で是正（`ensureCart`/`findByCartId` 分離→baseline クエリ数 addItem4/updateItem4/removeItem3/merge2+2N/viewCart2）→delta 3観点再レビュー全員クリア。
- PR: backend **#11**（closes #29）→ **マージ済**（merge commit 2f7ec9e）。Issue #29 自動クローズ。Sprint Review 指摘なし（「問題ありません」）。
- Retro 完了（SM/DEV/PO）。Skills 更新: **SM=変更なし**（2回ルールで long_term 止まり・Sprint3/7/9/11 同型）／DEV=`backend-conventions §9` に2点（Spock then優先の2回ルール昇格／#29 PoC 実装パターン3点を #30 先例テンプレとして即時反映）／PO=質問傾向2件追記（傾向1=既昇格3件目・傾向2=リファクタ起票時の実コード未裏取り初出）・意思決定ログ7件。長期記憶反映済。
- agent-base 成果物: レトロ完了後にブランチ切ってコミット＆PR＆マージ（ユーザー指示・**実施中**）。
- **次スプリント候補**: #30（Repository 層 全体展開・Catalog/Account/Order・Ready/SP8・#29 完了で着手可）＝#29 の2方針を先例テンプレに踏襲。または E3 継続 #9/#10（注文照会・履歴）。PO TODO: #30 Refinement 時に #29 の先例2方針を AC/備考へ反映＋リファクタ起票時の実コード裏取り（傾向2 監視）。
