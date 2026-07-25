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
    var speedLastPlayedDate: Date? = nil

    // MARK: - Attention (Flanker Task)
    var flankerBestAccuracy: Int = 0    // 0–100 (%)
    var flankerPlayCount: Int = 0
    var flankerBrainScore: Int = 0
    var flankerLastPlayedDate: Date? = nil

    // MARK: - Spatial Memory
    var spatialBestLevel: Int = 0
    var spatialPlayCount: Int = 0
    var spatialBrainScore: Int = 0
    var spatialLastPlayedDate: Date? = nil

    // MARK: - Visual Search
    var visualBestScore: Int = 0        // correct rounds (0–8)
    var visualPlayCount: Int = 0
    var visualBrainScore: Int = 0
    var visualLastPlayedDate: Date? = nil

    // MARK: - Pattern Match
    var patternBestScore: Int = 0       // correct answers (0–10)
    var patternPlayCount: Int = 0
    var patternBrainScore: Int = 0
    var patternLastPlayedDate: Date? = nil

    // MARK: - Cognitive Flexibility (Switchboard)
    var switchBestScore: Int = 0        // correct answers in 60s
    var switchPlayCount: Int = 0
    var switchBrainScore: Int = 0
    var switchLastPlayedDate: Date? = nil

    // MARK: - Working Memory (N-Track)
    var nbackBestLevel: Int = 0         // highest N completed at ≥60% accuracy
    var nbackPlayCount: Int = 0
    var nbackBrainScore: Int = 0
    var nbackLastPlayedDate: Date? = nil

    // MARK: - Working Memory (Bounce Cast)
    var bounceBestScore: Int = 0        // correct rounds (0–8)
    var bouncePlayCount: Int = 0
    var bounceBrainScore: Int = 0
    var bounceLastPlayedDate: Date? = nil

    // MARK: - Cross-game engagement
    var totalXP: Int = 0
    var lastPlayedDate: Date? = nil
    var dailyStreakCount: Int = 0
    var lastStreakDate: Date? = nil
    var longestStreak: Int = 0

    // MARK: - Achievements (comma-separated IDs of unlocked achievements)
    var unlockedAchievementIDs: String = ""

    // MARK: - Daily challenges (reset each calendar day)
    var dailyChallengeDate: Date? = nil
    var dailyChallengeMemoryDone: Bool = false
    var dailyChallengeReflexDone: Bool = false
    var dailyChallengeSpeedDone: Bool = false
    var dailyChallengeFlankerDone: Bool = false
    var dailyChallengeSpatialDone: Bool = false
    var dailyChallengeVisualDone: Bool = false
    var dailyChallengePatternDone: Bool = false
    var dailyChallengeSnapshotDone: Bool = false

    // MARK: - Brain Snapshot
    var ageRange: String = ""               // "18-24" | "25-34" | "35-44" | "45-54" | "55+"
    var snapshotSessionCount: Int = 0
    var lastSnapshotDate: Date? = nil
    var baselineBrainScore: Int = 0         // set after session 2 (0 = not yet set)
    var bestBrainScore: Int = 0             // all-time highest Brain Score (0–1000)

    // MARK: - Milestones (track first-time Brain Score thresholds to show toast)
    var milestoneOverall100: Bool = false
    var milestoneOverall110: Bool = false
    var milestoneOverall120: Bool = false
    var milestoneOverall130: Bool = false

    // MARK: - Level milestones (no cap — infinite progression)
    var milestoneLevel25:  Bool = false
    var milestoneLevel50:  Bool = false
    var milestoneLevel100: Bool = false
    var milestoneLevel200: Bool = false

    init() {}

    // MARK: - Reset

    /// Wipes every stat, score, XP, streak, achievement, and daily-challenge flag back to defaults.
    func resetAllStats() {
        memoryBestScore = 0; memoryBestLevel = 0; memoryPlayCount = 0
        memoryBrainScore = 0; memoryLastPlayedDate = nil
        colorBestScore = 0; colorBestStreak = 0; colorPlayCount = 0; colorLastPlayedDate = nil
        reflexBestTimeMs = 0; reflexPlayCount = 0; reflexBrainScore = 0; reflexLastPlayedDate = nil
        speedBestScore = 0; speedPlayCount = 0; speedBrainScore = 0; speedLastPlayedDate = nil
        flankerBestAccuracy = 0; flankerPlayCount = 0; flankerBrainScore = 0; flankerLastPlayedDate = nil
        spatialBestLevel = 0; spatialPlayCount = 0; spatialBrainScore = 0; spatialLastPlayedDate = nil
        visualBestScore = 0; visualPlayCount = 0; visualBrainScore = 0; visualLastPlayedDate = nil
        patternBestScore = 0; patternPlayCount = 0; patternBrainScore = 0; patternLastPlayedDate = nil
        switchBestScore = 0; switchPlayCount = 0; switchBrainScore = 0; switchLastPlayedDate = nil
        nbackBestLevel = 0; nbackPlayCount = 0; nbackBrainScore = 0; nbackLastPlayedDate = nil
        bounceBestScore = 0; bouncePlayCount = 0; bounceBrainScore = 0; bounceLastPlayedDate = nil
        totalXP = 0; lastPlayedDate = nil; dailyStreakCount = 0; lastStreakDate = nil; longestStreak = 0
        unlockedAchievementIDs = ""
        dailyChallengeDate = nil
        dailyChallengeMemoryDone = false; dailyChallengeReflexDone = false
        dailyChallengeSpeedDone = false; dailyChallengeFlankerDone = false
        dailyChallengeSpatialDone = false; dailyChallengeVisualDone = false
        dailyChallengePatternDone = false; dailyChallengeSnapshotDone = false
        milestoneOverall100 = false; milestoneOverall110 = false
        milestoneOverall120 = false; milestoneOverall130 = false
        milestoneLevel25 = false; milestoneLevel50 = false
        milestoneLevel100 = false; milestoneLevel200 = false
        snapshotSessionCount = 0; lastSnapshotDate = nil
        baselineBrainScore = 0; bestBrainScore = 0; ageRange = ""
    }

    // MARK: - Derived

    var playerLevel: Int { totalXP / 100 + 1 }   // no cap — infinite progression
    var xpProgressInCurrentLevel: Int { totalXP % 100 }
    var totalPlayCount: Int { memoryPlayCount + colorPlayCount + reflexPlayCount + speedPlayCount + flankerPlayCount + spatialPlayCount + visualPlayCount + patternPlayCount + switchPlayCount + nbackPlayCount + bouncePlayCount }

    // MARK: - Daily tracking (per-game "played today" for game card checkmarks)

    var playedMemoryToday: Bool { isToday(memoryLastPlayedDate) }
    var playedColorToday:  Bool { isToday(colorLastPlayedDate) }
    var playedReflexToday: Bool { isToday(reflexLastPlayedDate) }

    /// "Played today" lookup by GameSession gameType key.
    func playedToday(_ gameType: String) -> Bool {
        switch gameType {
        case "memory":  return isToday(memoryLastPlayedDate)
        case "color":   return isToday(colorLastPlayedDate)
        case "reflex":  return isToday(reflexLastPlayedDate)
        case "speed":   return isToday(speedLastPlayedDate)
        case "flanker": return isToday(flankerLastPlayedDate)
        case "spatial": return isToday(spatialLastPlayedDate)
        case "visual":  return isToday(visualLastPlayedDate)
        case "pattern": return isToday(patternLastPlayedDate)
        case "switch":  return isToday(switchLastPlayedDate)
        case "nback":   return isToday(nbackLastPlayedDate)
        case "bounce":  return isToday(bounceLastPlayedDate)
        default:        return false
        }
    }

    // MARK: - Streak (honest display value — a lapsed streak reads 0 without waiting for the next play)

    var currentStreak: Int {
        guard let last = lastStreakDate else { return 0 }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: last),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return days <= 1 ? dailyStreakCount : 0
    }

    // MARK: - Brain Snapshot cooldown
    var canTakeSnapshot: Bool {
        guard let last = lastSnapshotDate else { return true }
        return Date().timeIntervalSince(last) >= 86400   // 24 hours
    }
    var snapshotCooldownRemaining: String {
        guard let last = lastSnapshotDate else { return "" }
        let remaining = max(0, 86400 - Date().timeIntervalSince(last))
        let h = Int(remaining / 3600)
        let m = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(h)h \(m)m"
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    /// Overall Brain Score: average of every scored game (needs at least 3 to unlock).
    var overallBrainScore: Int {
        let scores = [memoryBrainScore, reflexBrainScore, speedBrainScore,
                      flankerBrainScore, spatialBrainScore, visualBrainScore,
                      patternBrainScore, switchBrainScore, nbackBrainScore,
                      bounceBrainScore].filter { $0 > 0 }
        guard scores.count >= 3 else { return 0 }
        return scores.reduce(0, +) / scores.count
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
        // 280ms ≈ 100 (population average simple visual RT); ~45ms faster = +15 pts.
        // Clamped 70–145, so 200ms ≈ 126 and 400ms bottoms out.
        max(70, min(145, Int(100.0 + (280.0 - avgMs) / 3.0)))
    }

    static func speedBrainScore(correct: Int) -> Int {
        // 30 correct ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 10 + correct * 3))
    }

    static func flankerBrainScore(accuracy: Int) -> Int {
        // 80% accuracy ≈ 100 (average). Clamped 70–145.
        max(70, min(145, accuracy + 20))
    }

    static func spatialBrainScore(level: Int) -> Int {
        // Level 6 ≈ 100 (average). Each level ±7 pts. Clamped 70–145.
        max(70, min(145, 58 + level * 7))
    }

    static func visualBrainScore(correct: Int) -> Int {
        // 5/8 correct ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 40 + correct * 13))
    }

    static func patternBrainScore(correct: Int) -> Int {
        // 7/10 correct ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 35 + correct * 10))
    }

    static func switchBrainScore(correct: Int) -> Int {
        // 30 correct in 60s ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 40 + correct * 2))
    }

    static func nbackBrainScore(maxN: Int, accuracy: Int) -> Int {
        // 2-back at ~75% accuracy ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 45 + maxN * 20 + accuracy / 10))
    }

    static func bounceBrainScore(correct: Int) -> Int {
        // 5/8 rounds ≈ 100 (average). Clamped 70–145.
        max(70, min(145, 40 + correct * 13))
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
        speedLastPlayedDate = Date()
        markDailyChallenge("speed")
        return addXP(score * 2)
    }

    @discardableResult
    func recordSwitchGame(score: Int) -> Bool {
        if score > switchBestScore { switchBestScore = score }
        switchPlayCount += 1
        switchBrainScore = Self.switchBrainScore(correct: score)
        switchLastPlayedDate = Date()
        return addXP(score * 2)
    }

    @discardableResult
    func recordNBackGame(maxN: Int, accuracy: Int) -> Bool {
        if maxN > nbackBestLevel { nbackBestLevel = maxN }
        nbackPlayCount += 1
        nbackBrainScore = Self.nbackBrainScore(maxN: maxN, accuracy: accuracy)
        nbackLastPlayedDate = Date()
        return addXP(maxN * 20 + accuracy / 5)
    }

    @discardableResult
    func recordBounceGame(correct: Int) -> Bool {
        if correct > bounceBestScore { bounceBestScore = correct }
        bouncePlayCount += 1
        bounceBrainScore = Self.bounceBrainScore(correct: correct)
        bounceLastPlayedDate = Date()
        return addXP(correct * 10)
    }

    @discardableResult
    func recordFlankerGame(accuracy: Int) -> Bool {
        if accuracy > flankerBestAccuracy { flankerBestAccuracy = accuracy }
        flankerPlayCount += 1
        flankerBrainScore = Self.flankerBrainScore(accuracy: accuracy)
        flankerLastPlayedDate = Date()
        markDailyChallenge("flanker")
        return addXP(accuracy / 5)
    }

    @discardableResult
    func recordSpatialGame(level: Int) -> Bool {
        if level > spatialBestLevel { spatialBestLevel = level }
        spatialPlayCount += 1
        spatialBrainScore = Self.spatialBrainScore(level: level)
        spatialLastPlayedDate = Date()
        markDailyChallenge("spatial")
        return addXP(level * 8)
    }

    @discardableResult
    func recordVisualGame(correct: Int) -> Bool {
        if correct > visualBestScore { visualBestScore = correct }
        visualPlayCount += 1
        visualBrainScore = Self.visualBrainScore(correct: correct)
        visualLastPlayedDate = Date()
        markDailyChallenge("visual")
        return addXP(correct * 10)
    }

    @discardableResult
    func recordPatternGame(correct: Int) -> Bool {
        if correct > patternBestScore { patternBestScore = correct }
        patternPlayCount += 1
        patternBrainScore = Self.patternBrainScore(correct: correct)
        patternLastPlayedDate = Date()
        markDailyChallenge("pattern")
        return addXP(correct * 8)
    }

    /// Records a completed Brain Snapshot session. Returns true if player leveled up.
    /// Also marks all three core daily challenges done (spec §9: snapshot counts for all domains).
    @discardableResult
    func recordSnapshotSession(brainScore: Int) -> Bool {
        snapshotSessionCount += 1
        lastSnapshotDate = Date()

        // Set baseline on session 2
        if snapshotSessionCount == 2 {
            baselineBrainScore = brainScore
        }

        // XP: +20 base, +10 improvement vs baseline, +20 personal best (max 50)
        var bonusXP = 0
        if brainScore > bestBrainScore {
            bestBrainScore = brainScore
            bonusXP = 20   // new personal best
        } else if baselineBrainScore > 0 && brainScore > baselineBrainScore {
            bonusXP = 10   // improved vs baseline
        }

        // Mark snapshot + all 3 core daily challenges done
        markDailyChallenge("snapshot")
        dailyChallengeMemoryDone = true
        dailyChallengeReflexDone = true
        dailyChallengeSpeedDone  = true

        return addXP(20 + bonusXP)
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

    /// Returns the newly crossed level milestone (25/50/100/200), or nil.
    @discardableResult
    func checkLevelMilestones() -> Int? {
        if !milestoneLevel200 && playerLevel >= 200 { milestoneLevel200 = true; return 200 }
        if !milestoneLevel100 && playerLevel >= 100 { milestoneLevel100 = true; return 100 }
        if !milestoneLevel50  && playerLevel >= 50  { milestoneLevel50  = true; return 50 }
        if !milestoneLevel25  && playerLevel >= 25  { milestoneLevel25  = true; return 25 }
        return nil
    }

    // MARK: - Private helpers

    private func markDailyChallenge(_ type: String) {
        resetDailyChallengesIfNeeded()
        switch type {
        case "memory":   dailyChallengeMemoryDone   = true
        case "reflex":   dailyChallengeReflexDone   = true
        case "speed":    dailyChallengeSpeedDone    = true
        case "flanker":  dailyChallengeFlankerDone  = true
        case "spatial":  dailyChallengeSpatialDone  = true
        case "visual":   dailyChallengeVisualDone   = true
        case "pattern":  dailyChallengePatternDone  = true
        case "snapshot": dailyChallengeSnapshotDone = true
        default: break
        }
    }

    private func resetDailyChallengesIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let last = dailyChallengeDate {
            if calendar.startOfDay(for: last) < today {
                dailyChallengeMemoryDone   = false
                dailyChallengeReflexDone   = false
                dailyChallengeSpeedDone    = false
                dailyChallengeFlankerDone  = false
                dailyChallengeSpatialDone  = false
                dailyChallengeVisualDone   = false
                dailyChallengePatternDone  = false
                dailyChallengeSnapshotDone = false
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
        if dailyStreakCount > longestStreak { longestStreak = dailyStreakCount }
    }
}

// MARK: - Singleton access
//
// Fetching through the context (rather than relying on a not-yet-refreshed @Query)
// guarantees repeated calls within one render pass see the same record, so the
// singleton can never be duplicated.
extension PlayerStats {
    static func fetchOrCreate(in context: ModelContext) -> PlayerStats {
        if let existing = try? context.fetch(FetchDescriptor<PlayerStats>()).first {
            return existing
        }
        let fresh = PlayerStats()
        context.insert(fresh)
        return fresh
    }

    /// Clears stale daily-challenge checkmarks; call on app foreground.
    func refreshDailyState() {
        resetDailyChallengesIfNeeded()
    }
}
