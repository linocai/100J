import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
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
        case .today: return "Today Command"
        case .personalTasks: return "Personal Tasks"
        case .personalNotes: return "Ideas / Notes"
        case .companyTasks: return "Company Workbench"
        case .companyProjects: return "Projects"
        case .calendar: return "Fixed Calendar"
        case .agent: return "Agent"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sparkle.magnifyingglass"
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
