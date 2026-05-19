import PersonalAffairsCore
import SwiftUI

struct GlobalCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var filter: CalendarScopeFilter = .all
    @State private var selectedProjectId: String?
    @State private var displayedMonth = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingNewItem = false
    var selection: InspectorSelection? = nil
    var onSelectCalendarItem: (CalendarItem) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                SurfaceView(style: .elevated) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        filterBar
                        Text("有截止日期的待办仍然属于待办；只有固定日期 / 固定时间事项进入日历。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        calendarBoard
                    }
                }
            }
            .padding(layout.pagePadding)
        }
        .sheet(isPresented: $showingNewItem) {
            CalendarItemFormView(projects: model.projects) { draft in
                await model.createCalendarItem(draft)
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
        ViewThatFits(in: .horizontal) {
            horizontalFilterBar
            verticalFilterBar
        }
    }

    private var horizontalFilterBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            filterPicker
                .frame(width: min(320, max(240, layout.centerWidth * 0.32)))

            if filter == .project {
                projectPicker
                    .frame(width: min(220, max(160, layout.centerWidth * 0.22)))
            }
            Spacer()
            PillView(text: "待办不会自动进入日程", style: .warningSubtle)
        }
    }

    private var verticalFilterBar: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            filterPicker
            if filter == .project {
                projectPicker
            }
            PillView(text: "待办不会自动进入日程", style: .warningSubtle)
        }
    }

    private var filterPicker: some View {
        Picker("筛选", selection: $filter) {
            ForEach(CalendarScopeFilter.allCases) { scope in
                Text(scope.label).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .onValueChange(of: filter) { _ in Task { await reload() } }
    }

    private var projectPicker: some View {
        Picker("项目", selection: $selectedProjectId) {
            Text("选择").tag(Optional<String>.none)
            ForEach(model.projects) { project in
                Text(project.name).tag(Optional(project.id))
            }
        }
        .onValueChange(of: selectedProjectId) { _ in Task { await reload() } }
    }

    private var calendarBoard: some View {
        Group {
            if layout.usesWideColumns {
                HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                    monthBoard
                        .frame(minWidth: 0, maxWidth: .infinity)
                    verticalHairline
                    selectedDayAgenda
                        .frame(width: min(330, max(292, layout.centerWidth * 0.34)))
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    monthBoard
                    selectedDayAgenda
                }
            }
        }
    }

    private var monthBoard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            monthToolbar
            monthGrid
        }
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(AppTheme.Colors.hairline)
            .frame(width: 1)
    }

    private var monthToolbar: some View {
        ViewThatFits(in: .horizontal) {
            fullMonthToolbar
            compactMonthToolbar
        }
    }

    private var fullMonthToolbar: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("上个月")

            Text(Self.monthTitleFormatter.string(from: CalendarViewState.startOfMonth(displayedMonth)))
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

    private var compactMonthToolbar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("上个月")

            Text(Self.monthTitleFormatter.string(from: CalendarViewState.startOfMonth(displayedMonth)))
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("下个月")

            Spacer(minLength: AppTheme.Spacing.sm)

            Button("今天") {
                displayedMonth = Date()
                selectedDate = Calendar.current.startOfDay(for: Date())
            }
            .buttonStyle(.bordered)
        }
    }

    private var monthGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(minimum: layout.isCompact ? 34 : 52), spacing: layout.isCompact ? 4 : AppTheme.Spacing.sm),
            count: 7
        )
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
                        .frame(minHeight: dayCellHeight)
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
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    agendaSection("All-day", items: selectedDayItems.filter(\.allDay))
                    agendaSection("Timed Events", items: selectedDayItems.filter { !$0.allDay })
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surfaceTinted)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    private func agendaSection(_ title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
            if items.isEmpty {
                Text(title == "All-day" ? "没有全天事项。" : "没有具体时间事项。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            } else {
                ForEach(items) { item in
                    CalendarEventCardView(
                        item: item,
                        spaceName: model.spaceLabel(for: item.spaceId),
                        spaceStyle: spaceStyle(item.spaceId),
                        projectName: model.projectName(for: item.projectId),
                        isSelected: selection == .calendarItem(item.id),
                        compact: true,
                        onSelect: { onSelectCalendarItem(item) },
                        onDelete: { delete(item) }
                    )
                }
            }
        }
    }

    private var sortedItems: [CalendarItem] {
        CalendarViewState.sortedItems(model.calendarItems)
    }

    private var selectedDayItems: [CalendarItem] {
        CalendarViewState.items(on: selectedDate, from: model.calendarItems)
    }

    private var agendaEmptyTitle: String {
        filter == .project && selectedProjectId == nil ? "先选择项目" : "这天没有固定日程"
    }

    private var agendaEmptyMessage: String {
        filter == .project && selectedProjectId == nil ? "选择一个公司项目后，只显示这个项目的固定日程。" : "选择其他日期，或新建一条固定日程。"
    }

    private var monthDays: [Date?] {
        CalendarViewState.monthDays(displayedMonth: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = Self.weekdayFormatter.shortStandaloneWeekdaySymbols ?? Self.weekdayFormatter.shortWeekdaySymbols
        guard let symbols, symbols.count == 7 else { return ["日", "一", "二", "三", "四", "五", "六"] }
        let firstIndex = Calendar.current.firstWeekday - 1
        return Array(symbols[firstIndex..<symbols.count]) + Array(symbols[0..<firstIndex])
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let dayItems = CalendarViewState.items(on: date, from: model.calendarItems)
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
                            .foregroundStyle(isSelected ? AppTheme.Colors.companyAccent : AppTheme.Colors.surfaceElevated)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(isSelected ? AppTheme.Colors.surfaceElevated : AppTheme.Colors.companyAccent)
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dayItems.prefix(2)) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isSelected ? eventAccent(for: item).opacity(0.82) : eventAccent(for: item))
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
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(layout.isCompact ? 6 : 10)
            .frame(maxWidth: .infinity, minHeight: dayCellHeight, alignment: .topLeading)
            .background(dayBackground(isSelected: isSelected, isToday: isToday))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(dayBorder(isSelected: isSelected, isToday: isToday), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func dayBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return AppTheme.Colors.companyAccent.opacity(0.14)
        }
        if isToday {
            return AppTheme.Colors.warningAccent.opacity(0.12)
        }
        return AppTheme.Colors.surfaceBase
    }

    private var dayCellHeight: CGFloat {
        layout.isCompact ? 68 : 92
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

    private func changeMonth(by value: Int) {
        let nextMonth = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: CalendarViewState.startOfMonth(displayedMonth)
        ) ?? displayedMonth
        displayedMonth = nextMonth
        selectedDate = CalendarViewState.startOfMonth(nextMonth)
    }

    private func spaceStyle(_ spaceId: String) -> PillStyle {
        model.spaces.first { $0.id == spaceId }?.type == .personal ? .personal : .company
    }

    private func reload() async {
        guard let query = CalendarViewState.query(
            filter: filter,
            selectedProjectId: selectedProjectId,
            personalSpaceId: model.personalSpace?.id,
            companySpaceId: model.companySpace?.id
        ) else {
            await MainActor.run {
                model.calendarItems = []
            }
            return
        }
        await model.reloadCalendar(query: query)
    }

    private func delete(_ item: CalendarItem) {
        Task { await model.deleteCalendarItem(item) }
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

private struct CalendarItemFormView: View {
    let projects: [Project]
    let save: (CalendarDraftState) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CalendarDraftState()

    var body: some View {
        EditorSheetView(
            title: "新建固定日程",
            subtitle: "这里只放固定日期、约会、纪念日、订阅到期、截止日和提醒。",
            isActionDisabled: draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            cancel: { dismiss() },
            action: {
                Task {
                    await save(draft)
                    dismiss()
                }
            }
        ) {
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
        }
    }
}
