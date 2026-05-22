import Foundation

public enum AppAuthMode: String, Codable, CaseIterable, Identifiable {
    case localOwner
    case cloudJWT

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .localOwner: return "本机 Owner"
        case .cloudJWT: return "个人云端"
        }
    }
}

public enum SpaceType: String, Codable, CaseIterable, Identifiable {
    case personal
    case company

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .personal: return "个人"
        case .company: return "公司"
        }
    }
}

public enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case done
    case archived

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .active: return "进行中"
        case .done: return "已完成"
        case .archived: return "已归档"
        }
    }
}

public enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case urgent

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }
}

public enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case completed
    case archived

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .active: return "进行中"
        case .completed: return "已完成"
        case .archived: return "已归档"
        }
    }
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
        case .appointment: return "约会"
        case .anniversary: return "纪念日"
        case .subscriptionExpiry: return "订阅"
        case .deadline: return "截止日"
        case .reminder: return "提醒"
        }
    }
}

public enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case monthly
    case yearly

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .none: return "不重复"
        case .monthly: return "每月"
        case .yearly: return "每年"
        }
    }
}

public enum NoteType: String, Codable, CaseIterable, Identifiable {
    case idea
    case memo

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .idea: return "灵感"
        case .memo: return "备忘"
        }
    }
}

public enum NoteStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case archived

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .active: return "活跃"
        case .archived: return "已归档"
        }
    }
}
