import SwiftUI

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

    var defaultPadding: CGFloat {
        switch self {
        case .card, .subtle, .selected, .tinted, .warning:
            return AppTheme.Spacing.md
        case .sidebar:
            return AppTheme.Spacing.md
        default:
            return AppTheme.Spacing.lg
        }
    }

    var defaultRadius: CGFloat {
        switch self {
        case .card, .subtle, .selected, .tinted, .warning:
            return AppTheme.Radius.md
        case .sidebar:
            return AppTheme.Radius.lg
        default:
            return AppTheme.Radius.lg
        }
    }

    var borderColor: Color {
        switch self {
        case .selected(let style), .tinted(let style):
            return style.color.opacity(0.28)
        case .warning:
            return AppTheme.Colors.warningAccent.opacity(0.26)
        case .inspector:
            return AppTheme.Colors.agentAccent.opacity(0.16)
        default:
            return AppTheme.Colors.hairline
        }
    }

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

    func fill(_ scheme: ColorScheme) -> Color {
        switch self {
        case .elevated:
            return AppTheme.Colors.surfaceElevated
        case .selected(let style), .tinted(let style):
            return style.color.opacity(scheme == .dark ? 0.18 : 0.11)
        case .warning:
            return AppTheme.Colors.warningAccent.opacity(scheme == .dark ? 0.16 : 0.10)
        case .sidebar:
            return AppTheme.Colors.sidebarBackground.opacity(scheme == .dark ? 0.74 : 0.62)
        case .inspector:
            return AppTheme.Colors.surfaceElevated.opacity(scheme == .dark ? 0.72 : 0.68)
        case .card:
            return AppTheme.Colors.surfaceBase
        case .subtle:
            return AppTheme.Colors.surfaceTinted
        case .base:
            return AppTheme.Colors.surfaceBase
        }
    }
}

struct SurfaceView<Content: View>: View {
    let style: SurfaceStyle
    let cornerRadius: CGFloat?
    let padding: CGFloat?
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

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
        content
            .padding(resolvedPadding)
            .background(.regularMaterial, in: shape)
            .background {
                shape.fill(style.fill(colorScheme))
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(style.borderColor, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(style.shadowOpacity), radius: 18, x: 0, y: 10)
    }

    private var resolvedPadding: CGFloat {
        padding ?? style.defaultPadding
    }

    private var resolvedRadius: CGFloat {
        cornerRadius ?? style.defaultRadius
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
    }
}

struct SoftSurfaceView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SurfaceView(style: .subtle) {
            content
        }
    }
}
