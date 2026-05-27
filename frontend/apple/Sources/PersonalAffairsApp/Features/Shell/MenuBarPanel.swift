#if os(macOS)
import AppKit
import PersonalAffairsCore
import SwiftUI

/// v1.2.4.2 (P1-10): the inline "快速捕捉" field is gone — it was the menu-bar
/// entry point into the deleted Composer / CaptureParser chain. The panel
/// keeps the sync indicator, the Today Top 3 preview, and the open/quit
/// shortcuts. Owners who want to record an item now click into the main
/// window and use the Plan inline quick-add row instead.
struct MenuBarPanel: View {
    @ObservedObject var model: AppModel

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
}
#endif
