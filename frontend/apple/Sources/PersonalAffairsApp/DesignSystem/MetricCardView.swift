import SwiftUI

struct MetricCardView: View {
    let title: String
    let value: String
    let caption: String
    var style: PillStyle = .neutral
    var systemImage: String = "circle.grid.2x2"

    var body: some View {
        SurfaceView(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(style.color)
                    .frame(width: 28, height: 28)
                    .background(style.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
