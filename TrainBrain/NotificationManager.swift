import UserNotifications
import SwiftUI

// MARK: - NotificationManager
// Wraps UNUserNotificationCenter. Schedules one repeating daily reminder.
// All methods are safe to call at any time — scheduling is idempotent.

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let reminderID = "daily_reminder"

    // MARK: - Permission

    /// Requests notification permission. Returns true if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Returns current authorization status without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Schedule

    /// Schedules (or replaces) the daily reminder at the given hour:minute.
    /// Safe to call repeatedly — cancels any existing reminder first.
    func scheduleDailyReminder(hour: Int, minute: Int, streakCount: Int) {
        cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = "Train Brain"
        content.body = streakCount > 0
            ? "Keep your \(streakCount)-day streak alive! 5 minutes is all it takes."
            : "Your daily brain training is waiting. Stay sharp!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour   = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: reminderID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}
