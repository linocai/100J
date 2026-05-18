import PersonalAffairsCore
import SwiftUI

struct GlobalCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter = "all"
    @State private var selectedProjectId: String?
    @State private var displayedMonth = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
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
                        calendarBoard
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
                            startDate: draft.allDay ? draft.startDate.dayKey : nil,
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

    private var calendarBoard: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                monthToolbar
                monthGrid
            }
            .frame(minWidth: 620)

            Divider()

            selectedDayAgenda
                .frame(width: 330)
        }
    }

    private var monthToolbar: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("上个月")

            Text(Self.monthTitleFormatter.string(from: startOfMonth(displayedMonth)))
                .font(.title3.weight(.semibold))

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("下个月")

            Button("今天") {
                displayedMonth = Date()
                selectedDate = Calendar.current.startOfDay(for: Date())
            }
            .buttonStyle(.bordered)

            Spacer()

            PillView(text: "\(model.calendarItems.count) 条固定日程", style: .neutralSubtle)
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 76), spacing: AppTheme.Spacing.sm), count: 7)
        return LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
            ForEach(weekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(monthDays.enumerated()), id: \.offset) { entry in
                if let date = entry.element {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(minHeight: 92)
                }
            }
        }
    }

    private var selectedDayAgenda: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.dayTitleFormatter.string(from: selectedDate))
                        .font(.headline.weight(.semibold))
                    Text(Calendar.current.isDateInToday(selectedDate) ? "今天" : "\(selectedDayItems.count) 条日程")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                Button {
                    showingNewItem = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("新建日程")
            }

            if selectedDayItems.isEmpty {
                EmptyStateInline(title: agendaEmptyTitle, message: agendaEmptyMessage)
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(selectedDayItems) { item in
                        CalendarEventCardView(
                            item: item,
                            spaceName: model.spaceLabel(for: item.spaceId),
                            spaceStyle: spaceStyle(item.spaceId),
                            projectName: model.projectName(for: item.projectId),
                            isSelected: true,
                            compact: true,
                            onSelect: { onSelectCalendarItem(item) },
                            onDelete: { delete(item) }
                        )
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color.white.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    private var sortedItems: [CalendarItem] {
        sortedCalendarItems(model.calendarItems)
    }

    private var selectedDayItems: [CalendarItem] {
        items(on: selectedDate)
    }

    private var agendaEmptyTitle: String {
        filter == "project" && selectedProjectId == nil ? "先选择项目" : "这天没有固定日程"
    }

    private var agendaEmptyMessage: String {
        filter == "project" && selectedProjectId == nil ? "选择一个公司项目后，只显示这个项目的固定日程。" : "选择其他日期，或新建一条固定日程。"
    }

    private var monthDays: [Date?] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(displayedMonth)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let leadingBlanks = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        let trailingBlanks = (7 - days.count % 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: trailingBlanks))
        return days
    }

    private var weekdaySymbols: [String] {
        let symbols = Self.weekdayFormatter.shortStandaloneWeekdaySymbols ?? Self.weekdayFormatter.shortWeekdaySymbols
        guard let symbols, symbols.count == 7 else { return ["日", "一", "二", "三", "四", "五", "六"] }
        let firstIndex = Calendar.current.firstWeekday - 1
        return Array(symbols[firstIndex..<symbols.count]) + Array(symbols[0..<firstIndex])
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let dayItems = items(on: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)

        Button {
            selectedDate = Calendar.current.startOfDay(for: date)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.callout.weight(isSelected || isToday ? .bold : .semibold))
                    Spacer()
                    if !dayItems.isEmpty {
                        Text("\(dayItems.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? AppTheme.Colors.companyAccent : .white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(isSelected ? Color.white : AppTheme.Colors.companyAccent)
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dayItems.prefix(2)) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.82) : eventAccent(for: item))
                                .frame(width: 5, height: 5)
                            Text(item.title)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                        }
                    }
                    if dayItems.count > 2 {
                        Text("+\(dayItems.count - 2)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? .white.opacity(0.82) : AppTheme.Colors.tertiaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .white : AppTheme.Colors.primaryText)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(dayBackground(isSelected: isSelected, isToday: isToday))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(dayBorder(isSelected: isSelected, isToday: isToday), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func items(on date: Date) -> [CalendarItem] {
        sortedItems.filter { item in
            guard let itemDate = calendarSortDate(item) else { return false }
            return Calendar.current.isDate(itemDate, inSameDayAs: date)
        }
    }

    private func dayBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return AppTheme.Colors.companyAccent.opacity(0.92)
        }
        if isToday {
            return AppTheme.Colors.warningAccent.opacity(0.12)
        }
        return Color.white.opacity(0.50)
    }

    private func dayBorder(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return AppTheme.Colors.companyAccent.opacity(0.45)
        }
        if isToday {
            return AppTheme.Colors.warningAccent.opacity(0.32)
        }
        return Color.primary.opacity(0.06)
    }

    private func eventAccent(for item: CalendarItem) -> Color {
        switch item.type {
        case .subscriptionExpiry, .anniversary:
            return AppTheme.Colors.warningAccent
        case .deadline:
            return AppTheme.Colors.dangerAccent
        default:
            return spaceStyle(item.spaceId) == .personal ? AppTheme.Colors.personalAccent : AppTheme.Colors.companyAccent
        }
    }

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func changeMonth(by value: Int) {
        let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: startOfMonth(displayedMonth)) ?? displayedMonth
        displayedMonth = nextMonth
        selectedDate = startOfMonth(nextMonth)
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
            } else {
                await MainActor.run {
                    model.calendarItems = []
                }
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

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }()

    private static let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
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
    var startDate = Date()
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
                    DatePicker("开始日期", selection: $draft.startDate, displayedComponents: .date)
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
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 540)
    }
}
