#!/usr/bin/env bash
# 启动 Hub 后端 + 前端 dev（数据存储容器由 docker compose 单独管理）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f deploy/.env ]; then
  set -a; source deploy/.env; set +a
fi
export DB_PASSWORD="${MYSQL_PASSWORD:-$DB_PASSWORD}"
export REDIS_PASSWORD="${REDIS_PASSWORD:-}"

if [ ! -f hub-server/target/hub-server-0.1.0-SNAPSHOT.jar ]; then
  echo "后端 jar 不存在，请先执行: mvn -DskipTests package"
  exit 1
fi

nohup java -jar hub-server/target/hub-server-0.1.0-SNAPSHOT.jar > "${HUB_LOG:-/tmp/aihub-boot.log}" 2>&1 &
echo "backend pid=$! port=18080"

if command -v npm >/dev/null 2>&1 && [ -d frontend ]; then
  (cd frontend && nohup npm run dev > "${FE_LOG:-/tmp/aihub-frontend.log}" 2>&1 &)
  echo "frontend port=15173"
fi
