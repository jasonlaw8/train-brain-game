import SwiftUI
import SwiftData

// Shared building blocks used by every game: score→color mapping, result rows,
// the pre-game 3-2-1 countdown, the pause overlay, and the Today's Workout plan.

// MARK: - Score color (single source of truth — was duplicated in 5 files)

func scoreColor(_ score: Int) -> Color {
    if score >= 120 { return .green }
    if score >= 100 { return .teal }
    if score >= 85  { return .orange }
    return .red
}

// MARK: - ResultRow

struct ResultRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - CountdownOverlay (3-2-1 before a round starts)

struct CountdownOverlay: View {
    var onFinished: () -> Void

    @State private var count = 3
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Text("\(count)")
                .font(.system(size: 110, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(countsDown: true))
                .scaleEffect(appeared ? 1.0 : 0.6)
                .animation(.spring(response: 0.3), value: appeared)
                .accessibilityLabel("Starting in \(count)")
        }
        .onAppear { appeared = true }
        .task {
            for step in stride(from: 3, through: 1, by: -1) {
                withAnimation { count = step }
                Haptics.light()
                try? await Task.sleep(for: .milliseconds(800))
                if Task.isCancelled { return }
            }
            Haptics.medium()
            onFinished()
        }
    }
}

// MARK: - PauseOverlay (blurs the play field so memory games can't be cheated)

struct PauseOverlay: View {
    var onResume: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Paused")
                    .font(.title.bold())

                VStack(spacing: 12) {
                    Button(action: onResume) {
                        Text("Resume")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel("Resume game")

                    Button(action: onQuit) {
                        Text("Quit Game")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Quit game without saving")
                }
                .padding(.horizontal, 48)
            }
        }
    }
}

// MARK: - Today's Workout
//
// A rotating daily plan of 3 games spanning different cognitive domains —
// the structure competitors gate behind subscriptions, free here.

struct WorkoutGame: Identifiable {
    let id: String        // GameSession gameType key
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    @ViewBuilder
    var destination: some View {
        switch id {
        case "memory":  MemoryGameView()
        case "color":   ColorGameView()
        case "reflex":  ReflexGameView()
        case "speed":   MathBlitzGameView()
        case "flanker": FlankerGameView()
        case "spatial": SpatialMemoryGameView()
        case "visual":  VisualSearchGameView()
        case "pattern": PatternMatchGameView()
        case "switch":  SwitchboardGameView()
        case "nback":   NBackGameView()
        case "bounce":  BounceCastGameView()
        default:        EmptyView()
        }
    }
}

enum TodayWorkout {
    // Buckets keep each day's trio spread across domains.
    private static let buckets: [[WorkoutGame]] = [
        [   // Memory & working memory
            WorkoutGame(id: "memory",  title: "Simon Says",     subtitle: "Repeat the tile sequence",   icon: "square.grid.3x3.fill", color: .blue),
            WorkoutGame(id: "spatial", title: "Spatial Memory", subtitle: "Recreate the grid pattern",  icon: "square.grid.2x2.fill", color: .cyan),
            WorkoutGame(id: "nback",   title: "N-Track",        subtitle: "Spot repeats from N back",   icon: "square.grid.3x3.topleft.filled", color: .purple),
            WorkoutGame(id: "bounce",  title: "Bounce Cast",    subtitle: "Predict the ball's exit",    icon: "arrow.uturn.right.circle.fill", color: .cyan),
        ],
        [   // Attention & inhibition
            WorkoutGame(id: "flanker", title: "Flanker Task",   subtitle: "Judge the center arrow",     icon: "arrow.left.and.right", color: .teal),
            WorkoutGame(id: "color",   title: "Stroop Challenge", subtitle: "Name the ink color",       icon: "paintpalette.fill",    color: .purple),
        ],
        [   // Speed
            WorkoutGame(id: "speed",   title: "Math Blitz",     subtitle: "Rapid-fire arithmetic",      icon: "function",             color: .green),
            WorkoutGame(id: "visual",  title: "Visual Search",  subtitle: "Find the odd one out",       icon: "eye.fill",             color: .indigo),
            WorkoutGame(id: "reflex",  title: "Reaction Time",  subtitle: "Tap as fast as you can",     icon: "bolt.fill",            color: .orange),
        ],
        [   // Executive function
            WorkoutGame(id: "switch",  title: "Switchboard",    subtitle: "Follow the changing rule",   icon: "arrow.triangle.swap",  color: .mint),
            WorkoutGame(id: "pattern", title: "Pattern Match",  subtitle: "Find the hidden rule",       icon: "puzzlepiece.fill",     color: .pink),
        ],
    ]

    /// Deterministic 3-game plan for a given day: skips one bucket per day and
    /// rotates through each bucket's games so the mix changes daily.
    static func games(for date: Date = Date()) -> [WorkoutGame] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let skipped = day % buckets.count
        var plan: [WorkoutGame] = []
        for (i, bucket) in buckets.enumerated() where i != skipped {
            plan.append(bucket[(day / buckets.count) % bucket.count])
        }
        return plan
    }
}
