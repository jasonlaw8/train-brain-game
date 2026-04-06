import SwiftData
import Foundation

// Single record that holds all-time bests and play counts across all games.
// Only one instance ever exists — fetch or create on first launch.
@Model
final class PlayerStats {
    // Memory
    var memoryBestScore: Int = 0
    var memoryBestLevel: Int = 0
    var memoryPlayCount: Int = 0

    // Color
    var colorBestScore: Int = 0
    var colorBestStreak: Int = 0
    var colorPlayCount: Int = 0

    // Reflex (stored as ms * 1000 to avoid Float precision issues in SwiftData)
    var reflexBestTimeMs: Double = 0   // 0 = never played
    var reflexPlayCount: Int = 0

    // Cross-game engagement
    var totalXP: Int = 0
    var lastPlayedDate: Date? = nil
    var dailyStreakCount: Int = 0
    var lastStreakDate: Date? = nil

    init() {}

    // MARK: - Derived

    var playerLevel: Int {
        // Every 100 XP = 1 level, capped at 50
        min(50, totalXP / 100 + 1)
    }

    var xpProgressInCurrentLevel: Int {
        totalXP % 100
    }

    // MARK: - Update helpers

    func recordMemoryGame(score: Int, level: Int) {
        if score > memoryBestScore { memoryBestScore = score }
        if level > memoryBestLevel { memoryBestLevel = level }
        memoryPlayCount += 1
        addXP(score / 5)
        touchStreak()
    }

    func recordColorGame(score: Int, streak: Int) {
        if score > colorBestScore { colorBestScore = score }
        if streak > colorBestStreak { colorBestStreak = streak }
        colorPlayCount += 1
        addXP(score / 5)
        touchStreak()
    }

    func recordReflexGame(bestMs: Double) {
        if reflexBestTimeMs == 0 || bestMs < reflexBestTimeMs {
            reflexBestTimeMs = bestMs
        }
        reflexPlayCount += 1
        // Faster = more XP (sub-200ms earns 40, sub-400ms earns 20, else 10)
        let xp = bestMs < 200 ? 40 : bestMs < 400 ? 20 : 10
        addXP(xp)
        touchStreak()
    }

    private func addXP(_ amount: Int) {
        totalXP += max(0, amount)
        lastPlayedDate = Date()
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
                // Missed a day — reset
                dailyStreakCount = 1
                lastStreakDate = Date()
            }
        } else {
            dailyStreakCount = 1
            lastStreakDate = Date()
        }
    }
}
