import Combine
import Foundation

public struct TodayScheduleItem: Identifiable, Equatable {
    public let id: String
    public let item: CalendarItem
    public let timeLabel: String

    public init(item: CalendarItem, timeLabel: String) {
        self.id = item.id
        self.item = item
        self.timeLabel = timeLabel
    }
}

public struct TodayLooseEnd: Identifiable, Equatable {
    public enum Kind: Equatable {
        case task
        case note
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let kind: Kind

    public init(id: String, title: String, subtitle: String, kind: Kind) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
    }
}

@MainActor
public final class TodayViewModel: ObservableObject {
    @Published public private(set) var topThree: [TaskItem] = []
    @Published public private(set) var upcoming: [TodayScheduleItem] = []
    @Published public private(set) var looseEnds: [TodayLooseEnd] = []

    private let personalTasks: () -> [TaskItem]
    private let companyTasks: () -> [TaskItem]
    private let calendarItems: () -> [CalendarItem]
    private let notes: () -> [Note]
    private let now: () -> Date

    public init(
        personalTasks: @escaping () -> [TaskItem],
        companyTasks: @escaping () -> [TaskItem],
        calendarItems: @escaping () -> [CalendarItem],
        notes: @escaping () -> [Note],
        now: @escaping () -> Date = Date.init
    ) {
        self.personalTasks = personalTasks
        self.companyTasks = companyTasks
        self.calendarItems = calendarItems
        self.notes = notes
        self.now = now
    }

    public func refresh() {
        let activeTasks = (personalTasks() + companyTasks()).filter { $0.status == .active }
        topThree = Array(Self.sortedForFocus(activeTasks).prefix(3))

        let today = now()
        upcoming = CalendarViewState.items(on: today, from: calendarItems()).prefix(3).map { item in
            TodayScheduleItem(item: item, timeLabel: Self.timeLabel(for: item))
        }

        let looseCompanyTasks = companyTasks()
            .filter { $0.status == .active && $0.projectId == nil }
            .map {
                TodayLooseEnd(
                    id: "task-\($0.id)",
                    title: $0.title,
                    subtitle: "公司 · 无项目",
                    kind: .task
                )
            }
        let looseNotes = notes()
            .filter { $0.status == .active && $0.linkedTaskId == nil }
            .map {
                TodayLooseEnd(
                    id: "note-\($0.id)",
                    title: $0.title?.nilIfBlank ?? String($0.body.prefix(48)),
                    subtitle: $0.type.label,
                    kind: .note
                )
            }
        looseEnds = Array((looseCompanyTasks + looseNotes).prefix(6))
    }

    private static func sortedForFocus(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return priorityRank(lhs.priority) > priorityRank(rhs.priority)
            }
            let lhsDate = CalendarViewState.parsedDateOnly(lhs.dueDate)
            let rhsDate = CalendarViewState.parsedDateOnly(rhs.dueDate)
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

    private static func priorityRank(_ priority: TaskPriority) -> Int {
        switch priority {
        case .urgent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private static func timeLabel(for item: CalendarItem) -> String {
        if item.allDay {
            return "全天"
        }
        guard let startAt = item.startAt else {
            return "定时"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startAt)
    }
}
