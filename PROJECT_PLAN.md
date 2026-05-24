# 100J v1.2.5 项目规划

> 这是 v1.2.5 的施工蓝图。v1.2.4 已经发布（main HEAD `8987b8d`，tag `v1.2.4`，build 1.126），修了 reviewer 报告 32/34 条。剩下 3 项 deferred 全部落入本期。
>
> 工作目录 `/Users/linotsai/Lino/100%J/`。基线 commit = `v1.2.4`。目标 tag = `v1.2.5`，build = `1.127`。
>
> v1.2.4 的 plan 归档在 `PROJECT_PLAN_v1.2.4.md`，本文件**不引用**它的 phase 编号（避免歧义）；本期 phase 重新从 P1 起。

---

## 1. 概述

### 1.1 目标

补齐 v1.2.4 reviewer 报告中 deferred 的 3 项问题，不引入任何新业务能力：

| 编号（reviewer） | 简述 | v1.2.4 状态 | v1.2.5 phase |
| --- | --- | --- | --- |
| #3 | iOS Widget 永远空数据：widget bundle 没有作为 extension target 装上设备 | 代码侧已就绪（`OneHundredJWidgetsBundle.init()` 已调 `useAppGroup`），缺 Xcode target | **P1** |
| #14 | 分页 cursor 用 OFFSET，并发增删可能漏行/重复 | 单测覆盖 + README 标 Known Limitation | **P2** |
| #17 | Alembic 0001 用 `Base.metadata.create_all`，未来 model 漂移会让 fresh install 与 upgrade path 出现 schema diff | CI 加 drift guard 阻止情况恶化 | **P3** |

### 1.2 覆盖范围

- **仅 3 个 deferred 项**，不夹带其他功能或重构。
- 不动 OpenAPI 已有契约（分页 cursor 是黑箱，client 无感知；新增字段或 endpoint = 0）。
- 后端测试基线：86 passed（v1.2.4）→ v1.2.5 目标 ≥ 95（P2 + P3 各加若干）。
- Swift 测试基线：53 passed（v1.2.4）→ 目标 ≥ 55（P1 加 1–2 个 widget 集成 smoke + P2 不动 client）。
- Alembic 迁移基线：6 个（v1.2.4 = `0001..0006`）→ v1.2.5 = 7 个（新增 `0007_keyset_indexes`）。
- 单用户私有云定位不变。

### 1.3 预估周期

| Phase | 内容 | 工作量 | 主要驱动 |
| --- | --- | --- | --- |
| P1 | Widget extension 进 Xcode 工程 | M | owner 手动（GUI） + builder 写测试/文档 |
| P2 | Keyset 分页 | M | builder 全包 |
| P3 | Alembic 0001 重写 | L | builder 全包，但**强制 owner 人工 review** |

单人节奏 **5–7 个工作日**。P3 是关键路径（复杂度 H），可能拉长到 7+。

### 1.4 Release Criteria

下列条件**全部**满足才能打 v1.2.5 tag：

1. 3 个 deferred 项对应代码改动全部合入 `main`，每条都能在 commit message / PR 描述追到。
2. `pytest -q backend/tests` 全绿，含新增 keyset / 0001-baseline 用例。
3. `swift test` 全绿；`xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 通过；含 widget extension target 的 archive 也能跑通（见 §6.1 P1 验收）。
4. `alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连无报错。
5. `python -m scripts.check_alembic_drift` exit 0（v1.2.4 已存在，本期不能破）。
6. 新增 `scripts/check_alembic_0001_baseline.py` exit 0（P3 验收）。
7. `scripts/verify-release.sh` exit 0。
8. `scripts/prod-check.sh` 在 HZ 灰度环境 exit 0。
9. **手测**清单全过（§7.3），尤其 iOS 真机 Widget 安装路径（无法 CI 自动化）。
10. `MARKETING_VERSION = 1.2.5`、`CURRENT_PROJECT_VERSION = 1.127` 三 target 同步（App / Widget Extension / 任何后续 extension）。
11. `backend/pyproject.toml` `version = "1.2.5"`，`backend/app/main.py` 的 FastAPI `version="1.2.5"`，`tests/openapi_snapshot.json` 同步刷新（仅 `info.version` 一行差异）。
12. `deployment.md` 末尾追加 "v1.2.5 Upgrade Notes" 段落。

---

## 2. 依赖图

### 2.1 Phase 全景

```
P1 Widget extension 进 Xcode 工程  (覆盖 #3)
P2 Keyset 分页                      (覆盖 #14)
P3 Alembic 0001 重写                (覆盖 #17)

   三条线**完全独立**，可并行；只在 P4 发布工程汇合。

P4 发布工程 (版本号 + OpenAPI snapshot + deployment.md + prod-check + tag)
```

### 2.2 依赖说明

- P1 ↔ P2 ↔ P3 之间**没有代码依赖**。三个 phase 改动的文件几乎不重合：
  - P1：`frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`、`Resources/*.entitlements`、`Sources/OneHundredJWidgets/*`、widget 集成 smoke test。
  - P2：`backend/app/services/pagination.py`、各 list endpoint service、新增 `backend/alembic/versions/0007_keyset_indexes.py`、复合索引；前端零改动。
  - P3：`backend/alembic/versions/0001_initial_schema.py` 重写、新增 `scripts/check_alembic_0001_baseline.py`、`scripts/check_alembic_drift.py` 增强。
- 唯一隐式约束：P3 要在 P2 的 `0007_keyset_indexes` revision id 之后跑（因为 P3 重写的 0001 baseline 不包含 0007 索引；alembic 链条保持 `0001 → ... → 0006 → 0007` 顺序）。**这只是 revision 链顺序问题，不是代码依赖**。
- P4（发布工程）等三条线都合并后再开。

### 2.3 推荐串行顺序

```
P2 → P3 → P1 → P4
```

理由（不是强制）：

1. **P2 先**：纯后端、无 GUI 操作、风险低，跑一遍快速建立信心。
2. **P3 第二**：纯后端、风险高、需要 owner review。trade off：放在 P2 之后是因为 P3 重写后整套 alembic 链条要重跑回归，与 P2 新增 0007 一起验证更经济。
3. **P1 第三**：唯一需要 Xcode GUI 操作的 phase，单独安排 owner 手动窗口。完成后立刻验证 P2/P3 后端没有被 client 改动碰到。
4. **P4 最后**：纯发布工程。

如果 owner 时间窗口允许，**P1 与 P2 并行**是最高效的（不同 owner 角色，互不阻塞）。

---

## 3. Phase 细则

> 每个 phase 给：覆盖问题号 / 改动文件（精确到文件 + 区域）/ 接口契约（如涉及）/ 测试计划 / 验收标准 / 工作量（S/M/L）/ 风险（低/中/高）/ **builder 可独立完成 vs owner 必须手动**的标注。

---

### Phase P1 — Widget extension 进 Xcode 工程

**覆盖**：reviewer #3（Widget 永远空数据 / 致命）

**工作量**：M｜**风险**：中（Xcode 项目结构改动 + 签名 / provisioning）

**builder 边界**：**部分**。Xcode GUI 操作必须 owner 手动；builder 只能写非 GUI 部分（README 更新、widget 测试 stub、smoke test）。每个 step 下方明确标注 `[owner-only]` 或 `[builder-ok]`。

#### 3.1.1 背景

v1.2.4 已经完成代码侧准备：

- `frontend/apple/Sources/OneHundredJWidgets/OneHundredJWidgets.swift` 中 `OneHundredJWidgetsBundle.init()` 已调用 `WidgetSnapshotStore.useAppGroup("group.top.linotsai.app.PersonalAffairs")`。
- `WidgetSnapshotStore` 已经支持 `useAppGroup(_:)` 切到 App Group `UserDefaults` 容器。
- iOS host app entitlements `frontend/apple/Sources/PersonalAffairsApp/Resources/PersonalAffairsApp.iOS.entitlements` 含 `application-groups = [group.top.linotsai.app.PersonalAffairs]`（v1.2.2 已加）。

**缺的就一件事**：`frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 里只有 1 个 native target（host app），widget 没作为 extension target 被 archive / install。iOS 用户装 v1.2.4 后**根本看不到 widget 可选**。

#### 3.1.2 改动清单

**P1-1 在 Xcode 创建 Widget Extension target** `[owner-only]`

具体步骤（owner 在 Xcode GUI 操作）：

1. 打开 `frontend/apple/PersonalAffairsApp.xcodeproj`。
2. File → New → Target → iOS → Widget Extension。
3. Product name: `OneHundredJWidgets`。
4. Bundle Identifier: `top.linotsai.app.PersonalAffairs.Widgets`（必须以 host app bundle id `top.linotsai.app.PersonalAffairs` 为前缀，否则 App Group 不能共享）。
5. Embed in Application: `PersonalAffairsApp`。
6. Include Configuration Intent: **否**（v1.2.5 不做 configurable widget）。
7. Team: `HX73DFL88G`（与 host app 同）。
8. Code Signing: Automatic。

完成后 Xcode 会自动：
- 在 pbxproj 新增 native target `OneHundredJWidgets`。
- 新增 Embed Foundation Extensions / Embed App Extensions build phase 到 host app target。
- 创建 `frontend/apple/OneHundredJWidgets/Info.plist`（删除：让 widget 用 Build Settings 内嵌的 Info；或保留并把内容收敛到 `NSExtension` 段）。

**接管点**：Xcode 自动生成的 `frontend/apple/OneHundredJWidgets/OneHundredJWidgetsBundle.swift` 等占位文件需要**删掉**，因为真正的实现在 Swift Package `Sources/OneHundredJWidgets/`。

**P1-2 把 Swift Package 的 widget 源文件加进 widget target** `[owner-only]`

在 Xcode：

1. Project Navigator → 右键 OneHundredJWidgets group → Add Files to "PersonalAffairsApp"。
2. 选 `frontend/apple/Sources/OneHundredJWidgets/` 下所有 .swift 文件（`OneHundredJWidgets.swift`、相关 Provider、View、Snapshot store glue 等）。
3. 勾选 Target Membership：**仅** `OneHundredJWidgets`（不勾 host app 也不勾 PersonalAffairsCore）。
4. Reference Type: "Create groups"（默认）。

**关键**：这些文件**同时**必须保留在 Swift Package（`Package.swift` 的 `executableTarget(name: "OneHundredJWidgets")` 段），因为 swift package 路径仍然是 `swift test` 用来跑 widget 相关单测的入口。Xcode 通过文件系统 reference 引用到同一份 .swift 文件，**不复制**。

**P1-3 widget target 依赖 PersonalAffairsCore** `[owner-only]`

widget Swift 源使用 `WidgetSnapshotStore`、`PersonalAffairsCore.Models` 等，必须 link：

1. 选 `OneHundredJWidgets` target → General → Frameworks and Libraries。
2. 点 + → 选 `PersonalAffairsCore`（已存在的 Swift Package product）。
3. Embed: Do Not Embed（PersonalAffairsCore 是 static library；widget extension 不 embed framework）。

如果 Xcode 不识别 PersonalAffairsCore：先在 project root → Package Dependencies 确认本地 Package 已注册（v1.2.4 已注册，应无需改）。

**P1-4 创建 Widget entitlements** `[owner-only + builder 验证]`

1. owner 在 Xcode：File → New → File → iOS → Resource → Property List。文件名 `OneHundredJWidgets.entitlements`，保存到 `frontend/apple/OneHundredJWidgets/`。
2. owner 内容（在 Xcode 切换 Property List 视图或直接编辑 raw XML）：
   ```
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.top.linotsai.app.PersonalAffairs</string>
   </array>
   ```
3. owner Build Settings → Code Signing Entitlements → `OneHundredJWidgets/OneHundredJWidgets.entitlements`（相对路径）。
4. builder 验证：commit 后 `cat frontend/apple/OneHundredJWidgets/OneHundredJWidgets.entitlements` 检查 group id 完全匹配 host app entitlements。

**关键**：bundle id `top.linotsai.app.PersonalAffairs.Widgets` 必须以 host app id 为前缀，App Group `group.top.linotsai.app.PersonalAffairs` 才能跨 process 共享 UserDefaults 容器；否则 widget 进程读不到 host app 写的 snapshot。

**P1-5 Embed Foundation Extensions build phase 验证** `[owner-only + builder 验证]`

Xcode 在 P1-1 自动加这个 build phase；owner 验证：

1. 选 host app target → Build Phases → 确认有 "Embed Foundation Extensions"（或 "Embed App Extensions"）阶段。
2. 阶段内容必须含 `OneHundredJWidgets.appex`。
3. Destination: Plugins and Foundation Extensions。Code Sign On Copy: ✅。

builder 验证：commit 后 `grep -c "OneHundredJWidgets.appex" frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` ≥ 2（一处声明 product file，一处在 embed phase）。

**P1-6 Provisioning profile** `[owner-only，发布前]`

- 开发：Code Signing Style = Automatic，团队 `HX73DFL88G`，Xcode 自动生成 development profile，含 App Group capability。
- 发布：App Store Connect → Identifiers → 新建 App ID `top.linotsai.app.PersonalAffairs.Widgets`，勾选 App Groups → 选 `group.top.linotsai.app.PersonalAffairs`。生成 Distribution profile。

**这一步必须在 archive 上传 TestFlight 前完成**，否则 archive 会因为 widget extension 没有 prod profile 而 fail。

**P1-7 widget 集成 smoke test** `[builder-ok]`

新增 `frontend/apple/Tests/PersonalAffairsCoreTests/WidgetSnapshotIntegrationTests.swift`：

- `test_widgetSnapshotStore_useAppGroup_writes_and_reads_through_group_defaults`：在 sandbox UserDefaults 上模拟 `useAppGroup("group.test.fake")` → `save(snapshot)` → 重新 `useAppGroup("group.test.fake")` → `load()` 拿到相同 snapshot。
- `test_widgetBundle_init_invokes_useAppGroup_with_production_identifier`：构造 `OneHundredJWidgetsBundle()`，断言 `WidgetSnapshotStore.currentGroupIdentifier == "group.top.linotsai.app.PersonalAffairs"`（需在 `WidgetSnapshotStore` 暴露 internal getter）。

如果 `WidgetSnapshotStore` 目前没有 `currentGroupIdentifier` getter，加一行 `internal static private(set) var currentGroupIdentifier: String?`，在 `useAppGroup(_:)` 中赋值即可。**这是测试可观察性需要，非业务字段**。

**P1-8 README / deployment 文档更新** `[builder-ok]`

- `README.md`：在 "iOS Widget 安装" 段（如无则新增）说明 v1.2.5 起 widget 自动作为 host app 的 extension 安装，无需用户额外操作；首次显示数据延迟 ≤ 5 min。
- `deployment.md` v1.2.5 段落（P4 写入）：注明发布 prod build 前必须在 App Store Connect 创建 Widget extension App ID + Distribution profile，否则 archive fail。

#### 3.1.3 接口契约

无后端 API 变更。无客户端 public API 变更。

#### 3.1.4 测试计划

- **CI 自动化**：
  - `swift test` 跑新增 `WidgetSnapshotIntegrationTests`（builder 写）。
  - `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 必须能编译含 widget extension 的完整 archive 候选（v1.2.4 已存在；P1 之后会因为多了 widget target 而自动覆盖）。
  - 新增 verify 步骤：`xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -configuration Release -archivePath /tmp/100j-v125.xcarchive archive` 在 verify-release.sh 内（owner 跑过一次即可，CI 因为签名问题不强制）。
- **手测（owner，无 CI 替代）**：
  - iOS 真机装 v1.2.5 → 长按桌面 → 添加 Widget → 搜索 "100J" → 应能看到 widget 列表（Top 3 / Agenda）。
  - 添加后 5 min 内 widget 显示真实 Top 3 + Agenda（host app 必须先登录拉过一次数据）。
  - macOS 端**不在本期范围**（macOS widget 需独立 target，且 Reviewer #3 仅针对 iOS）。

#### 3.1.5 验收标准

- iOS 真机装 v1.2.5 → 添加 Widget → 5 min 内显示真实 Top 3 / Agenda（reviewer #3 的原始验收）。
- `xcodebuild ... archive` 成功，产出 `.xcarchive` 内含 `OneHundredJWidgets.appex`（用 `find /tmp/100j-v125.xcarchive -name "*.appex"` 验证）。
- pbxproj 中 widget extension target 完整存在；`grep "OneHundredJWidgets.appex" frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 至少 2 处命中。
- widget entitlements 与 host app entitlements 的 App Group 字符串**逐字符**一致。

#### 3.1.6 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| owner 在 Xcode GUI 操作过程意外破坏 pbxproj（build phase 顺序错乱、文件 reference 重复） | 操作前 `git stash` 干净 working tree；操作后 `git diff frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 逐行 review；builder 跑 `xcodebuild build` 立刻验证 |
| Provisioning profile 配错（缺 App Group capability） | 开发用 Automatic（Xcode 自动加 capability）；发布前 App Store Connect 的 App ID 必须明确勾 App Groups 才能生成 prod profile，否则 archive 直接报错 |
| widget Swift 源同时归属 Swift Package + Xcode widget target 引起重复编译 | 文件 reference 使用 "Create groups"（不勾 host app target），Xcode 只编译给 widget target；Swift Package 仍独立编译给 `swift test` 用 |
| 旧 iOS 用户从 v1.2.4 升 v1.2.5：widget 新装但 host app 还没把 snapshot 写到 App Group 容器 | host app 在 v1.2.2 起已经把 snapshot 写到 App Group；升 v1.2.5 后第一次 app 启动 + 任意刷新即写入；用户在添加 widget 后 5 min 内见到数据 |

---

### Phase P2 — Keyset 分页

**覆盖**：reviewer #14（分页 OFFSET cursor 在并发增删下漏行/重复）

**工作量**：M｜**风险**：低（单用户 0 并发，无回归风险；仅是把"将来可能漏行"修干净）

**builder 边界**：**完全可独立完成**。无 GUI、无 client 改动。

#### 3.2.1 背景

`backend/app/services/pagination.py` 现状：

- `paginate(query, limit, cursor)` 用 `OFFSET` 思路：cursor 编码 `str(offset + safe_limit)`，下一页用新 offset 继续切。
- 并发漏行 / 重复 case：list 第一页拿前 50 条 → 用户删/插入 → list 第二页（offset=50）会跳过新插入的行 / 重复返回滑下来的行。
- v1.2.4 已经加了 `paginate` 单元测试（"limit=1 翻页 3 次拿到 3 条不同行"）和 README "Known Limitations" 段。

单用户私有云实际并发 = 0，但任何 list endpoint 在长翻页过程中有客户端增删（前端 `fetchAll` 循环式拉所有页）会触发。

#### 3.2.2 改动清单

**P2-1 `paginate()` 改 keyset 实现**

文件：`backend/app/services/pagination.py`

新签名（与现有签名兼容，cursor 类型仍是 `str`）：

```
def paginate(
    query: Select,
    *,
    limit: int,
    cursor: Optional[str],
    order_columns: tuple[Column, Column] | None = None,
) -> PaginationResult:
    ...
```

- `order_columns` 默认 `(updated_at, id)`，但 agent_action_log 例外（见 P2-3）。
- cursor 编码：`base64(json({"u": "<iso8601 utc>", "i": "<uuid>"}))`，且必须能 round-trip。
- 解码失败（base64 错 / json 错 / 缺字段 / 时间格式错）→ `AppError(400, "invalid_cursor", "Cursor format invalid.")`。这是新错误码，但 client 不会主动构造 cursor，所以实际触发面是 0。
- query 拼接：`.where(tuple_(updated_at, id) < tuple_(cursor.u, cursor.i)).order_by(updated_at.desc(), id.desc()).limit(limit + 1)`。
- 用 `limit + 1` 探测是否还有下一页：拿到 `limit + 1` 行 → 截前 `limit` 行返回，构造 next_cursor = 第 `limit` 行的 `(updated_at, id)`；拿到 ≤ limit 行 → next_cursor = None。

**保持向后兼容**：旧 cursor 格式（纯数字字符串 "50"）→ decode 时 fallback 走老 OFFSET 路径（一次性，**仅本 release**），下一页 cursor 改成 keyset 格式。这是给已经在飞行中的 client 请求一个 grace 路径。

> **决策点**：是否需要这层兼容？单用户私有云没有"飞行中请求"概念；client 不会持久化 cursor。**决定**：不加 fallback，旧 cursor 直接 400。理由：复杂度低、行为干净；client 重新发请求即拿到新格式。在 §6.2 P4 deployment notes 中提示 "升 v1.2.5 后 client 任何持有旧 cursor 的内存状态都 invalidate，但实际无影响"。

**P2-2 各 list endpoint 接入新 paginate**

涉及的 endpoint（grep `paginate(` 找全）：

| Endpoint | Router 文件 | Service 文件 | Model | order_columns |
| --- | --- | --- | --- | --- |
| `GET /api/v1/tasks` | `backend/app/api/v1/tasks.py` | `backend/app/services/task_service.py` | `Task` | `(updated_at, id)` |
| `GET /api/v1/projects` | `backend/app/api/v1/projects.py` | `backend/app/services/project_service.py` | `Project` | `(updated_at, id)` |
| `GET /api/v1/notes` | `backend/app/api/v1/notes.py` | `backend/app/services/note_service.py` | `Note` | `(updated_at, id)` |
| `GET /api/v1/calendar-items` | `backend/app/api/v1/calendar.py` | `backend/app/services/calendar_service.py` | `CalendarItem` | `(updated_at, id)` |
| `GET /api/v1/agent/logs`（或 actions） | `backend/app/api/v1/agent.py` | `backend/app/services/agent_service.py` | `AgentActionLog` | `(created_at, id)` ← **注意不同** |
| `GET /api/v1/spaces` | `backend/app/api/v1/spaces.py` | `backend/app/services/space_service.py` | `Space` | `(updated_at, id)` |

每个 service 的 list 函数（如 `list_tasks(db, user_id, *, limit, cursor)`）：

1. 在构造 query 时加 `.order_by(Model.updated_at.desc(), Model.id.desc())`（或 `created_at` for agent_action_log）。
2. 把 query 传给 `paginate(query, limit=limit, cursor=cursor, order_columns=(Model.updated_at, Model.id))`。
3. 返回 `PaginationResult` 不变（结构里有 items + next_cursor）。

router 层不需要改：cursor 是 string 黑箱直接透传给 service。

**P2-3 agent_action_log 用 created_at**

`AgentActionLog` 模型只有 `created_at`，没有 `updated_at`（这是 immutable log）。order 必须用 `(created_at, id)`。

`backend/app/models/agent_action_log.py` 应该已存在 `created_at`；如果没有 `id` 字段（用 UUID 主键 `id` 是标配），需在 P2-2 接入时确认。**如果 model 缺 `id` 列**，stop and ask owner——本期不应该改 model schema。

**P2-4 复合索引迁移 `0007_keyset_indexes`**

新文件：`backend/alembic/versions/0007_keyset_indexes.py`

- revision id: `0007_keyset_indexes`
- down_revision: `0006_refresh_token_jti`
- upgrade：
  ```
  op.create_index("ix_tasks_user_updated_id", "tasks", ["user_id", "updated_at", "id"])
  op.create_index("ix_projects_user_updated_id", "projects", ["user_id", "updated_at", "id"])
  op.create_index("ix_notes_user_updated_id", "notes", ["user_id", "updated_at", "id"])
  op.create_index("ix_calendar_items_user_updated_id", "calendar_items", ["user_id", "updated_at", "id"])
  op.create_index("ix_spaces_user_updated_id", "spaces", ["user_id", "updated_at", "id"])
  op.create_index("ix_agent_action_logs_user_created_id", "agent_action_logs", ["user_id", "created_at", "id"])
  ```
  注意 agent_action_log 用 `created_at`。
- downgrade：6 个 `op.drop_index(...)`。
- 必须保持完全 reversible。

**索引命名约定**：`ix_<table>_user_<order_col>_id`，统一格式便于 grep 与 drift guard 识别。

**P2-5 模型层声明索引（与迁移同步）**

文件：各 model 文件（`backend/app/models/task.py` 等）

- 在 model 的 `__table_args__` 加：
  ```
  __table_args__ = (
      Index("ix_tasks_user_updated_id", "user_id", "updated_at", "id"),
      ...其他已存在的 __table_args__...
  )
  ```
- 这一步**必须做**，否则 `check_alembic_drift.py`（v1.2.4 已存在）会因为 metadata 与 db schema 不一致而 fail（"db has index but metadata doesn't"）。
- 已存在的 `__table_args__`（如 unique constraints）保留，只追加 Index。

#### 3.2.3 接口契约

**修改：所有 list endpoint 的 cursor 内部格式**（client 不感知）

| 项 | v1.2.4 | v1.2.5 |
| --- | --- | --- |
| cursor 编码 | `str(offset + limit)` 纯数字 | `base64(json({"u": iso8601, "i": uuid}))` |
| 行为 | OFFSET-based，并发增删可能漏/重 | keyset，按 `(updated_at, id) DESC` 单调，并发增删保证不漏不重 |
| 响应结构 | `{items, next_cursor, ...}` | 不变 |
| 新错误码 | — | `400 invalid_cursor` `Cursor format invalid.`（仅当 client 手工构造 cursor 时触发；正常 client 不会） |

OpenAPI 文档没有 cursor 字段的 schema（cursor 是 string），所以**没有 schema 变化**；snapshot 不会因 P2 改变。

#### 3.2.4 Alembic 迁移

| Revision | 文件 | 操作 |
| --- | --- | --- |
| `0007_keyset_indexes` | `backend/alembic/versions/0007_keyset_indexes.py` | 6 个复合索引；downgrade 6 个 drop_index |

回滚要求：`alembic upgrade head && alembic downgrade -1 && alembic upgrade head` 三连无报错。

#### 3.2.5 测试计划

- 新增 `backend/tests/test_pagination_keyset.py`：
  - `test_paginate_returns_distinct_rows_across_pages_with_concurrent_insert`：第一页拿 limit=2 → 在两页之间 insert 新行（updated_at 最大）→ 第二页不重复返回第一页任何行；漏行可允许（新插入的行落在"过去 cursor"之后是预期，user 下次刷新会看到）。
  - `test_paginate_returns_distinct_rows_with_concurrent_delete`：第一页拿 limit=2 → 删第二页第一行 → 第二页应该取到原本的第二页第二行（即"如果原 page2 = [A, B]，删 A，新 page2 = [B]"），没有漏。
  - `test_paginate_invalid_cursor_returns_400`：cursor = "not-base64-!@#" → 400。
  - `test_paginate_cursor_round_trip`：拿 next_cursor → 用同样 cursor 再请求一次，应该拿到同样的 next 一页（幂等）。
  - `test_paginate_handles_ties_via_id_tiebreaker`：两行 `updated_at` 相同 → id 大的先返回；翻页用 id 做 tiebreaker，不重复。
- 新增 `backend/tests/test_keyset_indexes_used.py`：
  - 在 PostgreSQL 上跑 `EXPLAIN (FORMAT JSON) SELECT ... ORDER BY updated_at DESC, id DESC LIMIT 50` → 断言 plan 节点用了 `ix_<table>_user_updated_id`。SQLite 不支持等价语义 → 用 `pytest.mark.skipif` 跳过 sqlite。
  - 覆盖 6 张表全部。
- 已有的 `paginate` 单测（v1.2.4 增）保留，行为不变；如果在 OFFSET cursor 上断言 cursor format，那条断言改为新格式。
- Alembic 回滚测试：`tests/test_alembic_drift.py` 已自动覆盖。新增 `tests/test_alembic_0007_reversible.py`：`upgrade → downgrade → upgrade` 三连，无 schema diff。

#### 3.2.6 验收标准

- `pytest -q -k "pagination or keyset or alembic"` 全绿。
- `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` 无报错。
- 灰度环境跑 `EXPLAIN` 验证 6 张表都用了新复合索引（owner 在 HZ 灰度跑一次 `psql` 命令）。
- `python -m scripts.check_alembic_drift` exit 0（新索引在 metadata 也声明了）。

#### 3.2.7 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| 6 张表多复合索引，写入时索引维护开销 | 单用户私有云写入 QPS < 1，影响微观可忽略；prod 监控 `pg_stat_user_indexes` 验证 idx_scan 上升、idx_tup_fetch 比 seq_scan 显著优 |
| cursor 格式变化导致 client 缓存的旧 cursor 失效 | client 不持久化 cursor（仅在循环内传递）；新一次 list 调用从 cursor=None 开始，无影响 |
| keyset 在 `updated_at` 一秒内被多次 update 的同行场景下 ordering 不稳定 | 单用户写入间隔远大于 1 秒；id tiebreaker 保证 deterministic 顺序 |
| 0007 在生产已经跑了，需要回滚 | `alembic downgrade -1` 把 6 个索引 drop 干净，service 层 fallback 到无索引也能跑（seq_scan，单用户 < 几千行可接受） |

---

### Phase P3 — Alembic 0001 重写为显式 schema

**覆盖**：reviewer #17（0001 用 `Base.metadata.create_all`，未来 fresh install 与 upgrade path schema 漂移）

**工作量**：L｜**风险**：高（动 alembic 历史链 + 必须 byte-equivalent；高度依赖人工 review）

**builder 边界**：**完全可独立完成**，但**强制 owner 人工 review 重写后的 0001**，且 owner 必须本地跑回归对比 schema hash 后才能 merge。

#### 3.3.1 背景

`backend/alembic/versions/0001_initial_schema.py` 当前实现：

```
def upgrade() -> None:
    Base.metadata.create_all(op.get_bind())

def downgrade() -> None:
    Base.metadata.drop_all(op.get_bind())
```

问题：`Base.metadata` 在每次 release 都跟随当前 model 演化；fresh install 跑 0001 拿到的是"今天的 schema"，跟"从 v1.0 跑 0001 → 跑 0002 → ... → 跑 0006 升上来"的 schema **理论上**可能有 diff。

v1.2.4 已经加了 `scripts/check_alembic_drift.py`，每次 CI 跑：

1. fresh sqlite → `alembic upgrade head` → inspect 拿到 schema A。
2. 把 `Base.metadata` reflect 拿到 schema B。
3. 比对 A vs B，有 diff 即 fail。

这只能阻止"继续漂移"，**不能修复"已经漂移"**——因为 A 就是按当前 metadata 跑出来的，与 B 永远一致。

#### 3.3.2 改动清单

**P3-1 推断 v1.0 时代的 schema**

无法用 `git show <v1.0-tag>:backend/alembic/versions/0001_*.py` 拿到原始定义（v1.0 的 0001 就是 `create_all`）。必须人工推断：

1. 阅读 0002 / 0003 / 0004 / 0005 / 0006 全部迁移文件，记录每张表"在 0001 之后被加了什么列/索引"。
2. 反向得到 0001 应该有的表 + 列。

候选表 + 列推断方法：

| 表 | 来源 | 推断方式 |
| --- | --- | --- |
| `users` | 0001 (v1.0) | reflect 当前 model `User` → 减去 0003 加的 v1.1 auth 字段（如有） |
| `spaces` | 0001 | reflect Space → 减去 0004 加的 seed_demo_source 字段 |
| `tasks`, `projects`, `notes`, `calendar_items` | 0001 | reflect 各 model → 减去任何后续 migration 加的列 |
| `agent_action_logs` | 0001 | reflect → 减去 0002 之后的列 |
| `agent_pending_confirmations` | 0002 加 | **不在 0001**，0001 不创建 |
| `device_sessions` | 0005 加 | **不在 0001** |
| `refresh_token_jti` | 0006 加 | **不在 0001** |
| `email_otp_codes` | 0003 加（推测，需 verify） | **大概率不在 0001**，确认后写 |
| `device_tokens` | 不确定 | 必须 verify |
| `llm_provider_keys` | 不确定 | 必须 verify |

**关键步骤**：在干净 sqlite 上分别跑 `alembic upgrade 0001`、`upgrade 0002`、... `upgrade 0006`，每步 dump schema（`sqlite3 db ".schema"`），diff 相邻两个 dump，精确记录每个 revision 引入的列/表/索引。这是 P3 最耗时的工作（预计 4–6 小时）。

输出：一份内部文档（不 commit，写在 PR description）"v1.0 schema 推断表格"，列出每张表 + 每列的类型 / nullable / default / server_default。

**P3-2 重写 `0001_initial_schema.py`**

文件：`backend/alembic/versions/0001_initial_schema.py`

- **保持 revision id 不变**：`revision = "0001_initial_schema"`，`down_revision = None`。
- upgrade 重写为显式 `op.create_table(...)`，所有列写死 v1.0 时代的字段：

```
def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        # ...v1.0 时代的其他字段，按 P3-1 推断结果
    )
    op.create_table("spaces", ...)
    # ...其余 v1.0 表
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    # ...v1.0 时代的所有索引
```

- downgrade 改为显式 `op.drop_table(...)`，反向顺序（先 drop 有 FK 依赖的子表）。
- 不引用 `Base.metadata`，整个文件**零 ORM 依赖**（除了 sa 类型）。

**关键约束**：重写后的 0001 + 0002 + ... + 0006 + 0007 链条跑完，必须与当前 `Base.metadata` reflect 出的 schema **逐字段等价**。否则 v1.2.4 已有的 `check_alembic_drift` 立刻 fail。

**P3-3 加 baseline 验证 script**

新文件：`backend/scripts/check_alembic_0001_baseline.py`

- 行为：
  1. 内存 sqlite → `alembic upgrade 0001`（仅跑 0001，停在 v1.0 schema）。
  2. inspect schema 拿到 table + column + index 全集。
  3. 与硬编码的"v1.0 期望 schema" 字典逐项比对（字典内容来自 P3-1 推断结果，写在 script 顶部）。
  4. 任意 mismatch（多/少表、多/少列、类型不一致、索引不一致）→ `sys.exit(1)` 并打印 diff。
- 接入：
  - `scripts/verify-release.sh` 末尾追加 `python -m scripts.check_alembic_0001_baseline`。
  - 新增 `backend/tests/test_alembic_0001_baseline.py` 调用 main 函数，断言 exit code = 0。

**为什么需要这个 script**：v1.2.4 的 `check_alembic_drift` 只验证 head 与 metadata 一致；P3 重写后必须额外验证 0001 单独跑完的结果与 v1.0 schema 一致——否则别人可能后续无意中又改回 `create_all` 而 head check 仍绿。

**P3-4 增强 `check_alembic_drift.py`**

文件：`backend/scripts/check_alembic_drift.py`（v1.2.4 已有）

- 在已有逻辑后追加：跑完 `alembic upgrade head` 后，记录每张表 + 每个索引的 SHA256 hash（DDL 字符串 hash），写到 `backend/tests/__schema_hash__.txt`（git tracked）。
- CI 在脚本里跑 `git diff --exit-code backend/tests/__schema_hash__.txt`，如果与 git 版本不一致 → fail。这相当于把"schema 长什么样"作为审计点钉死，任何 model 改动必须同步刷新 hash 文件。
- v1.2.5 release 前 owner 跑一次脚本生成基线 hash 并 commit。

**这是 P3 的"持久化护栏"**——即使有人重新搞坏 0001，hash 文件也能 catch。

**P3-5 双路径等价验证**

builder 在 PR description 中**手动**提供以下证据（owner review 必看）：

1. **Path A**（fresh install）：
   ```
   alembic upgrade head
   sqlite3 dbA.sqlite ".schema" | sort > /tmp/path_a.sql
   ```
2. **Path B**（按现网升级）：在 v1.2.4 的 commit 上跑：
   ```
   git checkout v1.2.4
   alembic upgrade head    # = 0001(老 create_all) + 0002..0006
   sqlite3 dbB.sqlite ".schema" | sort > /tmp/path_b.sql
   git checkout main
   ```
3. **Path C**（重写后 + 完整链）：
   ```
   alembic upgrade head    # = 0001(新 explicit) + 0002..0006 + 0007
   sqlite3 dbC.sqlite ".schema" | sort > /tmp/path_c.sql
   ```
4. `diff /tmp/path_a.sql /tmp/path_b.sql` 必须**仅有 0007 索引差异**（path A/C 有，path B 无）。
5. `diff /tmp/path_a.sql /tmp/path_c.sql` 必须**完全相同**。

PR description 贴这 4 个文件的 hash + diff 结果。owner 在本地复现一遍，确认后才 merge。

#### 3.3.3 接口契约

无 API 变更。无 schema 变更（重写的目标是 byte-equivalent，新行为是 fresh install 走显式路径）。

#### 3.3.4 Alembic 迁移

| Revision | 文件 | 操作 |
| --- | --- | --- |
| `0001_initial_schema` | `backend/alembic/versions/0001_initial_schema.py` | **重写**：从 `Base.metadata.create_all` 改成显式 `op.create_table` × N |

**不新增 revision**。revision id 不变。

**对现有部署的影响**：

- HZ 云生产库的 `alembic_version` 表已经记录 `0001_initial_schema`（在 v1.0 时被打入），现有部署**不会重跑 0001**，所以重写对生产零影响。
- 任何新 fresh install（开发机、CI、未来灾难恢复）都会跑新版 0001。
- 灾难恢复场景：备份恢复 + alembic upgrade 路径，跑新 0001 拿到 v1.0 schema，继续 0002..0007 升到 head；与生产现状最终一致（P3-5 已 verify）。

#### 3.3.5 测试计划

- 新增 `backend/tests/test_alembic_0001_baseline.py`：调用 `check_alembic_0001_baseline.main()`，断言 exit code = 0。
- 已有 `tests/test_alembic_drift.py` 必须仍然绿（v1.2.4 加的）。
- 新增 `backend/tests/test_alembic_0001_downgrade.py`：`alembic upgrade 0001 && alembic downgrade base` 必须把所有 v1.0 表 drop 干净（inspect 拿不到任何表）。
- 完整链回归：`alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连，每一步无报错；最终 schema 与 reset 前等价。
- `pytest -q backend/tests` 全部 86+ 用例必须仍然绿（重写 0001 是 invisible change）。

#### 3.3.6 验收标准

- `scripts/check_alembic_0001_baseline.py` exit 0。
- `scripts/check_alembic_drift.py` exit 0。
- `tests/__schema_hash__.txt` 与 v1.2.4 reset 后的 hash 对比，只允许"新增 0007 索引行"差异（P2 引入的）。
- P3-5 的三路径 diff 验证 owner 本地复现通过，PR description 贴出 hash 证据。
- `alembic upgrade head && alembic downgrade base && alembic upgrade head` × 3 次循环全无报错。

#### 3.3.7 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| 推断的 v1.0 schema 与真实 v1.0 schema 有微小差异（漏列、类型差异），未来灾难恢复时报错 | P3-5 的三路径 diff 验证；owner 必须本地复现；hash 文件钉死作为长期回归护栏 |
| 重写后某列 server_default 与原始 create_all 出来的不一致（如 `created_at` 默认值） | model `__table_args__` 与新 0001 同步 review；`check_alembic_drift` 会捕获这种 mismatch |
| 现网部署的 alembic_version 记录的是 `0001_initial_schema`，重写不影响现网；但如果有人手动 `alembic stamp head` 之后 downgrade 到 0001 会跑新 downgrade（drop 所有表）→ 数据丢失 | 在脚本 deployment.md 警告"v1.2.5 起 alembic downgrade 0001 会清表，禁止在 prod 库执行"；deploy-hz.sh 不暴露 downgrade 入口 |
| P3 与 P2 同时 merge：0001 重写 + 0007 新增，回滚复杂 | 推荐串行（P2 先 merge → 跑一次完整回归 → P3 再 merge）；不要在同一 PR 同时改 |

---

### Phase P4 — 发布工程

**覆盖**：版本号 + OpenAPI snapshot + deployment.md + prod-check + verify-release + tag。**仅在 P1/P2/P3 全部 merge 后开始。**

**工作量**：S｜**风险**：低（纯发布机械动作）

**builder 边界**：**完全可独立完成**。

#### 3.4.1 改动清单

**P4-1 版本号**

- `frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`：
  - 现有 App target 的 `MARKETING_VERSION = 1.2.4` → `1.2.5`（Debug + Release 各 1 处 = 2 处）。
  - 现有 App target 的 `CURRENT_PROJECT_VERSION = 1.126` → `1.127`（2 处）。
  - **新增** Widget extension target 的 `MARKETING_VERSION` 也是 `1.2.5`，`CURRENT_PROJECT_VERSION` 也是 `1.127`（2 处 Debug + 2 处 Release = 4 处）。**与 host app 同步是 App Store 必需**，否则上传 archive 报 "extension version mismatch"。
- `backend/pyproject.toml`：`version = "1.2.4"` → `version = "1.2.5"`。
- `backend/app/main.py`：`FastAPI(..., version="1.2.4")` → `version="1.2.5"`。

**P4-2 OpenAPI snapshot 刷新**

- `backend/tests/openapi_snapshot.json`：仅 `info.version` 一行变化 `"1.2.4"` → `"1.2.5"`。
- 刷新命令（同 v1.2.4 P7-2 风格，inline）：
  ```
  python -c "import json; from app.main import app; print(json.dumps(app.openapi(), indent=2))" > backend/tests/openapi_snapshot.json
  ```
- 提交时 diff review 确认仅 1 行变化；如果 P2 / P3 期间不小心动了 schema（不应发生），diff 会暴露。

**P4-3 deployment.md 增 v1.2.5 段落**

- 末尾追加 `## v1.2.5 Upgrade Notes`：
  1. **iOS Widget**：v1.2.5 起 iOS 安装包内含 widget extension；首次安装/升级后，用户长按桌面 → 添加 widget → 等 ≤ 5 min 显示数据。无需后端动作。
  2. **后端**：`alembic upgrade head` 会执行 `0007_keyset_indexes`（6 个复合索引，单用户库执行 < 1 s）。
  3. **数据库**：v1.2.5 起 `alembic downgrade 0001` 会清空所有 v1.0 表（重写后 explicit drop）。**禁止在 prod 库执行**。
  4. **回滚**：见 §7 "回滚预案"。
  5. **App Store**：发布 prod build 前需在 App Store Connect 创建 Widget extension 的 App ID `top.linotsai.app.PersonalAffairs.Widgets`（capabilities 勾 App Groups → `group.top.linotsai.app.PersonalAffairs`），生成 Distribution profile。

**P4-4 prod-check.sh 增项**

- `scripts/prod-check.sh` 末尾追加 "Pagination cursor (v1.2.5)" 段：
  - `curl -s "$API_BASE/tasks?limit=1" -H "Authorization: Bearer $TOKEN" | jq '.next_cursor'` 拿到 cursor。
  - `echo "$CURSOR" | base64 -d | jq -e '.u and .i'` 验证 cursor 是新格式（包含 `u` 和 `i` 字段）；exit 1 if false。
- 不动 v1.2.4 已有的 register 404 / device-logout 401 / forwarded-IP 健康检查。

**P4-5 verify-release.sh 增项**

- `scripts/verify-release.sh`：
  - 追加 `python -m scripts.check_alembic_0001_baseline`。
  - `tests/__schema_hash__.txt` 的 git diff exit-code 检查（在 `check_alembic_drift.py` 内部已含；这里只是确认 verify 流程会调到）。

**P4-6 tag & merge**

- `git tag v1.2.5`。
- 跑 §7.1 / §7.2 / §7.3 全部清单。
- `git push origin main --tags`。

#### 3.4.2 验收标准

- `scripts/verify-release.sh` exit 0。
- `scripts/prod-check.sh` 在 HZ 灰度 exit 0。
- §7.3 手测全过。
- iOS TestFlight build 1.127 上传 App Store Connect 成功，含 widget extension。

---

## 4. 跨 phase 公共改动汇总

| 主题 | 涉及文件 | 涉及 phase |
| --- | --- | --- |
| Xcode 项目结构（widget target） | `frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`、`frontend/apple/OneHundredJWidgets/*` | P1, P4 |
| `paginate()` 实现 | `backend/app/services/pagination.py` | P2 |
| list endpoint service order by | `backend/app/services/{task,project,note,calendar,agent,space}_service.py` | P2 |
| Alembic 新版本 0007 | `backend/alembic/versions/0007_keyset_indexes.py`、各 model `__table_args__` | P2 |
| Alembic 0001 重写 | `backend/alembic/versions/0001_initial_schema.py` | P3 |
| Drift / baseline 守卫 | `backend/scripts/check_alembic_drift.py`、`backend/scripts/check_alembic_0001_baseline.py`、`backend/tests/__schema_hash__.txt` | P3 |
| 版本号 | pbxproj × 4 个 build setting block、`pyproject.toml`、`main.py` | P4 |
| `deployment.md` | `deployment.md` | P4 |
| `verify-release.sh` / `prod-check.sh` | `scripts/*.sh` | P4 |

---

## 5. 测试新增汇总

| Phase | 文件 | 测试 |
| --- | --- | --- |
| P1 | `frontend/apple/Tests/PersonalAffairsCoreTests/WidgetSnapshotIntegrationTests.swift` | `test_widgetSnapshotStore_useAppGroup_writes_and_reads_through_group_defaults`、`test_widgetBundle_init_invokes_useAppGroup_with_production_identifier` |
| P1 | （手测，无 CI 替代） | iOS 真机添加 widget → 5 min 内显示 Top 3 / Agenda |
| P2 | `backend/tests/test_pagination_keyset.py` | concurrent insert / delete / invalid cursor / round trip / id tiebreaker，共 5 条 |
| P2 | `backend/tests/test_keyset_indexes_used.py` | 6 张表 EXPLAIN 用 ix 索引（PostgreSQL only） |
| P2 | `backend/tests/test_alembic_0007_reversible.py` | upgrade→downgrade→upgrade 三连 |
| P3 | `backend/tests/test_alembic_0001_baseline.py` | 跑 check_alembic_0001_baseline.main()，断言 exit 0 |
| P3 | `backend/tests/test_alembic_0001_downgrade.py` | upgrade 0001 → downgrade base → 无残留表 |

后端测试总数预估：86（v1.2.4 基线）+ 5 (P2 keyset) + 6 (P2 EXPLAIN, postgresql) + 1 (P2 0007 reversible) + 1 (P3 baseline) + 1 (P3 0001 downgrade) ≈ **100**。CI 跑 sqlite 时 EXPLAIN 测试 skip，实际 ≈ 94。

Swift 测试总数预估：53 (v1.2.4 基线) + 2 (P1 widget) = **55**。

---

## 6. 发布检查清单

### 6.1 自动化（CI 必过）

- [ ] `pytest -q backend/tests` 全绿（≥ 94 passed）
- [ ] `python -m scripts.check_alembic_drift` exit 0
- [ ] `python -m scripts.check_alembic_0001_baseline` exit 0
- [ ] `git diff --exit-code backend/tests/__schema_hash__.txt`（无 uncommitted hash 变化）
- [ ] `alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连无报错
- [ ] `alembic upgrade head && alembic downgrade -1 && alembic upgrade head`（验 0007 reversible）
- [ ] `swift test` 全绿（≥ 55 passed）
- [ ] `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 通过
- [ ] `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' archive` 成功且含 `OneHundredJWidgets.appex`
- [ ] `scripts/verify-release.sh` exit 0
- [ ] `backend/tests/openapi_snapshot.json` 仅 `info.version` 一行差异

### 6.2 灰度（HZ 云）

- [ ] `scripts/deploy-hz.sh` 部署到灰度机
- [ ] 灰度机执行 `alembic upgrade head` 成功（< 5 s）
- [ ] `scripts/prod-check.sh` 全绿（含 cursor 格式校验）
- [ ] `journalctl -u 100j-api -n 200` 无 ERROR
- [ ] `psql -c "SELECT indexname FROM pg_indexes WHERE indexname LIKE 'ix_%_user_%_id';"` 6 行命中
- [ ] `psql -c "EXPLAIN SELECT * FROM tasks WHERE user_id='<owner>' ORDER BY updated_at DESC, id DESC LIMIT 10"` plan 中含 `ix_tasks_user_updated_id`

### 6.3 手测（owner 亲测）

- [ ] **iOS 真机 v1.2.5**：升级后桌面长按 → 添加 widget → 搜索 "100J" → 添加 Top 3 + Agenda → 等 5 min → 显示真实数据（**P1 验收 = reviewer #3 主验收**）
- [ ] iOS：注销重登 → widget 数据更新到新登录账号视角
- [ ] macOS：list tasks 翻页（开发者菜单或代码调试）→ 三页都无重复行
- [ ] HZ 灰度：手动 `INSERT INTO tasks` 模拟"翻页中插入新行"→ 翻页结果不重复
- [ ] HZ 灰度：跑 `EXPLAIN` 验证 6 张表全部用了新索引
- [ ] P3：owner 本地按 §3.3.2 P3-5 的方法跑三路径 diff，确认 `path_a.sql == path_c.sql`

### 6.4 版本号

- [ ] `MARKETING_VERSION = 1.2.5`（App + Widget × Debug/Release = 4 处）
- [ ] `CURRENT_PROJECT_VERSION = 1.127`（同上 4 处）
- [ ] `backend/pyproject.toml` version = `1.2.5`
- [ ] `backend/app/main.py` FastAPI version = `1.2.5`
- [ ] `backend/tests/openapi_snapshot.json` info.version = `1.2.5`
- [ ] `git tag v1.2.5` + push

---

## 7. 回滚预案

按"改动可逆性"分等级。

### 7.1 服务端（最高优先级）

**触发条件**：API 出现新 5xx、list endpoint 行为异常、`pg_stat_activity` 出现长事务。

**回滚步骤**：

1. `ssh hz "cd /opt/100j/backend && git checkout v1.2.4 && systemctl restart 100j-api"`。
2. **回滚 0007 索引**：`alembic downgrade -1` 把 6 个复合索引 drop。索引 drop 是元数据操作，单用户库 < 1 s，无锁竞争。回滚后 list endpoint 走 seq_scan，单用户数据量 < 几千行可接受。
3. **不能回滚 0001 重写**：0001 的 alembic_version 标记从未变（仍是 `0001_initial_schema`），v1.2.4 的 0001 老代码（`create_all`）跑在 v1.2.4 的 model 上结果与重写一致；现网零影响。如果是 fresh install 场景灾难恢复，v1.2.4 的 0001 跑出来的 schema 是"v1.2.4 时代 model"，与 v1.2.5 的 0001 跑出"v1.0 时代 schema" 不同——但灾难恢复路径会继续跑 0002..0006 升到 head，**最终 schema 都一样**。所以 0001 重写**不需要回滚动作**。

**演练要求**：

- 发布前在 `hz-db-restore-rehearsal.sh`（如有）跑一次"v1.2.4 → 升 v1.2.5 → 回滚 v1.2.4"全流程。
- `alembic_version` 表内容前后必须保持指向最高已 apply revision。

### 7.2 客户端

**iOS Widget**（P1）：

- 回滚 = 用户在 App Store 装 v1.2.4 IPA（或 TestFlight 切回 build 1.126）。
- v1.2.4 不含 widget extension，TestFlight 降级后 widget 自动从桌面消失（iOS 系统行为）。
- App Group 容器里的 snapshot 数据保留（v1.2.4 host app 仍写）；下次升回 v1.2.5 widget 立刻读到。
- **应急保留**：v1.2.5 上 App Store 后 v1.2.4 IPA 至少保留 14 天。

**前端代码（PersonalAffairsCore）**：

- P2 / P3 不动客户端代码；P1 仅动 widget extension 与 pbxproj。
- 回滚 = `git revert` 对应 commit，rebuild。

### 7.3 部署脚本

- `verify-release.sh` 新增的 baseline check：可通过 `RUN_ALEMBIC_BASELINE=0` env 临时跳过。
- `prod-check.sh` 新增的 cursor 格式校验：cursor 格式不变是 v1.2.5 后端的契约；如果误报可临时 comment-out 这段检查，不阻塞 release。

### 7.4 灾难恢复路径

最坏情况：HZ 云生产库损坏，需从备份恢复 + 升级到 v1.2.5。

新路径：

1. `pg_restore` 从最新备份。
2. `alembic current` 检查 revision（应该是备份时的 head，通常是 v1.2.4 的 `0006_refresh_token_jti`）。
3. `alembic upgrade head` 跑到 `0007_keyset_indexes`。
4. 验证 schema = `python -m scripts.check_alembic_drift && python -m scripts.check_alembic_0001_baseline`。
5. 重启 service。

如果备份是更老版本（如 v1.0），fresh install 路径用新 0001：

1. `alembic upgrade head` 从 `base` 跑全链：新 0001（v1.0 schema）→ 0002..0007（升到 v1.2.5 head）。
2. 终态 schema 与上面 path 一致（P3-5 已验证）。
3. 数据恢复需另外的 `pg_restore --data-only` 处理。

---

## 8. Builder 执行顺序建议

1. 开新分支 `v1.2.5-dev` from `main`（HEAD `8987b8d`，tag `v1.2.4`）。
2. **P2 先开**：纯后端、低风险、快速建信心。每个 commit 聚焦单个 endpoint 接入新 paginate，最后一个 commit 加 0007 migration + model `__table_args__`。
3. **P3 第二**：建议拆 PR：
   - PR1：P3-1 推断 + P3-2 重写 0001 + P3-3 baseline check。
   - PR2：P3-4 drift guard 增强 + hash 文件。
   - owner 必须在 PR1 merge 前本地复现 P3-5 三路径 diff。
4. **P1 第三**：owner 在 Xcode GUI 做 P1-1 ~ P1-6（一次完成，提一个 commit 含 pbxproj + entitlements + Info.plist）；builder 后续提 P1-7 测试 + P1-8 文档。
5. **P4 最后**：单独一个 PR，含版本号 + OpenAPI snapshot + deployment.md + verify-release.sh + prod-check.sh 增项。
6. 跑 §6.1 / §6.2 / §6.3 全部清单，全绿后 `git tag v1.2.5` → 合 main → push。
7. App Store Connect 上传 archive → TestFlight beta → 灰度验证 → 推送至全部用户（仅 owner 一人）。

---

## 9. 长期路线说明（不在 v1.2.5 范围）

记录已知但**故意延后**的事项，避免误以为漏了：

- **macOS Widget extension**：本期仅做 iOS。macOS widget 需要独立的 widget extension target（不能复用 iOS 的），且需 App Group entitlement on macOS（与 iOS 不同声明方式）。延后到 v1.3.0 或 v1.2.6 单独处理。
- **Provisioning Profile 自动化**：发布前必须手动在 App Store Connect 配 widget App ID + profile；fastlane / xcode-cloud 自动化延后到运维优化期。
- **Pagination cursor TTL / 签名**：cursor 当前是无签名的 base64 JSON，理论上 client 可手工伪造（但单用户场景无攻击面）。如未来开多用户，cursor 应加 HMAC 签名 + 短 TTL。
- **0001 重写的 idempotency 验证 in production**：本期靠 sqlite + PR 手动验证；如未来想加 prod-only 验证 step，可考虑在 `prod-check.sh` 加一个只读对比"实际 schema vs 期望 schema"的脚本。

---

## 变更日志

### [2026-05-24] 初版
- 初始规划完成。
- 覆盖 v1.2.4 deferred 的 3 项：reviewer #3（Widget extension）、#14（keyset 分页）、#17（Alembic 0001 重写）。
- 4 个 phase（P1–P4），其中 P1/P2/P3 完全独立可并行，P4 是发布工程汇合点。
- 推荐串行顺序 P2 → P3 → P1 → P4。
- P1 必须 owner 在 Xcode GUI 手动操作；P2/P3 builder 可独立完成；P3 复杂度 H，必须 owner review。
- 版本号目标：v1.2.5 / build 1.127。
