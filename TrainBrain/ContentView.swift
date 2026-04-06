import SwiftUI
import SwiftData

// Root tab container. Onboarding is handled in TrainBrainApp before this view appears.
struct ContentView: View {
    var body: some View {
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
    @State private var prevLevel = 1
    @State private var showLevelUp = false

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
                        if stats.totalPlayCount > 0 { dailyProgressStrip }
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
                if showLevelUp {
                    LevelUpBanner(level: stats.playerLevel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(19)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AchievementsView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            if stats.unlockedCount > 0 {
                                Text("\(stats.unlockedCount)/\(allAchievements.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4), value: showLevelUp)
            .animation(.spring(response: 0.5), value: showMilestone)
            .onAppear {
                prevLevel = stats.playerLevel
                checkMilestones()
            }
            .onChange(of: stats.playerLevel) { _, newLevel in
                guard newLevel > prevLevel else { return }
                prevLevel = newLevel
                showLevelUp = true
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    showLevelUp = false
                }
            }
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
            if stats.dailyStreakCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                    Text("\(stats.dailyStreakCount) day streak")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.orange, in: Capsule())
            }
        }
    }

    // MARK: Brain Score Card

    var brainScoreSection: some View {
        VStack(spacing: 16) {
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
                            .padding(.horizontal, 10).padding(.vertical, 4)
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
                VStack(alignment: .trailing, spacing: 8) {
                    metricBadge("Memory", score: stats.memoryBrainScore, color: .blue)
                    metricBadge("Reflex", score: stats.reflexBrainScore, color: .orange)
                    metricBadge("Speed",  score: stats.speedBrainScore,  color: .green)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 20))
        }
    }

    func metricBadge(_ name: String, score: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(score > 0 ? "\(score)" : "—")
                .font(.caption.bold())
                .foregroundStyle(score > 0 ? color : .secondary)
        }
    }

    // MARK: Daily Progress Strip (game-card "played today" dots)

    var dailyProgressStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar").foregroundStyle(.secondary).font(.subheadline)
            Text("Today").font(.subheadline.bold())
            Spacer()
            HStack(spacing: 8) {
                DailyDot(icon: "square.grid.3x3.fill", color: .blue,   done: stats.playedMemoryToday)
                DailyDot(icon: "paintpalette.fill",    color: .purple, done: stats.playedColorToday)
                DailyDot(icon: "bolt.fill",            color: .orange, done: stats.playedReflexToday)
            }
            Text("\(stats.dailyGamesCompleted)/3")
                .font(.caption.bold()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(.secondarySystemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Daily Challenges

    var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Challenges").font(.headline)
                Spacer()
                if stats.allDailyChallengesDone {
                    Label("All done!", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold()).foregroundStyle(.green)
                }
            }
            VStack(spacing: 10) {
                challengeRow("Memory Training",  icon: "square.grid.3x3.fill", color: .blue,
                             done: stats.dailyChallengeMemoryDone, destination: AnyView(MemoryGameView()))
                challengeRow("Reflex Test",      icon: "bolt.fill",            color: .orange,
                             done: stats.dailyChallengeReflexDone, destination: AnyView(ReflexGameView()))
                challengeRow("Speed Sprint",     icon: "function",             color: .green,
                             done: stats.dailyChallengeSpeedDone,  destination: AnyView(MathBlitzGameView()))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 20))
    }

    func challengeRow(_ title: String, icon: String, color: Color, done: Bool, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(done ? .green : color)
                    .frame(width: 32)
                    .animation(.spring(response: 0.4), value: done)
                Text(title).font(.subheadline.bold()).foregroundStyle(done ? .secondary : .primary)
                Spacer()
                if done {
                    Text("Done").font(.caption.bold()).foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption.bold())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Streak & Level

    var streakAndLevelSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(stats.dailyStreakCount > 0 ? .orange : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stats.dailyStreakCount)").font(.title3.bold())
                    Text("day streak").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding()
            .background(Color(.secondarySystemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Level \(stats.playerLevel)", systemImage: "star.fill")
                        .font(.subheadline.bold()).foregroundStyle(.indigo)
                    Spacer()
                    Text("\(stats.xpProgressInCurrentLevel)/100 XP")
                        .font(.caption).foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity).padding()
            .background(Color(.secondarySystemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
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
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(
                Capsule().fill(LinearGradient(colors: [.indigo, .blue],
                                              startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: .indigo.opacity(0.4), radius: 12)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - DailyDot

struct DailyDot: View {
    let icon: String
    let color: Color
    let done: Bool

    var body: some View {
        Image(systemName: done ? "checkmark.circle.fill" : icon)
            .font(.system(size: 18))
            .foregroundStyle(done ? .green : color.opacity(0.4))
    }
}

// MARK: - GameCard

struct GameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var bestScore: String? = nil
    var playedToday: Bool = false
    var brainScore: Int? = nil

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                if playedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                        .background(Circle().fill(Color(.systemBackground)).padding(2))
                        .offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title2.bold()).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                if let best = bestScore {
                    Text(best).font(.caption.bold()).foregroundStyle(color)
                }
            }

            Spacer()

            if let bs = brainScore, bs > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(bs)").font(.title3.bold()).foregroundStyle(color)
                    Text("score").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.subheadline.bold())
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground).opacity(0.92)))
        .buttonStyle(.plain)
    }
}

#Preview("Main App") {
    ContentView()
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
