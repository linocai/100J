# Personal Affairs App 后端施工蓝图 v1

> 面向 Codex / 后端施工队的第一版实现说明。  
> 当前阶段目标：先做 macOS App，后做 iOS App，后端保持同一套。  
> 当前版本只规划后端核心业务、数据模型、API、AI Agent 接口与施工约束。

---

## 0. 已确认的产品约束

以下是 v1 的硬性约束，施工时不要偏离：

1. **事务空间分为 Personal 与 Company 两个板块。**
   - Personal：个人事务。
   - Company：公司事务。
   - 后端使用统一的 `spaces` 模型承载，但 v1 默认只创建两个 space。

2. **Personal 不做 Project。**
   - 个人事务只有：个人待办、个人日历、个人灵感/备忘。
   - 不允许个人 Task 绑定 `project_id`。
   - v1 不实现个人项目。

3. **Company 使用项目制，但待办仍然有独立总入口。**
   - 公司 Task 可以属于某个 Project。
   - 公司 Task 也可以不属于任何 Project，作为公司杂项待办。
   - Company Tasks 页面应该能看到所有公司待办，包括项目内任务与无项目任务。
   - Project 页面只是同一批 Task 的项目视角。

4. **Task 与 CalendarItem 严格分离。**
   - Task：我可以自己决定什么时候做的灵活待办。
   - CalendarItem：必须在某天某时刻，或某个固定日期发生/提醒的事项。
   - 有截止日期的 Task 仍然是 Task，不因为有 `due_date` 就变成 CalendarItem。

5. **Task 第一版只做三个状态。**
   - `active`：未完成。
   - `done`：已完成。
   - `archived`：已归档。
   - v1 不做 `waiting`、`someday`、`next_action`、`inbox` 等复杂状态。

6. **订阅到期日第一版只做简单记录。**
   - 不做独立 Subscription 模块。
   - 订阅到期日作为 `calendar_items.type = subscription_expiry`。
   - 金额、自动续费、付款方式等暂不建独立字段，可先写在 `description`。

7. **AI Agent 以后也只在 App 内使用。**
   - 不做第三方外部 Agent API。
   - 不做外部开发者 token。
   - Agent 通过当前用户的 App 登录态调用后端。
   - Agent 不直接操作数据库，只能通过后端 API / 后端 domain service 操作。

---

## 1. 后端目标

后端需要支持以下核心能力：

```text
Personal
├── Tasks        个人待办
├── Calendar     个人日历、纪念日、订阅到期日、固定时间事项
└── Notes        灵感库 / 备忘录

Company
├── Tasks        公司全部待办
├── Projects     公司项目
└── Calendar     公司日历、会议、公司截止日、固定时间事项

Agent
├── 查询事务
├── 创建事务
├── 修改事务
├── 整理事务
├── 给出建议
└── 记录操作日志
```

后端应该做到：

- macOS 和 iOS 共用同一套 API。
- 业务规则由后端保证，不能只依赖前端。
- API 字段使用英文，UI 显示可以本地化为中文。
- 所有数据按用户隔离。
- 所有 Agent 写操作必须记录日志。
- 未来可以扩展同步、离线缓存、多设备冲突处理。

---

## 2. 推荐技术栈

默认推荐：

```text
Backend: FastAPI
Language: Python
Database: PostgreSQL
ORM: SQLAlchemy / SQLModel
Migration: Alembic
Validation: Pydantic
API Docs: OpenAPI
Auth: JWT access token + refresh token
```

如果施工队选择其他后端框架，也必须保持本文件定义的数据模型、业务规则和 API 语义。

---

## 3. 核心领域模型

v1 需要实现以下模型：

```text
User
Space
Task
Project
CalendarItem
Note
Tag
AgentActionLog
LLMProviderKey
```

其中最核心的是：

```text
Space         区分 Personal / Company
Task          灵活待办
Project       仅 Company 使用的项目
CalendarItem  固定时间 / 固定日期事项
Note          仅 Personal 使用的灵感 / 备忘
```

---

## 4. 业务规则

### 4.1 Space 规则

v1 中每个用户默认拥有两个 Space：

```text
Personal Space
Company Space
```

`spaces.type` 枚举：

```text
personal
company
```

新用户初始化时自动创建：

```json
[
  { "name": "Personal", "type": "personal" },
  { "name": "Company", "type": "company" }
]
```

v1 可以暂时不提供创建更多 Space 的 UI，但后端可以保留创建 Space 的能力，或只通过 seed 创建默认 Space。

---

### 4.2 Task 与 CalendarItem 的分界

这是最重要的产品规则。

#### Task 是灵活待办

适用于：

```text
整理资料
研究某个想法
买某个东西
处理某个问题
写一个方案
学习某项技能
```

即使有 `due_date`，只要用户可以自己决定什么时候做，它仍然是 Task。

示例：

```json
{
  "type": "task",
  "title": "整理税务材料",
  "due_date": "2026-06-01"
}
```

#### CalendarItem 是固定时间 / 固定日期事项

适用于：

```text
2026-05-25 14:00 去银行办理业务
2026-06-01 09:00 体检
每年 7 月 20 日朋友生日
2026-08-01 某订阅到期
公司会议
外部硬性截止日
```

示例：

```json
{
  "type": "calendar_item",
  "title": "去银行办理业务",
  "start_at": "2026-05-25T14:00:00-04:00",
  "all_day": false
}
```

---

### 4.3 Personal 规则

Personal 只包含：

```text
Personal Tasks
Personal CalendarItems
Personal Notes
```

Personal 不允许：

```text
Project
Task.project_id
CalendarItem.project_id
Note.linked_project_id
```

如果 API 请求试图在 Personal space 下创建 Project 或绑定 Project，应返回 400 / 422。

---

### 4.4 Company 规则

Company 包含：

```text
Company Tasks
Company Projects
Company CalendarItems
```

Company 不做 Notes / Ideas 功能。v1 后端也不需要支持 Company Note。

公司 Task 有两种：

```text
project_id != null  项目内任务
project_id == null  公司杂项任务 / 无项目任务
```

Company Tasks 页面应该支持：

```text
全部公司待办
仅无项目待办
按项目分组
某个项目的待办
```

---

### 4.5 Project 规则

Project 只能属于 Company Space。

创建 Project 时必须校验：

```text
space.type == company
```

Project 下的 Task 必须满足：

```text
task.space_id == project.space_id
```

也就是不能把 Personal Task 挂到 Company Project，不能跨 Space 挂任务。

---

### 4.6 Note 规则

Note 是个人灵感库 / 备忘录。

v1 Note 只允许属于 Personal Space。

Note 与 Task 的区别：

```text
Task = 要做的事情
Note = 想法 / 记录 / 灵感 / 备忘
```

Note 可以转换成 Task：

```text
POST /api/v1/notes/{note_id}/convert-to-task
```

转换后：

- 原 Note 保留。
- 新建一个 Personal Task。
- `notes.linked_task_id` 指向新 Task。

---

### 4.7 订阅到期日规则

v1 不做 subscriptions 表。

订阅到期日使用：

```text
calendar_items.type = subscription_expiry
calendar_items.all_day = true
```

示例：

```json
{
  "space_id": "personal_space_id",
  "title": "ChatGPT Plus 到期",
  "description": "到期前确认是否续费。",
  "type": "subscription_expiry",
  "all_day": true,
  "start_date": "2026-08-01"
}
```

---

## 5. 数据库设计

### 5.1 通用字段

大多数业务表建议包含：

```text
id UUID primary key
created_at timestamptz not null
updated_at timestamptz not null
deleted_at timestamptz nullable
version integer not null default 1
```

说明：

- `deleted_at` 用于软删除。
- `version` 用于未来离线同步和乐观锁。
- 查询默认排除 `deleted_at is not null` 的记录。

---

### 5.2 users

```sql
users
- id UUID primary key
- email text unique nullable
- display_name text nullable
- timezone text not null default 'America/New_York'
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

v1 可以先做单用户开发模式，但数据库仍应保留 `users` 表和 `user_id` 外键。

---

### 5.3 spaces

```sql
spaces
- id UUID primary key
- user_id UUID not null references users(id)
- name text not null
- type text not null check (type in ('personal', 'company'))
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

建议索引：

```sql
create index idx_spaces_user_id on spaces(user_id);
create unique index idx_spaces_user_type_unique_active
on spaces(user_id, type)
where deleted_at is null;
```

v1 每个用户只允许一个 personal space 和一个 company space。

---

### 5.4 tasks

```sql
tasks
- id UUID primary key
- user_id UUID not null references users(id)
- space_id UUID not null references spaces(id)
- project_id UUID nullable references projects(id)
- title text not null
- description text nullable
- status text not null check (status in ('active', 'done', 'archived')) default 'active'
- priority text not null check (priority in ('low', 'medium', 'high', 'urgent')) default 'medium'
- due_date date nullable
- remind_at timestamptz nullable
- estimated_minutes integer nullable
- source text not null check (source in ('manual', 'agent')) default 'manual'
- completed_at timestamptz nullable
- archived_at timestamptz nullable
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

业务校验：

1. Personal Task 必须满足：

```text
project_id is null
```

2. Company Task 可以：

```text
project_id is null
project_id is not null
```

3. 如果 `project_id` 不为空，必须满足：

```text
project.space_id == task.space_id
project.space.type == company
```

4. Task 状态变化规则：

```text
active -> done
active -> archived
done -> active
done -> archived
archived -> active
```

5. `completed_at` 规则：

```text
status = done     => completed_at should be set
status != done    => completed_at should be null
```

6. `archived_at` 规则：

```text
status = archived => archived_at should be set
status != archived => archived_at should be null
```

建议索引：

```sql
create index idx_tasks_user_space on tasks(user_id, space_id);
create index idx_tasks_project_id on tasks(project_id);
create index idx_tasks_status on tasks(status);
create index idx_tasks_due_date on tasks(due_date);
create index idx_tasks_updated_at on tasks(updated_at);
```

---

### 5.5 projects

```sql
projects
- id UUID primary key
- user_id UUID not null references users(id)
- space_id UUID not null references spaces(id)
- name text not null
- description text nullable
- status text not null check (status in ('active', 'completed', 'archived')) default 'active'
- start_date date nullable
- target_date date nullable
- completed_at timestamptz nullable
- archived_at timestamptz nullable
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

业务校验：

```text
Project 只能创建在 company space 下。
```

建议索引：

```sql
create index idx_projects_user_space on projects(user_id, space_id);
create index idx_projects_status on projects(status);
```

---

### 5.6 calendar_items

为了清楚地区分全天事项和具体时间事项，v1 使用 date 字段与 datetime 字段双轨设计。

```sql
calendar_items
- id UUID primary key
- user_id UUID not null references users(id)
- space_id UUID not null references spaces(id)
- project_id UUID nullable references projects(id)
- related_task_id UUID nullable references tasks(id)
- title text not null
- description text nullable
- type text not null check (type in (
    'appointment',
    'anniversary',
    'subscription_expiry',
    'deadline',
    'reminder'
  )) default 'appointment'
- all_day boolean not null default false
- start_date date nullable
- end_date date nullable
- start_at timestamptz nullable
- end_at timestamptz nullable
- timezone text not null default 'America/New_York'
- recurrence text nullable check (recurrence in ('none', 'yearly', 'monthly'))
- remind_at timestamptz nullable
- source text not null check (source in ('manual', 'agent')) default 'manual'
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

字段规则：

1. 全天事项：

```text
all_day = true
start_date required
start_at must be null
end_at must be null
```

2. 具体时间事项：

```text
all_day = false
start_at required
start_date should be null
```

3. Personal CalendarItem：

```text
project_id must be null
```

4. Company CalendarItem：

```text
project_id nullable
```

5. 如果 `project_id` 不为空，必须满足：

```text
project.space_id == calendar_item.space_id
```

6. 如果 `related_task_id` 不为空，必须满足：

```text
task.space_id == calendar_item.space_id
```

7. v1 的 recurrence 只支持简单值：

```text
none
monthly
yearly
```

不要在 v1 实现完整 RRULE。

建议索引：

```sql
create index idx_calendar_items_user_space on calendar_items(user_id, space_id);
create index idx_calendar_items_start_date on calendar_items(start_date);
create index idx_calendar_items_start_at on calendar_items(start_at);
create index idx_calendar_items_type on calendar_items(type);
create index idx_calendar_items_project_id on calendar_items(project_id);
create index idx_calendar_items_related_task_id on calendar_items(related_task_id);
```

---

### 5.7 notes

```sql
notes
- id UUID primary key
- user_id UUID not null references users(id)
- space_id UUID not null references spaces(id)
- title text nullable
- body text not null
- type text not null check (type in ('idea', 'memo')) default 'idea'
- status text not null check (status in ('active', 'archived')) default 'active'
- linked_task_id UUID nullable references tasks(id)
- source text not null check (source in ('manual', 'agent')) default 'manual'
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

业务校验：

```text
Note 只能属于 personal space。
```

如果 `linked_task_id` 不为空，必须满足：

```text
task.space_id == note.space_id
task.space.type == personal
```

建议索引：

```sql
create index idx_notes_user_space on notes(user_id, space_id);
create index idx_notes_status on notes(status);
create index idx_notes_updated_at on notes(updated_at);
```

---

### 5.8 tags

v1 可以实现简单 Tag，也可以作为次优先级。若实现，建议如下：

```sql
tags
- id UUID primary key
- user_id UUID not null references users(id)
- name text not null
- color text nullable
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
- version integer not null default 1
```

```sql
taggings
- id UUID primary key
- user_id UUID not null references users(id)
- tag_id UUID not null references tags(id)
- target_type text not null check (target_type in ('task', 'project', 'calendar_item', 'note'))
- target_id UUID not null
- created_at timestamptz not null
```

v1 如果时间紧，可以先不实现 Tag。

---

### 5.9 llm_provider_keys

用于保存用户输入的 LLM Provider API Key。

```sql
llm_provider_keys
- id UUID primary key
- user_id UUID not null references users(id)
- provider text not null
- encrypted_api_key text not null
- key_preview text nullable
- is_active boolean not null default true
- created_at timestamptz not null
- updated_at timestamptz not null
- deleted_at timestamptz nullable
```

安全要求：

- 不允许明文存储 API key。
- 不允许 API 返回完整 API key。
- `key_preview` 只能保存类似 `sk-...abcd` 的预览文本。
- 日志中必须过滤 API key。

---

### 5.10 agent_action_logs

所有 Agent 写操作必须记录。

```sql
agent_action_logs
- id UUID primary key
- user_id UUID not null references users(id)
- action_type text not null
- target_type text nullable
- target_id UUID nullable
- request_payload jsonb nullable
- result_payload jsonb nullable
- status text not null check (status in ('success', 'failed', 'requires_confirmation'))
- error_message text nullable
- created_at timestamptz not null
```

示例 action_type：

```text
create_task
update_task
complete_task
archive_task
create_calendar_item
update_calendar_item
create_project
update_project
create_note
convert_note_to_task
```

---

## 6. API 设计原则

基础路径：

```text
/api/v1
```

通用规则：

- API 字段使用 snake_case。
- 所有列表接口支持分页。
- 所有列表接口默认排除软删除数据。
- 所有写接口必须校验当前用户是否拥有目标资源。
- 所有跨表关系必须校验同一个 `user_id` 和同一个 `space_id`。

分页格式：

```http
GET /api/v1/tasks?limit=50&cursor=xxx
```

响应格式：

```json
{
  "items": [],
  "next_cursor": null
}
```

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

---

## 7. API Endpoints

### 7.1 Auth API

v1 可先做简单登录，具体认证方案可按项目决定。

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/me
```

注册成功后必须自动创建默认 spaces：

```text
Personal
Company
```

---

### 7.2 Space API

```http
GET /api/v1/spaces
GET /api/v1/spaces/{space_id}
```

v1 不建议开放删除 Space。

响应示例：

```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Personal",
      "type": "personal"
    },
    {
      "id": "uuid",
      "name": "Company",
      "type": "company"
    }
  ]
}
```

---

### 7.3 Task API

```http
GET    /api/v1/tasks
POST   /api/v1/tasks
GET    /api/v1/tasks/{task_id}
PATCH  /api/v1/tasks/{task_id}
DELETE /api/v1/tasks/{task_id}
POST   /api/v1/tasks/{task_id}/complete
POST   /api/v1/tasks/{task_id}/reopen
POST   /api/v1/tasks/{task_id}/archive
```

查询参数：

```text
space_id
project_id
project_scope
status
priority
due_before
due_after
search
limit
cursor
```

`project_scope` 可选值：

```text
all             所有任务
no_project      仅无项目任务
with_project    仅项目内任务
```

示例：获取个人待办

```http
GET /api/v1/tasks?space_id={personal_space_id}&status=active
```

示例：获取公司全部待办

```http
GET /api/v1/tasks?space_id={company_space_id}&status=active
```

示例：获取公司无项目待办

```http
GET /api/v1/tasks?space_id={company_space_id}&project_scope=no_project&status=active
```

示例：获取某项目任务

```http
GET /api/v1/tasks?project_id={project_id}&status=active
```

创建个人 Task：

```json
{
  "space_id": "personal_space_id",
  "title": "整理房间",
  "description": null,
  "priority": "medium",
  "due_date": null,
  "remind_at": null
}
```

创建公司无项目 Task：

```json
{
  "space_id": "company_space_id",
  "project_id": null,
  "title": "处理一封客户邮件",
  "priority": "medium"
}
```

创建公司项目 Task：

```json
{
  "space_id": "company_space_id",
  "project_id": "project_uuid",
  "title": "整理 Q2 财务材料",
  "priority": "high",
  "due_date": "2026-06-10"
}
```

---

### 7.4 Project API

```http
GET    /api/v1/projects
POST   /api/v1/projects
GET    /api/v1/projects/{project_id}
PATCH  /api/v1/projects/{project_id}
DELETE /api/v1/projects/{project_id}
POST   /api/v1/projects/{project_id}/archive
POST   /api/v1/projects/{project_id}/complete
GET    /api/v1/projects/{project_id}/tasks
POST   /api/v1/projects/{project_id}/tasks
```

查询参数：

```text
space_id
status
search
limit
cursor
```

创建 Project：

```json
{
  "space_id": "company_space_id",
  "name": "Personal Affairs App",
  "description": "个人事务管理 App 项目",
  "target_date": null
}
```

`POST /api/v1/projects/{project_id}/tasks` 本质上是创建带 `project_id` 的公司 Task。

请求示例：

```json
{
  "title": "设计后端数据模型",
  "description": null,
  "priority": "high",
  "due_date": null
}
```

---

### 7.5 Calendar API

```http
GET    /api/v1/calendar-items
POST   /api/v1/calendar-items
GET    /api/v1/calendar-items/{calendar_item_id}
PATCH  /api/v1/calendar-items/{calendar_item_id}
DELETE /api/v1/calendar-items/{calendar_item_id}
```

查询参数：

```text
space_id
project_id
type
from_date
to_date
from_at
to_at
limit
cursor
```

创建具体时间事项：

```json
{
  "space_id": "personal_space_id",
  "title": "去银行办理业务",
  "description": null,
  "type": "appointment",
  "all_day": false,
  "start_at": "2026-05-25T14:00:00-04:00",
  "end_at": "2026-05-25T15:00:00-04:00",
  "timezone": "America/New_York",
  "remind_at": "2026-05-25T13:30:00-04:00"
}
```

创建纪念日：

```json
{
  "space_id": "personal_space_id",
  "title": "朋友生日",
  "description": null,
  "type": "anniversary",
  "all_day": true,
  "start_date": "2026-07-20",
  "recurrence": "yearly"
}
```

创建订阅到期日：

```json
{
  "space_id": "personal_space_id",
  "title": "某订阅到期",
  "description": "到期前确认是否续费。",
  "type": "subscription_expiry",
  "all_day": true,
  "start_date": "2026-08-01",
  "recurrence": "none"
}
```

创建公司项目会议：

```json
{
  "space_id": "company_space_id",
  "project_id": "project_uuid",
  "title": "项目周会",
  "description": null,
  "type": "appointment",
  "all_day": false,
  "start_at": "2026-05-26T10:00:00-04:00",
  "end_at": "2026-05-26T10:30:00-04:00",
  "timezone": "America/New_York"
}
```

---

### 7.6 Note API

```http
GET    /api/v1/notes
POST   /api/v1/notes
GET    /api/v1/notes/{note_id}
PATCH  /api/v1/notes/{note_id}
DELETE /api/v1/notes/{note_id}
POST   /api/v1/notes/{note_id}/archive
POST   /api/v1/notes/{note_id}/convert-to-task
```

查询参数：

```text
status
type
search
limit
cursor
```

创建灵感：

```json
{
  "space_id": "personal_space_id",
  "title": "一个新的产品想法",
  "body": "把个人待办、日历、灵感和公司项目管理统一起来。",
  "type": "idea"
}
```

Note 转 Task：

```http
POST /api/v1/notes/{note_id}/convert-to-task
```

请求：

```json
{
  "title": "整理个人事务 App 的产品逻辑",
  "priority": "medium",
  "due_date": null
}
```

响应：

```json
{
  "task": {
    "id": "task_uuid",
    "title": "整理个人事务 App 的产品逻辑",
    "status": "active"
  },
  "note": {
    "id": "note_uuid",
    "linked_task_id": "task_uuid"
  }
}
```

---

## 8. AI Agent 设计

### 8.1 Agent 总原则

Agent 是 App 内功能，不是外部开放平台。

Agent 不允许：

```text
直接操作数据库
绕过用户权限
绕过业务规则
静默执行危险操作
返回或暴露用户的 LLM API key
```

Agent 必须：

```text
使用当前 App 登录用户身份
通过后端 domain service 执行操作
写入 agent_action_logs
对危险操作进行确认
```

---

### 8.2 LLM Provider Key API

```http
GET    /api/v1/agent/llm-key
PUT    /api/v1/agent/llm-key
DELETE /api/v1/agent/llm-key
```

保存 key：

```json
{
  "provider": "openai",
  "api_key": "sk-..."
}
```

响应不能返回完整 key：

```json
{
  "provider": "openai",
  "key_preview": "sk-...abcd",
  "is_active": true
}
```

---

### 8.3 Agent Tools 文档接口

Agent 需要知道自己能调用哪些工具。提供：

```http
GET /api/v1/agent/tools
```

返回结构：

```json
{
  "tools": [
    {
      "name": "create_task",
      "description": "Create a flexible task. Use this when the user can decide when to do it.",
      "parameters_schema": {}
    },
    {
      "name": "create_calendar_item",
      "description": "Create a fixed-time or fixed-date calendar item.",
      "parameters_schema": {}
    }
  ]
}
```

v1 必须提供这些工具：

```text
list_tasks
create_task
update_task
complete_task
archive_task
list_projects
create_project
update_project
list_calendar_items
create_calendar_item
update_calendar_item
list_notes
create_note
update_note
convert_note_to_task
```

---

### 8.4 Agent Command API

```http
POST /api/v1/agent/commands
POST /api/v1/agent/commands/confirm
GET  /api/v1/agent/action-logs
```

命令请求：

```json
{
  "command": "create_task",
  "arguments": {
    "space_id": "company_space_id",
    "project_id": "project_uuid",
    "title": "整理 Q2 财务材料",
    "priority": "high",
    "due_date": "2026-06-10"
  },
  "dry_run": false
}
```

成功响应：

```json
{
  "status": "success",
  "result": {
    "type": "task",
    "id": "task_uuid"
  }
}
```

预演响应：

```json
{
  "status": "dry_run",
  "would_execute": {
    "command": "create_task",
    "arguments": {}
  }
}
```

需要确认的响应：

```json
{
  "status": "requires_confirmation",
  "reason": "This action will archive 12 tasks.",
  "confirmation_token": "token_uuid"
}
```

---

### 8.5 需要确认的 Agent 操作

以下操作必须要求用户确认：

```text
删除任何资源
归档整个 Project
批量修改超过 5 个 Task
批量归档超过 5 个 Task
修改 CalendarItem 的时间
把 Task 从 Personal 移到 Company，或反向移动
```

v1 可以先不实现跨 Space 移动。

---

### 8.6 Agent 判断 Task vs CalendarItem 的规则

Agent 创建事务时必须遵循：

```text
用户说“某天某时要做” => CalendarItem
用户说“某天之前要完成” => Task with due_date
用户说“记一下这个想法” => Note
用户说“公司某项目要做某事” => Company Task with project_id
用户说“公司有个小事”但未指定项目 => Company Task with project_id = null
用户说“订阅到期” => CalendarItem with type = subscription_expiry, all_day = true
用户说“纪念日 / 生日” => CalendarItem with type = anniversary, all_day = true
```

---

## 9. 同步与多端准备

v1 先做 macOS，但后端要为 iOS 做准备。

每个主要表保留：

```text
updated_at
deleted_at
version
```

未来可实现：

```http
GET  /api/v1/sync?since=cursor
POST /api/v1/sync/push
```

v1 可以暂时只实现普通 CRUD，但不要删除这些字段。

---

## 10. 前端视图与后端查询对应关系

### 10.1 Personal Tasks

```http
GET /api/v1/tasks?space_id={personal_space_id}&status=active
```

### 10.2 Personal Calendar

```http
GET /api/v1/calendar-items?space_id={personal_space_id}&from_date=2026-05-01&to_date=2026-05-31
```

### 10.3 Personal Notes

```http
GET /api/v1/notes?status=active
```

### 10.4 Company All Tasks

```http
GET /api/v1/tasks?space_id={company_space_id}&status=active
```

### 10.5 Company No Project Tasks

```http
GET /api/v1/tasks?space_id={company_space_id}&project_scope=no_project&status=active
```

### 10.6 Company Tasks Grouped by Project

后端可以直接返回扁平列表，由前端分组。

也可以提供聚合接口：

```http
GET /api/v1/company/task-groups
```

响应：

```json
{
  "groups": [
    {
      "project": null,
      "label": "No Project",
      "tasks": []
    },
    {
      "project": {
        "id": "project_uuid",
        "name": "Project A"
      },
      "tasks": []
    }
  ]
}
```

v1 建议优先实现扁平列表，聚合接口可选。

### 10.7 Project Detail

```http
GET /api/v1/projects/{project_id}
GET /api/v1/projects/{project_id}/tasks
```

### 10.8 Company Calendar

```http
GET /api/v1/calendar-items?space_id={company_space_id}&from_date=2026-05-01&to_date=2026-05-31
```

---

## 11. 施工优先级

### Phase 1: 基础框架

- FastAPI 项目结构。
- PostgreSQL 连接。
- Alembic migration。
- User / Auth 基础。
- 默认创建 Personal 与 Company spaces。
- OpenAPI docs。

### Phase 2: 核心业务模型

- Space。
- Task。
- Project。
- CalendarItem。
- Note。
- 业务校验。
- 基础 CRUD API。

### Phase 3: Company 项目制视图

- 公司全部待办。
- 公司无项目待办。
- 项目内任务。
- Project Detail。
- Project Task 创建。

### Phase 4: Calendar 逻辑

- 固定时间事项。
- 全天事项。
- 纪念日。
- 订阅到期日。
- 简单 recurrence：none / monthly / yearly。

### Phase 5: Agent 基础

- LLM Provider Key 加密保存。
- Agent tools 文档接口。
- Agent command API。
- Agent action logs。
- Agent dry_run。
- 危险操作确认。

### Phase 6: 测试与验收

- 单元测试。
- API 测试。
- 业务规则测试。
- Agent 操作日志测试。
- OpenAPI schema 检查。

---

## 12. 建议项目结构

```text
backend/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   └── database.py
│   ├── models/
│   │   ├── user.py
│   │   ├── space.py
│   │   ├── task.py
│   │   ├── project.py
│   │   ├── calendar_item.py
│   │   ├── note.py
│   │   ├── llm_provider_key.py
│   │   └── agent_action_log.py
│   ├── schemas/
│   │   ├── task.py
│   │   ├── project.py
│   │   ├── calendar_item.py
│   │   ├── note.py
│   │   └── agent.py
│   ├── services/
│   │   ├── task_service.py
│   │   ├── project_service.py
│   │   ├── calendar_service.py
│   │   ├── note_service.py
│   │   ├── agent_service.py
│   │   └── validation_service.py
│   ├── api/
│   │   └── v1/
│   │       ├── auth.py
│   │       ├── spaces.py
│   │       ├── tasks.py
│   │       ├── projects.py
│   │       ├── calendar_items.py
│   │       ├── notes.py
│   │       └── agent.py
│   └── tests/
│       ├── test_tasks.py
│       ├── test_projects.py
│       ├── test_calendar_items.py
│       ├── test_notes.py
│       └── test_agent.py
├── alembic/
├── pyproject.toml
└── README.md
```

---

## 13. 必须测试的业务场景

### 13.1 Personal Task 不允许绑定 Project

请求：

```json
{
  "space_id": "personal_space_id",
  "project_id": "project_uuid",
  "title": "错误示例"
}
```

预期：

```text
400 / 422
```

---

### 13.2 Project 只能创建在 Company Space

请求：

```json
{
  "space_id": "personal_space_id",
  "name": "个人项目"
}
```

预期：

```text
400 / 422
```

---

### 13.3 Company Task 可以没有 Project

请求：

```json
{
  "space_id": "company_space_id",
  "project_id": null,
  "title": "公司小事"
}
```

预期：

```text
201 Created
```

---

### 13.4 Company Task 可以属于 Project

请求：

```json
{
  "space_id": "company_space_id",
  "project_id": "project_uuid",
  "title": "项目任务"
}
```

预期：

```text
201 Created
```

---

### 13.5 Note 只能属于 Personal Space

请求：

```json
{
  "space_id": "company_space_id",
  "body": "公司灵感"
}
```

预期：

```text
400 / 422
```

---

### 13.6 Calendar 全天事项校验

合法请求：

```json
{
  "space_id": "personal_space_id",
  "title": "订阅到期",
  "type": "subscription_expiry",
  "all_day": true,
  "start_date": "2026-08-01"
}
```

非法请求：

```json
{
  "space_id": "personal_space_id",
  "title": "订阅到期",
  "type": "subscription_expiry",
  "all_day": true,
  "start_at": "2026-08-01T09:00:00-04:00"
}
```

预期：

```text
非法请求返回 400 / 422
```

---

### 13.7 Calendar 具体时间事项校验

合法请求：

```json
{
  "space_id": "personal_space_id",
  "title": "体检",
  "type": "appointment",
  "all_day": false,
  "start_at": "2026-06-01T09:00:00-04:00"
}
```

非法请求：

```json
{
  "space_id": "personal_space_id",
  "title": "体检",
  "type": "appointment",
  "all_day": false,
  "start_date": "2026-06-01"
}
```

预期：

```text
非法请求返回 400 / 422
```

---

### 13.8 Agent 写操作必须生成日志

执行：

```json
{
  "command": "create_task",
  "arguments": {
    "space_id": "personal_space_id",
    "title": "Agent 创建的任务"
  }
}
```

预期：

```text
创建 task 成功
agent_action_logs 新增一条 success 记录
```

---

## 14. 非目标 / v1 不做的事情

v1 明确不做：

```text
个人 Project
公司 Notes / Ideas
独立 Subscription 模块
复杂 Task 状态
复杂重复规则 RRULE
团队协作
多公司 Space
外部 Agent / 第三方开发者 API
复杂权限角色 RBAC
完整离线冲突合并
附件系统
统计报表
```

这些可以未来扩展，但 v1 不要提前做复杂。

---

## 15. 验收标准

后端 v1 完成时，必须能做到：

1. 新用户注册后自动拥有 Personal 与 Company 两个 space。
2. 可以创建、查询、修改、完成、归档 Personal Task。
3. Personal Task 不能绑定 Project。
4. 可以创建、查询、修改、完成、归档 Company Task。
5. Company Task 可以无项目，也可以属于 Project。
6. Project 只能存在于 Company Space。
7. 可以按 Project 查询任务。
8. 可以查询 Company 全部待办和无项目待办。
9. 可以创建个人 / 公司 CalendarItem。
10. 可以创建纪念日和订阅到期日。
11. 可以创建、查询、修改、归档 Personal Note。
12. 可以把 Personal Note 转换成 Personal Task。
13. Agent 可以通过 command API 创建 Task / CalendarItem / Project / Note。
14. Agent 所有写操作都有 action log。
15. OpenAPI 文档可访问，并能被 Agent tools 接口复用。

---

## 16. 最小可运行数据示例

### Personal Task

```json
{
  "title": "整理房间",
  "status": "active",
  "priority": "medium",
  "due_date": null
}
```

### Company Project

```json
{
  "name": "个人事务管理 App",
  "status": "active"
}
```

### Company Project Task

```json
{
  "title": "实现后端 Task API",
  "project_id": "project_uuid",
  "status": "active",
  "priority": "high"
}
```

### Company No-Project Task

```json
{
  "title": "回复供应商邮件",
  "project_id": null,
  "status": "active",
  "priority": "medium"
}
```

### Anniversary CalendarItem

```json
{
  "title": "朋友生日",
  "type": "anniversary",
  "all_day": true,
  "start_date": "2026-07-20",
  "recurrence": "yearly"
}
```

### Subscription Expiry CalendarItem

```json
{
  "title": "某订阅到期",
  "type": "subscription_expiry",
  "all_day": true,
  "start_date": "2026-08-01",
  "recurrence": "none"
}
```

### Personal Note

```json
{
  "title": "App 想法",
  "body": "把个人事务和公司事务统一管理，但保持 Task 与 Calendar 分离。",
  "type": "idea",
  "status": "active"
}
```

---

## 17. 给施工队的最终提醒

这套系统的关键不是做一个普通 Todo App，而是保持以下分界：

```text
Personal vs Company
Task vs CalendarItem
Company Project Task vs Company No-Project Task
Task vs Note
Manual Action vs Agent Action
```

不要把所有事情都塞进 Todo，也不要把所有有日期的事情都塞进 Calendar。

核心判断：

```text
可以自由安排时间做的事情 => Task
必须在固定时间 / 固定日期发生的事情 => CalendarItem
只是想法、记录、灵感 => Note
公司项目内的工作 => Company Task with project_id
公司杂项小事 => Company Task with project_id = null
```

