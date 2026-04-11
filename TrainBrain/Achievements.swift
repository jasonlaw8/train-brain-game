import SwiftUI
import SwiftData

// MARK: - Achievement definition

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let check: (PlayerStats) -> Bool

    func isUnlocked(for stats: PlayerStats) -> Bool { stats.isAchievementUnlocked(id) }
}

// MARK: - All achievements (14 total)

let allAchievements: [Achievement] = [
    Achievement(
        id: "first_game",
        name: "First Steps",
        description: "Play your very first game",
        icon: "play.circle.fill",
        color: .blue
    ) { $0.totalPlayCount >= 1 },

    Achievement(
        id: "play_25",
        name: "Veteran",
        description: "Play 25 games total",
        icon: "shield.fill",
        color: .indigo
    ) { $0.totalPlayCount >= 25 },

    Achievement(
        id: "memory_5",
        name: "Sharp Mind",
        description: "Reach level 5 in Memory",
        icon: "brain",
        color: .blue
    ) { $0.memoryBestLevel >= 5 },

    Achievement(
        id: "memory_10",
        name: "Memory Pro",
        description: "Reach level 10 in Memory",
        icon: "brain.filled.head.profile",
        color: .blue
    ) { $0.memoryBestLevel >= 10 },

    Achievement(
        id: "memory_20",
        name: "Memory Master",
        description: "Reach level 20 in Memory",
        icon: "sparkles",
        color: .cyan
    ) { $0.memoryBestLevel >= 20 },

    Achievement(
        id: "color_60",
        name: "Colorful",
        description: "Score 60 pts in Color",
        icon: "paintpalette",
        color: .purple
    ) { $0.colorBestScore >= 60 },

    Achievement(
        id: "color_150",
        name: "Chromatic",
        description: "Score 150 pts in Color",
        icon: "paintpalette.fill",
        color: .purple
    ) { $0.colorBestScore >= 150 },

    Achievement(
        id: "color_300",
        name: "Color King",
        description: "Score 300 pts in Color",
        icon: "crown.fill",
        color: .yellow
    ) { $0.colorBestScore >= 300 },

    Achievement(
        id: "streak_5",
        name: "On Fire",
        description: "Get a 5x streak in Color",
        icon: "flame",
        color: .orange
    ) { $0.colorBestStreak >= 5 },

    Achievement(
        id: "streak_10",
        name: "Inferno",
        description: "Get a 10x streak in Color",
        icon: "flame.fill",
        color: .red
    ) { $0.colorBestStreak >= 10 },

    Achievement(
        id: "reflex_300",
        name: "Quick Draw",
        description: "React in under 300 ms",
        icon: "bolt",
        color: .orange
    ) { $0.reflexBestTimeMs > 0 && $0.reflexBestTimeMs < 300 },

    Achievement(
        id: "reflex_200",
        name: "Lightning",
        description: "React in under 200 ms",
        icon: "bolt.fill",
        color: .yellow
    ) { $0.reflexBestTimeMs > 0 && $0.reflexBestTimeMs < 200 },

    Achievement(
        id: "level_5",
        name: "Rising Star",
        description: "Reach player level 5",
        icon: "star.fill",
        color: .yellow
    ) { $0.playerLevel >= 5 },

    Achievement(
        id: "streak_7days",
        name: "Dedicated",
        description: "Play 7 days in a row",
        icon: "calendar.badge.checkmark",
        color: .green
    ) { $0.dailyStreakCount >= 7 },

    // MARK: Math Blitz
    Achievement(
        id: "speed_20",
        name: "Speed Demon",
        description: "Get 20 correct in Math Blitz",
        icon: "function",
        color: .green
    ) { $0.speedBestScore >= 20 },

    Achievement(
        id: "speed_40",
        name: "Math Wizard",
        description: "Get 40 correct in Math Blitz",
        icon: "plus.forwardslash.minus",
        color: .teal
    ) { $0.speedBestScore >= 40 },

    Achievement(
        id: "speed_60",
        name: "Calculation King",
        description: "Get 60 correct in Math Blitz",
        icon: "crown.fill",
        color: .green
    ) { $0.speedBestScore >= 60 },

    // MARK: Overall Brain Score
    Achievement(
        id: "brain_110",
        name: "Above Average",
        description: "Reach an overall Brain Score of 110",
        icon: "brain.filled.head.profile",
        color: .indigo
    ) { $0.overallBrainScore >= 110 },

    // MARK: Flanker Task (Attention)
    Achievement(
        id: "flanker_80",
        name: "Sharp Focus",
        description: "Hit 80% accuracy in Flanker Task",
        icon: "scope",
        color: .teal
    ) { $0.flankerBestAccuracy >= 80 },

    Achievement(
        id: "flanker_95",
        name: "Laser Focus",
        description: "Hit 95% accuracy in Flanker Task",
        icon: "target",
        color: .teal
    ) { $0.flankerBestAccuracy >= 95 },

    // MARK: Spatial Memory
    Achievement(
        id: "spatial_5",
        name: "Spatial Thinker",
        description: "Reach level 5 in Spatial Memory",
        icon: "square.grid.2x2.fill",
        color: .cyan
    ) { $0.spatialBestLevel >= 5 },

    Achievement(
        id: "spatial_10",
        name: "Mind Map",
        description: "Reach level 10 in Spatial Memory",
        icon: "map.fill",
        color: .cyan
    ) { $0.spatialBestLevel >= 10 },

    // MARK: Visual Search
    Achievement(
        id: "visual_6",
        name: "Eagle Eye",
        description: "Find 6 targets in Visual Search",
        icon: "eye.fill",
        color: .indigo
    ) { $0.visualBestScore >= 6 },

    Achievement(
        id: "visual_8",
        name: "Perfect Vision",
        description: "Find all 8 targets in Visual Search",
        icon: "eye.circle.fill",
        color: .indigo
    ) { $0.visualBestScore >= 8 },

    // MARK: Pattern Match
    Achievement(
        id: "pattern_8",
        name: "Pattern Seeker",
        description: "Get 8 correct in Pattern Match",
        icon: "puzzlepiece.fill",
        color: .pink
    ) { $0.patternBestScore >= 8 },

    Achievement(
        id: "pattern_10",
        name: "Code Breaker",
        description: "Get a perfect score in Pattern Match",
        icon: "sparkles",
        color: .pink
    ) { $0.patternBestScore >= 10 },

    // MARK: Brain Snapshot
    Achievement(
        id: "snapshot_1",
        name: "Brain Mapped",
        description: "Complete your first Brain Snapshot",
        icon: "brain.head.profile",
        color: .purple
    ) { $0.snapshotSessionCount >= 1 },

    Achievement(
        id: "snapshot_baseline",
        name: "Calibrated",
        description: "Complete both calibration sessions",
        icon: "scope",
        color: .indigo
    ) { $0.snapshotSessionCount >= 2 },

    Achievement(
        id: "snapshot_improve",
        name: "Real Growth",
        description: "Achieve significant improvement on any domain",
        icon: "chart.line.uptrend.xyaxis",
        color: .green
    ) { $0.isAchievementUnlocked("snapshot_improve") },

    Achievement(
        id: "brain_700",
        name: "Brain Elite",
        description: "Reach a Brain Score of 700 or higher",
        icon: "crown.fill",
        color: .yellow
    ) { $0.bestBrainScore >= 700 },

    Achievement(
        id: "snapshot_10",
        name: "Dedicated Mind",
        description: "Complete 10 Brain Snapshots",
        icon: "calendar.badge.clock",
        color: .teal
    ) { $0.snapshotSessionCount >= 10 },

    // MARK: Digit Span
    Achievement(
        id: "digitspan_1",
        name: "Memory Span",
        description: "Reach level 6 in Number Memory",
        icon: "number.circle.fill",
        color: .mint
    ) { $0.digitSpanBestLevel >= 6 },

    Achievement(
        id: "digitspan_pro",
        name: "Mind Vault",
        description: "Reach level 9 in Number Memory",
        icon: "lock.open.fill",
        color: .mint
    ) { $0.digitSpanBestLevel >= 9 },

    // MARK: Stop Signal
    Achievement(
        id: "stopsignal_1",
        name: "Self Control",
        description: "Hit 80% accuracy in Brake Test",
        icon: "stop.circle.fill",
        color: .red
    ) { $0.stopSignalBestAccuracy >= 80 },

    Achievement(
        id: "stopsignal_pro",
        name: "Iron Brake",
        description: "Hit 95% accuracy in Brake Test",
        icon: "hand.raised.fill",
        color: .red
    ) { $0.stopSignalBestAccuracy >= 95 },

    // MARK: Mental Rotation
    Achievement(
        id: "rotation_1",
        name: "Mind's Eye",
        description: "Get 12 correct in Shape Flip",
        icon: "rotate.3d",
        color: .yellow
    ) { $0.mentalRotationBestScore >= 12 },

    Achievement(
        id: "rotation_pro",
        name: "Spatial Master",
        description: "Get 18 correct in Shape Flip",
        icon: "cube.fill",
        color: .yellow
    ) { $0.mentalRotationBestScore >= 18 },

    // MARK: Word Scramble
    Achievement(
        id: "scramble_1",
        name: "Word Wizard",
        description: "Complete 4 words in Word Scramble",
        icon: "character.book.closed.fill",
        color: Color(red: 0.15, green: 0.65, blue: 0.35)
    ) { $0.wordScrambleBestScore >= 4 },

    Achievement(
        id: "scramble_pro",
        name: "Lexical Speed",
        description: "Complete 8 words in Word Scramble",
        icon: "text.book.closed.fill",
        color: Color(red: 0.15, green: 0.65, blue: 0.35)
    ) { $0.wordScrambleBestScore >= 8 },

    // MARK: Number Trail
    Achievement(
        id: "trail_1",
        name: "Pathfinder",
        description: "Complete your first Number Trail",
        icon: "arrow.triangle.branch",
        color: Color(red: 0.75, green: 0.5, blue: 0.1)
    ) { $0.numberTrailBestTime > 0 },

    Achievement(
        id: "trail_pro",
        name: "Neural Highway",
        description: "Finish Number Trail in under 15 s avg",
        icon: "bolt.horizontal.fill",
        color: Color(red: 0.75, green: 0.5, blue: 0.1)
    ) { $0.numberTrailBestTime > 0 && $0.numberTrailBestTime <= 15.0 },
]

// MARK: - Check & unlock

/// Checks all achievements against current stats. Unlocks any newly earned ones.
/// Returns the list of achievements that were newly unlocked.
func checkAndUnlock(stats: PlayerStats) -> [Achievement] {
    allAchievements.filter { achievement in
        guard achievement.check(stats) else { return false }
        return stats.unlockAchievement(achievement.id)   // returns true only if newly unlocked
    }
}

// MARK: - AchievementsView

struct AchievementsView: View {
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary header
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("\(stats.unlockedCount) / \(allAchievements.count) unlocked")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(stats.unlockedCount) / CGFloat(allAchievements.count))
                    }
                }
                .frame(height: 6)
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(allAchievements) { achievement in
                        AchievementCard(achievement: achievement, stats: stats)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let stats: PlayerStats

    var unlocked: Bool { achievement.isUnlocked(for: stats) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? achievement.color.opacity(0.18) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                Image(systemName: achievement.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(unlocked ? achievement.color : Color(.systemGray3))
            }

            VStack(spacing: 3) {
                Text(achievement.name)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(unlocked ? .primary : .secondary)
                Text(achievement.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color(.systemGray4))
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(unlocked ? achievement.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .opacity(unlocked ? 1 : 0.7)
    }
}

// MARK: - Achievement unlocked banner (toast)

struct AchievementUnlockedBanner: View {
    let achievement: Achievement

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(achievement.color.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: achievement.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(achievement.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievement Unlocked!")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(achievement.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Level-up banner

struct LevelUpBanner: View {
    let level: Int

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Level Up! You're now Level \(level)")
                    .font(.subheadline.bold())
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: .indigo.opacity(0.4), radius: 10)
            .padding(.top, 8)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack { AchievementsView() }
        .modelContainer(for: PlayerStats.self, inMemory: true)
}
