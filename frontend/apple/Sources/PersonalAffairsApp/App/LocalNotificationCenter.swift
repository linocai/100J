#if os(iOS) && canImport(UserNotifications)
import Foundation
import PersonalAffairsCore
import UserNotifications

final class LocalNotificationCenter {
    static let shared = LocalNotificationCenter()

    private init() {}

    func sync(items: [CalendarItem]) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true else {
            return
        }

        let pendingCalendarIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("calendar-") }
        center.removePendingNotificationRequests(withIdentifiers: pendingCalendarIdentifiers)

        for item in items {
            guard let fireDate = item.remindAt, fireDate > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? item.type.label
            content.sound = .default
            content.threadIdentifier = "calendar"

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationID(for: item.id),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func notificationID(for itemID: String) -> String {
        "calendar-\(itemID)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
