import SwiftUI

/// 行内空状态：用在 GroupBox / SurfaceView 内部，作为"还没有内容"的占位条。
/// v1.1 起从 Features/Today/FocusStackPanel.swift 迁出，全 App 共用。
struct EmptyStateInline: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
        )
    }
}

struct EmptyStateCardView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        SurfaceView {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        }
    }
}
