import SwiftUI
import SwiftData

@main
struct TrainBrainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PlayerStats.self, GameSession.self])
    }
}
