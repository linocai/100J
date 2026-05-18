import SwiftUI

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
