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
                        Text("无项目收件箱")
                            .font(.headline.weight(.semibold))
                        Text("无项目公司任务仍然是公司任务，不是第四种任务状态。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("整理", action: showMore)
                        .font(.caption.weight(.semibold))
                }

                if tasks.isEmpty {
                    EmptyStateInline(
                        title: "收件箱已清空",
                        message: "没有需要归类项目的公司任务。"
                    )
                } else {
                    TaskCardList {
                        ForEach(tasks) { task in
                            TaskCardView(
                                task: task,
                                projectName: nil,
                                spaceStyle: .company,
                                spaceLabel: "公司",
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
