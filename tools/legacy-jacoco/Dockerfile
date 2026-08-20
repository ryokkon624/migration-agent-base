# [L2] #50 AC2: jpetstore-legacy（無改変）にJaCoCoエージェントを被せるoverlayイメージ。
# legacy-jpetstore側の run/Dockerfile・run/entrypoint.sh・アプリのソース/WARは一切変更しない
# （凍結アーティファクトの原則）。別タグ（jpetstore-legacy-jacoco）でビルドすること。
#
# build context = このディレクトリ（tools/legacy-jacoco）。
# 事前に ./fetch-jars.sh を実行し jacocoagent.jar を配置しておくこと（README.md参照）。
#
#   docker build -t jpetstore-legacy-jacoco tools/legacy-jacoco
#
# spike（試作）で実証済みの構成をそのまま正本化したもの（design.md §7.3・推測で書き直していない）。
FROM jpetstore-legacy
COPY jacocoagent.jar /opt/jacocoagent.jar
COPY entrypoint-jacoco.sh /entrypoint-jacoco.sh
RUN sed -i 's/\r$//' /entrypoint-jacoco.sh && chmod +x /entrypoint-jacoco.sh
ENTRYPOINT ["/entrypoint-jacoco.sh"]
