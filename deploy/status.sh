#!/usr/bin/env bash
# 查看 AI 研发中枢运行状态
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DOCKER_CONFIG="${DOCKER_CONFIG:-/home/wangchong/ai-hub/config/docker}"

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }

echo "━━━ 数据存储（Docker Desktop）━━━"
if docker info >/dev/null 2>&1; then
  docker ps -a --filter name=aihub- --format '  {{.Names}}\t{{.Status}}\t{{.Ports}}'
else
  bad "Docker 守护进程未运行（请在 Windows 启动 Docker Desktop）"
fi

echo
echo "━━━ 后端 Hub ━━━"
if pgrep -f 'hub-server-0.1.0-SNAPSHOT.jar' >/dev/null 2>&1; then
  ok "进程运行中 (pid=$(pgrep -f 'hub-server-0.1.0-SNAPSHOT.jar' | head -1))"
  h=$(curl -s -m 3 http://127.0.0.1:18080/api/health 2>/dev/null)
  if echo "$h" | grep -q '"database":"UP"'; then
    ok "HTTP 18080 可访问，数据库 UP"
  elif [ -n "$h" ]; then
    warn "HTTP 18080 可访问，但数据库 DOWN：$h"
  else
    bad "HTTP 18080 无响应"
  fi
else
  bad "未运行"
fi

echo
echo "━━━ 前端管理后台 ━━━"
if pgrep -f 'vite.*15173' >/dev/null 2>&1; then
  ok "进程运行中 (pid=$(pgrep -f 'vite.*15173' | head -1))"
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 3 http://127.0.0.1:15173/ 2>/dev/null)
  [ "$code" = "200" ] && ok "HTTP 15173 可访问" || bad "HTTP 15173 异常 (status=$code)"
else
  bad "未运行"
fi

echo
echo "━━━ 端口 ━━━"
ss -ltn 2>/dev/null | grep -E ':(18080|15173|13306|16379)\b' | sed 's/^/  /' || warn "无相关端口监听"

echo
echo "━━━ 原生 Agent ━━━"
for a in claude codex opencode; do
  p="/home/wangchong/.npm-global/bin/$a"
  if [ -x "$p" ]; then ok "$a ($p)"; else bad "$a 未安装"; fi
done

echo
echo "日志： /home/wangchong/ai-hub/runtime/{hub,frontend}.log"
