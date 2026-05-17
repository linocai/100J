import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
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
        case .personalTasks: return "Tasks"
        case .personalNotes: return "Notes"
        case .companyTasks: return "Tasks"
        case .companyProjects: return "Projects"
        case .calendar: return "Calendar"
        case .agent: return "Agent"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .personalTasks: return "checklist"
        case .personalNotes: return "note.text"
        case .companyTasks: return "list.bullet.rectangle"
        case .companyProjects: return "folder"
        case .calendar: return "calendar"
        case .agent: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

