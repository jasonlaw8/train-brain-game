import SwiftUI
import SwiftData

@main
struct TrainBrainApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 9
    @AppStorage("notificationMinute") private var notificationMinute = 0

    private let container: ModelContainer = {
        // Try CloudKit-backed store first
        do {
            let config = ModelConfiguration(cloudKitDatabase: .automatic)
            return try ModelContainer(for: PlayerStats.self, GameSession.self, configurations: config)
        } catch {}
        // Fall back to local-only store
        do {
            return try ModelContainer(for: PlayerStats.self, GameSession.self)
        } catch {}
        // Last resort: in-memory (no persistence loss risk, app won't crash)
        return try! ModelContainer(for: PlayerStats.self, GameSession.self,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }()

    init() {
        // Haptics default to ON — only off if user explicitly disabled
        UserDefaults.standard.register(defaults: ["hapticsEnabled": true])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    ContentView()
                } else {
                    OnboardingView { hasOnboarded = true }
                }
            }
            .task {
                // Re-schedule notification on every launch (covers reinstall / permission grant)
                guard notificationsEnabled else { return }
                let status = await NotificationManager.shared.authorizationStatus()
                if status == .authorized {
                    NotificationManager.shared.scheduleDailyReminder(
                        hour: notificationHour,
                        minute: notificationMinute,
                        streakCount: 0
                    )
                }
            }
        }
        .modelContainer(container)
    }
}
