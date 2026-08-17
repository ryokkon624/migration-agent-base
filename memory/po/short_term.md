# PO 短期記憶（今スプリント）

## Sprint 15 Retro（2026-08-17）で棚卸し済み

Sprint 14 Retro以降の文脈（Sprint15計画フェーズでのDEV→ユーザー確認5件：#11 remoting/WS getOrder廃止の成果物定義・#12 支払プレースホルダ文言/孤立カード型撤去範囲/CardType.java削除永続性・#28 カートマージバッチ化の重複itemId挙動）はSprint 15 Retroで棚卸し済み。要点は `memory/po/long_term.md`（質問傾向へSprint15セクション追記・チェックリストへ1件新規昇格〔Sprint12傾向2「リファクタ/是正Story起票時のスコープが実コード未裏取りでずれる」を、Sprint15 #12（CardType.javaのcodegen生成物由来未確認）・#28（localStorageのデータ構造前提の誤り）の2件の再発を受け、対象を「スコープ」から「前提（データ構造・削除対象の生成物由来等）」まで含む形に拡張して正式昇格〕・既存チェックリスト項目「secure-by-default機構の既存充足確認」へ引用追記1件〔Sprint15 #11・4件目の再発〕・意思決定ログ6件追記）に反映済み。`spec/intended-diff-ledger.md`のID-8記述も強化済み（支払プレースホルダ文言が「扱わない/保持しない」旨を明示する点・孤立型残骸の撤去範囲を追記。Sprint11 RetroのID-22強化と同型の運用）。

### 未解決の判断事項

- #7のAC1（プリフィル住所データ源=backend `GET /api/account/me`・cross-repo新設）・スコープ境界（確定前段=#7／送信・在庫引当・永続化=#8）・ウィザード下書き保持方式（Piniaのみ・揮発）・API命名（`AccountController`等）・空カート誘導UX（`/cart?reason=empty-checkout`）・ルート構成（`/checkout`単一ルート）を、次回RefinementでAC/備考へ反映するかユーザーに確認する。
- #8のAC-neg/AC6/備考へ、Sprint11計画フェーズで確定した5点（在庫競合409・空カート409・完了画面スコープ最小化・価格変動時再計算値確定・監査ログ成功/失敗両方記録）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- 確認メール（#8備考）を独立の将来Feature Issue として NotReady で track するか（現状は #8 備考に記録のみ）。
- #23のAC/備考への先回り明記（スコープ境界・実証手段・監査ログ範囲・秘密管理方針・他repo連携方式）は次回Refinementでユーザーに確認のうえ反映する（Sprint2 Retro以降継続未着手。#23は実装済みのため優先度低）。
- #8 の SP=8 は本移行の目玉Story（同時/二重発注の売り越し防止テスト等）で見積り上振れリスクあり。実装フェーズで並行テスト負荷が重いと判明すれば13への引き上げを検討する。
- #1のAC3/備考へ、Sprint6計画フェーズで確定した3点（残少閾値N=5・在庫ステータスm_code方式・ページ1-index）を反映するかは次回Refinementでユーザーに確認のうえ判断する（現状は`sprint_backlog.md`承認済み計画セクションのみに反映）。
- #2のAC1「カテゴリフィルタは任意（PO決定）」の確定値（今スプリントで実装＝API `categoryId`任意＋UIカテゴリ選択）と、検索語LIKEメタ文字（`%`/`_`）のハードニング仕様（リテラル化・ESCAPE併用）をAC/備考へ反映するかは次回Refinementでユーザーに確認のうえ判断する（`spec/intended-diff-ledger.md`のID-29登録はSprint7 Retroで完了済み。Issue #2本体のAC/備考更新のみ未着手）。
- #4のAC5/AC-neg1または備考へ、未ログインカートの在庫上限検証手段（`GET /api/items/{itemId}/orderable?quantity=N`・qty非露出維持）を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD1で決定）。
- #4のAC3備考へ、カート画面ルートが公開（`meta.requiresAuth`なし）・認証必須は`/api/cart/**` APIのみである旨を次回Refinementでユーザーに確認のうえ反映する（Sprint8計画フェーズD2で決定）。
- #29のAC1/備考へ、Sprint12計画フェーズで確定したD1（集約の型戦略＝単一rich型・`stockQuantity`はprivate内部保持＋外向きは射影アクセサのみ公開）・D2（Repository書込メソッド粒度＝細粒度`upsertItem`/`removeItem`をドメイン語彙メソッドで残す）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- #30のAC/方針欄へ、Sprint13計画フェーズで確定したQ1（Order集約=richな集約を新設せず#8のorchestrationをOrderApplicationServiceに残す。方針欄「#29の集約パターンに準拠」の文言を是正）・Q2（read/write Repositoryは統一`...Repository`命名。`...Query`分離は不採用）・Q3（`InventoryRepository`は新規`domain/inventory`パッケージ）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- #9のAC/備考へ、Sprint14計画フェーズで確定した索引方針（ページング用複合索引`(user_id, order_id)`を`t_order`に追加し、既存単一索引`idx_t_order_user_id`は置換=DROPして重複索引を残さない）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- #11のAC/備考へ、Sprint15計画フェーズで確定した成果物定義（remoting面の構造的な既達＝回帰テスト＋明文化で固定）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- #12のAC/備考へ、Sprint15計画フェーズで確定した3点（支払プレースホルダ文言を「扱わない」明示に変更／孤立カード型enum・定数のみ撤去しDB m_code 0002は温存／backend `CardType.java`はcodegen生成物のため削除しない旨の注記）を反映するかは次回Refinementでユーザーに確認のうえ判断する。
- #28のAC/備考へ、Sprint15計画フェーズで確定したバッチ化の重複itemId挙動保持方針（coalesceで挙動不変を厳守）と、バックログ前提記述の訂正（localStorageは配列であり itemIdキーmapではない）を反映するかは次回Refinementでユーザーに確認のうえ判断する。

### 次回PO稼働時のTODO

- 残りの Ready昇格＋SP付与: #13〜#17（E4）＋#26（E6依存版currency）。#27（refactor・SP1・Draft）はスプリント差し込み時にReady昇格。**#13〜17（E4）Refinement 時は「新規 Story は Repository 経由で実装」の運用ルール（2026-08-17決定）を各 Issue の AC/備考に反映すること。**
- E3継続（#9/#10 注文照会・履歴）が次スプリント候補。#29/#30でRepository層全展開が完了したため、**#9/#10 Refinement時も「新規StoryはRepository経由で実装」の運用ルール（2026-08-17決定）をAC/備考に反映すること。**
- #30のRefinement時、#29計画フェーズで確定した先例規約2点（集約の型戦略＝単一rich型・`stockQuantity`はprivate内部保持＋外向きは射影アクセサのみ公開／Repository書込メソッド粒度＝細粒度`upsertItem`/`removeItem`をドメイン語彙メソッドで残す）をAC/備考に反映できないか確認する。
- 確認メール（#8備考）の将来Feature化（Issue起票 or ドロップ）の判断。
- #23のAC/備考へ、Sprint2質問ログで判明した5観点（スコープ境界・実証手段・監査ログ範囲・秘密管理・他repo連携）を反映（着手可否含め次回Refinementで判断）。
- 振る舞いを変える新判断が出たら都度 `spec/intended-diff-ledger.md` への追記要否を判定する（Sprint6はID-28、Sprint7はID-29、Sprint8はID-19具体化、Sprint10はID-30を追記済み・Sprint9は追記なし〔SBD-2/17は既存維持項目のため台帳対象外と判定〕・Sprint11はID-22の説明強化のみ追記〔新規差分IDの追加なし〕・Sprint12は台帳追記なし〔#28〜30/D1/D2はいずれもAPI仕様・レスポンス形状に影響しない内部実装リファクタと判定〕・Sprint13は台帳追記なし〔#30はQ1〜Q3含めAPI仕様・レスポンス形状不変の内部リファクタと判定〕・Sprint14は追記なし・Sprint15はID-8の説明強化のみ追記〔新規差分IDの追加なし。#28は挙動不変のためAC上も台帳対象外と判定〕）。
- architecture-conventionsのPO判断委譲パターン（§3.1区分値のm_code採用・§4.3更新系エンティティのversion列・§9集約深度）は3セクションで再発しチェックリストへ正式昇格済み（Sprint8 Retro。Sprint13 #30・§9で3件目の実例追加）。architecture-conventions文書自体の一般原則firmup（個別確認を減らす明文化）要否は、さらなる再発またはユーザーとの次回接点で判断する。
- Sprint7傾向3（specがPOへ確定を委譲した論点の計画フェーズ確認）は初出のため、次回以降の同種発生時に正式昇格を判断する。
- Sprint11傾向2（監査ログACの成功/失敗粒度未定義）は初出のため、次回以降の同種Story（監査ログを扱うStory）で再発した場合、正式昇格を判断する。
- Sprint15傾向3（intended-diff-ledgerとの整合確認対象をUI表示文言のニュアンスへ拡張できないか）は初出のため、次回以降の同種発生時（既存ledger決定とUI表示文言のニュアンスの不整合）に正式昇格を判断する。

## SMやDevから受けた質問ログ

| 日付 | 質問者 | 質問内容 | 対応 | バックログ修正が必要か |
|---|---|---|---|---|
