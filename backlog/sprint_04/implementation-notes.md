## #21: [E5] 認証プリンシパル基準の認可土台を全ドメインへ提供する

### 仕様外の判断・変更・妥協点

- **実証エンドポイントの設計**: `SecuredPingController#myResource` は `GET /api/secured/my-resource/{resourceOwnerUserId}`
  とし、パス変数を「対象リソースの真の所有者userId（サーバー側解決済みの体）」とみなした。対象ドメインリソースが
  未実装のため、実ドメインでの「リソースIDから所有者をDB解決する」ステップは省略し、パス変数自体を解決済み所有者として
  扱う実証にとどめた（過剰実装回避）。AC-neg1の「?userId=他人を付けても結果不変」は、エンドポイントのシグネチャに
  該当パラメータをそもそも束縛しない（Spring MVCが未知のqueryパラメータを無視する）ことで構造的に保証した。

## #20: [E5] 認証を堅牢化する（レート制限/ロックアウト・既定資格情報廃止・GET認証廃止・リダイレクト検証）

### 仕様外の判断・変更・妥協点

- **`LoginAttemptCustomEntity`（読み取り用エンティティ）を計画から変更し削除した**: 計画時点では
  `LoginAttemptCustomMapper`/`LoginAttemptCustomEntity` のペアで用意する想定だったが、実装中に
  ロック判定をJava側（`entity.getLockUntil().isAfter(LocalDateTime.now())`）で行うと、**JVM（JST）と
  Testcontainers MySQL（UTC）のクロックスキューによりロック判定が常にfalseになり機能しない不具合**をIT
  （`LoginLockoutSpec`）実行で実際に検出した。ロック判定をDB側の`NOW(6)`で完結させる
  `LoginAttemptCustomMapper#countActiveLock(username): int`に置き換えたところ、entity/`findByUsername`を
  読む経路が無くなり未使用コードになるため、entityクラス自体を削除した（YAGNI・過剰実装回避）。同じ理由で
  `LoginLockoutSpec`のロック解除確認テストも、JVM時刻ではなくDB側で計算する
  `DATE_SUB(NOW(6), INTERVAL 1 MINUTE)`によるSQL側の書き換えに変更した。
- **`recordFailure`の単文アトミックUPDATE SQLで、MySQLのSET句が左から右へ評価され後続の式が同一文内で
  既に代入済みの列の新しい値を参照できる（ドキュメント化された挙動）ことを踏まえてSQLを設計し直した**:
  当初案は`failed_attempt_count`の閾値到達判定用の条件式を`lock_until`のSET句内で独立に再計算していたが、
  この左→右評価の影響で「閾値判定が実際の失敗回数より1回分前倒しでロックする」ズレが生じることをIT実行で
  発見した。`lock_until`のSET句で`failed_attempt_count`（直前のSET句で更新済みの新しい値）をそのまま
  参照する形に単純化し、二重計算・評価順依存のズレを解消した。

## Sprint 4 コードレビュー結果・SM受容判断（2026-08-15）

3観点レビュー: **convention=指摘なし / performance=指摘なし / security=非ブロッキング2件**。
SM が実コードで検証のうえ、ユーザー承認（2026-08-15）を得て**両件とも受容（コード修正なし）**と判断。

- **Finding 1（タイミング副次チャネル・受容）**: `AuthApplicationService.login` が `assertNotLocked`（高速SELECT）を
  `authenticate()`（bcrypt・低速）より前に呼ぶため、ロック中/非ロックで応答時間に差が出る。
  **ただし列挙 oracle にはならない**: `t_login_attempt` は username 文字列PKで失敗時に実在/非実在を問わず行を作る
  （未知ユーザーも対称にロック）＋非ロック時は Spring `DaoAuthenticationProvider` が未知ユーザーへダミー bcrypt を
  走らせタイミングを均等化するため、タイミングが割れるのは {ロック中=速い}vs{非ロック=遅い} の軸のみで**存在と直交**。
  ロック状態は攻撃者自身が誘発するもので新情報を与えない。計画時に承認済みの**受容リスク(a) の顕在化**であり、
  AC3（一律メッセージ）は充足（定数時間化はACの要求水準を超える）。硬化（短絡経路のダミー遅延）は実益が限定的で
  perf が評価した軽量設計を損なうため見送り。
- **Finding 2（check-then-act 非原子性→ロック延長・受容）**: `assertNotLocked` と `recordFailure` が別文のため、
  ロック成立をまたぐ高並列バーストで in-flight リクエストが `lock_until` を都度再計算し**ロック期限が後ろ倒しに延長**され得る。
  ただしこれは**フェイルセーフ（ロックがより長くなるだけ・bypass 不可）**で、攻撃中アカウントの可用性が僅かに延びるのみ＝
  **受容済みDoSモデルの範囲内**。悲観ロック導入は軽量設計を損なうため見送り。
- Sec の主要観点（SBD-1 param非依存＝`SecuredPingController` が `@RequestParam` 非束縛の構造保証＋E2E／SBD-14 監査記録／
  SBD-6 対称ロック・応答一致・自動解除／SBD-9 sink不在／SQLi パラメタライズ／秘密情報）は**すべて問題なし**。
  m_account と t_login_attempt の collation 一致（`utf8mb4_ja_0900_as_cs`）で case bypass も該当なし。
- 上記2件は Sprint Review でユーザーに明示する（既知の受容リスクとして）。
