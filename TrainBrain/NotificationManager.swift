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

    // MARK: - Brain Snapshot reminders

    private let snapshotReminderID = "snapshot_reminder"

    // Notification copy variants (rotate by session count)
    private let snapshotCopies = [
        "Your weekly Brain Snapshot is ready. How much did your training pay off?",
        "Time for your brain check-in. Just 4 minutes to see your progress.",
        "Ready for your Brain Snapshot? See how your training is paying off.",
        "Your training streak suggests your scores might be up. Take your Snapshot to find out."
    ]

    /// Schedules the next Brain Snapshot reminder.
    /// - sessionCount: used to rotate notification copy and determine weekly vs. biweekly cadence.
    /// - daysFromNow: how many days until the reminder fires (typically 7 or 14).
    func scheduleSnapshotReminder(sessionCount: Int, daysFromNow: Int = 7) {
        cancelSnapshotReminder()

        let content = UNMutableNotificationContent()
        content.title = "Brain Snapshot"
        content.body = snapshotCopies[sessionCount % snapshotCopies.count]
        content.sound = .default

        let seconds = TimeInterval(daysFromNow * 86400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)

        let request = UNNotificationRequest(
            identifier: snapshotReminderID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelSnapshotReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [snapshotReminderID])
    }
}
