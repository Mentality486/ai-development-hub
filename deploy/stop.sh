#!/usr/bin/env bash
# 停止 AI 研发中枢：后端 + 前端 dev
# 用法：
#   bash deploy/stop.sh           # 停止后端与前端（容器保留）
#   bash deploy/stop.sh --all     # 连 MySQL/Redis 容器一起停
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_DIR="${HUB_RUN_DIR:-/home/wangchong/ai-hub/runtime}"
export DOCKER_CONFIG="${DOCKER_CONFIG:-/home/wangchong/ai-hub/config/docker}"

echo "▶ 停止后端..."
if pkill -f 'hub-server-0.1.0-SNAPSHOT.jar'; then echo "  ✓ 已停止"; else echo "  （未在运行）"; fi
rm -f "$RUN_DIR/hub.pid"

echo "▶ 停止前端..."
if pkill -f 'vite.*15173'; then echo "  ✓ 已停止"; else echo "  （未在运行）"; fi
rm -f "$RUN_DIR/frontend.pid"

if [ "${1:-}" = "--all" ]; then
  echo "▶ 停止 MySQL/Redis 容器..."
  ( cd deploy && docker compose --env-file .env down ) && echo "  ✓ 已停止（数据卷保留）"
fi

echo "完成。数据不会丢失。"
