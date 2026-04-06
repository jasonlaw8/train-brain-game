import SwiftUI
import UIKit

// MARK: - SnapshotResultsView
// Progressive reveal: domain bars → Brain Score counter → Brain Age → radar chart.
// Shows baseline/retest delta for session 3+.

struct SnapshotResultsView: View {
    let session: SnapshotSession
    let stats: PlayerStats
    let onDone: () -> Void

    @State private var revealed: Int = 0      // 0–5: gates each reveal step
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    private let revealDelays: [Double] = [0.3, 1.1, 1.9, 2.7, 4.0, 5.0]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                sessionLabel

                // Domain bars (reveal 1–4)
                domainBarsSection

                // Brain Score (reveal 5)
                if revealed >= 5 {
                    brainScoreSection
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                // Radar chart
                if revealed >= 5 {
                    radarSection
                        .transition(.opacity)
                }

                // RCI / change delta (session 3+)
                if stats.snapshotSessionCount >= 3 && revealed >= 5 {
                    changeSection
                }

                // Share + paywall placeholder
                if revealed >= 5 {
                    shareButton
                    if stats.snapshotSessionCount >= 3 {
                        premiumPreviewBanner
                    }
                }

                Button { onDone() } label: {
                    Text("Continue")
                        .font(.title3.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.purple, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top, 20)
        }
        .onAppear { scheduleReveals() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
    }

    // MARK: - Session label

    var sessionLabel: some View {
        VStack(spacing: 4) {
            Text(sessionTitle)
                .font(.caption.bold().smallCaps())
                .foregroundStyle(.secondary)
            if let note = sessionNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    var sessionTitle: String {
        if session.sessionNumber == 1 { return "Preliminary Baseline" }
        if session.isBaseline        { return "Your Baseline" }
        return "Session \(session.sessionNumber)"
    }

    var sessionNote: String? {
        if session.sessionNumber == 1 {
            return "Complete one more session this week for your official baseline."
        }
        if session.isBaseline {
            return "This is your starting point. Train daily and retake weekly to track improvement."
        }
        return nil
    }

    // MARK: - Domain bars

    var domainBarsSection: some View {
        VStack(spacing: 14) {
            Text("Domain Scores")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            VStack(spacing: 10) {
                domainBar(label: "Processing Speed", pct: session.speedPercentile,
                          icon: "bolt.fill", color: .orange, revealStep: 1)
                domainBar(label: "Attention",        pct: session.attentionPercentile,
                          icon: "scope", color: .indigo, revealStep: 2)
                domainBar(label: "Working Memory",   pct: session.memoryPercentile,
                          icon: "brain", color: .blue, revealStep: 3)
                domainBar(label: "Flexibility",      pct: session.flexibilityPercentile,
                          icon: "arrow.triangle.2.circlepath", color: .purple, revealStep: 4)
            }
            .padding(.horizontal)
        }
    }

    func domainBar(label: String, pct: Int, icon: String, color: Color, revealStep: Int) -> some View {
        let labelText = SnapshotNorms.domainLabel(percentile: pct)
        let labelColor = domainLabelColor(labelText)

        return VStack(spacing: 0) {
            if revealed >= revealStep {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 24)

                    Text(label).font(.subheadline)
                    Spacer()
                    Text(labelText)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(labelColor.opacity(0.15))
                        .foregroundStyle(labelColor)
                        .clipShape(Capsule())
                    Text("\(pct)th")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(pct) / 100)
                            .animation(.easeOut(duration: 0.7), value: pct)
                    }
                }
                .frame(height: 8)
            }
        }
        .frame(minHeight: revealed >= revealStep ? 48 : 0)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .animation(.spring(response: 0.5), value: revealed >= revealStep)
    }

    func domainLabelColor(_ label: String) -> Color {
        switch label {
        case "Elite":    return Color(red: 0.56, green: 0.27, blue: 0.68)   // #8E44AD purple
        case "Strong":   return Color(red: 0.15, green: 0.68, blue: 0.38)   // #27AE60 green
        case "Solid":    return Color(red: 0.18, green: 0.46, blue: 0.71)   // #2E75B6 blue
        default:         return Color(red: 0.90, green: 0.49, blue: 0.13)   // #E67E22 orange
        }
    }

    // MARK: - Brain Score

    var brainScoreSection: some View {
        VStack(spacing: 12) {
            Text("Brain Score")
                .font(.subheadline.smallCaps())
                .foregroundStyle(.secondary)

            AnimatedScoreText(
                value: session.brainScore,
                font: .system(size: 72, weight: .bold, design: .rounded),
                color: .primary
            )

            Text("Brain Age: \(session.brainAge)")
                .font(.title3.bold())
                .foregroundStyle(brainAgeColor)

            if let userAge = userAgeString {
                Text(userAge)
                    .font(.caption)
                    .foregroundStyle(brainAgeColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    var brainAgeColor: Color {
        guard !stats.ageRange.isEmpty,
              let userAgeMid = SnapshotNorms.ageBandMidpoints[stats.ageRange] else { return .primary }
        return session.brainAge <= userAgeMid ? .green : .orange
    }

    var userAgeString: String? {
        guard !stats.ageRange.isEmpty,
              let mid = SnapshotNorms.ageBandMidpoints[stats.ageRange] else { return nil }
        let diff = mid - session.brainAge
        if diff > 0  { return "↓ \(diff) years younger than your age group" }
        if diff < 0  { return "Let's work on that! ↑ \(abs(diff)) years above average" }
        return "Right in line with your age group"
    }

    // MARK: - Radar chart

    var radarSection: some View {
        VStack(spacing: 8) {
            Text("Cognitive Profile")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            RadarChartView(
                values: [
                    Double(session.speedPercentile),
                    Double(session.attentionPercentile),
                    Double(session.memoryPercentile),
                    Double(session.flexibilityPercentile)
                ],
                labels: ["Speed", "Attention", "Memory", "Flexibility"],
                color: .purple
            )
            .frame(height: 240)
            .padding(.horizontal)
        }
    }

    // MARK: - Change section (session 3+)

    var changeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("vs. Your Baseline")
                .font(.headline).padding(.horizontal)

            let baselineScore = Double(stats.baselineBrainScore)
            let currentScore  = Double(session.brainScore)
            let rci = SnapshotScoringEngine.reliableChangeIndex(
                retest: currentScore, baseline: baselineScore,
                sdBaseline: 80,   // approximate SD for Brain Score 0–1000 scale
                icc: 0.83,
                expectedPE: 0
            )
            let rciResult = SnapshotScoringEngine.interpretRCI(rci)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brain Score Change")
                        .font(.subheadline).foregroundStyle(.secondary)
                    let delta = session.brainScore - stats.baselineBrainScore
                    Text("\(delta >= 0 ? "+" : "")\(delta) pts")
                        .font(.title3.bold())
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(rciLabel(rciResult))
                        .font(.subheadline.bold())
                        .foregroundStyle(rciColor(rciResult))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if case .unusualDecrease = rciResult {
                Text("Day-to-day fluctuations are normal and can be caused by sleep, stress, or distractions.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    func rciLabel(_ r: SnapshotScoringEngine.RCIResult) -> String {
        switch r {
        case .significantImprovement: return "Significant improvement"
        case .likelyImprovement:      return "Likely real improvement"
        case .normalFluctuation:      return "Within normal fluctuation"
        case .unusualDecrease:        return "Unusual decrease"
        }
    }

    func rciColor(_ r: SnapshotScoringEngine.RCIResult) -> Color {
        switch r {
        case .significantImprovement, .likelyImprovement: return .green
        case .normalFluctuation: return .secondary
        case .unusualDecrease:   return .orange
        }
    }

    // MARK: - Share

    var shareButton: some View {
        Button {
            let card = SnapshotShareCard(session: session, stats: stats)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            shareImage = renderer.uiImage
            showShareSheet = true
        } label: {
            Label("Share Your Results", systemImage: "square.and.arrow.up")
                .font(.subheadline.bold())
                .foregroundStyle(.purple)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    // MARK: - Premium preview banner

    var premiumPreviewBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)
                Text("Track Your Progress Over Time")
                    .font(.subheadline.bold())
                Spacer()
                Text("Coming Soon")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.purple, in: Capsule())
            }

            Text("Unlock weekly trend charts, detailed domain history, and personalized training recommendations.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Blurred mock chart
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 60)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple.opacity(0.3))
                )
                .blur(radius: 2)
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Reveal scheduling

    func scheduleReveals() {
        for (step, delay) in revealDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.5)) {
                    revealed = step + 1
                }
                if step == 4 { Haptics.success() }  // Brain Score reveal
                else { Haptics.light() }
            }
        }
    }
}

// MARK: - RadarChartView

struct RadarChartView: View {
    let values: [Double]     // 0–100 each
    let labels: [String]
    let color: Color

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 28
                let n = values.count
                let angles = (0..<n).map { i in
                    Double(i) * (2 * .pi / Double(n)) - .pi / 2
                }

                // Grid rings at 25%, 50%, 75%, 100%
                for ring in [0.25, 0.50, 0.75, 1.0] {
                    var ringPath = Path()
                    for (i, angle) in angles.enumerated() {
                        let r = radius * ring
                        let pt = CGPoint(x: center.x + r * cos(angle),
                                         y: center.y + r * sin(angle))
                        i == 0 ? ringPath.move(to: pt) : ringPath.addLine(to: pt)
                    }
                    ringPath.closeSubpath()
                    ctx.stroke(ringPath, with: .color(.gray.opacity(0.2)), lineWidth: 1)
                }

                // Axis lines
                for angle in angles {
                    var axisPath = Path()
                    axisPath.move(to: center)
                    axisPath.addLine(to: CGPoint(x: center.x + radius * cos(angle),
                                                  y: center.y + radius * sin(angle)))
                    ctx.stroke(axisPath, with: .color(.gray.opacity(0.2)), lineWidth: 1)
                }

                // Data polygon
                guard !values.isEmpty else { return }
                var dataPath = Path()
                for (i, angle) in angles.enumerated() {
                    let r = radius * (values[i] / 100.0)
                    let pt = CGPoint(x: center.x + r * cos(angle),
                                     y: center.y + r * sin(angle))
                    i == 0 ? dataPath.move(to: pt) : dataPath.addLine(to: pt)
                }
                dataPath.closeSubpath()
                ctx.fill(dataPath, with: .color(color.opacity(0.25)))
                ctx.stroke(dataPath, with: .color(color), lineWidth: 2.5)

                // Data points
                for (i, angle) in angles.enumerated() {
                    let r = radius * (values[i] / 100.0)
                    let pt = CGPoint(x: center.x + r * cos(angle),
                                     y: center.y + r * sin(angle))
                    let dot = Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8))
                    ctx.fill(dot, with: .color(color))
                }
            }

            // Axis labels
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = min(geo.size.width, geo.size.height) / 2 - 10
                let n = labels.count
                ForEach(0..<n, id: \.self) { i in
                    let angle = Double(i) * (2 * .pi / Double(n)) - .pi / 2
                    let pt = CGPoint(x: center.x + radius * cos(angle),
                                      y: center.y + radius * sin(angle))
                    Text(labels[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .position(pt)
                }
            }
        }
    }
}

// MARK: - Snapshot Share Card

struct SnapshotShareCard: View {
    let session: SnapshotSession
    let stats: PlayerStats

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.85), Color.blue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Train Brain")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("Brain Snapshot")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.top, 28)

                Spacer()

                // Brain Score
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(session.brainScore)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                    Text("/ 1000")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .padding(.bottom, 6)
                }
                .foregroundStyle(.white)

                Text("Brain Age: \(session.brainAge)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)

                Spacer()

                // Domain row
                HStack(spacing: 0) {
                    ForEach([
                        ("Speed", session.speedPercentile, Color.orange),
                        ("Attn",  session.attentionPercentile, Color.indigo),
                        ("Mem",   session.memoryPercentile, Color.blue),
                        ("Flex",  session.flexibilityPercentile, Color.teal)
                    ], id: \.0) { label, pct, color in
                        VStack(spacing: 2) {
                            Text("\(pct)th")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(label)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 28)

                HStack {
                    Spacer()
                    Text("trainbrain.app")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
                .padding(.top, 12)
            }
        }
        .frame(width: 400, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
