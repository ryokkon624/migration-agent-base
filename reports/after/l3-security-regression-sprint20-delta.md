# Phase 4 L3 — Sprint 20 セキュリティ修正の差分回帰検証（jpetstore-backend）

> **目的**: Sprint 20 のセキュリティ修正（#38/#39/#40/#41）によって **新たな脆弱性が作り込まれていないか**を、差分スコープで検証する。全体再スキャンは行わない。
> **担当**: SEC（security-lead）／ **日付**: 2026-08-20 ／ **run**: `security/20260820_01/`
> **スコープ**: `jpetstore-backend` のコミット `73c8d13^1..73c8d13`（44 files, +1798/-251。うち `src/main` は 17 files, +609/-185）
> **手法**: 発見（Discovery）と検証（Verification）を分離。Discovery は攻撃面ごとに4並列、Verification は3ペルソナの独立判定＋多数決。
> **校正の枠組み**: [`spec/security-baseline.md`](../../spec/security-baseline.md)（SBD-1〜18）を満たすべき NFR、[`spec/intended-diff-ledger.md`](../../spec/intended-diff-ledger.md)（ID-1〜31）を「仕様どおりの変更＝脆弱性ではない」の宣言として使う。
> **前提**: 前回 run [`l3-security-regression-backend.md`](./l3-security-regression-backend.md) の N1〜N16 のうち #38〜41 が対象にしたものは regression spec 化済みのため再検証しない（§1 の `integrationTest` 結果で足りる）。既知所見の再掲もしない。

---

## 全体結論

| 区分 | 結果 |
| --- | --- |
| **#38〜41 の回帰テスト** | `./gradlew integrationTest` **BUILD SUCCESSFUL / 225 tests・failures 0・errors 0・skipped 0**（§1） |
| **差分で新たに作り込まれた脆弱性** | **Critical / High は 0件**。多数決で確定したのは **Low 4件**（§4.1）と Informational 群（§4.2）のみ |
| **Discovery の候補が検証で落ちたもの** | **8件を REFUTED**（うち1件は「実装の方が正しい」＝Discovery の枠組み自体が誤り）＋ 5件を Informational へ格下げ（§4） |
| **レッドチームが実際に攻撃を構築できたもの** | **S20-1 のみ**（他は「運用者の設定ミス依存」「pre-existing」「攻撃者制御のトリガ無し」で武器化不能） |
| **総合判定** | **差分は概ね clean**。#38〜41 は意図した脆弱性（N1〜N4）を実際に塞いでおり、新規に持ち込まれたのは運用・監査品質レベルの Low 所見に留まる |

**「概ね clean」と書いた理由**: 完全な clean とは書けない所見が4件（Low）残るため。ただし **攻撃者が単独で成立させられるのは S20-1 のみ**で、残る3件は「攻撃者制御のトリガが存在しない（S20-4）」「独立したプール枯渇が前提（S20-3）」「pre-existing 構造の増分（S20-2）」であり、Sprint 20 の修正を差し戻す理由にはならない。

---

## §0 手法と実行メタ

### Discovery（発見・4並列）

`security-scanner` を4攻撃面に並列起動。各ワーカーには差分全文・重点ファイル・SBD/ID 台帳・前回 N 所見（「既知の再掲ではなく、その修正で新しく生まれた問題を探せ」という指示付き）を渡した。

| 攻撃面 | 出力 | 候補 |
| --- | --- | --- |
| 監査 write 抑止 quota（新設の抑止機構そのもの） | [`discovery/audit-quota-suppression.md`](../../security/20260820_01/discovery/audit-quota-suppression.md) | 4件（Medium 1 / Low 3） |
| レート制限の原子化（条件付き UPDATE） | [`discovery/ratelimit-atomization.md`](../../security/20260820_01/discovery/ratelimit-atomization.md) | 5件（Medium 3 / Low 2） |
| 例外ハンドリング／エラー応答／注文失敗監査 | [`discovery/error-exposure-order.md`](../../security/20260820_01/discovery/error-exposure-order.md) | 4件（全 Low） |
| JWT 鍵ポリシー／秘密管理 | [`discovery/jwt-secret-policy.md`](../../security/20260820_01/discovery/jwt-secret-policy.md) | 5件（Medium 2 / Low 3） |

**収束（convergent）**: 独立した2ワーカーが同一根本原因を発見したものが2組あった（後述 S20-1・§4.2 の過大長 username）。収束は信頼度を上げる材料として扱った。

### Triage

18候補を根本原因で重複排除 → **14候補（V1〜V14）** に統合し、[`verification/candidates.md`](../../security/20260820_01/verification/candidates.md) にまとめた。SEC 側で先に確定させた事実（§0 末尾）も判定の前提として同梱している。

### Verification（多数決・3ペルソナ独立）

`security-verifier` を3体、異なるペルソナで起動。**互いの結論は見せていない**。

| ペルソナ | 立場 | 出力 |
| --- | --- | --- |
| 懐疑的監査者（skeptic） | デフォルト REFUTED。到達可能な具体手順が引けるものだけ CONFIRMED | [`verification/skeptic.md`](../../security/20260820_01/verification/skeptic.md) |
| 保守者（defender） | 誤検知・過大評価・スコープ外を最大限主張。守れないものは素直に CONFIRMED | [`verification/defender.md`](../../security/20260820_01/verification/defender.md) |
| レッドチーム（red-team） | 最短の攻撃手順を組み立てる。面をまたぐ連鎖も探す | [`verification/red-team.md`](../../security/20260820_01/verification/red-team.md) |

red-team の出力は初回時点でディスク上 9,906 bytes（判定サマリ表まで）で、SEC からの再依頼後に 28,041 bytes へ拡張された。red-team 自身は「元から全文あった」としており、初回時点でどちらだったかは確証がない（多数決は完成した判定サマリ表に基づいており影響しない）。**内容面では完成版で V2(a)・V11 の判定が改訂**され、面をまたぐ連鎖が R-1〜R-4 として独立項目に書き起こされた。本書は完成版を採用している。

### ライブ PoC（S20-1 のみ実施・ユーザー承認済み）

Discovery / Verification フェーズは稼働 backend 停止中のため**コード解析＋既存テスト資産＋読み取り専用の DB スキーマ確認**で判定した。その後**ユーザー承認を得て S20-1 のみライブ PoC を実施**し、**CONFIRMED(live)** で確定した（[`verification/poc-s20-1.md`](../../security/20260820_01/verification/poc-s20-1.md)）。

**実測サマリ**: 未認証 `GET /api/cart` を100回（約6秒・資格情報不要）で quota を焼き切り、その後 CSRF 正常な誤 password ログインを4つの異なる username へ送ったところ、**4件とも 401 でありながら `t_audit_log` に1行も記録されず**（`suppressed_count` は 4 に加算）、per-username 閾値（5回/15分）にも触れないため**ロックアウトも発火しなかった**。同時に、格下げ根拠である残存証跡（`suppressed_count` の正確な加算・`t_login_attempt` への username 別記録）も実測で確認している。PoC で作成した状態は全て実行前へ復元済み（`t_audit_log`/`t_audit_write_quota`/`t_login_attempt` とも 0 行・アカウント2件と注文0件は無傷）。

S20-2 のプール枯渇 PoC は**未実施**（稼働機への負荷試験になるため。§6-1）。

### SEC が判定の前提として実測した事実

- `./gradlew integrationTest` = BUILD SUCCESSFUL / 225 tests・failures 0・errors 0・skipped 0
- 稼働 dev `.env` の `JWT_SECRET` は 64byte・distinct 43。**リポジトリ既知リテラル3種（`TestJwtSecrets.STRONG` / `.env.example` placeholder / `LOW_ENTROPY`）のいずれとも sha256 不一致**（値は出力せずハッシュのみ照合）→ **N1 は実環境でも解消済み**
- `RegistrationApplicationService.register` の `@Transactional` と `RegisterAttemptService` の `REQUIRES_NEW` は**差分前から存在**（`git show 73c8d13^1` で確認）
- `LoginAttemptService` は**差分前は `@Transactional` 無し**・ロック判定は行ロックを取らない `SELECT COUNT(*)` だった
- `application.yml` に HikariCP のサイジング設定は**無い**（Spring Boot 既定 = maximum-pool-size 10）。`src/test` では `RateLimitBurstConcurrencySpec` **のみ**が 50 に引き上げている
- `t_login_attempt.username` と `m_account.username` は**同一照合順序** `utf8mb4_ja_0900_as_cs`
- `AuditProgramInterceptor.java:46-57` により `create_program` は常に補完され（`ProgramContext` か `"SYSTEM"`）、攻撃者制御外
- `backlog/sprint_20/sprint_backlog.md` Q2 の計画 SQL には `AND failed_attempt_count < :maxAttempts` が**あり**、実装の WHERE には**無い**（→ §5-1 で「実装の方が正しい」と判明）

---

## §1 #38〜41 の回帰テスト結果（指示2）

```
> Task :integrationTest
BUILD SUCCESSFUL in 2m 11s
```

| 集計 | 値 |
| --- | --- |
| tests | **225** |
| failures | **0** |
| errors | **0** |
| skipped | **0** |

Sprint 20 で新設された regression spec は全て通過している:

| Spec | ケース数 | 固定している命題 |
| --- | --- | --- |
| `AuditSuppressionL3RegressionSpec` | 3 | N2: 200文字級 URI でも 403 のまま・action 先頭100文字の監査行が残る／監査 INSERT 失敗でも応答は本来のステータス／quota チェック失敗でも fail-open |
| `JwtForgedTokenL3RegressionSpec` | 2 | N1: placeholder 鍵で署名した偽造トークン → 401／`roles:["ADMIN"]` 偽造 → 401 |
| `OrderFailureAuditL3RegressionSpec` | 1 | N3: 在庫不足以外の失敗でも `ORDER_CREATE`/`FAILURE` 監査が1件残る |
| `RateLimitBurstConcurrencySpec` | 3 | N4: 20並列失敗ログイン／20並列登録で閾値頭打ち／maxAttempts 並列の成功ログインは全て 200 |
| `AuditWriteQuotaServiceSpec` | 4 | quota の窓・上限・`suppressed_count`・IP 独立性 |
| `AuditLogRecorderBestEffortSpec` | 7 | best-effort の伝播抑止と ERROR ログ残置 |

→ **指示2 の「#38〜41 は再検証不要」の条件は満たされた**。以降は「差分で新たに作り込まれたもの」だけを扱う。

---

## §2 Verification 多数決の全結果

**判定凡例**: `CONFIRMED`=事実成立かつ所見として扱う／`REFUTED`=主張が成立しない、または攻撃者到達性が無く脆弱性と呼ぶのが過大／`スコープ外`=差分前から同一の性質が存在（pre-existing）／`事実`=コード上の事実は成立するが重大度 Informational。

| # | 候補 | skeptic | defender | red-team | **確定（多数決）** |
| --- | --- | --- | --- | --- | --- |
| **V1** | 未認証監査 quota がログイン失敗の監査を抑止 | CONFIRMED / Low | Low へ格下げ | CONFIRMED / Medium（Low 寄り） | **CONFIRMED・Low** |
| **V2(a)** | 登録の拒否経路が接続2本を要求 | CONFIRMED（増分のみ） / Low | スコープ外＋Low | REFUTED（新規 DoS として）／登録側スコープ外・Low | **中核はスコープ外（pre-existing）・差分の残差のみ Low（3/3 一致）** |
| **V2(b)** | ログインのホットロー直列化 | REFUTED | REFUTED | REFUTED（武器化不能） | **REFUTED（3/3）** |
| **V3** | 過大長 username のログインが 400 | REFUTED | Info へ格下げ | REFUTED | **REFUTED・Informational**（500→400 の改善） |
| **V4** | `TestJwtSecrets.STRONG` が denylist 未収録 | REFUTED | Info へ格下げ | REFUTED（悪用として）／漏れは事実 | **REFUTED・Informational** |
| **V5** | denylist 完全一致の派生鍵バイパス | REFUTED | REFUTED | REFUTED | **REFUTED（3/3）** |
| **V6** | エントロピー検査が distinct 文字数の代理指標 | REFUTED | REFUTED | REFUTED | **REFUTED（3/3）** |
| **V7** | best-effort が成功系監査にも及び fail-open 化 | 事実 / Info | Low へ格下げ | REFUTED（悪用可能性として）/ Low | **事実成立・悪用可能性は否定・Low** |
| **V8(a)** | commit 時例外が try/catch 外 | REFUTED | スコープ外 | REFUTED | **REFUTED（3/3）** |
| **V8(b)** | 独立監査呼び出しが無保護（保護の非対称） | CONFIRMED / Low | スコープ外 | REFUTED（悪用可能性として）/ Low | **事実成立・悪用可能性は否定・Low** |
| **V9** | 計画 SQL の count guard が欠落 | REFUTED（実装が正しい） | REFUTED（決定的） | REFUTED | **REFUTED（3/3）** |
| **V10** | quota の IP バイパス＋無制限成長 | REFUTED | スコープ外＋Info | 成長のみ CONFIRMED / Low・IP バイパスは REFUTED | **Informational**（IP バイパスは 3/3 で否定） |
| **V11** | truncate で IDOR 探索対象が復元不能 | 事実 / Info | REFUTED（回帰でない） | REFUTED（※根拠は誤り・下記） | **Informational**（改善の残余） |
| **V12** | DataIntegrity の WARN ログが新シンク | REFUTED | REFUTED | REFUTED | **REFUTED（3/3）** |
| **V13** | `.env.example` の記述が実装と乖離 | 事実 / Info | Info へ格下げ | Info | **Informational（3/3）** |
| **V14** | 実ブート経路の JWT 否定テスト欠落 | 事実 / Info | REFUTED | Info | **Informational** |

> **red-team の判定改訂について**: red-team は初回出力（判定サマリのみ完成）で V2(a)=High・V11=CONFIRMED としていたが、詳細検証を経た**完成版で自ら改訂**し、V2(a) は「新規 DoS としては REFUTED・中核は pre-existing」、V11 は REFUTED に変更した。本表は**完成版の判定**を採用している。
>
> **ただし V11 の反証根拠は SEC が採用しなかった**。red-team は「100字超 URI は `Long` 変換で 400 になり authz-failure 監査経路に到達しない」としたが、先頭ゼロ埋めは `Long.parseLong` でオーバーフローしないため 400 にはならない。実際、チーム自身の通過テスト `AuditSuppressionL3RegressionSpec.groovy:67-86` が、`"0"*81 + "909090909"`（102文字パス）で **403 が返り `action` が先頭100文字に切り詰められた監査行が残る**ことを固定している。よって「0埋めで action を定数化できる」という事実自体は成立する（skeptic の判定が正しい）。結論が Informational である理由は red-team の根拠ではなく、**defender の「pre-delta は行ごと消失していたので厳密に改善＝回帰ではない」**の方である。

---

## §3 確定所見

### §3.1 Low（4件）

| # | finding-key | 所見 | 判定根拠 |
| --- | --- | --- | --- |
| **S20-1**<br>**CONFIRMED(live)** | `backend:audit:unauth-quota-blinds-authn-failure-audit` | **未認証監査 quota の窓を攻撃者が自分で焼き切ると、その窓のログイン失敗が `t_audit_log` に残らない。** ログイン失敗（誤資格・非存在ユーザ・ロック中短絡）は SecurityContext が空＝`actor==null` なので、#39 が新設した未認証 quota 経路に乗る。安価な未認証 401（`anyRequest().authenticated()` に落ちる任意パス）を100回送るだけで枠が尽き、以降は `recordAuthzFailure` が早期 return する。 | **CONFIRMED 3/3**。結線は `AuditLogRecorder.java:76-81` ＋ `GlobalExceptionHandler.java:111-116`。枠は `application.yml:64-66`（100 writes / PT1M / client_ip 単独）。**収束**（`disc-audit-quota` D-AQ-1 と `disc-ratelimit` D-RL-3 が独立発見）。<br>**Medium → Low の根拠**: 抑止1件ごとに `AuditWriteQuotaService.java:53-59` が WARN 1行＋`suppressed_count`+1 を確定的に残すため、**抑止された件数と発生 IP は完全に保存される**。消えるのは「狙われた username」だけで、しかも username は元々この監査行に記録されていない（`actor_username=NULL`）。username 別の失敗事実は `t_login_attempt` に quota と無関係に残る。さらに、枠焼き用の 100 req/min のトラフィック自体が、抑止対象の散発401より目立つ。<br>**実用性の上限（red-team R-2）**: この攻撃は per-username 閾値に触れないよう username を毎回変える必要があるため**username リストを要する**。in-band の入手経路は登録の 409 明示メッセージ（`GlobalExceptionHandler.java:76-80`）だが、既定 **5試行/15分/IP**（`RegisterAttemptProperties.java:21-22`）＝**20 username/時/IP** の低速オラクルに留まる。現実的には外部漏えいリストへの依存が前提になる。なお 409 でも枠は消費されるため **#41 は列挙コストを改善も悪化もしていない**（差分スコープ外）。この明示メッセージ自体は ID-11／E4 で「列挙対策はレート制限が担保する前提」として宣言済み。 |
| **S20-2** | `backend:auth:register-reject-path-requires-two-connections` | **登録レート制限で拒否（429）される要求も、主 tx ＋ `REQUIRES_NEW` の DB 接続2本を掴むようになった。** 旧実装は `assertNotRateLimited`（主 tx に参加する SELECT）で短絡し `finally` の `recordAttempt` に到達しなかったため、拒否は接続1本で済んでいた。既定プール10（`application.yml` にサイジング設定なし）。 | **「新規 DoS」としては成立せず・残差のみ Low（3/3 一致）**。`RegistrationApplicationService.java:66-70`。<br>**High → Low の経緯**: 「主 tx ＋ REQUIRES_NEW ＝2接続」という入れ子構造自体は `73c8d13^1` の `finally { recordAttempt }`（同じく REQUIRES_NEW）に**そのまま存在**＝pre-existing。プール枯渇の脆弱性クラス自体は差分が作ったものではない。差分の新規寄与は「レート制限発動**後**も1接続でなく2接続を消費させられる」拒否経路のコスト増**のみ**で、そこに到達するには既に max-attempts 回の試行（各回とも旧実装でも2接続）を消費している必要がある。red-team は初回 High としたが完成版で「新規 DoS としては REFUTED」に自ら改訂した。<br>**関連する文書証拠**: `RateLimitBurstConcurrencySpec.groovy:62-72` に DEV 自身が「20並列だと最大40本同時に必要となり既定の HikariCP pool（10）を使い切ってしまう」と記し、**当該 spec だけ pool を50へ引き上げ**、本番のプールサイジングは「本 Sprint のスコープ外」と明記している。**本番プールのサイジングは差分の欠陥ではないが、未対応の運用課題として残っている**（§6-11）。 |
| **S20-3** | `backend:audit:independent-audit-call-unprotected-asymmetry` | **同種のリスクを片方だけ保護している非対称。** `isWithinQuota` は `tryAcquire`（REQUIRES_NEW）の例外を fail-open で捕捉し、javadoc に「REQUIRES_NEW は新規コネクション取得を伴うためプール枯渇時に例外を投げやすい」とまで書いている。一方 `placeOrder` の catch 節から呼ぶ `recordStateChangeIndependently`（同じく REQUIRES_NEW）には同等の保護が無い。取得失敗時は `CannotCreateTransactionException` が `insert` 内部の try/catch より**手前**で飛び、元の例外を置換する＝本来 409 の `InsufficientStockException` が 500 になり FAILURE 監査も残らない。 | **事実は成立（skeptic が確認）・悪用可能性は 2/3 が否定**。`AuditLogRecorder.java:107-117`（保護あり）vs `OrderApplicationService.java:136-137, 142-143`（保護なし）。<br>defender は pre-existing としてスコープ外を主張、red-team は「発火にプール枯渇が前提＝低ペイロード」として悪用可能性を否定。**設計一貫性の欠落としては事実だが、単独で攻撃可能な脆弱性ではない**ため Low。 |
| **S20-4** | `backend:audit:best-effort-insert-flips-success-audit-fail-open` | **#39 AC2 の best-effort catch が private 共通経路 `insert` に置かれたため、成功系 `recordStateChange` にも波及し fail-closed → fail-open に反転した。** pre-delta は監査 INSERT の例外が `placeOrder` まで伝播して主 tx がロールバック＝**注文自体が成立しなかった**。現行は監査だけ落ちて注文はコミットされる（ID-22「成功・失敗いずれも記録」の無言の後退）。 | **事実は 3/3 が成立と判定・悪用可能性は否定**（skeptic は Info、red-team は「悪用可能性としては REFUTED」）。`AuditLogRecorder.java:161-173`。<br>**Low 止まりの根拠**: 現行 HEAD に**攻撃者制御の INSERT 失敗トリガが1つも残っていない**。攻撃者影響下の4列は truncate 済（`:153-157`）、`event_type`/`result`/`action` は定数、`detail` は JSON 列、`client_ip`/`create_program` はサーバ決定。Discovery 4面でも安価な誘発手段は見つからなかった。best-effort 化自体は N2 再発を避けるための AC2 明文要求。 |

### §3.2 Informational（起票不要・記録のみ）

| finding-key | 内容 | 補足 |
| --- | --- | --- |
| `backend:error:login-normalization-break-via-oversized-username` | 81文字以上の username でのログインが 401 でなく **400**（`AuthController.java:96` に `@Size` 無し × `t_login_attempt.username VARCHAR(80)` × #40 の新ハンドラ）。**収束**（D-EX-1・D-RL-5） | pre-delta は同一入力で **500＋trace 付き ERROR** だったので **SBD-10 の改善**。実在 username は `m_account.username VARCHAR(80)` により81字以上ありえず**列挙価値ゼロ**。`@Size(max=80)` を付けても応答は同じ 400 |
| `backend:audit:write-quota-unbounded-growth-and-ip-bypass` | quota キーが IP 単独＝送信元を変えれば素通り。`t_audit_write_quota` に purge/GC が無い | per-IP は #39 AC3 の明文指定。IP 変更の結果は「監査が**残る**」方向で隠蔽には使えない。purge 不在は D7 3表共通の pre-existing。`t_audit_log` の**リクエストごと1行**が `t_audit_write_quota` の**IP ごと1行**に置き換わっており成長次元は増えていない |
| `backend:audit:authz-failure-target-unidentifiable-after-truncate` | `recordAuthzFailure` は targetType/targetId が常に null で、対象は action(=URI) のみが担う。先頭100文字保持のため 0 埋めパスで action を定数化できる | pre-delta は101文字以上で**行ごと消失**していたので厳密に改善。action の意味づけ是正は PO がスコープ外と決定済み（`sprint_backlog.md:131`） |
| `backend:secrets:env-example-stale-guidance` | `.env.example` のコメントが「最小32byte・起動時に鍵長を検証」のままで、denylist / distinct 24 要件も「この値では起動しない」ことも未記載（更新されたのは README のみ） | placeholder 値の残置自体は ID-25 で意図された仕様。起動失敗時の例外メッセージが対処法を返すため実行時に自己是正される |
| `backend:secrets:jwt-failfast-realboot-coverage-gap` | `JwtSecretContextFailFastSpec` は `ApplicationContextRunner` ベースで `application.yml` を読まない。実ブート経路の JWT 否定ケースが無く、`application.yml` にデフォルト値が無いことを assert するテストも無い | リポジトリ自身が `ApplicationBootFailFastSpec` の javadoc でこの限界を明記済み。現行 HEAD では実害ゼロ（デフォルト無し・無条件 `@Component`）。将来回帰への保険の欠落 |
| （skeptic 追加）`AuditLogRecorder.insert` の truncate が `detail` に及んでいない | 現行は `detail` に入る攻撃者制御値が無い（固定文言のみ）ため実害ゼロ。`detail` に可変長ユーザー入力を渡す後続 Story が出た時に **N2 と同じ失敗モードを再導入しうる** | `AuditLogRecorder.java:153-159` |
| （skeptic 追加）`AuthApplicationService.java:71` の `recordSuccess` が無保護 | tx 保護も try/catch も無い。DELETE 失敗時は資格情報が正しいのにトークン未発行で500、枠は消費済みのまま残る。ID-11 の S1 トレードオフ受容根拠（「DELETE で即自己回復」）は**この DELETE が必ず成功する前提**の上に立っている | インフラ障害依存のため Info |
| （SEC 追加）quota は「未認証リクエストごとの DB write」自体は減らしていない | 抑止時も `ensureRow`(INSERT..ODKU) + `tryAcquire`(UPDATE) + `recordSuppressed`(UPDATE) の3文＋REQUIRES_NEW のコミットを実行し、防ぐのは `t_audit_log` の1 INSERT。N14 が減らしたのは**行数**（無制限成長）であって書き込み回数ではない | Q1 の設計（`sprint_backlog.md:41`）が INSERT..ODKU 方式を明示的に選んだ結果であり意図どおり。1 IP 1 行に固定されるため表は成長しない |

---

## §4 検証で反証・格下げした主張（発見と検証を分離した効用）

Discovery が挙げた候補のうち、**独立検証で落ちたもの**を明示する。これを書かないと「発見量＝成果」になってしまうため、SEC 原則に従って記録する。

### §4-1 V9 — Discovery の枠組み自体が誤りだった（3/3 REFUTED・最も価値のある反証）

Discovery（D-RL-4）は「`backlog/sprint_20/sprint_backlog.md` Q2 の計画 SQL にあった `AND failed_attempt_count < :maxAttempts` が実装の WHERE から欠落している＝閾値担保が `lock_until` 単独の一点依存になっている」と指摘した。SEC も計画と実装を照合し、**字面の差があること自体は確認した**。

**しかし3ペルソナ全員が「実装の方が正しい」と判定した。** 計画 SQL の条件を WHERE に足すと:

- ロック期限切れ後の要求では `lock_until <= NOW(6)` は真だが、`failed_attempt_count`(=5) `< 5` は**偽**
- → UPDATE が0行になり `BadCredentialsException` → **永久ロック**
- 窓リセット（`failed_attempt_count` を1に戻す）は SET 句側で行われるため、UPDATE が走らない限り永遠にリセットされない

SEC が既存テストで裏取りした: `LoginLockoutSpec.groovy:128`「lock_until を過去に書き換える(ロック期間経過)と、正しい password で再度ログインできる」が **RED になる**。この spec は §1 の通過225件に含まれる。

さらに defender が指摘したとおり、`lock_until = IF(failed_attempt_count >= maxAttempts, ...)` が SET 句で毎回再計算されるため **`lock_until IS NULL` ⟺ `failed_attempt_count < maxAttempts`** の不変条件が維持されており、WHERE は計画 SQL の条件を**既に内包している**。二重に書くことこそ、#41 AC4 が名指しで禁じた「同じ条件式を2箇所で独立に書くと閾値判定が1回分ずれる」不具合の再来にあたる。

→ **計画 SQL の方が誤りで、実装の省略は必要な是正。** 起票しない。

### §4-2 その他の反証・格下げ

| 候補 | Discovery の主張 | 検証の結論 |
| --- | --- | --- |
| **V2(b)** ログインのホットロー直列化 | ロック中の要求が排他行ロックを取り、既定プール10なら11並列で全接続が待ち行列に入る | **REFUTED 2/3**。`AuthApplicationService.java:64` の `login` に `@Transactional` が**無い**ため接続は常に同時1本。臨界区間は `ensureRow`+`acquireSlot`+commit のみで bcrypt を含まない（`:66→68` の順序）。さらに **コスト方向が逆**: pre-delta は閾値超過後も毎回 `authenticate()` を通り bcrypt 1回（数十〜百 ms）を消費していたのに対し、現行は 2 SQL 文（sub-ms）で短絡する＝**同一 username へのフラッドの単価はむしろ下がっている** |
| **V12** WARN ログが新しい情報シンク | 新設 `log.warn("Data integrity violation: {}", e.getMessage())` が DB 名・テーブル・列・制約名・SQL をログへ落とす | **REFUTED 2/3**。同じ例外は pre-delta では `handleUnexpected` の `log.error(..., e)`（メッセージ＋**スタックトレース**）に落ちていた。新ハンドラは message のみ WARN＝**情報量は厳密に減少**。新シンクではない。応答側は固定文言で SBD-10 準拠 |
| **V11** truncate で IDOR 対象が復元不能 | 0埋めパスで action を定数化でき、監査から探索対象が復元できない | **回帰ではない**。pre-delta は101文字以上で**行ごと消失**（＝N2 そのもの）だったので厳密に改善。「改善の残余」として Informational |
| **V3** 過大長 username で一律401から逸脱 | 未認証1リクエストで第3の応答クラス（400）が得られ SBD-6 に反する | **Informational**。pre-delta は **500**（`handleUnexpected`）。応答クラス数は 401/500 → 401/400 で増えていない。81字以上の username は構造的に実在不可能＝列挙価値ゼロ。`@Size` を付けても応答は同じ 400 |
| **V4** テスト鍵が denylist 未収録 | 運用者が `TestJwtSecrets.STRONG` を流用しても一切警告されない | **REFUTED 2/3**。SEC の実測で稼働鍵は当該リテラルと**不一致**。`src/test` 限定で boot jar 非同梱。出荷物（`.env.example`/README/例外メッセージ）は全て `openssl rand -base64 32` へ誘導しており、この定数への導線が存在しない。加えて skeptic 指摘: **denylist に入れると当該フィクスチャを使う IT 群が起動不能になる**（提言自体が、フィクスチャ値の差し替えとセットでないと実行不能） |
| **V5 / V6** denylist 完全一致・エントロピー代理指標 | placeholder の派生鍵が通る／`abc…xyz012345` が通り `openssl rand -hex 32` が常に落ちる | **REFUTED 3/3**。いずれも「運用者が再生成ではなく加工を選ぶ／閾値を満たす値を手打ちする」という**攻撃者制御外の自傷行為**が前提。素のコピー・大小文字違い・前後空白・1〜2文字追加は distinct 21〜23 で**依然として落ちる**（多層防御が実際に効いている）。ID-25 が distinct 検査を**補助**と明示済み。ただし「真正 256bit の hex 鍵が恒久的に拒否される」という判定の逆転は事実として §6 に残す |
| **V8(a)** commit 時例外で監査ゼロ | `placeOrder` の commit は try/catch の外なので失敗が無記録 | **REFUTED 3/3**。InnoDB に遅延制約が無く、制約違反は全て文の実行時（try 内）に出る。攻撃者が誘発する筋道が示されていない |
| **V10** quota が N14 を緩和していない | 表が1つ増えただけで無制限成長は続く | **Informational**。`t_audit_log` の**リクエストごと1行**が `t_audit_write_quota` の**IP ごと1行**に置き換わっており、成長次元は増えていない。IP 変更による素通りは「監査が残る」方向で隠蔽には使えない |

---

## §5 clean と確認した領域

差分を読んだうえで**問題なしと確認した**もの（過大主張回避のため明示）。

### レート制限の原子化（#41）

- **レート制限バイパスは存在しない**。`acquireSlot` の SET 句を状態遷移で追い、既定値（max=5）で 1→5 と増え **5本目で `lock_until` が立ち6本目以降は WHERE 不一致で affected==0** になることを確認。窓が切れた行は count=1 にリセットされ旧 `recordFailure` と同一の意味論が保たれている（AC4 の要求どおり）。`RateLimitBurstConcurrencySpec` の20並列テストが実測で裏付け。
- **ロールバックによる枠の巻き戻しは起きない**。例外送出は `affected == 0`（枠を消費していない）ときのみ。枠確保成功後に例外を投げる経路が存在しない（javadoc が宣言する不変条件が実際に成立）。登録側は REQUIRES_NEW により主 tx のロールバック（409/400）で枠が戻らないことも確認。
- **カウンタのキー分割・キー衝突は成立しない**。`t_login_attempt.username` と `m_account.username` が**同一照合順序**（`utf8mb4_ja_0900_as_cs`・NO PAD）。大小文字・アクセント・末尾空白の扱いが認証キーとレート制限キーで完全一致するため、「レート制限だけ別行に逃がして認証は同一アカウントに当てる」バイパスも「照合衝突で他人をロックアウトする」も作れない（衝突する username 同士は `uk_m_account_username` によりそもそも同時登録不能）。
- **ロック延長 DoS は無い**。WHERE がロック中の行を除外するため、ロック中に何回叩いても `lock_until` は延長されない。
- **既存レースが1つ消えている**。2文が個別 autocommit だった場合、他スレッドの `recordSuccess`（DELETE）が割り込むと正資格の正規ユーザが誤 401 になり得た。REQUIRES_NEW で行ロックがコミットまで保持されるためこの窓は塞がった。
- **列挙耐性（AC3）の後退なし**。ロック中短絡は誤資格と同一の `BadCredentialsException` → 一律401。bcrypt 前に短絡するタイミング特性も旧 `assertNotLocked` と同じ。

### 監査 quota（#39）

- **fail-open の選択は妥当で N2 の再現は無い**。`isWithinQuota` が `tryAcquire` の `RuntimeException` を捕捉するため、quota の DB 障害がセキュリティハンドラ内からの例外送出（→`/error` ディスパッチ→403/401 化け）にならない。**fail-closed にしていたら quota の DB 障害がそのまま新しい監査抑止経路になっていた**。
- **認証済み403に quota を掛けていない**。掛けていれば N2 をそのまま再導入していた（攻撃者が自分の枠を使い切って以降の自分の403を無記録化）。`AuditLogRecorder.java:79` の `actor == null` 条件で正しく限定（Q1 でユーザー承認済み）。
- **時刻はすべて DB 側 `NOW(6)`**。窓判定・窓延長・WHERE 句に app 側時刻が一切混ざらず、クロックスキューでも壊れない。攻撃者が渡せる時刻入力も無い。
- **SET 句の左→右評価依存は正しく書けている**。`window_expires_at` を最後に代入しているため他列の IF 条件は更新前の値を参照する。「窓が永久にリセットされず抑止が固定化する」経路は無い。
- **truncate の列幅が DDL と完全一致**（100/50/50/80 ⇔ `VARCHAR(100)/(50)/(50)/(80)`）。`@Size` は UTF-16 コード単位、MySQL VARCHAR は文字数だが**コード単位数 ≧ 文字数**のためすり抜けは生じない。**N2 の INSERT 破綻トリガは塞がっている**。
- **quota SQL に注入面は無い**。3本とも全パラメータ `#{}` バインド（`${}` ゼロ）。`clientIp` は `getRemoteAddr()` 由来（X-Forwarded-For は意図的に不信頼）。
- **Spring AOP の自己呼び出し迂回は無い**。`acquireAttemptSlotOrThrow`（両サービス）・`tryAcquire`・`recordStateChangeIndependently` はいずれも別 bean から呼ばれており `@Transactional` プロキシが介在する。

### 例外ハンドリング・注文失敗監査（#40）

- **例外ハンドラの優先順位逆転は無い**。新設 `DataIntegrityViolationException` ハンドラは既存のどのハンドラよりも広い型を登録していない。唯一の実質的サブクラス `DuplicateKeyException` は `RegistrationApplicationService.java:82` で先に捕捉され409になるため、**登録の重複応答（ID-14/E4 の宣言済み意図差分）は400に化けない**。
- **SBD-8（not-found と not-owned の403統一）は無変更で維持**。差分はここに触れていない。
- **監査 detail に PII・生例外・攻撃者入力が入らない**。新設の catch は `Map.of("reason", "UNEXPECTED_ERROR")` の定数のみ。成功監査も `total`/`itemCount` だけで注文 PII は一切入らない。
- **例外は全経路で rethrow され部分コミットは起きない**。`@Transactional` の既定ロールバック規則が効き、在庫減算・明細 INSERT・カートクリアは all-or-nothing のまま。
- **`@Size` の値が DB 列幅と一致**（80/80/80/80/80/80/20/20 ⇔ `t_order` の該当列）。
- **エラー応答本体は SBD-10 準拠のまま**。`ErrorResponse` は `code/message/path/timestamp` の4フィールドのみで trace・クラス名・版数のフィールドが存在しない。`spring.web.error.include-*` も全て無効。
- **CORS・キャッシュ・レスポンスヘッダの変更は差分に無い**。

### JWT 鍵ポリシー（#38）

- **デフォルト値による fail-fast の骨抜きは無い**。`application.yml:45` は `secret: ${JWT_SECRET}` でフォールバック無し。追跡下の設定ファイルに `jwt.secret` を定義する他ファイルは存在せず、環境変数名の変更も無い。
- **fail-fast は全ブート経路で走る**。`src/main` に `spring.main.lazy-initialization`・`@Profile`・`@ConditionalOn*` は0件。`JwtProperties` は素の `@Component` で eager singleton。`JwtSecretPolicy` は package-private・呼び出し元1箇所・鍵生成1箇所＝**ポリシーを迂回して鍵を作る経路が main に無い**。
- **鍵長判定に単位の食い違いは無い**。検証側と実鍵側が同一の `getBytes(StandardCharsets.UTF_8)`。正規化（trim/lowercase）は判定にのみ使われ鍵材料には元の文字列が使われる。
- **判定順序による早期 return の穴は無い**。denylist → 鍵長 → エントロピーの順で、いずれも throw（return ではない）。
- **秘密の露出は確認できず**。3つの例外メッセージは定数・閾値・実測バイト数/distinct 数のみで、鍵の実値も部分文字列も含まない。Lombok 非使用・`toString()` 未定義。actuator 露出は `health,info` のみ。
- **テスト用鍵の main classpath 混入なし**。`build.gradle` に `sourceSets`/`bootJar`/`testFixtures` のカスタマイズ無し。`src/main` からの参照0件。
- **鍵ローテーション/複数鍵は未導入**＝downgrade・`alg`/`kid` 取り違えの新規面は本差分から生じていない。
- **`.env` は追跡外**（`.gitignore` 済・`git ls-files` に不在）。今回の差分で新たに追跡下へ入った秘密ファイルは無い。

---

## §6 未確認・残件

1. **ライブ PoC 全般（未実施）**。稼働 backend が停止中。S20-1（未認証101発→ログイン失敗が `t_audit_log` に残らない）と S20-2（並列登録でのプール枯渇）はいずれも `cheap_poc: y` と評価されているが、**並列バースト系は稼働機への負荷試験になるため SEC 原則に従いユーザー承認前には実施しない**。承認が得られれば経験的に確定できる。
2. **`INSERT .. ON DUPLICATE KEY UPDATE col = col` の InnoDB 行ロック実挙動**。ドキュメント上は重複キー検出時に排他インデックスレコードロックを取ると読めるが**実測していない**。3ペルソナとも「真であっても判定は変わらない」としている。
3. **稼働 MySQL の `@@sql_mode`**（V3 の分岐）。`docker-compose.yml` に上書きが無いことから MySQL 8.4 既定の STRICT と判断したが実機未確認。STRICT でも非 STRICT でも V3 の判定は変わらない。
4. **`DataIntegrityViolationException.getMessage()` にバインドパラメータ値が含まれるか**（V12）。含まれる場合、`log.warn` が攻撃者制御文字列をログへ落とす（CRLF によるログ行偽装の余地）。応答側の clean 性には影響しないため V12 の REFUTED は変わらない。
5. **リバースプロキシ配下での quota キー崩壊（条件付き増幅要因・red-team R-3）**。`clientIp` は `getRemoteAddr()` 固定（`AuditLogRecorder.java:203-208`・X-Forwarded-For 不信頼）かつ `t_audit_write_quota` の PK が `client_ip` のため、**プロキシ/LB 配下では全クライアントが単一の quota 行に集約**され、100件/分の枠を全体で共有することになる。この場合 S20-1 の攻撃コストがさらに下がり、**S20-1 の格下げ根拠である「per-IP なので他人の監査は消せない」（`AuditWriteQuotaService.java:14-17`）が崩れる**（無関係な利用者の未認証監査まで巻き添えで落ちる）。<br>コード中の既存 TODO（`AuditLogRecorder.java:200-201`）はプロキシ配下での **client_ip の正確性/偽装**の観点のみを扱っており、「IP が潰れることで quota バケットが共有される」という帰結までは書かれていない。<br>**本プロジェクトに本番デプロイ基盤が無く（`README.md:57`）トポロジ前提が確定できない**ため、**現行構成では発火せず、Sprint 20 差分の欠陥として起票すべきものではない**。所見ではなく条件付き増幅要因として記録する（WAF/プロキシを防御として当てにする主張ではない）。
6. **面をまたぐ連鎖の探索結果（red-team R-1〜R-4）**。結論は「**これ以外の新規の面をまたぐ連鎖は無し**」だった。R-2 は S20-1 の実用性上限として §3.1 に、R-3 は上記5に反映済み。
   - **R-1** = S20-1 と同一。「per-username レート制限（5回/15分）」×「per-IP 監査 quota（100/分）」×「ログイン失敗が `actor==null` 経路に乗る」の3面合流で、「監査を焼いてから per-username 閾値に触れないスプレーを流す」が成立する。Discovery が面ごとに割れていたものを繋ぐと成立するという指摘で、D-AQ-1／D-RL-3 の収束が実体。**上限**として red-team 自身が、`suppressed_count`/WARN 量のスパイクが**攻撃者を逆に目立たせる**点と、per-username ロックが単一アカウントの総当りを依然封じる点を挙げている。
   - **R-4（REFUTED 寄り・Info）**: S20-2 でプールを圧迫 → 同時進行の正規 `placeOrder` が `recordStateChangeIndependently` の接続を取れず例外置換 → 409 が 500 化＋FAILURE 監査喪失（S20-3）。成立には複数 IP ＋精密なタイミングが要り、得られるのは「1注文の失敗監査喪失」の低ペイロード。**実用チェーンとして構築できない**と判定された。
   - V4/V5/V6/V9 は全て運用者の設定ミス依存＝攻撃者制御外のため、互いに連鎖させても攻撃者到達経路が生まれない。
7. **`t_login_attempt` / `t_register_attempt` / `t_audit_write_quota` の purge/GC 不在**。D7 3表共通の pre-existing で差分由来ではないため所見にしていないが、運用衛生として記録。
8. **登録レート制限ヒット（429）が監査ログに残らない**。`GlobalExceptionHandler` の該当ハンドラに `recordAuthzFailure` 呼び出しが無い。旧実装でも同じで**差分由来ではない**が、SBD-14 の観点で S20-1 と併せて評価する価値がある。
9. **`openssl rand -hex 32` が恒久的に拒否される**（V6(b)）。真正256bit のランダム鍵でも hex の文字集合が16種のため distinct ≤16 < 24 で必ず落ちる。fail-closed なので脆弱性ではないが、README は「まれにユニーク文字数24未満になる場合は再生成」としか書いておらず、hex では「まれに」ではなく常時であることに触れていない。運用性の記録。
10. **本番 HikariCP のプールサイジングが未設定**。`application.yml` にサイジング設定が無く Spring Boot 既定（maximum-pool-size 10 / connection-timeout 30秒）のまま。`register` は主 tx ＋ REQUIRES_NEW で**1リクエストあたり接続2本**を要するため実効同時数は半減する。DEV が `RateLimitBurstConcurrencySpec.groovy:67` で「本番の pool サイジング自体は本 Sprint のスコープ外」と明記しており**差分の欠陥ではない**が、pre-existing の運用課題として記録する（S20-2 の背景）。
11. **既知未修正（差分由来ではないため本 run の対象外）**: N5（`handleIllegalArgument` の生メッセージ返却）・N15（メディアタイプ非正規化）は HEAD でも健在。ただし新ハンドラの追加により「未認証から到達できる非正規化応答」の面は増えているため、N5/N15 と束ねた**正規化網羅性の再点検**を推奨する。

---

## §7 受け渡し（Patching）

本書は SEC の Find-and-Fix ループの「発見→検証」まで。**修正は行わない。**

**Issue 化はユーザー承認を得て実施済み**（2026-08-20）。

### 既存 Issue 突合

`ryokkon624/jpetstore-manage` の `security` ラベル付き Issue **22件（open + closed）**と突合した。

- **NEW: 4件**（S20-1〜S20-4）。`finding-key` 完全一致なし・意味照合でも該当なし。既存 open の #42〜#45 は前回 run（`security/20260819_01`）の N5〜N16 を束ねたもので重複しない。
- **KNOWN: 0件** / **REGRESSION: 0件**。#38〜41 は closed だが、それぞれの元 `finding-key` は**再検出されていない**（対応する regression spec が §1 で全通過）。S20-1 は #39 と同じ「監査抑止」だが機序が異なり、**#39 の修正自体の副作用として生まれた新規**であるため回帰ではない。

### 起票結果

| Issue | 内容 | 重大度 |
| --- | --- | --- |
| [#46](https://github.com/ryokkon624/jpetstore-manage/issues/46) | S20-1 単独（**CONFIRMED(live)** のため独立起票） | Low |
| [#47](https://github.com/ryokkon624/jpetstore-manage/issues/47) | S20-2〜S20-4 を「Sprint20修正の副作用ハードニング」として1本に束ね（#42〜#45 と同じ塩漬け可の束の慣例に倣う） | Low |

両 Issue とも `security` ラベル付き・本文に `finding-key` を明記・Project #2 に追加し **Ready=Draft** に設定済み。多数決の内訳・PoC 証跡・既存 Issue 突合結果はコメントで記録した。#47 には「Discovery で挙がったが検証で落ちた主張」も記載し、過大主張が独り歩きしないようにしている。

§3.2 の Informational 群は**起票せず本書への記録に留めた**（攻撃者到達性が無く、起票すると Low 束のノイズになるため）。Critical / High は 0件のため、Sprint 21 の優先度としては低い。

---

## 成果物

- Discovery: [`security/20260820_01/discovery/`](../../security/20260820_01/discovery/)（`audit-quota-suppression.md` / `ratelimit-atomization.md` / `error-exposure-order.md` / `jwt-secret-policy.md`）
- Triage: [`security/20260820_01/verification/candidates.md`](../../security/20260820_01/verification/candidates.md)
- Verification: [`security/20260820_01/verification/`](../../security/20260820_01/verification/)（`skeptic.md` / `defender.md` / `red-team.md`）
