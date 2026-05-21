import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case plan
    case personalTasks
    case personalNotes
    case companyTasks
    case companyProjects
    case calendar
    case agent
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .plan: return "Plan"
        case .personalTasks: return "个人待办"
        case .personalNotes: return "灵感 / 备忘"
        case .companyTasks: return "公司工作台"
        case .companyProjects: return "项目"
        case .calendar: return "Calendar"
        case .agent: return "Agent"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .plan: return "square.grid.2x2"
        case .personalTasks: return "checklist"
        case .personalNotes: return "note.text"
        case .companyTasks: return "rectangle.3.group"
        case .companyProjects: return "folder"
        case .calendar: return "calendar"
        case .agent: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}
