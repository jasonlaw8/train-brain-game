import Foundation

// MARK: - SnapshotMetric
// The four primary metrics that feed into domain percentiles.

enum SnapshotMetric {
    case simpleRT       // lower = better (Lightning Tap median simple RT, ms)
    case flankerScore   // higher = better (Arrow Storm NIH composite 0–10)
    case dPrime         // higher = better (Card Match d')
    case flexRT         // lower = better (Shape Shift mixed-block median RT, ms)
}

// MARK: - SnapshotNorms
// Provisional norm tables seeded from published Cogstate / NIH Toolbox data.
// Each table maps percentile → raw value for a given age band.
// Interpolation is linear between rows.
// As user base grows, replace with app-specific percentiles.

struct SnapshotNorms {

    // MARK: Age-band midpoints for Brain Age display
    static let ageBandMidpoints: [String: Int] = [
        "18-24": 21,
        "25-34": 30,
        "35-44": 40,
        "45-54": 50,
        "55+":   60
    ]

    static let allBands = ["18-24", "25-34", "35-44", "45-54", "55+"]

    // MARK: Norm table type: [(percentile, rawValue)]
    // For RT metrics: lower raw = faster = higher percentile (table sorted descending by raw)
    // For score metrics: higher raw = better = higher percentile (table sorted ascending by raw)

    // MARK: Median Simple RT norms (milliseconds)
    // Lower RT = faster = better (use inversion when computing domain percentile)
    // Source: Cogstate Detection Task norms + published RT literature
    private static let simpleRTNorms: [String: [(pct: Int, ms: Double)]] = [
        "18-24": [(90,210),(75,240),(50,275),(25,320),(10,380)],
        "25-34": [(90,220),(75,250),(50,285),(25,335),(10,400)],
        "35-44": [(90,235),(75,265),(50,300),(25,355),(10,420)],
        "45-54": [(90,255),(75,285),(50,320),(25,380),(10,450)],
        "55+":   [(90,270),(75,305),(50,345),(25,405),(10,475)]
    ]

    // MARK: Flanker composite score norms (0–10 NIH scale)
    // Higher = better
    // Source: NIH Toolbox Flanker norms (ages 18+)
    private static let flankerNorms: [String: [(pct: Int, score: Double)]] = [
        "18-24": [(10,5.2),(25,6.1),(50,7.0),(75,7.8),(90,8.5)],
        "25-34": [(10,5.0),(25,5.9),(50,6.8),(75,7.6),(90,8.3)],
        "35-44": [(10,4.7),(25,5.6),(50,6.5),(75,7.3),(90,8.1)],
        "45-54": [(10,4.4),(25,5.3),(50,6.2),(75,7.0),(90,7.8)],
        "55+":   [(10,4.0),(25,4.8),(50,5.8),(75,6.6),(90,7.4)]
    ]

    // MARK: d-prime norms (Card Match n-back)
    // Higher = better
    // Source: Published working memory norms (Cogstate One Back)
    private static let dPrimeNorms: [String: [(pct: Int, score: Double)]] = [
        "18-24": [(10,0.5),(25,1.0),(50,1.7),(75,2.4),(90,3.0)],
        "25-34": [(10,0.4),(25,0.9),(50,1.6),(75,2.3),(90,2.9)],
        "35-44": [(10,0.3),(25,0.8),(50,1.5),(75,2.1),(90,2.7)],
        "45-54": [(10,0.2),(25,0.7),(50,1.3),(75,1.9),(90,2.5)],
        "55+":   [(10,0.1),(25,0.5),(50,1.1),(75,1.7),(90,2.2)]
    ]

    // MARK: Mixed-block median RT norms (Shape Shift, milliseconds)
    // Lower RT = faster = better (use inversion when computing domain percentile)
    // Source: Published task-switching literature
    private static let flexRTNorms: [String: [(pct: Int, ms: Double)]] = [
        "18-24": [(90,620),(75,720),(50,840),(25,990),(10,1180)],
        "25-34": [(90,650),(75,755),(50,880),(25,1040),(10,1240)],
        "35-44": [(90,690),(75,800),(50,940),(25,1110),(10,1320)],
        "45-54": [(90,740),(75,860),(50,1010),(25,1200),(10,1420)],
        "55+":   [(90,800),(75,940),(50,1110),(25,1320),(10,1560)]
    ]

    // MARK: - Percentile lookup

    /// Convert a raw metric value to an age-band percentile (1–99).
    static func percentile(metric: SnapshotMetric, value: Double, ageBand: String) -> Int {
        switch metric {
        case .simpleRT:
            return rtPercentile(value: value, table: simpleRTNorms[ageBand] ?? simpleRTNorms["35-44"]!)
        case .flankerScore:
            return scorePercentile(value: value, table: flankerNorms[ageBand] ?? flankerNorms["35-44"]!)
        case .dPrime:
            return scorePercentile(value: value, table: dPrimeNorms[ageBand] ?? dPrimeNorms["35-44"]!)
        case .flexRT:
            return rtPercentile(value: value, table: flexRTNorms[ageBand] ?? flexRTNorms["35-44"]!)
        }
    }

    /// For RT metrics: lower value → higher percentile.
    /// Table format: [(pct, ms)] sorted descending by ms (90th = fastest).
    private static func rtPercentile(value: Double, table: [(pct: Int, ms: Double)]) -> Int {
        // Table is sorted: (90, fastest_ms) ... (10, slowest_ms)
        // If value < fastest norm → clamp to 99
        // If value > slowest norm → clamp to 1
        // Otherwise interpolate

        // Sort ascending by ms so we can interpolate
        let sorted = table.sorted { $0.ms < $1.ms }  // fast → slow, pct 90 → 10

        if value <= sorted.first!.ms { return 99 }
        if value >= sorted.last!.ms  { return 1 }

        for i in 0..<(sorted.count - 1) {
            let lo = sorted[i]   // lower ms = higher pct
            let hi = sorted[i+1] // higher ms = lower pct
            if value >= lo.ms && value <= hi.ms {
                let t = (value - lo.ms) / (hi.ms - lo.ms)
                let interpolated = Double(lo.pct) + t * Double(hi.pct - lo.pct)
                return max(1, min(99, Int(interpolated.rounded())))
            }
        }
        return 50
    }

    /// For score metrics: higher value → higher percentile.
    /// Table format: [(pct, score)] sorted ascending by score (10th = lowest score).
    private static func scorePercentile(value: Double, table: [(pct: Int, score: Double)]) -> Int {
        let sorted = table.sorted { $0.score < $1.score }  // low → high, pct 10 → 90

        if value <= sorted.first!.score { return max(1, sorted.first!.pct - 5) }
        if value >= sorted.last!.score  { return min(99, sorted.last!.pct + 5) }

        for i in 0..<(sorted.count - 1) {
            let lo = sorted[i]
            let hi = sorted[i+1]
            if value >= lo.score && value <= hi.score {
                let t = (value - lo.score) / (hi.score - lo.score)
                let interpolated = Double(lo.pct) + t * Double(hi.pct - lo.pct)
                return max(1, min(99, Int(interpolated.rounded())))
            }
        }
        return 50
    }

    // MARK: - Brain Age estimation

    /// Estimate brain age by finding the age band whose 50th-percentile norms
    /// most closely match the user's raw scores (Euclidean distance after z-standardising).
    static func brainAge(
        speedRT: Double,
        flankerScore: Double,
        dPrime: Double,
        flexRT: Double
    ) -> Int {
        // Reference values: 50th percentile for each band
        let ref50: [String: (rt: Double, fl: Double, dp: Double, fx: Double)] = [
            "18-24": (275, 7.0, 1.7, 840),
            "25-34": (285, 6.8, 1.6, 880),
            "35-44": (300, 6.5, 1.5, 940),
            "45-54": (320, 6.2, 1.3, 1010),
            "55+":   (345, 5.8, 1.1, 1110)
        ]

        // Z-standardisation denominators (approx SD across all age 50th percentiles)
        let sdRT: Double   = 30   // ms spread across bands
        let sdFl: Double   = 0.5
        let sdDp: Double   = 0.3
        let sdFx: Double   = 100

        var bestBand = "35-44"
        var bestDist = Double.infinity

        for band in allBands {
            guard let ref = ref50[band] else { continue }
            // For RT: higher raw = worse, so flip sign so that bigger difference = bigger distance
            let dRT = (speedRT - ref.rt) / sdRT
            let dFl = (flankerScore - ref.fl) / sdFl
            let dDp = (dPrime - ref.dp) / sdDp
            let dFx = (flexRT - ref.fx) / sdFx
            let dist = sqrt(dRT*dRT + dFl*dFl + dDp*dDp + dFx*dFx)
            if dist < bestDist {
                bestDist = dist
                bestBand = band
            }
        }

        return ageBandMidpoints[bestBand] ?? 35
    }

    // MARK: - Domain label

    /// Map a percentile to the spec's user-facing performance label.
    static func domainLabel(percentile: Int) -> String {
        switch percentile {
        case 76...99: return "Elite"
        case 51...75: return "Strong"
        case 26...50: return "Solid"
        default:       return "Building"
        }
    }
}
