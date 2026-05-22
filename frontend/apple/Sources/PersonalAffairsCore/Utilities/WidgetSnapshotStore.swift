import Foundation

public struct WidgetTaskSnapshot: Codable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let priority: String

    public init(id: String, title: String, subtitle: String, priority: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.priority = priority
    }
}

public struct WidgetCalendarSnapshot: Codable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let timeLabel: String

    public init(id: String, title: String, subtitle: String, timeLabel: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.timeLabel = timeLabel
    }
}

public struct WidgetSnapshot: Codable, Equatable {
    public let generatedAt: Date
    public let topThree: [WidgetTaskSnapshot]
    public let upcoming: [WidgetCalendarSnapshot]

    public init(
        generatedAt: Date = Date(),
        topThree: [WidgetTaskSnapshot] = [],
        upcoming: [WidgetCalendarSnapshot] = []
    ) {
        self.generatedAt = generatedAt
        self.topThree = topThree
        self.upcoming = upcoming
    }

    public static let empty = WidgetSnapshot()
}

public enum WidgetSnapshotStore {
    /// 仅供 widget extension 在有 provisioning profile 时切回 group container 用。
    /// v1.1.4 起 macOS host App **不使用** group container，避免 ad-hoc 触发 TCC 弹窗。
    public static let appGroupID = "group.top.linotsai.app.PersonalAffairs"

    /// 切换 group container（默认 nil = per-app UserDefaults）。
    /// Widget extension 启动时可调用 `useAppGroup(...)` 来开启共享。
    public static var preferredAppGroupID: String?

    private static let key = "oneHundredJ.widgetSnapshot.v1"

    public static func useAppGroup(_ groupID: String?) {
        preferredAppGroupID = groupID
    }

    public static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder.personalAffairs.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder.personalAffairs.decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    private static var defaults: UserDefaults {
        if let groupID = preferredAppGroupID, let shared = UserDefaults(suiteName: groupID) {
            return shared
        }
        return .standard
    }
}
