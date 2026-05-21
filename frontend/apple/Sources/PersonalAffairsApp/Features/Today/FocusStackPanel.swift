import PersonalAffairsCore
import SwiftUI

struct FocusStackPanel: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let subtitle: String
    let tasks: [TaskItem]
    let spaceLabel: String
    let spaceStyle: PillStyle
    let selectTask: (TaskItem) -> Void
    let showMore: () -> Void

    var body: some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("查看全部", action: showMore)
                        .font(.caption.weight(.semibold))
                }

                if tasks.isEmpty {
                    EmptyStateInline(
                        title: "这里暂时不急",
                        message: "出现弹性事项时，用 Quick Capture 记录为待办。"
                    )
                } else {
                    TaskCardList {
                        ForEach(tasks) { task in
                            TaskCardView(
                                task: task,
                                projectName: model.projectName(for: task.projectId),
                                spaceStyle: spaceStyle,
                                spaceLabel: spaceLabel,
                                compact: true,
                                onSelect: { selectTask(task) },
                                onComplete: { mutateTask(.complete, task) },
                                onReopen: { mutateTask(.reopen, task) },
                                onArchive: { mutateTask(.archive, task) }
                            )
                        }
                    }
                }
            }
        }
    }

    private enum Mutation {
        case complete
        case reopen
        case archive
    }

    private func mutateTask(_ mutation: Mutation, _ task: TaskItem) {
        Task {
            switch mutation {
            case .complete:
                await model.completeTask(task)
            case .reopen:
                await model.reopenTask(task)
            case .archive:
                await model.archiveTask(task)
            }
        }
    }
}

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
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
    }
}
