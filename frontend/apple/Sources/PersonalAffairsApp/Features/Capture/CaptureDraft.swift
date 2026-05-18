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
    var hasDueDate = false
    var dueDate = Date()
    var calendarSpace: SpaceType = .personal
    var calendarType: CalendarItemType = .appointment
    var allDay = false
    var startDate = Date()
    var startAt = Date()
    var recurrence: Recurrence = .none
    var noteType: NoteType = .idea
    var projectId: String?

    var dueDateString: String? {
        hasDueDate ? dueDate.dayKey : nil
    }

    var startDateString: String {
        startDate.dayKey
    }
}

extension CaptureDraft {
    init(rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawText = trimmed
        self.title = trimmed

        if let intent = CaptureParser.parse(trimmed) {
            self.title = intent.title
            self.description = intent.description ?? ""
            self.priority = intent.priority
            self.calendarSpace = intent.calendarSpace
            self.calendarType = intent.calendarType
            self.allDay = intent.allDay
            self.recurrence = intent.recurrence
            self.noteType = intent.noteType
            if let dueDate = intent.dueDate, let parsed = parsedDateOnly(dueDate) {
                self.hasDueDate = true
                self.dueDate = parsed
            }
            if let startDate = intent.startDate, let parsed = parsedDateOnly(startDate) {
                self.startDate = parsed
            }
            if let startAt = intent.startAt {
                self.startAt = startAt
            }
            switch intent.target {
            case .personalTask:
                self.target = .personalTask
            case .companyTask, .companyProject:
                self.target = .companyTask
            case .fixedCalendar:
                self.target = .fixedCalendar
            case .personalNote:
                self.target = .personalNote
            }
        }
    }
}
