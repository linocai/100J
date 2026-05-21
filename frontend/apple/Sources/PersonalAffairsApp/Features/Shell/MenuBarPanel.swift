import PersonalAffairsCore
import SwiftUI

#if os(macOS)
import AppKit

struct MenuBarPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top 3")
                    .font(.headline.weight(.semibold))
                Spacer()
                SyncStatusDot(state: model.syncStatus)
            }

            if model.todayViewModel.topThree.isEmpty {
                Text("今天还没有焦点任务。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(model.todayViewModel.topThree) { task in
                    MenuBarTaskRow(task: task)
                }
            }

            Divider()

            TextField("快速捕捉", text: $model.menuBarCaptureText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await model.submitMenuBarCapture() }
                }

            HStack {
                Button("打开 100J") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

private struct MenuBarTaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Text(task.priority.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct SyncStatusDot: View {
    let state: AppSyncStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("同步状态：\(label)")
    }

    private var color: Color {
        switch state {
        case .offline: return .gray
        case .syncing: return .orange
        case .synced: return .green
        case .error: return .red
        }
    }

    private var label: String {
        switch state {
        case .offline: return "Offline"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .error: return "Error"
        }
    }
}
#endif
