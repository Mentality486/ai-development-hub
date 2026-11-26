#!/usr/bin/env bash
# 启动 AI 研发中枢：MySQL/Redis 容器 + Hub 后端 + 前端 dev
#
# 用法：
#   bash deploy/start.sh          # 启动全部
#   bash deploy/start.sh backend  # 只启动后端
#   bash deploy/start.sh frontend # 只启动前端
#
# 说明：Agent 与构建 100% 在 WSL Native 执行；Docker 仅承载 MySQL/Redis 数据存储。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_DIR="${HUB_RUN_DIR:-/home/wangchong/ai-hub/runtime}"
mkdir -p "$RUN_DIR"
HUB_LOG="${HUB_LOG:-$RUN_DIR/hub.log}"
FE_LOG="${FE_LOG:-$RUN_DIR/frontend.log}"
HUB_PID_FILE="$RUN_DIR/hub.pid"
FE_PID_FILE="$RUN_DIR/frontend.pid"

TARGET="${1:-all}"

# ---------- 读取凭据（deploy/.env 不入 Git） ----------
if [ -f deploy/.env ]; then
  set -a; source deploy/.env; set +a
else
  echo "⚠ 缺少 deploy/.env，数据库密码将为空。请先: cp deploy/.env.example deploy/.env"
fi
export DB_PASSWORD="${MYSQL_PASSWORD:-${DB_PASSWORD:-}}"
export REDIS_PASSWORD="${REDIS_PASSWORD:-}"
# Docker Desktop 的 credsStore 是 Windows helper，Linux 下不可用，使用项目级空配置
export DOCKER_CONFIG="${DOCKER_CONFIG:-/home/wangchong/ai-hub/config/docker}"

# ---------- 1. 数据存储 ----------
start_storage() {
  echo "▶ 启动 MySQL 8 / Redis 7 容器..."
  if ! docker info >/dev/null 2>&1; then
    echo "✗ Docker 守护进程未运行。请先在 Windows 启动 Docker Desktop 后重试。"
    return 1
  fi
  ( cd deploy && docker compose --env-file .env up -d ) || return 1

  echo -n "  等待容器健康"
  for _ in $(seq 1 30); do
    local s
    s="$(docker ps --filter name=aihub-mysql --filter name=aihub-redis --format '{{.Status}}' | grep -c healthy)"
    if [ "$s" -ge 2 ]; then echo " ✓"; return 0; fi
    echo -n "."; sleep 2
  done
  echo " ✗ 超时（查看: docker logs aihub-mysql）"
  return 1
}

# ---------- 2. 后端 ----------
start_backend() {
  if pgrep -f 'hub-server-0.1.0-SNAPSHOT.jar' >/dev/null 2>&1; then
    echo "▶ 后端已在运行 (pid=$(pgrep -f 'hub-server-0.1.0-SNAPSHOT.jar' | head -1))"
    return 0
  fi
  if [ ! -f hub-server/target/hub-server-0.1.0-SNAPSHOT.jar ]; then
    echo "✗ 后端 jar 不存在，请先执行: mvn -DskipTests package"
    return 1
  fi
  echo "▶ 启动后端 (18080)..."
  # setsid：让进程脱离当前终端会话，关闭终端/退出 SSH 不会带走服务
  setsid nohup java -jar hub-server/target/hub-server-0.1.0-SNAPSHOT.jar \
    > "$HUB_LOG" 2>&1 < /dev/null &
  echo $! > "$HUB_PID_FILE"

  echo -n "  等待后端就绪"
  for _ in $(seq 1 60); do
    if curl -s -o /dev/null -m 2 http://127.0.0.1:18080/api/auth/login; then
      echo " ✓ (pid=$(cat "$HUB_PID_FILE"))"; return 0
    fi
    echo -n "."; sleep 2
  done
  echo " ✗ 启动失败，日志尾部："
  tail -30 "$HUB_LOG"
  return 1
}

# ---------- 3. 前端 ----------
start_frontend() {
  if pgrep -f 'vite.*15173' >/dev/null 2>&1; then
    echo "▶ 前端已在运行 (pid=$(pgrep -f 'vite.*15173' | head -1))"
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    echo "✗ 未找到 npm，跳过前端"
    return 1
  fi
  if [ ! -d frontend/node_modules ]; then
    echo "▶ 首次运行，安装前端依赖（可能较慢）..."
    ( cd frontend && npm install --no-audit --no-fund ) || return 1
  fi
  echo "▶ 启动前端 dev (15173)..."
  ( cd frontend && setsid nohup npm run dev > "$FE_LOG" 2>&1 < /dev/null & echo $! > "$FE_PID_FILE" )

  echo -n "  等待前端就绪"
  for _ in $(seq 1 30); do
    if curl -s -o /dev/null -m 2 http://127.0.0.1:15173/; then
      echo " ✓"; return 0
    fi
    echo -n "."; sleep 1
  done
  echo " ✗ 启动失败，日志尾部："
  tail -20 "$FE_LOG"
  return 1
}

# ---------- 主流程 ----------
case "$TARGET" in
  backend)  start_backend ;;
  frontend) start_frontend ;;
  storage)  start_storage ;;
  all)
    start_storage
    start_backend || exit 1
    start_frontend || echo "  （前端未启动，可稍后单独执行: bash deploy/start.sh frontend）"
    ;;
  *) echo "用法: bash deploy/start.sh [all|backend|frontend|storage]"; exit 1 ;;
esac

if [ "$TARGET" = "all" ]; then
  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AI 研发中枢已启动
  管理后台   http://127.0.0.1:15173
  后端 API   http://127.0.0.1:18080
  默认账号   admin / Admin@123456   ← 首次登录后请立即修改
  查看状态   bash deploy/status.sh
  停止服务   bash deploy/stop.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
fi
