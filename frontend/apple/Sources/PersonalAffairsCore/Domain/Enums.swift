import Foundation

public enum SpaceType: String, Codable, CaseIterable, Identifiable {
    case personal
    case company

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case done
    case archived

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case urgent

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case completed
    case archived

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum CalendarItemType: String, Codable, CaseIterable, Identifiable {
    case appointment
    case anniversary
    case subscriptionExpiry = "subscription_expiry"
    case deadline
    case reminder

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .appointment: return "Appointment"
        case .anniversary: return "Anniversary"
        case .subscriptionExpiry: return "Subscription"
        case .deadline: return "Deadline"
        case .reminder: return "Reminder"
        }
    }
}

public enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case monthly
    case yearly

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum NoteType: String, Codable, CaseIterable, Identifiable {
    case idea
    case memo

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum NoteStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case archived

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

