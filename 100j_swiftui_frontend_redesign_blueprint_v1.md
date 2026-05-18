# 100J SwiftUI 前端视觉重构施工蓝图 v1

> 面向 Codex / SwiftUI 前端施工队。  
> 目标：把当前 macOS 前端从“基础 CRUD 列表壳”升级为一个真正适合个人事务管理的 **Today Command Center + Company Workbench + Fixed Calendar + App 内 Agent** 工作台。  
> 本文是视觉与交互重构蓝图，不改变既有后端契约。

---

## 0. 施工摘要

本轮只做 **macOS 前端体验重构优先**，iOS 端必须保持可编译、可运行，但不要求同步完成同等视觉复杂度。

核心变化：

```text
Before:
NavigationSplitView
├── Sidebar: Personal / Company / Global
└── Detail: 某一个 CRUD List 页面

After:
100J macOS Workbench
├── Top Command Bar: Quick Capture / Refresh / Status
├── Left Sidebar: Today / Personal / Company / Calendar / Agent / Settings
├── Main Work Area: Today Command / Tasks / Notes / Company Workbench / Calendar / Agent
└── Right Context Inspector: 当前选择对象详情 + Agent Suggestions
```

重构目标不是简单换颜色，而是改变用户一打开 APP 的心智：

```text
不是进入“待办列表”
而是进入“今天我应该怎么管理个人和公司的事务”
```

最重要的产品原则仍然不变：

```text
Task           = 可以自由安排时间做的事
CalendarItem   = 必须在固定日期 / 固定时间发生的事
Note           = 灵感 / 想法 / 备忘，不一定要执行
Project        = 只用于 Company，不用于 Personal
Agent          = App 内事务管家，不是外部 API 控制台
```

---

## 1. 本轮硬性规则

Codex 施工时必须遵守以下规则。

### 1.1 不改后端契约

不得为了视觉重构修改后端 API、数据库模型或枚举语义。前端只能使用现有数据：

```text
User
Space
TaskItem
Project
CalendarItem
Note
AgentTool
AgentActionLog
LLMKey
```

除非用户另行要求，不新增后端接口。

---

### 1.2 Personal 仍然没有 Project

Personal 事务只允许：

```text
Personal Tasks
Personal Notes / Ideas
Personal CalendarItems
```

禁止：

```text
Personal Project
Personal Task 选择 Company Project
Personal Note 关联 Project
Personal CalendarItem 选择 Project
```

---

### 1.3 Task 状态第一版只有三步

Task UI 只支持：

```text
active
 done
 archived
```

不要引入复杂 GTD 状态，例如：

```text
Inbox
Next Action
Waiting
Someday
Canceled
```

可以在 UI 上显示 `No Project Inbox`，但这只是 Company 无项目任务的视图名称，不是新的 Task 状态。

---

### 1.4 订阅到期日第一版只是 CalendarItem

`subscription_expiry` 仍然是 CalendarItem 的一种类型。

不要新增：

```text
Subscription model
Subscription page
Subscription renewal workflow
Payment tracking
Price tracking
```

---

### 1.5 Agent 只在 App 内使用

Agent 不是外部开发者 API。前端不需要做：

```text
外部 API Token 管理
外部 Webhook
第三方 Agent App 接入
外部工具市场
```

Agent UI 只服务于当前 App 内：

```text
自然语言输入
Dry run 预览
需要确认的操作
Action logs
LLM Key 设置入口
```

---

## 2. 当前代码背景

施工队需要先理解当前结构，再动手改。

当前 Apple 端在：

```text
frontend/apple/
```

建议保留当前 Swift Package 结构：

```text
frontend/apple/
├── Package.swift
├── Sources/
│   ├── PersonalAffairsCore/
│   │   ├── API/
│   │   ├── Domain/
│   │   ├── Repositories/
│   │   └── Utilities/
│   └── PersonalAffairsApp/
│       ├── App/
│       ├── DesignSystem/
│       └── Features/
└── Tests/
```

当前 `PersonalAffairsCore` 已经承担 Domain、API Client、Repositories、token storage 等共享能力；重构不要破坏这层。  

当前 macOS shell 的问题是：

```text
MainShellView 仍然是很基础的 NavigationSplitView
Sidebar 只是 Personal / Company / Global 分组
Detail 直接 switch 到 PersonalTasksView / CompanyTasksView / Calendar / Agent / Settings
```

这会导致整个产品看起来像“接口功能列表”，而不是一个事务工作台。

本轮目标是：

```text
保留现有 Domain / Repository / API 能力
重构 PersonalAffairsApp 的 Shell、DesignSystem 和 Feature 页面
让 macOS 体验变成真正的 100J Workbench
```

---

## 3. 视觉方向

### 3.1 总体气质

目标风格：

```text
macOS 原生
安静
温暖
高密度但不拥挤
Material / glass 感
清楚区分 Task、Calendar、Note、Project、Agent
```

不要做成：

```text
营销页
网页后台
过度彩色 dashboard
emoji 过度堆砌
大面积纯蓝色 SaaS 风格
```

---

### 3.2 色彩方向

HTML 原型使用的是温暖灰米色背景 + 白色半透明 surface + 少量蓝 / 紫 / 绿 / 橙强调。SwiftUI 中不要硬编码过多十六进制颜色，而应建立语义 token。

建议 token：

```swift
AppTheme.Colors.windowBackground
AppTheme.Colors.sidebarBackground
AppTheme.Colors.surface
AppTheme.Colors.surfaceStrong
AppTheme.Colors.surfaceSoft
AppTheme.Colors.separator
AppTheme.Colors.primaryText
AppTheme.Colors.secondaryText
AppTheme.Colors.tertiaryText
AppTheme.Colors.personalAccent
AppTheme.Colors.companyAccent
AppTheme.Colors.agentAccent
AppTheme.Colors.warningAccent
AppTheme.Colors.dangerAccent
```

Light Mode 建议：

```text
windowBackground: warm gray / beige
surface: translucent white
primaryText: near black warm gray
secondaryText: 60% opacity
personalAccent: green / teal
companyAccent: blue
agentAccent: purple / indigo
warningAccent: orange
dangerAccent: red
```

Dark Mode 建议：

```text
windowBackground: system dark background with slight warm tint
surface: elevated dark material
primaryText: system primary
secondaryText: system secondary
accent colors use system-safe variants
```

---

### 3.3 字体与层级

使用系统字体，不引入外部字体。

建议层级：

```text
Window title / Today greeting: title2 / title3 semibold
Section title: headline / subheadline semibold
Card title: callout / body semibold
Metadata: caption / caption2
Pill: caption2 semibold
```

内容密度应偏 macOS 生产力工具，不要像 iOS 卡片一样过大。

---

### 3.4 圆角与阴影

建议 token：

```text
radiusXL: 28
radiusLG: 20
radiusMD: 14
radiusSM: 10
```

卡片阴影要轻，Material 优先于厚重阴影。

```text
主要 surface: .regularMaterial / .thinMaterial
卡片边框: 1px equivalent overlay stroke with low opacity
悬浮强调: small soft shadow
```

---

## 4. 新信息架构

### 4.1 左侧 Sidebar

新的 macOS sidebar 不再以 Personal / Company / Global 作为唯一心智，而是以“今天怎么工作”为主。

建议一级结构：

```text
100J
├── Today
│   └── Today Command
│
├── Personal
│   ├── Personal Tasks
│   └── Ideas / Notes
│
├── Company
│   ├── Company Workbench
│   └── Projects
│
└── System
    ├── Fixed Calendar
    ├── Agent
    └── Settings
```

对应 `AppSection` 建议：

```swift
enum AppSection: String, CaseIterable, Identifiable {
    case today
    case personalTasks
    case personalNotes
    case companyWorkbench
    case companyProjects
    case calendar
    case agent
    case settings
}
```

如果当前已有 `companyTasks`，可以保留兼容，但 UI 上应将它升级为 `companyWorkbench`。如果为了减少改动，可以：

```swift
case companyTasks
```

但展示 title 用：

```text
Company Workbench
```

---

### 4.2 顶部 Command Bar

macOS 顶部区域负责三件事：

```text
Quick Capture
当前数据状态 / Refresh
上下文主要动作
```

视觉上位于主 window 顶部，不必第一版就自定义 macOS 原生 titlebar。可以先在 RootView 内实现一个 `CommandTopBar`。

布局：

```text
CommandTopBar
├── 左侧：当前 Section / 用户状态 / 数据加载状态
├── 中间：Quick Capture 输入框
└── 右侧：Refresh / New / Settings shortcut
```

Quick Capture placeholder：

```text
Capture task, fixed event, idea…
```

或者中文：

```text
快速记录：待办、固定日程、灵感……
```

---

### 4.3 中央工作区

中央工作区根据 section 切换。

```text
TodayCommandView
PersonalTasksRedesignedView
PersonalNotesRedesignedView
CompanyWorkbenchView
CompanyProjectsRedesignedView
FixedCalendarView
AgentRedesignedView
SettingsView
```

其中 Settings 可先复用当前 `SettingsView`，但外层要统一 surface 样式。

---

### 4.4 右侧 Context Inspector

右侧 Inspector 是 macOS 体验的关键。

默认状态：

```text
Today Summary
Agent Suggestions
Upcoming fixed items
Loose company tasks
```

用户选中一个 item 后：

```text
Task selected       -> Task detail / quick actions / metadata
Calendar selected   -> Calendar detail / time / recurrence / related task
Note selected       -> Note detail / convert to task
Project selected    -> Project detail / progress / project tasks summary
Agent result        -> Agent action preview / confirm card
```

Inspector 第一版不必承担完整编辑，可以先承担：

```text
详情展示
完成 / 归档 / 删除等轻动作
打开编辑 sheet
Agent 建议展示
```

未来再把表单内联到 Inspector。

---

## 5. macOS Shell 施工方案

### 5.1 新建文件

建议新增：

```text
frontend/apple/Sources/PersonalAffairsApp/Features/Shell/
├── MacWorkbenchShellView.swift
├── MacSidebarView.swift
├── CommandTopBar.swift
├── QuickCaptureBar.swift
├── ContextInspectorView.swift
└── InspectorSelection.swift
```

如果当前目录没有 `Features/Shell`，新建即可。

---

### 5.2 RootView 修改

当前逻辑：

```swift
if model.isAuthenticated {
    #if os(iOS)
    IOSMainShellView()
    #else
    MainShellView()
    #endif
} else {
    AuthView()
}
```

修改为：

```swift
if model.isAuthenticated {
    #if os(iOS)
    IOSMainShellView()
    #else
    MacWorkbenchShellView()
    #endif
} else {
    AuthView()
}
```

可以保留旧 `MainShellView` 文件，但不要再作为 macOS 主入口。为了安全，可以暂时不删除旧代码。

---

### 5.3 MacWorkbenchShellView 布局

建议不要一开始就深度改 window chrome，先在 content 内做：

```swift
struct MacWorkbenchShellView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inspectorSelection: InspectorSelection? = nil
    @State private var quickCaptureText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            CommandTopBar(
                quickCaptureText: $quickCaptureText,
                onSubmitQuickCapture: handleQuickCapture
            )
            Divider()
            HStack(spacing: 0) {
                MacSidebarView(selection: $model.selectedSection)
                    .frame(width: 246)

                Divider()

                currentWorkspace
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                ContextInspectorView(selection: inspectorSelection)
                    .frame(width: 324)
            }
        }
        .background(AppBackgroundView())
        .task { await model.refreshAll() }
    }
}
```

注意：

```text
1. 如果 `selectedSection` 当前默认为 personalTasks，应改为 today。
2. InspectorSelection 可以先作为本地 @State，后续再升到 AppModel。
3. currentWorkspace 根据 AppSection 切换。
4. 窄窗口时可以隐藏 Inspector，见响应式规则。
```

---

### 5.4 响应式规则

macOS 窗口宽度分三档：

```text
>= 1200 px: sidebar + main + inspector 全显示
900 - 1199 px: sidebar + main，inspector 可折叠或 overlay
< 900 px: sidebar 可折叠，main 优先，inspector 隐藏
```

第一版可以简单处理：

```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass
```

但 macOS 上 sizeClass 不总是理想。更实用的做法是用 `GeometryReader` 判断宽度：

```swift
let showsInspector = geometry.size.width >= 1180
```

不要让右侧 Inspector 导致中央区域过窄。

---

## 6. DesignSystem 施工方案

### 6.1 新增 / 重构文件

建议新增：

```text
frontend/apple/Sources/PersonalAffairsApp/DesignSystem/
├── AppTheme.swift
├── AppBackgroundView.swift
├── SurfaceView.swift
├── PillView.swift
├── MetricCardView.swift
├── TaskCardView.swift
├── CalendarEventCardView.swift
├── NoteCardView.swift
├── ProjectCardView.swift
├── SectionHeaderView.swift
└── EmptyStateCardView.swift
```

当前已有：

```text
SharedViews.swift
```

可以继续保留里面的：

```text
ErrorBanner
ToolbarTitle
EmptyStateView
BadgeText
```

但新页面优先使用新的 DesignSystem 组件。

---

### 6.2 AppTheme.swift

目标：集中管理颜色、间距、圆角、阴影语义。

建议结构：

```swift
enum AppTheme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Colors {
        static let personalAccent = Color.green
        static let companyAccent = Color.blue
        static let agentAccent = Color.indigo
        static let warningAccent = Color.orange
        static let dangerAccent = Color.red
    }
}
```

对于 light / dark，可以用 `Color.primary`、`Color.secondary`、`.regularMaterial` 先处理。不要过早写复杂 NSColor provider，除非确实需要。

---

### 6.3 SurfaceView.swift

用于统一卡片 surface：

```swift
struct SurfaceView<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = AppTheme.Radius.lg,
         @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppTheme.Spacing.lg)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
    }
}
```

第一版不要追求完全还原 HTML CSS，SwiftUI 要原生、稳定。

---

### 6.4 PillView.swift

替代过于基础的 `BadgeText`，但不要删除旧组件。

```swift
enum PillStyle {
    case neutral
    case personal
    case company
    case agent
    case warning
    case danger
    case success
}
```

用于：

```text
priority
status
space
project
source agent
due date
calendar type
```

---

### 6.5 TaskCardView.swift

TaskCard 是本轮核心组件。

输入：

```swift
struct TaskCardView: View {
    let task: TaskItem
    let projectName: String?
    let spaceKind: SpaceKindDisplay
    let isSelected: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onArchive: () -> Void
}
```

显示内容：

```text
左侧完成按钮
标题
描述，两行以内
metadata pills:
  priority
  due_date if exists
  project if exists
  agent if source == agent
右侧轻动作：archive / more
```

视觉规则：

```text
active: 正常文本
done: 标题 strikethrough + 透明度降低
archived: 默认不在 active list 展示
urgent: danger pill
high: warning pill
company project: company accent pill
personal: personal accent pill
```

---

### 6.6 CalendarEventCardView.swift

CalendarItem 必须显著区别于 Task。

显示内容：

```text
type icon
时间 / 日期
标题
space pill
calendar type pill
project pill if company project item
recurrence hint if exists
agent pill if source == agent
```

图标映射：

```text
appointment           -> calendar
anniversary           -> gift
subscription_expiry   -> creditcard / bell
 deadline              -> flag
reminder              -> bell
```

视觉规则：

```text
Fixed Calendar 事件不要显示完成 checkbox
不要让 CalendarEventCard 看起来像 TaskCard
all_day 用 date chip
timed 用 startAt chip
```

---

### 6.7 ProjectCardView.swift

用于 Company Workbench 顶部项目概览。

显示内容：

```text
project name
status pill
target_date if exists
active task count
completed task count if available from loaded data
mini progress visual optional
```

第一版 active count 可从 `model.companyTasks` 本地统计。

---

## 7. Today Command Center 页面

### 7.1 文件

新增：

```text
frontend/apple/Sources/PersonalAffairsApp/Features/Today/
├── TodayCommandView.swift
├── FocusStackPanel.swift
├── FixedSchedulePanel.swift
├── LooseEndsPanel.swift
└── TodayMetricsPanel.swift
```

---

### 7.2 页面目标

Today 是用户打开 App 后的默认页面。

它回答三个问题：

```text
1. 今天固定发生什么？
2. 我有哪些可自由安排的重点待办？
3. 公司有没有未归项目的小事和需要处理的项目？
```

---

### 7.3 布局

建议中央区域：

```text
TodayCommandView
├── Header
│   ├── title: Today Command
│   └── subtitle: Flexible tasks stay flexible. Fixed time stays fixed.
│
├── Metrics row
│   ├── Personal active tasks
│   ├── Company active tasks
│   ├── Fixed items today/upcoming
│   └── No-project company tasks
│
└── Two-column content
    ├── Focus Stack
    │   ├── Personal Focus
    │   └── Company Focus
    └── Fixed Schedule
        ├── Today
        └── Upcoming
```

如果窗口变窄，改成单列。

---

### 7.4 数据来源

直接使用 AppModel 中已有数据：

```swift
model.personalTasks
model.companyTasks
model.calendarItems
model.projects
model.notes
```

筛选建议：

```swift
let activePersonalTasks = model.personalTasks.filter { $0.status == .active }
let activeCompanyTasks = model.companyTasks.filter { $0.status == .active }
let noProjectCompanyTasks = activeCompanyTasks.filter { $0.projectId == nil }
```

CalendarItem 今日筛选：

```text
all_day: startDate == today yyyy-MM-dd
 timed: Calendar.current.isDate(startAt, inSameDayAs: Date())
```

Upcoming 筛选：

```text
未来 7 天内的 CalendarItems
```

不要把 Task 的 `due_date` 放进 Fixed Schedule。Task 的 due date 可在 Focus Stack 中以 pill 呈现。

---

### 7.5 Focus Stack

Focus Stack 不是日历。

它展示：

```text
Personal active tasks: 最多 4 个
Company active tasks: 最多 4 个
```

排序建议：

```text
urgent > high > medium > low
有 due_date 的在前
updated_at 较新的在前
```

用户动作：

```text
点击 card -> Inspector 显示详情
完成 -> 调用 complete
归档 -> 调用 archive
查看更多 -> 跳转对应 Task 页面
```

---

### 7.6 Fixed Schedule

Fixed Schedule 只展示 CalendarItem。

分组：

```text
Today
Upcoming
```

显示规则：

```text
Personal CalendarItem: personal accent
Company CalendarItem: company accent
subscription_expiry: warning accent
anniversary: warm / gift icon
deadline: flag icon
```

---

## 8. Personal Tasks 页面重构

### 8.1 文件策略

现有：

```text
Features/Personal/PersonalTasksView.swift
```

可以直接改造这个文件，也可以新建：

```text
Features/Personal/PersonalTasksRedesignedView.swift
```

为了减少 RootView 变更，建议保留 `PersonalTasksView` 名字，内部重构为新视觉。

---

### 8.2 页面布局

```text
PersonalTasksView
├── PageHeader
│   ├── title: Personal Tasks
│   ├── subtitle: Flexible personal work. Due dates stay in tasks.
│   └── New Task button
│
├── FilterBar
│   ├── status segmented control: Active / Done / Archived
│   ├── search field
│   └── optional priority filter
│
└── TaskCard list / grid
```

第一版使用垂直 list 即可，不要做复杂 kanban。

---

### 8.3 交互

保留现有能力：

```text
create
complete
reopen
archive
search
status filter
```

新增：

```text
点击 task card 后右侧 Inspector 显示详情
```

如果 InspectorSelection 暂时是 shell 本地 state，需要通过 closure 传给页面：

```swift
PersonalTasksView(onSelectTask: { task in inspectorSelection = .task(task.id) })
```

如果不想大改函数签名，也可先让页面内部只做视觉升级，不接 Inspector，Phase 2 再接。

---

## 9. Personal Notes / Ideas 页面重构

### 9.1 目标

Notes 是个人灵感库，不是另一个待办列表。

视觉上应更像：

```text
Apple Notes + idea cards
```

而不是 Task list。

---

### 9.2 布局

```text
PersonalNotesView
├── Header
│   ├── Ideas / Notes
│   └── New Note
├── FilterBar
│   ├── All / Ideas / Memos / Archived
│   └── Search
└── Note cards
```

Note card 显示：

```text
title if exists
body preview, 最多 3 行
type pill: idea / memo
created_at / updated_at
agent source if applicable
linked task if exists
```

---

### 9.3 Convert to Task

Note 转 Task 仍保留。

交互建议：

```text
Note card more menu -> Convert to Task
或 Inspector detail -> Convert to Task primary action
```

转换后：

```text
保留原 Note
刷新 notes
刷新 personal tasks
Inspector 显示 linked task hint
```

---

## 10. Company Workbench 页面

### 10.1 文件

新增：

```text
frontend/apple/Sources/PersonalAffairsApp/Features/Company/CompanyWorkbenchView.swift
```

当前 `CompanyTasksView.swift` 可以保留为内部组件或旧页面。新的 sidebar 应指向 `CompanyWorkbenchView`。

---

### 10.2 页面目标

Company Workbench 解决你最初提出的矛盾：

```text
公司事务要项目制
但公司待办又要有独立总入口
```

新的页面必须同时呈现：

```text
Project Overview
All Company Tasks
No Project Inbox
Grouped by Project
```

---

### 10.3 布局

```text
CompanyWorkbenchView
├── Header
│   ├── title: Company Workbench
│   ├── subtitle: Project work and no-project tasks share one command surface.
│   ├── New Task
│   └── New Project
│
├── Project Overview Strip
│   ├── ProjectCard A
│   ├── ProjectCard B
│   └── ProjectCard C
│
└── Task Board
    ├── No Project Inbox
    ├── Project A
    ├── Project B
    └── Project C
```

---

### 10.4 Task Board 规则

Company Task 仍是一个独立对象。

```text
project_id = null     -> No Project Inbox
project_id = xxx      -> 对应 Project lane
```

排序：

```text
No Project Inbox 放最上方
active projects 按 updated_at 或 target_date 排序
每组内部按 priority / due_date 排序
```

第一版不要做拖拽跨项目。如果想支持“归入项目”，用 Task 编辑表单修改 project_id。

---

### 10.5 Company Workbench 与 Company Projects 的关系

```text
Company Workbench = 日常处理入口
Company Projects  = 项目管理入口
```

Projects 页面不要重复完整 task board，只展示：

```text
项目列表
项目详情
项目任务摘要
进入当前项目任务过滤入口
```

---

## 11. Company Projects 页面重构

### 11.1 布局

```text
CompanyProjectsView
├── Header
│   ├── title: Projects
│   └── New Project
├── Project list / cards
└── optional selected project detail
```

Project detail 建议展示：

```text
name
description
status
start_date
target_date
active task count
project tasks preview
related calendar items preview
```

完整项目任务处理仍回到 Company Workbench 的 project lane。

---

## 12. Fixed Calendar 页面重构

### 12.1 命名

Sidebar 显示名称建议：

```text
Fixed Calendar
```

原因：强调这里不是任务计划表，而是固定日期 / 固定时间事项。

文件可以继续叫：

```text
GlobalCalendarView.swift
```

也可以新建：

```text
FixedCalendarView.swift
```

Root 中把 `.calendar` 指向新视图。

---

### 12.2 页面布局

```text
FixedCalendarView
├── Header
│   ├── title: Fixed Calendar
│   ├── subtitle: Only fixed dates, appointments, anniversaries, and expiries.
│   └── New Item
│
├── FilterBar
│   ├── All / Personal / Company / Project
│   └── project picker if Project
│
└── Agenda list
    ├── Today
    ├── Tomorrow
    ├── This Week
    └── Later
```

第一版不需要复杂月历。Agenda 优先。

---

### 12.3 关键规则

Calendar 页面不能暗示 Task 会自动进入日历。

文案建议：

```text
Tasks with due dates remain in Tasks. Only fixed-time items live here.
```

中文：

```text
有截止日期的待办仍然属于待办；只有固定日期 / 固定时间事项进入日历。
```

---

### 12.4 表单规则

沿用现有 Calendar form，但视觉升级。

保留：

```text
Space picker
Title
Description
Type
All day toggle
Start date or Start time
Recurrence
Project picker when Company
```

默认建议：

```text
anniversary           -> all_day = true, recurrence = yearly
subscription_expiry   -> all_day = true
appointment           -> all_day = false
reminder              -> depends on user input
deadline              -> all_day often true, but not forced
```

---

## 13. Agent 页面重构

### 13.1 目标

Agent 不应该只是“聊天页面”。它是 100J 的事务管家。

Agent 页面应包括：

```text
Command input
Suggested commands
Dry run result
Confirmation card
Recent action logs
LLM key status
```

---

### 13.2 布局

```text
AgentRedesignedView
├── Header
│   ├── title: Agent
│   └── subtitle: Let the app organize tasks, calendar items, notes, and projects.
│
├── Command composer
│   ├── multiline input
│   ├── Dry Run toggle
│   └── Run button
│
├── Suggestion chips
│   ├── 整理无项目公司待办
│   ├── 找出最近到期订阅
│   ├── 把灵感转成待办建议
│   └── 今天我可以做什么
│
├── Result / Confirmation panel
└── Recent Agent Logs
```

---

### 13.3 Inspector 中的 Agent Suggestions

右侧 Inspector 默认状态下可以展示一个小 Agent panel：

```text
Agent Suggestions
├── 3 company tasks are not assigned to any project
├── 2 calendar items are upcoming this week
└── 1 note might be convertible to task
```

第一版这些 suggestions 可以本地规则生成，不必调用模型。

---

### 13.4 安全规则

以下操作需要确认 UI：

```text
delete any resource
archive project
batch modify more than 5 tasks
batch archive more than 5 tasks
modify CalendarItem time
cross-space move
```

如果后端返回 `requires_confirmation`，前端必须展示：

```text
operation summary
affected target type
affected count if available
confirmation button
cancel button
```

不要静默执行。

---

## 14. Quick Capture 设计

### 14.1 第一版不要过度智能

Quick Capture 是体验关键，但第一版可以先做成“输入后选择落点”。

用户输入：

```text
整理税务材料
明天下午 3 点体检
想到一个新的产品点子
```

提交后弹出 Capture Sheet：

```text
Raw input preview
Suggested type chips:
  Task
  Fixed Calendar
  Idea / Note
  Company Task
Optional fields based on chosen type
Save
```

不要在没有用户确认的情况下自动判断并写入后端。

---

### 14.2 未来 Agent 接入

如果 Agent tools 已可用，Quick Capture 可以调用 Agent dry run 来建议类型：

```text
Input -> Agent dry run -> Suggested action -> User confirm -> Backend command
```

但本轮优先完成 UI 和安全确认。

---

### 14.3 Quick Capture 输入行为

建议快捷键：

```text
Cmd + K 或 Cmd + Shift + Space 聚焦 Quick Capture
Enter 打开 Capture Sheet
Esc 清空 / 关闭
```

不要抢占系统常用快捷键过多。

---

## 15. InspectorSelection 设计

新增：

```swift
enum InspectorSelection: Equatable {
    case task(String)
    case calendarItem(String)
    case note(String)
    case project(String)
    case agentLog(String)
}
```

Inspector 内部根据 id 从 AppModel 当前数组查找对象：

```swift
model.personalTasks + model.companyTasks
model.calendarItems
model.notes
model.projects
model.agentLogs
```

如果找不到，显示：

```text
No item selected
或 Item no longer available
```

第一版不需要全局 selected model object，避免过多同步问题。

---

## 16. AppModel 建议微调

当前 AppModel 已有：

```text
currentUser
spaces
personalTasks
companyTasks
projects
notes
calendarItems
agentTools
agentLogs
llmKey
isLoading
errorMessage
selectedSection
repositories
```

本轮建议增加：

```swift
@Published var selectedSection: AppSection? = .today
```

如果原本没有 `.today`，新增后将默认从 `.personalTasks` 改为 `.today`。

可以新增只读 helper，不改变 API：

```swift
var activePersonalTasks: [TaskItem]
var activeCompanyTasks: [TaskItem]
var noProjectCompanyTasks: [TaskItem]
func projectName(for projectId: String?) -> String?
func spaceKind(for spaceId: String) -> SpaceKindDisplay
```

如果担心 AppModel 变胖，可以把 helper 放在 View extension 或 `DashboardDataBuilder`。

---

## 17. 数据排序规则

### 17.1 Task 排序

统一函数：

```swift
func sortedForFocus(_ tasks: [TaskItem]) -> [TaskItem]
```

排序：

```text
1. priority: urgent > high > medium > low
2. due_date exists before nil
3. due_date earlier first
4. updated_at newer first
```

注意：`due_date` 是 String date-only，需要安全解析。解析失败时当作 nil。

---

### 17.2 CalendarItem 排序

排序 key：

```text
1. date / datetime
2. all_day before timed for same day
3. type priority optional
```

Calendar date 获取：

```text
if allDay: startDate
else: startAt
```

`startDate` 是 date-only string。`startAt` 是 Date。

---

### 17.3 Project 排序

建议：

```text
active first
target_date earlier first
updated_at newer first
name alphabetically as fallback
```

---

## 18. 表单策略

### 18.1 第一版继续用 Sheet

虽然目标是 Inspector 编辑，但第一版为了施工稳定，可以继续用 sheet 表单：

```text
TaskFormView
CalendarItemFormView
NoteFormView
ProjectFormView
```

需要做的是：

```text
统一视觉
统一间距
统一按钮位置
统一错误展示
```

---

### 18.2 表单视觉

Sheet 内容建议：

```text
FormHeader
Grouped fields
Primary action at bottom-right
Cancel as secondary
Validation inline message
```

不要使用过大的 sheet。macOS 合理宽度：

```text
Task: 480
CalendarItem: 540
Note: 560
Project: 520
```

---

## 19. Accessibility 与键盘

必须支持：

```text
VoiceOver label
keyboard shortcuts
focus order
Dynamic Type 基础适配
高对比度下可读
```

建议快捷键：

```text
Cmd + 1: Today
Cmd + 2: Personal Tasks
Cmd + 3: Ideas / Notes
Cmd + 4: Company Workbench
Cmd + 5: Fixed Calendar
Cmd + 6: Agent
Cmd + N: 根据当前上下文新建
Cmd + R: Refresh
Cmd + F: Search
Cmd + K: Quick Capture
```

不要因为卡片化导致键盘用户无法操作。

---

## 20. 文件级施工步骤

### Phase 0: 建立安全基线

目标：确认当前能编译。

执行：

```bash
cd frontend/apple
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
```

如果 SwiftPM 因路径或 index store 报错，使用 scratch path。

验收：

```text
构建通过
现有测试通过
不先改代码
```

---

### Phase 1: DesignSystem 基础

新增：

```text
AppTheme.swift
AppBackgroundView.swift
SurfaceView.swift
PillView.swift
SectionHeaderView.swift
MetricCardView.swift
```

验收：

```text
项目可编译
不影响现有页面
新组件有 preview if possible
Light / Dark Mode 基础可读
```

---

### Phase 2: macOS Shell

新增：

```text
Features/Shell/MacWorkbenchShellView.swift
Features/Shell/MacSidebarView.swift
Features/Shell/CommandTopBar.swift
Features/Shell/QuickCaptureBar.swift
Features/Shell/ContextInspectorView.swift
Features/Shell/InspectorSelection.swift
```

修改：

```text
RootView.swift
AppSection.swift or AppSection declaration location
```

验收：

```text
登录后 macOS 默认进入 Today
左侧导航显示新 IA
顶部 Quick Capture 可见
右侧 Inspector 可见或按窗口宽度隐藏
旧 iOS shell 不受影响
```

---

### Phase 3: Today Command

新增：

```text
Features/Today/TodayCommandView.swift
Features/Today/FocusStackPanel.swift
Features/Today/FixedSchedulePanel.swift
Features/Today/LooseEndsPanel.swift
Features/Today/TodayMetricsPanel.swift
```

验收：

```text
Today 显示 personal task count
Today 显示 company task count
Today 显示 no-project company task count
Today 显示今日 / upcoming calendar items
Task 不被混入 Fixed Schedule
CalendarItem 不显示完成 checkbox
```

---

### Phase 4: Shared Cards

新增：

```text
TaskCardView.swift
CalendarEventCardView.swift
NoteCardView.swift
ProjectCardView.swift
```

修改现有页面逐步替换 `List` row。

验收：

```text
PersonalTasksView 使用 TaskCardView
CompanyWorkbench 使用 TaskCardView
Calendar 使用 CalendarEventCardView
Notes 使用 NoteCardView
Projects 使用 ProjectCardView
```

---

### Phase 5: Company Workbench

新增：

```text
Features/Company/CompanyWorkbenchView.swift
```

可拆分：

```text
ProjectOverviewStrip.swift
CompanyTaskBoard.swift
CompanyTaskLane.swift
```

验收：

```text
Company Workbench 有 Project Overview
No Project Inbox 单独分组
项目任务按 project_id 分组
New Task 可选 project_id 或 nil
New Project 可用
点击项目可进入 Projects 或 Inspector
```

---

### Phase 6: Calendar 与 Agent 视觉升级

修改或新增：

```text
FixedCalendarView.swift / GlobalCalendarView.swift
AgentRedesignedView.swift / AgentView.swift
```

验收：

```text
Calendar 名称显示为 Fixed Calendar
Agenda 分组清楚
All / Personal / Company / Project filter 可用
Agent 有 command composer
Agent 有 logs
LLM key preview 不泄露完整 key
requires_confirmation 时有确认 UI
```

---

### Phase 7: Polish

处理：

```text
loading states
empty states
error states
hover states
selection states
keyboard shortcuts
window width adaptation
VoiceOver labels
```

验收：

```text
窄窗口不重叠
空数据时页面仍好看
网络错误时 ErrorBanner 可见
macOS Light / Dark 都可读
iOS 仍然可编译
```

---

## 21. 关键实现细节

### 21.1 不要把 App 变成纯卡片堆砌

卡片用于：

```text
Task
CalendarItem
Note
Project
Metric
Agent confirmation
```

页面 section 不要每层都套重卡片。否则 macOS 上会显得笨重。

---

### 21.2 列表密度

macOS TaskCard 高度建议：

```text
compact: 58 - 72
normal: 76 - 96
```

Today Focus Stack 应偏 compact。Detail 页可以稍大。

---

### 21.3 hover 与 selection

macOS 要有 hover 状态。

```swift
.onHover { isHovering = $0 }
```

Selection：

```text
selected card 背景稍强
左侧加 accent stroke 或 subtle glow
不要使用大面积高饱和色
```

---

### 21.4 Source = agent

`source == "agent"` 时，只显示小型 pill：

```text
Agent
```

不要让 Agent 来源抢占标题位置。

---

### 21.5 Project name lookup

统一函数：

```swift
func projectName(_ projectId: String?, projects: [Project]) -> String?
```

如果 projectId 存在但找不到项目，显示：

```text
Unknown Project
```

不要显示 raw UUID。

---

### 21.6 Space display

统一函数：

```swift
func spaceLabel(_ spaceId: String, spaces: [Space]) -> String
```

如果找不到：

```text
Unknown Space
```

但 UI 中尽量避免 raw ID。

---

## 22. Quick Capture Sheet 细节

新增：

```text
Features/Capture/QuickCaptureSheet.swift
Features/Capture/CaptureDraft.swift
```

CaptureDraft：

```swift
enum CaptureTarget {
    case personalTask
    case companyTask
    case fixedCalendar
    case personalNote
}

struct CaptureDraft {
    var rawText: String
    var target: CaptureTarget
    var title: String
    var description: String
    var priority: TaskPriority
    var dueDate: String
    var calendarType: CalendarItemType
    var allDay: Bool
    var startDate: String
    var startAt: Date
    var noteType: NoteType
    var projectId: String?
}
```

规则：

```text
personalTask: space_id = personal, project_id = nil
companyTask: space_id = company, project_id optional
fixedCalendar: choose personal/company; project only if company
personalNote: space_id = personal
```

Sheet UI：

```text
顶部显示原始输入
Target segmented control / chips
根据 target 显示对应字段
Save button
```

---

## 23. Loading / Empty / Error 状态

### 23.1 Loading

当前 `model.isLoading` 是全局 loading。页面可使用：

```text
small progress indicator in CommandTopBar
not full-screen blocking unless first load
```

---

### 23.2 Empty State 文案

Today 无数据：

```text
Nothing is pressing right now.
Capture a task, fixed event, or idea to start organizing 100J.
```

Personal Tasks 无数据：

```text
No flexible personal tasks.
Tasks are things you can do when you choose.
```

Calendar 无数据：

```text
No fixed items.
Appointments, anniversaries, and expiries belong here.
```

Company Workbench 无数据：

```text
No company work yet.
Create a project or add a no-project company task.
```

Notes 无数据：

```text
No ideas yet.
Capture thoughts here before they become tasks.
```

---

### 23.3 Error

继续使用 ErrorBanner，但视觉升级为 Material card。

错误不应吞掉页面。除登录失败外，大部分错误显示 banner 并保留现有数据。

---

## 24. iOS 保持策略

本轮不要求 iOS 同步大改，但必须：

```text
swift build 不坏
iOSMainShellView 不坏
共享组件不要使用 macOS-only API，除非 #if os(macOS)
新 macOS Shell 必须包在 #if os(macOS)
```

若 DesignSystem 使用 macOS-only modifier，需要条件编译。

建议：

```swift
#if os(macOS)
// Mac hover / window-specific behavior
#endif
```

不要把 iOS TabView 替换成 macOS 三栏。

---

## 25. 测试清单

### 25.1 编译测试

```bash
cd frontend/apple
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
```

如果使用 Xcode：

```bash
cd frontend/apple
xcodebuild -scheme PersonalAffairsApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/personal-affairs-xcode-derived \
  build
```

模拟器名称可按本机可用设备替换。

---

### 25.2 功能测试

必须验证：

1. 登录后 macOS 默认进入 Today。
2. Sidebar 有 Today / Personal Tasks / Ideas / Company Workbench / Projects / Fixed Calendar / Agent / Settings。
3. Personal Task 创建时不出现 Project Picker。
4. Company Task 创建时 Project Picker 可选，也可为 No Project。
5. Today Focus Stack 只显示 Task。
6. Today Fixed Schedule 只显示 CalendarItem。
7. Task 的 due_date 不会让它进入 Calendar 区域。
8. CalendarItem 不显示完成 checkbox。
9. Note card 可以打开 Convert to Task。
10. Company Workbench 有 No Project Inbox。
11. Company Workbench 能按 Project 分组。
12. Fixed Calendar 能按 All / Personal / Company / Project 过滤。
13. Agent 操作需要确认时不会静默执行。
14. LLM Key 不显示完整 key。
15. Refresh 可正常调用 `model.refreshAll()`。
16. ErrorBanner 正常显示并可关闭。
17. 窗口缩小时 Inspector 不挤压主内容。
18. iOS 仍然可编译。

---

## 26. 非目标

本轮不要做：

```text
个人 Project
公司 Notes / Ideas
独立 Subscription 模块
完整月历复杂交互
拖拽式 Kanban
跨项目拖拽改 project_id
复杂 recurrence 编辑器
外部 Agent API token
第三方集成
团队协作 / 多用户权限
完整离线同步
统计报表
自定义主题系统
```

---

## 27. Codex 施工顺序建议

建议按下面顺序提交 PR / patch：

```text
Patch 1: DesignSystem tokens + surfaces + pills
Patch 2: MacWorkbenchShell + Sidebar + CommandTopBar + Inspector placeholder
Patch 3: TodayCommandView + metrics + FocusStack + FixedSchedule
Patch 4: TaskCard / CalendarEventCard / NoteCard / ProjectCard
Patch 5: PersonalTasksView 和 PersonalNotesView 视觉替换
Patch 6: CompanyWorkbenchView
Patch 7: FixedCalendarView 和 AgentRedesignedView
Patch 8: QuickCaptureSheet
Patch 9: polish + keyboard shortcuts + accessibility + tests
```

每个 patch 后都运行：

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
```

如果改到 core 或 repository，再运行：

```bash
swift test --scratch-path /tmp/personal-affairs-apple-build
```

---

## 28. 最终验收标准

完成后，100J macOS 前端应该满足：

```text
1. 第一眼不是 CRUD shell，而是 Today Command Center。
2. 左侧导航清楚呈现 Today / Personal / Company / Calendar / Agent。
3. Task 与 CalendarItem 在视觉和交互上明显不同。
4. Personal 没有 Project 的任何入口。
5. Company Workbench 同时支持项目制和无项目小任务。
6. Fixed Calendar 只承载固定日期 / 固定时间事项。
7. Notes 明确是灵感库，而不是任务列表。
8. Agent 是 App 内事务管家，有输入、预览、确认和日志。
9. macOS 有三栏工作台感：Sidebar + Work Area + Inspector。
10. iOS 不因本轮 macOS 重构而坏掉。
11. Light / Dark Mode 都可读。
12. 空状态、错误状态、加载状态都不是临时白板。
13. 用户可以通过 Quick Capture 快速记录，但写入前有明确落点。
```

---

## 29. 施工队最后提醒

100J 的核心不是“更多页面”，而是帮助用户把事情放到正确的位置：

```text
可以自由安排时间做的事情       -> Task
必须在固定日期 / 时间发生的事情 -> CalendarItem
只是想法、灵感、记录             -> Note
公司项目内工作                   -> Company Task with project_id
公司杂项小事                     -> Company Task with project_id = null
```

前端每一个按钮、表单、卡片和页面名称都要强化这个心智。

如果视觉很好看，但让用户分不清 Task 和 CalendarItem，这次重构就失败了。

