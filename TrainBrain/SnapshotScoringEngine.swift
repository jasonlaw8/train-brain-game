import Foundation

// MARK: - SnapshotScoringEngine
// Pure functions — no SwiftData, no UI. Called by BrainSnapshotView after all 4 tasks complete.

struct SnapshotScoringEngine {

    // MARK: - Task 1: Lightning Tap (Processing Speed)

    /// Median of log10-transformed RTs. Returns value in milliseconds for display;
    /// log10 form is used only internally for statistical validity.
    static func medianRT(_ rtsMs: [Double]) -> Double {
        guard !rtsMs.isEmpty else { return 0 }
        let logs = rtsMs.map { log10($0) }
        let sorted = logs.sorted()
        let mid = sorted.count / 2
        let logMedian = sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return pow(10, logMedian)   // convert back to ms for storage / display
    }

    /// Coefficient of Variation on log10-transformed RTs.
    static func coefficientOfVariation(_ rtsMs: [Double]) -> Double {
        guard rtsMs.count > 1 else { return 0 }
        let logs = rtsMs.map { log10($0) }
        let mean = logs.reduce(0, +) / Double(logs.count)
        let variance = logs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(logs.count - 1)
        let sd = sqrt(variance)
        guard mean > 0 else { return 0 }
        return sd / abs(mean)
    }

    // MARK: - Task 2: Arrow Storm (Attention & Inhibitory Control)

    /// NIH Toolbox Flanker scoring method (two-branch, per spec §2.2).
    /// accuracy: proportion correct on incongruent trials (0.0–1.0)
    /// medianIncongruentRT: median RT on correct incongruent trials, in milliseconds
    static func flankerScore(accuracy: Double, medianIncongruentRT: Double) -> Double {
        if accuracy > 0.80 {
            let rtComponent = medianIncongruentRT > 0 ? (1.0 / medianIncongruentRT) * 2000 : 0
            return min(10.0, accuracy * 0.125 + rtComponent)
        } else {
            return accuracy * 5.0
        }
    }

    // MARK: - Task 3: Card Match (Working Memory)

    /// d-prime with Snodgrass (1980) correction to prevent infinite z-scores.
    /// hits: number of correctly identified matches
    /// targets: total match trials (should be ~8)
    /// falseAlarms: number of "Match" responses on non-match trials
    /// nonTargets: total non-match trials (should be ~16)
    static func dPrime(hits: Int, targets: Int, falseAlarms: Int, nonTargets: Int) -> Double {
        guard targets > 0, nonTargets > 0 else { return 0 }

        // Snodgrass correction
        let hRate: Double
        if hits == targets {
            hRate = (Double(hits) - 0.5) / Double(targets)
        } else {
            hRate = Double(hits) / Double(targets)
        }

        let faRate: Double
        if falseAlarms == 0 {
            faRate = 0.5 / Double(nonTargets)
        } else {
            faRate = Double(falseAlarms) / Double(nonTargets)
        }

        // Clamp to valid range
        let hClamped  = max(0.001, min(0.999, hRate))
        let faClamped = max(0.001, min(0.999, faRate))

        return inversePhi(hClamped) - inversePhi(faClamped)
    }

    // MARK: - Task 4: Shape Shift (Cognitive Flexibility)

    /// Efficiency score for high-accuracy performers. Per spec §2.4.
    static func shapeShiftEfficiency(accuracy: Double, medianRT: Double) -> Double {
        guard accuracy > 0.95, medianRT > 0 else { return 0 }
        return accuracy / medianRT
    }

    // MARK: - Composite Brain Score (Level 3)

    /// Average the four domain percentiles (inverting RT-based ones) and scale to 0–1000.
    /// RT metrics (speed, flex) are inverted: if you're at the 20th percentile for speed,
    /// 80% of people are faster → inverted = 80 → points in the right direction.
    static func brainScore(
        speedPercentile: Int,    // from simpleRT norm (lower RT = higher pct already from norm table)
        attentionPercentile: Int,
        memoryPercentile: Int,
        flexPercentile: Int      // from flexRT norm (lower RT = higher pct already from norm table)
    ) -> Int {
        // Note: SnapshotNorms.percentile already returns a "higher = better" percentile for RT metrics
        // (90th percentile = fastest reaction time), so no manual inversion needed.
        let avg = Double(speedPercentile + attentionPercentile + memoryPercentile + flexPercentile) / 4.0
        return max(0, min(1000, Int((avg * 10).rounded())))
    }

    // MARK: - Reliable Change Index (§6.3)

    /// RCI for detecting statistically significant change between sessions.
    /// retest, baseline: the primary metric values being compared
    /// sdBaseline: standard deviation of the baseline metric (use published SD if unavailable)
    /// icc: test-retest reliability (from spec ICC table; use published values cold-start)
    /// expectedPE: expected practice effect (0 until 200+ sessions accumulated)
    static func reliableChangeIndex(
        retest: Double,
        baseline: Double,
        sdBaseline: Double,
        icc: Double,
        expectedPE: Double = 0
    ) -> Double {
        guard sdBaseline > 0 else { return 0 }
        let seDiff = sdBaseline * sqrt(2 * (1 - icc))
        guard seDiff > 0 else { return 0 }
        return (retest - baseline - expectedPE) / seDiff
    }

    // MARK: - RCI interpretation

    enum RCIResult {
        case significantImprovement   // RCI > 1.96 (95% CI)
        case likelyImprovement        // RCI > 1.645 (90% CI)
        case normalFluctuation        // |RCI| < 1.645
        case unusualDecrease          // RCI < -1.645
    }

    static func interpretRCI(_ rci: Double) -> RCIResult {
        if rci > 1.96  { return .significantImprovement }
        if rci > 1.645 { return .likelyImprovement }
        if rci < -1.645 { return .unusualDecrease }
        return .normalFluctuation
    }

    // MARK: - Inverse normal CDF (Abramowitz & Stegun rational approximation)
    // Accurate to ±4.5×10⁻⁴ for 0 < p < 1. No Foundation/Accelerate import needed.

    static func inversePhi(_ p: Double) -> Double {
        let p0 = max(0.0001, min(0.9999, p))

        // Coefficients for rational approximation
        let a = [-3.969683028665376e+01,  2.209460984245205e+02,
                 -2.759285104469687e+02,  1.383577518672690e+02,
                 -3.066479806614716e+01,  2.506628277459239e+00]
        let b = [-5.447609879822406e+01,  1.615858368580409e+02,
                 -1.556989798598866e+02,  6.680131188771972e+01,
                 -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01,
                 -2.400758277161838e+00, -2.549732539343734e+00,
                  4.374664141464968e+00,  2.938163982698783e+00]
        let d = [ 7.784695709041462e-03,  3.224671290700398e-01,
                  2.445134137142996e+00,  3.754408661907416e+00]

        let pLow  = 0.02425
        let pHigh = 1 - pLow

        var q: Double
        var r: Double

        if p0 < pLow {
            q = sqrt(-2 * log(p0))
            return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) /
                   ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
        } else if p0 <= pHigh {
            q = p0 - 0.5
            r = q * q
            return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q /
                   (((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)
        } else {
            q = sqrt(-2 * log(1 - p0))
            return -(((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) /
                    ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
        }
    }

    // MARK: - Score computation helper (full pipeline for one session)

    struct TaskResults {
        // Task 1
        var ltValidSimpleRTs: [Double]   // ms, already filtered (no lapse, no anticipatory)
        var ltValidChoiceRTs: [Double]   // ms, correct green trials only
        var ltAllValidRTs: [Double]      // for CV computation

        // Task 2
        var asIncongruentCorrect: Int
        var asIncongruentTotal: Int      // should be 12
        var asIncongruentRTs: [Double]   // correct incongruent trial RTs, ms

        // Task 3
        var cmHits: Int
        var cmTargets: Int              // should be ~8
        var cmFalseAlarms: Int
        var cmNonTargets: Int           // should be ~16
        var cmCorrectMatchRTs: [Double] // ms

        // Task 4
        var ssCorrectMixed: Int
        var ssMixedTotal: Int           // should be 12
        var ssMixedCorrectRTs: [Double] // ms
    }

    static func computeScores(from results: TaskResults, ageBand: String) -> (
        session: (
            ltMedianSimpleRT: Double, ltMedianChoiceRT: Double,
            ltCV: Double, ltValidTrials: Int,
            asAccuracy: Double, asMedianRT: Double, asFlankerScore: Double,
            cmHitRate: Double, cmFARate: Double, cmDPrime: Double, cmMatchRT: Double,
            ssMixedAccuracy: Double, ssMixedMedianRT: Double, ssEfficiency: Double
        ),
        percentiles: (speed: Int, attention: Int, memory: Int, flex: Int),
        brainScore: Int,
        brainAge: Int
    ) {
        // Task 1
        let ltSimpleRT = medianRT(results.ltValidSimpleRTs)
        let ltChoiceRT = medianRT(results.ltValidChoiceRTs)
        let ltCV       = coefficientOfVariation(results.ltAllValidRTs)
        let ltValid    = results.ltValidSimpleRTs.count + results.ltValidChoiceRTs.count

        // Task 2
        let asAcc    = results.asIncongruentTotal > 0
            ? Double(results.asIncongruentCorrect) / Double(results.asIncongruentTotal) : 0
        let asRT     = medianRT(results.asIncongruentRTs)
        let asScore  = flankerScore(accuracy: asAcc, medianIncongruentRT: asRT)

        // Task 3
        let cmHR  = results.cmTargets > 0 ? Double(results.cmHits) / Double(results.cmTargets) : 0
        let cmFAR = results.cmNonTargets > 0 ? Double(results.cmFalseAlarms) / Double(results.cmNonTargets) : 0
        let cmDP  = dPrime(hits: results.cmHits, targets: results.cmTargets,
                          falseAlarms: results.cmFalseAlarms, nonTargets: results.cmNonTargets)
        let cmRT  = medianRT(results.cmCorrectMatchRTs)

        // Task 4
        let ssAcc  = results.ssMixedTotal > 0
            ? Double(results.ssCorrectMixed) / Double(results.ssMixedTotal) : 0
        let ssRT   = medianRT(results.ssMixedCorrectRTs)
        let ssEff  = shapeShiftEfficiency(accuracy: ssAcc, medianRT: ssRT)

        // Percentiles (SnapshotNorms handles "higher = better" for all)
        let speedPct = SnapshotNorms.percentile(metric: .simpleRT,    value: ltSimpleRT,  ageBand: ageBand)
        let attPct   = SnapshotNorms.percentile(metric: .flankerScore, value: asScore,     ageBand: ageBand)
        let memPct   = SnapshotNorms.percentile(metric: .dPrime,       value: cmDP,        ageBand: ageBand)
        let flexPct  = SnapshotNorms.percentile(metric: .flexRT,       value: ssRT > 0 ? ssRT : 1500, ageBand: ageBand)

        let bs = brainScore(speedPercentile: speedPct, attentionPercentile: attPct,
                            memoryPercentile: memPct, flexPercentile: flexPct)
        let ba = SnapshotNorms.brainAge(speedRT: ltSimpleRT, flankerScore: asScore,
                                         dPrime: cmDP, flexRT: ssRT > 0 ? ssRT : 1500)

        return (
            session: (ltSimpleRT, ltChoiceRT, ltCV, ltValid,
                      asAcc, asRT, asScore,
                      cmHR, cmFAR, cmDP, cmRT,
                      ssAcc, ssRT, ssEff),
            percentiles: (speedPct, attPct, memPct, flexPct),
            brainScore: bs,
            brainAge: ba
        )
    }
}
