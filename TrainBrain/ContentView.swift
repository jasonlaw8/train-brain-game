import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        if stats.hasCompletedOnboarding {
            mainTabs
        } else {
            OnboardingView(isComplete: Binding(
                get: { stats.hasCompletedOnboarding },
                set: { stats.hasCompletedOnboarding = $0 }
            ))
        }
    }

    var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            TrainView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
            ProgressView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext

    @State private var milestoneScore: Int? = nil
    @State private var showMilestone = false

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground().ignoresSafeArea()
                Color(.systemBackground).opacity(0.82).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        brainScoreSection
                        dailyChallengesSection
                        streakAndLevelSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 52)
                    .padding(.bottom, 32)
                }

                if showMilestone, let ms = milestoneScore {
                    MilestoneToast(score: ms)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(20)
                }
            }
            .navigationBarHidden(true)
            .animation(.spring(response: 0.5), value: showMilestone)
            .onAppear { checkMilestones() }
        }
    }

    // MARK: Header

    var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
            Text("Train Brain")
                .font(.largeTitle.bold())
            Text("Challenge your mind daily")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Brain Score Card

    var brainScoreSection: some View {
        VStack(spacing: 16) {
            // Overall score + percentile
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brain Score")
                        .font(.subheadline.smallCaps())
                        .foregroundStyle(.secondary)
                    if stats.overallBrainScore > 0 {
                        AnimatedScoreText(value: stats.overallBrainScore,
                                          font: .system(size: 56, weight: .bold, design: .rounded),
                                          color: .primary)
                        Text(PlayerStats.percentileLabel(for: stats.overallBrainScore))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(scoreColor(stats.overallBrainScore).opacity(0.15))
                            .foregroundStyle(scoreColor(stats.overallBrainScore))
                            .clipShape(Capsule())
                    } else {
                        Text("—")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("Play all 3 metrics to unlock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // Per-metric mini scores
                VStack(alignment: .trailing, spacing: 8) {
                    metricBadge("Memory",  score: stats.memoryBrainScore, color: .blue)
                    metricBadge("Reflex",  score: stats.reflexBrainScore, color: .orange)
                    metricBadge("Speed",   score: stats.speedBrainScore,  color: .green)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 20))
        }
    }

    func metricBadge(_ name: String, score: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(score > 0 ? "\(score)" : "—")
                .font(.caption.bold())
                .foregroundStyle(score > 0 ? color : .secondary)
        }
    }

    // MARK: Daily Challenges

    var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Challenges")
                    .font(.headline)
                Spacer()
                if stats.allDailyChallengesDone {
                    Label("All done!", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            VStack(spacing: 10) {
                challengeRow(
                    title: "Memory Training",
                    icon: "square.grid.3x3.fill",
                    color: .blue,
                    done: stats.dailyChallengeMemoryDone,
                    destination: AnyView(MemoryGameView())
                )
                challengeRow(
                    title: "Reflex Test",
                    icon: "bolt.fill",
                    color: .orange,
                    done: stats.dailyChallengeReflexDone,
                    destination: AnyView(ReflexGameView())
                )
                challengeRow(
                    title: "Speed Sprint",
                    icon: "function",
                    color: .green,
                    done: stats.dailyChallengeSpeedDone,
                    destination: AnyView(MathBlitzGameView())
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    func challengeRow(title: String, icon: String, color: Color, done: Bool, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(done ? .green : color)
                    .frame(width: 32)
                    .animation(.spring(response: 0.4), value: done)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(done ? .secondary : .primary)

                Spacer()

                if done {
                    Text("Done")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption.bold())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Streak & Level

    var streakAndLevelSection: some View {
        HStack(spacing: 12) {
            // Streak
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(stats.dailyStreakCount > 0 ? .orange : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stats.dailyStreakCount)")
                        .font(.title3.bold())
                    Text("day streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 16))

            // XP Level
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Level \(stats.playerLevel)", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.indigo)
                    Spacer()
                    Text("\(stats.xpProgressInCurrentLevel)/100 XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(Color.indigo)
                            .frame(width: geo.size.width * CGFloat(stats.xpProgressInCurrentLevel) / 100)
                            .animation(.easeOut(duration: 0.5), value: stats.xpProgressInCurrentLevel)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Helpers

    func scoreColor(_ score: Int) -> Color {
        if score >= 120 { return .green }
        if score >= 100 { return .teal }
        if score >= 85  { return .orange }
        return .red
    }

    func checkMilestones() {
        if let ms = stats.checkMilestones() {
            milestoneScore = ms
            withAnimation { showMilestone = true }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { showMilestone = false }
            }
        }
    }
}

// MARK: - Milestone Toast

struct MilestoneToast: View {
    let score: Int
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "brain.filled.head.profile")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Brain Score Milestone!")
                        .font(.subheadline.bold())
                    Text("You hit \(score) — \(PlayerStats.percentileLabel(for: score))")
                        .font(.caption)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.indigo, .blue],
                                   startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: .indigo.opacity(0.4), radius: 12)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - GameCard (kept for TrainView)

struct GameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var bestScore: String? = nil
    var brainScore: Int? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 60, height: 60)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                if let best = bestScore {
                    Text(best)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
            }

            Spacer()

            if let bs = brainScore, bs > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(bs)")
                        .font(.title3.bold())
                        .foregroundStyle(color)
                    Text("score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.subheadline.bold())
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground).opacity(0.92))
        )
        .buttonStyle(.plain)
    }
}

#Preview("Onboarding") {
    ContentView()
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}

#Preview("Main App") {
    // Simulate already-onboarded user
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PlayerStats.self, GameSession.self, configurations: config)
    let stats = PlayerStats()
    stats.hasCompletedOnboarding = true
    container.mainContext.insert(stats)
    return ContentView().modelContainer(container)
}
