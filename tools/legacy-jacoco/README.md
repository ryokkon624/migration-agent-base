# legacy-jacoco — L2パリティのカバレッジ計測（#50・#51）

`jpetstore-legacy`（無改変）へJaCoCoエージェントを被せたoverlayイメージ（別タグ
`jpetstore-legacy-jacoco`）で、L2パリティ（`jpetstore-backend`の`parity`シナリオ）が
legacyの「保存すべき業務ロジック」をどれだけ踏めているかを実測する。

設計: [`spec/l2-parity-design.md`](../../spec/l2-parity-design.md) §4・§7.3。
分母の定義（29クラス・`domain`/`dao`のみ）はAC1参照。

> **#51 Q4確定**: `report.sh`は**3本出し**（`ac1`/`gate`=#50合意の3除外/`gate-v2`=#51提案の5除外
> ＝`OrderValidator`/`AccountValidator`を追加除外）。実測結果は
> [`reports/after/l2-parity-coverage.md`](../../reports/after/l2-parity-coverage.md) Sprint 22 追記参照。

## 前提

- `legacy-jpetstore`をビルド済みで `jpetstore-legacy` イメージが存在すること
  （`legacy-jpetstore/run/README.md`参照。**本ディレクトリの手順は`jpetstore-legacy`イメージを
  一切変更しない**＝凍結アーティファクトの原則）。
- `jpetstore-backend`側で `captureGolden` タスクが使えること（`-Dparity.legacy.baseUrl`等で
  接続先を差し替え可能）。
- ホストに Docker・curl・JDK（jacococli実行用。21系で動作確認済み）があること。

## 1) JaCoCo jarを取得（初回のみ）

```sh
cd tools/legacy-jacoco
./fetch-jars.sh
```

`jacocoagent.jar`/`jacococli.jar`が本ディレクトリに置かれる（`.gitignore`対象・版管理しない）。

## 2) overlayイメージをビルド

```sh
docker build -t jpetstore-legacy-jacoco tools/legacy-jacoco
```

`jpetstore-legacy`イメージ自体は無変更（別タグでの追加ビルドのみ）。

## 3) 採取プロトコル（#48/#49と共通の起動・後始末手順 + JaCoCo計測）

計測実行は golden を上書きしないよう `-Pparity.goldenDir=<throwaway>` で退避先を切り替える
（既定の `src/test/resources/parity/golden` を汚さない）。

```sh
# 1. 初期シードから開始
docker rm -f jpetstore-legacy-jacoco-measure 2>/dev/null || true

# 2. agent付きで起動（採取用は別ポート8081/9002・design.md F2）
# ★Git Bash(MSYS)特有の罠: `-v host:/jacoco`の`/jacoco`（コンテナ側の絶対パス）をMSYSのパス変換が
#   誤ってホストパスとして解釈し、ボリュームが正しくバインドされない（jacoco.execが書かれない）。
#   `MSYS_NO_PATHCONV=1`を先頭に付けて回避する（#51で実際に踏んだ罠。PowerShell/cmdでは不要）。
mkdir -p tools/legacy-jacoco/out
MSYS_NO_PATHCONV=1 docker run -d --name jpetstore-legacy-jacoco-measure \
  -p 8081:8080 -p 9002:9002 \
  -v "$(pwd)/tools/legacy-jacoco/out:/jacoco" \
  jpetstore-legacy-jacoco

# 3. index.do が200を返すまでポーリング
until curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/jpetstore/shop/index.do | grep -q 200; do
  sleep 2
done

# 4. 全シナリオ（#48 W1 + #49 R1-R6/W2/W3）を実行（golden本体は上書きしない）
cd ../jpetstore-backend   # migration-agent-baseの兄弟ディレクトリ
./gradlew captureGolden \
  -Dparity.legacy.baseUrl=http://localhost:8081/jpetstore/shop \
  -Dparity.legacy.jdbcUrl=jdbc:hsqldb:hsql://localhost:9002 \
  -Dparity.goldenDir=/tmp/parity-coverage-golden
cd ../migration-agent-base

# 5. graceful停止（★ docker stop -t 30 でないとexecが書かれない。強制停止しないこと）
docker stop -t 30 jpetstore-legacy-jacoco-measure

# 6. レポート生成（AC3手順4・#51 Q4: 3本出し。コンテナはまだ削除しない＝docker cpでclassfilesを取り出すため）
tools/legacy-jacoco/report.sh jpetstore-legacy-jacoco-measure \
  tools/legacy-jacoco/out/jacoco.exec tools/legacy-jacoco/out/report

# 7. 後始末（AC-neg1: 採取用コンテナを削除。jpetstore-legacyイメージ自体は無改変のまま）
docker rm jpetstore-legacy-jacoco-measure
```

`report.sh`は**#51 Q4確定により3本のレポートを出力**する（`tools/legacy-jacoco/out/report/ac1/`＝
AC1分母＝計測の分母29クラス/解析22・`tools/legacy-jacoco/out/report/gate/`＝#50合意のゲート分母＝
AC1−到達不能3クラス（継続性のため維持）・`tools/legacy-jacoco/out/report/gate-v2/`＝#51提案のゲート分母＝
`gate`−`OrderValidator`/`AccountValidator`＝判定用候補。それぞれ`index.html`/`jacoco.xml`/`jacoco.csv`）。
gate/gate-v2を同一execに対して出すことで、(a)除外による分母縮小の効果と(b)追加シナリオによる被覆増の
効果を手計算ゼロで分離できる（詳細は`reports/after/l2-parity-coverage.md` Sprint 22追記S3）。

あわせて除外反証チェックを2方式で行う（#51 Q5確定）:
- **STRICT**（`SendOrderConfirmationEmailAdvice`/`MsSqlOrderDao`/`OracleSequenceDao`）: カバレッジが
  1つでも0を超えたら即座にfail（除外の前提「未配線=構造的に到達不能」が崩れたことを検知）。
- **BASELINE**（`OrderValidator`/`AccountValidator`）: 実測ベースライン（`instruction_covered=3`・
  `branch_covered=0`）との`!=`でfail（増＝呼び出し元到達不能という前提の崩壊／減＝bean定義自体の変化、
  でメッセージを書き分ける）。

`--classfiles`にはAC1で定義した分母（`domain`/`dao`配下のみ）だけを渡す
（`web.struts`/`web.spring`/`service`はID-5/ID-6により分母から除外＝`report.sh`が自動的にこの2パッケージ
のみ抽出する）。

## 採取事故と回避策（#53）

Sprint 21/22 の採取で、**中身が空のゴミディレクトリが2種類**できた。どちらも一次データを含まないので、
見つけたら消してよい（`.gitignore` で追跡対象からも外してある）。

| 事故ディレクトリ | 再現条件 | 回避策 |
| --- | --- | --- |
| `tools/legacy-jacoco/out3;C` | **Git Bash(MSYS) のパス変換**。`docker cp` / `docker run -v` などコンテナ側の絶対パス（`/jacoco` 等）を含む引数を渡すと、MSYS が `C:\...` へ変換しようとして引数の末尾に `;C` が付いた別ディレクトリが生まれる（上の手順の `MSYS_NO_PATHCONV=1` を付け忘れた場合に起きる） | **コマンド先頭に `MSYS_NO_PATHCONV=1` を付ける**（`docker run -v` だけでなく、コンテナ側絶対パスを引数に含む docker 系コマンド全般）。PowerShell/cmd では不要 |
| `tools/legacy-jacoco/tools/legacy-jacoco/out/report`（入れ子） | **ホスト側パスの二重解決**。`report.sh` / `docker cp` のホスト側出力先を `tools/legacy-jacoco/out/report` のような**リポジトリルート基準の相対パス**で渡したまま、カレントディレクトリが既に `tools/legacy-jacoco/` だった場合に、`tools/legacy-jacoco/tools/legacy-jacoco/...` が生成される | **`report.sh` は必ずリポジトリルート（`migration-agent-base/`）から実行する**（上の手順のとおり）。別の場所から叩く場合はホスト側パスを絶対パスで渡す |

いずれも `git status` には出ない（`.gitignore` 済み）ため、**気づかず残り続ける**のが唯一の実害。
掃除は空であることを確認してから `rmdir`（`rm -rf` ではなく `rmdir` を使えば、誤って一次データ入りの
`out/` `out2/` `out3/` を消す事故を構造的に防げる）。

> **`out/` `out2/` `out3/` は削除しないこと**（2026-08-21 ユーザー判断・#53 AC-neg1）。
> `reports/after/l2-parity-coverage.md` が BRANCH 28/34・INSTRUCTION 1360/1424 の出典として
> `out3/report/gate-v2/jacoco.csv` などを**名指しで参照**している一次データで、コミットされていないため
> 消すとゲート値の裏取り経路がローカルから失われる。

## 実測結果

`migration-agent-base/reports/after/l2-parity-coverage.md` に記録する（spike時点の初期実測を
出発点として併記し、増分を明示する）。

## 既知の制約

- 分母22クラス（インタフェース除く）に対する`--classfiles`はWARの`WEB-INF/classes`から直接
  抽出したバイトコードを使う（ソースからの再ビルドはしない＝凍結アーティファクトの原則）。
- `jacoco.exec`は`append=true`で追記されるため、複数回`captureGolden`を実行すると前回分と
  合算される。クリーンな実測を取り直したい場合は手順1（コンテナ削除→再作成）からやり直すこと。
