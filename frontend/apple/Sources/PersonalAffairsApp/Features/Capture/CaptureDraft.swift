import Foundation
import PersonalAffairsCore

enum CaptureTarget: String, CaseIterable, Identifiable {
    case personalTask
    case companyTask
    case fixedCalendar
    case personalNote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .personalTask: return "Task"
        case .companyTask: return "Company Task"
        case .fixedCalendar: return "Fixed Calendar"
        case .personalNote: return "Idea / Note"
        }
    }
}

struct CaptureDraft {
    var rawText: String
    var target: CaptureTarget = .personalTask
    var title: String
    var description = ""
    var priority: TaskPriority = .medium
    var dueDate = ""
    var calendarSpace: SpaceType = .personal
    var calendarType: CalendarItemType = .appointment
    var allDay = false
    var startDate = Date().dayKey
    var startAt = Date()
    var recurrence: Recurrence = .none
    var noteType: NoteType = .idea
    var projectId: String?
}
