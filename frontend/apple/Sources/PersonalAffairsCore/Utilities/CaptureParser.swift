import Foundation

public enum ParsedCaptureTarget: String, Codable, Equatable {
    case personalTask
    case companyTask
    case fixedCalendar
    case personalNote
    case companyProject
}

public struct ParsedCaptureIntent: Equatable {
    public var target: ParsedCaptureTarget
    public var title: String
    public var description: String?
    public var priority: TaskPriority
    public var dueDate: String?
    public var calendarSpace: SpaceType
    public var calendarType: CalendarItemType
    public var allDay: Bool
    public var startDate: String?
    public var startAt: Date?
    public var recurrence: Recurrence
    public var noteType: NoteType

    public init(
        target: ParsedCaptureTarget,
        title: String,
        description: String? = nil,
        priority: TaskPriority = .medium,
        dueDate: String? = nil,
        calendarSpace: SpaceType = .personal,
        calendarType: CalendarItemType = .appointment,
        allDay: Bool = true,
        startDate: String? = nil,
        startAt: Date? = nil,
        recurrence: Recurrence = .none,
        noteType: NoteType = .idea
    ) {
        self.target = target
        self.title = title
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.calendarSpace = calendarSpace
        self.calendarType = calendarType
        self.allDay = allDay
        self.startDate = startDate
        self.startAt = startAt
        self.recurrence = recurrence
        self.noteType = noteType
    }
}

public enum CaptureParser {
    public static func parse(_ rawText: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedCaptureIntent? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let target = detectTarget(lower)
        let date = detectDate(lower, now: now, calendar: calendar)
        let time = detectTime(lower)
        let title = cleanupTitle(trimmed, target: target)
        let safeTitle = title.isEmpty ? trimmed : title

        switch target {
        case .companyProject:
            return ParsedCaptureIntent(target: target, title: safeTitle, calendarSpace: .company)
        case .personalNote:
            return ParsedCaptureIntent(
                target: target,
                title: safeTitle,
                description: trimmed,
                calendarSpace: .personal,
                noteType: lower.contains("备忘") ? .memo : .idea
            )
        case .fixedCalendar:
            let space: SpaceType = lower.contains("公司") || lower.contains("项目") || lower.contains("会议") ? .company : .personal
            let type = calendarType(lower)
            let day = date ?? now
            if let time {
                let startAt = calendar.date(
                    bySettingHour: time.hour,
                    minute: time.minute,
                    second: 0,
                    of: day
                ) ?? day
                return ParsedCaptureIntent(
                    target: target,
                    title: safeTitle,
                    description: trimmed,
                    calendarSpace: space,
                    calendarType: type,
                    allDay: false,
                    startAt: startAt,
                    recurrence: type == .anniversary ? .yearly : .none
                )
            }
            return ParsedCaptureIntent(
                target: target,
                title: safeTitle,
                description: trimmed,
                calendarSpace: space,
                calendarType: type,
                allDay: true,
                startDate: dayKey(day),
                recurrence: type == .anniversary ? .yearly : .none
            )
        case .companyTask, .personalTask:
            return ParsedCaptureIntent(
                target: target,
                title: safeTitle,
                description: trimmed == safeTitle ? nil : trimmed,
                priority: lower.contains("紧急") ? .urgent : (lower.contains("重要") ? .high : .medium),
                dueDate: date.map(dayKey),
                calendarSpace: target == .companyTask ? .company : .personal
            )
        }
    }

    private static func detectTarget(_ lower: String) -> ParsedCaptureTarget {
        if lower.contains("新建项目") || lower.contains("创建项目") || lower.hasPrefix("项目") {
            return .companyProject
        }
        if lower.contains("灵感") || lower.contains("想法") || lower.contains("备忘") || lower.contains("记录一下") {
            return .personalNote
        }
        if lower.contains("日程") || lower.contains("会议") || lower.contains("预约") || lower.contains("提醒")
            || lower.contains("纪念日") || lower.contains("订阅") || lower.contains("到期")
            || lower.contains("今天") || lower.contains("明天") || lower.contains("后天")
            || lower.contains(":") || lower.contains("：") || lower.contains("点")
        {
            return .fixedCalendar
        }
        if lower.contains("公司") || lower.contains("工作") {
            return .companyTask
        }
        return .personalTask
    }

    private static func calendarType(_ lower: String) -> CalendarItemType {
        if lower.contains("纪念日") || lower.contains("生日") {
            return .anniversary
        }
        if lower.contains("订阅") || lower.contains("到期") {
            return .subscriptionExpiry
        }
        if lower.contains("截止") {
            return .deadline
        }
        if lower.contains("提醒") {
            return .reminder
        }
        return .appointment
    }

    private static func detectDate(_ lower: String, now: Date, calendar: Calendar) -> Date? {
        if lower.contains("后天") {
            return calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
        }
        if lower.contains("明天") {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }
        if lower.contains("今天") {
            return calendar.startOfDay(for: now)
        }
        if let match = firstMatch(#"\d{4}-\d{2}-\d{2}"#, in: lower) {
            return dateOnlyFormatter.date(from: match)
        }
        return nil
    }

    private static func detectTime(_ lower: String) -> (hour: Int, minute: Int)? {
        if let match = firstCaptureGroups(#"(\d{1,2})[:：](\d{2})"#, in: lower),
           let hour = Int(match[0]),
           let minute = Int(match[1]) {
            return (hour, minute)
        }
        if let match = firstCaptureGroups(#"(上午|下午|晚上)?\s*(\d{1,2})点"#, in: lower),
           let rawHour = Int(match[1]) {
            var hour = rawHour
            let period = match[0]
            if (period == "下午" || period == "晚上"), hour < 12 {
                hour += 12
            }
            return (hour, 0)
        }
        return nil
    }

    private static func cleanupTitle(_ text: String, target: ParsedCaptureTarget) -> String {
        var result = text
        let removable = [
            "新建项目", "创建项目", "项目", "个人待办", "公司待办", "待办", "日程", "会议",
            "预约", "提醒", "灵感", "想法", "备忘", "记录一下", "今天", "明天", "后天",
            "上午", "下午", "晚上", "紧急", "重要", "公司", "工作"
        ]
        for token in removable {
            result = result.replacingOccurrences(of: token, with: "")
        }
        result = result.replacingOccurrences(of: #"\d{1,2}[:：]\d{2}"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\d{1,2}点"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\d{4}-\d{2}-\d{2}"#, with: "", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if target == .companyProject, result.hasPrefix("：") || result.hasPrefix(":") {
            result.removeFirst()
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text)
        else {
            return nil
        }
        return String(text[matchRange])
    }

    private static func firstCaptureGroups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        return (1..<match.numberOfRanges).map { index in
            guard let groupRange = Range(match.range(at: index), in: text) else { return "" }
            return String(text[groupRange])
        }
    }

    private static func dayKey(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
