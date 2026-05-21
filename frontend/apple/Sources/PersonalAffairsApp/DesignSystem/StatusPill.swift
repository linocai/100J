import SwiftUI

/// HTML demo 中的 `.tag` pill 对应物：圆角 999、12% tint 底色、accent 文字。
struct StatusPill: View {
    let text: String
    var color: Color = AppTheme.Status.neutral
    var systemImage: String?
    var size: Size = .regular

    enum Size {
        case small
        case regular

        var font: Font {
            switch self {
            case .small: return .caption2.weight(.semibold)
            case .regular: return .caption.weight(.semibold)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .regular: return 3
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(size.font)
            }
            Text(text)
                .lineLimit(1)
                .font(size.font)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .foregroundStyle(color)
        .background(color.opacity(0.14), in: Capsule())
        .accessibilityLabel(text)
    }
}

extension StatusPill {
    init(text: String, style: PillStyle, size: Size = .regular, systemImage: String? = nil) {
        self.init(text: text, color: style.color, systemImage: systemImage, size: size)
    }
}
