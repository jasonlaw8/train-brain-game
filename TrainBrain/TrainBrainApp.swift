import SwiftUI
import SwiftData

@main
struct TrainBrainApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 9
    @AppStorage("notificationMinute") private var notificationMinute = 0

    init() {
        // Haptics default to ON — only off if user explicitly disabled
        UserDefaults.standard.register(defaults: ["hapticsEnabled": true])
    }

    var body: some Scene {
        WindowGroup {
            if hasOnboarded {
                ContentView()
            } else {
                OnboardingView { hasOnboarded = true }
            }
        }
        .modelContainer(for: [PlayerStats.self, GameSession.self], cloudKitDatabase: .automatic)
        .task {
            // Re-schedule notification on every launch (covers reinstall / permission grant)
            if notificationsEnabled {
                let status = await NotificationManager.shared.authorizationStatus()
                if status == .authorized {
                    // Streak count not available here without model context; use 0 as safe default.
                    // The Settings view reschedules with accurate streak when the user visits.
                    NotificationManager.shared.scheduleDailyReminder(
                        hour: notificationHour,
                        minute: notificationMinute,
                        streakCount: 0
                    )
                }
            }
        }
    }
}
