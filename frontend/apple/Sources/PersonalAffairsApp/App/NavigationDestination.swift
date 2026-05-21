import Foundation
import SwiftUI

/// v1.1 起 Sidebar 只有 4 个一级入口；旧的 personalTasks/personalNotes/...
/// 仍保留作为 Composer prefill / Spotlight intent 的"虚拟 section"，但 sidebar 不会列出。
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case plan
    case calendar
    case agent
    case settings
    // legacy enum cases kept for AppShortcuts / older code referencing them
    case personalTasks
    case personalNotes
    case companyTasks
    case companyProjects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .plan: return "Plan"
        case .calendar: return "Calendar"
        case .agent: return "Agent"
        case .settings: return "设置"
        case .personalTasks: return "个人待办"
        case .personalNotes: return "灵感 / 备忘"
        case .companyTasks: return "公司工作台"
        case .companyProjects: return "项目"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .plan: return "rectangle.3.group"
        case .calendar: return "calendar"
        case .agent: return "sparkles"
        case .settings: return "gearshape"
        case .personalTasks: return "checklist"
        case .personalNotes: return "note.text"
        case .companyTasks: return "rectangle.3.group"
        case .companyProjects: return "folder"
        }
    }

    var accent: Color {
        switch self {
        case .today, .calendar: return AppTheme.Section.today
        case .plan, .personalTasks, .personalNotes, .companyTasks, .companyProjects:
            return AppTheme.Section.plan
        case .agent: return AppTheme.Section.agent
        case .settings: return AppTheme.Section.settings
        }
    }

    /// v1.1 sidebar/tabbar 仅显示这 4 个。
    static let primary: [AppSection] = [.today, .plan, .calendar, .agent]
}
