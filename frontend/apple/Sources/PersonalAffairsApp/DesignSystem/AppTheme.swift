import PersonalAffairsCore
import SwiftUI

enum AppTheme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Colors {
        static let windowBackground = Color(red: 0.93, green: 0.91, blue: 0.87)
        static let sidebarBackground = Color(red: 0.96, green: 0.94, blue: 0.91)
        static let surface = Color.white.opacity(0.68)
        static let surfaceStrong = Color.white.opacity(0.88)
        static let surfaceSoft = Color.white.opacity(0.44)
        static let separator = Color.primary.opacity(0.10)
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color.secondary.opacity(0.72)
        static let personalAccent = Color(red: 0.17, green: 0.62, blue: 0.43)
        static let companyAccent = Color(red: 0.26, green: 0.46, blue: 0.96)
        static let agentAccent = Color(red: 0.51, green: 0.34, blue: 0.85)
        static let warningAccent = Color(red: 0.84, green: 0.50, blue: 0.16)
        static let dangerAccent = Color(red: 0.81, green: 0.31, blue: 0.31)
        static let successAccent = Color(red: 0.20, green: 0.62, blue: 0.39)
    }
}

extension TaskPriority {
    var sortRank: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .urgent: return .danger
        case .high: return .warning
        case .medium: return .neutral
        case .low: return .neutralSubtle
        }
    }
}

extension ProjectStatus {
    var pillStyle: PillStyle {
        switch self {
        case .active: return .company
        case .completed: return .success
        case .archived: return .neutralSubtle
        }
    }
}

extension CalendarItemType {
    var systemImage: String {
        switch self {
        case .appointment: return "calendar"
        case .anniversary: return "gift"
        case .subscriptionExpiry: return "creditcard"
        case .deadline: return "flag"
        case .reminder: return "bell"
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .subscriptionExpiry: return .warning
        case .deadline: return .danger
        case .anniversary: return .warningSubtle
        case .appointment: return .company
        case .reminder: return .agent
        }
    }
}

extension NoteType {
    var systemImage: String {
        switch self {
        case .idea: return "lightbulb"
        case .memo: return "doc.text"
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .idea: return .agent
        case .memo: return .neutral
        }
    }
}

extension Date {
    var dayKey: String {
        DateOnlyFormatter.shared.string(from: self)
    }

    var compactTime: String {
        TimeOnlyFormatter.shared.string(from: self)
    }
}

enum DateOnlyFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum TimeOnlyFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

func parsedDateOnly(_ value: String?) -> Date? {
    guard let value else { return nil }
    return DateOnlyFormatter.shared.date(from: value)
}

func sortedForFocus(_ tasks: [TaskItem]) -> [TaskItem] {
    tasks.sorted { lhs, rhs in
        if lhs.priority.sortRank != rhs.priority.sortRank {
            return lhs.priority.sortRank < rhs.priority.sortRank
        }

        let lhsDate = parsedDateOnly(lhs.dueDate)
        let rhsDate = parsedDateOnly(rhs.dueDate)
        switch (lhsDate, rhsDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}

func sortedCalendarItems(_ items: [CalendarItem]) -> [CalendarItem] {
    items.sorted { lhs, rhs in
        let lhsDate = calendarSortDate(lhs) ?? .distantFuture
        let rhsDate = calendarSortDate(rhs) ?? .distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        if lhs.allDay != rhs.allDay {
            return lhs.allDay
        }
        return lhs.updatedAt > rhs.updatedAt
    }
}

func calendarSortDate(_ item: CalendarItem) -> Date? {
    if item.allDay {
        return parsedDateOnly(item.startDate)
    }
    return item.startAt
}
