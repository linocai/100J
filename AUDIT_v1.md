# 100J v1 偏离审计与修改方案

> 全部 P0/P1 已在 v1.1 收口；P6 已按个人账户发布口径完成 HZ 部署与本地安装包验收。

> 审计人视角：资深全栈审计工程师
> 审计基线：`plan.md`（v1 施工计划）+ `personal_affairs_backend_blueprint_v1.md` + `personal_affairs_frontend_blueprint_v1.md`
> 审计对象：`backend/`、`frontend/apple/`、`.planning/`、`.learnings/`
> 审计时间：2026-05-19

---

## 0. 一句话锐评

**后端是这个仓库里最遵守计划的部分，几乎按图纸交付；macOS 前端在中途偷偷换了一张图纸（从 plan 里的"主工作台"变成了一个新设计的"Today Command Center"），iOS 前端违反了"只重做导航和表单、不复制逻辑"的核心约束，自己另开了一份视图实现；Phase 5（上云）一行没动；`.planning/STATE.md` 写得太自信，跟当前工作区脏状态对不上。**

简而言之：plan.md 这本书还摆在桌上，但工程师已经偷偷在读另一本书写代码了，且没有把另一本书也明确升格为 source of truth。

---

## 1. 偏离量化总览

| 维度 | 计划要求 | 实际状态 | 偏离 | 严重度 |
|---|---|---|---|---|
| Phase 1 后端 | 见 plan.md §2 | 接口、模型、迁移、测试齐全 | 接近零 | 🟢 |
| Phase 2 macOS IA | Sidebar = Personal/Company/Calendar/Agent/Settings（plan §3.4） | Sidebar 增加 `Today`，并以 Today Command Center 为首页 | **新增一级入口** | 🟡 |
| Phase 2 macOS shell | NavigationSplitView 三栏 | `MacWorkbenchShellView` 三栏（Sidebar+Workspace+Inspector），与 plan 兼容但实现已偏向 redesign blueprint | 实现 ≠ 计划描述 | 🟡 |
| Phase 2 macOS 主要 CRUD | Personal/Company/Calendar/Agent 五条主路径 | 全部存在；但 Agent 写操作 **缺少 requires_confirmation UI** | 关键路径残缺 | 🔴 |
| Phase 3 iOS 复用 | "不复制 API 逻辑、不复制业务校验、iOS 只重做导航/列表/表单/触摸"（plan §4.2） | iOS 在 `Features/iOS/*` 重写了 1544 行视图，与 macOS Features 平行存在 | **违反核心施工原则** | 🔴 |
| Phase 4 本地测试 | 后端测试、smoke、acceptance | 通过 | 接近零 | 🟢 |
| Phase 5 上云 | Dockerfile / deployment.md / CI / 平台选型 | 全部不存在 | **完全未启动** | 🟡 |
| 计划文档自身 | plan.md 是唯一施工标准 | 旁边出现 3 个新设计文档（`100J_Frontend.md`、`100j_swiftui_frontend_redesign_blueprint_v1.md`、`100j_frontend_redesign_v1.html`），事实上变成了"第二份图纸" | **图纸双轨** | 🔴 |
| 工作区状态 | STATE.md 声称 Phase 4 已锁定 | 27 个文件未提交、2 个新增文件未跟踪、`100J_Frontend.md` 也未跟踪 | 文档与工作区脱节 | 🟡 |

---

## 2. 后端审计（vs `plan.md §2` + `personal_affairs_backend_blueprint_v1.md`）

### 2.1 总评：合格 ✅

后端是这个项目最干净、最遵守 plan 的部分。FastAPI + SQLAlchemy + Pydantic + Alembic + PostgreSQL 全部按图实现，目录结构与 plan §2.3 一致，14 项业务规则测试通过。

### 2.2 全部对齐项

- 鉴权五件套（register / login / refresh / logout / me）+ 注册自动创建 Personal & Company space。
- Task CRUD + 完成/重开/归档 + 全部查询参数（`space_id` / `project_id` / `project_scope` / `status` / `priority` / `due_before` / `due_after` / `search` / `limit` / `cursor`）。
- Project 仅限 Company，Note 仅限 Personal，convert-to-task 实现。
- CalendarItem 全天 / 具体时间字段双轨校验在 `app/services/validation_service.py:155-166` 落地。
- Agent：LLM key Fernet 加密、tools 列表、dry run、confirmation token（15 min 过期）、`agent_action_logs`、危险操作要求确认。
- 错误信封 `{error: {code, message, details}}` 与 plan §2.4.9 一致（`app/core/errors.py:32-36`）。
- OpenAPI `/docs` 可用。
- Alembic 两份迁移可从空库 upgrade head。

### 2.3 轻微偏离

| 项 | 文件 | 情况 |
|---|---|---|
| `AUTH_MODE` 增加了 `local_owner` 模式 | `app/api/deps.py:37-38`、`app/core/config.py:12` | plan 里只提 JWT，仓库追加了"本地单用户免登录"模式，README 已说明，且对 `production` 有 guard。**属于合理工程便利，不算违反，但应在 plan 的"v1 不做"或附录里写明，避免下一个 engineer 误判。** |
| `test_local_owner.py` | `backend/tests/test_local_owner.py` | 文件名误导，实际是 auth 模式 + 生产 secret + confirmation 过期测试。建议重命名 `test_auth_modes.py`。 |
| 描述/正文字段无 maxlength | `app/schemas/*` | 全部 `Text` 无限长，存在小型 payload 放大风险。生产前加上 `max_length`。 |
| Agent dry run 不做 Pydantic 校验 | `app/services/agent_service.py:163-167` | dry run 可能"假成功"，实际执行才报 422，UX 隐患。 |
| LLM key 加密 secret 是 `sha256(env)` 派生 | `agent_service.py:_fernet()` | 单用户本地够用，但写进 README 提醒云端必须给真随机 32 bytes secret。 |

### 2.4 Phase 5 缺口（后端侧）

后端**完全没有上云素材**：

- 没有 `Dockerfile`
- 没有 `docker-compose.yml`
- 没有 `deployment.md`
- 没有 `.github/workflows/`
- README 没有任何 Phase 5 段落
- 没有平台选型记录（plan §6.3 要求在 Render/Fly/Railway/AWS/GCP/Azure 中选一种）

这部分的状态正好对应 `.planning/STATE.md` 的"Phase 4 完成，Phase 5 待启动"，是诚实的。但 plan §6.5 要求"部署步骤写入 README 或 deployment.md"，所以**Phase 5 退出标准 = 0 / 5**。

---

## 3. 前端审计（vs `plan.md §3-4` + `personal_affairs_frontend_blueprint_v1.md`）

### 3.1 总评：偏离明显，且偏离是"沉默偏离" 🟡

前端是这次审计真正出问题的地方。问题不是"做得不好"，而是"做的事情和 plan 里写的不一样，而 plan 并没有被相应更新"。

### 3.2 偏离 1：信息架构悄悄加了一级入口

**plan §3.4 macOS Sidebar：**

```
Personal / Company / Calendar / Agent / Settings
```

**实际 `Features/Shell/MacSidebarView.swift`：**

```
Today (Command Center, 首页)
Personal / Company / Calendar / Agent / Settings
```

`Today` 不在 plan 里。它来自后期的 `100j_swiftui_frontend_redesign_blueprint_v1.md` 与 `100J_Frontend.md`。配套生出了：

- `Features/Today/TodayCommandView.swift`
- `Features/Today/FocusStackPanel.swift`
- `Features/Today/FixedSchedulePanel.swift`
- `Features/Today/LooseEndsPanel.swift`
- `Features/Today/TodayMetricsPanel.swift`

这是**事实上的范围扩大**。plan §7 "v1 不做"里没有禁止 Today，但 plan §3.4 明确写过 Sidebar 的五个入口，新增第六个入口属于未经文档化的 scope change。

**修改方案：**

- **路线 A（推荐）**：把 `100j_swiftui_frontend_redesign_blueprint_v1.md` 提升为 frontend v1.1 蓝图，正式 supersede `personal_affairs_frontend_blueprint_v1.md`，并在 `plan.md §3.4` 增补 Today 入口，明确"Today = macOS 首页，作为 Personal + Company + Calendar 的聚合视图，**不引入新的领域对象**"。补一行约束："Today 内容必须只由现有 Task/CalendarItem/Note 聚合而成，不允许产生新表或新 API。"
- **路线 B**：删除 Today，回归 plan 原版（不推荐，已写了 5 个 Panel，沉没成本高，且 Today 体验对 macOS 是加分项）。

---

### 3.3 偏离 2：旧壳/旧视图"半死不活"

`grep` 结果：

- `RootView.swift:34 struct LegacyMainShellView`
- `Features/Company/CompanyTasksView.swift:4 struct LegacyCompanyTasksView`
- `RootView.swift:75 LegacyCompanyTasksView()` 仍被 Legacy shell 调用

`100J_Frontend.md §1` 自己也指出过这个问题（"必须从 macOS 主体验里彻底拿掉"），但代码里只是**加了 Legacy 前缀，没有真正移除**。Legacy shell 还能被构建，文件大小非平凡（`CompanyTasksView.swift` 是 macOS 第一版完整实现）。

**修改方案：**

- 在 `App/RootView.swift` 用 `#if DEBUG && false` 或直接删除 `LegacyMainShellView` 的入口路径，确保 release build 里它进不去。
- `LegacyMainShellView` / `LegacyCompanyTasksView` 整体迁到 `Sources/PersonalAffairsApp/Legacy/`，并在文件顶部加注释 `// Kept for reference until 2026-06; remove after macOS UI sign-off`。
- 给自己设一个 hard deadline（建议 Phase 5 启动前），到期删除，避免"两份 UI 永远共存"。

---

### 3.4 偏离 3（最严重）：iOS 违反复用原则

**plan §4.2：**

> 不复制 API 逻辑。不复制业务校验。iOS 只重做导航外壳、列表密度、表单呈现与触摸交互。

**实际：**

```
Features/iOS/IOSPersonalView.swift     259 行
Features/iOS/IOSCompanyView.swift      374 行
Features/iOS/IOSCalendarView.swift     268 行
Features/iOS/IOSAgentView.swift        161 行
Features/iOS/IOSSettingsView.swift      72 行
Features/iOS/IOSSharedViews.swift      215 行
Features/iOS/IOSForms.swift            159 行
Features/iOS/IOSMainShellView.swift     36 行
                                  -----------
                                     1544 行
```

而 macOS Features 同等模块大约 2900 行。**iOS 不是"只重做导航/表单"，而是把视图层重新写了一遍。**

API 与 Repository 层确实是共享的（`PersonalAffairsCore/Repositories/*`，`PersonalAffairsCore/API/*`），这部分守住了。但视图组合、列表筛选、empty state、空间选择等都被 iOS 重新各写一份，意味着：

- 同一个 bug 修两次。
- 同一个 UX 决策出现两个事实版本（例如 "active/done/archived" 分段控件，macOS 在 `PersonalTasksView.swift:7-8`，iOS 在 `IOSPersonalView.swift` 又写一遍）。
- v1.1 加字段时必然漏改其中一端。

**修改方案：**

1. 立刻盘点 `Features/iOS/*` 中每个 view 的功能切片，与 `Features/Personal|Company|Calendar|Agent` 对应。
2. 抽取**平台无关的 ViewModel 或 ViewState**（普通 Swift struct/class，不依赖 SwiftUI 平台 API）到 `PersonalAffairsCore/ViewState/` 或 `Features/Shared/ViewModels/`：
   - `PersonalTasksViewModel`
   - `CompanyWorkbenchViewModel`
   - `GlobalCalendarViewModel`
   - `AgentViewModel`
3. macOS / iOS 各自只保留**纯 SwiftUI 布局壳**：sidebar vs tabbar、`SurfaceView` vs `Form`、键鼠 vs 触摸。
4. 写一个简短约束文档 `frontend/apple/SHARING_RULES.md`，明确："任何 fetch、filter、convert、validate 写两次的 PR 必须 reject"，并把它链接到 plan §4.2。
5. 短期止血：所有 iOS view 文件顶部加 `// TODO(SHARED-VM): collapse with macOS counterpart, see SHARING_RULES.md`。

这条不解决，Phase 3 退出标准里的"iOS 与 macOS 共用 Domain / API / Repository"虽然形式上通过（Domain/API/Repository 是共享的），但精神上没通过（视图层的业务表达完全分叉）。

---

### 3.5 偏离 4：Agent 缺少 requires_confirmation UI

后端 Agent 的危险操作走 `agent_pending_confirmations` 表 + 15 min token，**这条契约是 plan §2.4.8 明确要求**。Repository 层也实现了 `AgentRepository.confirm()`（`PersonalAffairsCore/Repositories/AgentRepository.swift:49`）。

但 `grep "pendingConfirmation\|requiresConfirmation\|confirmCommand" AgentView.swift` **没有任何命中**。

也就是说：

- 后端会返回 `requires_confirmation: true` + token
- Repository 也有 `confirm(token:)` 方法
- **但 macOS 的 `AgentView.swift` 没有任何 UI 处理这个分支**

后果：用户在 macOS 上跑 Agent 删除一个 Project，会发生：

- 后端返回 needs confirmation
- macOS UI 不知道该怎么显示
- 用户看到的可能是空响应、错误或 dry run 结果，永远没人 confirm

**这条是 plan §3.5.8 + §3.6 的硬验收项，目前实际未交付。**

**修改方案：**

1. 在 `AgentView.swift` 增加 confirmation state：

```swift
@State private var pendingConfirmation: AgentConfirmationPrompt?
```

2. 接收 `AgentCommandResponse` 时分支：

```swift
if response.requiresConfirmation {
    pendingConfirmation = .init(
        token: response.confirmationToken!,
        summary: response.previewSummary,
        expiresAt: response.expiresAt
    )
}
```

3. 用 `.sheet(item: $pendingConfirmation)` 或 Inspector 区域展示"待确认操作"卡片，含：
   - 操作摘要
   - 涉及的资源（task / calendar item / project）
   - 倒计时（distance to expiresAt）
   - `Confirm` / `Cancel` 按钮 → 调用 `AgentRepository.confirm(token:)` / 丢弃
4. iOS `IOSAgentView.swift` 同步做 sheet 版本。
5. 增加测试：mock Agent response = requires_confirmation，验证 UI 显示 sheet。

---

### 3.6 偏离 5：图纸双轨

仓库根目录下现在并存：

```
personal_affairs_frontend_blueprint_v1.md           （plan 引用，正本）
100j_swiftui_frontend_redesign_blueprint_v1.md      （明显是更新版蓝图）
100J_Frontend.md                                    （第三份再修订版，且 git untracked）
100j_frontend_redesign_v1.html                      （HTML 视觉原型）
```

四份文档里有重叠、有冲突、有不同的 IA。`plan.md` 只引用第一份。代码事实上在按第二、三份做。

这是**最危险的偏离**：不是代码偏离文档，而是 source of truth 自己分裂了。后续任何 contributor 都不知道该信哪个。

**修改方案：**

1. **必须立刻确定一份正本**。建议以 `100j_swiftui_frontend_redesign_blueprint_v1.md` 为 v1.1 蓝图，正式 supersede `personal_affairs_frontend_blueprint_v1.md`。
2. 在两份旧 blueprint 的文件头加 `> SUPERSEDED by 100j_swiftui_frontend_redesign_blueprint_v1.md as of 2026-05-19`，**不删，但失去权威**。
3. `100J_Frontend.md` 是一个 review 备忘录而不是蓝图，建议改名为 `frontend_review_2026-05-18.md`，移到 `.planning/reviews/`，避免被当作图纸。
4. 在 `plan.md` 顶部"本计划基于"那一段补一行：`- 100j_swiftui_frontend_redesign_blueprint_v1.md`，并把它列为 frontend 真正的 spec。
5. 把当前 untracked 的 `100J_Frontend.md` 要么 commit 进 `.planning/reviews/`，要么删除——别让它一直挂在工作区。

---

### 3.7 其他前端发现（轻量）

| 项 | 位置 | 情况 | 优先级 |
|---|---|---|---|
| Cmd+1..8 区段快捷键 | `MacSidebarView.swift:203-210` | ✅ 已实现 | — |
| Cmd+N / Cmd+K / Cmd+R | `CommandTopBar.swift` / `QuickCaptureBar.swift` | ✅ 已实现 | — |
| Cmd+F 搜索 | 各 Personal/Company 主面板 | ❌ 未绑定 | P2 |
| ViewModel / Repository 测试 | `Tests/PersonalAffairsCoreTests/` | 仅 1 个占位文件 | P2 |
| `dist/100J.app/` | `frontend/apple/dist/` | `.gitignore` 已忽略 `dist/`，**未实际入库**，但 5MB binary 在工作目录里，容易误操作。建议每次 build 输出到 `/tmp/`。 | P3 |
| ProjectOverviewStrip prefix(6) 截断 | `CompanyWorkbenchView.swift` | redesign blueprint 明确反对静默截断，需要"More" affordance | P2 |
| Inspector 宽度 324 vs blueprint 360~372 | `MacWorkbenchShellView.swift:17` | 视觉偏窄 | P3 |
| 大量 `.opacity(...)` 硬编码 | DesignSystem 多文件 | 60+ 处，未完全迁到 AppTheme token | P3 |
| 工作区 27 个未提交修改 | `git status` | STATE.md 声称 Phase 4 锁定（2026-05-17），实际工作区还在频繁改 | **P1：要么提交，要么 stash，要么写明"acceptance 后的视觉迭代"** |

---

## 4. Phase 4（本地测试）审计 vs `plan.md §5`

### 4.1 总评：✅ 合格

- `backend/scripts/phase4_smoke.py` 端到端覆盖 auth / spaces / tasks / projects / notes / calendar / agent dry run / agent confirm / action logs / token refresh。
- `frontend/apple/ACCEPTANCE_REPORT.md` 列出 18 项功能 + 13 项架构 acceptance，全部 pass。
- `.planning/PHASE4_LOCAL_TEST.md` 给出可重复的本地启动 + 手测清单。
- `.learnings/ERRORS.md` 记录 7 个已解决问题 + 1 个用 workaround 绕过（SwiftPM `%` 路径）。
- 后端 9 条 pytest + Apple 1 条 XCTest 全部通过。

**唯一遗留：**

- 没有显式的 OpenAPI schema diff 测试（plan §2.5 列出但 §5.3 实现只用 smoke 覆盖路由，没有 schema lock 文件）。建议加一个 `tests/test_openapi.py` 做 schema snapshot，防止后续 PR 静默改 API 形状。
- "Mock LLM Provider for Agent tests"（plan §5.2 可选项）未实现。当前 Agent 测试覆盖 `create_task` 与 `update_calendar` 两条，**只有 2/16 tool 有测试**。可以接受，但记入 v1.x backlog。

---

## 5. Phase 5（上云）审计 vs `plan.md §6`

### 5.1 总评：⚠️ 零进度，且 `.planning/STATE.md` 没掩盖这一点

| 子项 | 状态 |
|---|---|
| 平台选型（Render/Fly/Railway/AWS/GCP/Azure） | ❌ 未选 |
| Dockerfile | ❌ 无 |
| docker-compose.yml | ❌ 无 |
| deployment.md | ❌ 无 |
| CI/CD（`.github/workflows/`） | ❌ 无 |
| 生产环境变量模板 | ⚠️ `.env.example` 只覆盖本地 dev，无 prod 模板 |
| 后端 config 对 prod 的支持 | ✅ `app/core/config.py` 有 `app_env` + AUTH_MODE + 生产 secret guard |
| 数据库迁移可上云 | ✅ Alembic 迁移完整，schema 覆盖所有 §6.3.3 表 |
| `/health` 健康检查 | ✅ 已就绪 |

**Phase 5 退出标准（plan §6.5）目前 0 / 4 通过。**

### 5.2 修改方案（推荐次序）

1. **平台选型 1 小时拍板**：v1 单用户 + 单后端 + 单 PostgreSQL，**推荐 Fly.io 或 Railway**，理由：
   - 自带 PostgreSQL
   - 单 region 即可
   - HTTPS / 域名零配置
   - 环境变量管理简单
   - 月成本 < $20 可控
2. **加 Dockerfile**：
   ```dockerfile
   FROM python:3.12-slim
   WORKDIR /app
   COPY pyproject.toml .
   RUN pip install -e .
   COPY app app
   COPY alembic alembic
   COPY alembic.ini .
   CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
   ```
3. **写 `deployment.md`**，覆盖：
   - 选定平台的 create / deploy / migrate 步骤
   - 生产 env 列表（DATABASE_URL / JWT_SECRET_KEY / LLM_KEY_ENCRYPTION_SECRET / CORS_ORIGINS / AUTH_MODE=jwt / APP_ENV=production）
   - 健康检查 path & 期望状态码
   - 日志查看方式
   - rollback 步骤
4. **客户端环境切换**：plan §6.3.6 要求 macOS / iOS 加云端 base URL。当前 `AuthView.swift:41-45` 已可输入 base URL，但应固化为：
   - Debug build → `http://127.0.0.1:8000/api/v1`
   - Release build → 云端 URL（编译期注入）
5. **smoke**：把 `scripts/phase4_smoke.py` 改造成接受 `--base-url`（已有）+ `--env prod` 标签，跑完作为 Phase 5 验收脚本。
6. **`.github/workflows/ci.yml`**：最低限度跑 `ruff check` + `pytest`，PR 必过。可选 push main 触发 fly deploy。

---

## 6. STATE.md 与工作区的"叙事漂移"

`.planning/STATE.md`：

> Phase 4 automated local verification is complete. Latest result: all passed on 2026-05-17.

实际工作区（今天 2026-05-19）：

```
M  27 files (RootView / AppTheme / 全部 Today panels / Company workbench / Personal views / Shell)
?? 100J_Frontend.md
?? frontend/apple/Sources/PersonalAffairsApp/DesignSystem/EditorSheetView.swift
?? frontend/apple/Sources/PersonalAffairsApp/DesignSystem/InspectorCardView.swift
```

也就是说：**Phase 4 acceptance 拍板之后，工作区又开始了一轮没记录的视觉/结构改动，并产生了两个新增 DesignSystem 文件和一份新的 review 文档**。STATE.md 没有更新，没有人正式宣告"进入 Phase 2.5: redesign"。

**修改方案：**

1. 立刻在 `.planning/STATE.md` 增加 `## Current Position` 之外的 `## In-Flight Changes` 段落，写明：
   ```
   Since 2026-05-17 acceptance, an additional visual / shell redesign pass is in flight,
   driven by 100j_swiftui_frontend_redesign_blueprint_v1.md and the new 100J_Frontend.md
   review memo. Phase 4 sign-off remains valid only for the snapshot at commit 2f17828.
   ```
2. 决定这轮 redesign 走 v1.0.x patch 还是 v1.1。
3. 该提交的提交，该 stash 的 stash。`git status --short` 持续脏 = 项目失控信号。

---

## 7. 总体修改方案（按优先级）

### P0 — 立刻

1. **明确 frontend source of truth**：把 `100j_swiftui_frontend_redesign_blueprint_v1.md` 升格为 v1.1 蓝图，在 `plan.md` 顶部补引用；其它两份 frontend 文档加 `SUPERSEDED` 标记或迁到 `.planning/reviews/`。
2. **macOS Agent 补 requires_confirmation UI**。这是 plan §3.6 的硬验收项，目前缺失。
3. **更新 `.planning/STATE.md`** 反映 2026-05-17 之后的 redesign in-flight 状态，避免叙事漂移。
4. **清理 `git status`**：要么提交 redesign 进度，要么 stash，给当前工作区一个确定的语义。

### P1 — 本周

5. **iOS 视图层去重**：抽 `*ViewModel` 到 `PersonalAffairsCore`，写 `SHARING_RULES.md` 锁约束，把 `Features/iOS/*` 削成"纯布局壳"。
6. **真正删除 Legacy shell**：`LegacyMainShellView` + `LegacyCompanyTasksView` 移到 `Legacy/` 目录或 `#if false`，给出删除 deadline。
7. **plan.md 增补 Today 入口** + "Today 不允许产生新领域对象" 约束，让事实状态与文档对齐。

### P2 — Phase 5 启动前

8. **后端 Phase 5 上云素材**：Dockerfile + deployment.md + 选平台 + CI。
9. **OpenAPI schema snapshot 测试**。
10. **Cmd+F 搜索快捷键**。
11. **ProjectOverviewStrip 取消静默截断**。

### P3 — Phase 5 之后 / v1.x

12. 描述/正文 maxlength 限制。
13. Agent dry run 走 Pydantic 校验。
14. ViewModel / Repository 测试补齐（至少 `PersonalTasksViewModel`、`CompanyWorkbenchViewModel`、`AgentViewModel`）。
15. Inspector 宽度、`.opacity()` 硬编码、视觉细节按 redesign blueprint 收口。
16. Agent 16 个 tool 都加 unit test。

---

## 8. 一页纸结论

后端可以按计划交付 Phase 1，质量稳定。**真正阻塞 v1 上线的是三件事：**

1. **Agent confirmation UI 缺失**（功能性 bug，是 plan 硬指标）；
2. **iOS 视图层私自重写**（违反 plan §4.2 原则，会变成长期维护债）；
3. **Frontend 蓝图分裂成 3 份**，事实图纸和正式 plan 不一致（流程性问题，但是项目内最危险的偏离）。

把上面这三件按 P0 处置，把 Phase 5 当成一周内可完成的独立小工程做掉，v1 可以稳定收口。如果继续沉默偏离，**到 Phase 5 上云那天会发现两端表现不一致，且没人知道该信哪份文档**——那才是真正的成本爆炸点。

---

*审计完。*
