#!/usr/bin/env bash
# 查看 Hub 运行状态：容器 / 端口 / 进程
set -uo pipefail
export DOCKER_CONFIG="${DOCKER_CONFIG:-/home/wangchong/ai-hub/config/docker}"
echo "=== Docker 数据存储 ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "docker 不可用"
echo "=== Hub 进程 ==="
pgrep -af 'hub-server-0.1.0-SNAPSHOT.jar' || echo "后端未运行"
echo "=== 端口 ==="
ss -ltnp 2>/dev/null | grep -E ':(18080|15173|13306|16379)\b' || echo "无监听"
echo "=== 健康检查 ==="
curl -s -o /dev/null -w 'backend /api/auth/login (GET 应为 405 或 200): %{http_code}\n' -m 3 http://127.0.0.1:18080/api/auth/login || true
curl -s -o /dev/null -w 'frontend: %{http_code}\n' -m 3 http://127.0.0.1:15173/ || true
