# 100J v1.2.5 项目规划

> 这是 v1.2.5 的施工蓝图。v1.2.4.1 已发布（main HEAD `351106c`，tag `v1.2.4.1`，build 1.126.1）。
>
> 工作目录 `/Users/linotsai/Lino/100%J/`。基线 commit = `v1.2.4.1`。目标 tag = `v1.2.5`，build = `1.128`（v1.2.5 的 P1 UX 重做会产生显式 release，build 至少跳 1）。
>
> v1.2.4 / v1.2.4.1 的 plan 归档在 `PROJECT_PLAN_v1.2.4.md`，本文件**不引用**它的 phase 编号（避免歧义）；本期 phase 编号 P0–P3。
>
> **本期范围大调整**：owner 真机使用 v1.2.4.1 后发现写入链路 UX 严重劣化（记一条公司待办要走 7 步：按钮→Composer Sheet prefill→选中文字按方向键→输入→Agent 解析→Confirmation Sheet→确认）。owner 决定**完全推翻 Composer 写入链路**，原 v1.2.5 计划中"keyset 分页"与"Alembic 0001 重写"两项 **defer 到 v1.2.6**（见 §10）。

---

## 1. 概述

### 1.1 目标

| Phase | 主题 | 工作量 | 主要驱动 |
| --- | --- | --- | --- |
| **P0** | Apple Developer Program 接入 + macOS Developer ID 签名/公证（覆盖 owner-1 + 为 P2 widget App Group 铺路） | S（builder 脚本） + 1–2 工作日 wall clock（Apple 审批） | owner 注册付费 + builder 改 package script |
| **P1** | UX 重做：Plan inline quick-add + 删除整条 Composer 链路 + 手动 UI 零确认 | M | builder 全包 |
| **P2** | Widget extension 进 Xcode 工程（依赖 P0） | M | owner Xcode GUI + builder 测试/文档 |
| **P3** | 发布工程（版本号 / OpenAPI snapshot / deployment.md / tag） | S | builder 全包 |

### 1.2 覆盖范围

- **owner-1（macOS 启动 Keychain 弹窗，P0）+ 真机 UX 痛点（P1）+ reviewer #3 Widget extension（P2）+ 发布工程（P3）**。
- **不夹带其他功能或重构**。
- **后端零改动**：v1.2.5 不动 backend 任何代码 / model / migration / endpoint。所有 P1 写入路径都走已存在的 REST endpoint（`POST /api/v1/tasks` / `/notes` / `/projects`），写入路径已经是 direct REST 不经过 Agent，**不需要改任何 backend 代码或 Alembic**。
- 不动 OpenAPI 已有契约（snapshot 只刷 `info.version` 一行）。
- 后端测试基线：86 passed（v1.2.4）→ **v1.2.5 保持 ≥ 86**（不增不减，本期不动后端）。
- Swift 测试基线：53 passed（v1.2.4）→ 目标 **48–52**（删除 Composer / CaptureParser 相关测试约 5–8 条，新增 InlineQuickAddRow + AppModel inline create 测试约 4–6 条，净变化 -3 ~ -1）。
- Alembic 迁移基线：6 个（v1.2.4 = `0001..0006`）→ **v1.2.5 = 6 个**（本期不新增）。
- 单用户私有云定位不变。
- **新增外部付费依赖**：本期引入 Apple Developer Program（$99/年，owner 已决定）以获取 Developer ID Application 证书 + App Group entitlement 的付费签名权限。owner 必须先完成 Apple Developer 注册与证书申请（P0）才能进入 P2（widget 必须付费 team 才能签 App Group entitlement）；同时 P0 顺带修掉 owner-1（Keychain 弹窗）。

### 1.3 预估周期

| Phase | 内容 | 工作量 | 主要驱动 |
| --- | --- | --- | --- |
| P0 | Apple Developer Program 接入 + macOS Developer ID 签名/公证 | S（builder 侧脚本） + 1–2 个工作日 wall clock（Apple 审批） | owner 注册付费 + builder 改打包脚本 |
| P1 | UX 重做：删 Composer + Plan inline quick-add + AppModel 直写方法 | M（约 1–2 个工作日 builder） | builder 全包 |
| P2 | Widget extension 进 Xcode 工程 | M | owner 手动（GUI） + builder 写测试/文档 |
| P3 | 发布工程 | S | builder 全包 |

单人节奏 **4–6 个工作日**。P0 wall clock 来自 Apple 审批（1–2 天，owner 等待期 builder 推 P1）；P2 必须等 P0 完成；P3 等 P0/P1/P2 全部 merge。

### 1.4 Release Criteria

下列条件**全部**满足才能打 v1.2.5 tag：

1. 4 个 phase 对应代码改动全部合入 `main`，每条都能在 commit message / PR 描述追到。
2. `pytest -q backend/tests` 全绿，**与 v1.2.4 持平**（≥ 86）；OpenAPI snapshot 仅 `info.version` 一行差异。
3. `swift test` 全绿（≥ 48）。
4. `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 通过；含 widget extension 的 archive 跑通（见 §3 P2 验收）。
5. `alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连无报错（**与 v1.2.4 持平**，本期不动 alembic）。
6. `python -m scripts.check_alembic_drift` exit 0（v1.2.4 已存在，本期不能破）。
7. `scripts/verify-release.sh` exit 0。
8. `scripts/prod-check.sh` 在 HZ 灰度环境 exit 0。
9. **手测**清单全过（§6.3）。
10. `MARKETING_VERSION = 1.2.5`、`CURRENT_PROJECT_VERSION = 1.128` 三 target 同步（App / Widget Extension / 任何 extension）。
11. `backend/pyproject.toml` `version = "1.2.5"`，`backend/app/main.py` 的 FastAPI `version="1.2.5"`，`tests/openapi_snapshot.json` 同步刷新（仅 `info.version` 一行差异）。
12. `deployment.md` 末尾追加 "v1.2.5 Upgrade Notes" 段落。
13. **P0 macOS release signing**：`RELEASE=1 NOTARY_PROFILE=100j-notary frontend/apple/scripts/package-macos-app.sh` 跑通无错；产物满足：
    - `codesign --verify --deep --strict --verbose=2 dist/100J.app` exit 0；签名 Authority 第一行为 `Developer ID Application: ...`（**不允许** `-` / ad-hoc）。
    - `spctl --assess --type execute --verbose dist/100J.app` 输出 `accepted source=Notarized Developer ID`。
    - `xcrun stapler validate dist/100J.app` exit 0。
    - notarize 流程返回 `status: Accepted`（owner 在本机跑过一次成功）。
14. **P0 真机回归**：owner 在干净 macOS 用户账户（或先删除旧 Keychain item `top.linotsai.app.PersonalAffairs.auth`）安装 v1.2.5 release pkg → 登录 → 重启 app 3 次 → **0 次** Keychain 弹窗（解决 owner-1）。
15. **P1 真机回归**：
    - macOS / iOS 任一端打开 v1.2.5 → Plan tab → 个人 / 公司 / 项目 / 笔记 4 个子 tab 顶部均有 inline quick-add 行 → 在公司 tab 输入"开会"按 Enter → 任务**立即**出现在列表顶部 → 输入框清空 → 焦点保留可继续输入（**1 步**完成"记一条公司待办"，对比 v1.2.4.1 的 7 步）。
    - 全 app 内**找不到任何** Composer 入口（顶部"新建"按钮 / 紫色 sparkles 图标 / ⌘K shortcut / AppShortcuts 中的 ComposerOpen intent 等全部消失）。
    - Agent 屏的 pendingConfirmation banner / sheet 仍正常（仅 Agent 主动调命令时弹）。
16. **P2 真机回归**：iOS 真机装 v1.2.5 → 长按桌面 → 添加 Widget → 搜索 "100J" → 看到 widget 列表 → 添加后 ≤ 5 min 显示真实 Top 3 / Agenda。

---

## 2. 依赖图

### 2.1 Phase 全景

```
P0 Apple Developer Program 接入 + macOS 签名/公证  (覆盖 owner-1 + 为 P2 铺路)
        │
        └── 硬前置 ──> P2 Widget extension 进 Xcode 工程  (覆盖 reviewer #3)

P1 UX 重做：Plan inline quick-add + 删 Composer 链路  ← 与 P0 完全独立可并行

P0 → P2 是唯一硬依赖；P0 / P1 完全独立可并行。
在 owner 等 Apple 审批的 1–2 天里，builder 全力推进 P1。

P3 发布工程 (版本号 + OpenAPI snapshot + deployment.md + prod-check + tag)
   等 P0 / P1 / P2 全部合并后开
```

### 2.2 依赖说明

- **P0 → P2 是硬依赖**：widget extension 需要在 entitlements 声明 App Group，App Group entitlement 必须由付费 team 的 Developer ID 证书签名才被系统接受；ad-hoc 签的 widget 安装即 silently fail。所以 P2 的 Xcode capability 配置必须在 P0 完成（Apple Developer 注册成功 + Team ID 确认）之后进行。
- P1 与 P0 / P2 **完全独立**，可并行。P1 仅动 Swift 客户端（Sources/PersonalAffairsApp 与 Sources/PersonalAffairsCore），不动 backend、不动打包脚本、不动 Xcode 工程结构（pbxproj）。
- P0 / P1 / P2 三者改动的文件几乎不重合：
  - P0：`frontend/apple/scripts/package-macos-app.sh`、新增 `frontend/apple/scripts/setup-codesign-credentials.sh`、`.gitignore`（如缺 `.env.local`）、`deployment.md` "macOS Release Signing" 段。
  - P1：**新增** `frontend/apple/Sources/PersonalAffairsApp/DesignSystem/InlineQuickAddRow.swift`；**删除** `Sources/PersonalAffairsCore/ViewModels/UniversalComposerViewModel.swift`、`Sources/PersonalAffairsCore/Utilities/CaptureParser.swift`、`Sources/PersonalAffairsApp/Features/Composer/ComposerSheet.swift`、`Sources/PersonalAffairsApp/DesignSystem/AdaptiveHeroActionButton.swift`（如独立文件）；**改** `PlanScreen.swift` / `TodayScreen.swift` / `CalendarScreen.swift` / `MacShell.swift` / `IOSShell.swift` / `AppShortcuts.swift` / `AppModel.swift` / `AdaptiveHeroHeader.swift` / `MenuBarPanel.swift`；删 Composer / CaptureParser 相关 swift test，新增 InlineQuickAddRow + AppModel inline-create 测试。
  - P2：`frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`、`Resources/*.entitlements`、`Sources/OneHundredJWidgets/*`、widget 集成 smoke test。
  - P3：`pbxproj` 版本号字段、`backend/pyproject.toml`、`backend/app/main.py`、`backend/tests/openapi_snapshot.json`、`deployment.md`、`scripts/verify-release.sh`、`scripts/prod-check.sh`。
- 唯一隐式约束：P3 必须等 P0 / P1 / P2 全部合并（因为版本号是发布闸门），且 P2 的 widget target 版本号字段也需被 P3 改到 1.2.5 / 1.128。

### 2.3 推荐串行顺序

```
day 0：owner 提交 Apple Developer 申请 ────┐
                                            │
day 0–2：builder 全力推 P1（UX 重做）       │  ←─ 并行
                                            │
day 1–2：Apple 审批（owner 等待） ──────────┘

day 2–3：owner 拿到证书 → builder 改 P0 打包脚本 → P0 合并

day 3：owner Xcode GUI 做 P2-1 ~ P2-6 → builder 提 P2-7 测试/文档 → P2 合并

day 4：P3 发布工程 → tag v1.2.5 → push
```

理由：

1. **P0 owner 申请部分 day-0 启动**（成本：填表 + 信用卡）：尽快开启 Apple 审批排队。
2. **P1 与 P0 并行**：P1 全是 Swift 客户端改动，不依赖签名 / widget；day-0 即可启动。
3. **P0 builder 部分**：owner 拿到证书后 1 天内改完打包脚本 + 文档。
4. **P2 第三**：必须在 P0 完成后开。唯一需要 Xcode GUI 操作的 phase，单独安排 owner 手动窗口。
5. **P3 最后**：纯发布工程。

---

## 3. Phase 细则

> 每个 phase 给：覆盖问题号 / 改动文件（精确到文件 + 区域）/ 接口契约（如涉及）/ 测试计划 / 验收标准 / 工作量（S/M/L）/ 风险（低/中/高）/ **`[owner-only]` vs `[builder-ok]`** 边界标注。

---

### Phase P0 — Apple Developer Program 接入 + macOS Developer ID 签名/公证

**覆盖**：owner-1（macOS 每次启动 Keychain 弹窗，根因 = ad-hoc 签名 cdhash 漂移）+ 为 P2 widget App Group entitlement 铺路（付费 team 才能签）

**工作量**：S（builder 侧脚本改动）｜**wall clock**：1–2 个工作日（Apple 审批 + owner 操作）｜**风险**：低（脚本层；现有 `package-macos-app.sh` 已预留 notarize 接入点，只需把"可选"变"必需"）

**builder 边界**：**部分**。Apple Developer 注册 / 证书申请 / Keychain 导入 / App-Specific Password 生成必须 owner 手动；builder 可独立完成所有脚本与文档改动。

#### 3.0.1 背景

v1.2.4.1 的 owner-1 现状：

- `package-macos-app.sh` 默认 ad-hoc 签名（`CODESIGN_IDENTITY=-`、`NOTARIZE=0`）。每次重打包 cdhash 漂移，designated requirement 不稳定 → macOS Keychain 每次启动弹"100J 想要使用钥匙串中的机密信息"。
- 根因：Keychain ACL 用 designated requirement 鉴权。Developer ID 签的 app 有稳定 requirement（`anchor apple generic and certificate leaf[subject.CN] = "Developer ID Application: <Name> (<TeamID>)"`），同 team 签的任意版本都被接受。
- 同时 P2 widget 的 `application-groups` entitlement **必须付费 team 签名**才被系统接受。

打包脚本现状（v1.2.4.1 HEAD `351106c`）已就位以下基础设施，只需把"可选"变"必需"：

- `CODESIGN_IDENTITY` / `NOTARIZE` / `NOTARY_PROFILE` / `APPLE_ID` / `APPLE_TEAM_ID` / `APPLE_APP_SPECIFIC_PASSWORD` env 全部已声明（默认空 / 0）。
- `require_notarization_credentials()` 完整校验函数已实现。
- `notarize_app()` 已实现 submit → wait → staple → spctl 链。
- 仅缺：`RELEASE=1` 一键强制路径 + Authority assert。

#### 3.0.2 改动清单

**P0-1 owner 注册 Apple Developer Program** `[owner-only]`

1. 用 Apple ID `linocai13@gmail.com` 登录 https://developer.apple.com/programs/ → "Enroll"。
2. 个人开发者（Individual）档；填姓名、地址、电话；提供信用卡 / 借记卡支付 $99。
3. 提交后 Apple 审批 **1–2 个工作日**（节假日更长）。审批结果通过 email 通知。
4. 审批通过后登录 https://developer.apple.com/account → 顶栏看到 "Membership" 段含 Team ID。
5. **owner 必须把以下信息抄出来交给 builder**：
   - **Team ID**（很可能仍是 `HX73DFL88G`——free team 已经分配过这个 ID，付费转换后通常保持不变；但**必须人工 verify**，复制到 §3.0.5 验收清单中）。
   - Apple ID 邮箱：已知 `linocai13@gmail.com`。

**P0-2 owner 申请 Developer ID Application 证书** `[owner-only]`

1. https://developer.apple.com/account/resources/certificates/list → "+" 新建。
2. 选 **Developer ID Application**（**注意区分**：不要选 "Apple Development"，那是开发期；也不要选 "Apple Distribution"，那是 App Store 上架；macOS 在 App Store 外分发必须用 Developer ID Application）。
3. 按提示在本地 Keychain Access 创建 CSR：Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority → Save to Disk。
4. 上传 .certSigningRequest → 下载 `developerID_application.cer`。
5. **双击 .cer** → 选择"登录"钥匙串导入。
6. 在 Keychain Access → 登录 → "我的证书" 应能看到一条 `Developer ID Application: <Name> (HX73DFL88G)`。
7. owner 把**完整 identity 字符串**（精确到括号内 Team ID）抄给 builder——这是脚本 `CODESIGN_IDENTITY` env 的值。
8. 验证命令（owner 在本机跑）：
   ```
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
   预期看到 1 条 `Developer ID Application: <Name> (HX73DFL88G)`。

**P0-3 owner 生成 App-Specific Password（用于 notarytool）** `[owner-only]`

1. https://appleid.apple.com → 登录 → "登录与安全" → "应用专用密码" → "+" → 名称填 `100J-notarytool`。
2. Apple 生成 16 字符密码（格式 `xxxx-xxxx-xxxx-xxxx`），**只显示一次**，owner 立即抄下来。
3. **不要把密码直接贴在 git / PR / commit message / GitHub issue 任何地方**。
4. owner 选下列两种存储方式之一（推荐 B）：

   **A. 写进 `/Users/linotsai/Lino/100%J/.env.local`**（不在 git tracked，已在 `.gitignore`；如未在，builder 需追加）：
   ```
   APPLE_ID=linocai13@gmail.com
   APPLE_TEAM_ID=HX73DFL88G
   APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
   CODESIGN_IDENTITY=Developer ID Application: <Name> (HX73DFL88G)
   ```
   build 时 `source .env.local && RELEASE=1 frontend/apple/scripts/package-macos-app.sh`。

   **B. 存进 macOS Keychain + notarytool keychain profile**（推荐，最干净）：
   - owner 跑 builder 提供的 `frontend/apple/scripts/setup-codesign-credentials.sh`（见 P0-5）。
   - 该脚本内部调 `xcrun notarytool store-credentials 100j-notary --apple-id <id> --team-id <team> --password <pwd>`，把密码加密存进 Keychain item `com.apple.notarytool.100j-notary`。
   - 之后 build 只需 `RELEASE=1 NOTARY_PROFILE=100j-notary frontend/apple/scripts/package-macos-app.sh`，**zero 凭据出现在命令行**。

5. owner 操作完成后通知 builder：选了 A 还是 B，以及 Team ID / identity 字符串。
**P0-4 builder 修改 `frontend/apple/scripts/package-macos-app.sh`** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/scripts/package-macos-app.sh`

引入 `RELEASE` env（默认 0 = 保留现有 ad-hoc 路径不变以兼容本地快速 dev build；=1 = release 模式强制 Developer ID + notarize + staple）。

改动点（精确到行号，行号基准 = v1.2.4.1 HEAD `351106c`）：

1. **行 20 `STAPLE="${STAPLE:-1}"` 之后追加**：`RELEASE="${RELEASE:-0}"`。
2. **`require_notarization_credentials()`（行 38–52）之后追加新函数** `require_release_signing()`，逐条校验（失败即 `exit 1` + stderr 提示）：
   - `CODESIGN_IDENTITY != "-"` 且非空。
   - `CODESIGN_IDENTITY` 以 `Developer ID Application:` 开头（拒 Apple Distribution / Apple Development）。
   - `NOTARIZE == "1"`、`STAPLE == "1"`。
3. **在 `if [[ "$NOTARIZE" == "1" ]]; then` 块（行 107–110）之前插入**：
   ```
   if [[ "$RELEASE" == "1" ]]; then
     NOTARIZE=1; STAPLE=1
     require_release_signing
   fi
   ```
4. **`codesign_app()`（行 59–80）的 `codesign --verify` 之后追加 release-only assert**：再跑一次 `codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"`；并 grep `codesign -dvv` 输出，断言首行 `Authority=Developer ID Application:` 否则 `exit 1`。
5. **`notarize_app()`（行 82–105）的 `spctl --assess` 之后追加 release-only assert**：跑 `xcrun stapler validate "$APP_BUNDLE"`；并 grep `spctl --assess --type execute --verbose=4` 输出含 `source=Notarized Developer ID`，否则 `exit 1`。

**P0-5 新增 `frontend/apple/scripts/setup-codesign-credentials.sh`（可选助手）** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/scripts/setup-codesign-credentials.sh`，可执行。

功能：bash 交互脚本，接受 `PROFILE_NAME="${1:-100j-notary}"` 参数，`read -r -p` 交互提示输入 Apple ID / Team ID / App-Specific Password（密码用 `-s` 隐藏输入），调用：
```
xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD"
```
存进 Keychain。脚本顶 `set -euo pipefail`。完成后 echo 测试命令 `RELEASE=1 NOTARY_PROFILE=$PROFILE_NAME frontend/apple/scripts/package-macos-app.sh`。代码量 < 30 行。

**P0-6 `.gitignore` 加 `.env.local`** `[builder-ok]`：verify `grep -E "^\.env\.local$" .gitignore`；如无追加。`.env.local` **永远不 commit**。

**P0-7 `deployment.md` 末尾追加 "macOS Release Signing" 段** `[builder-ok]`

追加新段 `## macOS Release Signing (v1.2.5+)`，结构：

1. **声明**：release builds 必须 Developer ID 签 + notarize；ad-hoc 仅供本地 dev。
2. **前置（owner 一次性）**：Apple Developer Program 注册 → 申请 Developer ID Application 证书 → 生成 App-Specific Password → 跑 `setup-codesign-credentials.sh` 存进 Keychain notarytool profile（或写 `.env.local`）。
3. **Release build 命令**：
   ```
   RELEASE=1 NOTARY_PROFILE=100j-notary \
     CODESIGN_IDENTITY="Developer ID Application: <Name> (HX73DFL88G)" \
     frontend/apple/scripts/package-macos-app.sh
   ```
   说明 `RELEASE=1` 强制 `NOTARIZE=1 + STAPLE=1` + fail-fast 校验（Authority / 凭据 / spctl / stapler）。
4. **一次性迁移说明**：交叉引用本文件 §7.3.1（owner 选项 A "始终允许" 或 选项 B 删 keychain item）。

**P0-8 不动 P2 widget Xcode signing 配置**

P0 完成后 owner 在 Xcode 配置 widget target signing 时，自动用 P0-1 注册成功的付费 team（HX73DFL88G）。这是 P2-1 ~ P2-6 的隐式前置，已在 §3.2 P2 章节描述。P0 不重复改 P2 步骤。

#### 3.0.3 接口契约

无 API 变更。无客户端 public API 变更。脚本层改动仅影响打包产物的签名状态，不影响 app runtime 行为。

#### 3.0.4 测试计划

- **builder 单测**：脚本层无单测要求（owner 已明确）。
- **builder 静态校验**：
  - `bash -n frontend/apple/scripts/package-macos-app.sh` 语法 OK。
  - `bash -n frontend/apple/scripts/setup-codesign-credentials.sh` 语法 OK。
  - `grep -c "RELEASE=" frontend/apple/scripts/package-macos-app.sh` ≥ 3（env 声明 + 强制开关 + assert 行）。
- **owner 验证**（无 CI 替代）：
  1. 在本机跑 `RELEASE=1 NOTARY_PROFILE=100j-notary CODESIGN_IDENTITY="Developer ID Application: <Name> (HX73DFL88G)" frontend/apple/scripts/package-macos-app.sh`。
  2. 全流程 < 10 min（含 Apple notarize 排队时间，通常 2–5 min）。
  3. 产物 `dist/100J.app` 跑以下 4 条命令全部 exit 0：
     - `codesign --verify --deep --strict --verbose=2 dist/100J.app`
     - `codesign -dvv dist/100J.app 2>&1 | grep "Authority=Developer ID Application:"`
     - `spctl --assess --type execute --verbose dist/100J.app 2>&1 | grep "source=Notarized Developer ID"`
     - `xcrun stapler validate dist/100J.app`
  4. 安装到 macOS（**先删除旧 Keychain item** 或在干净用户账户）→ 登录 → 重启 app 3 次 → 0 次 Keychain 弹窗。
- **fail path 验证**（builder，本机跑）：
  - `RELEASE=1 CODESIGN_IDENTITY=- frontend/apple/scripts/package-macos-app.sh` → 必须 exit 1 且 stderr 含 "RELEASE=1 requires CODESIGN_IDENTITY='Developer ID Application: ...'"。
  - `RELEASE=1 NOTARIZE=0 frontend/apple/scripts/package-macos-app.sh` → 必须 exit 1（NOTARIZE 强开校验失败）。

#### 3.0.5 验收标准

- owner 完成 Apple Developer Program 注册，付费 $99，Team ID 已确认（**记录在 PR description**；预期 `HX73DFL88G`，若不同需通报 builder 同步更新 pbxproj / entitlements 中可能 hardcode 的 Team ID）。
- owner 拿到 Developer ID Application 证书，`security find-identity -v -p codesigning | grep "Developer ID Application"` 输出 1 条。
- owner 完成 App-Specific Password 生成，按选项 A 或 B 存储完毕。
- `frontend/apple/scripts/package-macos-app.sh` 改完，本地 `bash -n` 通过，三条 fail path 触发 exit 1 正确。
- `frontend/apple/scripts/setup-codesign-credentials.sh` 新建完毕，可执行，owner 跑过一次成功。
- owner 在本机用 `RELEASE=1` 跑完整 release 打包流程，4 条验证命令全 exit 0。
- 干净 macOS 账户安装 v1.2.5 release pkg → 重启 app 3 次 → 0 次 Keychain 弹窗。
- `deployment.md` "macOS Release Signing" 段落写完。

#### 3.0.6 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| Apple 审批拖延 > 1 周 | 同期 P1 与 P0 独立，不阻塞 builder；超时联系 Apple Developer Support |
| 付费转换后 Team ID 变了（不再 `HX73DFL88G`） | owner 必须人工 verify；如变 `grep -rn "HX73DFL88G" frontend/apple/` 批量替换 |
| App-Specific Password 泄漏 | 选项 B 用 Keychain profile 不出现明文；`.gitignore` 必须含 `.env.local`；commit 前 `git diff` 自查 |
| Apple notarize 服务慢 / 故障 | 脚本用 `--wait` 阻塞等待；超时可重跑，幂等 |
| Keychain item ACL 升级弹窗 owner 误点"拒绝" | deployment.md "一次性迁移" 段明确指引；误点后按选项 B 删除 keychain item 重新登录恢复 |
| 旧 ad-hoc v1.2.4.1 包与 v1.2.5 Developer ID 包混装 → ACL 混乱 | 装 v1.2.5 前 `rm -rf /Applications/100J.app` 清装 |
| `codesign` Authority 字符串格式因 macOS 版本变化 | 测过的格式 `Authority=Developer ID Application: <Name> (HX73DFL88G)`；如变更新 assert grep |

---

### Phase P1 — UX 重做：Plan inline quick-add + 删除整条 Composer 链路

**覆盖**：owner 真机痛点（"记一条公司待办要 7 步" / "Composer 的 CaptureParser NLP 解析脆弱" / "Agent confirmation 对普通 create 是杀鸡用牛刀"）

**工作量**：M（约 1–2 个工作日 builder）｜**风险**：中（大面积删除 + 多 screen / shell 文件改动，必须保证 Agent 屏 confirmation banner 不被误删）

**builder 边界**：**完全可独立完成**。无 GUI 操作、无 owner 手工步骤。owner 仅在 §6.3 手测清单中真机验收。

#### 3.1.1 背景

v1.2.4.1 真机使用反馈：

- 记一条公司待办：用户路径 = 顶部"新建"按钮 → Composer Sheet 弹出 prefill "新待办：" → 选中"新待办："这几个字按方向键到光标位置 → 输入实际标题 → 点确定触发 Agent → CaptureParser NLP 解析（脆弱，可能把"开会"误归个人）→ Agent confirmation sheet 弹"确认创建" → 用户再点确认 → 创建。**共 7 步**。
- 这是大量真实需求的高频路径（owner 每天 ≥ 5 次），UX 成本不可接受。
- 同时 `CaptureParser` 的 NLP 解析（"#工作"、"!明天"、"@项目" 等约定语法）不可靠，且 Agent confirmation 对普通 create 是过度设计——confirmation 应该只在 Agent 主动调命令时弹（v1.2.4 P5-2 已实现该 banner，本期保留）。

owner 拍板的方案：**完全删除 Composer 链路**，Plan 4 个 tab 各自加 inline quick-add 行，**直接 POST 创建零确认**。

#### 3.1.2 设计决策（owner 已拍板）

1. **方案**：**只要 Plan tab inline quick-add，不要 Composer**。
2. **Plan 4 个 tab 各自加 inline quick-add 行**：
   - 个人 tab：placeholder = `+ 记一条个人待办，按 Enter ↵`
   - 公司 tab：placeholder = `+ 记一条公司待办，按 Enter ↵`
   - 项目 tab：placeholder = `+ 新建项目，按 Enter ↵`
   - 笔记 tab：placeholder = `+ 记一条灵感，按 Enter ↵`
   - 位置：tab 切换器下方、列表上方（与列表同样的 horizontal padding）。
   - 行为：聚焦 → 输入标题 → 按 Enter → **立即** POST 创建 → 任务出现在列表顶部 → 输入框清空 → 保持焦点（连续记）。
   - 写入路径：直接调 `TaskRepository.create` / `NoteRepository.create` / `ProjectRepository.create` —— **不**经过 Agent，**不**弹任何 confirmation。
   - 失败处理：errorMessage 显示 toast / banner（沿用现有错误显示机制）。
3. **不动**：
   - CalendarScreen（owner 决定日程仍走传统点 cell 弹详情表单）。
   - TodayScreen 顶部 hero **全删但不加 quick-add**（owner 说 Today 只用来看）。
   - Agent 屏所有功能（confirmation 仅在 Agent 主动调命令时弹，已经是这个行为，**不需要改后端**）。
4. **后端零改动**：所有 endpoint 已存在（`POST /api/v1/tasks` / `POST /api/v1/notes` / `POST /api/v1/projects`），写入路径已经是 direct REST 不经过 Agent。

#### 3.1.3 改动清单（精确文件 + 区域）

**P1-1 新增 `InlineQuickAddRow` 组件** `[builder-ok]`

新文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/DesignSystem/InlineQuickAddRow.swift`

设计：

- SwiftUI 单行 `HStack`：左侧 `Image(systemName: "plus.circle.fill")`（次要色，13–14pt），中间 `TextField`（占满剩余宽度），无右侧按钮。
- 背景：圆角矩形（`RoundedRectangle(cornerRadius: 10)`），fill `Color(.secondarySystemBackground)` / macOS 等价；horizontal padding 12，vertical padding 10。
- 接受 props：`placeholder: String`、`isBusy: Bool = false`、`onSubmit: (String) async -> Bool`（返回 true = 成功，清空 text；false = 失败，保留 text 让用户修改）。
- 内部 `@FocusState var isFocused: Bool`、`@State var text: String = ""`、`@State var submitting: Bool = false`。
- `.onSubmit { Task { await handleSubmit() } }` 触发 `handleSubmit`：
  - `let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmed.isEmpty else { return }`
  - `submitting = true; let ok = await onSubmit(trimmed); submitting = false`
  - `if ok { text = ""; isFocused = true }`（保持焦点连续记）
- `submitting == true` 时 TextField disabled + 右侧显示小 ProgressView（24x24）。

代码量预估：< 80 行 SwiftUI。

**P1-2 AppModel 新增 4 个 direct-write 方法** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/App/AppModel.swift`

新增 4 个 `@MainActor` async 方法：

```
@MainActor
func createPersonalTask(title: String) async -> Bool {
    // 调 taskRepository.create(CreateTaskRequest(title: title, classification: .personal, ...))
    // 成功后 append 到 in-memory `tasks` 数组顶部
    // 调 refreshDerivedViewModels()（与已有 submit 路径一致的下游 refresh）
    // 失败时 set errorMessage，返回 false
}

@MainActor
func createCompanyTask(title: String) async -> Bool {
    // 同上，classification: .company
}

@MainActor
func createProject(name: String) async -> Bool {
    // projectRepository.create(CreateProjectRequest(name: name, ...))
}

@MainActor
func createNote(title: String) async -> Bool {
    // noteRepository.create(CreateNoteRequest(title: title, type: .idea, body: ""))
}
```

实现要点：

- 复用现有 `taskRepository` / `noteRepository` / `projectRepository` 依赖（已经在 AppModel 持有）。
- 复用现有的 in-memory 列表数组（`tasks` / `notes` / `projects`），把新建对象 `insert(at: 0)` 到对应数组。
- 调 `refreshDerivedViewModels()`（或等价方法名）让 PlanViewModel / CompanyTasksViewModel / PersonalTasksViewModel / NotesViewModel / ProjectsViewModel 重新切片。
- 失败时设 `self.errorMessage = error.localizedDescription`（沿用现有 errorMessage 机制），返回 false。
- 不要走任何 Agent 路径。

**默认值**：

- task：`classification` = personal/company（按方法名）；`status` = `.todo`；`projectId` = nil；`dueAt` = nil；其他字段全部省略（后端模型应允许 null）。
- project：`name` = title；`color` = nil；其他省略。
- note：`title` = title；`type` = `.idea`；`body` = `""`；`tags` = []。

**P1-3 PlanScreen 接入 4 个 InlineQuickAddRow** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/Features/Screens/PlanScreen.swift`

改动：

1. **删除**顶部 hero 区域的 "新建" 按钮（`AdaptiveHeroActionButton` 用法，参数 `actions:` 闭包内容）。如 `AdaptiveHeroHeader` 的 `actions:` 闭包是必传 ViewBuilder 参数，改为可选 / 提供空闭包。见 P1-9。
2. 在 tab 切换器（PickerStyle segmented 或自定义 segment）**下方、列表上方**，按当前选中 tab 渲染对应 `InlineQuickAddRow`：
   ```swift
   switch selectedTab {
   case .personal:
       InlineQuickAddRow(placeholder: "+ 记一条个人待办，按 Enter ↵") { title in
           await model.createPersonalTask(title: title)
       }
   case .company:
       InlineQuickAddRow(placeholder: "+ 记一条公司待办，按 Enter ↵") { title in
           await model.createCompanyTask(title: title)
       }
   case .projects:
       InlineQuickAddRow(placeholder: "+ 新建项目，按 Enter ↵") { title in
           await model.createProject(name: title)
       }
   case .notes:
       InlineQuickAddRow(placeholder: "+ 记一条灵感，按 Enter ↵") { title in
           await model.createNote(title: title)
       }
   }
   ```
3. 保留 PlanScreen 其余结构（segment picker、list section、empty state）不变。
4. 删除该文件中所有 `showingComposer` / `composerPrefill` / `UniversalComposerViewModel` 引用。

**P1-4 TodayScreen 删 hero "新建" 按钮** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/Features/Screens/TodayScreen.swift`

- 删除 `AdaptiveHeroActionButton` / `AdaptiveHeroHeader.actions` 闭包中的"新建"按钮用法。
- **不加** InlineQuickAddRow（owner 决定 Today 只看不记）。
- 删除该文件中所有 `showingComposer` / `composerPrefill` / `UniversalComposerViewModel` 引用。

**P1-5 CalendarScreen 删 hero "新建" 按钮** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/Features/Screens/CalendarScreen.swift`

- 删除 `AdaptiveHeroActionButton` / `AdaptiveHeroHeader.actions` 闭包中的"新建"按钮用法。
- **不加** InlineQuickAddRow（owner 决定日程仍走传统点 cell 弹详情）。
- 保留点击日历 cell 弹详情表单的现有逻辑。
- 删除该文件中所有 `showingComposer` / `composerPrefill` / `UniversalComposerViewModel` 引用。

**P1-6 MacShell 删 ⌘K binding 与 Composer sheet** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/Features/Shell/MacShell.swift`

删除：

- `.keyboardShortcut("k", modifiers: .command)` binding（任何关联到打开 Composer 的 button 或 commands）。
- `.sheet(isPresented: $showingComposer) { ComposerSheet(...) }`。
- `@State private var showingComposer = false`。
- `.onReceive(model.composer.$isOpen) { ... showingComposer = $0 }` 或等价同步逻辑（如有）。
- **Sidebar 顶部紫色 sparkles 图标**（Composer 入口的左上角圆形按钮，紫色渐变背景 + `sparkles` SFSymbol），整段 button 删除。

**保留**：

- v1.2.4.1 hotfix 引入的 `.onReceive(model.$agentReview) { ... }` 同步（Agent 屏 sheet 仍用），**禁止误删**。
- MenuBar / Settings 入口与所有非 Composer-related 行为。

**P1-7 IOSShell 删 ⌘K binding / Composer sheet / sparkles 按钮** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/Features/Shell/IOSShell.swift`

与 P1-6 一致：

- 删除 `@State private var showingComposer`。
- 删除 `.sheet(isPresented: $showingComposer) { ComposerSheet(...) }`。
- 删除任何打开 Composer 的 toolbar button / floating button / sparkles 图标。
- 删除 `.onReceive(model.composer.$isOpen) { ... }` 等价同步。
- **保留** `.onReceive(model.$agentReview)` Agent 同步。

**P1-8 AppShortcuts 删 ComposerOpen intent**（如存在） `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/App/AppShortcuts.swift`

- grep `Composer` / `composer.isOpen` / `openComposer`，删除对应 `AppIntent` struct + `AppShortcut` 注册。
- 如该文件除 ComposerOpen 外无其他 intent，整体文件可保留空骨架（保留 `AppShortcutsProvider` struct，appShortcuts 数组为空），或直接删除文件（如删，需 verify 没有别处 import）。

**P1-9 AdaptiveHeroHeader 调整 actions 参数** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/DesignSystem/AdaptiveHeroHeader.swift`

- 当前签名（推测）：`init<Actions: View>(..., @ViewBuilder actions: () -> Actions)` 强制传 actions ViewBuilder。
- 改为：actions 改为可选闭包（默认 `nil`），或保留 ViewBuilder 但允许传 `EmptyView()`：
  ```swift
  init(..., @ViewBuilder actions: () -> Actions = { EmptyView() })
  ```
- 视觉上：actions 为空时不渲染右上角按钮区。
- **保留** hero 标题 / 副标题渲染（owner 要保留 hero 视觉，只是不再带 action button）。

**P1-10 MenuBarPanel 删 Composer 引用** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/Features/Shell/MenuBarPanel.swift`

- grep `Composer` / `composerPrefill` / `UniversalComposerViewModel` / `openComposer`，删除对应代码（推测是 menu item "新建…" 触发 `model.composer.open(...)`）。
- 如 MenuBar 整个 panel 只有 Composer 入口可删，保留其余 menu item（Settings / Quit / Sign out 等）。

**P1-11 AppModel 删 `submitUniversalComposer` 与 composer 相关 state** `[builder-ok]`

文件：`/Users/linotsai/Lino/100%J/frontend/apple/Sources/PersonalAffairsApp/App/AppModel.swift`

- 删除：
  - `let composer: UniversalComposerViewModel`（或 `@Published var composer: ...`）属性 + init 时的构造。
  - `func submitUniversalComposer(...) async`（或等价命名）方法。
  - 任何 `composer.isOpen` / `composer.prefill` 的 publisher binding（如 onChange）。
- **保留** `agentReview` / `agentViewModel` / `taskRepository` / `noteRepository` / `projectRepository` / `errorMessage` 等无关属性。

**P1-12 删除整条 Composer / CaptureParser 链路文件** `[builder-ok]`

`git rm` 以下文件：

1. `frontend/apple/Sources/PersonalAffairsCore/ViewModels/UniversalComposerViewModel.swift`
2. `frontend/apple/Sources/PersonalAffairsCore/Utilities/CaptureParser.swift`
3. `frontend/apple/Sources/PersonalAffairsApp/Features/Composer/ComposerSheet.swift`
4. `frontend/apple/Sources/PersonalAffairsApp/DesignSystem/AdaptiveHeroActionButton.swift`（**条件删除**：用 `ls` 验证是否独立文件；如果是在 `AdaptiveHeroHeader.swift` 内部定义的内联 struct，则在 P1-9 删那一段 struct 定义即可，不 `git rm` 独立文件）

`AgentNaturalCommandBuilder`：grep 整个 Sources 树 (`grep -rn "AgentNaturalCommandBuilder" frontend/apple/Sources/`)，如存在为独立文件且仅被 UniversalComposerViewModel / CaptureParser 引用，一并 `git rm`；如不存在或被其他地方引用，stop 并报告 owner。

**P1-13 删除 Composer / CaptureParser 相关 Swift 测试** `[builder-ok]`

grep 所有 Swift test 文件：
```
grep -rln "UniversalComposer\|CaptureParser\|ComposerSheet" frontend/apple/Tests/
```

- 整文件只测 Composer / CaptureParser 的（如 `UniversalComposerViewModelTests.swift` / `CaptureParserTests.swift`）→ `git rm` 整文件。
- 混合测试文件（同文件中既测 Composer 又测其他）→ 仅删除 Composer-related 的 `func test...` 方法，保留其他。
- **不要碰**：`testAuthRepository*` / `testCalendarDraftUpdateRequest*`（CalendarDraft 是日历内部 model，与 Composer 无关，必须保留）。grep 验证：`grep -rn "CalendarDraft" frontend/apple/Sources/` 应仍有引用。

**P1-14 新增 `InlineQuickAddRowTests`** `[builder-ok]`

新文件：`frontend/apple/Tests/PersonalAffairsAppTests/InlineQuickAddRowTests.swift`（如该 test target 不存在，放到 `PersonalAffairsCoreTests/` 并改测 InlineQuickAddRow 的可测部分；测试组件层渲染可能需要 `@MainActor` + ViewInspector，如项目不用 ViewInspector，改用纯单元逻辑测试 onSubmit closure）。

测试用例（≥ 3 条）：

1. `test_onSubmit_called_when_text_not_empty`：模拟 `text = "开会"`，触发 `.onSubmit`，断言 onSubmit closure 被调用且参数 == "开会"。
2. `test_onSubmit_not_called_when_text_empty_or_whitespace`：text = "" / "   " / "\n"，触发 `.onSubmit`，断言 closure 未被调用。
3. `test_text_cleared_after_successful_submit`：模拟 onSubmit 返回 true，断言 text == ""；模拟返回 false，断言 text 仍 == 原值。

**实现策略**：如果 `InlineQuickAddRow` 把核心逻辑抽到一个 `private func handleSubmit()`，提一个 internal helper / static method 让测试直调；或在 InlineQuickAddRow 暴露一个 testing-only `internal var _state` 便于断言。**优先**：抽 pure function `func sanitizeAndShouldSubmit(_ text: String) -> String?`（返回 nil = 不提交，非 nil = trimmed 提交内容），直接单测该函数即可，避免 SwiftUI view inspection 复杂度。

**P1-15 新增 `AppModelInlineCreateTests`** `[builder-ok]`

新文件：`frontend/apple/Tests/PersonalAffairsAppTests/AppModelInlineCreateTests.swift`（或 `PersonalAffairsCoreTests/`，与现有 AppModel 测试目录一致）。

测试用例（≥ 4 条）：

1. `test_createCompanyTask_calls_taskRepository_create_with_company_classification`：mock `TaskRepository`，调 `model.createCompanyTask(title: "开会")`，断言 mock 收到 `CreateTaskRequest` 且 `classification == .company`、`title == "开会"`。
2. `test_createPersonalTask_calls_taskRepository_create_with_personal_classification`：同上，`classification == .personal`。
3. `test_createCompanyTask_inserts_task_at_top_of_tasks_array_on_success`：mock 返回新 Task → 断言 `model.tasks.first?.id == newTask.id`。
4. `test_createCompanyTask_sets_errorMessage_and_returns_false_on_failure`：mock 抛错 → 断言返回 false 且 `model.errorMessage != nil`。
5. （可选）`test_createNote_defaults_to_idea_type_with_empty_body`、`test_createProject_uses_title_as_name`。

依赖：项目已有 `MockTaskRepository` / `MockNoteRepository` / `MockProjectRepository`（v1.2.4 测试已用过）。如无，新建最简版本（实现对应 Repository protocol，记录调用参数 + 返回 stub）。

#### 3.1.4 接口契约

**后端**：零变化。所有写入路径用已存在的 endpoint：

| 操作 | Endpoint | Request | Response |
| --- | --- | --- | --- |
| 创建公司待办 | `POST /api/v1/tasks` | `{title, classification: "company"}` | `201 {id, title, classification, status, created_at, updated_at, ...}` |
| 创建个人待办 | `POST /api/v1/tasks` | `{title, classification: "personal"}` | `201 {id, ...}` |
| 创建项目 | `POST /api/v1/projects` | `{name: title}` | `201 {id, name, ...}` |
| 创建笔记 | `POST /api/v1/notes` | `{title, type: "idea", body: ""}` | `201 {id, ...}` |

错误：沿用 v1.2.4 现有 `AppError`（400 validation / 401 unauth / 500）。InlineQuickAddRow 失败时 `errorMessage` 显示在现有 toast/banner（PlanScreen 顶部 ErrorBanner 已有）。

**OpenAPI snapshot**：仅 `info.version` 一行变化（P3 一并刷新）。

#### 3.1.5 测试计划

- **删除**（Swift test 净减约 5–8 条）：
  - `UniversalComposerViewModelTests.swift` 全文件（如存在）。
  - `CaptureParserTests.swift` 全文件（如存在）。
  - `ComposerSheetTests.swift` 全文件（如存在）。
  - 混合测试中的 `test_composer_*` / `test_captureParse_*` 方法。
- **新增**（Swift test 净加 4–6 条）：
  - `InlineQuickAddRowTests.swift`（≥ 3 条，见 P1-14）。
  - `AppModelInlineCreateTests.swift`（≥ 4 条，见 P1-15）。
- **CI 验证**：`swift test` 全绿，最终用例数 ≥ 48（v1.2.4 = 53；净 -3 ~ -1）。
- **静态校验**：
  - `grep -rn "UniversalComposerViewModel\|CaptureParser\|ComposerSheet" frontend/apple/Sources/` 必须 **0 命中**。
  - `grep -rn "AdaptiveHeroActionButton" frontend/apple/Sources/` 必须 **0 命中**（或者保留作为 unused 但需 P1-12 决定）。
  - `grep -rn "showingComposer\|composer.isOpen\|composer.open" frontend/apple/Sources/` 必须 **0 命中**。
- **后端测试**：不动，`pytest -q backend/tests` 必须仍然 86 passed（与 v1.2.4 持平）。

#### 3.1.6 验收标准

- 编译：`swift build` + `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 均通过。
- 测试：`swift test` 全绿（≥ 48 passed）。
- 静态：上述 3 条 grep 均 0 命中。
- 真机（owner，§6.3 P1 段）：macOS / iOS 任一端 Plan 4 个 tab 顶部均有 inline quick-add 行；公司 tab 输入"开会" Enter → 1 秒内任务出现在列表顶部，输入框清空且焦点保留；连续输入 3 条均成功；全 app 无任何 Composer 入口残留；Agent 屏 confirmation banner 与 sheet 仍按 v1.2.4 P5-2 行为工作（只有 Agent 主动调命令时弹）。
- 文件删除：`git status` 显示 `deleted: UniversalComposerViewModel.swift / CaptureParser.swift / ComposerSheet.swift`（+ AdaptiveHeroActionButton.swift 如独立文件）。

#### 3.1.7 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| 误删 `.onReceive(model.$agentReview)` 同步（v1.2.4.1 hotfix） | P1-6 / P1-7 明确保留；commit 前 `grep -n "agentReview" .../Shell/*.swift` 必须 ≥ 2 命中 |
| 误删 `CalendarDraft` 相关测试 | P1-13 明确只删 Composer / CaptureParser 相关；保留 `testCalendarDraft*` |
| `AdaptiveHeroActionButton` 若是内联 struct（在 `AdaptiveHeroHeader.swift` 内）而非独立文件 | P1-12 标"条件删除"，先 `ls` 验证；如不存在则在 `AdaptiveHeroHeader.swift` 内 grep 并删该 struct |
| AppModel.createXxx 字段与后端 endpoint 期望不匹配 | 参考现有 `submitUniversalComposer` 内构造 `CreateTaskRequest` 的字段；保持 enum 值与现有代码一致；后端 86 passed 覆盖 endpoint contract |
| InlineQuickAddRow 在 macOS / iOS 渲染差异 | `.textFieldStyle(.plain)` 跨平台一致；细节问题 owner 真机后微调 |
| 删 Composer 后 ViewModel 持有的 `composer` 引用 dangling | grep `composer` 全 Sources 树清完；编译 fail 即回归信号 |
| 用户狂按 Enter 触发 race | P1-1 `TextField disabled` when submitting；`await` 自然串行 |

---

### Phase P2 — Widget extension 进 Xcode 工程

**覆盖**：reviewer #3（Widget 永远空数据 / 致命）

**前置依赖**：**P0 必须先完成**（Apple Developer Program 注册成功，付费 team 可用）。widget 的 `application-groups` entitlement 在 free team 下签名后会被 macOS / iOS 系统拒绝，因此必须等 P0 拿到付费 team 才能进入本 phase。

**工作量**：M｜**风险**：中（Xcode 项目结构改动 + 签名 / provisioning）

**builder 边界**：**部分**。Xcode GUI 操作必须 owner 手动；builder 只能写非 GUI 部分（README 更新、widget 测试 stub、smoke test）。每个 step 下方明确标注 `[owner-only]` 或 `[builder-ok]`。

#### 3.2.1 背景

v1.2.4 已经完成代码侧准备：

- `frontend/apple/Sources/OneHundredJWidgets/OneHundredJWidgets.swift` 中 `OneHundredJWidgetsBundle.init()` 已调用 `WidgetSnapshotStore.useAppGroup("group.top.linotsai.app.PersonalAffairs")`。
- `WidgetSnapshotStore` 已经支持 `useAppGroup(_:)` 切到 App Group `UserDefaults` 容器。
- iOS host app entitlements `frontend/apple/Sources/PersonalAffairsApp/Resources/PersonalAffairsApp.iOS.entitlements` 含 `application-groups = [group.top.linotsai.app.PersonalAffairs]`（v1.2.2 已加）。

**缺的就一件事**：`frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 里只有 1 个 native target（host app），widget 没作为 extension target 被 archive / install。iOS 用户装 v1.2.4 / v1.2.4.1 后**根本看不到 widget 可选**。

#### 3.2.2 改动清单

**P2-1 在 Xcode 创建 Widget Extension target** `[owner-only]`

具体步骤（owner 在 Xcode GUI 操作）：

1. 打开 `frontend/apple/PersonalAffairsApp.xcodeproj`。
2. File → New → Target → iOS → Widget Extension。
3. Product name: `OneHundredJWidgets`。
4. Bundle Identifier: `top.linotsai.app.PersonalAffairs.Widgets`（必须以 host app bundle id `top.linotsai.app.PersonalAffairs` 为前缀，否则 App Group 不能共享）。
5. Embed in Application: `PersonalAffairsApp`。
6. Include Configuration Intent: **否**（v1.2.5 不做 configurable widget）。
7. Team: `HX73DFL88G`（与 host app 同；P0 验证 Team ID 后填）。
8. Code Signing: Automatic。

完成后 Xcode 会自动：

- 在 pbxproj 新增 native target `OneHundredJWidgets`。
- 新增 Embed Foundation Extensions / Embed App Extensions build phase 到 host app target。
- 创建 `frontend/apple/OneHundredJWidgets/Info.plist`（删除：让 widget 用 Build Settings 内嵌的 Info；或保留并把内容收敛到 `NSExtension` 段）。

**接管点**：Xcode 自动生成的 `frontend/apple/OneHundredJWidgets/OneHundredJWidgetsBundle.swift` 等占位文件需要**删掉**，因为真正的实现在 Swift Package `Sources/OneHundredJWidgets/`。

**P2-2 把 Swift Package 的 widget 源文件加进 widget target** `[owner-only]`

在 Xcode：

1. Project Navigator → 右键 OneHundredJWidgets group → Add Files to "PersonalAffairsApp"。
2. 选 `frontend/apple/Sources/OneHundredJWidgets/` 下所有 .swift 文件（`OneHundredJWidgets.swift`、相关 Provider、View、Snapshot store glue 等）。
3. 勾选 Target Membership：**仅** `OneHundredJWidgets`（不勾 host app 也不勾 PersonalAffairsCore）。
4. Reference Type: "Create groups"（默认）。

**关键**：这些文件**同时**必须保留在 Swift Package（`Package.swift` 的 `executableTarget(name: "OneHundredJWidgets")` 段），因为 swift package 路径仍然是 `swift test` 用来跑 widget 相关单测的入口。Xcode 通过文件系统 reference 引用到同一份 .swift 文件，**不复制**。

**P2-3 widget target 依赖 PersonalAffairsCore** `[owner-only]`

widget Swift 源使用 `WidgetSnapshotStore`、`PersonalAffairsCore.Models` 等，必须 link：

1. 选 `OneHundredJWidgets` target → General → Frameworks and Libraries。
2. 点 + → 选 `PersonalAffairsCore`（已存在的 Swift Package product）。
3. Embed: Do Not Embed（PersonalAffairsCore 是 static library；widget extension 不 embed framework）。

如果 Xcode 不识别 PersonalAffairsCore：先在 project root → Package Dependencies 确认本地 Package 已注册（v1.2.4 已注册，应无需改）。

**P2-4 创建 Widget entitlements** `[owner-only + builder 验证]`

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

**P2-5 Embed Foundation Extensions build phase 验证** `[owner-only + builder 验证]`

Xcode 在 P2-1 自动加这个 build phase；owner 验证：

1. 选 host app target → Build Phases → 确认有 "Embed Foundation Extensions"（或 "Embed App Extensions"）阶段。
2. 阶段内容必须含 `OneHundredJWidgets.appex`。
3. Destination: Plugins and Foundation Extensions。Code Sign On Copy: ✅。

builder 验证：commit 后 `grep -c "OneHundredJWidgets.appex" frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` ≥ 2（一处声明 product file，一处在 embed phase）。

**P2-6 Provisioning profile** `[owner-only，发布前]`

- 开发：Code Signing Style = Automatic，团队 `HX73DFL88G`，Xcode 自动生成 development profile，含 App Group capability。
- 发布：App Store Connect → Identifiers → 新建 App ID `top.linotsai.app.PersonalAffairs.Widgets`，勾选 App Groups → 选 `group.top.linotsai.app.PersonalAffairs`。生成 Distribution profile。

**这一步必须在 archive 上传 TestFlight 前完成**，否则 archive 会因为 widget extension 没有 prod profile 而 fail。

**P2-7 widget 集成 smoke test** `[builder-ok]`

新增 `frontend/apple/Tests/PersonalAffairsCoreTests/WidgetSnapshotIntegrationTests.swift`：

- `test_widgetSnapshotStore_useAppGroup_writes_and_reads_through_group_defaults`：在 sandbox UserDefaults 上模拟 `useAppGroup("group.test.fake")` → `save(snapshot)` → 重新 `useAppGroup("group.test.fake")` → `load()` 拿到相同 snapshot。
- `test_widgetBundle_init_invokes_useAppGroup_with_production_identifier`：构造 `OneHundredJWidgetsBundle()`，断言 `WidgetSnapshotStore.currentGroupIdentifier == "group.top.linotsai.app.PersonalAffairs"`（需在 `WidgetSnapshotStore` 暴露 internal getter）。

如果 `WidgetSnapshotStore` 目前没有 `currentGroupIdentifier` getter，加一行 `internal static private(set) var currentGroupIdentifier: String?`，在 `useAppGroup(_:)` 中赋值即可。**这是测试可观察性需要，非业务字段**。

**P2-8 README / deployment 文档更新** `[builder-ok]`

- `README.md`：在 "iOS Widget 安装" 段（如无则新增）说明 v1.2.5 起 widget 自动作为 host app 的 extension 安装，无需用户额外操作；首次显示数据延迟 ≤ 5 min。
- `deployment.md` v1.2.5 段落（P3 写入）：注明发布 prod build 前必须在 App Store Connect 创建 Widget extension App ID + Distribution profile，否则 archive fail。

#### 3.2.3 接口契约

无后端 API 变更。无客户端 public API 变更。

#### 3.2.4 测试计划

- **CI 自动化**：
  - `swift test` 跑新增 `WidgetSnapshotIntegrationTests`（builder 写）。
  - `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 必须能编译含 widget extension 的完整 archive 候选（v1.2.4 已存在；P2 之后会因为多了 widget target 而自动覆盖）。
  - 新增 verify 步骤：`xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -configuration Release -archivePath /tmp/100j-v125.xcarchive archive` 在 verify-release.sh 内（owner 跑过一次即可，CI 因为签名问题不强制）。
- **手测（owner，无 CI 替代）**：
  - iOS 真机装 v1.2.5 → 长按桌面 → 添加 Widget → 搜索 "100J" → 应能看到 widget 列表（Top 3 / Agenda）。
  - 添加后 5 min 内 widget 显示真实 Top 3 + Agenda（host app 必须先登录拉过一次数据）。
  - macOS 端**不在本期范围**（macOS widget 需独立 target，且 Reviewer #3 仅针对 iOS）。

#### 3.2.5 验收标准

- iOS 真机装 v1.2.5 → 添加 Widget → 5 min 内显示真实 Top 3 / Agenda（reviewer #3 的原始验收）。
- `xcodebuild ... archive` 成功，产出 `.xcarchive` 内含 `OneHundredJWidgets.appex`（用 `find /tmp/100j-v125.xcarchive -name "*.appex"` 验证）。
- pbxproj 中 widget extension target 完整存在；`grep "OneHundredJWidgets.appex" frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 至少 2 处命中。
- widget entitlements 与 host app entitlements 的 App Group 字符串**逐字符**一致。

#### 3.2.6 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| owner 在 Xcode GUI 操作过程意外破坏 pbxproj（build phase 顺序错乱、文件 reference 重复） | 操作前 `git stash` 干净 working tree；操作后 `git diff frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 逐行 review；builder 跑 `xcodebuild build` 立刻验证 |
| Provisioning profile 配错（缺 App Group capability） | 开发用 Automatic（Xcode 自动加 capability）；发布前 App Store Connect 的 App ID 必须明确勾 App Groups 才能生成 prod profile，否则 archive 直接报错 |
| widget Swift 源同时归属 Swift Package + Xcode widget target 引起重复编译 | 文件 reference 使用 "Create groups"（不勾 host app target），Xcode 只编译给 widget target；Swift Package 仍独立编译给 `swift test` 用 |
| 旧 iOS 用户从 v1.2.4 升 v1.2.5：widget 新装但 host app 还没把 snapshot 写到 App Group 容器 | host app 在 v1.2.2 起已经把 snapshot 写到 App Group；升 v1.2.5 后第一次 app 启动 + 任意刷新即写入；用户在添加 widget 后 5 min 内见到数据 |

---

### Phase P3 — 发布工程

**覆盖**：版本号 + OpenAPI snapshot + deployment.md + prod-check + verify-release + tag。**仅在 P0 / P1 / P2 全部 merge 后开始。**

**工作量**：S｜**风险**：低（纯发布机械动作）

**builder 边界**：**完全可独立完成**。

#### 3.3.1 改动清单

**P3-1 版本号** `[builder-ok]`

- `frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`：
  - 现有 App target 的 `MARKETING_VERSION = 1.2.4` → `1.2.5`（Debug + Release 各 1 处 = 2 处）。
  - 现有 App target 的 `CURRENT_PROJECT_VERSION = 1.126` → `1.128`（2 处）。
  - **新增** Widget extension target 的 `MARKETING_VERSION` 也是 `1.2.5`，`CURRENT_PROJECT_VERSION` 也是 `1.128`（2 处 Debug + 2 处 Release = 4 处）。**与 host app 同步是 App Store 必需**，否则上传 archive 报 "extension version mismatch"。
- `backend/pyproject.toml`：`version = "1.2.4"` → `version = "1.2.5"`。
- `backend/app/main.py`：`FastAPI(..., version="1.2.4")` → `version="1.2.5"`。

**build 号选择 1.128 的理由**：v1.2.4 = 1.126，v1.2.4.1 hotfix = 1.126.1（沿用基号），v1.2.5 因 P1 UX 重做产生显式 release，build 跳到 1.128（**不**用 1.127 是为了在 TestFlight 历史中明确切割 v1.2.4.x hotfix 段落与 v1.2.5 主线）。

**P3-2 OpenAPI snapshot 刷新** `[builder-ok]`

- `backend/tests/openapi_snapshot.json`：仅 `info.version` 一行变化 `"1.2.4"` → `"1.2.5"`。
- 刷新命令（同 v1.2.4 P7-2 风格，inline）：
  ```
  python -c "import json; from app.main import app; print(json.dumps(app.openapi(), indent=2))" > backend/tests/openapi_snapshot.json
  ```
- 提交时 diff review 确认仅 1 行变化；如果 P1 / P2 期间不小心动了 schema（不应发生——P1 不动后端，P2 只动 Xcode），diff 会暴露。

**P3-3 deployment.md 增 v1.2.5 段落** `[builder-ok]`

- 末尾追加 `## v1.2.5 Upgrade Notes`：
  1. **iOS Widget**：v1.2.5 起 iOS 安装包内含 widget extension；首次安装/升级后，用户长按桌面 → 添加 widget → 等 ≤ 5 min 显示数据。无需后端动作。
  2. **macOS Release Signing**：见同文件 "macOS Release Signing (v1.2.5+)" 段（P0-7 写入）。release build 必须用 `RELEASE=1` 模式。
  3. **UX 写入路径**：v1.2.5 删除整条 Composer 链路。用户在 Plan tab 4 个 sub-tab（个人 / 公司 / 项目 / 笔记）顶部 inline quick-add 行直接输入 → Enter 即创建，**不经过 Agent**。Agent 屏 confirmation banner 仅在 Agent 主动调命令时弹（保留 v1.2.4 P5-2 行为）。
  4. **后端**：v1.2.5 后端零改动。无 alembic 迁移变化（仍 6 个：`0001..0006`）。
  5. **回滚**：见 §7 "回滚预案"。
  6. **App Store**：发布 prod build 前需在 App Store Connect 创建 Widget extension 的 App ID `top.linotsai.app.PersonalAffairs.Widgets`（capabilities 勾 App Groups → `group.top.linotsai.app.PersonalAffairs`），生成 Distribution profile。

**P3-4 prod-check.sh 不增项**（本期不动后端） `[builder-ok]`

- `scripts/prod-check.sh` 保持 v1.2.4 现状（register 404 / device-logout 401 / forwarded-IP 健康检查不动）。
- v1.2.5 不动后端 endpoint / cursor 格式 / 分页，无新增检查点。

**P3-5 verify-release.sh 不增项** `[builder-ok]`

- `scripts/verify-release.sh` 保持 v1.2.4 现状。
- 本期不引入 baseline check / hash 文件等额外验证（这些 defer 到 v1.2.6 的 P3 重启）。

**P3-6 tag & merge** `[builder-ok]`

- `git tag v1.2.5`。
- 跑 §6.1 / §6.2 / §6.3 全部清单。
- `git push origin main --tags`。

#### 3.3.2 验收标准

- `scripts/verify-release.sh` exit 0。
- `scripts/prod-check.sh` 在 HZ 灰度 exit 0。
- §6.3 手测全过。
- iOS TestFlight build 1.128 上传 App Store Connect 成功，含 widget extension。

---

## 4. 跨 phase 公共改动汇总

| 主题 | 涉及文件 | 涉及 phase |
| --- | --- | --- |
| macOS release signing 脚本 | `frontend/apple/scripts/package-macos-app.sh`（改）、`frontend/apple/scripts/setup-codesign-credentials.sh`（新建）、`.gitignore`（如缺 `.env.local`）、`deployment.md`（"macOS Release Signing" 段） | P0, P3 |
| 删除 Composer / CaptureParser 链路 | `Sources/PersonalAffairsCore/ViewModels/UniversalComposerViewModel.swift`（删）、`Sources/PersonalAffairsCore/Utilities/CaptureParser.swift`（删）、`Sources/PersonalAffairsApp/Features/Composer/ComposerSheet.swift`（删）、`Sources/PersonalAffairsApp/DesignSystem/AdaptiveHeroActionButton.swift`（条件删） | P1 |
| Plan tab inline quick-add | 新增 `Sources/PersonalAffairsApp/DesignSystem/InlineQuickAddRow.swift`、改 `Features/Screens/PlanScreen.swift` | P1 |
| 删 hero "新建" 按钮 / Composer sheet / ⌘K shortcut | `Features/Screens/{Today,Calendar,Plan}Screen.swift`、`Features/Shell/{Mac,IOS}Shell.swift`、`Features/Shell/MenuBarPanel.swift`、`App/AppShortcuts.swift`、`DesignSystem/AdaptiveHeroHeader.swift` | P1 |
| AppModel direct-write 方法 | `App/AppModel.swift`（新增 4 方法 + 删 composer 相关 state / `submitUniversalComposer`） | P1 |
| Xcode 项目结构（widget target） | `frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`、`frontend/apple/OneHundredJWidgets/*` | P2, P3 |
| 版本号 | pbxproj × 4 个 build setting block（App + Widget × Debug/Release）、`pyproject.toml`、`main.py` | P3 |
| `deployment.md` | `deployment.md` | P0, P3 |
| `verify-release.sh` / `prod-check.sh` | `scripts/*.sh` | 本期不动 |

---

## 5. 测试新增汇总

| Phase | 文件 | 测试 |
| --- | --- | --- |
| P1 | 删 `frontend/apple/Tests/.../UniversalComposerViewModelTests.swift`（如存在） | – 全删 |
| P1 | 删 `frontend/apple/Tests/.../CaptureParserTests.swift`（如存在） | – 全删 |
| P1 | 删 `frontend/apple/Tests/.../ComposerSheetTests.swift`（如存在） | – 全删 |
| P1 | 新增 `frontend/apple/Tests/.../InlineQuickAddRowTests.swift` | onSubmit called / not called for empty / text cleared on success（≥ 3 条） |
| P1 | 新增 `frontend/apple/Tests/.../AppModelInlineCreateTests.swift` | createCompanyTask / createPersonalTask / createProject / createNote 各走对应 Repository.create，写入后 tasks 数组更新（≥ 4 条） |
| P2 | 新增 `frontend/apple/Tests/PersonalAffairsCoreTests/WidgetSnapshotIntegrationTests.swift` | `useAppGroup` 写读 round-trip / `OneHundredJWidgetsBundle.init` 触发 useAppGroup with prod identifier（≥ 2 条） |
| P2 | （手测，无 CI 替代） | iOS 真机添加 widget → 5 min 内显示 Top 3 / Agenda |

Swift 测试总数预估：53（v1.2.4 基线）- 5~8（P1 删 Composer / CaptureParser）+ 3（P1 InlineQuickAddRow）+ 4（P1 AppModel inline create）+ 2（P2 widget） ≈ **48–52**。

后端测试总数：86（v1.2.4 基线）→ **86**（本期不动后端）。

---

## 6. 发布检查清单

### 6.1 自动化（CI 必过）

- [ ] `bash -n frontend/apple/scripts/package-macos-app.sh` 语法 OK（P0）
- [ ] `bash -n frontend/apple/scripts/setup-codesign-credentials.sh` 语法 OK（P0）
- [ ] `grep -E "^\.env\.local$" .gitignore` 命中（P0）
- [ ] `pytest -q backend/tests` 全绿（**= 86 passed**，本期不动后端）
- [ ] `python -m scripts.check_alembic_drift` exit 0（v1.2.4 已有，本期不能破）
- [ ] `alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连无报错（与 v1.2.4 持平）
- [ ] `swift test` 全绿（≥ 48 passed）
- [ ] `grep -rn "UniversalComposerViewModel\|CaptureParser\|ComposerSheet" frontend/apple/Sources/` **0 命中**（P1）
- [ ] `grep -rn "showingComposer\|composer.isOpen\|composer.open" frontend/apple/Sources/` **0 命中**（P1）
- [ ] `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build` 通过
- [ ] `xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' archive` 成功且含 `OneHundredJWidgets.appex`（P2）
- [ ] `scripts/verify-release.sh` exit 0
- [ ] `backend/tests/openapi_snapshot.json` 仅 `info.version` 一行差异

### 6.2 灰度（HZ 云）

- [ ] `scripts/deploy-hz.sh` 部署到灰度机（**实际无需**：本期后端零改动，可选跳过；但建议跑一次确认无回归）
- [ ] 灰度机执行 `alembic upgrade head` 成功（本期无新增 migration，应是 no-op）
- [ ] `scripts/prod-check.sh` 全绿（与 v1.2.4 一致）
- [ ] `journalctl -u 100j-api -n 200` 无 ERROR

### 6.3 手测（owner 亲测）

**P0 macOS release 签名链**：

- [ ] `RELEASE=1 NOTARY_PROFILE=100j-notary frontend/apple/scripts/package-macos-app.sh` exit 0
- [ ] `codesign --verify --deep --strict --verbose=2 dist/100J.app` exit 0
- [ ] `codesign -dvv dist/100J.app 2>&1 | grep "Authority=Developer ID Application:"` 命中 1 行
- [ ] `spctl --assess --type execute --verbose dist/100J.app 2>&1 | grep "source=Notarized Developer ID"` 命中
- [ ] `xcrun stapler validate dist/100J.app` exit 0

**P0 owner-1 验收**：

- [ ] 干净 macOS 账户（或先删 `top.linotsai.app.PersonalAffairs.auth` keychain item）装 v1.2.5 → 登录 → 重启 app 3 次 → 0 次 Keychain 弹窗
- [ ] **P0 fail-fast 验证**（builder/owner 任一）：`RELEASE=1 CODESIGN_IDENTITY=- frontend/apple/scripts/package-macos-app.sh` 必须 exit 1

**P1 UX 重做**：

- [ ] macOS / iOS 任一端 v1.2.5：Plan tab → 4 个 sub-tab（个人 / 公司 / 项目 / 笔记）顶部均有 inline quick-add 行（plus 图标 + placeholder + 圆角灰底）
- [ ] 公司 tab：输入"开会"按 Enter → 1 秒内任务出现在列表顶部 → 输入框清空且焦点保留
- [ ] 连续输入 3 条公司待办均成功，全部出现在列表顶部
- [ ] 个人 / 项目 / 笔记 tab 各输入 1 条，行为一致（创建成功 / 清空 / 保焦点）
- [ ] 全 app 搜索"新建"按钮：顶部 hero 0 个、Sidebar 顶部紫色 sparkles 0 个、⌘K 不响应（macOS）、长按桌面无 100J app shortcut "Open Composer"（iOS）
- [ ] Agent 屏：发送一条 Agent 指令触发 confirmation → banner 与 sheet 仍按 v1.2.4 P5-2 行为弹起 → 确认后命令执行
- [ ] 失败路径：断网状态下 inline quick-add 输入"测试"按 Enter → errorMessage banner 显示 → 输入框保留"测试"文本可重试

**P2 iOS Widget**：

- [ ] iOS 真机装 v1.2.5 → 长按桌面 → 添加 widget → 搜索 "100J" → 看到 widget 列表
- [ ] 添加 Top 3 + Agenda widget → 等 ≤ 5 min → 显示真实数据（**P2 验收 = reviewer #3 主验收**）
- [ ] iOS：注销重登 → widget 数据更新到新登录账号视角

### 6.4 版本号

- [ ] `MARKETING_VERSION = 1.2.5`（App + Widget × Debug/Release = 4 处）
- [ ] `CURRENT_PROJECT_VERSION = 1.128`（同上 4 处）
- [ ] `backend/pyproject.toml` version = `1.2.5`
- [ ] `backend/app/main.py` FastAPI version = `1.2.5`
- [ ] `backend/tests/openapi_snapshot.json` info.version = `1.2.5`
- [ ] `git tag v1.2.5` + push

---

## 7. 回滚预案

按"改动可逆性"分等级。

### 7.1 服务端（无回滚动作）

- 本期后端零改动，无 alembic 迁移变化、无 endpoint 变化、无 cursor 格式变化。
- v1.2.5 → v1.2.4 服务端无需回滚动作。
- HZ 灰度 / 生产部署本期实际可跳过（但建议跑一次 prod-check.sh 确认没人误改了 backend）。

### 7.2 客户端

**iOS Widget**（P2）：

- 回滚 = 用户在 App Store 装 v1.2.4 IPA（或 TestFlight 切回 build 1.126）。
- v1.2.4 不含 widget extension，TestFlight 降级后 widget 自动从桌面消失（iOS 系统行为）。
- App Group 容器里的 snapshot 数据保留（v1.2.4 host app 仍写）；下次升回 v1.2.5 widget 立刻读到。
- **应急保留**：v1.2.5 上 App Store 后 v1.2.4 IPA 至少保留 14 天。

**P1 UX 重做回滚**：

- 触发条件：inline quick-add 在真机出现严重 bug（创建失败率 > 5% / 焦点丢失无法连续输入 / 数据丢失等）。
- 回滚步骤：
  1. `git revert <P1-commits>` （P1 PR squash merge 后是 1 个 commit，revert 简单）。
  2. rebuild + 发 v1.2.5.1 hotfix。
  3. UX 回到 v1.2.4.1 状态（Composer 链路，7 步流程，已知劣化但可工作）。
- 注意：P1 删除大量代码 + 添加少量代码，revert 后代码全部恢复；无数据迁移风险（本期不动 schema / 数据）。
- **不建议在 P1 已上线后切回 Composer**：UX 劣化是已知的；优先策略 = 修 inline 的 bug 而不是回 Composer。

**macOS Developer ID 签名 → ad-hoc 回退**（P0）：

**触发条件**：Developer ID 证书被 Apple 吊销 / Apple Developer Program 续费失败 / notarize 服务长期不可用 / 紧急 hotfix 需要在凭据失效时出包。

**回滚步骤**：

1. owner 用 ad-hoc 重新出包（保留 v1.2.4.1 行为）：
   ```
   RELEASE=0 NOTARIZE=0 CODESIGN_IDENTITY=- frontend/apple/scripts/package-macos-app.sh
   ```
   `RELEASE=0` 是默认值，脚本走 v1.2.4.1 ad-hoc 路径（保留向后兼容是 P0-4 的设计决策）。
2. **owner 必须先删除 v1.2.5 Developer ID 签的 app 留下的 Keychain item**，否则装 ad-hoc 包后启动会再次弹"100J 想要使用钥匙串中的机密信息"（与升级时镜像问题）：
   - 打开 Keychain Access → 登录 → 搜索 `top.linotsai.app.PersonalAffairs.auth` → 整项删除。
   - 启动 ad-hoc 签的 app → 重新登录 → 新 ACL 由 ad-hoc app 写入。
   - 后续每次 ad-hoc 重打包仍会再弹一次（owner-1 现状），点"始终允许"恢复 v1.2.4.1 行为。
3. **回滚不影响 widget**：iOS widget 与 macOS host app 是独立的发布通道；macOS 回滚 ad-hoc 不影响已部署的 iOS widget。
4. **服务端无回滚动作**：P0 是纯客户端打包脚本改动，不动后端。

**注意**：P0 回滚仅是临时应急，长期方案是续费 Apple Developer 或重新申请 Developer ID 证书。回滚 ad-hoc 后 owner-1 复发。

### 7.3 部署脚本

- 本期不改 `verify-release.sh` / `prod-check.sh`，无回滚动作。
- `package-macos-app.sh` 的 `RELEASE=1` 强制路径（P0）：dev 本地快速 iteration 时仍可用 `RELEASE=0`（默认）走 ad-hoc 路径，不需要凭据；只有 release 发布才必须凭据齐全。

### 7.3.1 P0 一次性迁移说明（v1.2.4.1 → v1.2.5）

从 ad-hoc 签的 v1.2.4.1 升到 Developer ID 签的 v1.2.5，macOS Keychain ACL 会**最后弹一次**"100J 想要使用钥匙串中的机密信息"——这是因为旧 Keychain item `top.linotsai.app.PersonalAffairs.auth` 的 ACL 是 ad-hoc app（不同 designated requirement）写的，新 Developer ID app 第一次访问需要 owner 批准 ACL 升级。

**owner 操作（任选其一）**：

- **选项 A（推荐，最省事）**：弹窗时点"始终允许"——macOS 把新 Developer ID requirement 加到该 keychain item 的 ACL 白名单。从此**永久不再弹**，所有未来 Developer ID 签的 v1.2.5+ 版本都被接受。
- **选项 B（最干净，0 弹窗）**：
  1. 装 v1.2.5 前打开 Keychain Access（钥匙串访问 app）→ 登录 → 搜索 `top.linotsai.app.PersonalAffairs.auth` → 整项删除。
  2. 启动 v1.2.5 → 重新登录账号 → 新 ACL 由 Developer ID app 写入，从设计上就只接受 Developer ID requirement。
  3. 0 弹窗。

升级后第 2 次启动起：**永久 0 弹窗**。如果第 2 次启动仍弹，说明 v1.2.5 的签名身份不稳定（不应发生，立即排查 `codesign -dvv` 输出对比上一次启动）。

deployment.md 的 "macOS Release Signing" 段（P0-7 引入）含同款 owner 指引。

### 7.4 灾难恢复路径

最坏情况：HZ 云生产库损坏，需从备份恢复 + 升级到 v1.2.5。

路径（**与 v1.2.4 相同**，本期不动后端）：

1. `pg_restore` 从最新备份。
2. `alembic current` 检查 revision（应该是备份时的 head，通常是 `0006_refresh_token_jti`）。
3. `alembic upgrade head` 跑到 head（v1.2.5 仍是 `0006`，应是 no-op）。
4. 验证 schema = `python -m scripts.check_alembic_drift`。
5. 重启 service。

---

## 8. Builder 执行顺序建议

1. 开新分支 `v1.2.5-dev` from `main`（HEAD `351106c`，tag `v1.2.4.1`）。
2. **P0 owner 部分 day-0 立即启动**：owner 当天提交 Apple Developer Program 注册（信用卡支付 $99），开启 1–2 天审批等待窗口。builder 不阻塞，进入步骤 3。
3. **P1 与 P0 并行**（day 0–2）：builder 全力推 P1（UX 重做）。建议拆 PR：
   - PR1：P1-1（InlineQuickAddRow 组件）+ P1-2（AppModel 4 个新方法）+ P1-3（PlanScreen 接入）+ P1-14（InlineQuickAddRowTests）+ P1-15（AppModelInlineCreateTests）。**先建后拆**，新功能先 land，确保 inline quick-add 在真机可用。
   - PR2：P1-4 ~ P1-13（删除 Composer 链路：hero 按钮 / shell sheet / shortcut / sparkles 图标 / Composer 文件 / 旧测试）。在 PR1 真机验证 inline quick-add 工作后再合 PR2 删旧路径，**降低回滚成本**。
   - 每个 PR 跑 `swift test` + `xcodebuild build` 全绿后才合。
4. **P0 builder 部分**：owner Apple 审批通过 + 拿到证书 + 完成 setup-codesign-credentials.sh 一次性配置后，builder 1 天内提交 P0 PR（package-macos-app.sh 改动 + setup-codesign-credentials.sh 新建 + .gitignore + deployment.md 段落）。owner 在本机跑通完整 `RELEASE=1` 流程并清单 §6.3 P0 全过后 merge。
5. **P2 第三**（P0 merge 后开）：owner 在 Xcode GUI 做 P2-1 ~ P2-6（一次完成，提一个 commit 含 pbxproj + entitlements + Info.plist）；builder 后续提 P2-7 测试 + P2-8 文档。
6. **P3 最后**：单独一个 PR，含版本号 + OpenAPI snapshot + deployment.md final review（含 P0 macOS Release Signing 段确认 + v1.2.5 Upgrade Notes 段）。
7. 跑 §6.1 / §6.2 / §6.3 全部清单，全绿后 `git tag v1.2.5` → 合 main → push。
8. App Store Connect 上传 archive → TestFlight beta → 灰度验证 → 推送至全部用户（仅 owner 一人）。

---

## 9. 长期路线说明（不在 v1.2.5 范围）

记录已知但**故意延后**的事项，避免误以为漏了：

- **macOS Widget extension**：本期仅做 iOS。macOS widget 需要独立的 widget extension target（不能复用 iOS 的），且需 App Group entitlement on macOS（与 iOS 不同声明方式）。延后到 v1.3.0 或 v1.2.6 单独处理。
- **Provisioning Profile 自动化**：发布前必须手动在 App Store Connect 配 widget App ID + profile；fastlane / xcode-cloud 自动化延后到运维优化期。
- **CalendarScreen quick-add**：owner 明确决定日程仍走点 cell 弹详情表单（v1.2.5 不动）。如未来希望日历也支持 inline 快速创建，可在 v1.3+ 引入。
- **TodayScreen quick-add**：owner 明确决定 Today 只看不记（v1.2.5 不加 inline quick-add 行）。

---

## 10. v1.2.6 路线（defer 自原 v1.2.5）

原 v1.2.5 计划中以下 2 项**完整原样**搬到 v1.2.6，理由：v1.2.5 优先 owner 实测发现的 UX 体验问题（P1 写入链路）。

### 10.1 reviewer #14 — Keyset 分页

- 内容：`backend/app/services/pagination.py` 从 OFFSET cursor 改为 keyset（按 `(updated_at, id) DESC`）；6 个 list endpoint 接入；新增 `0007_keyset_indexes` migration 加 6 个复合索引；model `__table_args__` 同步声明。
- 工作量：M（builder 全包，无 GUI）。
- 完整规格保留在 `PROJECT_PLAN_v1.2.4.md`（v1.2.4 deferred 段）+ 旧 v1.2.5 plan 的 P2 章节（可在 git history 找回，commit `351106c` 之前的 PROJECT_PLAN.md）。

### 10.2 reviewer #17 — Alembic 0001 重写

- 内容：把 `0001_initial_schema.py` 从 `Base.metadata.create_all` 改为显式 `op.create_table`，等价于 v1.0 时代 schema；新增 `scripts/check_alembic_0001_baseline.py` baseline 守卫；增强 `check_alembic_drift.py` 钉死 schema hash 到 `tests/__schema_hash__.txt`。
- 工作量：L（builder 推断 v1.0 schema + 重写 + owner 必须人工 review；高度依赖三路径 diff 验证）。
- 完整规格同上，保留在 git history。

### 10.3 为什么 defer

- v1.2.4.1 真机使用后，**owner 的痛感排序**：UX 写入 7 步 >> macOS 弹窗（已 workaround）>> Widget 空数据（已知 widget 没装） >> keyset 分页（不可见，单用户 0 并发实际无影响） >> Alembic 0001（不可见，仅在灾难恢复时才重要）。
- 本期容量有限（4 工作日单人），优先解决用户每天感知的问题（P1 写入路径 + P2 widget 真实可用 + P0 macOS 无骚扰）。
- keyset 与 Alembic 0001 的修复**没有时间压力**：单用户 0 并发，OFFSET cursor 实际不会出错；Alembic 0001 仅在 fresh install / 灾难恢复时才重要，HZ 生产库 alembic_version 已固定不会重跑 0001。

### 10.4 v1.2.6 预估

- 目标 tag = `v1.2.6`，build = `1.129`（v1.2.5 的 1.128 之后）。
- 内容 = 上述 2 项 + 必要的发布工程。
- 工作量预估 = L + M ≈ 5–7 工作日 builder（无 owner GUI 操作；owner 仅在 #17 三路径 diff 验证时介入 1–2 小时）。
- 启动时机 = v1.2.5 上 App Store + 灰度稳定 ≥ 3 天后。

---

## 变更日志

### [2026-05-24] 初版
- 覆盖 v1.2.4 deferred 的 3 项（reviewer #3 / #14 / #17）。4 phase（P1–P4），目标 v1.2.5 / build 1.127。

### [2026-05-27] 新增 P0 Apple Developer Program 接入
- 新增 Phase P0：Apple Developer Program 注册（$99/年）+ macOS Developer ID 签名 / 公证，覆盖 owner-1（Keychain 弹窗）+ 为 P1 widget App Group 铺路。详见 §3 P0 章节、§7.2 / §7.3.1。

### [2026-05-27] 范围大调整 — 推翻 Composer 链路
- 触发：owner 真机使用 v1.2.4.1 后反馈写入链路 UX 严重劣化（"记一条公司待办要 7 步"），决定完全推翻 Composer 写入链路。
- 新 phase 编号 = P0 / P1 / P2 / P3：
  - **P0** 原样保留（Apple Developer Program + macOS 签名）。
  - **P1（新增）** UX 重做 — 新增 `InlineQuickAddRow` + Plan 4 个 tab 各加 inline quick-add 行 + AppModel 加 4 个 direct-write 方法 + 删整条 Composer / CaptureParser 链路（4 个文件 + 6+ 处 hero 按钮 / shell sheet / shortcut / sparkles 图标 / AppShortcuts intent）+ 删 Composer 相关 swift test + 加 InlineQuickAddRow / AppModel inline-create test。后端零改动。
  - **P2（原 P1）** Widget extension 进 Xcode 工程，仅改 phase 编号。
  - **P3（原 P4，简化）** 发布工程，版本号 1.2.5 / build 1.128（P1 显式 release，build 跳 1）；本期不动 prod-check.sh / verify-release.sh（后端零改动）。
- **defer 到 v1.2.6**：原 P2（keyset 分页 / reviewer #14）+ 原 P3（Alembic 0001 重写 / reviewer #17），完整规格搬到新 §10。理由：v1.2.5 优先 owner 每天感知的体验问题。
- 测试基线：Swift 53 → 48–52；后端 86 → 86（不变）；Alembic 6 → 6（不变）。
- 依赖图：P0 → P2 是唯一硬依赖；P0 / P1 完全独立可并行；P3 等 P0/P1/P2 全部 merge。
- 文档影响：§1 / §2 / §3 / §5 / §6 / §7 / §8 / §9 全部按新范围重写；新增 §10 v1.2.6 路线段。
