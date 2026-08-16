# intended-diff-ledger — 意図差分台帳（旧と"違ってよい／違うべき"の宣言）

> **所有**: PO（レビュー承認を経て確定）。**生きた文書** — Story 起票/Refinement で「振る舞いを変える」と判断したら**必ず追記**する。
> **役割**: AI Factory は 1:1 再現ではなく仕様源からの作り直し。ゆえに「旧と違う＝バグ」の誤解を断つため、**変える差分をここで宣言**する。
> **判定規範**: Phase 4 L4 で実測された差分は**すべて本台帳に載っていること**が合否ゲート（[`verification-strategy.md`](./verification-strategy.md) §4・§5）。**台帳に無い差分＝要調査（欠陥候補）**。
> **由来**: [`verification-strategy.md`](./verification-strategy.md) §4 雛形（ID-1〜7）＋本 Refinement の決定＋[`reports/before/baseline-summary.md`](../reports/before/baseline-summary.md) findings（R#=Spring MVC run / S#=Struts run）。
> **関連**: [`architecture-conventions.md`](./architecture-conventions.md)（D6 並行制御）／[`security-baseline.md`](./security-baseline.md)（SBD）／[`backlog-map.md`](./backlog-map.md)。

## 台帳（intended diffs）

| # | 旧の振る舞い（as-is） | 新の振る舞い（after） | 理由 | 由来 | 関連Story |
| --- | --- | --- | --- | --- | --- |
| **ID-1** | 在庫ガード無し減算（`qty=qty-n` 無条件）＝売り越し・マイナス在庫可 | `qty>=n` ガード付きアトミック減算・在庫不足で注文失敗 | 売り越し防止 | D6 / SBD-2 | #8 |
| **ID-2** | パスワード平文保存・平文比較 | ハッシュ＋ソルト保存・照合 | 資格情報保護 | SBD-5 / S7,R5 | #19, #13, #15 |
| **ID-3** | 金額 `double`（丸め誤差の余地） | `BigDecimal` / `decimal` | 丸め正確性 | SBD-13 | #8, #10, #22 |
| **ID-4** | 連番 orderId で他人注文参照可（IDOR）＋ identity-rebind でセッション汚染 | サービス層認可（プリンシパル基準）＋ not-owned/not-found を同一応答（or 不透明ID） | アクセス制御・列挙封じ | SBD-1 / SBD-8 / S3,S15,R2 | #9, #10, #14, #21 |
| **ID-5** | Hessian/Burlap/HttpInvoker/Axis remoting 面（無認証 `getOrder` 総当り含む） | 廃止（REST・認証必須のみ） | 攻撃面除去 | SBD-7 / S1,S13,S14,S16 | #11, #23 |
| **ID-6** | JSP / サーバサイドレンダリング | Vue3 SPA＋REST | モダン化 | D1 | 全ドメイン (#1–#24) |
| **ID-7** | banner 広告 / MyList（bannerdata INNER JOIN 依存） | 廃止（bannerdata 除外＝JOIN 依存解消） | スコープ決定 | backlog-map / 決定 2026-08-10 | #13, #22 |
| **ID-8** | 実カード列を永続化・カード欄必須（ダミー処理） | カード列/入力欄/必須検証を撤去・支払プレースホルダ | 機微データ非保持 | F3.6 決定 | #12, #22 |
| **ID-9** | 注文確定が GET リンクで成立（状態変更 GET）・CSRF 全域不在 | 非冪等 POST＋CSRF トークン | CSRF 防止 | SBD-3 / S5,R6 | #8, #6, #16, #18 |
| **ID-10** | ログイン/登録成功時にセッションID 非再生成（固定化） | ログイン/登録時にセッション再生成 | 固定化防止 | SBD-4 / S8,R7 | #18, #13 |
| **ID-11** | 資格情報を GET でも受理・`j2ee/j2ee` プリフィル・ロックアウト無し | POST body 限定・プリフィル廃止・レート制限/ロックアウト | 認証堅牢化 | SBD-6 / S10,S11,R10,R13 | #20 |
| **ID-12** | `forwardAction` を無検証 `sendRedirect`（オープンリダイレクト） | リダイレクト先は allowlist/相対のみ | フィッシング防止 | SBD-9 / S9,R11 | #20 |
| **ID-13** | 現在PW 未確認で PW 変更 | 現在PW 確認/再認証を必須 | 機微操作保護 | SBD-16 / S6 | #15 |
| **ID-14** | stale-session/不正 ID で 500＋スタックトレース露出（3経路） | 404/空へ正規化・trace 非露出 | 情報漏えい防止 | SBD-10 / S18,R9 | #3, #2, #10, #23 |
| **ID-15** | `product.description` の HTML 内包を `escapeXml=false` で描画（格納XSS seam） | plaintext 化＋商品画像は新規アセット（nano banana） | XSS 面除去 | SBD-18 / L1 seam | #1, #3, #24 |
| **ID-16** | 入力検証＝非空＋PW一致のみ | email 形式・最大長・PW 強度（8字以上・複数文字種）を検証 | データ健全性・資格情報強度 | F4.5 決定 / SBD-5 | #17, #15 |
| **ID-17** | カート数量 0/負で `itemMap` desync（幽霊行バグ・再追加で increment） | map/list 一貫の単一削除に正規化 | バグ是正 | cart.md 決定 | #4 |
| **ID-18** | 在庫切れでもカート追加可・数量上限なし | 在庫切れは追加不可・数量上限＝在庫数 | 在庫整合 UX | 細部決定 2026-08-11 | #4, #1 |
| **ID-19** | 未ログインカートはセッションのみ（離脱で消失） | クライアント保持＋ログイン時にサーバーカートへマージ | カート永続 UX | E2① 決定 2026-08-11 | #4 |
| **ID-20** | カタログ一覧 4件/頁・セッション保持ページング | 12件/頁・API ページングパラメータ | UX/モダン化 | 細部決定 2026-08-11 | #1, #2, #9 |
| **ID-21** | `courier=UPS`/`locale=CA` を保持 | courier/locale 撤去（プレースホルダ） | スコープ簡素化 | E3 決定 2026-08-11 | #7, #8, #22 |
| **ID-22** | `status="P"` 固定1行（orderstatus: linenum=orderId 等の異形） | 固定プレースホルダ・状態変更は監査ログに記録 | スコープ簡素化 | E3 決定 / SBD-14 | #8, #22 |
| **ID-23** | orderId 採番が select→+1→update（非アトミック・重複リスク） | DB 原子採番 | 正確性/並行安全 | D6 | #8, #22 |
| **ID-24** | 注文詳細（履歴経由）で明細の商品名が空 | 商品名を表示（非等価改善） | UX 改善 | E3 決定 2026-08-11 | #10 |
| **ID-25** | Axis 管理PW/認証情報をソースに平文・HTTP 平文・Cookie フラグ欠落 | シークレットストア・TLS 前提・Secure/HttpOnly/SameSite | 設定衛生 | SBD-11 / SBD-15 / S17,S19,R15,R16 | #23, #24 |
| **ID-26** | EOL/脆弱依存（Struts1.2.9/Axis1.4/Spring3.1/hsqldb1.8…）・版レンジ未固定 | 保守された現行版・版固定 | 依存健全化 | SBD-12 / S20,S21,R12,R17 | #23 |
| **ID-27** | 多言語＝english/japanese（日英 JSP 同梱） | i18n 基盤（文言外部化）を実装・launch は英語のみ。日本語ローカライズは別バックログ **#25** に切り出し、既存スコープ完了後に実施（m_code は日英データ保有済＝D4） | スコープ決定（段階的ローカライズ） | E4②/E5① 決定 / backlog #25 | #24, #13, #25 |
| **ID-28** | アイテム詳細に在庫状況表示なし（全アイテム qty=10000 固定・残少/在庫切れ概念なし） | 在庫状況を3段階バッジ表示（在庫あり／残少 `0<qty≤5`／在庫切れ `qty≤0`）。qty 自体はレスポンス非露出（status のみ算出返却） | 新規UX（在庫数非公開のまま状況を伝達）・在庫数直接露出の防止 | R3 / 論点2 決定 2026-08-16 | #1 |

## 補足（台帳の対象外）

- **構造スキーマ差分は行動差分ではない**（台帳非対象）: WHO 6列・`version` 列・自動採番ID・`created_at`/`updated_at`・HSQLDB→MySQL は [`verification-strategy.md`](./verification-strategy.md) §3 で L2 比較から**正規化除外**する。意味デルタ（金額/数量/在庫増減/ステータス/関連レコード件数）で比較する。
- **維持項目（＝差分でない・"clean を保つ"）**: SQLi 無（全パラメタライズ・SBD-17）／稼働 JSP 反射XSS 無（SBD-18 の反射面）／カート価格サーバ権威（SBD-2）／ログアウトでセッション無効化／ソース内に実効的秘密なし。→ [`reports/before/baseline-summary.md`](../reports/before/baseline-summary.md) §4 基準線として Phase 4 で「維持」を検証（L2/L3）。台帳には載せない（差分ではないため）。

## 運用

- 追記トリガ: Refinement/起票で「旧と振る舞いを変える」と判断した時。理由と由来（SBD-x / D# / 決定日）と関連 Story を必ず埋める。
- Phase 4: SM/PO が L4 で「実測差分 ⊆ 本台帳」を確認し `reports/after/verification-report.md` に反映。
