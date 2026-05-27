import PersonalAffairsCore
import SwiftUI

/// HTML `.scene-plan` 1:1 翻译。顶部 SegmentedControl 4 个 Tab：个人/公司/项目/笔记。
struct PlanScreen: View {
    enum Segment: String, CaseIterable, Identifiable {
        case personal, company, projects, notes
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
        /// v1.2.4.2 P1-3: inline quick-add placeholder shown above the list
        /// in each tab. Format mirrors the Notes / Linear-style "+ ..."
        /// affordance so the row reads as a single create-action target.
        var quickAddPlaceholder: String {
            switch self {
            case .personal: return "+ 记一条个人待办，按 Enter ↵"
            case .company:  return "+ 记一条公司待办，按 Enter ↵"
            case .projects: return "+ 新建项目，按 Enter ↵"
            case .notes:    return "+ 记一条灵感，按 Enter ↵"
            }
        }
    }

    @EnvironmentObject private var model: AppModel
    @State private var segment: Segment = .personal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                header
                Picker("Plan", selection: $segment) {
                    ForEach(Segment.allCases) { s in
                        Label(s.title, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                quickAdd

                content
            }
            .padding(.horizontal, AdaptivePageLayout.horizontalPadding)
            .padding(.top, AdaptivePageLayout.topPadding)
            .padding(.bottom, AdaptivePageLayout.bottomPadding)
            .frame(maxWidth: AdaptivePageLayout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear { model.planViewModel.refresh() }
    }

    private var header: some View {
        // v1.2.4.2 (P1-3): the "新建" AdaptiveHeroActionButton was removed;
        // quick-add now sits inline below the segment picker. The hero title
        // / subtitle visuals are preserved.
        AdaptiveHeroHeader(
            eyebrow: "规划",
            title: "Plan",
            subtitle: "个人事项保持弹性；公司事项可挂项目；项目与笔记按需展开。",
            accent: .indigo
        )
    }

    /// v1.2.4.2 P1-3: tab-specific inline quick-add row. Direct POST, no
    /// Agent, no confirmation. Returning `true` clears the field; `false`
    /// keeps the typed text so the user can fix it (AppModel will have
    /// surfaced an `errorMessage` for the toast / banner).
    @ViewBuilder
    private var quickAdd: some View {
        switch segment {
        case .personal:
            InlineQuickAddRow(placeholder: segment.quickAddPlaceholder) { title in
                await model.createPersonalTask(title: title)
            }
        case .company:
            InlineQuickAddRow(placeholder: segment.quickAddPlaceholder) { title in
                await model.createCompanyTask(title: title)
            }
        case .projects:
            InlineQuickAddRow(placeholder: segment.quickAddPlaceholder) { title in
                await model.createProject(name: title)
            }
        case .notes:
            InlineQuickAddRow(placeholder: segment.quickAddPlaceholder) { title in
                await model.createNote(title: title)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch segment {
        case .personal:
            taskList(title: "个人待办",
                     subtitle: "弹性处理，不自动进入日历。",
                     items: model.planViewModel.personalItems,
                     emptyTitle: "暂无个人待办")
        case .company:
            taskList(title: "公司事项",
                     subtitle: "可挂项目；保留 Top 3 焦点策略。",
                     items: model.planViewModel.companyItems,
                     emptyTitle: "暂无公司待办")
        case .projects:
            projectList
        case .notes:
            noteList
        }
    }

    // MARK: Task list

    private func taskList(title: String, subtitle: String, items: [TaskItem], emptyTitle: String) -> some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: title, subtitle: subtitle, systemImage: nil)
                    Spacer()
                    Text("\(items.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                if items.isEmpty {
                    Text(emptyTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(AppTheme.Spacing.lg)
                } else {
                    ForEach(items) { task in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        TaskListRow(task: task) {
                            Task { await model.toggleTaskDone(task) }
                        }
                        .environmentObject(model)
                    }
                }
            }
        }
    }

    // MARK: Projects

    private var projectList: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: "项目", subtitle: "仅公司空间")
                    Spacer()
                    Text("\(model.planViewModel.projectItems.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                if model.planViewModel.projectItems.isEmpty {
                    Text("暂无项目。可以让 Agent 把一组任务合并成项目。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(AppTheme.Spacing.lg)
                } else {
                    ForEach(model.planViewModel.projectItems) { project in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        CardRow {
                            HStack(spacing: AppTheme.Spacing.md) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.indigo)
                                    .frame(width: 8, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name).font(.body.weight(.medium))
                                    Text(projectSubtitle(project)).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                StatusPill(text: project.status.rawValue,
                                           style: project.status.pillStyle,
                                           size: .small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func projectSubtitle(_ project: Project) -> String {
        let activeTasks = model.companyTasks.filter { $0.projectId == project.id && $0.status == .active }.count
        return "\(activeTasks) 个进行中任务"
    }

    // MARK: Notes

    private var noteList: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: "笔记", subtitle: "仅个人空间")
                    Spacer()
                    Text("\(model.planViewModel.noteItems.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                if model.planViewModel.noteItems.isEmpty {
                    Text("暂无笔记。灵感先记下，再决定是否转成行动。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(AppTheme.Spacing.lg)
                } else {
                    ForEach(model.planViewModel.noteItems) { note in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        CardRow {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: note.type.systemImage)
                                    .foregroundStyle(note.type == .idea ? .pink : .mint)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title?.nilIfBlank ?? String(note.body.prefix(40)))
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(note.type.label).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if note.linkedTaskId == nil {
                                    Button {
                                        Task { await model.convertNoteToTask(note) }
                                    } label: {
                                        Image(systemName: "arrow.right.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.indigo)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension NoteType {
    var label: String {
        switch self {
        case .idea: return "灵感"
        case .memo: return "备忘录"
        }
    }
}

struct TaskListRow: View {
    @EnvironmentObject private var model: AppModel
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        CardRow(action: onToggle) {
            HStack(spacing: AppTheme.Spacing.md) {
                CheckCircle(done: task.status == .done)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.status == .done)
                        .foregroundStyle(task.status == .done ? .secondary : .primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                StatusPill(text: task.priority.label,
                           style: task.priority.pillStyle,
                           size: .small)
            }
        }
    }

    private var subtitle: String {
        var bits: [String] = []
        if let name = model.projectName(for: task.projectId) {
            bits.append(name)
        }
        if let due = task.dueDate {
            bits.append(due)
        }
        if bits.isEmpty {
            bits.append(task.status.label)
        }
        return bits.joined(separator: " · ")
    }
}
