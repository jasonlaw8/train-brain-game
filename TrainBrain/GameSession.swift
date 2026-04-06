import SwiftData
import Foundation

// One record per game played. Powers historical charts and trend calculations.
@Model
final class GameSession {
    var gameType: String    // "memory" | "reflex" | "speed" | "color"
    var date: Date
    var rawScore: Int       // game-native value: level (memory), ms (reflex), correct count (speed)
    var brainScore: Int     // normalized 70–145; 0 if not a scored metric (e.g. color)
    var difficulty: String  // "Easy" | "Medium" | "Hard"

    init(gameType: String, date: Date = Date(), rawScore: Int, brainScore: Int, difficulty: String) {
        self.gameType = gameType
        self.date = date
        self.rawScore = rawScore
        self.brainScore = brainScore
        self.difficulty = difficulty
    }
}
