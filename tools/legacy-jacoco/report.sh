#!/bin/sh
# [L2] #50 AC3/AC4: JaCoCo実測レポートを生成する（採取プロトコルの手順4）。
#
# 前提:
#   - captureGolden 実行中、agent付きコンテナを `-v <host_out>:/jacoco` でマウントしていたこと
#   - `docker stop -t 30`（graceful）でコンテナを停止済み（強制停止するとexecが書かれない）
#   - コンテナ自体はまだ削除していないこと（--classfiles抽出に docker cp を使うため）
#   - ./fetch-jars.sh 済み（jacococli.jarが本ディレクトリにあること）
#
# 使い方:
#   ./report.sh <container_name> <exec_file_path> <out_dir>
#   例: ./report.sh jpetstore-legacy-parity ./out/jacoco.exec ./out/report
#
# --classfiles には AC1 の分母（domain/dao配下のみ）だけを置いたツリーを渡す
# （WEB-INF/classes から org/springframework/samples/jpetstore/{domain,dao} のみ抽出）。
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
trap 'rm -rf "$DENOM_DIR"' EXIT

WAR_CLASSES="/usr/local/tomcat/webapps/jpetstore/WEB-INF/classes/org/springframework/samples/jpetstore"
DEST="${DENOM_DIR}/org/springframework/samples/jpetstore"
mkdir -p "$DEST"

echo "[report] extracting denominator classfiles (domain/dao) from container '${CONTAINER_NAME}' ..."
docker cp "${CONTAINER_NAME}:${WAR_CLASSES}/domain" "${DEST}/domain"
docker cp "${CONTAINER_NAME}:${WAR_CLASSES}/dao" "${DEST}/dao"

mkdir -p "$OUT_DIR"
echo "[report] generating jacoco report -> ${OUT_DIR}"
java -jar "${SCRIPT_DIR}/jacococli.jar" report "$EXEC_FILE" \
  --classfiles "$DENOM_DIR" \
  --html "$OUT_DIR" \
  --xml "${OUT_DIR}/jacoco.xml"

echo "[report] done: ${OUT_DIR}/index.html"
