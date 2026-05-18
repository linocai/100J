import SwiftUI

struct CommandTopBar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var quickCaptureText: String
    let onSubmitQuickCapture: () -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text((model.selectedSection ?? .today).title)
                    .font(.headline.weight(.semibold))
                HStack(spacing: 6) {
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                        Text("Syncing")
                    } else {
                        Image(systemName: "checkmark.icloud")
                        Text("Ready")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(width: 190, alignment: .leading)

            QuickCaptureBar(text: $quickCaptureText, submit: onSubmitQuickCapture)
                .frame(maxWidth: 680)

            Spacer(minLength: AppTheme.Spacing.md)

            Button {
                Task { await model.refreshAll() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh data")

            Button(action: onNew) {
                Label("New", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}
