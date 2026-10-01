import Foundation
import SwiftData
import UserNotifications

/// Local bill reminders. Notification text is deliberately generic — no amounts,
/// payees or bill names — because notifications can appear on the lock screen.
@MainActor
enum NotificationScheduler {
    private static let prefix = "ledgerly.bill."

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(in context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.billReminders)
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        let rules = (try? context.fetch(descriptor)) ?? []

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard enabled else { return }

        let calendar = Calendar.current
        let now = Date()
        var scheduled = 0
        for rule in rules where rule.remindDaysBefore >= 0 && rule.kind == .expense {
            guard scheduled < 50 else { break } // iOS keeps at most 64 pending requests
            let reminderDay = rule.nextDueDate.startOfDay.adding(days: -rule.remindDaysBefore)
            guard let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDay),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming bill"
            content.body = rule.remindDaysBefore == 0
                ? "You have a bill due today. Open Ledgerly to review it."
                : "You have a bill due in \(rule.remindDaysBefore) day\(rule.remindDaysBefore == 1 ? "" : "s"). Open Ledgerly to review it."
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + rule.id.uuidString, content: content, trigger: trigger)
            try? await center.add(request)
            scheduled += 1
        }
    }
}
