# 核心 API 接口设计

> 版本：v1.0　编写日期：2026-11-25　状态：待确认
> 约定：所有 `/api/**` 需 JWT；`/v1/chat/completions` 需独立 API Key。统一响应结构见第一节。

---

## 一、通用约定

### 1.1 统一响应

```json
{
  "code": 0,
  "message": "ok",
  "data": { },
  "traceId": "b7f3c2a1e9d44f0b",
  "timestamp": 1795000000123
}
```

- `code=0` 表示成功；非 0 为错误码。
- HTTP 状态码与业务码并存：鉴权失败返 401，权限不足 403，参数错误 400，其余业务错误一律 200 + 非 0 code（与 PMS 习惯一致，减少前端分支）。

### 1.2 分页

请求：`?page=1&size=20&sort=created_at,desc`
响应：

```json
{ "code":0, "data": { "records": [], "total": 137, "page": 1, "size": 20, "pages": 7 } }
```

`size` 上限 200，超限自动截断并在 `message` 提示。

### 1.3 错误码段位

| 段 | 含义 | 示例 |
| --- | --- | --- |
| 0 | 成功 | |
| 1000–1999 | 通用/参数 | 1001 参数校验失败 |
| 2000–2999 | 认证授权 | 2001 未登录、2003 无权限 |
| 3000–3999 | 项目/工作区 | 3001 路径非 WSL、3002 路径不存在 |
| 4000–4999 | Agent | 4001 Agent 离线、4002 并发已满、4003 ACP 握手失败 |
| 5000–5999 | 任务/调度 | 5001 非法状态迁移、5002 无可用 Agent、5003 任务超时 |
| 6000–6999 | 审批 | 6001 审批不存在、6002 已过期 |
| 7000–7999 | 渠道/微信 | 7001 非白名单、7002 渠道离线 |
| 9000–9999 | 系统 | 9001 内部错误 |

### 1.4 鉴权

| 接口组 | 方式 |
| --- | --- |
| `/api/**` | `Authorization: Bearer <jwt>`，JWT 内 `uid`、`roles` |
| `/v1/chat/completions` | `Authorization: Bearer <channel-api-key>`（独立于用户 JWT） |
| `/actuator/health` | 无鉴权，仅本机 |

---

## 二、微信兼容接口（WeClaw → Hub）

### POST /v1/chat/completions

**目的**：让 WeClaw 的 HTTP Agent 模式把微信私聊消息送进 Hub。

**请求**（严格按 OpenAI Chat Completions 格式，超集字段放 `metadata`）

```json
{
  "model": "ai-hub",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "帮我检查一下明景 PMS 项目最近有没有明显 Bug" }
  ],
  "stream": false,
  "user": "wxid_abc123",
  "metadata": {
    "channel": "wechat",
    "external_msg_id": "msg_8891",
    "sender_name": "王工",
    "chat_type": "private"
  }
}
```

**响应（非 stream）**

```json
{
  "id": "chatcmpl-8f2a1c",
  "object": "chat.completion",
  "created": 1795000000,
  "model": "ai-hub",
  "choices": [{
    "index": 0,
    "message": { "role": "assistant", "content": "收到，我先看项目最近改动，稍后汇报。" },
    "finish_reason": "stop"
  }],
  "usage": { "prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0 }
}
```

**响应（stream）**：标准 SSE，`data: {...}` 逐块，末尾 `data: [DONE]`。

**行为约定（重要）**

| 项 | 约定 |
| --- | --- |
| 阻塞时长 | **≤2 秒返回受理语**，绝不等任务完成。长任务结果由 Hub 主动推 `POST /api/send` |
| 身份识别 | 优先 `metadata.external_msg_id` → 其次 `user` 字段 → 最后对 `messages` 最后一条内容做 hash。三者都无则拒绝（400） |
| 白名单 | `user` 未在 `sys_user.wechat_id` 或 `hub_channel_session` 中 → 返回固定文案"你没有使用权限"，写审计，不建任务 |
| 幂等 | 同一 `external_msg_id` 60 秒内重复 → 直接返回上一次的受理语，不重复建任务 |
| 会话隔离 | `(channel_id, external_user_id)` → 唯一 `conversation_id`，不同用户绝不共享上下文 |
| 鉴权 | `Authorization: Bearer <API_KEY>`，Key 存 `hub_channel.config_json`（值加密）或 env |
| 命令 | 内容以 `/` 开头走命令分发（`/help` `/agents` `/status` `/tasks` `/projects` `/cancel TASK-10001`），不建任务 |

**错误响应**：仍按 OpenAI 错误格式

```json
{ "error": { "message": "unauthorized sender", "type": "invalid_request_error", "code": "7001" } }
```

---

## 三、Agent 管理

| 方法 | 路径 | 说明 | 权限 |
| --- | --- | --- | --- |
| GET | `/api/agents` | 列表（支持 `?status=&type=`） | agent:read |
| GET | `/api/agents/{id}` | 详情 | agent:read |
| POST | `/api/agents/discover` | 触发全量发现（异步，返回 jobId） | agent:discover |
| POST | `/api/agents/{id}/health-check` | 单 Agent 健康检查（同步，≤10 s） | agent:discover |
| GET | `/api/agents/{id}/capabilities` | 能力列表 | agent:read |
| PUT | `/api/agents/{id}/capabilities` | 批量更新能力权重 | agent:write |
| GET | `/api/agents/{id}/status-history` | 状态历史（分页） | agent:read |
| PUT | `/api/agents/{id}` | 修改配置（maxConcurrency、acpCommand、workDir） | agent:write |

**GET /api/agents 响应样例**

```json
{
  "code": 0,
  "data": {
    "records": [{
      "id": "1839200173381234",
      "agentCode": "claude-code",
      "name": "Claude Code",
      "agentType": "CLAUDE_CODE",
      "executablePath": "/home/wangchong/.npm-global/bin/claude",
      "version": "2.1.332",
      "model": "claude-sonnet-4-5",
      "protocol": "ACP",
      "acpCommand": "claude-agent-acp",
      "status": "ONLINE",
      "statusMessage": null,
      "currentSessions": 1,
      "maxConcurrency": 3,
      "workDir": "/home/wangchong/projects",
      "lastHeartbeatAt": "2026-11-25T15:40:12.331+08:00",
      "lastError": null
    }],
    "total": 3, "page": 1, "size": 20, "pages": 1
  }
}
```

**POST /api/agents/discover 响应**

```json
{ "code":0, "data": { "jobId":"disc-20261125-154012", "accepted":true } }
```
异步进度通过 `GET /api/monitor/agents` 或 SSE `/api/sse/agents` 观察。

**发现流程的九态判定（必须严格按此顺序，不允许只 which）**

| 步骤 | 检查 | 失败映射 |
| --- | --- | --- |
| 1 | `executable_path` 存在且**在 Linux 内可执行**（`Files.isRegularFile` + 试运行 `--version`） | `NOT_INSTALLED` |
| 2 | 版本号可解析 | `INSTALLED` |
| 3 | 凭据文件存在（`~/.claude`、`~/.codex`、`~/.local/share/opencode`）或 `--version` 返回已认证标识 | `UNLICENSED` |
| 4 | ACP 适配器可执行（`acp_command` 在 PATH） | `CONNECTABLE` 降级为 CLI |
| 5 | ACP `initialize` 握手成功 | `CONNECTABLE` |
| 6 | `session/new` 成功 | `ONLINE` |
| 7 | 心跳超时（>90 s 无事件） | `OFFLINE` |
| 8 | 握手抛异常/进程崩溃 | `ERROR` |
| 9 | 能力集与任务类型无交集 | `UNSUPPORTED` |

> 只要 1 命中而 2 不命中，就是"装了但跑不起来"，必须报 `ERROR` 并附 stderr 首行——这正是本机 `/mnt/d` shim 的场景。

---

## 四、任务管理

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/tasks` | 新建任务（管理后台手工建，非微信入口） |
| GET | `/api/tasks` | 列表（`?status=&projectId=&agentId=&keyword=&from=&to=`） |
| GET | `/api/tasks/{id}` | 详情（含 steps、agents、最近日志） |
| GET | `/api/tasks/{id}/logs` | 日志分页（`?type=&level=&afterSeq=`） |
| GET | `/api/tasks/{id}/diff` | Git Diff（`?format=unified\|stat\|files`） |
| GET | `/api/tasks/{id}/report` | 执行报告（Markdown 文本） |
| POST | `/api/tasks/{id}/cancel` | 取消 |
| POST | `/api/tasks/{id}/pause` | 暂停 |
| POST | `/api/tasks/{id}/resume` | 恢复 |
| POST | `/api/tasks/{id}/retry` | 重试（`{"fromStep": 3}` 可选） |
| POST | `/api/tasks/{id}/approve` | 对任务级审批动作（与 /api/approvals 二选一，建议走审批中心） |

**POST /api/tasks 请求**

```json
{
  "title": "检查 PMS 最近 Bug",
  "rawRequirement": "帮我检查一下明景 PMS 项目最近有没有明显 Bug",
  "projectId": "1839000000000001",
  "taskType": "CODE_ANALYSIS",
  "complexity": "MEDIUM",
  "priority": 50,
  "preferredAgentId": null,
  "autoDispatch": true
}
```

**GET /api/tasks/{id} 响应（节选关键字段）**

```json
{
  "code": 0,
  "data": {
    "id": "1839200173389999",
    "taskNo": "TASK-10001",
    "title": "检查 PMS 最近 Bug",
    "rawRequirement": "帮我检查一下明景 PMS 项目最近有没有明显 Bug",
    "taskType": "CODE_ANALYSIS",
    "complexity": "MEDIUM",
    "status": "VERIFYING",
    "project": { "id": "...", "name": "明景 PMS", "localPath": "/home/wangchong/projects/mgiot-pms" },
    "primaryAgent": { "id": "...", "name": "Claude Code" },
    "collaborators": [{ "id": "...", "name": "Codex", "role": "REVIEWER" }],
    "analysisSummary": "项目为 Spring Boot + Vue3 单体仓库，最近 30 天变更集中在审批引擎…",
    "dispatchReason": "候选 3 个；claude-code 能力匹配 92/加载 33%/历史成功率 94% → 得分 86；codex 得分 74；opencode 得分 61。选 claude-code。",
    "plan": [ { "seq":1, "title":"静态扫描", "agentId":"...", "status":"SUCCESS" } ],
    "worktreePath": "/home/wangchong/ai-hub/worktrees/task-10001",
    "branchName": "hub/task-10001",
    "buildResult": "SUCCESS",
    "testResult": "SUCCESS",
    "diffStat": "3 files changed, 42 insertions(+), 8 deletions(-)",
    "startedAt": "2026-11-25T15:41:00+08:00",
    "finishedAt": null
  }
}
```

**状态迁移的 API 校验**：`pause` 仅允许 `RUNNING|QUEUED`；`resume` 仅 `PAUSED`；`cancel` 不允许终态；`retry` 仅 `FAILED`。违反返 5001 并列出允许的状态。

---

## 五、项目管理

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/projects` | 注册项目 |
| GET | `/api/projects` | 列表 |
| GET | `/api/projects/{id}` | 详情 |
| PUT | `/api/projects/{id}` | 更新 |
| DELETE | `/api/projects/{id}` | 逻辑删除（有运行中任务则拒绝） |
| POST | `/api/projects/{id}/validate` | 校验路径/Git/工具链可用性 |
| GET | `/api/projects/{id}/config` | 项目配置键值 |
| PUT | `/api/projects/{id}/config` | 批量 upsert 配置 |

**POST /api/projects 请求**

```json
{
  "name": "明景 PMS",
  "projectNo": "PRJ-0001",
  "type": "MIXED",
  "description": "企业项目/投诉/服务单管理系统",
  "localPath": "/home/wangchong/projects/mgiot-pms",
  "gitUrl": "http://gitlab.example.com/mk/end/mgiot-pms.git",
  "defaultBranch": "v2.x",
  "techStack": "Spring Boot 3.2 + Vue 3 + MyBatis-Plus",
  "jdkVersion": "17",
  "nodeVersion": "22",
  "buildCommand": "mvn -o -DskipTests compile",
  "testCommand": "mvn -o test",
  "rulesFile": "AGENTS.md"
}
```

**路径校验（服务端强制）**

| 规则 | 失败码 |
| --- | --- |
| 必须 `/` 开头 | 3001 |
| 禁止 `^/mnt/[a-z]/` | 3001（Windows 映射路径） |
| 禁止含 `\\\\wsl.localhost` 或 `\\\\wsl$` | 3001 |
| 路径必须存在且为目录 | 3002 |
| 必须是 Git 仓库（有 `.git`） | 3003 |
| 不允许指向 `~/ai-hub/worktrees` 下 | 3004 |

---

## 六、审批管理

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/approvals` | 列表（`?status=&type=&riskLevel=`） |
| GET | `/api/approvals/{id}` | 详情 |
| POST | `/api/approvals/{id}/approve` | 通过（`{"comment":"..."}`） |
| POST | `/api/approvals/{id}/reject` | 拒绝 |
| GET | `/api/approvals/pending/count` | 待办数（用于顶部红点） |

审批与执行的关系：

```
运行时遇到需审批动作
   ├─ 创建 hub_approval(status=PENDING, expires_at=now+30min)
   ├─ 任务转 WAITING_APPROVAL，进程保持挂起（ACP 的 session/request_permission 不回响应）
   ├─ 微信推送审批卡片（含编号 + 风险等级 + 动作摘要）
   ├─ 用户回复"/approve APR-0007" 或 Web 点击
   ├─ APPROVED → 回 ACP 响应 allow → 任务继续
   └─ REJECTED/EXPIRED → 回 deny → Agent 收到拒绝，任务转 FAILED(原因=审批拒绝)
```

---

## 七、系统监控

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/monitor/overview` | 首页聚合 |
| GET | `/api/monitor/agents` | Agent 维度统计 |
| GET | `/api/monitor/tasks` | 任务维度统计 |
| GET | `/api/monitor/tasks/trend` | 近 N 天趋势（`?days=7`） |
| GET | `/api/monitor/system` | JVM/磁盘/DB 连接池 |
| GET | `/api/monitor/anomalies` | 最近异常 |

**GET /api/monitor/overview 响应**

```json
{
  "code": 0,
  "data": {
    "agents": { "total": 3, "online": 2, "busy": 1, "offline": 1 },
    "tasks": { "today": 12, "running": 2, "success": 8, "failed": 2, "queued": 1 },
    "wechat": { "connected": true, "lastHeartbeatAt": "2026-11-25T15:40:00+08:00", "accountName": "小明助理" },
    "recentTasks": [ { "taskNo":"TASK-10012", "title":"...", "status":"SUCCESS", "agent":"Claude Code", "createdAt":"..." } ],
    "recentAnomalies": [ { "level":"ERROR", "message":"Agent codex 握手失败: Exec format error", "at":"..." } ]
  }
}
```

---

## 八、其他必要接口

### 8.1 认证

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/login` | 账号密码登录，返 JWT + refresh |
| POST | `/api/auth/refresh` | 刷新 |
| POST | `/api/auth/logout` | 登出（JWT 加黑名单到 Redis） |
| GET | `/api/auth/me` | 当前用户 + 权限列表 |

### 8.2 AI 身份

| 方法 | 路径 |
| --- | --- |
| GET/POST | `/api/identities` |
| GET/PUT/DELETE | `/api/identities/{id}` |
| GET | `/api/identities/{id}/files` （列出 profile/personality/... 内容） |
| PUT | `/api/identities/{id}/files/{name}` （编辑 Markdown） |

### 8.3 记忆

| 方法 | 路径 |
| --- | --- |
| GET/POST | `/api/memories` |
| GET/PUT/DELETE | `/api/memories/{id}` |
| GET | `/api/memories/search?q=&scope=` |

### 8.4 渠道（微信连接管理）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/channels` | 渠道列表与状态 |
| POST | `/api/channels/{id}/test` | 发送测试消息 |
| GET | `/api/channels/{id}/qrcode` | 触发重新扫码（如有） |
| GET | `/api/channels/{id}/sessions` | 渠道会话列表 |

### 8.5 调度规则与系统配置

| 方法 | 路径 |
| --- | --- |
| GET/PUT | `/api/schedule-rules` `/api/schedule-rules/{id}` |
| GET/PUT | `/api/system-configs` |

### 8.6 审计

| 方法 | 路径 |
| --- | --- |
| GET | `/api/audit-logs`（`?userId=&action=&from=&to=`） |

### 8.7 实时推送（SSE）

| 路径 | 事件 |
| --- | --- |
| `/api/sse/tasks/{id}` | `state` / `log` / `done` |
| `/api/sse/agents` | `status` |
| `/api/sse/dashboard` | `overview` |

---

## 九、接口清单与阶段对应

| 阶段 | 交付接口 |
| --- | --- |
| 一 | `/api/auth/*`、`/api/system-configs`、`/api/monitor/overview`（骨架数据） |
| 二 | `/api/agents/*` |
| 三 | `/api/sse/tasks/{id}`、内部 ACP 相关 |
| 四 | `/api/tasks/*`、`/api/schedule-rules` |
| 五 | `/api/projects/*`、`/api/tasks/{id}/diff|report` |
| 六 | `/v1/chat/completions`、`/api/channels/*` |
| 七 | 全部补齐 + `/api/sse/dashboard` |

> 每个接口在实现时同步更新 `docs/api/*.md`（OpenAPI 由 springdoc 生成，手写文档只写"业务语义与坑"）。
