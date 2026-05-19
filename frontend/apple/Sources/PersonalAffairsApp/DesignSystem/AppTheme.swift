import PersonalAffairsCore
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

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
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }

    enum Layout {
        static let minimumWindowWidth: CGFloat = 900
        static let minimumWindowHeight: CGFloat = 720
        static let inspectorVisibilityThreshold: CGFloat = 1180
        static let wideWindowThreshold: CGFloat = 1400
        static let inspectorRegularWidth: CGFloat = 360
        static let inspectorWideWidth: CGFloat = 372
        static let inspectorPopoverWidth: CGFloat = 360
        static let inspectorPopoverHeight: CGFloat = 640
        static let centerContentCompactThreshold: CGFloat = 900
        static let centerContentRegularMaxWidth: CGFloat = 1120
        static let centerContentWideMaxWidth: CGFloat = 1180
        static let sidebarCompactWidth: CGFloat = 224
        static let sidebarRegularWidth: CGFloat = 244
        static let sidebarWideWidth: CGFloat = 260
    }

    enum Alpha {
        static let sidebarSelection: CGFloat = 0.14
        static let macOSSurfaceBase: CGFloat = 0.70
        static let macOSSurfaceElevated: CGFloat = 0.78
        static let macOSHairline: CGFloat = 0.72
        static let iOSSurfaceBase: CGFloat = 0.76
        static let iOSSurfaceElevated: CGFloat = 0.82
        static let iOSHairline: CGFloat = 0.68
        static let subtleSurface: CGFloat = 0.045
        static let selectedSurface: CGFloat = 0.14
        static let tertiaryText: CGFloat = 0.72
    }

    enum Colors {
        #if os(macOS)
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
        static let sidebarSelection = Color(nsColor: .selectedContentBackgroundColor).opacity(Alpha.sidebarSelection)
        static let surfaceBase = Color(nsColor: .controlBackgroundColor).opacity(Alpha.macOSSurfaceBase)
        static let surfaceElevated = Color(nsColor: .textBackgroundColor).opacity(Alpha.macOSSurfaceElevated)
        static let hairline = Color(nsColor: .separatorColor).opacity(Alpha.macOSHairline)
        #else
        static let windowBackground = Color(uiColor: .systemGroupedBackground)
        static let sidebarBackground = Color(uiColor: .secondarySystemGroupedBackground)
        static let sidebarSelection = Color(uiColor: .tertiarySystemFill)
        static let surfaceBase = Color(uiColor: .secondarySystemGroupedBackground).opacity(Alpha.iOSSurfaceBase)
        static let surfaceElevated = Color(uiColor: .systemBackground).opacity(Alpha.iOSSurfaceElevated)
        static let hairline = Color(uiColor: .separator).opacity(Alpha.iOSHairline)
        #endif
        static let sidebarSelectionBorder = Color.primary.opacity(0.10)
        static let surfaceTinted = Color.primary.opacity(Alpha.subtleSurface)
        static let surfaceSelected = companyAccent.opacity(Alpha.selectedSurface)
        static let separator = hairline
        static let surface = surfaceBase
        static let surfaceStrong = surfaceElevated
        static let surfaceSoft = surfaceTinted
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color.secondary.opacity(Alpha.tertiaryText)
        static let textPrimary = primaryText
        static let textSecondary = secondaryText
        static let textTertiary = tertiaryText
        static let personalAccent = Color(red: 0.17, green: 0.62, blue: 0.43)
        static let companyAccent = Color(red: 0.26, green: 0.46, blue: 0.96)
        static let calendarAccent = Color(red: 0.88, green: 0.55, blue: 0.18)
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
