import PersonalAffairsCore
import SwiftUI

struct PlanView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case personal
        case company
        case projects
        case notes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .personal: return "个人"
            case .company: return "公司"
            case .projects: return "项目"
            case .notes: return "笔记"
            }
        }

        var systemImage: String {
            switch self {
            case .personal: return "person"
            case .company: return "building.2"
            case .projects: return "folder"
            case .notes: return "note.text"
            }
        }
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var tab: Tab = .personal

    var selection: InspectorSelection?
    let selectTask: (TaskItem) -> Void
    let selectProject: (Project) -> Void
    let selectNote: (Note) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Plan", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                Group {
                    switch tab {
                    case .personal:
                        taskSection(
                            title: "个人待办",
                            subtitle: "弹性处理，不自动进入日历。",
                            tasks: model.planViewModel.personalItems,
                            spaceStyle: .personal,
                            spaceLabel: "个人"
                        )
                    case .company:
                        taskSection(
                            title: "公司待办",
                            subtitle: "项目任务和无项目任务在这里统一收束。",
                            tasks: model.planViewModel.companyItems,
                            spaceStyle: .company,
                            spaceLabel: "公司"
                        )
                    case .projects:
                        projectSection
                    case .notes:
                        noteSection
                    }
                }
                .transition(.opacity)
            }
            .padding(layout.pagePadding)
        }
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.universalComposerViewModel.open()
                } label: {
                    Label("新建", systemImage: "plus")
                }
            }
        }
    }

    private func taskSection(
        title: String,
        subtitle: String,
        tasks: [TaskItem],
        spaceStyle: PillStyle,
        spaceLabel: String
    ) -> some View {
        GroupBox {
            if tasks.isEmpty {
                EmptyStateInline(title: "暂无\(title)", message: "按 ⌘K 用一句话创建新事项。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        PlanTaskRow(
                            task: task,
                            projectName: model.projectName(for: task.projectId),
                            spaceStyle: spaceStyle,
                            spaceLabel: spaceLabel,
                            isSelected: selection == .task(task.id),
                            select: { selectTask(task) },
                            toggle: { Task { await model.toggleTaskDone(task) } },
                            archive: { Task { await model.archiveTask(task) } }
                        )
                        Divider()
                    }
                }
            }
        } label: {
            PlanSectionLabel(title: title, subtitle: subtitle, systemImage: spaceStyle == .personal ? "checklist" : "building.2")
        }
    }

    private var projectSection: some View {
        GroupBox {
            if model.planViewModel.projectItems.isEmpty {
                EmptyStateInline(title: "暂无项目", message: "公司里的长期事项可以沉淀为项目。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.planViewModel.projectItems) { project in
                        PlanProjectRow(
                            project: project,
                            activeTaskCount: model.companyTasks.filter { $0.projectId == project.id && $0.status == .active }.count,
                            isSelected: selection == .project(project.id),
                            select: { selectProject(project) }
                        )
                        Divider()
                    }
                }
            }
        } label: {
            PlanSectionLabel(title: "项目", subtitle: "只承载公司里的阶段性成果。", systemImage: "folder")
        }
    }

    private var noteSection: some View {
        GroupBox {
            if model.planViewModel.noteItems.isEmpty {
                EmptyStateInline(title: "暂无笔记", message: "灵感和备忘先记下，再决定是否转行动。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.planViewModel.noteItems) { note in
                        PlanNoteRow(
                            note: note,
                            isSelected: selection == .note(note.id),
                            select: { selectNote(note) },
                            convert: { Task { await model.convertNoteToTask(note) } },
                            archive: { Task { await model.archiveNote(note) } }
                        )
                        Divider()
                    }
                }
            }
        } label: {
            PlanSectionLabel(title: "笔记", subtitle: "Inbox，不急着变成任务。", systemImage: "note.text")
        }
    }
}

private struct PlanSectionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.indigo)
        }
    }
}

private struct PlanTaskRow: View {
    let task: TaskItem
    let projectName: String?
    let spaceStyle: PillStyle
    let spaceLabel: String
    let isSelected: Bool
    let select: () -> Void
    let toggle: () -> Void
    let archive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? Color.green : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: select) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.indigo : .primary)
                        .strikethrough(task.status == .done)
                        .lineLimit(2)
                    if let description = task.description?.trimmedOrNil {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    WrappingHStack(spacing: 6, rowSpacing: 5) {
                        PillView(text: task.priority.label, style: task.priority.pillStyle)
                        if let dueDate = task.dueDate {
                            PillView(text: "截止 \(dueDate)", style: .warningSubtle, systemImage: "calendar.badge.clock")
                        }
                        if let projectName {
                            PillView(text: projectName, style: .company, systemImage: "folder")
                        } else {
                            PillView(text: spaceLabel, style: spaceStyle)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: archive) {
                Image(systemName: "archivebox")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("归档")
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct PlanProjectRow: View {
    let project: Project
    let activeTaskCount: Int
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder")
                    .foregroundStyle(isSelected ? Color.indigo : .secondary)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.indigo : .primary)
                    if let description = project.description?.trimmedOrNil {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    WrappingHStack(spacing: 6, rowSpacing: 5) {
                        PillView(text: project.status.label, style: project.status.pillStyle)
                        PillView(text: "\(activeTaskCount) 个进行中", style: .company)
                        if let targetDate = project.targetDate {
                            PillView(text: "目标 \(targetDate)", style: .warningSubtle)
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PlanNoteRow: View {
    let note: Note
    let isSelected: Bool
    let select: () -> Void
    let convert: () -> Void
    let archive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: select) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: note.type.systemImage)
                        .foregroundStyle(isSelected ? Color.purple : .secondary)
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.title?.trimmedOrNil ?? "未命名")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.purple : .primary)
                        Text(note.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        WrappingHStack(spacing: 6, rowSpacing: 5) {
                            PillView(text: note.type.label, style: note.type.pillStyle)
                            if note.linkedTaskId != nil {
                                PillView(text: "已转待办", style: .success)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: convert) {
                Image(systemName: "arrow.triangle.branch")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("转为待办")

            Button(action: archive) {
                Image(systemName: "archivebox")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("归档")
        }
        .padding(.vertical, 10)
    }
}
