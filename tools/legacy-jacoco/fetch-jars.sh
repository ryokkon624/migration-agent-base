#!/bin/sh
# [L2] #50 AC2: JaCoCo agent/cli jarをMaven Centralから取得しこのディレクトリへ配置する。
# jpetstore-backend の JaCoCo（build.gradle: jacoco { toolVersion = "0.8.12" }）と同版に揃える。
#
# 取得先（jacocoagent.jar / jacococli.jar）は .gitignore 対象（バイナリを版管理しない）。
# 実行後、Dockerfile が同ディレクトリの jacocoagent.jar を COPY する。
set -e
VERSION=0.8.12
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[fetch-jars] downloading org.jacoco.agent:${VERSION}:runtime -> jacocoagent.jar"
curl -fsSL -o jacocoagent.jar \
  "https://repo1.maven.org/maven2/org/jacoco/org.jacoco.agent/${VERSION}/org.jacoco.agent-${VERSION}-runtime.jar"

echo "[fetch-jars] downloading org.jacoco.cli:${VERSION}:nodeps -> jacococli.jar"
curl -fsSL -o jacococli.jar \
  "https://repo1.maven.org/maven2/org/jacoco/org.jacoco.cli/${VERSION}/org.jacoco.cli-${VERSION}-nodeps.jar"

echo "[fetch-jars] done:"
ls -la jacocoagent.jar jacococli.jar
