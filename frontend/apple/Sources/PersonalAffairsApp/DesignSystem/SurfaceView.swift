import SwiftUI

/// v1.1 起 SurfaceView 退化为 `GroupBox` 的薄包装：
///   - 几何与阴影完全交给系统（macOS/iOS GroupBox + .regularMaterial）
///   - 仅保留 `style.tint` 语义（warning / tinted / selected 仍可染色）
/// 旧 API（`style` / `cornerRadius` / `padding`）保持不变，避免破坏调用方。
enum SurfaceStyle {
    case base
    case elevated
    case selected(PillStyle = .company)
    case tinted(PillStyle)
    case warning
    case sidebar
    case inspector
    case card
    case subtle

    /// 状态色：有色 → GroupBox 外叠一层 10% 着色作为提示；无 → 完全系统外观。
    var tint: Color? {
        switch self {
        case .warning:
            return AppTheme.Colors.warningAccent
        case .selected(let pill), .tinted(let pill):
            return pill.color
        case .base, .elevated, .sidebar, .inspector, .card, .subtle:
            return nil
        }
    }
}

struct SurfaceView<Content: View>: View {
    let style: SurfaceStyle
    let cornerRadius: CGFloat?
    let padding: CGFloat?
    let content: Content

    init(
        style: SurfaceStyle = .base,
        cornerRadius: CGFloat? = nil,
        padding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
                .padding(padding ?? 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(SurfaceTintModifier(tint: style.tint, cornerRadius: cornerRadius ?? AppTheme.Radius.md))
    }
}

struct SoftSurfaceView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SurfaceView { content }
    }
}

private struct SurfaceTintModifier: ViewModifier {
    let tint: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if let tint {
            content
                .background(
                    tint.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
        }
    }
}
