import SwiftUI

/// 头像圆形徽章，用在 sidebar 底部 / iOS 状态栏。
struct AvatarBadge: View {
    let initial: String
    var size: CGFloat = 30
    var gradient: LinearGradient = .init(
        colors: [Color.orange, Color.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Text(initial.uppercased())
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient, in: Circle())
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

/// 品牌方块（沿用 HTML demo 的 J indigo→purple 渐变）。
struct BrandMark: View {
    var size: CGFloat = 32
    var letter: String = "J"

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [.indigo, .purple],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .shadow(color: .indigo.opacity(0.45), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

/// 同步状态指示点。
struct SyncStatusDot: View {
    let state: AppSyncStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch state {
        case .offline: return .red
        case .syncing: return .orange
        case .synced: return .green
        case .error: return .orange
        }
    }

    private var label: String {
        switch state {
        case .offline: return "离线"
        case .syncing: return "同步中"
        case .synced: return "已同步"
        case .error: return "需要关注"
        }
    }
}
