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
                    Button("View all", action: showMore)
                        .font(.caption.weight(.semibold))
                }

                if tasks.isEmpty {
                    EmptyStateInline(
                        title: "Nothing pressing here",
                        message: "Capture a task when flexible work appears."
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
            await model.run {
                switch mutation {
                case .complete:
                    _ = try await model.taskRepository.complete(id: task.id)
                case .reopen:
                    _ = try await model.taskRepository.reopen(id: task.id)
                case .archive:
                    _ = try await model.taskRepository.archive(id: task.id)
                }
                try await model.loadAllData()
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
