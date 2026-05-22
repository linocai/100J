#if os(macOS)
import AppKit
import PersonalAffairsCore
import SwiftUI

struct MenuBarPanel: View {
    @ObservedObject var model: AppModel
    @State private var captureText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                BrandMark(size: 26)
                Text("100J")
                    .font(.headline.weight(.semibold))
                Spacer()
                SyncStatusDot(state: model.syncStatus)
            }

            Divider()

            if !model.todayViewModel.topThree.isEmpty {
                Text("今天 Top 3")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(model.todayViewModel.topThree.prefix(3)) { task in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                        Text(task.title)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Divider()
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                TextField("快速捕捉", text: $captureText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submitCapture)
                Button(action: submitCapture) {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            HStack {
                Button("打开 100J") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                Spacer()
                Button("退出") {
                    NSApp.terminate(nil)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 320)
    }

    private func submitCapture() {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            model.universalComposerViewModel.input = text
            _ = await model.submitUniversalComposer()
            captureText = ""
        }
    }
}
#endif
