#!/bin/sh
# [L2] #50/#51 AC3/AC4/AC5/AC-neg3: JaCoCo実測レポートを生成する（採取プロトコルの手順4）。
#
# #51 Q4確定により、1つのexecから **3本** のレポートを出力する:
#   (a) ac1/     … AC1分母（計測の分母・29クラス/解析22。web.struts/web.spring/serviceのみ除外＝ID-5/ID-6）
#   (b) gate/    … #50合意のゲート分母（AC1 − 到達不能3クラス）。継続性のため維持する。
#   (c) gate-v2/ … #51 AC5反映の提案分母（gate − OrderValidator/AccountValidator）。
#
# gate/ と gate-v2/ を同一execに対して出すことで、(a)除外による分母縮小の効果 と
# (b)追加シナリオによる被覆増の効果 を手計算ゼロで分離できる（#51 AC7・R2対策）。
#
# 除外反証チェックは2方式に分ける（#51 Q5確定）:
#   - STRICT（SendOrderConfirmationEmailAdvice/MsSqlOrderDao/OracleSequenceDao）: 従来どおり `==0` を維持
#     （一度も生成されない＝真の0が前提のため。#50から継続）。
#   - BASELINE（OrderValidator/AccountValidator）: 実測ベースライン（instruction_covered=3・
#     branch_covered=0、根拠は#51 T5 out2/report/ac1/jacoco.csv）からの `!=` でfailする。
#     増（呼び出し元が到達不能という前提の崩壊）と減（bean定義自体の変化）でメッセージを書き分ける。
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
#   <out_dir>/ac1/     … AC1分母（29クラス/解析22）でのレポート（index.html/jacoco.xml/jacoco.csv）
#   <out_dir>/gate/    … #50ゲート分母（AC1 − 到達不能3クラス）でのレポート（同上・継続性）
#   <out_dir>/gate-v2/ … #51提案ゲート分母（gate − OrderValidator/AccountValidator）でのレポート（同上）
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
GATE_V2_DIR="$(mktemp -d)"
trap 'rm -rf "$DENOM_DIR" "$GATE_DIR" "$GATE_V2_DIR"' EXIT

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

# CSV列: GROUP,PACKAGE,CLASS,INSTRUCTION_MISSED,INSTRUCTION_COVERED,BRANCH_MISSED,BRANCH_COVERED,...
# ($5=INSTRUCTION_COVERED, $7=BRANCH_COVERED。jacococli 0.8.12で実測確認済み)。

# --- 除外反証チェック(1) STRICT: ==0 を維持（#50から継続） ---
echo "[report] verifying STRICT-excluded classes remain unreachable (0 coverage) ..."
STRICT_EXCLUDED="SendOrderConfirmationEmailAdvice MsSqlOrderDao OracleSequenceDao"
for cls in $STRICT_EXCLUDED; do
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
echo "[report] OK: all STRICT-excluded classes remain at 0 coverage (exclusion premise holds)."

# --- 除外反証チェック(2) BASELINE: #51 AC5・実測ベースラインからの!=でfail（Q5確定） ---
echo "[report] verifying BASELINE-excluded classes (OrderValidator/AccountValidator) match baseline ..."
BASELINE_EXCLUDED="OrderValidator:3:0 AccountValidator:3:0"
for entry in $BASELINE_EXCLUDED; do
  cls="$(echo "$entry" | cut -d: -f1)"
  baseline_instr="$(echo "$entry" | cut -d: -f2)"
  baseline_branch="$(echo "$entry" | cut -d: -f3)"
  row="$(grep ",${cls}," "${AC1_OUT}/jacoco.csv" || true)"
  if [ -z "$row" ]; then
    echo "[report] ERROR: baseline class '${cls}' not found in ${AC1_OUT}/jacoco.csv" >&2
    echo "[report]        (分母ツリーの構成が変わった可能性がある。--classfiles抽出元を確認すること)" >&2
    exit 1
  fi
  instr_covered="$(echo "$row" | awk -F',' '{print $5}')"
  branch_covered="$(echo "$row" | awk -F',' '{print $7}')"
  if [ "$instr_covered" -ne "$baseline_instr" ] || [ "$branch_covered" -ne "$baseline_branch" ]; then
    if [ "$instr_covered" -gt "$baseline_instr" ] || [ "$branch_covered" -gt "$baseline_branch" ]; then
      echo "[report] FAIL: baseline class '${cls}' exceeds baseline" \
           "(instruction_covered=${instr_covered} baseline=${baseline_instr}," \
           "branch_covered=${branch_covered} baseline=${baseline_branch})." >&2
      echo "[report]       増＝「呼び出し元が到達不能」という除外の前提が崩れた。" \
           "ゲート分母の再定義とPO再合意が必要（自動ラチェットはしない）。" >&2
    else
      echo "[report] FAIL: baseline class '${cls}' is below baseline" \
           "(instruction_covered=${instr_covered} baseline=${baseline_instr}," \
           "branch_covered=${branch_covered} baseline=${baseline_branch})." >&2
      echo "[report]       減＝bean定義自体が変化した(インスタンス化されなくなった)。" \
           "ベースライン値の実測根拠がstale化している。再実測が必要。" >&2
    fi
    exit 1
  fi
done
echo "[report] OK: all BASELINE-excluded classes match their baseline (exclusion premise holds)."

# --- (b) #50ゲート分母（AC1 − 到達不能3クラス）でのレポート ---
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

# --- (c) #51提案ゲート分母（gate − OrderValidator/AccountValidator）でのレポート ---
cp -r "${GATE_DIR}/." "${GATE_V2_DIR}/"
rm -f "${GATE_V2_DIR}/org/springframework/samples/jpetstore/domain/logic/OrderValidator.class"
rm -f "${GATE_V2_DIR}/org/springframework/samples/jpetstore/domain/logic/AccountValidator.class"

GATE_V2_OUT="${OUT_DIR}/gate-v2"
mkdir -p "$GATE_V2_OUT"
echo "[report] generating gate-v2-denominator report (gate minus OrderValidator/AccountValidator) -> ${GATE_V2_OUT}"
java -jar "${SCRIPT_DIR}/jacococli.jar" report "$EXEC_FILE" \
  --classfiles "$GATE_V2_DIR" \
  --html "$GATE_V2_OUT" \
  --xml "${GATE_V2_OUT}/jacoco.xml" \
  --csv "${GATE_V2_OUT}/jacoco.csv"

echo "[report] done:"
echo "[report]   AC1分母(計測の分母)         : ${AC1_OUT}/index.html"
echo "[report]   #50ゲート分母(継続性)        : ${GATE_OUT}/index.html"
echo "[report]   #51提案ゲート分母(判定用候補) : ${GATE_V2_OUT}/index.html"
