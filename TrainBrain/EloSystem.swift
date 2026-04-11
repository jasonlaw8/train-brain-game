import CoreGraphics

/// Pure Elo rating math — no SwiftData or UI dependencies.
/// K = 32, 400-point logistic curve (standard chess variant).
/// Target success rate: 75% (flow-state sweet spot).
enum EloSystem {
    static let defaultRating: Double = 1000
    static let K: Double = 32
    static let floor: Double = 600

    // MARK: - Core Math

    /// Probability that a player at `playerRating` answers a question of `questionRating` correctly.
    static func expectedProbability(playerRating: Double, questionRating: Double) -> Double {
        1.0 / (1.0 + pow(10.0, (questionRating - playerRating) / 400.0))
    }

    /// Returns the updated Elo rating after a response.
    /// `questionRating` defaults to 1000 (average difficulty).
    static func updated(_ rating: Double, correct: Bool, questionRating: Double = 1000) -> Double {
        let expected = expectedProbability(playerRating: rating, questionRating: questionRating)
        let actual: Double = correct ? 1.0 : 0.0
        return max(floor, rating + K * (actual - expected))
    }

    // MARK: - Per-Game Difficulty Params

    // ── Echo Grid (Memory) ───────────────────────────────────────
    struct MemoryParams {
        let startLength: Int
        let highlightDuration: Double   // seconds per tile
        let pauseDuration: Double       // gap between tiles
    }
    static func memoryParams(_ r: Double) -> MemoryParams {
        switch r {
        case ..<1000:  return .init(startLength: 3, highlightDuration: 0.70, pauseDuration: 0.30)
        case 1000..<1200: return .init(startLength: 4, highlightDuration: 0.55, pauseDuration: 0.25)
        default:       return .init(startLength: 5, highlightDuration: 0.35, pauseDuration: 0.18)
        }
    }

    // ── Lightning Tap (Reflex) ────────────────────────────────────
    struct ReflexParams {
        let targetSize: CGFloat
        let delayMin: Double
        let delayMax: Double
    }
    static func reflexParams(_ r: Double) -> ReflexParams {
        switch r {
        case ..<1000:  return .init(targetSize: 104, delayMin: 1.5, delayMax: 3.5)
        case 1000..<1200: return .init(targetSize: 88,  delayMin: 1.0, delayMax: 3.0)
        default:       return .init(targetSize: 64,  delayMin: 0.5, delayMax: 2.0)
        }
    }

    // ── Number Rush (Math) ────────────────────────────────────────
    struct MathParams {
        let maxNumber: Int
        let useNumberPad: Bool
        let timerSeconds: Double
        let includeMultiply: Bool
        let useScenarios: Bool
    }
    static func mathParams(_ r: Double) -> MathParams {
        switch r {
        case ..<900:
            return .init(maxNumber: 9,  useNumberPad: false, timerSeconds: 60, includeMultiply: false, useScenarios: false)
        case 900..<1000:
            return .init(maxNumber: 20, useNumberPad: false, timerSeconds: 60, includeMultiply: false, useScenarios: false)
        case 1000..<1100:
            return .init(maxNumber: 50, useNumberPad: true,  timerSeconds: 60, includeMultiply: true,  useScenarios: false)
        case 1100..<1200:
            return .init(maxNumber: 50, useNumberPad: true,  timerSeconds: 50, includeMultiply: true,  useScenarios: true)
        default:
            return .init(maxNumber: 99, useNumberPad: true,  timerSeconds: 45, includeMultiply: true,  useScenarios: true)
        }
    }

    // ── Fish School (Flanker) ──────────────────────────────────────
    struct FlankerParams {
        let congruentRatio: Double      // fraction of congruent trials
        let responseWindow: Double      // seconds
        let includeVertical: Bool       // 3-direction mode
    }
    static func flankerParams(_ r: Double) -> FlankerParams {
        switch r {
        case ..<1000:  return .init(congruentRatio: 0.70, responseWindow: 2.0, includeVertical: false)
        case 1000..<1100: return .init(congruentRatio: 0.50, responseWindow: 1.5, includeVertical: false)
        case 1100..<1200: return .init(congruentRatio: 0.30, responseWindow: 1.5, includeVertical: false)
        default:       return .init(congruentRatio: 0.30, responseWindow: 1.2, includeVertical: true)
        }
    }

    // ── Star Map (Spatial Memory) ─────────────────────────────────
    struct SpatialParams {
        let gridSize: Int
        let cellCount: Int
        let displayTime: Double         // seconds
    }
    static func spatialParams(_ r: Double) -> SpatialParams {
        switch r {
        case ..<950:   return .init(gridSize: 3, cellCount: 3, displayTime: 2.0)
        case 950..<1050: return .init(gridSize: 4, cellCount: 4, displayTime: 1.5)
        case 1050..<1150: return .init(gridSize: 4, cellCount: 5, displayTime: 1.0)
        case 1150..<1250: return .init(gridSize: 5, cellCount: 6, displayTime: 0.8)
        default:       return .init(gridSize: 5, cellCount: 7, displayTime: 0.5)
        }
    }

    // ── Odd One Out (Visual Search) ───────────────────────────────
    struct VisualSearchParams {
        let gridStart: Int
        let timePerRound: Double
    }
    static func visualSearchParams(_ r: Double) -> VisualSearchParams {
        switch r {
        case ..<1000:  return .init(gridStart: 9,  timePerRound: 5.0)
        case 1000..<1100: return .init(gridStart: 12, timePerRound: 4.0)
        default:       return .init(gridStart: 16, timePerRound: 3.0)
        }
    }

    // ── Code Cracker (Pattern Match) ─────────────────────────────
    enum PatternCategory: String, CaseIterable {
        case addition, multiplication, fibonacci, alternating, squares
    }
    struct PatternParams {
        let categories: [PatternCategory]
        let timeLimit: Double?              // nil = unlimited
    }
    static func patternParams(_ r: Double) -> PatternParams {
        switch r {
        case ..<950:   return .init(categories: [.addition], timeLimit: nil)
        case 950..<1050: return .init(categories: [.addition, .multiplication], timeLimit: 15)
        case 1050..<1150: return .init(categories: [.multiplication, .fibonacci, .squares], timeLimit: 10)
        default:       return .init(categories: PatternCategory.allCases, timeLimit: 8)
        }
    }

    // ── Vault Cracker (Digit Span) ────────────────────────────────
    struct DigitSpanParams {
        let startLength: Int
        let displayTime: Double     // seconds per digit
        let lives: Int
    }
    static func digitSpanParams(_ r: Double) -> DigitSpanParams {
        switch r {
        case ..<950:   return .init(startLength: 3, displayTime: 0.90, lives: 3)
        case 950..<1050: return .init(startLength: 4, displayTime: 0.70, lives: 2)
        case 1050..<1150: return .init(startLength: 5, displayTime: 0.55, lives: 2)
        default:       return .init(startLength: 5, displayTime: 0.40, lives: 1)
        }
    }

    // ── Bug Catcher (Stop Signal) ─────────────────────────────────
    struct StopSignalParams {
        let stopDelay: Double       // seconds after GO signal before STOP appears
    }
    static func stopSignalParams(_ r: Double) -> StopSignalParams {
        switch r {
        case ..<950:   return .init(stopDelay: 0.300)
        case 950..<1050: return .init(stopDelay: 0.225)
        case 1050..<1150: return .init(stopDelay: 0.175)
        default:       return .init(stopDelay: 0.125)
        }
    }

    // ── Block Builder (Mental Rotation) ──────────────────────────
    struct RotationParams {
        let use3D: Bool
        let timeLimit: Double
    }
    static func rotationParams(_ r: Double) -> RotationParams {
        switch r {
        case ..<950:   return .init(use3D: false, timeLimit: 8.0)
        case 950..<1050: return .init(use3D: false, timeLimit: 6.0)
        case 1050..<1150: return .init(use3D: true,  timeLimit: 5.0)
        default:       return .init(use3D: true,  timeLimit: 4.0)
        }
    }

    // ── Dot Connect (Number Trail) ────────────────────────────────
    struct TrailParams {
        let circleCount: Int
        let useAlphaMode: Bool      // TMT-B: alternate numbers and letters
        let circleSize: CGFloat
    }
    static func trailParams(_ r: Double) -> TrailParams {
        switch r {
        case ..<950:   return .init(circleCount: 9,  useAlphaMode: false, circleSize: 44)
        case 950..<1050: return .init(circleCount: 12, useAlphaMode: false, circleSize: 36)
        case 1050..<1150: return .init(circleCount: 15, useAlphaMode: false, circleSize: 30)
        case 1150..<1250: return .init(circleCount: 15, useAlphaMode: false, circleSize: 26)
        default:       return .init(circleCount: 12, useAlphaMode: true,  circleSize: 28)
        }
    }

    // ── Word Hunt ─────────────────────────────────────────────────
    struct WordHuntParams {
        let letterCount: Int
        let timerSeconds: Double
    }
    static func wordHuntParams(_ r: Double) -> WordHuntParams {
        switch r {
        case ..<1000:  return .init(letterCount: 6, timerSeconds: 90)
        case 1000..<1150: return .init(letterCount: 7, timerSeconds: 90)
        default:       return .init(letterCount: 7, timerSeconds: 75)
        }
    }
}
