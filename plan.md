# Personal Affairs App v1 施工计划

> 本计划基于：
>
> - `AUDIT_v1.md`（当前最高生产指导文件，负责裁决旧文档冲突）
> - `personal_affairs_backend_blueprint_v1.md`
> - `100j_swiftui_frontend_redesign_blueprint_v1.md`
>
> v1 总顺序固定为：**后端 -> 前端 macOS -> 前端 iOS -> 本地测试 -> 后端整体上云**。
>
> 已停用的旧前端蓝图、临时 review memo、HTML 原型不再作为施工输入。

---

## 0. v1 总目标

交付一个可本地完整跑通、后端可部署到云端、macOS 与 iOS 共用同一套后端 API 的 Personal Affairs App v1。

核心产品边界：

```text
Personal
├── Tasks
├── CalendarItems
└── Notes

Company
├── Tasks
├── Projects
└── CalendarItems

Global
├── Calendar
├── Agent
└── Settings
```

必须守住的领域规则：

- Personal 不做 Project。
- Company 做 Project，但 Company Tasks 是总入口。
- Calendar 是全局一级入口，同时展示 Personal 与 Company CalendarItems。
- Agent 是全局一级入口，不隶属于 Personal 或 Company。
- Task 与 CalendarItem 严格分离。
- Note 只属于 Personal。
- Agent 写操作必须经过后端 API，并记录 action log。

---

## 1. 阶段总览

| Phase | 阶段 | 目标 | 退出标准 |
| --- | --- | --- | --- |
| Phase 1 | 后端 v1 | 完成本地可运行 API、领域模型、业务规则、Agent 基础 | OpenAPI 可访问，后端测试通过，核心接口可被前端调用 |
| Phase 2 | 前端 macOS v1 | 完成 macOS 主工作台 | macOS 能完成核心 CRUD、Global Calendar、Agent 基础路径 |
| Phase 3 | 前端 iOS v1 | 复用共享层完成 iOS 主要路径 | iOS 能浏览、创建、完成、归档核心资源 |
| Phase 4 | 本地测试 | 端到端验证后端、macOS、iOS | 本地 E2E 核心路径通过，缺陷清单收敛 |
| Phase 5 | 后端整体上云 | 部署后端、数据库、迁移、环境变量与健康检查 | 云端 API 可用，客户端可切换到云端环境 |

---

## 2. Phase 1: 后端 v1

### 2.1 阶段目标

先把后端建成稳定事实源，让 macOS 与 iOS 后续只接同一套 API，不在客户端复制业务规则。

### 2.2 施工输入

- `personal_affairs_backend_blueprint_v1.md`
- 当前 Git 仓库。
- 本地 PostgreSQL 或 Docker PostgreSQL。

### 2.3 目录目标

```text
backend/
├── app/
│   ├── main.py
│   ├── core/
│   ├── models/
│   ├── schemas/
│   ├── services/
│   ├── api/
│   │   └── v1/
│   └── tests/
├── alembic/
├── pyproject.toml
└── README.md
```

### 2.4 施工任务

1. 初始化后端工程
   - FastAPI。
   - SQLAlchemy / SQLModel。
   - Pydantic。
   - Alembic。
   - PostgreSQL 连接。
   - 本地 `.env.example`。
   - `/health` 或 `/api/v1/health`。

2. Auth 与 User
   - `POST /api/v1/auth/register`
   - `POST /api/v1/auth/login`
   - `POST /api/v1/auth/refresh`
   - `POST /api/v1/auth/logout`
   - `GET /api/v1/me`
   - JWT access token + refresh token。
   - 注册后自动创建 Personal 与 Company spaces。

3. Space
   - `GET /api/v1/spaces`
   - `GET /api/v1/spaces/{space_id}`
   - 每个用户默认仅一个 personal space 与一个 company space。

4. Task
   - CRUD。
   - Complete / Reopen / Archive。
   - 查询支持 `space_id`、`project_id`、`project_scope`、`status`、`priority`、`due_before`、`due_after`、`search`、`limit`、`cursor`。
   - Personal Task 禁止 `project_id`。
   - Company Task 允许 `project_id = null`。

5. Project
   - CRUD。
   - Complete / Archive。
   - `GET /api/v1/projects/{project_id}/tasks`
   - `POST /api/v1/projects/{project_id}/tasks`
   - Project 只能属于 Company Space。

6. CalendarItem
   - CRUD。
   - 全天事项与具体时间事项双轨字段校验。
   - 支持 `appointment`、`anniversary`、`subscription_expiry`、`deadline`、`reminder`。
   - 支持 `none`、`monthly`、`yearly` 简单 recurrence。
   - Personal CalendarItem 禁止 `project_id`。
   - Company CalendarItem 可选 `project_id`。

7. Note
   - CRUD。
   - Archive。
   - `POST /api/v1/notes/{note_id}/convert-to-task`
   - Note 只能属于 Personal Space。

8. Agent 基础
   - LLM Provider Key 加密保存。
   - `GET /api/v1/agent/tools`
   - `POST /api/v1/agent/commands`
   - `POST /api/v1/agent/commands/confirm`
   - `GET /api/v1/agent/action-logs`
   - Agent 写操作必须写入 `agent_action_logs`。
   - 删除、批量修改、归档整个 Project、修改 CalendarItem 时间等危险操作必须 requires confirmation。

9. OpenAPI 与前端契约
   - OpenAPI docs 可访问。
   - API 字段保持 snake_case。
   - 错误响应统一为：

```json
{
  "error": {
    "code": "validation_error",
    "message": "Personal tasks cannot have project_id.",
    "details": {}
  }
}
```

### 2.5 后端验收

必须通过：

- 单元测试。
- API 测试。
- 业务规则测试。
- Agent action log 测试。
- OpenAPI schema 检查。

核心验收路径：

- 新用户注册后自动拥有 Personal 与 Company。
- Personal Task 不能绑定 Project。
- Company Task 可以有 Project，也可以无 Project。
- Project 只能创建在 Company。
- Note 只能创建在 Personal。
- Note 能转换成 Personal Task。
- Calendar 全天事项只接受 `start_date`。
- Calendar 具体时间事项只接受 `start_at`。
- Agent 创建 Task / CalendarItem / Project / Note 后生成 action log。

### 2.6 Phase 1 退出标准

- 后端本地启动命令写入 README。
- 数据库迁移可从空库完整执行。
- `/docs` 或 OpenAPI JSON 可访问。
- 前端所需接口全部可用。
- 测试通过。

---

## 3. Phase 2: 前端 macOS v1

### 3.1 阶段目标

完成 macOS 主工作台。macOS 是 v1 的首要客户端，承担完整整理、编辑、查看与 Agent 操作。

### 3.2 施工输入

- 后端本地 API。
- OpenAPI schema。
- `AUDIT_v1.md`。
- `100j_swiftui_frontend_redesign_blueprint_v1.md`。

### 3.3 技术方向

```text
UI: SwiftUI
Navigation: MacWorkbenchShellView / SwiftUI workbench shell
Networking: URLSession + async/await
Auth Storage: Keychain
Icons: SF Symbols
State: Observation / ObservableObject
```

### 3.4 macOS 信息架构

```text
Sidebar
├── Today
│   └── Today Command Center
├── Personal
│   ├── Tasks
│   └── Notes
├── Company
│   ├── Tasks
│   └── Projects
├── Calendar
├── Agent
└── Settings
```

Today 是 macOS 默认首页，只能聚合既有 Task、CalendarItem、Note、Project 数据；不得引入新领域对象、新表或新后端 API。

### 3.5 施工任务

1. Apple 工程基础
   - 创建 SwiftUI App。
   - 建立 `Shared/API`、`Shared/Domain`、`Shared/Repositories`。
   - 建立 `Features/Auth`、`Features/Personal`、`Features/Company`、`Features/Calendar`、`Features/Agent`、`Features/Settings`。
   - 配置本地 API base URL。

2. API Client 与 Auth
   - 登录。
   - 注册。
   - Token refresh。
   - Logout。
   - Keychain 存储 token。
   - 拉取 `GET /api/v1/spaces` 并缓存 `personal_space_id` 与 `company_space_id`。

3. Personal Tasks
   - Active / Done / Archived。
   - 创建、编辑、完成、reopen、归档、删除。
   - Due date、priority、search。
   - 表单不显示 Project。

4. Personal Notes
   - Ideas / Memos / Archived。
   - 创建、编辑、归档、删除。
   - Convert to Task。
   - Note 详情显示 linked task。

5. Company Tasks
   - All Tasks。
   - No Project。
   - Grouped by Project。
   - Project Filter。
   - 创建、编辑、完成、reopen、归档、删除。
   - Project Picker 只显示 Company Projects。

6. Company Projects
   - Project 列表。
   - Project Detail。
   - Project 内任务。
   - 创建、编辑、完成、归档。
   - Project Detail 展示相关 CalendarItems 摘要。

7. Global Calendar
   - Calendar 独立一级入口。
   - All / Personal / Company / Project filter。
   - All 视图并发查询 Personal 与 Company CalendarItems 后本地合并。
   - 月视图 + 当日 Agenda + Inspector。
   - 创建、编辑、删除 CalendarItem。
   - 新建 CalendarItem 时必须确定 Personal 或 Company。

8. Agent
   - Agent 独立一级入口。
   - LLM Key 设置。
   - Tools 拉取。
   - Command 输入。
   - Dry run 预览。
   - Requires confirmation 确认 UI。
   - Action logs。
   - Agent 写操作后刷新对应 Repository。

9. macOS 体验
   - Toolbar 上下文新建。
   - 右侧 Inspector。
   - 键盘快捷键：`Cmd+N`、`Cmd+F`、`Cmd+R`。
   - Loading / Empty / Error / Disabled 状态。
   - Light / Dark Mode。
   - Dynamic Type 与 VoiceOver 基础支持。

### 3.6 macOS 验收

- macOS 能完成 Personal Tasks / Notes 核心 CRUD。
- macOS 能完成 Company Tasks / Projects 核心 CRUD。
- Global Calendar 能同时展示 Personal 与 Company CalendarItems。
- CalendarItem 全天与具体时间表单不会提交错误字段。
- Agent 可完成 command、dry run、confirmation、action logs。
- LLM Key 不展示完整 key。
- 后端 validation error 能映射到字段或全局错误。

### 3.7 Phase 2 退出标准

- macOS App 可连接本地后端完成核心路径。
- macOS UI 无明显文字溢出、控件重叠、不可点击状态。
- 关键 ViewModel / Repository 测试通过。

---

## 4. Phase 3: 前端 iOS v1

### 4.1 阶段目标

复用 macOS 阶段完成的 Domain、API Client、Repository，补齐 iOS 浏览、捕捉、完成与归档路径。

### 4.2 施工原则

- 不复制 API 逻辑。
- 不复制业务校验。
- iOS 只重做导航外壳、列表密度、表单呈现与触摸交互。

### 4.3 iOS 信息架构

```text
TabView
├── Personal
├── Company
├── Calendar
├── Agent
└── Settings
```

Personal：

```text
Segmented Control
├── Tasks
└── Notes
```

Company：

```text
Segmented Control
├── Tasks
└── Projects
```

### 4.4 施工任务

1. iOS Shell
   - TabView。
   - NavigationStack。
   - Shared Repository 注入。
   - 本地 / 云端 API 环境切换预留。

2. Personal
   - Tasks 列表、详情、创建、编辑、完成、归档。
   - Notes 列表、详情、创建、编辑、归档、convert to task。
   - Swipe Actions。

3. Company
   - Tasks All / No Project / Project Filter。
   - Projects 列表与详情。
   - 项目内任务创建。
   - Swipe Actions。

4. Global Calendar
   - Agenda 优先。
   - 月视图可折叠或作为辅助视图。
   - All / Personal / Company / Project filter。
   - 创建 / 编辑 CalendarItem 使用 Sheet。
   - 新建时必须选择空间。

5. Agent
   - Command 输入。
   - Confirmation Sheet。
   - Action logs。
   - LLM Key 设置。
   - 支持系统键盘与语音输入。

6. iOS 体验
   - 小屏文本不溢出。
   - 表单字段分组清楚。
   - Loading / Empty / Error 状态。
   - Dynamic Type。
   - VoiceOver。
   - Light / Dark Mode。

### 4.5 iOS 验收

- iOS 可登录、注册、刷新 token。
- iOS 可完成 Personal Task / Note 主要路径。
- iOS 可完成 Company Task / Project 主要路径。
- iOS Calendar 可同时展示 Personal 与 Company 事项。
- iOS Agent 可提交命令并处理 confirmation。
- iOS 小屏无明显文本溢出或按钮不可点。

### 4.6 Phase 3 退出标准

- iOS App 可连接本地后端完成主要路径。
- iOS 与 macOS 共用 Domain / API / Repository。
- 主要 UI Tests 通过。

---

## 5. Phase 4: 本地测试

### 5.1 阶段目标

在上云前，把后端、macOS、iOS 在本地完整串起来，验证 v1 业务边界、端到端路径和错误处理。

### 5.2 本地环境

建议本地至少具备：

```text
PostgreSQL
Backend API
macOS App
iOS Simulator
Test user
Seed data
```

可选：

```text
Docker Compose for PostgreSQL + Backend
Mock LLM Provider for Agent tests
```

### 5.3 测试任务

1. 后端测试
   - Unit tests。
   - API tests。
   - Migration from empty database。
   - OpenAPI schema check。
   - Agent action logs。

2. macOS 本地 E2E
   - Auth。
   - Personal Tasks。
   - Personal Notes。
   - Company Tasks。
   - Company Projects。
   - Global Calendar。
   - Agent。
   - Settings。

3. iOS 本地 E2E
   - Auth。
   - Personal。
   - Company。
   - Calendar。
   - Agent confirmation。
   - 小屏适配。

4. 跨端一致性
   - macOS 创建的数据 iOS 可见。
   - iOS 创建的数据 macOS 可见。
   - Agent 创建的数据两个端都可见。
   - Calendar All 视图在两个端都能合并 Personal 与 Company。

5. 错误与边界
   - Personal Task 绑定 Project 被拒绝。
   - Personal 创建 Project 被拒绝。
   - Company Note 被拒绝。
   - Calendar 全天事项错误字段被拒绝。
   - Calendar 具体时间事项错误字段被拒绝。
   - Token 过期可 refresh。
   - Refresh 失败回登录。

### 5.4 缺陷处理规则

- P0：阻断登录、数据写入、核心列表读取，必须修。
- P1：核心业务规则错误，必须修。
- P2：明显 UI 错误、表单错误提示缺失，上云前修。
- P3：体验优化，记录到 v1.x。

### 5.5 Phase 4 退出标准

- 后端测试通过。
- macOS 本地核心路径通过。
- iOS 本地核心路径通过。
- P0 / P1 / P2 缺陷清零。
- 云端部署所需环境变量、迁移命令、健康检查已整理。

---

## 6. Phase 5: 后端整体上云

### 6.1 阶段目标

把后端从本地可用推进到云端可用，让 macOS 与 iOS 可以切换到云端 API。

### 6.2 部署范围

必须部署：

- FastAPI 后端服务。
- PostgreSQL。
- Alembic migrations。
- 环境变量与 secrets。
- 健康检查。
- 日志。
- HTTPS 入口。

暂不部署：

- 外部 Agent 平台。
- 第三方开发者 API。
- 复杂监控平台。
- 多区域部署。

### 6.3 云端施工任务

1. 选择部署平台
   - v1 可选 Render、Fly.io、Railway、AWS、GCP、Azure 中一种。
   - 选择标准：PostgreSQL 支持、环境变量管理、日志可查、HTTPS 简单、成本可控。

2. 配置生产环境
   - `DATABASE_URL`
   - JWT secret。
   - Token TTL。
   - CORS allowed origins。
   - LLM key encryption secret。
   - App environment：`production`。

3. 数据库
   - 创建生产 PostgreSQL。
   - 执行 Alembic migration。
   - 验证 users / spaces / tasks / projects / calendar_items / notes / agent_action_logs 等表存在。

4. 后端服务
   - 构建镜像或平台构建。
   - 启动 FastAPI。
   - 配置健康检查。
   - 配置日志过滤，确保不输出 API Key。

5. API 验证
   - 访问 health endpoint。
   - 注册新用户。
   - 验证默认 spaces 创建。
   - 创建 Personal Task。
   - 创建 Company Project。
   - 创建 Company Task。
   - 创建 CalendarItem。
   - 创建 Note 并 convert to task。
   - Agent command 创建 Task，并确认 action log。

6. 客户端环境切换
   - macOS 增加云端 API base URL。
   - iOS 增加云端 API base URL。
   - Debug 默认本地。
   - Release / TestFlight 可配置云端。

### 6.4 上云验收

- 云端 `/health` 正常。
- 云端 OpenAPI 可访问，或至少 schema 可导出。
- 生产数据库迁移成功。
- 新用户注册后自动创建 Personal 与 Company spaces。
- macOS 可连接云端 API。
- iOS 可连接云端 API。
- Agent 写操作在云端生成 action log。
- 日志不泄露 token、LLM key、完整 API key。

### 6.5 Phase 5 退出标准

- 后端云端 API 可持续访问。
- 客户端可切换本地 / 云端环境。
- 云端 smoke test 全部通过。
- 部署步骤写入 README 或 `deployment.md`。

---

## 7. v1 不做

v1 明确不做：

```text
个人 Project
公司 Notes / Ideas
独立 Subscription 模块
复杂 Task 状态
复杂 RRULE
团队协作
多公司 Space
外部 Agent API
复杂 RBAC
完整离线冲突合并
附件系统
统计报表
自定义主题系统
```

---

## 8. 推荐 Git 节奏

建议按阶段提交，保持每个 commit 可解释：

```text
Phase 1 backend scaffold
Phase 1 backend auth and spaces
Phase 1 backend tasks projects calendar notes
Phase 1 backend agent foundation
Phase 2 macOS app shell
Phase 2 macOS core features
Phase 3 iOS shell
Phase 3 iOS core features
Phase 4 local test fixes
Phase 5 backend deployment
```

每个阶段结束前必须确认：

- `git status` 干净，或未提交变更有明确原因。
- README / 运行说明同步更新。
- 测试结果写进提交信息、PR 描述或阶段记录。

---

## 9. 第一条施工命令

恢复施工时，优先从这里开始：

```bash
sed -n '1,220p' plan.md
git status --short
```

然后进入 Phase 1 后端工程初始化。
