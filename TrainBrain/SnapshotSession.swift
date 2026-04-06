import Foundation
import SwiftData

// MARK: - SnapshotSession
// One record per Brain Snapshot assessment session.
// Inserted into SwiftData after all 4 tasks complete and scores are computed.

@Model
final class SnapshotSession {
    var id: UUID = UUID()
    var sessionNumber: Int = 0       // 1, 2, 3, … (from PlayerStats.snapshotSessionCount)
    var date: Date = Date()
    var isCalibration: Bool = false  // true for sessions 1 & 2
    var isBaseline: Bool = false     // true only for session 2

    // MARK: Task 1 — Lightning Tap (Processing Speed)
    var ltMedianSimpleRT: Double = 0    // milliseconds (raw)
    var ltMedianChoiceRT: Double = 0    // milliseconds (raw)
    var ltCoefficientOfVariation: Double = 0  // SD/mean of all valid log-RTs
    var ltValidTrials: Int = 0

    // MARK: Task 2 — Arrow Storm (Attention & Inhibitory Control)
    var asIncongruentAccuracy: Double = 0   // 0.0–1.0
    var asMedianIncongruentRT: Double = 0   // milliseconds
    var asFlankerScore: Double = 0          // 0–10 NIH composite

    // MARK: Task 3 — Card Match (Working Memory)
    var cmHitRate: Double = 0           // 0.0–1.0
    var cmFalseAlarmRate: Double = 0    // 0.0–1.0
    var cmDPrime: Double = 0            // signal-detection d'
    var cmMedianMatchRT: Double = 0     // milliseconds, correct match trials only

    // MARK: Task 4 — Shape Shift (Cognitive Flexibility)
    var ssMixedAccuracy: Double = 0     // 0.0–1.0, mixed block only
    var ssMixedMedianRT: Double = 0     // milliseconds, correct mixed trials
    var ssEfficiencyScore: Double = 0   // accuracy / medianRT if accuracy > 95%, else 0

    // MARK: Composite scores
    var speedPercentile: Int = 0        // 1–99, from norm tables
    var attentionPercentile: Int = 0
    var memoryPercentile: Int = 0
    var flexibilityPercentile: Int = 0
    var brainScore: Int = 0             // 0–1000
    var brainAge: Int = 0               // estimated age (midpoint of closest norm band)

    // MARK: Raw trial data (JSON-encoded for debugging / future analysis)
    var rawTrialData: Data? = nil

    init(
        sessionNumber: Int,
        isCalibration: Bool,
        isBaseline: Bool
    ) {
        self.id = UUID()
        self.sessionNumber = sessionNumber
        self.date = Date()
        self.isCalibration = isCalibration
        self.isBaseline = isBaseline
    }
}

// MARK: - TrialRecord
// Codable struct stored as JSON in SnapshotSession.rawTrialData.

struct TrialRecord: Codable {
    var trialNumber: Int
    var taskName: String          // "lightningTap" | "arrowStorm" | "cardMatch" | "shapeShift"

    // Lightning Tap fields
    var phase: String?            // "simple" | "choice"
    var orbColor: String?         // "green" | "red" (Phase B only)

    // Arrow Storm fields
    var trialType: String?        // "congruent" | "incongruent"
    var centerDirection: String?  // "left" | "right"

    // Card Match fields
    var cardRank: String?
    var cardSuit: String?
    var isTargetMatch: Bool?

    // Shape Shift fields
    var block: String?            // "color" | "shape" | "mixed"
    var currentRule: String?      // "color" | "shape"
    var stimulusColor: String?
    var stimulusShape: String?
    var isSwitchTrial: Bool?

    // Common
    var userResponse: String?     // varies by task
    var reactionTimeMs: Int
    var isCorrect: Bool
    var isAnticipatory: Bool      // RT < 100ms (Lightning Tap)
    var isLapse: Bool             // RT > window or no response
}
