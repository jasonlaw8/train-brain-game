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
    var memoryLastPlayedDate: Date? = nil

    // Color
    var colorBestScore: Int = 0
    var colorBestStreak: Int = 0
    var colorPlayCount: Int = 0
    var colorLastPlayedDate: Date? = nil

    // Reflex
    var reflexBestTimeMs: Double = 0   // 0 = never played
    var reflexPlayCount: Int = 0
    var reflexLastPlayedDate: Date? = nil

    // Cross-game engagement
    var totalXP: Int = 0
    var lastPlayedDate: Date? = nil
    var dailyStreakCount: Int = 0
    var lastStreakDate: Date? = nil

    // Achievements — comma-separated IDs of unlocked achievements
    var unlockedAchievementIDs: String = ""

    init() {}

    // MARK: - Derived

    var playerLevel: Int { min(50, totalXP / 100 + 1) }
    var xpProgressInCurrentLevel: Int { totalXP % 100 }
    var totalPlayCount: Int { memoryPlayCount + colorPlayCount + reflexPlayCount }

    // MARK: - Daily tracking

    var playedMemoryToday: Bool { isToday(memoryLastPlayedDate) }
    var playedColorToday:  Bool { isToday(colorLastPlayedDate) }
    var playedReflexToday: Bool { isToday(reflexLastPlayedDate) }
    var dailyGamesCompleted: Int { [playedMemoryToday, playedColorToday, playedReflexToday].filter { $0 }.count }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
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

    // MARK: - Record helpers (return whether player leveled up)

    @discardableResult
    func recordMemoryGame(score: Int, level: Int) -> Bool {
        if score > memoryBestScore { memoryBestScore = score }
        if level > memoryBestLevel { memoryBestLevel = level }
        memoryPlayCount += 1
        memoryLastPlayedDate = Date()
        return addXP(score / 5)
    }

    @discardableResult
    func recordColorGame(score: Int, streak: Int) -> Bool {
        if score > colorBestScore { colorBestScore = score }
        if streak > colorBestStreak { colorBestStreak = streak }
        colorPlayCount += 1
        colorLastPlayedDate = Date()
        return addXP(score / 5)
    }

    @discardableResult
    func recordReflexGame(bestMs: Double) -> Bool {
        if reflexBestTimeMs == 0 || bestMs < reflexBestTimeMs {
            reflexBestTimeMs = bestMs
        }
        reflexPlayCount += 1
        reflexLastPlayedDate = Date()
        let xp = bestMs < 200 ? 40 : bestMs < 400 ? 20 : 10
        return addXP(xp)
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
