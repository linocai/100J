#if os(iOS) && canImport(UserNotifications)
import Foundation
import PersonalAffairsCore
import UserNotifications

final class LocalNotificationCenter {
    static let shared = LocalNotificationCenter()

    private init() {}

    func sync(items: [CalendarItem]) async {
        let center = UNUserNotificationCenter.current()

        // v1.2.4 P6-5 (#28): inspect the current authorization state first.
        // Calling `requestAuthorization` unconditionally on every sync used
        // to re-prompt users who had already denied (and silently did
        // nothing for users who had already granted, while still costing a
        // TCC round-trip). Only prompt when the user has never been asked.
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        case .denied:
            // Honour the user's choice — no prompts, no scheduled reminders.
            return
        default:
            // .authorized / .provisional / .ephemeral — proceed to sync.
            break
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
