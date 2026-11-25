#!/usr/bin/env bash
# 停止 Hub 后端与前端 dev 进程
set -euo pipefail
pkill -f 'hub-server-0.1.0-SNAPSHOT.jar' 2>/dev/null || true
pkill -f 'vite --host 127.0.0.1 --port 15173' 2>/dev/null || true
echo "stopped hub backend and frontend dev"
