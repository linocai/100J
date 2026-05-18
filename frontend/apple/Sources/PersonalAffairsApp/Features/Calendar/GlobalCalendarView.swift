import PersonalAffairsCore
import SwiftUI

struct GlobalCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter = "all"
    @State private var selectedProjectId: String?
    @State private var showingNewItem = false
    var onSelectCalendarItem: (CalendarItem) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                SurfaceView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        filterBar
                        Text("有截止日期的待办仍然属于待办；只有固定日期 / 固定时间事项进入日历。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if model.calendarItems.isEmpty {
                            EmptyStateCardView(
                                title: "暂无固定日程",
                                message: "约会、纪念日、订阅到期和提醒都放在这里。",
                                systemImage: "calendar"
                            )
                        } else {
                            agendaGroup("今天", items: todayItems)
                            agendaGroup("明天", items: tomorrowItems)
                            agendaGroup("本周", items: weekItems)
                            agendaGroup("更晚", items: laterItems)
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .sheet(isPresented: $showingNewItem) {
            CalendarItemFormView(projects: model.projects) { draft in
                let targetSpace = draft.spaceType == .personal ? model.personalSpace : model.companySpace
                guard let space = targetSpace else { return }
                await model.run {
                    _ = try await model.calendarRepository.create(
                        CalendarItemCreateRequest(
                            spaceId: space.id,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            type: draft.type,
                            allDay: draft.allDay,
                            startDate: draft.allDay ? draft.startDate.trimmedOrNil : nil,
                            startAt: draft.allDay ? nil : draft.startAt,
                            timezone: TimeZone.current.identifier,
                            recurrence: draft.recurrence,
                            projectId: draft.spaceType == .company ? draft.projectId : nil
                        )
                    )
                    try await model.loadAllData()
                }
            }
        }
        .task { await reload() }
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "系统",
            title: "固定日程",
            subtitle: "这里只承载固定日期、固定时间、纪念日和订阅到期。",
            systemImage: "calendar"
        ) {
            Button {
                showingNewItem = true
            } label: {
                Label("新建日程", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filterBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Picker("筛选", selection: $filter) {
                Text("全部").tag("all")
                Text("个人").tag("personal")
                Text("公司").tag("company")
                Text("项目").tag("project")
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .onChange(of: filter) { _ in Task { await reload() } }

            if filter == "project" {
                Picker("项目", selection: $selectedProjectId) {
                    Text("选择").tag(Optional<String>.none)
                    ForEach(model.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .frame(width: 180)
                .onChange(of: selectedProjectId) { _ in Task { await reload() } }
            }
            Spacer()
            PillView(text: "待办不会自动进入日程", style: .warningSubtle)
        }
    }

    private func agendaGroup(_ title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
            if items.isEmpty {
                Text("没有固定日程。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(items) { item in
                        CalendarEventCardView(
                            item: item,
                            spaceName: model.spaceLabel(for: item.spaceId),
                            spaceStyle: spaceStyle(item.spaceId),
                            projectName: model.projectName(for: item.projectId),
                            onSelect: { onSelectCalendarItem(item) },
                            onDelete: { delete(item) }
                        )
                    }
                }
            }
        }
    }

    private var sortedItems: [CalendarItem] {
        sortedCalendarItems(model.calendarItems)
    }

    private var todayItems: [CalendarItem] {
        sortedItems.filter { item in
            guard let date = calendarSortDate(item) else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

    private var tomorrowItems: [CalendarItem] {
        sortedItems.filter { item in
            guard let date = calendarSortDate(item) else { return false }
            return Calendar.current.isDateInTomorrow(date)
        }
    }

    private var weekItems: [CalendarItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let upper = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        return sortedItems.filter { item in
            guard let date = calendarSortDate(item) else { return false }
            return date >= dayAfterTomorrow && date <= upper
        }
    }

    private var laterItems: [CalendarItem] {
        let upper = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return sortedItems.filter { item in
            guard let date = calendarSortDate(item) else { return false }
            return date > upper
        }
    }

    private func spaceStyle(_ spaceId: String) -> PillStyle {
        model.spaces.first { $0.id == spaceId }?.type == .personal ? .personal : .company
    }

    private func reload() async {
        switch filter {
        case "personal":
            await model.reloadCalendar(filter: .personal)
        case "company":
            await model.reloadCalendar(filter: .company)
        case "project":
            if let selectedProjectId {
                await model.reloadCalendar(filter: .project(selectedProjectId))
            }
        default:
            await model.reloadCalendar(filter: .all)
        }
    }

    private func delete(_ item: CalendarItem) {
        Task {
            await model.run {
                _ = try await model.calendarRepository.delete(id: item.id)
                try await model.loadAllData()
            }
        }
    }
}

private struct CalendarItemRow: View {
    let item: CalendarItem
    let space: String
    let project: String
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(item.allDay ? .orange : .blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    BadgeText(text: space, color: space == "个人" ? .green : .blue)
                    BadgeText(text: item.type.label)
                    BadgeText(text: item.allDay ? (item.startDate ?? "全天") : (item.startAt?.shortDateTime ?? "定时"))
                    if item.projectId != nil {
                        BadgeText(text: project, color: .blue)
                    }
                    if item.source == "agent" {
                        BadgeText(text: "Agent", color: .indigo)
                    }
                }
            }
            Spacer()
            Button(action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("删除")
        }
        .padding(.vertical, 6)
    }

    private var icon: String {
        switch item.type {
        case .appointment: return "calendar"
        case .anniversary: return "gift"
        case .subscriptionExpiry: return "creditcard"
        case .deadline: return "flag"
        case .reminder: return "bell"
        }
    }
}

private struct CalendarDraft {
    var spaceType: SpaceType = .personal
    var title = ""
    var description = ""
    var type: CalendarItemType = .appointment
    var allDay = false
    var startDate = ""
    var startAt = Date()
    var recurrence: Recurrence = .none
    var projectId: String?
}

private struct CalendarItemFormView: View {
    let projects: [Project]
    let save: (CalendarDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CalendarDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "新建固定日程", subtitle: "这里只放固定日期、约会、纪念日、订阅到期、截止日和提醒。")
            Form {
                Picker("空间", selection: $draft.spaceType) {
                    ForEach(SpaceType.allCases) { space in
                        Text(space.label).tag(space)
                    }
                }
                TextField("标题", text: $draft.title)
                TextField("描述", text: $draft.description, axis: .vertical)
                Picker("类型", selection: $draft.type) {
                    ForEach(CalendarItemType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                Toggle("全天", isOn: $draft.allDay)
                if draft.allDay {
                    TextField("开始日期 (YYYY-MM-DD)", text: $draft.startDate)
                } else {
                    DatePicker("开始时间", selection: $draft.startAt)
                }
                Picker("重复", selection: $draft.recurrence) {
                    ForEach(Recurrence.allCases) { recurrence in
                        Text(recurrence.label).tag(recurrence)
                    }
                }
                if draft.spaceType == .company {
                    Picker("项目", selection: $draft.projectId) {
                        Text("无项目").tag(Optional<String>.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    Task {
                        await save(draft)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (draft.allDay && draft.startDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 540)
    }
}
