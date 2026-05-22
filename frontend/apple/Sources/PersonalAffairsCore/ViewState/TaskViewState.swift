import Foundation

public struct TaskListQuery: Equatable {
    public var spaceId: String?
    public var projectId: String?
    public var projectScope: String?
    public var status: TaskStatus?
    public var priority: TaskPriority?
    public var search: String?

    public init(
        spaceId: String? = nil,
        projectId: String? = nil,
        projectScope: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        search: String? = nil
    ) {
        self.spaceId = spaceId
        self.projectId = projectId
        self.projectScope = projectScope
        self.status = status
        self.priority = priority
        self.search = search
    }
}

public enum CompanyTaskScope: Equatable {
    case all
    case noProject
    case withProject
    case project(String?)

    public var pickerValue: String {
        switch self {
        case .all: return "all"
        case .noProject: return "no_project"
        case .withProject: return "with_project"
        case .project: return "project"
        }
    }

    public init(pickerValue: String, selectedProjectId: String? = nil) {
        switch pickerValue {
        case "no_project":
            self = .noProject
        case "with_project":
            self = .withProject
        case "project":
            self = .project(selectedProjectId)
        default:
            self = .all
        }
    }

    public func query(companySpaceId: String, status: TaskStatus, search: String? = nil) -> TaskListQuery {
        switch self {
        case .all:
            return TaskListQuery(spaceId: companySpaceId, status: status, search: search)
        case .noProject:
            return TaskListQuery(spaceId: companySpaceId, projectScope: "no_project", status: status, search: search)
        case .withProject:
            return TaskListQuery(spaceId: companySpaceId, projectScope: "with_project", status: status, search: search)
        case .project(let projectId):
            return TaskListQuery(projectId: projectId, status: status, search: search)
        }
    }
}

public enum PersonalTasksViewState {
    public static func query(personalSpaceId: String, status: TaskStatus, search: String? = nil) -> TaskListQuery {
        TaskListQuery(spaceId: personalSpaceId, status: status, search: search)
    }

    public static func focusTasks(_ tasks: [TaskItem], limit: Int = 3) -> [TaskItem] {
        Array(sortedForFocus(tasks.filter { $0.status == .active }).prefix(limit))
    }
}

public struct CompanyTaskLaneState: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let projectId: String?
    public let projectName: String?
    public let tasks: [TaskItem]
    public let isInbox: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        projectId: String?,
        projectName: String?,
        tasks: [TaskItem],
        isInbox: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.projectId = projectId
        self.projectName = projectName
        self.tasks = tasks
        self.isInbox = isInbox
    }
}

public enum CompanyWorkbenchViewState {
    public static func sortedProjects(_ projects: [Project]) -> [Project] {
        projects.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }
            let lhsDate = parsedDateOnly(lhs.targetDate)
            let rhsDate = parsedDateOnly(rhs.targetDate)
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

    public static func lanes(projects: [Project], tasks: [TaskItem]) -> [CompanyTaskLaneState] {
        let activeCompanyTasks = tasks.filter { $0.status == .active }
        let inbox = CompanyTaskLaneState(
            id: "no_project",
            title: "无项目收件箱",
            subtitle: "公司杂项，建议定期归类",
            projectId: nil,
            projectName: nil,
            tasks: sortedForFocus(activeCompanyTasks.filter { $0.projectId == nil }),
            isInbox: true
        )
        let projectLanes = sortedProjects(projects).map { project in
            CompanyTaskLaneState(
                id: project.id,
                title: project.name,
                subtitle: project.targetDate.map { "目标 \($0)" } ?? "项目任务",
                projectId: project.id,
                projectName: project.name,
                tasks: sortedForFocus(activeCompanyTasks.filter { $0.projectId == project.id }),
                isInbox: false
            )
        }
        return [inbox] + projectLanes
    }

    public static func activeCount(projectId: String, tasks: [TaskItem]) -> Int {
        tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    }

    public static func completedCount(projectId: String, tasks: [TaskItem]) -> Int {
        tasks.filter { $0.projectId == projectId && $0.status == .done }.count
    }
}

private func parsedDateOnly(_ value: String?) -> Date? {
    guard let value else { return nil }
    return dateOnlyFormatter.date(from: value)
}

private func sortedForFocus(_ tasks: [TaskItem]) -> [TaskItem] {
    tasks.sorted { lhs, rhs in
        if lhs.priority != rhs.priority {
            return priorityRank(lhs.priority) > priorityRank(rhs.priority)
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

private func priorityRank(_ priority: TaskPriority) -> Int {
    switch priority {
    case .urgent: return 4
    case .high: return 3
    case .medium: return 2
    case .low: return 1
    }
}

private let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
