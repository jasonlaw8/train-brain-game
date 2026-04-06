import SwiftUI
import SwiftData

@main
struct TrainBrainApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

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
        .modelContainer(for: [PlayerStats.self, GameSession.self])
    }
}
