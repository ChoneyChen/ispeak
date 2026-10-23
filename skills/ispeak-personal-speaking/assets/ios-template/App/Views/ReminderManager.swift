import SwiftUI
import UserNotifications

@MainActor final class ReminderManager: ObservableObject {
    private var pendingTask: Task<Void, Never>?
    private let center = UNUserNotificationCenter.current()
    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
    }
    func refresh(_ store: LearningStore) {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let permission = await center.notificationSettings()
            guard !Task.isCancelled else { return }
            let permitted = [.authorized, .provisional, .ephemeral].contains(permission.authorizationStatus)
            let plan = store.settings
            let dates = permitted ? store.reminderDates() : []
            let desired = Dictionary(uniqueKeysWithValues: dates.map { date in
                ("ispeak.daily.\(store.dayKey(date)).\(plan.reminderHour).\(plan.reminderMinute)", date)
            })
            let existing = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("ispeak.daily.") }
            guard !Task.isCancelled else { return }
            center.removePendingNotificationRequests(withIdentifiers: existing.filter { desired[$0.identifier] == nil }.map(\.identifier))
            let existingIDs = Set(existing.map(\.identifier))
            for (id, time) in desired.sorted(by: { $0.value < $1.value }) where !existingIDs.contains(id) {
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = "句屿 · 今天也练几句"
                content.body = "你的口语练习已准备好。复习旧句，再记几句新表达。"
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
