#!/bin/sh
# [L2] #50 AC3/AC4/AC5: JaCoCo実測レポートを生成する（採取プロトコルの手順4）。
#
# PO合意（AC5・ゲート値合意）により、1つのexecから **2本** のレポートを出力する:
#   (a) AC1分母（計測の分母・29クラス/解析22。web.struts/web.spring/serviceのみ除外＝ID-5/ID-6）
#   (b) ゲート分母（AC1 − 到達不能3クラス。判定に使う分母）
#
# あわせて、到達不能と判定した3クラス（SendOrderConfirmationEmailAdvice/MsSqlOrderDao/
# OracleSequenceDao）のカバレッジが(a)のレポートで1つでも0を超えたら **fail** する
# （「未配線だから到達不能」という除外の前提が崩れたことを検知する反証チェック。
# PO指摘: 除外理由を脚注でなく機構で担保しないと、手計算の派生値はdriftする＝
# 実際に「到達可能分母36」という誤った値がレビューを通ってしまった経緯を踏まえた対策）。
#
# 前提:
#   - captureGolden 実行中、agent付きコンテナを `-v <host_out>:/jacoco` でマウントしていたこと
#   - `docker stop -t 30`（graceful）でコンテナを停止済み（強制停止するとexecが書かれない）
#   - コンテナ自体はまだ削除していないこと（--classfiles抽出に docker cp を使うため）
#   - ./fetch-jars.sh 済み（jacococli.jarが本ディレクトリにあること）
#
# 使い方:
#   ./report.sh <container_name> <exec_file_path> <out_dir>
#   例: ./report.sh jpetstore-legacy-jacoco-measure ./out/jacoco.exec ./out/report
#
# 出力:
#   <out_dir>/ac1/  … AC1分母（29クラス/解析22）でのレポート（index.html/jacoco.xml/jacoco.csv）
#   <out_dir>/gate/ … ゲート分母（AC1 − 到達不能3クラス）でのレポート（同上・判定用）
set -e
CONTAINER_NAME="${1:?usage: report.sh <container_name> <exec_file_path> <out_dir>}"
EXEC_FILE="${2:?usage: report.sh <container_name> <exec_file_path> <out_dir>}"
OUT_DIR="${3:?usage: report.sh <container_name> <exec_file_path> <out_dir>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# EXEC_FILE/OUT_DIRは呼び出し元のカレントディレクトリからの相対パスを想定するため、
# SCRIPT_DIRへcdする前に絶対パスへ解決しておく（cd後に解決すると二重パスになる罠）。
CALLER_DIR="$(pwd)"
case "$EXEC_FILE" in
  /*) : ;;
  *) EXEC_FILE="${CALLER_DIR}/${EXEC_FILE}" ;;
esac
case "$OUT_DIR" in
  /*) : ;;
  *) OUT_DIR="${CALLER_DIR}/${OUT_DIR}" ;;
esac

DENOM_DIR="$(mktemp -d)"
GATE_DIR="$(mktemp -d)"
trap 'rm -rf "$DENOM_DIR" "$GATE_DIR"' EXIT

WAR_CLASSES="/usr/local/tomcat/webapps/jpetstore/WEB-INF/classes/org/springframework/samples/jpetstore"
DEST="${DENOM_DIR}/org/springframework/samples/jpetstore"
mkdir -p "$DEST"

echo "[report] extracting denominator classfiles (domain/dao) from container '${CONTAINER_NAME}' ..."
docker cp "${CONTAINER_NAME}:${WAR_CLASSES}/domain" "${DEST}/domain"
docker cp "${CONTAINER_NAME}:${WAR_CLASSES}/dao" "${DEST}/dao"

# --- (a) AC1分母（計測の分母）でのレポート ---
AC1_OUT="${OUT_DIR}/ac1"
mkdir -p "$AC1_OUT"
echo "[report] generating AC1-denominator report -> ${AC1_OUT}"
java -jar "${SCRIPT_DIR}/jacococli.jar" report "$EXEC_FILE" \
  --classfiles "$DENOM_DIR" \
  --html "$AC1_OUT" \
  --xml "${AC1_OUT}/jacoco.xml" \
  --csv "${AC1_OUT}/jacoco.csv"

# --- 除外反証チェック（PO指摘: 除外を機構で担保する） ---
# CSV列: GROUP,PACKAGE,CLASS,INSTRUCTION_MISSED,INSTRUCTION_COVERED,BRANCH_MISSED,BRANCH_COVERED,...
# ($5=INSTRUCTION_COVERED, $7=BRANCH_COVERED。jacococli 0.8.12で実測確認済み)。
echo "[report] verifying excluded classes remain unreachable (0 coverage) ..."
EXCLUDED_CLASSES="SendOrderConfirmationEmailAdvice MsSqlOrderDao OracleSequenceDao"
for cls in $EXCLUDED_CLASSES; do
  row="$(grep ",${cls}," "${AC1_OUT}/jacoco.csv" || true)"
  if [ -z "$row" ]; then
    echo "[report] ERROR: excluded class '${cls}' not found in ${AC1_OUT}/jacoco.csv" >&2
    echo "[report]        (分母ツリーの構成が変わった可能性がある。--classfiles抽出元を確認すること)" >&2
    exit 1
  fi
  instr_covered="$(echo "$row" | awk -F',' '{print $5}')"
  branch_covered="$(echo "$row" | awk -F',' '{print $7}')"
  if [ "$instr_covered" -gt 0 ] || [ "$branch_covered" -gt 0 ]; then
    echo "[report] FAIL: excluded class '${cls}' now has coverage" \
         "(instruction_covered=${instr_covered}, branch_covered=${branch_covered})." >&2
    echo "[report]       '構造的に到達不能(未配線)'という除外の前提が崩れている。" \
         "ゲート分母の再定義とPO再合意が必要（自動ラチェットはしない）。" >&2
    exit 1
  fi
done
echo "[report] OK: all excluded classes remain at 0 coverage (exclusion premise holds)."

# --- (b) ゲート分母（AC1 − 到達不能3クラス）でのレポート ---
cp -r "${DENOM_DIR}/." "${GATE_DIR}/"
rm -f "${GATE_DIR}/org/springframework/samples/jpetstore/domain/logic/SendOrderConfirmationEmailAdvice.class"
rm -f "${GATE_DIR}/org/springframework/samples/jpetstore/dao/ibatis/MsSqlOrderDao.class"
rm -f "${GATE_DIR}/org/springframework/samples/jpetstore/dao/ibatis/OracleSequenceDao.class"

GATE_OUT="${OUT_DIR}/gate"
mkdir -p "$GATE_OUT"
echo "[report] generating gate-denominator report (AC1 minus 3 unreachable classes) -> ${GATE_OUT}"
java -jar "${SCRIPT_DIR}/jacococli.jar" report "$EXEC_FILE" \
  --classfiles "$GATE_DIR" \
  --html "$GATE_OUT" \
  --xml "${GATE_OUT}/jacoco.xml" \
  --csv "${GATE_OUT}/jacoco.csv"

echo "[report] done:"
echo "[report]   AC1分母(計測の分母) : ${AC1_OUT}/index.html"
echo "[report]   ゲート分母(判定用)  : ${GATE_OUT}/index.html"
