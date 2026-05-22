import SwiftUI

/// HTML demo 中的 `.group` 卡片对应物：圆角 14、轻 shadow、可选 tint。
/// macOS 用 `.regularMaterial` 让卡片自带细微毛玻璃；iOS 用系统 grouped 风。
struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color?
    let padding: CGFloat?
    let content: Content

    init(
        cornerRadius: CGFloat = AppTheme.Glass.cardCorner,
        tint: Color? = nil,
        padding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding ?? AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape
                    #if os(macOS)
                    .fill(.regularMaterial)
                    #else
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    #endif
            }
            .overlay {
                if let tint {
                    shape.fill(tint.opacity(0.10))
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: 10, x: 0, y: 4
            )
    }

    private var shadowOpacity: Double {
        #if os(macOS)
        return 0.06
        #else
        return 0.04
        #endif
    }
}

/// 内嵌一行 "Row" 容器（带 hover-friendly tap）。
struct CardRow<Content: View>: View {
    let action: (() -> Void)?
    let content: Content

    init(action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        if let action {
            Button(action: action) {
                rowBody
            }
            .buttonStyle(.plain)
        } else {
            rowBody
        }
    }

    private var rowBody: some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
