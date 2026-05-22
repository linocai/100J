# Apple Client Sharing Rules

## 红线

1. 任何 API 调用、过滤、排序、状态机逻辑必须写在 `PersonalAffairsCore/ViewModels/`。
2. `Features/iOS/*` 与 `Features/Personal|Company|Calendar|Agent/*` 只能写 SwiftUI 布局。
3. 同一份业务校验出现在两个端，PR 必须 reject。
4. 新增 ViewModel 必须配套写 `PersonalAffairsCoreTests/<Name>Tests.swift` 或更新等价测试文件。

## 红线之外的合理偏差

- 平台特定 UI（`NSAttributedString` / `UIBarButtonItem`）可以分平台写。
- 平台特定快捷键（⌘N vs swipe action）属于布局。
- 适配 Liquid Glass / 各自工具栏的私有 modifier 属于布局。
