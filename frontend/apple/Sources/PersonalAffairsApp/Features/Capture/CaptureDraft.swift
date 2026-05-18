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
        case .personalTask: return "个人待办"
        case .companyTask: return "公司待办"
        case .fixedCalendar: return "固定日程"
        case .personalNote: return "个人备忘"
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

extension CaptureDraft {
    init(rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawText = trimmed
        self.title = trimmed

        let lower = trimmed.lowercased()
        if lower.contains("idea") || lower.contains("想法") || lower.contains("灵感") {
            self.target = .personalNote
        } else if lower.contains("明天") || lower.contains("下午") || lower.contains("上午") || lower.contains(":") || lower.contains("预约") {
            self.target = .fixedCalendar
        }
    }
}
