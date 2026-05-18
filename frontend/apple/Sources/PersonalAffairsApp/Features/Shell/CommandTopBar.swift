import SwiftUI

struct CommandTopBar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var quickCaptureText: String
    @FocusState.Binding var isQuickCaptureFocused: Bool
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
                        Text("同步中")
                    } else {
                        Image(systemName: "checkmark.icloud")
                        Text("已同步")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(width: 184, alignment: .leading)

            QuickCaptureBar(text: $quickCaptureText, isFocused: $isQuickCaptureFocused, submit: onSubmitQuickCapture)
                .frame(maxWidth: 680)

            Spacer(minLength: AppTheme.Spacing.md)

            Button {
                Task { await model.refreshAll() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("刷新数据")

            Button(action: onNew) {
                Label("新建", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(.leading, 104)
        .padding(.trailing, AppTheme.Spacing.xl)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.thinMaterial)
    }
}
