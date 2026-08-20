#!/bin/sh
# legacy 起動 + JaCoCo agent（WAR/ソースは無改変・起動オプションのみ）
# legacy-jpetstore/run/entrypoint.sh と同一処理（HSQLDB起動→sleep 6→Tomcat起動）に
# exec catalina.sh run 直前の CATALINA_OPTS 差し込みのみを加えたもの（#50 AC2・design.md §7.3）。
# spike（試作）で実証済みの内容をそのまま正本化（推測で書き直していない）。
set -e
rm -f /hsqldb-db/jpetstore.lck 2>/dev/null || true
mkdir -p /jacoco
java -cp /opt/hsqldb.jar org.hsqldb.Server \
  -database.0 file:/hsqldb-db/jpetstore -dbname.0 "" -port 9002 -no_system_exit true &
sleep 6
export CATALINA_OPTS="-javaagent:/opt/jacocoagent.jar=destfile=/jacoco/jacoco.exec,append=true,includes=org.springframework.samples.jpetstore.*"
echo "[entrypoint] JaCoCo agent enabled -> /jacoco/jacoco.exec"
exec catalina.sh run
