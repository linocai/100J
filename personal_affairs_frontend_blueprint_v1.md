# Personal Affairs App 前端规划蓝图 v1

> 面向 Codex / 前端施工队的第一版实现说明。  
> 本文与 `personal_affairs_backend_blueprint_v1.md` 对齐。  
> 当前阶段目标：先做 macOS App，后做 iOS App，前端共享同一套领域模型、API Client、业务校验与设计语言。

---

## 0. 前后端统一原则

前端不能重新发明产品规则，必须以后端规划为事实源：

1. **空间模型统一**
   - 前端只展示两个默认 Space：`Personal` 与 `Company`。
   - 后端字段为 `spaces.type = personal | company`。
   - UI 可以显示中文，但 API、缓存模型、枚举值保持英文。

2. **Personal 不做 Project**
   - Personal 下只允许：Tasks、CalendarItems、Notes。
   - Personal Task 创建 / 编辑表单不出现 Project 选择器。
   - Personal CalendarItem 创建 / 编辑表单不出现 Project 选择器。
   - Personal Note 不允许关联 Project。

3. **Company 使用 Project，但 Company Tasks 是总入口**
   - Company Tasks 必须能看到全部公司任务。
   - Company Tasks 必须支持：全部、无项目、按项目分组、某个项目。
   - Project Detail 只是同一批任务的项目视角。

4. **Task 与 CalendarItem 严格分离**
   - Task：用户可自行安排时间做的灵活待办。
   - CalendarItem：固定日期或固定时间发生的事项。
   - 有 `due_date` 的事项仍然是 Task，不自动进入 CalendarItem。

5. **Note 只属于 Personal**
   - Notes 是个人灵感库 / 备忘录。
   - Company v1 不做 Notes。
   - Note 可以转换成 Personal Task，原 Note 保留。

6. **Agent 是 App 内能力**
   - Agent 不直接写本地数据库，也不绕过后端。
   - Agent 写操作必须走 `/api/v1/agent/commands`。
   - 需要确认的操作必须出现明确确认 UI。

7. **一级导航不是只有 Personal / Company**
   - `Personal` 与 `Company` 是业务空间，不是全部导航。
   - `Calendar` 是跨空间的全局一级入口，同时展示 Personal 与 Company 的 CalendarItems。
   - `Agent` 是跨空间的全局一级入口，可以在当前上下文下执行，也可以处理跨空间查询。
   - `Settings` 是全局一级入口。

---

## 1. 推荐前端技术栈

v1 建议使用原生 Apple 技术栈，保证 macOS 与 iOS 共用核心能力：

```text
UI: SwiftUI
State: Observation / ObservableObject，按项目实际最低系统版本决定
Networking: URLSession + async/await
API Contract: OpenAPI 生成 Swift Client，或手写薄封装但以 OpenAPI 为准
Persistence v1: online-first + lightweight local cache
Persistence future: 为 sync cursor / version / deleted_at 预留本地存储层
Auth Storage: Keychain
Date Handling: Foundation Date / Calendar / TimeZone
Icons: SF Symbols
Testing: XCTest + Swift Testing + UI Tests
```

前端不应直接依赖数据库结构，但必须完整理解后端领域模型与 API 语义。

---

## 2. Apple 端项目结构建议

```text
frontend/
└── apple/
    ├── PersonalAffairs.xcodeproj
    ├── PersonalAffairsApp/
    │   ├── App/
    │   ├── DesignSystem/
    │   ├── Features/
    │   │   ├── Auth/
    │   │   ├── Spaces/
    │   │   ├── Personal/
    │   │   ├── Company/
    │   │   ├── Calendar/
    │   │   ├── Agent/
    │   │   └── Settings/
    │   ├── Shared/
    │   │   ├── API/
    │   │   ├── Domain/
    │   │   ├── Repositories/
    │   │   ├── Cache/
    │   │   └── Utilities/
    │   └── Resources/
    └── PersonalAffairsTests/
```

模块边界：

- `Domain`：与后端枚举和值对象对齐，如 `TaskStatus`、`Priority`、`CalendarItemType`、`SpaceType`。
- `API`：负责 `/api/v1` 请求、分页、错误格式、Token 刷新。
- `Repositories`：屏蔽网络细节，为 ViewModel 提供任务、日历、项目、笔记、Agent 数据。
- `Features`：只放 UI 与交互逻辑，不直接拼 API URL。
- `DesignSystem`：颜色、字体、间距、控件样式、空状态、错误状态。

---

## 3. 信息架构

### 3.1 macOS 一级结构

macOS 使用 `NavigationSplitView`，建议三栏：

```text
Sidebar
├── Personal
│   ├── Tasks
│   └── Notes
├── Company
│   ├── Tasks
│   └── Projects
├── Calendar
├── Agent
└── Settings

Content List / Board / Calendar

Detail / Inspector
```

macOS 设计目标：

- 适合长时间整理事务。
- 支持列表 + 详情的高效率工作流。
- 支持键盘快捷操作。
- 支持右侧 Inspector 编辑详情，避免频繁弹窗。
- 重要创建动作放在 Toolbar：新建 Task、新建 CalendarItem、新建 Note、新建 Project。
- Calendar 是全局视图，Toolbar 中的新建 CalendarItem 必须要求选择 Personal 或 Company。

### 3.2 iOS 一级结构

iOS 使用 `TabView` + 分层导航：

```text
Tabs
├── Personal
├── Company
├── Calendar
├── Agent
└── Settings
```

Personal 内部：

```text
Segmented Control
├── Tasks
└── Notes
```

Company 内部：

```text
Segmented Control
├── Tasks
└── Projects
```

iOS 设计目标：

- 快速捕捉、快速查看、快速完成。
- 表单使用 Sheet / Full-screen Cover。
- 详情页使用 Navigation Stack。
- 日历优先展示 Agenda 列表，月视图作为辅助。
- 大批量整理操作弱化，必要时跳转到 macOS 更高效完成。
- iOS Tab 数量控制为五个：Personal、Company、Calendar、Agent、Settings。

---

## 4. 核心页面规划

### 4.1 Auth

页面：

- 登录。
- 注册。
- Token 过期后的重新登录。

后端接口：

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/me
GET  /api/v1/spaces
```

前端规则：

- 注册成功后立即拉取 `GET /api/v1/spaces`。
- 本地缓存 `personal_space_id` 与 `company_space_id`。
- Access token 与 refresh token 只能存 Keychain。

### 4.2 Personal Tasks

用途：管理个人灵活待办。

查询：

```http
GET /api/v1/tasks?space_id={personal_space_id}&status=active
```

列表视图：

- Active。
- Done。
- Archived。
- Due date 筛选。
- Priority 筛选。
- Search。

创建 / 编辑字段：

```text
title
description
priority
due_date
remind_at
estimated_minutes
status
```

前端禁止：

- 不显示 `project_id`。
- 不允许从 Personal Task 选择 Company Project。

### 4.3 Global Calendar

用途：统一查看 Personal 与 Company 的固定日期 / 固定时间事项。

v1 不要求后端新增聚合接口。前端可以按时间范围并发查询两个 Space，然后在本地按时间合并：

```http
GET /api/v1/calendar-items?space_id={personal_space_id}&from_date={yyyy-mm-dd}&to_date={yyyy-mm-dd}
GET /api/v1/calendar-items?space_id={company_space_id}&from_date={yyyy-mm-dd}&to_date={yyyy-mm-dd}
GET /api/v1/calendar-items?space_id={company_space_id}&project_id={project_id}&from_date={yyyy-mm-dd}&to_date={yyyy-mm-dd}
```

视图：

- macOS：月视图 + 当日 Agenda + 详情 Inspector。
- iOS：Agenda 优先，月视图可折叠。
- 支持范围过滤：All、Personal、Company、Company Project。
- All 视图同时展示 Personal 与 Company CalendarItems。
- 每个事项必须显示空间来源，避免用户混淆个人与公司事项。

创建 / 编辑字段：

```text
space_type personal | company
title
description
type
project_id optional, company only
all_day
start_date / end_date
start_at / end_at
timezone
recurrence
remind_at
related_task_id
```

表单规则：

- 从 Global Calendar 新建事项时，必须先确定 `space_id`。
- 选择 Personal 时，`project_id` 永远为 `null`。
- 选择 Company 时，`project_id` 可选，Project Picker 只显示 Company Projects。
- `all_day = true` 时只显示 date 字段。
- `all_day = false` 时只显示 datetime 字段。
- `subscription_expiry` 默认 `all_day = true`。
- `anniversary` 默认 `all_day = true`，`recurrence = yearly`。
- 用户未主动选择空间时，个人订阅到期日与纪念日默认落到 Personal。
- `deadline` 可以是 CalendarItem，但不要替代 Task 的 `due_date`。

### 4.4 Personal Notes

用途：个人灵感 / 备忘。

查询：

```http
GET /api/v1/notes?status=active
```

列表视图：

- Ideas。
- Memos。
- Archived。
- Search。

创建 / 编辑字段：

```text
title
body
type
status
```

关键动作：

```http
POST /api/v1/notes/{note_id}/convert-to-task
```

交互要求：

- Convert to Task 打开一个轻量任务确认表单。
- 转换成功后保留原 Note。
- Note 详情显示已关联 Task 的入口。

### 4.5 Company Tasks

用途：公司全部待办的统一入口。

查询：

```http
GET /api/v1/tasks?space_id={company_space_id}&status=active
GET /api/v1/tasks?space_id={company_space_id}&project_scope=no_project&status=active
GET /api/v1/tasks?space_id={company_space_id}&project_scope=with_project&status=active
GET /api/v1/tasks?project_id={project_id}&status=active
```

视图模式：

- All Tasks。
- No Project。
- Grouped by Project。
- Project Filter。

创建 / 编辑字段：

```text
title
description
priority
due_date
remind_at
estimated_minutes
project_id optional
status
```

前端规则：

- `project_id = null` 是合法公司杂项任务。
- 如果选择 Project，必须只展示 Company Projects。
- Grouped by Project v1 可由前端对扁平列表分组。

### 4.6 Company Projects

用途：公司项目管理。

查询：

```http
GET /api/v1/projects?space_id={company_space_id}&status=active
GET /api/v1/projects/{project_id}
GET /api/v1/projects/{project_id}/tasks
```

列表字段：

```text
name
status
target_date
active_task_count
completed_task_count
```

创建 / 编辑字段：

```text
name
description
start_date
target_date
status
```

Project Detail：

- 项目基本信息。
- 项目内 Active Tasks。
- 项目内 Done Tasks。
- 项目相关 CalendarItems。
- 快速创建项目任务。

前端禁止：

- 不允许在 Personal Space 创建 Project。
- 不允许把 Personal Task 移入 Company Project。

### 4.7 Calendar Context Entrypoints

用途：在 Personal、Company、Project Detail 内提供上下文入口，但不重复做独立日历页。

上下文入口：

```text
Personal Tasks / Notes -> 打开 Global Calendar 且过滤 Personal
Company Tasks / Projects -> 打开 Global Calendar 且过滤 Company
Project Detail -> 打开 Global Calendar 且过滤当前 Project
```

前端规则：

- Calendar 的唯一完整页面是 Global Calendar。
- Personal 与 Company 内部不再放完整 Calendar 子页面，避免同一事项在多个入口下形成重复心智。
- Project Detail 可以展示项目相关 CalendarItems 摘要，但完整编辑跳转或弹出 Global Calendar 的项目过滤视图。
- 修改 CalendarItem 时间属于高风险 Agent 操作，但用户手动编辑可以直接保存。

### 4.8 Agent

用途：App 内自然语言操作与整理。

接口：

```http
GET  /api/v1/agent/tools
POST /api/v1/agent/commands
POST /api/v1/agent/commands/confirm
GET  /api/v1/agent/action-logs
GET  /api/v1/agent/llm-key
PUT  /api/v1/agent/llm-key
DELETE /api/v1/agent/llm-key
```

视图：

- Agent Command 输入区。
- Dry run 预览。
- Requires confirmation 确认卡片。
- 最近 Agent 操作日志。
- LLM Provider Key 设置入口。

确认 UI 必须覆盖：

- 删除任何资源。
- 归档整个 Project。
- 批量修改超过 5 个 Task。
- 批量归档超过 5 个 Task。
- 修改 CalendarItem 的时间。
- 跨 Space 移动 Task。

安全规则：

- 不显示完整 LLM API Key。
- 只显示后端返回的 `key_preview`。
- Agent 结果中出现批量修改时，必须列出影响数量与目标类型。

---

## 5. 设计系统

### 5.1 视觉原则

这是事务管理工具，不是营销页面。视觉应该安静、密集、清楚：

- 使用系统字体。
- 使用系统动态颜色，支持 Light / Dark Mode。
- 使用 SF Symbols 表示任务、日历、项目、笔记、Agent、设置。
- macOS 以侧边栏、列表、表格、Inspector 为主。
- iOS 以分组列表、Sheet 表单、底部 Tab、紧凑 Agenda 为主。
- 卡片只用于独立重复项或确认块，不把页面区块堆成卡片。
- 避免单一色系铺满应用。

### 5.2 语义颜色

```text
Personal accent: green / teal family
Company accent: blue family
Danger: red
Warning: orange
Success: green
Agent: indigo as accent only
```

颜色只用于状态和导航辅助，不应抢占内容层级。

### 5.3 状态表达

Task status：

```text
active   正常文本 + 可完成按钮
done     弱化文本 + completed_at
archived 从默认列表隐藏
```

Priority：

```text
low      muted
medium   normal
high     emphasized
urgent   danger accent
```

CalendarItem type：

```text
appointment          calendar icon
anniversary          gift icon
subscription_expiry  creditcard / bell icon
deadline             flag icon
reminder             bell icon
```

Source：

```text
manual 默认不展示
agent  小型 Agent 标记，可在详情中展示
```

### 5.4 可访问性

必须支持：

- Dynamic Type。
- VoiceOver label。
- 键盘导航。
- macOS Command shortcuts。
- 高对比度模式。
- 文本截断与多行策略。
- 表单错误的可读提示。

---

## 6. API 与状态层设计

### 6.1 API Client

统一基础路径：

```text
/api/v1
```

所有请求统一处理：

- JWT access token 注入。
- Refresh token 自动刷新。
- `401` 后重新登录。
- 后端错误格式解析。
- Cursor pagination。
- ISO8601 datetime。
- `YYYY-MM-DD` date-only 字段。

错误格式：

```json
{
  "error": {
    "code": "validation_error",
    "message": "Personal tasks cannot have project_id.",
    "details": {}
  }
}
```

前端展示：

- `message` 作为主提示。
- `details` 映射到具体表单字段。
- 未知错误给出可恢复操作：重试、复制诊断信息、重新登录。

### 6.2 Repository

建议提供：

```text
AuthRepository
SpaceRepository
TaskRepository
ProjectRepository
CalendarRepository
NoteRepository
AgentRepository
SettingsRepository
```

ViewModel 只能依赖 Repository，不直接依赖 URLSession。

### 6.3 Pagination

列表接口返回：

```json
{
  "items": [],
  "next_cursor": null
}
```

前端行为：

- 首屏默认拉取 `limit=50`。
- 滚动到底自动加载下一页。
- 筛选条件变化后清空 cursor 并重新拉取。
- macOS 支持手动刷新。
- iOS 支持 pull to refresh。

### 6.4 Cache 与同步准备

v1 可以 online-first，但数据层必须为未来同步预留：

- 所有本地模型保留 `id`、`updated_at`、`deleted_at`、`version`。
- 不在 UI 层硬编码删除逻辑，统一走 Repository。
- 软删除后默认从列表隐藏。
- 未来接入 `/api/v1/sync?since=cursor` 与 `/api/v1/sync/push` 时，不改 Feature 层。

---

## 7. 表单与业务校验

前端校验用于减少错误，不替代后端校验。

### 7.1 Task Form

通用校验：

- `title` 必填。
- `priority` 只能是 `low | medium | high | urgent`。
- `status` 只能是 `active | done | archived`。
- `due_date` 是 date-only。
- `remind_at` 是 datetime。

Personal：

- 固定使用 `personal_space_id`。
- `project_id` 永远为 `null`。

Company：

- 固定使用 `company_space_id`。
- `project_id` 可为 `null`。
- Project Picker 只列出 Company Projects。

### 7.2 CalendarItem Form

通用校验：

- 从 Global Calendar 创建时，如果当前没有明确上下文，必须先选择 Personal 或 Company。
- `title` 必填。
- `type` 只能是 `appointment | anniversary | subscription_expiry | deadline | reminder`。
- `recurrence` 只能是 `none | monthly | yearly`。

全天事项：

- `all_day = true`。
- 必须有 `start_date`。
- 不发送 `start_at` 与 `end_at`。

具体时间事项：

- `all_day = false`。
- 必须有 `start_at`。
- 不发送 `start_date`。

Personal：

- 使用 `personal_space_id`。
- `project_id` 永远为 `null`。

Company：

- 使用 `company_space_id`。
- `project_id` 可选。
- 如果有关联项目，只能选 Company Project。

### 7.3 Note Form

校验：

- `body` 必填。
- `type` 只能是 `idea | memo`。
- `status` 只能是 `active | archived`。
- 固定使用 `personal_space_id`。

转换成 Task：

- 打开 Task 轻表单。
- 提交 `POST /api/v1/notes/{note_id}/convert-to-task`。
- 成功后刷新 Note 与 Personal Tasks。

### 7.4 Project Form

校验：

- `name` 必填。
- `status` 只能是 `active | completed | archived`。
- 固定使用 `company_space_id`。

---

## 8. 平台差异规划

### 8.1 macOS

macOS 优先完成，适合作为 v1 主工作台：

- Sidebar 固定展示 Personal / Company / Agent / Settings。
- 内容区支持表格密度。
- 右侧 Inspector 编辑详情。
- Toolbar 提供上下文新建按钮。
- 支持多选批量完成 / 归档。
- 支持快捷键：
  - `Cmd+N` 新建当前上下文资源。
  - `Cmd+F` 搜索。
  - `Cmd+R` 刷新。
  - `Space` 打开详情或预览。

### 8.2 iOS

iOS 后续接入，必须复用 Domain、API、Repository：

- TabView 承载一级导航。
- Sheet 承载创建 / 编辑。
- Swipe Actions 支持完成、归档、删除。
- Agenda 优先于复杂月历。
- Agent 输入支持语音键盘与短文本快速提交。
- 小屏不展示三栏，详情独立页面承载。

### 8.3 共享与差异边界

共享：

- Domain models。
- API Client。
- Repository。
- Business validation。
- Design tokens。
- Formatter。

差异：

- Navigation shell。
- List density。
- Inspector vs detail page。
- Toolbar vs bottom sheet actions。
- Keyboard-first vs touch-first interactions。

---

## 9. 前后端接口映射表

| 前端视图 | 后端接口 |
| --- | --- |
| 登录 | `POST /api/v1/auth/login` |
| 注册 | `POST /api/v1/auth/register` |
| 当前用户 | `GET /api/v1/me` |
| Space 初始化 | `GET /api/v1/spaces` |
| Personal Tasks | `GET /api/v1/tasks?space_id={personal_space_id}&status=active` |
| Personal Task 新建 | `POST /api/v1/tasks` |
| Personal Task 完成 | `POST /api/v1/tasks/{task_id}/complete` |
| Global Calendar All | 并发调用 Personal 与 Company CalendarItems 后本地合并 |
| Global Calendar Personal Filter | `GET /api/v1/calendar-items?space_id={personal_space_id}&from_date={date}&to_date={date}` |
| Global Calendar Company Filter | `GET /api/v1/calendar-items?space_id={company_space_id}&from_date={date}&to_date={date}` |
| Global Calendar Project Filter | `GET /api/v1/calendar-items?space_id={company_space_id}&project_id={project_id}&from_date={date}&to_date={date}` |
| CalendarItem 新建 | `POST /api/v1/calendar-items` |
| Personal Notes | `GET /api/v1/notes?status=active` |
| Note 转 Task | `POST /api/v1/notes/{note_id}/convert-to-task` |
| Company All Tasks | `GET /api/v1/tasks?space_id={company_space_id}&status=active` |
| Company No Project Tasks | `GET /api/v1/tasks?space_id={company_space_id}&project_scope=no_project&status=active` |
| Company Projects | `GET /api/v1/projects?space_id={company_space_id}&status=active` |
| Project Detail | `GET /api/v1/projects/{project_id}` |
| Project Tasks | `GET /api/v1/projects/{project_id}/tasks` |
| Agent Tools | `GET /api/v1/agent/tools` |
| Agent Command | `POST /api/v1/agent/commands` |
| Agent Confirm | `POST /api/v1/agent/commands/confirm` |
| Agent Logs | `GET /api/v1/agent/action-logs` |
| LLM Key | `GET /api/v1/agent/llm-key` / `PUT /api/v1/agent/llm-key` / `DELETE /api/v1/agent/llm-key` |

---

## 10. 施工优先级

### Phase 1: Apple App 基础框架

- SwiftUI App shell。
- Auth flow。
- API Client。
- Error handling。
- Keychain token storage。
- 拉取 `GET /api/v1/spaces` 并保存两个 Space。
- macOS Sidebar 与 iOS TabView 骨架：Personal、Company、Calendar、Agent、Settings。

### Phase 2: Personal 核心

- Personal Tasks 列表、详情、创建、编辑、完成、归档。
- Personal Notes 列表、详情、创建、编辑、归档。
- Note 转 Task。

### Phase 3: Global Calendar

- Global Calendar 列表 / Agenda / 月视图。
- All / Personal / Company / Project 过滤。
- CalendarItem 创建、编辑、删除。
- 全天事项与具体时间事项表单。
- Personal 与 Company CalendarItems 合并展示。

### Phase 4: Company 核心

- Company Tasks 全部入口。
- No Project 筛选。
- Grouped by Project 前端分组。
- Company Projects 列表、详情、创建、编辑、完成、归档。
- Project Detail 内任务创建。
- Project Detail 内展示项目 CalendarItems 摘要，并跳转到 Global Calendar 项目过滤视图。

### Phase 5: Agent 基础

- LLM Key 设置。
- Agent Tools 拉取。
- Command 输入与 dry run。
- Requires confirmation UI。
- Action logs。
- Agent 创建 Task / CalendarItem / Project / Note。

### Phase 6: iOS 适配与体验收口

- iOS Tab / NavigationStack。
- Sheet 表单。
- Swipe Actions。
- Agenda 小屏优化。
- Dynamic Type。
- VoiceOver。
- UI Tests 覆盖核心路径。

### Phase 7: 同步与离线准备

- Repository 层补充缓存策略。
- 本地模型保留 `updated_at`、`deleted_at`、`version`。
- 预留 sync cursor。
- 网络失败时保留可恢复状态。

---

## 11. 必须测试的前端场景

1. 新用户登录后能看到 Personal 与 Company 两个空间。
2. Personal Task 创建请求中永远不包含 `project_id`。
3. Personal Task 有 `due_date` 时仍显示在 Tasks，不进入 Calendar。
4. Global Calendar All 视图能同时展示 Personal 与 Company CalendarItems。
5. Global Calendar 的事项必须清楚显示来源空间。
6. Calendar 全天事项只发送 `start_date`。
7. Calendar 具体时间事项只发送 `start_at`。
8. Personal Note 只能在 Personal 中创建。
9. Note 转 Task 后原 Note 保留，并展示 linked task。
10. Company Task 可以选择 Project。
11. Company Task 可以不选择 Project。
12. Company Tasks 的 All 视图包含项目内任务和无项目任务。
13. Company No Project 只展示 `project_id = null` 的任务。
14. Project Detail 只展示该 Project 的任务。
15. Global Calendar 创建 Company CalendarItem 时可以选择 Project，也可以不选择 Project。
16. Agent 作为独立一级入口可用，不隐藏在 Personal 或 Company 之下。
17. Agent 写操作成功后刷新对应列表。
18. Agent 需要确认时必须展示确认 UI，不能静默执行。
19. LLM Key 设置页不展示完整 key。
20. Token 过期时能 refresh，refresh 失败时回到登录页。
21. 后端 validation error 能映射到表单字段或全局错误。
22. macOS 三栏布局在窄窗口下不出现文本重叠。
23. iOS 小屏下所有按钮文字不溢出。

---

## 12. v1 非目标

前端 v1 不做：

```text
个人 Project
公司 Notes / Ideas
独立 Subscription 模块
复杂 Task 状态
复杂 RRULE 编辑器
团队协作
多公司 Space
外部 Agent API 管理台
复杂 RBAC
完整离线冲突合并
附件系统
统计报表
自定义主题系统
```

这些能力未来可以扩展，但 v1 不提前放入口，避免 UI 暗示后端不存在的能力。

---

## 13. 验收标准

前端 v1 完成时，必须做到：

1. macOS 可以完成 Personal Tasks / Notes 的核心 CRUD。
2. macOS 可以完成 Company Tasks / Projects 的核心 CRUD。
3. macOS 与 iOS 都有独立 Global Calendar 一级入口，可以同时查看 Personal 与 Company CalendarItems。
4. iOS 可以复用同一套 API 与领域模型，并完成主要浏览、创建、完成、归档路径。
5. Personal 与 Company 在 UI 上清楚分区，不混用 Project。
6. Task、CalendarItem、Note 在 UI 上有明确创建入口与解释性表单字段。
7. Company Tasks 是总入口，Project Detail 是项目视角。
8. Calendar 全天事项与具体时间事项的表单字段不会同时错误提交。
9. Agent 是独立一级入口，命令、dry run、确认、日志可用。
10. LLM Key 只显示 preview，不泄露完整 key。
11. 后端错误能清楚展示，不吞错。
12. macOS 与 iOS 都支持 Light / Dark Mode。
13. macOS 与 iOS 都无明显文字溢出、控件重叠、不可点击状态。
14. OpenAPI / API Client 与后端 schema 保持同步。
15. 未来接入 sync 时不需要重写 Feature UI。

---

## 14. 给前端施工队的最终提醒

这不是一个把所有信息塞进 Todo 的应用。前端必须帮助用户做正确分类：

```text
可以自由安排时间做的事情 => Task
必须在固定时间 / 固定日期发生的事情 => CalendarItem
只是想法、记录、灵感 => Note
公司项目内的工作 => Company Task with project_id
公司杂项小事 => Company Task with project_id = null
```

最重要的前端职责不是做更多入口，而是让入口和后端边界一致：

```text
Personal 没有 Project
Company 没有 Note
Task 不等于 CalendarItem
Project Detail 不等于 Company Tasks 总入口
Calendar 是全局入口，Personal / Company 只是过滤与归属
Agent 是全局入口，不能藏在某个业务空间里
Agent 不能绕过确认与日志
```
