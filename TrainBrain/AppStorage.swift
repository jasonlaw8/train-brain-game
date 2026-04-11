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
    var dailyChallengeFlankerDone: Bool = false
    var dailyChallengeSpatialDone: Bool = false
    var dailyChallengeVisualDone: Bool = false
    var dailyChallengePatternDone: Bool = false
    var dailyChallengeSnapshotDone: Bool = false

    // MARK: - New Games

    // MARK: - Digit Span
    var digitSpanBestLevel: Int = 0
    var digitSpanBrainScore: Int = 0
    var digitSpanPlayCount: Int = 0
    var digitSpanLastPlayedDate: Date? = nil

    // MARK: - Stop Signal
    var stopSignalBestAccuracy: Int = 0
    var stopSignalBrainScore: Int = 0
    var stopSignalPlayCount: Int = 0
    var stopSignalLastPlayedDate: Date? = nil

    // MARK: - Mental Rotation
    var mentalRotationBestScore: Int = 0
    var mentalRotationBrainScore: Int = 0
    var mentalRotationPlayCount: Int = 0
    var mentalRotationLastPlayedDate: Date? = nil

    // MARK: - Word Scramble
    var wordScrambleBestScore: Int = 0
    var wordScrambleBrainScore: Int = 0
    var wordScramblePlayCount: Int = 0
    var wordScrambleLastPlayedDate: Date? = nil

    // MARK: - Number Trail
    var numberTrailBestTime: Double = 0   // 0 = never played; lower is better
    var numberTrailBrainScore: Int = 0
    var numberTrailPlayCount: Int = 0
    var numberTrailLastPlayedDate: Date? = nil

    // MARK: - Daily challenges (new games)
    var dailyChallengeDigitSpanDone: Bool = false
    var dailyChallengeStopSignalDone: Bool = false
    var dailyChallengeMentalRotationDone: Bool = false
    var dailyChallengeWordScrambleDone: Bool = false
    var dailyChallengeNumberTrailDone: Bool = false

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
        speedBestScore = 0; speedPlayCount = 0; speedBrainScore = 0
        flankerBestAccuracy = 0; flankerPlayCount = 0; flankerBrainScore = 0; flankerLastPlayedDate = nil
        spatialBestLevel = 0; spatialPlayCount = 0; spatialBrainScore = 0; spatialLastPlayedDate = nil
        visualBestScore = 0; visualPlayCount = 0; visualBrainScore = 0; visualLastPlayedDate = nil
        patternBestScore = 0; patternPlayCount = 0; patternBrainScore = 0; patternLastPlayedDate = nil
        digitSpanBestLevel = 0; digitSpanBrainScore = 0; digitSpanPlayCount = 0; digitSpanLastPlayedDate = nil
        stopSignalBestAccuracy = 0; stopSignalBrainScore = 0; stopSignalPlayCount = 0; stopSignalLastPlayedDate = nil
        mentalRotationBestScore = 0; mentalRotationBrainScore = 0; mentalRotationPlayCount = 0; mentalRotationLastPlayedDate = nil
        wordScrambleBestScore = 0; wordScrambleBrainScore = 0; wordScramblePlayCount = 0; wordScrambleLastPlayedDate = nil
        numberTrailBestTime = 0; numberTrailBrainScore = 0; numberTrailPlayCount = 0; numberTrailLastPlayedDate = nil
        totalXP = 0; lastPlayedDate = nil; dailyStreakCount = 0; lastStreakDate = nil
        unlockedAchievementIDs = ""
        dailyChallengeDate = nil
        dailyChallengeMemoryDone = false; dailyChallengeReflexDone = false
        dailyChallengeSpeedDone = false; dailyChallengeFlankerDone = false
        dailyChallengeSpatialDone = false; dailyChallengeVisualDone = false
        dailyChallengePatternDone = false; dailyChallengeSnapshotDone = false
        dailyChallengeDigitSpanDone = false; dailyChallengeStopSignalDone = false
        dailyChallengeMentalRotationDone = false; dailyChallengeWordScrambleDone = false
        dailyChallengeNumberTrailDone = false
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
    var totalPlayCount: Int { memoryPlayCount + colorPlayCount + reflexPlayCount + speedPlayCount + flankerPlayCount + spatialPlayCount + visualPlayCount + patternPlayCount + digitSpanPlayCount + stopSignalPlayCount + mentalRotationPlayCount + wordScramblePlayCount + numberTrailPlayCount }

    // MARK: - Daily tracking (per-game "played today" for game card checkmarks)

    var playedMemoryToday: Bool { isToday(memoryLastPlayedDate) }
    var playedColorToday:  Bool { isToday(colorLastPlayedDate) }
    var playedReflexToday: Bool { isToday(reflexLastPlayedDate) }
    var dailyGamesCompleted: Int {
        [playedMemoryToday, playedColorToday, playedReflexToday,
         dailyChallengeDigitSpanDone, dailyChallengeStopSignalDone,
         dailyChallengeMentalRotationDone, dailyChallengeWordScrambleDone,
         dailyChallengeNumberTrailDone].filter { $0 }.count
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

    /// Overall Brain Score: average of all games played (score > 0).
    var overallBrainScore: Int {
        let scores = [memoryBrainScore, reflexBrainScore, speedBrainScore,
                      flankerBrainScore, spatialBrainScore, visualBrainScore,
                      patternBrainScore, digitSpanBrainScore, stopSignalBrainScore,
                      mentalRotationBrainScore, wordScrambleBrainScore, numberTrailBrainScore
                     ].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    /// Whether today's full set of daily challenges is complete.
    var allDailyChallengesDone: Bool {
        dailyChallengeMemoryDone && dailyChallengeReflexDone && dailyChallengeSpeedDone &&
        dailyChallengeDigitSpanDone && dailyChallengeStopSignalDone &&
        dailyChallengeMentalRotationDone && dailyChallengeWordScrambleDone &&
        dailyChallengeNumberTrailDone
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

    static func digitSpanBrainScore(level: Int) -> Int {
        // level 5 ≈ 97, level 7 ≈ 115. Clamped 70–145.
        max(70, min(145, 52 + level * 9))
    }

    static func stopSignalBrainScore(accuracy: Int) -> Int {
        // 82% accuracy ≈ 100. Clamped 70–145.
        max(70, min(145, accuracy + 18))
    }

    static func mentalRotationBrainScore(correct: Int) -> Int {
        // 12/20 ≈ 100. Clamped 70–145.
        max(70, min(145, 40 + correct * 5))
    }

    static func wordScrambleBrainScore(score: Int) -> Int {
        // 4 words ≈ 100. Clamped 70–145.
        max(70, min(145, 40 + score * 15))
    }

    static func numberTrailBrainScore(avgSeconds: Double) -> Int {
        // 20s avg ≈ 110, 32s avg ≈ 80. Clamped 70–145.
        max(70, min(145, Int(110.0 - (avgSeconds - 20.0) * 2.5)))
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

    @discardableResult
    func recordDigitSpanGame(level: Int) -> Bool {
        if level > digitSpanBestLevel { digitSpanBestLevel = level }
        digitSpanPlayCount += 1
        digitSpanBrainScore = Self.digitSpanBrainScore(level: level)
        digitSpanLastPlayedDate = Date()
        markDailyChallenge("digitspan")
        return addXP(level * 12)
    }

    @discardableResult
    func recordStopSignalGame(accuracy: Int) -> Bool {
        if accuracy > stopSignalBestAccuracy { stopSignalBestAccuracy = accuracy }
        stopSignalPlayCount += 1
        stopSignalBrainScore = Self.stopSignalBrainScore(accuracy: accuracy)
        stopSignalLastPlayedDate = Date()
        markDailyChallenge("stopsignal")
        return addXP(accuracy / 5)
    }

    @discardableResult
    func recordMentalRotationGame(correct: Int) -> Bool {
        if correct > mentalRotationBestScore { mentalRotationBestScore = correct }
        mentalRotationPlayCount += 1
        mentalRotationBrainScore = Self.mentalRotationBrainScore(correct: correct)
        mentalRotationLastPlayedDate = Date()
        markDailyChallenge("mentalrotation")
        return addXP(correct * 6)
    }

    @discardableResult
    func recordWordScrambleGame(score: Int) -> Bool {
        if score > wordScrambleBestScore { wordScrambleBestScore = score }
        wordScramblePlayCount += 1
        wordScrambleBrainScore = Self.wordScrambleBrainScore(score: score)
        wordScrambleLastPlayedDate = Date()
        markDailyChallenge("wordscramble")
        return addXP(score * 15)
    }

    @discardableResult
    func recordNumberTrailGame(avgSeconds: Double) -> Bool {
        if numberTrailBestTime == 0 || avgSeconds < numberTrailBestTime {
            numberTrailBestTime = avgSeconds
        }
        numberTrailPlayCount += 1
        numberTrailBrainScore = Self.numberTrailBrainScore(avgSeconds: avgSeconds)
        numberTrailLastPlayedDate = Date()
        markDailyChallenge("numbertrail")
        let xp = max(5, Int(60.0 / max(1.0, avgSeconds)) * 10)
        return addXP(xp)
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
        case "memory":        dailyChallengeMemoryDone        = true
        case "reflex":        dailyChallengeReflexDone        = true
        case "speed":         dailyChallengeSpeedDone         = true
        case "flanker":       dailyChallengeFlankerDone       = true
        case "spatial":       dailyChallengeSpatialDone       = true
        case "visual":        dailyChallengeVisualDone        = true
        case "pattern":       dailyChallengePatternDone       = true
        case "snapshot":      dailyChallengeSnapshotDone      = true
        case "digitspan":     dailyChallengeDigitSpanDone     = true
        case "stopsignal":    dailyChallengeStopSignalDone    = true
        case "mentalrotation": dailyChallengeMentalRotationDone = true
        case "wordscramble":  dailyChallengeWordScrambleDone  = true
        case "numbertrail":   dailyChallengeNumberTrailDone   = true
        default: break
        }
    }

    private func resetDailyChallengesIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let last = dailyChallengeDate {
            if calendar.startOfDay(for: last) < today {
                dailyChallengeMemoryDone        = false
                dailyChallengeReflexDone        = false
                dailyChallengeSpeedDone         = false
                dailyChallengeFlankerDone       = false
                dailyChallengeSpatialDone       = false
                dailyChallengeVisualDone        = false
                dailyChallengePatternDone       = false
                dailyChallengeSnapshotDone      = false
                dailyChallengeDigitSpanDone     = false
                dailyChallengeStopSignalDone    = false
                dailyChallengeMentalRotationDone = false
                dailyChallengeWordScrambleDone  = false
                dailyChallengeNumberTrailDone   = false
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
        // Cache streak in UserDefaults so TrainBrainApp can read it without SwiftData
        UserDefaults.standard.set(dailyStreakCount, forKey: "cachedStreakCount")
    }
}
