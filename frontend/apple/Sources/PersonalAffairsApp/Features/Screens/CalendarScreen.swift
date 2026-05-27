import PersonalAffairsCore
import SwiftUI

/// HTML `.scene-calendar` 1:1 翻译。月视图 + 当日 Agenda。
struct CalendarScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var anchorDate = Date()
    @State private var selectedDate = Date()
    @State private var scopeFilter: CalendarScopeFilter = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                header
                Picker("范围", selection: $scopeFilter) {
                    ForEach(CalendarScopeFilter.allCases, id: \.self) { f in
                        Text(filterLabel(f)).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                grid
            }
            .padding(.horizontal, AdaptivePageLayout.horizontalPadding)
            .padding(.top, AdaptivePageLayout.topPadding)
            .padding(.bottom, AdaptivePageLayout.bottomPadding)
            .frame(maxWidth: AdaptivePageLayout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onChange(of: scopeFilter) { _, _ in Task { await reload() } }
        .task { await reload() }
    }

    private func filterLabel(_ f: CalendarScopeFilter) -> String {
        switch f {
        case .all: return "All"
        case .personal: return "个人"
        case .company: return "公司"
        case .project: return "项目"
        }
    }

    private var header: some View {
        // v1.2.4.2 (P1-5): the "新建日程" AdaptiveHeroActionButton was
        // removed with the Composer chain. Owners still create calendar
        // items the traditional way (tap a day cell → detail sheet); the
        // month stepper stays in the actions slot so navigation works.
        AdaptiveHeroHeader(
            eyebrow: "日程",
            title: monthTitle,
            subtitle: "只显示固定时间事项；弹性待办在 Plan 里。",
            accent: .orange
        ) {
            monthStepper
        }
    }

    private var monthStepper: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: 4) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                    .buttonStyle(.bordered)
                Button {
                    anchorDate = Date()
                    selectedDate = Date()
                } label: {
                    Text("今天")
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 44, minHeight: 28)
                }
                    .buttonStyle(.bordered)
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: anchorDate)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: anchorDate) {
            anchorDate = d
        }
    }

    private var grid: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
            monthGridCard.frame(maxWidth: .infinity)
            agendaCard.frame(maxWidth: .infinity)
        }
        #else
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            monthGridCard
            agendaCard
        }
        #endif
    }

    private var monthGridCard: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: "月视图", subtitle: "中文起始日 · 周日")
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)
                MonthGrid(anchor: anchorDate, selected: $selectedDate, items: model.calendarItems)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
            }
        }
    }

    private var agendaCard: some View {
        let items = CalendarViewState.items(on: selectedDate, from: model.calendarItems)
        return GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: dateTitle, subtitle: items.isEmpty ? "今天没有固定日程" : "\(items.count) 项")
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)
                if items.isEmpty {
                    Text("点击月视图上的日子来查看那天的日程。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(AppTheme.Spacing.lg)
                } else {
                    ForEach(items) { item in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        CardRow {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Text(timeLabel(item))
                                    .font(.callout.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(item.type == .deadline ? .red : .orange)
                                    .frame(width: 56, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.body).lineLimit(1)
                                    Text(itemSubtitle(item))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                StatusPill(text: item.type.rawValue,
                                           style: item.type.pillStyle,
                                           size: .small)
                            }
                        }
                    }
                }
            }
        }
    }

    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 · EEEE"
        return f.string(from: selectedDate)
    }

    private func timeLabel(_ item: CalendarItem) -> String {
        if item.allDay { return "全天" }
        guard let startAt = item.startAt else { return "定时" }
        return startAt.compactTime
    }

    private func itemSubtitle(_ item: CalendarItem) -> String {
        let space = model.spaceLabel(for: item.spaceId)
        if let project = model.projectName(for: item.projectId) {
            return "\(space) · \(project)"
        }
        return space
    }

    private func reload() async {
        guard let personal = model.personalSpace, let company = model.companySpace else {
            await model.refreshAll()
            return
        }
        let query: CalendarListQuery
        switch scopeFilter {
        case .all, .project:
            query = .all(personalSpaceId: personal.id, companySpaceId: company.id)
        case .personal:
            query = .personal(spaceId: personal.id)
        case .company:
            query = .company(spaceId: company.id)
        }
        await model.reloadCalendar(query: query)
    }
}

// MARK: - Month grid

private struct MonthGrid: View {
    let anchor: Date
    @Binding var selected: Date
    let items: [CalendarItem]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                    Text(d)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.id) { day in
                    DayCell(day: day, hasEvent: hasEvent(day))
                        .onTapGesture {
                            if let d = day.date { selected = d }
                        }
                }
            }
        }
    }

    private struct DayInfo: Identifiable {
        let id: Int
        let displayNumber: Int
        let date: Date?
        let inMonth: Bool
        let isToday: Bool
        let isSelected: Bool
    }

    private var days: [DayInfo] {
        let cal = Calendar.current
        var cal2 = cal; cal2.firstWeekday = 1
        let firstOfMonth = cal2.date(from: cal2.dateComponents([.year, .month], from: anchor))!
        let weekday = cal2.component(.weekday, from: firstOfMonth) - 1
        let range = cal2.range(of: .day, in: .month, for: firstOfMonth)!.count
        let prevMonth = cal2.date(byAdding: .month, value: -1, to: firstOfMonth)!
        let prevRange = cal2.range(of: .day, in: .month, for: prevMonth)!.count
        let today = cal2.startOfDay(for: Date())
        let selectedDay = cal2.startOfDay(for: selected)
        var result: [DayInfo] = []
        for i in 0..<weekday {
            let d = prevRange - weekday + 1 + i
            result.append(DayInfo(id: -i - 1, displayNumber: d, date: nil, inMonth: false, isToday: false, isSelected: false))
        }
        for d in 1...range {
            let date = cal2.date(byAdding: .day, value: d - 1, to: firstOfMonth)!
            let dayStart = cal2.startOfDay(for: date)
            result.append(DayInfo(
                id: d,
                displayNumber: d,
                date: date,
                inMonth: true,
                isToday: dayStart == today,
                isSelected: dayStart == selectedDay
            ))
        }
        let tail = (7 - result.count % 7) % 7
        for i in 0..<tail {
            result.append(DayInfo(id: 100 + i, displayNumber: i + 1, date: nil, inMonth: false, isToday: false, isSelected: false))
        }
        return result
    }

    private func hasEvent(_ day: DayInfo) -> Bool {
        guard let date = day.date else { return false }
        return !CalendarViewState.items(on: date, from: items).isEmpty
    }

    private struct DayCell: View {
        let day: DayInfo
        let hasEvent: Bool
        var body: some View {
            ZStack {
                if day.isSelected {
                    Circle().fill(Color.orange).frame(width: 32, height: 32)
                } else if day.isToday {
                    Circle().strokeBorder(Color.orange, lineWidth: 1.5).frame(width: 32, height: 32)
                }
                Text("\(day.displayNumber)")
                    .font(.callout.weight(day.isSelected ? .semibold : .regular))
                    .foregroundStyle(textColor)
                if hasEvent && !day.isSelected {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                        .offset(y: 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .contentShape(Rectangle())
        }

        private var textColor: Color {
            if day.isSelected { return .white }
            if !day.inMonth { return Color.secondary.opacity(0.5) }
            if day.isToday { return .orange }
            return .primary
        }
    }
}

extension CalendarItemType {
    var label: String {
        switch self {
        case .appointment: return "事件"
        case .anniversary: return "纪念"
        case .subscriptionExpiry: return "订阅"
        case .deadline: return "截止"
        case .reminder: return "提醒"
        }
    }
}
