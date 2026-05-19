import SwiftUI

struct QuickCaptureBar: View {
    @Environment(\.workbenchLayout) private var layout
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let submit: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "sparkle.magnifyingglass")
                .foregroundStyle(AppTheme.Colors.agentAccent)
            TextField("输入任务、固定日程或灵感…", text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($isFocused)
                .onSubmit(submit)
            if !layout.isCompact {
                Text("⌘K")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.Colors.surfaceTinted)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xs, style: .continuous))
            }
        }
        .padding(.horizontal, layout.isCompact ? AppTheme.Spacing.md : AppTheme.Spacing.lg)
        .frame(height: 44)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(AppTheme.Colors.hairline, lineWidth: 1)
        }
        .overlay(alignment: .trailing) {
            Button("聚焦 Quick Capture") {
                isFocused = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
        }
        .accessibilityLabel("快速记录")
    }
}
