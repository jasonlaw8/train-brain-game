import SwiftUI
import SwiftData

@main
struct TrainBrainApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 9
    @AppStorage("notificationMinute") private var notificationMinute = 0

    @State private var showSplash = true

    init() {
        // Haptics default to ON — only off if user explicitly disabled
        UserDefaults.standard.register(defaults: ["hapticsEnabled": true])
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if hasOnboarded {
                        ContentView()
                    } else {
                        OnboardingView { hasOnboarded = true }
                    }
                }
                .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView(isShowing: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .task {
                // Minimum splash display time — model container loads fast but
                // this prevents the jarring black-to-content flash
                try? await Task.sleep(for: .milliseconds(1200))
                showSplash = false

                // Re-schedule notification on every launch
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
        .modelContainer(for: [PlayerStats.self, GameSession.self, SnapshotSession.self])
    }
}
