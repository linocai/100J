import SwiftUI

enum PillStyle {
    case neutral
    case neutralSubtle
    case personal
    case company
    case agent
    case warning
    case warningSubtle
    case danger
    case success

    var color: Color {
        switch self {
        case .neutral, .neutralSubtle:
            return .secondary
        case .personal:
            return AppTheme.Colors.personalAccent
        case .company:
            return AppTheme.Colors.companyAccent
        case .agent:
            return AppTheme.Colors.agentAccent
        case .warning, .warningSubtle:
            return AppTheme.Colors.warningAccent
        case .danger:
            return AppTheme.Colors.dangerAccent
        case .success:
            return AppTheme.Colors.successAccent
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .neutralSubtle, .warningSubtle:
            return 0.08
        default:
            return 0.13
        }
    }
}

struct PillView: View {
    let text: String
    var style: PillStyle = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(style.color)
        .background(style.color.opacity(style.backgroundOpacity))
        .clipShape(Capsule())
        .accessibilityLabel(text)
    }
}
