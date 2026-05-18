import PersonalAffairsCore
import SwiftUI

struct LooseEndsPanel: View {
    @EnvironmentObject private var model: AppModel
    let tasks: [TaskItem]
    let selectTask: (TaskItem) -> Void
    let showMore: () -> Void

    var body: some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No Project Inbox")
                            .font(.headline.weight(.semibold))
                        Text("Company tasks without project_id are still company tasks, not a new status.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sort", action: showMore)
                        .font(.caption.weight(.semibold))
                }

                if tasks.isEmpty {
                    EmptyStateInline(
                        title: "Inbox is clear",
                        message: "No loose company tasks need project triage."
                    )
                } else {
                    TaskCardList {
                        ForEach(tasks) { task in
                            TaskCardView(
                                task: task,
                                projectName: nil,
                                spaceStyle: .company,
                                spaceLabel: "Company",
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
