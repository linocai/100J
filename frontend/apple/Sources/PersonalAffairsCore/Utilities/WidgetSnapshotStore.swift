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
    public static let appGroupID = "group.top.linotsai.app.PersonalAffairs"
    private static let key = "oneHundredJ.widgetSnapshot.v1"

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
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
