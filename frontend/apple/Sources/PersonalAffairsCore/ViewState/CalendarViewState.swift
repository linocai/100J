import Foundation

public enum CalendarScopeFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case personal
    case company
    case project

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: return "全部"
        case .personal: return "个人"
        case .company: return "公司"
        case .project: return "项目"
        }
    }
}

public enum CalendarListQuery: Equatable {
    case all(personalSpaceId: String, companySpaceId: String)
    case personal(spaceId: String)
    case company(spaceId: String)
    case project(companySpaceId: String, projectId: String)
}

public struct CalendarDraftState: Equatable {
    public var spaceType: SpaceType
    public var title: String
    public var description: String
    public var type: CalendarItemType
    public var allDay: Bool
    public var startDate: Date
    public var startAt: Date
    public var recurrence: Recurrence
    public var hasReminder: Bool
    public var remindAt: Date
    public var projectId: String?

    public init(
        spaceType: SpaceType = .personal,
        title: String = "",
        description: String = "",
        type: CalendarItemType = .appointment,
        allDay: Bool = false,
        startDate: Date = Date(),
        startAt: Date = Date(),
        recurrence: Recurrence = .none,
        hasReminder: Bool = false,
        remindAt: Date = Date(),
        projectId: String? = nil
    ) {
        self.spaceType = spaceType
        self.title = title
        self.description = description
        self.type = type
        self.allDay = allDay
        self.startDate = startDate
        self.startAt = startAt
        self.recurrence = recurrence
        self.hasReminder = hasReminder
        self.remindAt = remindAt
        self.projectId = projectId
    }

    public init(item: CalendarItem, companySpaceId: String?) {
        self.init(
            spaceType: item.spaceId == companySpaceId ? .company : .personal,
            title: item.title,
            description: item.description ?? "",
            type: item.type,
            allDay: item.allDay,
            startDate: CalendarViewState.parsedDateOnly(item.startDate) ?? Date(),
            startAt: item.startAt ?? Date(),
            recurrence: item.recurrence ?? .none,
            hasReminder: item.remindAt != nil,
            remindAt: item.remindAt ?? item.startAt ?? Date(),
            projectId: item.projectId
        )
    }

    public var trimmedDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func createRequest(spaceId: String, timezone: String = TimeZone.current.identifier) -> CalendarItemCreateRequest {
        CalendarItemCreateRequest(
            spaceId: spaceId,
            title: title,
            description: trimmedDescription,
            type: type,
            allDay: allDay,
            startDate: allDay ? CalendarViewState.dayKey(startDate) : nil,
            startAt: allDay ? nil : startAt,
            timezone: timezone,
            recurrence: recurrence,
            remindAt: hasReminder ? remindAt : nil,
            projectId: spaceType == .company ? projectId : nil
        )
    }

    public func updateRequest(timezone: String = TimeZone.current.identifier) -> CalendarItemUpdateRequest {
        // P4-4 (#4): the backend now normalises mismatched all-day vs timed
        // fields, but keep a debug-only assert so future encoder regressions
        // (e.g. accidentally sending startAt while allDay==true) surface
        // during development rather than as 422s in production.
        let encodedStartDate = allDay ? CalendarViewState.dayKey(startDate) : nil
        let encodedStartAt: Date? = allDay ? nil : startAt
        assert(
            !allDay || (encodedStartDate != nil && encodedStartAt == nil),
            "all-day calendar update must encode startDate and omit startAt"
        )
        return CalendarItemUpdateRequest(
            title: title,
            description: trimmedDescription,
            type: type,
            allDay: allDay,
            startDate: encodedStartDate,
            startAt: encodedStartAt,
            timezone: timezone,
            recurrence: recurrence,
            remindAt: hasReminder ? remindAt : nil,
            projectId: spaceType == .company ? projectId : nil
        )
    }
}

public enum CalendarViewState {
    public static func query(
        filter: CalendarScopeFilter,
        selectedProjectId: String?,
        personalSpaceId: String?,
        companySpaceId: String?
    ) -> CalendarListQuery? {
        switch filter {
        case .all:
            guard let personalSpaceId, let companySpaceId else { return nil }
            return .all(personalSpaceId: personalSpaceId, companySpaceId: companySpaceId)
        case .personal:
            guard let personalSpaceId else { return nil }
            return .personal(spaceId: personalSpaceId)
        case .company:
            guard let companySpaceId else { return nil }
            return .company(spaceId: companySpaceId)
        case .project:
            guard let companySpaceId, let selectedProjectId else { return nil }
            return .project(companySpaceId: companySpaceId, projectId: selectedProjectId)
        }
    }

    public static func sortedItems(_ items: [CalendarItem], calendar: Calendar = .current) -> [CalendarItem] {
        items.sorted { lhs, rhs in
            let lhsDay = dayKey(for: lhs, calendar: calendar) ?? "9999-12-31"
            let rhsDay = dayKey(for: rhs, calendar: calendar) ?? "9999-12-31"
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }
            if lhs.allDay != rhs.allDay {
                return lhs.allDay
            }
            let lhsDate = sortDate(for: lhs, calendar: calendar) ?? .distantFuture
            let rhsDate = sortDate(for: rhs, calendar: calendar) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            if lhs.title != rhs.title {
                return lhs.title < rhs.title
            }
            return lhs.id < rhs.id
        }
    }

    public static func items(on date: Date, from items: [CalendarItem], calendar: Calendar = .current) -> [CalendarItem] {
        let targetDay = dayKey(date, calendar: calendar)
        return sortedItems(items, calendar: calendar).filter { item in
            dayKey(for: item, calendar: calendar) == targetDay
        }
    }

    public static func monthDays(displayedMonth: Date, calendar: Calendar = .current) -> [Date?] {
        let monthStart = startOfMonth(displayedMonth, calendar: calendar)
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

    public static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    public static func sortDate(for item: CalendarItem, calendar: Calendar = .current) -> Date? {
        if item.allDay {
            return parsedDateOnly(item.startDate, calendar: calendar)
        }
        return item.startAt
    }

    public static func parsedDateOnly(_ value: String?, calendar: Calendar = .current) -> Date? {
        guard let value else { return nil }
        return dateOnlyFormatter(calendar: calendar).date(from: value)
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        dateOnlyFormatter(calendar: calendar).string(from: date)
    }

    private static func dayKey(for item: CalendarItem, calendar: Calendar) -> String? {
        if item.allDay {
            return item.startDate
        }
        guard let startAt = item.startAt else { return nil }
        return dayKey(startAt, calendar: calendar)
    }
}

private func dateOnlyFormatter(calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}
