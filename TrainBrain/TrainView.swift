import SwiftUI
import SwiftData

// Browse all training games, grouped by cognitive domain.
struct TrainView: View {
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext

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
                        // MEMORY domain
                        domainSection(
                            title: "Memory",
                            icon: "brain",
                            color: .blue,
                            brainScore: stats.memoryBrainScore,
                            description: "Recall sequences and resist cognitive interference"
                        ) {
                            NavigationLink(destination: MemoryGameView()) {
                                GameCard(
                                    title: "Simon Says",
                                    subtitle: "Repeat the tile sequence",
                                    icon: "square.grid.3x3.fill",
                                    color: .blue,
                                    bestScore: stats.memoryBestLevel > 0
                                        ? "Best level: \(stats.memoryBestLevel)" : nil,
                                    playedToday: stats.playedMemoryToday,
                                    brainScore: stats.memoryBrainScore > 0 ? stats.memoryBrainScore : nil
                                )
                            }
                            NavigationLink(destination: ColorGameView()) {
                                GameCard(
                                    title: "Stroop Challenge",
                                    subtitle: "Name the ink color, not the word",
                                    icon: "paintpalette.fill",
                                    color: .purple,
                                    bestScore: stats.colorBestScore > 0
                                        ? "Best: \(stats.colorBestScore) pts" : nil,
                                    playedToday: stats.playedColorToday
                                )
                            }
                            NavigationLink(destination: SpatialMemoryGameView()) {
                                GameCard(
                                    title: "Spatial Memory",
                                    subtitle: "Memorize the grid pattern, then recreate it",
                                    icon: "square.grid.2x2.fill",
                                    color: .cyan,
                                    bestScore: stats.spatialBestLevel > 0
                                        ? "Best level: \(stats.spatialBestLevel)" : nil,
                                    playedToday: stats.dailyChallengeSpatialDone,
                                    brainScore: stats.spatialBrainScore > 0 ? stats.spatialBrainScore : nil
                                )
                            }
                        }

                        // ATTENTION domain
                        domainSection(
                            title: "Attention",
                            icon: "scope",
                            color: .teal,
                            brainScore: stats.flankerBrainScore,
                            description: "Focus on what matters and ignore distractions"
                        ) {
                            NavigationLink(destination: FlankerGameView()) {
                                GameCard(
                                    title: "Flanker Task",
                                    subtitle: "Identify the center arrow, ignore the rest",
                                    icon: "arrow.left.and.right",
                                    color: .teal,
                                    bestScore: stats.flankerBestAccuracy > 0
                                        ? "Best: \(stats.flankerBestAccuracy)% accuracy" : nil,
                                    playedToday: stats.dailyChallengeFlankerDone,
                                    brainScore: stats.flankerBrainScore > 0 ? stats.flankerBrainScore : nil
                                )
                            }
                        }

                        // PROCESSING SPEED domain
                        domainSection(
                            title: "Processing Speed",
                            icon: "function",
                            color: .green,
                            brainScore: stats.speedBrainScore,
                            description: "How quickly your brain solves problems under pressure"
                        ) {
                            NavigationLink(destination: MathBlitzGameView()) {
                                GameCard(
                                    title: "Math Blitz",
                                    subtitle: "Solve as many problems as you can",
                                    icon: "function",
                                    color: .green,
                                    bestScore: stats.speedBestScore > 0
                                        ? "Best: \(stats.speedBestScore) correct" : nil,
                                    playedToday: stats.dailyChallengeSpeedDone,
                                    brainScore: stats.speedBrainScore > 0 ? stats.speedBrainScore : nil
                                )
                            }
                            NavigationLink(destination: VisualSearchGameView()) {
                                GameCard(
                                    title: "Visual Search",
                                    subtitle: "Find the odd symbol before time runs out",
                                    icon: "eye.fill",
                                    color: .indigo,
                                    bestScore: stats.visualBestScore > 0
                                        ? "Best: \(stats.visualBestScore)/8 rounds" : nil,
                                    playedToday: stats.dailyChallengeVisualDone,
                                    brainScore: stats.visualBrainScore > 0 ? stats.visualBrainScore : nil
                                )
                            }
                        }

                        // REFLEX domain
                        domainSection(
                            title: "Reflex",
                            icon: "bolt.fill",
                            color: .orange,
                            brainScore: stats.reflexBrainScore,
                            description: "Reaction speed and neuromuscular response time"
                        ) {
                            NavigationLink(destination: ReflexGameView()) {
                                GameCard(
                                    title: "Reaction Time",
                                    subtitle: "Tap the circle as fast as you can",
                                    icon: "bolt.fill",
                                    color: .orange,
                                    bestScore: stats.reflexBestTimeMs > 0
                                        ? String(format: "Best: %.0f ms", stats.reflexBestTimeMs) : nil,
                                    playedToday: stats.playedReflexToday,
                                    brainScore: stats.reflexBrainScore > 0 ? stats.reflexBrainScore : nil
                                )
                            }
                        }

                        // PROBLEM SOLVING domain
                        domainSection(
                            title: "Problem Solving",
                            icon: "puzzlepiece.fill",
                            color: .pink,
                            brainScore: stats.patternBrainScore,
                            description: "Detect rules and reason about abstract patterns"
                        ) {
                            NavigationLink(destination: PatternMatchGameView()) {
                                GameCard(
                                    title: "Pattern Match",
                                    subtitle: "Find the rule and pick the next number",
                                    icon: "puzzlepiece.fill",
                                    color: .pink,
                                    bestScore: stats.patternBestScore > 0
                                        ? "Best: \(stats.patternBestScore)/10 correct" : nil,
                                    playedToday: stats.dailyChallengePatternDone,
                                    brainScore: stats.patternBrainScore > 0 ? stats.patternBrainScore : nil
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    func domainSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        brainScore: Int,
        description: String,
        @ViewBuilder games: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Domain header
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if brainScore > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(brainScore)")
                            .font(.title3.bold())
                            .foregroundStyle(color)
                        Text("score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)

            games()
        }
    }
}

#Preview {
    TrainView()
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
