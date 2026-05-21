# 100J macOS 视觉舒适度修改方案 v1

> 已并入 v1.1_final_plan.md §3，视觉细节以本文件为准

> 作者：资深前端面板设计师视角
> 目标：**只调视觉舒适度，不动信息架构、不改交互逻辑、不增减面板**
> 时间预算：1 个下午（约 8 处定点修改，全部位于 `DesignSystem/` 与 `Features/Shell/`）

---

## TL;DR — 你看到"丑"和"单调"的真正来源

打开 Mac 端看到的视觉问题，归根结底是 **三层叠加事故**：

| 层级 | 文件 | 问题 |
|---|---|---|
| 底层 | `AppBackgroundView.swift` | 顶左角有一坨 `companyAccent`（蓝紫色）径向渐变，半径 560pt，正好覆盖整个侧边栏 |
| 中层 | `MacSidebarView.swift:37` | 侧边栏用 `sidebarBackground.opacity(0.54)` 半透明面板，**挡不住底层的蓝色血晕** |
| 上层 | `SurfaceView.swift:113` | 每一张卡片都挂着 `y=10 radius=18 opacity=0.08` 的硬投影 |

结果就是：**侧边栏区域看起来像被一片蓝灰色雾气糊住**，每张内层卡片下面又掉了一块阴影砸在这片雾上。
你叫它"阴影遮罩"，本质是 **底层色彩透过半透明面板溢出 + 上层卡片投影撞色** 的复合产物。

"单调"则来自于：所有 SurfaceView 用一样的 fill、一样的 18pt 圆角、一样的边框 hairline、一样的阴影参数 —— **整页都是同一种灰色色块在做加法**。

---

## 一、修掉侧边栏的"阴影遮罩"（优先级 P0，4 处修改）

### 1.1 干掉侧边栏的蓝色血晕（最关键的一步）

**文件**：`Sources/PersonalAffairsApp/DesignSystem/AppBackgroundView.swift`

当前顶左角的径向渐变是用 `companyAccent`（饱和的蓝紫色）画的，半径 560pt 直接铺到侧边栏右边界。要做的事：**把它从"侧边栏头顶的色块"挪到"中间画布的远处装饰"**。

```swift
// 现状（AppBackgroundView.swift:9-17）
RadialGradient(
    colors: [
        AppTheme.Colors.companyAccent.opacity(colorScheme == .dark ? 0.18 : 0.10),
        .clear
    ],
    center: .topLeading,
    startRadius: 24,
    endRadius: 560
)

// 改为：中心位移到右上、降低饱和度、改用中性暖灰色
RadialGradient(
    colors: [
        Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035),
        .clear
    ],
    center: UnitPoint(x: 0.78, y: 0.12),  // 远离侧边栏
    startRadius: 40,
    endRadius: 520
)
```

把底下那个 `agentAccent` 渐变也用同样的方式淡化：opacity 0.16/0.08 → 0.05/0.025，颜色从 `agentAccent` 换成 `Color.primary`。

**理由**：彩色径向渐变是 2018 年那一波 "glassmorphism" 的视觉残留，在生产力工具里只会让眼睛累。100J 这种工具属性的 App 应该是 **中性背景 + 偶发的强调色**，不是反过来。

### 1.2 把侧边栏背景换成系统材质

**文件**：`Sources/PersonalAffairsApp/Features/Shell/MacSidebarView.swift:37`

```swift
// 现状
.background(AppTheme.Colors.sidebarBackground.opacity(0.54))

// 改为
.background(.regularMaterial)
.overlay(alignment: .trailing) {
    Rectangle()
        .fill(Color.primary.opacity(0.05))
        .frame(width: 1)
}
```

**理由**：`.regularMaterial` 是 SwiftUI 给到的原生 NSVisualEffectView 包装，会自动处理 vibrancy 与 dark mode，看起来就是 Finder / Notes / Reminders 那种舒服的毛玻璃，而不是一层手糊的半透明 paint。最右边那条 1pt 的暗色描边替代了原本 `MacWorkbenchShellView` 里的 `verticalHairline`（见 1.4）。

### 1.3 删掉 sidebar 内部卡片的硬阴影

**文件**：`Sources/PersonalAffairsApp/DesignSystem/SurfaceView.swift:49-58`

```swift
// 现状
var shadowOpacity: Double {
    switch self {
    case .elevated, .inspector:
        return 0.08
    case .base:
        return 0.05
    default:
        return 0.025
    }
}

// 改为：让 sidebar、subtle、tinted 一类完全不挂阴影
var shadowOpacity: Double {
    switch self {
    case .elevated:
        return 0.06
    case .inspector:
        return 0.05
    case .base:
        return 0.03
    case .sidebar, .subtle, .tinted, .selected, .warning, .card:
        return 0
    }
}
```

同时把 `body` 里的阴影参数收紧（`SurfaceView.swift:113`）：

```swift
// 现状
.shadow(color: Color.black.opacity(style.shadowOpacity), radius: 18, x: 0, y: 10)

// 改为
.shadow(color: Color.black.opacity(style.shadowOpacity), radius: 12, x: 0, y: 4)
```

**理由**：`y=10 radius=18` 是 hero card 的参数，**不是常驻面板的参数**。100J 里每一张 SurfaceView 都顶着这套，所以页面看起来"湿漉漉"。`y=4 radius=12` 是 macOS 系统 popup 的典型阴影手感，足够把卡片"轻轻抬起来"而不会糊脸。`shadowOpacity = 0` 对侧边栏内部的 Core Rule 卡尤其重要 —— 它现在是侧边栏里唯一一个有硬阴影的元素，**看起来就像贴了块创可贴**。

### 1.4 软化侧边栏 / 主区分隔线

**文件**：`Sources/PersonalAffairsApp/Features/Shell/MacWorkbenchShellView.swift:120-124`

```swift
// 现状
private var verticalHairline: some View {
    Rectangle()
        .fill(AppTheme.Colors.hairline)
        .frame(width: 1)
}

// 改为
private var verticalHairline: some View {
    Rectangle()
        .fill(Color.primary.opacity(0.06))
        .frame(width: 1)
}
```

也把 `horizontalHairline` 同步改掉。

**理由**：`AppTheme.Colors.hairline` 是 `separatorColor.opacity(0.72)`，在 macOS 上 separator 系统色本身已经够明显，再 × 0.72 反而过度。改成 `Color.primary.opacity(0.06)` 之后，在浅色模式是接近 #00000010 的发丝线，在深色模式自动反相 —— 不再像"硬塑料板拼接缝"。

---

## 二、缓解"单调感"（优先级 P1，4 处微调）

### 2.1 给 hero header 加一条 accent 色脊柱

**文件**：`Sources/PersonalAffairsApp/DesignSystem/SectionHeaderView.swift`（你已有，建议在 hero style 那一支里加 4 行）

每个 section 在头部加一条 3pt × 36pt 的圆头小竖线，颜色取自该 section 的 accent：

```
┃ 系统
┃ Agent
┃ 事务助理负责解析、预演和审核；危险操作必须确认。
```

实现伪代码（放在 SectionHeaderView 的 hero 布局最前面）：

```swift
HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
    RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(accent)
        .frame(width: 3)
        .frame(maxHeight: 44)
    VStack(alignment: .leading, spacing: 4) {
        // 原本的 eyebrow / title / subtitle
    }
    Spacer()
    // 原本的 action slot
}
```

`accent` 通过新参数从调用方传入（个人页传 `personalAccent`、公司页传 `companyAccent`、Calendar 传 `calendarAccent`、Agent 传 `agentAccent`）。

**理由**：当前 7 个 section 顶部长得几乎一模一样（一个 SF Symbol + 一行标题 + 一行副标题）。**3pt 一条彩条 = 0 信息密度增加 + 强烈的"我在哪个分区"提示**。比给每个页面塞背景色卡有效得多。

### 2.2 调圆角到呼吸感更好的尺度

**文件**：`Sources/PersonalAffairsApp/DesignSystem/AppTheme.swift:19-25`

```swift
// 现状
enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

// 改为
enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10   // pill / chip
    static let md: CGFloat = 14   // card
    static let lg: CGFloat = 20   // surface
    static let xl: CGFloat = 26   // hero
}
```

**理由**：14 / 20 这个组合更贴近 macOS Sonoma 之后的系统圆角 vibes（系统窗口 10pt，Sheet 16pt，Quick Look 22pt）。12 / 18 看起来略显锐利，特别是在 Retina 2x 上。

### 2.3 让 PillView 的"弱版"再淡一档

**文件**：`Sources/PersonalAffairsApp/UI/PillView.swift`（或你 PillStyle 定义的位置）

把 `.neutralSubtle` / `.warningSubtle` 这一档的 background opacity 从当前值（应该是 0.10~0.14 这一区间）**砍半到 0.05~0.07**，文字色保持。

**理由**：当前同一个页面经常 5~7 个 pill 横排（"需要审批"、"待办不会进日程"、"3 条固定日程"…），每个 pill 都是中等饱和。降低弱版的 opacity，**强版才显得"亮"**。这是用对比制造节奏，不是减信息。

### 2.4 收紧侧边栏 SidebarButton 的视觉冗余

**文件**：`Sources/PersonalAffairsApp/Features/Shell/MacSidebarView.swift:120-128`

当前 SidebarButton **同时** 用：
- 左侧 3pt accent 色竖条（选中时出现）
- 图标的圆角方块底色（任何时候都有，选中时变浓）
- 整个按钮的 itemBackground（选中时变浓）
- 选中时再加 1pt 边框

四种"我被选中了"的提示，重复了。建议改为：

```swift
// 选中态：仅"3pt 竖条 + itemBackground 变浓"
// 未选态：图标方块底色取消，只留图标本身
.background(isSelected ? accent.opacity(0.13) : Color.clear)  // 第 127 行那个 accent.opacity 改成这样
```

并把 `.overlay { RoundedRectangle ... stroke ... }` 那个 1pt 边框删掉。

**理由**：减少 1 层视觉噪音 = 选中态更利落，未选态更干净。这是侧边栏长期看着累的次要原因。

---

## 三、可选的"画龙点睛"（优先级 P2，留给闲的时候）

这些不是 bug 修复，是 nice-to-have，只在你觉得做完 P0/P1 还想再润一层的时候做。

- **品牌 logo 那个 J 字母方块**（`MacSidebarView.swift:42-53`）：当前是 `companyAccent → agentAccent` 蓝紫渐变。整个 App 唯一的高饱和元素，但跟其他视觉语言没有任何呼应。考虑要么改成 **单色 `agentAccent`**（与底部 Core Rule 卡呼应），要么 **把 brand 区域整块 ↑ 升级成一个 mini surface**（带 hover），让它真的是一个可点击的"home"按钮。
- **`Core Rule` 卡的措辞**：当前"待办保持弹性；固定时间进入日程；Agent 只做整理和建议。"信息密度太高，眼睛读不进去。改成 3 行短句 + 行间留白，或者干脆 **改成 3 个一行的小 bullet**。
- **CommandTopBar 高度收缩 2~4pt**：当前顶栏视觉上偏厚，看着像 Linear/Asana 那种"在 web 上模仿桌面"的样子。在原生 macOS 上稍微压扁一点，工具属性更纯。

---

## 四、改完之后的预期效果

- 侧边栏区域不再透出蓝色血晕，看起来像 Apple 自家的 Finder/Reminders 那种磨砂玻璃
- 每张卡片下面的"湿漉漉"投影消失，整页是干爽的
- 进入每个 section 第一眼看到的是 **一条该 section 颜色的小竖条**，而不是清一色灰底 + 灰 hairline
- 选中态的侧边栏按钮只剩"竖条 + 浅底"，不再像有四个图层在抢话语权

**修改文件清单**（共 5 个文件，估算 < 60 行 diff）：

```
DesignSystem/AppBackgroundView.swift       — 1.1
DesignSystem/AppTheme.swift                — 2.2
DesignSystem/SurfaceView.swift             — 1.3
Features/Shell/MacSidebarView.swift        — 1.2, 2.4
Features/Shell/MacWorkbenchShellView.swift — 1.4
UI/PillView.swift（按你的实际路径）          — 2.3
DesignSystem/SectionHeaderView.swift        — 2.1（如果做 P1）
```

不动 iOS 层、不动 ViewState、不动 AppModel、不动任何 Feature 视图的内容。
