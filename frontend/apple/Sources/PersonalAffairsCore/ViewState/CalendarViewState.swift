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
            projectId: spaceType == .company ? projectId : nil
        )
    }

    public func updateRequest(timezone: String = TimeZone.current.identifier) -> CalendarItemUpdateRequest {
        CalendarItemUpdateRequest(
            title: title,
            description: trimmedDescription,
            type: type,
            allDay: allDay,
            startDate: allDay ? CalendarViewState.dayKey(startDate) : nil,
            startAt: allDay ? nil : startAt,
            timezone: timezone,
            recurrence: recurrence,
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

    public static func sortedItems(_ items: [CalendarItem]) -> [CalendarItem] {
        items.sorted { lhs, rhs in
            let lhsDate = sortDate(for: lhs) ?? .distantFuture
            let rhsDate = sortDate(for: rhs) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.title < rhs.title
        }
    }

    public static func items(on date: Date, from items: [CalendarItem], calendar: Calendar = .current) -> [CalendarItem] {
        sortedItems(items).filter { item in
            guard let itemDate = sortDate(for: item) else { return false }
            return calendar.isDate(itemDate, inSameDayAs: date)
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

    public static func sortDate(for item: CalendarItem) -> Date? {
        if item.allDay {
            return parsedDateOnly(item.startDate)
        }
        return item.startAt
    }

    public static func parsedDateOnly(_ value: String?) -> Date? {
        guard let value else { return nil }
        return dateOnlyFormatter.date(from: value)
    }

    public static func dayKey(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }
}

private let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
