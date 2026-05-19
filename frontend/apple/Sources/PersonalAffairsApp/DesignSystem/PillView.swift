import SwiftUI

enum PillStyle: Equatable {
    case neutral
    case neutralSubtle
    case personal
    case company
    case calendar
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
        case .calendar:
            return AppTheme.Colors.calendarAccent
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

enum PillSize {
    case small
    case normal

    var font: Font {
        switch self {
        case .small: return .caption2.weight(.semibold)
        case .normal: return .caption.weight(.semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 7
        case .normal: return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 3
        case .normal: return 4
        }
    }
}

struct PillView: View {
    let text: String
    var style: PillStyle = .neutral
    var systemImage: String?
    var size: PillSize = .normal

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(size.font)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .foregroundStyle(style.color)
        .background(style.color.opacity(style.backgroundOpacity))
        .clipShape(Capsule())
        .accessibilityLabel(text)
    }
}
