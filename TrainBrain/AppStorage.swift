import SwiftData
import Foundation

// Single record that holds all-time bests, play counts, brain scores, and daily challenge state.
// Only one instance ever exists — fetch or create on first launch.
@Model
final class PlayerStats {
    // MARK: - Memory
    var memoryBestScore: Int = 0
    var memoryBestLevel: Int = 0
    var memoryPlayCount: Int = 0
    var memoryBrainScore: Int = 0       // latest normalized score (70–145)
    var memoryLastPlayedDate: Date? = nil

    // MARK: - Color (training only, no brain score)
    var colorBestScore: Int = 0
    var colorBestStreak: Int = 0
    var colorPlayCount: Int = 0
    var colorLastPlayedDate: Date? = nil

    // MARK: - Reflex
    var reflexBestTimeMs: Double = 0    // 0 = never played
    var reflexPlayCount: Int = 0
    var reflexBrainScore: Int = 0       // latest normalized score
    var reflexLastPlayedDate: Date? = nil

    // MARK: - Processing Speed (Math Blitz)
    var speedBestScore: Int = 0         // highest correct-answer count in 60s
    var speedPlayCount: Int = 0
    var speedBrainScore: Int = 0        // latest normalized score

    // MARK: - Cross-game engagement
    var totalXP: Int = 0
    var lastPlayedDate: Date? = nil
    var dailyStreakCount: Int = 0
    var lastStreakDate: Date? = nil

    // MARK: - Achievements (comma-separated IDs of unlocked achievements)
    var unlockedAchievementIDs: String = ""

    // MARK: - Daily challenges (reset each calendar day)
    var dailyChallengeDate: Date? = nil
    var dailyChallengeMemoryDone: Bool = false
    var dailyChallengeReflexDone: Bool = false
    var dailyChallengeSpeedDone: Bool = false

    // MARK: - Milestones (track first-time Brain Score thresholds to show toast)
    var milestoneOverall100: Bool = false
    var milestoneOverall110: Bool = false
    var milestoneOverall120: Bool = false
    var milestoneOverall130: Bool = false

    init() {}

    // MARK: - Derived

    var playerLevel: Int { min(50, totalXP / 100 + 1) }
    var xpProgressInCurrentLevel: Int { totalXP % 100 }
    var totalPlayCount: Int { memoryPlayCount + colorPlayCount + reflexPlayCount + speedPlayCount }

    // MARK: - Daily tracking (per-game "played today" for game card checkmarks)

    var playedMemoryToday: Bool { isToday(memoryLastPlayedDate) }
    var playedColorToday:  Bool { isToday(colorLastPlayedDate) }
    var playedReflexToday: Bool { isToday(reflexLastPlayedDate) }
    var dailyGamesCompleted: Int { [playedMemoryToday, playedColorToday, playedReflexToday].filter { $0 }.count }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    /// Overall Brain Score: average of all three metrics. 0 if any are unscored yet.
    var overallBrainScore: Int {
        guard memoryBrainScore > 0, reflexBrainScore > 0, speedBrainScore > 0 else { return 0 }
        return (memoryBrainScore + reflexBrainScore + speedBrainScore) / 3
    }

    /// Whether today's full set of daily challenges is complete.
    var allDailyChallengesDone: Bool {
        dailyChallengeMemoryDone && dailyChallengeReflexDone && dailyChallengeSpeedDone
    }

    // MARK: - Achievement helpers

    func isAchievementUnlocked(_ id: String) -> Bool {
        unlockedAchievementIDs.split(separator: ",").map(String.init).contains(id)
    }

    @discardableResult
    func unlockAchievement(_ id: String) -> Bool {
        guard !isAchievementUnlocked(id) else { return false }
        unlockedAchievementIDs = unlockedAchievementIDs.isEmpty ? id : "\(unlockedAchievementIDs),\(id)"
        return true
    }

    var unlockedCount: Int {
        unlockedAchievementIDs.isEmpty ? 0 : unlockedAchievementIDs.split(separator: ",").count
    }

    // MARK: - Brain Score Calculators

    static func memoryBrainScore(level: Int) -> Int {
        // Level 7 ≈ 100 (average); each level ±6 pts. Clamped 70–145.
        max(70, min(145, 60 + level * 6))
    }

    static func reflexBrainScore(avgMs: Double) -> Int {
        // 280ms ≈ 100 (average); faster = higher. Clamped 70–145.
        max(70, min(145, Int(70.0 + (280.0 - avgMs) / 4.5)))
    }

    static func speedBrainScore(correct: Int) -> Int {
        // 30 correct ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 10 + correct * 3))
    }

    // MARK: - Percentile label

    static func percentileLabel(for score: Int) -> String {
        switch score {
        case ..<80:  return "Bottom 10%"
        case ..<90:  return "Below average"
        case ..<105: return "Average"
        case ..<115: return "Above average"
        case ..<125: return "Top 20%"
        case ..<135: return "Top 10%"
        default:     return "Top 5%"
        }
    }

    // MARK: - Record helpers (return Bool = whether player leveled up)

    @discardableResult
    func recordMemoryGame(score: Int, level: Int) -> Bool {
        if score > memoryBestScore { memoryBestScore = score }
        if level > memoryBestLevel { memoryBestLevel = level }
        memoryPlayCount += 1
        memoryBrainScore = Self.memoryBrainScore(level: level)
        memoryLastPlayedDate = Date()
        markDailyChallenge("memory")
        return addXP(score / 5)
    }

    @discardableResult
    func recordColorGame(score: Int, streak: Int) -> Bool {
        if score > colorBestScore { colorBestScore = score }
        if streak > colorBestStreak { colorBestStreak = streak }
        colorPlayCount += 1
        colorLastPlayedDate = Date()
        // Color is memory training — counts toward the memory daily challenge
        markDailyChallenge("memory")
        return addXP(score / 5)
    }

    @discardableResult
    func recordReflexGame(bestMs: Double, avgMs: Double) -> Bool {
        if reflexBestTimeMs == 0 || bestMs < reflexBestTimeMs {
            reflexBestTimeMs = bestMs
        }
        reflexPlayCount += 1
        reflexBrainScore = Self.reflexBrainScore(avgMs: avgMs)
        reflexLastPlayedDate = Date()
        markDailyChallenge("reflex")
        let xp = bestMs < 200 ? 40 : bestMs < 400 ? 20 : 10
        return addXP(xp)
    }

    @discardableResult
    func recordSpeedGame(score: Int) -> Bool {
        if score > speedBestScore { speedBestScore = score }
        speedPlayCount += 1
        speedBrainScore = Self.speedBrainScore(correct: score)
        markDailyChallenge("speed")
        return addXP(score * 2)
    }

    /// Returns the newly crossed milestone Brain Score threshold (100/110/120/130), or nil.
    @discardableResult
    func checkMilestones() -> Int? {
        let overall = overallBrainScore
        guard overall > 0 else { return nil }
        if !milestoneOverall130 && overall >= 130 { milestoneOverall130 = true; return 130 }
        if !milestoneOverall120 && overall >= 120 { milestoneOverall120 = true; return 120 }
        if !milestoneOverall110 && overall >= 110 { milestoneOverall110 = true; return 110 }
        if !milestoneOverall100 && overall >= 100 { milestoneOverall100 = true; return 100 }
        return nil
    }

    // MARK: - Private helpers

    private func markDailyChallenge(_ type: String) {
        resetDailyChallengesIfNeeded()
        switch type {
        case "memory": dailyChallengeMemoryDone = true
        case "reflex": dailyChallengeReflexDone = true
        case "speed":  dailyChallengeSpeedDone  = true
        default: break
        }
    }

    private func resetDailyChallengesIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let last = dailyChallengeDate {
            if calendar.startOfDay(for: last) < today {
                dailyChallengeMemoryDone = false
                dailyChallengeReflexDone = false
                dailyChallengeSpeedDone  = false
                dailyChallengeDate = Date()
            }
        } else {
            dailyChallengeDate = Date()
        }
    }

    @discardableResult
    private func addXP(_ amount: Int) -> Bool {
        let before = playerLevel
        totalXP += max(0, amount)
        lastPlayedDate = Date()
        touchStreak()
        return playerLevel > before
    }

    private func touchStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let last = lastStreakDate {
            let lastDay = calendar.startOfDay(for: last)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 { /* already played today */ }
            else if diff == 1 { dailyStreakCount += 1; lastStreakDate = Date() }
            else { dailyStreakCount = 1; lastStreakDate = Date() }
        } else {
            dailyStreakCount = 1
            lastStreakDate = Date()
        }
    }
}
