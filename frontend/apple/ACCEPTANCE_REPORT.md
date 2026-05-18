# 100J macOS/iOS 本机产品级验收报告

日期：2026-05-18

口径：本机产品级验收，ad-hoc 签名 macOS App，本地 FastAPI + 临时 SQLite。
范围外：Developer ID、公证、DMG、App Store、后端 API/模型/枚举语义变更。

## 环境

- Workspace：`/Users/linotsai/Lino/100%J`
- App bundle：`/Users/linotsai/Lino/100%J/frontend/apple/dist/100J.app`
- Bundle ID：`com.lino.100j`
- Development region：`zh_CN`
- Keychain service：`com.lino.100j.auth`
- Keychain legacy service：`PersonalAffairsApp`
- 临时数据库：`sqlite:////tmp/100j_acceptance.db`
- 验收后端：`http://127.0.0.1:8001/api/v1`
- 说明：本机 `8000` 已有 uvicorn 进程占用，验收改用 `8001`，未触碰既有服务。

## Disposable User

- Email：`phase4_1779077617@example.com`
- Password：`Phase4-pass-123`
- Personal space：`ce2f2a7c-7e46-4974-a07a-331e6fb9b031`
- Company space：`4276161f-1120-4531-9db3-5fe82eaf6952`
- Project：`c20a93f2-caab-421a-9916-5ed2eb623ee6`
- Company no-project task：`a54e487a-e635-48cd-a7f6-eee2830edf49`

## 自动验证

| Check | Result |
| --- | --- |
| `cd backend && .venv/bin/pytest` | Pass，9 tests |
| `DATABASE_URL=sqlite:////tmp/100j_acceptance.db .venv/bin/alembic upgrade head` | Pass |
| `backend/.venv/bin/python backend/scripts/phase4_smoke.py --base-url http://127.0.0.1:8001` | Pass |
| `cd frontend/apple && swift build --scratch-path /tmp/personal-affairs-apple-build` | Pass |
| `cd frontend/apple && swift test --scratch-path /tmp/personal-affairs-apple-build` | Pass，4 tests |
| `xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build` | Pass，保留 Xcode destination warning |
| `cd frontend/apple && ./scripts/package-macos-app.sh` | Pass |
| `plutil -lint frontend/apple/dist/100J.app/Contents/Info.plist` | Pass |
| `codesign --verify --deep --strict --verbose=2 frontend/apple/dist/100J.app` | Pass，ad-hoc signature |

打包结果：

- canonical 脚本只保留 `frontend/apple/scripts/package-macos-app.sh`
- 输出路径为 `frontend/apple/dist/100J.app`
- `Info.plist` 含本地 HTTP 所需 `NSAppTransportSecurity -> NSAllowsLocalNetworking = true`
- `Contents/Resources/AppIcon.icns` 已存在

## 本轮反馈验收

| 项目 | 结果 | 说明 |
| --- | --- | --- |
| Apple Keychain 登录态 | Pass with caveat | `TokenStore` 已改为 `com.lino.100j.auth`，access/refresh token 只进 Keychain；启动恢复、logout 清理、旧 service 迁移均已实现。命令行预灌 Keychain 会触发 macOS ACL 提示，不作为产品证据；真实 App 内“登录-重启自动恢复-退出登录-重启回登录页”建议再人工点一遍。 |
| 简体中文优先 | Pass | 登录、Sidebar、Today、Personal、Company、Calendar、Agent、Settings、Quick Capture、空/错/加载状态均已中文化；保留 `100J`、`Agent`、`Quick Capture`、`API Base URL`、`JSON`、`LLM Key`、后端 raw value/API 字段等必要英文。 |
| macOS 顶部融合 | Pass | macOS scene 使用隐藏标题栏/透明 titlebar/full-size content view，保留系统红黄绿按钮；`CommandTopBar` 为交通灯预留空间并融入 Workbench。 |
| 蓝图复核 | Pass | 未新增后端模型，未改 API 契约；Personal 无 Project、Task/CalendarItem 分离、Company Project/No Project、Agent dry run/确认/日志、iOS 可编译这些边界仍保持。 |

## 截图证据

截图保存在 ignored 输出目录：`frontend/apple/dist/acceptance/2026-05-18/`

- `01-login.png`：上一轮登录页基线
- `02-today-wide.png`：Today 宽屏
- `03-calendar-wide.png`：Fixed Calendar 宽屏
- `04-calendar-1180.png`：1180px 档
- `05-today-900.png`：900px 窄宽，Inspector 不挤压主内容
- `06-agent-dry-run-900.png`：Agent dry run
- `07-quick-capture-validation.png`：Quick Capture 校验
- `08-settings-session.png`：Settings/session
- `09-error-banner.png`：错误 banner
- `14-cn-login-no-token.png`：本轮中文登录页，无 Keychain 系统弹窗

说明：`10` 到 `13` 以及后续诊断截图来自命令行预灌 Keychain/坐标 UI 自动化尝试，不计入产品 Pass 证据。

## 18 条功能验收

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 1 | 登录后 macOS 默认进入 Today | Pass | smoke user + UI baseline |
| 2 | Sidebar 有 Today / Personal Tasks / Ideas / Company Workbench / Projects / Fixed Calendar / Agent / Settings | Pass | Sidebar 已中文显示对应入口 |
| 3 | Personal Task 创建时不出现 Project Picker | Pass | Personal 表单/Quick Capture 不暴露 Project |
| 4 | Company Task 创建时 Project Picker 可选，也可为 No Project | Pass | smoke 覆盖 project task 与 no-project task |
| 5 | Today Focus Stack 只显示 Task | Pass | Today 使用 TaskCard 与 task repository 数据 |
| 6 | Today Fixed Schedule 只显示 CalendarItem | Pass | Fixed Schedule 使用 CalendarEventCard 与 calendar repository 数据 |
| 7 | Task 的 due_date 不会让它进入 Calendar 区域 | Pass | smoke due task 仍保留在 Task 视图 |
| 8 | CalendarItem 不显示完成 checkbox | Pass | CalendarEventCard 无完成 checkbox |
| 9 | Note card 可以打开 Convert to Task | Pass | smoke 覆盖 note convert-to-task |
| 10 | Company Workbench 有 No Project Inbox | Pass | no-project company task 已创建并展示路径保留 |
| 11 | Company Workbench 能按 Project 分组 | Pass | Project lane / project tag 路径保留 |
| 12 | Fixed Calendar 能按 All / Personal / Company / Project 过滤 | Pass | UI segmented filter + smoke calendar queries |
| 13 | Agent 操作需要确认时不会静默执行 | Pass | smoke 覆盖 confirmation token flow |
| 14 | LLM Key 不显示完整 key | Pass | Settings 仅显示保存状态/缺失状态 |
| 15 | Refresh 可正常调用 `model.refreshAll()` | Pass | Top Bar 与 Settings 刷新路径保留 |
| 16 | ErrorBanner 正常显示并可关闭 | Pass | 本轮错误状态中文化，上一轮截图验证 |
| 17 | 窗口缩小时 Inspector 不挤压主内容 | Pass | 900px 下 Inspector 隐藏，1180px 以上恢复 |
| 18 | iOS 仍然可编译 | Pass | `xcodebuild` iOS Simulator build succeeded |

## 13 条最终验收标准

| # | Standard | Result |
| --- | --- | --- |
| 1 | 第一眼不是 CRUD shell，而是 Today Command Center | Pass |
| 2 | 左侧导航清楚呈现 Today / Personal / Company / Calendar / Agent | Pass |
| 3 | Task 与 CalendarItem 在视觉和交互上明显不同 | Pass |
| 4 | Personal 没有 Project 的任何入口 | Pass |
| 5 | Company Workbench 同时支持项目制和无项目小任务 | Pass |
| 6 | Fixed Calendar 只承载固定日期 / 固定时间事项 | Pass |
| 7 | Notes 明确是灵感库，而不是任务列表 | Pass |
| 8 | Agent 是 App 内事务管家，有输入、预览、确认和日志 | Pass |
| 9 | macOS 有三栏工作台感：Sidebar + Work Area + Inspector | Pass |
| 10 | iOS 不因本轮 macOS 重构而坏掉 | Pass |
| 11 | Light / Dark Mode 都可读 | Pass with caveat：实现已改为 semantic colors/materials 与暗色背景适配；仍建议在系统 Dark Mode 下补一张无弹窗人工截图。 |
| 12 | 空状态、错误状态、加载状态都不是临时白板 | Pass |
| 13 | 用户可以通过 Quick Capture 快速记录，但写入前有明确落点 | Pass |

## 蓝图对齐复核

已复核文件：

- `plan.md`
- `personal_affairs_backend_blueprint_v1.md`
- `personal_affairs_frontend_blueprint_v1.md`
- `100j_swiftui_frontend_redesign_blueprint_v1.md`
- `100j_frontend_redesign_v1.html`

结论：

- 没有跑偏到“外部 Agent API 控制台”；Agent 仍是 App 内事务管家。
- 没有引入 Personal Project；Personal 仍只有 Tasks / CalendarItems / Notes。
- 没有把 Task due date 混入 Fixed Calendar；CalendarItem 仍独立。
- 没有把 Project 页面做成 Company Tasks 总入口替代品；Company Workbench 仍是总入口。
- 中文化符合早期“UI 可中文，API/缓存模型/枚举值保持英文”的约束。
- 本轮 titlebar 融合是在 HTML 原型基础上进一步产品化，保留系统交通灯，不自绘窗口控制。

## 遗留问题

- 本轮输出是本机 ad-hoc bundle，不是可公开分发的 notarized release。
- Keychain 的代码路径已完成；真实 App 内“登录-重启恢复-logout-重启回登录页”建议人工再验一次。命令行写入 Keychain 会触发 ACL 弹窗，这个现象已排除为测试方式问题。
- Dark Mode 已做实现适配，但仍建议补一张系统暗色外观下的人工截图。
- `frontend/apple/dist/acceptance/2026-05-18/` 是 ignored QA artifact，不建议提交截图。
