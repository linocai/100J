import SwiftUI

struct QuickCaptureBar: View {
    @Binding var text: String
    let submit: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "command")
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            TextField("快速记录：待办、固定日程、灵感……", text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .onSubmit(submit)
            Text("K")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(height: 36)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityLabel("Quick capture")
    }
}
