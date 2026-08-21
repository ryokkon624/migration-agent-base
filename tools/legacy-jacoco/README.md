# legacy-jacoco — L2パリティのカバレッジ計測（#50）

`jpetstore-legacy`（無改変）へJaCoCoエージェントを被せたoverlayイメージ（別タグ
`jpetstore-legacy-jacoco`）で、L2パリティ（`jpetstore-backend`の`parity`シナリオ）が
legacyの「保存すべき業務ロジック」をどれだけ踏めているかを実測する。

設計: [`spec/l2-parity-design.md`](../../spec/l2-parity-design.md) §4・§7.3。
分母の定義（29クラス・`domain`/`dao`のみ）はAC1参照。

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
mkdir -p tools/legacy-jacoco/out
docker run -d --name jpetstore-legacy-jacoco-measure \
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

# 6. レポート生成（AC3手順4・AC5: 2本出し。コンテナはまだ削除しない＝docker cpでclassfilesを取り出すため）
tools/legacy-jacoco/report.sh jpetstore-legacy-jacoco-measure \
  tools/legacy-jacoco/out/jacoco.exec tools/legacy-jacoco/out/report

# 7. 後始末（AC-neg1: 採取用コンテナを削除。jpetstore-legacyイメージ自体は無改変のまま）
docker rm jpetstore-legacy-jacoco-measure
```

`report.sh`は**PO合意（AC5）により2本のレポートを出力**する（`tools/legacy-jacoco/out/report/ac1/`＝
AC1分母＝計測の分母29クラス/解析22・`tools/legacy-jacoco/out/report/gate/`＝ゲート分母＝
AC1−到達不能3クラス＝判定用。それぞれ`index.html`/`jacoco.xml`/`jacoco.csv`）。あわせて、
**到達不能3クラス（`SendOrderConfirmationEmailAdvice`/`MsSqlOrderDao`/`OracleSequenceDao`）の
カバレッジが1つでも0を超えたら即座にfail**する（除外の前提「未配線=構造的に到達不能」が崩れたことを
検知する反証チェック）。`--classfiles`にはAC1で定義した分母（`domain`/`dao`配下のみ）だけを渡す
（`web.struts`/`web.spring`/`service`はID-5/ID-6により分母から除外＝`report.sh`が自動的にこの2パッケージ
のみ抽出する）。

## 実測結果

`migration-agent-base/reports/after/l2-parity-coverage.md` に記録する（spike時点の初期実測を
出発点として併記し、増分を明示する）。

## 既知の制約

- 分母22クラス（インタフェース除く）に対する`--classfiles`はWARの`WEB-INF/classes`から直接
  抽出したバイトコードを使う（ソースからの再ビルドはしない＝凍結アーティファクトの原則）。
- `jacoco.exec`は`append=true`で追記されるため、複数回`captureGolden`を実行すると前回分と
  合算される。クリーンな実測を取り直したい場合は手順1（コンテナ削除→再作成）からやり直すこと。
