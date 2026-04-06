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
                domainBarsSection
                revealedContent
                continueButton
            }
            .padding(.top, 20)
        }
        .onAppear { scheduleReveals() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
    }

    @ViewBuilder
    private var revealedContent: some View {
        if revealed >= 5 {
            brainScoreSection
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            radarSection
                .transition(.opacity)
            if stats.snapshotSessionCount >= 3 {
                changeSection
            }
            shareButton
            if stats.snapshotSessionCount >= 3 {
                premiumPreviewBanner
            }
        }
    }

    private var continueButton: some View {
        Button { onDone() } label: {
            Text("Continue")
                .font(.title3.bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.purple, in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
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
        let isRevealed = revealed >= revealStep
        let labelText = SnapshotNorms.domainLabel(percentile: pct)
        let labelColor = domainLabelColor(labelText)
        let fillFraction: CGFloat = CGFloat(pct) / 100.0

        return VStack(spacing: 0) {
            if isRevealed {
                domainBarHeader(label: label, icon: icon, color: color,
                                labelText: labelText, labelColor: labelColor, pct: pct)
                domainBarFill(color: color, fraction: fillFraction)
            }
        }
        .frame(minHeight: isRevealed ? 48 : 0)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .animation(.spring(response: 0.5), value: isRevealed)
    }

    private func domainBarHeader(label: String, icon: String, color: Color,
                                  labelText: String, labelColor: Color, pct: Int) -> some View {
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
    }

    private func domainBarFill(color: Color, fraction: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.7), value: fraction)
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

    private var scoreDelta: Int {
        session.brainScore - stats.baselineBrainScore
    }

    private var rciResult: SnapshotScoringEngine.RCIResult {
        let rci = SnapshotScoringEngine.reliableChangeIndex(
            retest: Double(session.brainScore),
            baseline: Double(stats.baselineBrainScore),
            sdBaseline: 80,
            icc: 0.83,
            expectedPE: 0
        )
        return SnapshotScoringEngine.interpretRCI(rci)
    }

    var changeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("vs. Your Baseline")
                .font(.headline).padding(.horizontal)

            changeDeltaCard

            if case .unusualDecrease = rciResult {
                Text("Day-to-day fluctuations are normal and can be caused by sleep, stress, or distractions.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var changeDeltaCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Brain Score Change")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("\(scoreDelta >= 0 ? "+" : "")\(scoreDelta) pts")
                    .font(.title3.bold())
                    .foregroundStyle(scoreDelta >= 0 ? .green : .orange)
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
                self.drawRadar(ctx: ctx, size: size)
            }
            GeometryReader { geo in
                axisLabels(in: geo.size)
            }
        }
    }

    private func drawRadar(ctx: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 28
        let n = values.count
        guard n > 0 else { return }
        let step: Double = 2.0 * Double.pi / Double(n)
        let halfPi: Double = Double.pi / 2.0
        let angles: [Double] = (0..<n).map { Double($0) * step - halfPi }
        drawGrid(ctx: ctx, center: center, radius: radius, angles: angles)
        drawAxes(ctx: ctx, center: center, radius: radius, angles: angles)
        drawData(ctx: ctx, center: center, radius: radius, angles: angles)
    }

    private func drawGrid(ctx: GraphicsContext, center: CGPoint, radius: Double, angles: [Double]) {
        for ring in [0.25, 0.50, 0.75, 1.0] {
            var path = Path()
            for (i, angle) in angles.enumerated() {
                let r = radius * ring
                let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
            ctx.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)
        }
    }

    private func drawAxes(ctx: GraphicsContext, center: CGPoint, radius: Double, angles: [Double]) {
        for angle in angles {
            var path = Path()
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle),
                                     y: center.y + radius * sin(angle)))
            ctx.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)
        }
    }

    private func drawData(ctx: GraphicsContext, center: CGPoint, radius: Double, angles: [Double]) {
        guard !values.isEmpty else { return }
        var dataPath = Path()
        for (i, angle) in angles.enumerated() {
            let r = radius * (values[i] / 100.0)
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            i == 0 ? dataPath.move(to: pt) : dataPath.addLine(to: pt)
        }
        dataPath.closeSubpath()
        ctx.fill(dataPath, with: .color(color.opacity(0.25)))
        ctx.stroke(dataPath, with: .color(color), lineWidth: 2.5)

        for (i, angle) in angles.enumerated() {
            let r = radius * (values[i] / 100.0)
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            let dot = Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8))
            ctx.fill(dot, with: .color(color))
        }
    }

    private func labelPosition(index: Int, total: Int, center: CGPoint, radius: Double) -> CGPoint {
        let step: Double = 2.0 * Double.pi / Double(total)
        let angle: Double = Double(index) * step - Double.pi / 2.0
        return CGPoint(x: center.x + radius * cos(angle),
                       y: center.y + radius * sin(angle))
    }

    private func axisLabels(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 10
        return ForEach(0..<labels.count, id: \.self) { i in
            Text(self.labels[i])
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .position(self.labelPosition(index: i, total: self.labels.count,
                                             center: center, radius: radius))
        }
    }
}

// MARK: - Snapshot Share Card

private struct ShareDomain: Identifiable {
    let id: String
    let label: String
    let pct: Int
}

struct SnapshotShareCard: View {
    let session: SnapshotSession
    let stats: PlayerStats

    private var domains: [ShareDomain] {
        [
            ShareDomain(id: "speed", label: "Speed", pct: session.speedPercentile),
            ShareDomain(id: "attn",  label: "Attn",  pct: session.attentionPercentile),
            ShareDomain(id: "mem",   label: "Mem",   pct: session.memoryPercentile),
            ShareDomain(id: "flex",  label: "Flex",  pct: session.flexibilityPercentile)
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.85), Color.blue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                shareCardHeader
                Spacer()
                shareCardScore
                Spacer()
                shareCardDomains
                shareCardFooter
            }
        }
        .frame(width: 400, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var shareCardHeader: some View {
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
    }

    private var shareCardScore: some View {
        VStack(spacing: 4) {
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
        }
    }

    private var shareCardDomains: some View {
        HStack(spacing: 0) {
            ForEach(domains) { domain in
                VStack(spacing: 2) {
                    Text("\(domain.pct)th")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(domain.label)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 28)
    }

    private var shareCardFooter: some View {
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
