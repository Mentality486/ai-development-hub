# AI 研发中枢（AI Development Hub）

> 运行在 **WSL Ubuntu Native** 环境的本地化、多 Agent 协同 AI 研发管理系统。
> 一个 AI 虚拟员工身份（**小明 · AI 研发总监**）统一指挥多个专业代码 Agent，微信为沟通入口，Web 为管理与审计入口。

**当前进度：第一阶段（基础工程）已完成并验收通过。** 详见 [第一阶段验收报告](docs/第一阶段验收报告.md)。

---

## 一、这个系统是什么

不是微信聊天机器人，而是一个 AI Agent 管理平台：

- **用户只管一个 AI**：AI 研发总监"小明"，由它理解需求、拆解任务、选择 Agent、监督执行、验收结果、汇报进度。
- **底层 Agent 只做专业活**：Claude Code / Codex / OpenCode 各负责擅长的任务，由小明调度。
- **代码执行 100% 在 WSL Native**：Git Worktree、Maven 构建、Node 构建、测试全部在 WSL 文件系统执行，**禁止**复制到 Windows 临时目录或 Docker 里跑代码。
- **微信是入口，Web 是驾驶舱**：日常对话在微信，配置/监控/审计在 Web 后台。

---

## 二、快速启动

### 前置条件

| 组件 | 要求 | 检查命令 |
| --- | --- | --- |
| Ubuntu (WSL) | 22.04 / 24.04，systemd 启用 | `cat /etc/os-release` |
| JDK | **21**（Hub 用）| `java -version` |
| Maven | 3.9+ | `mvn -version` |
| Node | 20+（推荐 22）| `node -v` |
| Docker Desktop | Windows 侧已启动，WSL 集成开启 | `docker info` |

### 三步启动

```bash
cd /home/wangchong/projects/ai-development-hub

# 1. 首次运行：准备凭据（.env 不入 Git）
cp deploy/.env.example deploy/.env
#    编辑 deploy/.env，填入你自己的强密码

# 2. 首次运行：构建后端
mvn -DskipTests package

# 3. 启动全部（MySQL/Redis 容器 + 后端 + 前端）
bash deploy/start.sh
```

启动成功后：

| 服务 | 地址 |
| --- | --- |
| **管理后台** | http://127.0.0.1:15173 |
| **后端 API** | http://127.0.0.1:18080 |
| 健康检查 | http://127.0.0.1:18080/api/health |

**默认账号：`admin` / `Admin@123456`** —— 首次登录后请立即修改。

### 常用运维命令

```bash
bash deploy/status.sh          # 查看所有组件状态（容器/后端/前端/端口/Agent）
bash deploy/stop.sh            # 停止后端与前端（数据保留）
bash deploy/stop.sh --all      # 连 MySQL/Redis 容器一起停
bash deploy/start.sh backend   # 只启后端
bash deploy/start.sh frontend  # 只启前端
bash deploy/start.sh storage   # 只启 MySQL/Redis
```

日志：`/home/wangchong/ai-hub/runtime/{hub,frontend}.log`

---

## 三、MySQL / Redis 账号密码

> ⚠️ **凭据只存在于本机 `deploy/.env`（600 权限，已加入 `.gitignore`，不进版本库）。**
> 出于安全考虑，本文不记录任何真实密码。查看方式：

```bash
cat deploy/.env
```

### MySQL 8.0

| 项 | 值 |
| --- | --- |
| 容器名 | `aihub-mysql` |
| 宿主地址 | `127.0.0.1`**:**`13306`（容器内 3306）|
| 数据库 | `ai_hub` |
| 业务账号 | `ai_hub` |
| 业务密码 | 见 `deploy/.env` 的 `MYSQL_PASSWORD` |
| root 密码 | 见 `deploy/.env` 的 `MYSQL_ROOT_PASSWORD` |

连接串（`application-dev.yml` 默认值）：

```
jdbc:mysql://127.0.0.1:13306/ai_hub?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true&useSSL=false
```

命令行登录（密码从 `.env` 读取，避免出现在 shell 历史里）：

```bash
set -a; source deploy/.env; set +a
docker exec -it aihub-mysql mysql -uai_hub -p"$MYSQL_PASSWORD" ai_hub
```

### Redis 7

| 项 | 值 |
| --- | --- |
| 容器名 | `aihub-redis` |
| 宿主地址 | `127.0.0.1`**:**`16379`（容器内 6379）|
| 密码 | 见 `deploy/.env` 的 `REDIS_PASSWORD` |
| 持久化 | AOF 开启，`maxmemory 1gb`，`allkeys-lru` |

```bash
set -a; source deploy/.env; set +a
docker exec -it aihub-redis redis-cli -a "$REDIS_PASSWORD" ping
```

> **为什么端口不是 3306 / 6379？**
> 3306 预留给同机其他实例；6379 已被 **Windows 宿主**上的 `redis-server` 占用。改宿主端口避免冲突，容器内仍是标准端口。

> **为什么 Docker 只跑数据库？**
> 需求硬约束：项目代码、Agent、构建、测试必须在 WSL Native 执行。Docker 在这里只承载数据存储这一件事。

---

## 四、目录结构

```
ai-development-hub/
├── pom.xml                    # Maven 父 pom（Boot 3.5.16 / JDK 21）
├── hub-common/                # 统一响应 R、错误码、全局异常、分页
├── hub-security/              # JWT 签发校验、Spring Security 配置
├── hub-system/                # 用户/角色/权限
├── hub-agent/                 # Agent 注册、发现、健康检查（阶段二）
├── hub-task/                  # 任务管理与调度（阶段四）
├── hub-project/               # 项目注册与配置（阶段五）
├── hub-channel/               # 微信渠道抽象（阶段六）
├── hub-memory/                # 分层记忆（阶段七）
├── hub-runtime/               # WSL Native 执行引擎（阶段五）
├── hub-approval/              # 审批与危险操作控制（阶段七）
├── hub-monitor/               # 系统监控
├── hub-web/                   # 后台管理 REST API
├── hub-server/                # 启动模块（唯一可执行 jar）
├── frontend/                  # Vue 3 + TS + Vite + Element Plus
├── database/flyway/           # 数据库版本化脚本（V1，V2...）
├── deploy/                    # docker-compose、启动/停止/状态脚本
└── docs/                      # 设计文档与验收报告
```

### 设计文档

| 文档 | 内容 |
| --- | --- |
| [项目可行性分析](docs/项目可行性分析.md) | 技术可行性与风险 |
| [系统总体架构设计](docs/系统总体架构设计.md) | 分层架构与模块边界 |
| [技术选型说明](docs/技术选型说明.md) | 每项选择的理由与替代方案 |
| [数据库设计](docs/数据库设计.md) | 21 张表 + 支撑表 |
| [核心 API 接口设计](docs/核心 API 接口设计.md) | 接口清单与约定 |
| [模块开发计划](docs/模块开发计划.md) | 八阶段拆解 |
| [系统安全设计](docs/系统安全设计.md) | 16 条安全约束的落地 |
| [部署架构设计](docs/部署架构设计.md) | 部署拓扑与恢复策略 |
| [环境实施记录](docs/环境实施记录.md) | 实际落地的环境与坑 |
| [第一阶段验收报告](docs/第一阶段验收报告.md) | 阶段一实测结果 |

---

## 五、技术栈

| 层 | 选型 |
| --- | --- |
| 后端 | JDK 21 · Spring Boot 3.5.16 · Spring Security · MyBatis-Plus 3.5.18 · Flyway |
| 存储 | MySQL 8.0（Docker）· Redis 7（Docker）|
| 前端 | Vue 3 · TypeScript · Vite 6 · Element Plus · Pinia · Vue Router · Axios · ECharts |
| Agent | Claude Code 2.1.332 · Codex CLI 0.172.0 · OpenCode 1.19.6（均为 WSL 原生）|
| 通信协议 | ACP (JSON-RPC over stdio)，自研 Java 客户端（Maven 无官方 Java SDK）|
| 微信网关 | WeClaw（Go，v0.10.1）|

### 端口规划

| 端口 | 用途 |
| --- | --- |
| 18080 | Hub 后端 API |
| 15173 | 前端 Vite dev |
| 13306 | MySQL（宿主映射）|
| 16379 | Redis（宿主映射）|
| 18011 | WeClaw 本地出站 API（阶段六）|

---

## 六、API 约定

统一响应结构：

```json
{ "code": 0, "message": "ok", "data": { }, "timestamp": 1795684551055 }
```

- `code = 0` 表示成功，非 0 为业务错误码。
- 段位：`1xxxx` 通用 / `2xxxx` 认证授权 / `3xxxx` Agent / `4xxxx` 任务 / `5xxxx` 项目 / `6xxxx` 渠道。

认证：除 `/api/auth/login` 与 `/api/health` 外，所有接口需 `Authorization: Bearer <token>`。

当前已实现：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/health` | 健康检查（真实探测数据库） |
| POST | `/api/auth/login` | 登录，返回 JWT |

---

## 七、数据库迁移

使用 **Flyway**，启动时自动执行 `classpath:database/flyway` 下的脚本。

- 脚本命名：`V{n}__{描述}.sql`
- 所有 `CREATE TABLE` 用 `IF NOT EXISTS`，保证可重复初始化
- 新增变更：在 `database/flyway/` 新建 `V2__xxx.sql`，并同步复制到 `hub-server/src/main/resources/database/flyway/`

> 两处副本的关系：`database/flyway/` 是可读的源文件目录，`hub-server/src/main/resources/database/flyway/` 是打进 jar 的运行时副本。修改时请同时更新（或改用 `maven-resources-plugin` 自动拷贝，待优化）。

---

## 八、安全基线

1. 微信用户白名单，非白名单用户不能驱动任何任务。
2. 所有任务关联真实用户身份，执行前做权限检查。
3. 危险命令、生产部署必须人工审批。
4. Agent 执行目录隔离，每个任务独立 Git Worktree。
5. 不默认开启 `bypassPermissions`。
6. Token / API Key / 密码不写入日志，不写入普通记忆文件。
7. 默认禁止自动 Push、自动合并主分支、自动部署生产。
8. 所有关键操作记录审计日志。

---

## 九、开发路线

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 一 | 基础工程（多模块、登录、DB、前端骨架）| ✅ 已完成 |
| 二 | Agent 注册中心（自动发现、状态区分、能力配置）| ⬜ 待开始 |
| 三 | ACP 通信与单 Agent 执行 | ⬜ |
| 四 | 任务调度中心 | ⬜ |
| 五 | 项目管理与 Native Runner | ⬜ |
| 六 | WeClaw 微信接入 | ⬜ |
| 七 | Web 后台完善（15 个页面）| ⬜ |
| 八 | 稳定性与扩展 | ⬜ |

---

## 十、常见问题

**Q：`docker ps` 报 `failed to connect to the docker API at npipe://...`**
Windows 侧 Docker Desktop 没启动。启动后等 15–30 秒再试。

**Q：`docker compose` 报 `docker-credential-desktop.exe: exec format error`**
Windows 的 credential helper 在 Linux 下不可用。项目已用 `DOCKER_CONFIG=/home/wangchong/ai-hub/config/docker`（空配置）规避；脚本里已自动设置。

**Q：6379 端口起不来，报 `ports are not available`**
Windows 宿主已有 `redis-server` 占用。本项目用 16379，无需处理。

**Q：`claude --version` 报 `Exec format error`**
PATH 里 `/mnt/d/ProgramFiles/nvm/nodejs` 的 Windows shim 优先级更高。用绝对路径 `/home/wangchong/.npm-global/bin/claude`，或先 `export PATH="$HOME/.npm-global/bin:$PATH"`。

**Q：登录提示"用户名或密码错误"**
确认数据库已初始化（启动日志应有 `Successfully applied 1 migration`）。若手工清过库，重启后端让 Flyway 重新执行 `V1__sys_auth.sql`。

**Q：改了 `.env` 里的密码后连不上**
容器已用旧密码初始化，数据卷里存的是旧密码。要么把 `.env` 改回旧值，要么 `docker compose down -v` 删卷重建（**会丢数据**）。

---

## 十一、约定

- 提交信息用中文，格式 `类型: 描述`（`feat` / `fix` / `docs` / `chore` / `refactor`）。
- 不使用 Mock 数据冒充已完成的后端功能；页面未接通的指标一律显示占位，不填假数字。
- 不把 WSL 路径替换成 Windows 路径。
- 数据库变更必须提供 SQL 脚本；新增接口必须更新文档。
