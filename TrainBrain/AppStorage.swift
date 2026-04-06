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
    var memoryBrainScore: Int = 0   // latest normalized score (70–145)

    // MARK: - Color (training only, no brain score)
    var colorBestScore: Int = 0
    var colorBestStreak: Int = 0
    var colorPlayCount: Int = 0

    // MARK: - Reflex
    var reflexBestTimeMs: Double = 0    // 0 = never played
    var reflexPlayCount: Int = 0
    var reflexBrainScore: Int = 0       // latest normalized score

    // MARK: - Processing Speed (Math Blitz)
    var speedBestScore: Int = 0         // highest correct-answer count in 60s
    var speedPlayCount: Int = 0
    var speedBrainScore: Int = 0        // latest normalized score

    // MARK: - Cross-game engagement
    var totalXP: Int = 0
    var lastPlayedDate: Date? = nil
    var dailyStreakCount: Int = 0
    var lastStreakDate: Date? = nil

    // MARK: - Daily challenges (reset each calendar day)
    var dailyChallengeDate: Date? = nil
    var dailyChallengeMemoryDone: Bool = false
    var dailyChallengeReflexDone: Bool = false
    var dailyChallengeSpeedDone: Bool = false

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool = false

    // MARK: - Milestones (track first-time thresholds to show toast)
    var milestoneOverall100: Bool = false
    var milestoneOverall110: Bool = false
    var milestoneOverall120: Bool = false
    var milestoneOverall130: Bool = false

    init() {}

    // MARK: - Derived

    var playerLevel: Int {
        min(50, totalXP / 100 + 1)
    }

    var xpProgressInCurrentLevel: Int {
        totalXP % 100
    }

    /// Overall Brain Score: average of all three metrics. 0 if any are unscored yet.
    var overallBrainScore: Int {
        guard memoryBrainScore > 0, reflexBrainScore > 0, speedBrainScore > 0 else { return 0 }
        return (memoryBrainScore + reflexBrainScore + speedBrainScore) / 3
    }

    /// Whether today's full set of challenges is complete.
    var allDailyChallengesDone: Bool {
        dailyChallengeMemoryDone && dailyChallengeReflexDone && dailyChallengeSpeedDone
    }

    // MARK: - Brain Score Calculators

    static func memoryBrainScore(level: Int) -> Int {
        // Level 7 ≈ 100 (average); each level ±6 pts. Clamped to 70–145.
        max(70, min(145, 60 + level * 6))
    }

    static func reflexBrainScore(avgMs: Double) -> Int {
        // 280ms ≈ 100 (average); faster = higher. Clamped to 70–145.
        max(70, min(145, Int(70.0 + (280.0 - avgMs) / 4.5)))
    }

    static func speedBrainScore(correct: Int) -> Int {
        // 30 correct ≈ 100 (average); each correct answer ≈ +3 pts. Clamped 70–145.
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

    // MARK: - Record helpers

    func recordMemoryGame(score: Int, level: Int) {
        if score > memoryBestScore { memoryBestScore = score }
        if level > memoryBestLevel { memoryBestLevel = level }
        memoryPlayCount += 1
        memoryBrainScore = Self.memoryBrainScore(level: level)
        addXP(score / 5)
        touchStreak()
        markDailyChallenge("memory")
    }

    func recordColorGame(score: Int, streak: Int) {
        if score > colorBestScore { colorBestScore = score }
        if streak > colorBestStreak { colorBestStreak = streak }
        colorPlayCount += 1
        addXP(score / 5)
        touchStreak()
        // Color is memory training — completing it counts for the memory daily challenge
        markDailyChallenge("memory")
    }

    func recordReflexGame(bestMs: Double, avgMs: Double) {
        if reflexBestTimeMs == 0 || bestMs < reflexBestTimeMs {
            reflexBestTimeMs = bestMs
        }
        reflexPlayCount += 1
        reflexBrainScore = Self.reflexBrainScore(avgMs: avgMs)
        let xp = bestMs < 200 ? 40 : bestMs < 400 ? 20 : 10
        addXP(xp)
        touchStreak()
        markDailyChallenge("reflex")
    }

    func recordSpeedGame(score: Int) {
        if score > speedBestScore { speedBestScore = score }
        speedPlayCount += 1
        speedBrainScore = Self.speedBrainScore(correct: score)
        addXP(score * 2)
        touchStreak()
        markDailyChallenge("speed")
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

    private func addXP(_ amount: Int) {
        totalXP += max(0, amount)
        lastPlayedDate = Date()
    }

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

    private func touchStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let last = lastStreakDate {
            let lastDay = calendar.startOfDay(for: last)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 {
                // Already played today — no change
            } else if diff == 1 {
                dailyStreakCount += 1
                lastStreakDate = Date()
            } else {
                dailyStreakCount = 1
                lastStreakDate = Date()
            }
        } else {
            dailyStreakCount = 1
            lastStreakDate = Date()
        }
    }
}
