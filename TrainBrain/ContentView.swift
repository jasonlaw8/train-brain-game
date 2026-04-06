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
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                    .ignoresSafeArea()

                // Soft scrim so text stays readable
                Color(.systemBackground).opacity(0.82)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "brain")
                                .font(.system(size: 64))
                                .foregroundStyle(.blue)
                            Text("Train Brain")
                                .font(.largeTitle.bold())
                            Text("Challenge your mind")
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
                        .padding(.top, 52)
                        .padding(.bottom, 36)

                        // Game cards
                        VStack(spacing: 16) {
                            NavigationLink(destination: MemoryGameView()) {
                                GameCard(
                                    title: "Memory",
                                    subtitle: "Repeat the sequence",
                                    icon: "square.grid.3x3.fill",
                                    color: .blue,
                                    bestScore: stats.memoryBestScore > 0
                                        ? "Best: \(stats.memoryBestScore) pts" : nil
                                )
                            }
                            NavigationLink(destination: ColorGameView()) {
                                GameCard(
                                    title: "Color",
                                    subtitle: "Stroop challenge",
                                    icon: "paintpalette.fill",
                                    color: .purple,
                                    bestScore: stats.colorBestScore > 0
                                        ? "Best: \(stats.colorBestScore) pts" : nil
                                )
                            }
                            NavigationLink(destination: ReflexGameView()) {
                                GameCard(
                                    title: "Reflex",
                                    subtitle: "Tap as fast as you can",
                                    icon: "bolt.fill",
                                    color: .orange,
                                    bestScore: stats.reflexBestTimeMs > 0
                                        ? String(format: "Best: %.0f ms", stats.reflexBestTimeMs) : nil
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                        if stats.totalXP > 0 {
                            levelStrip
                                .padding(.horizontal, 20)
                                .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    var levelStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Level \(stats.playerLevel)", systemImage: "star.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                Spacer()
                Text("\(stats.xpProgressInCurrentLevel) / 100 XP")
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
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct GameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var bestScore: String? = nil

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

#Preview {
    ContentView()
        .modelContainer(for: PlayerStats.self, inMemory: true)
}
