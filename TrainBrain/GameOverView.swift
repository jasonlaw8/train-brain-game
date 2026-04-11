import SwiftUI

// MARK: - GameResult

/// All data needed to render the unified game-over screen.
struct GameResult {
    let gameTitle: String
    let primaryScore: Int
    let primaryLabel: String            // "pts", "ms", "%", etc.
    let brainScore: Int                 // 70–145
    let previousBrainScore: Int         // 0 = no prior session
    let isNewBest: Bool
    let multiplierBreakdown: MultiplierBreakdown?
    let percentileText: String          // e.g. "Better than 67% of players"
    let accentColor: Color
    let share: ShareConfig

    struct MultiplierBreakdown {
        let baseScore: Int
        let bestMultiplier: Double
        let finalScore: Int
    }

    struct ShareConfig {
        let gameName: String
        let icon: String
        let color: Color
        let primaryValue: String
        let primaryLabel: String
        let secondaryLine: String?
    }
}

// MARK: - GameOverView

/// Unified full-screen game-over presentation.
/// Present this as the game's "game over" state replacement — via fullScreenCover or
/// as a conditional overlay in the game view hierarchy.
struct GameOverView: View {
    let result: GameResult
    let onRetry: () -> Void

    @State private var displayedScore: Int = 0
    @State private var showBadge  = false
    @State private var showParticles = false
    @State private var showBrainCard = false
    @State private var showButtons  = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Game title ─────────────────────────────────────────
                Text(result.gameTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 48)

                Spacer()

                // ── NEW BEST badge ──────────────────────────────────────
                if result.isNewBest && showBadge {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text("NEW BEST!")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.yellow.gradient, in: Capsule())
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .padding(.bottom, 12)
                }

                // ── Primary score ───────────────────────────────────────
                ZStack {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(displayedScore)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: Double(displayedScore)))
                            .animation(.linear(duration: 0.02), value: displayedScore)
                        Text(result.primaryLabel)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }

                    if showParticles && result.isNewBest {
                        ParticleBurst(color: .yellow, count: 32)
                            .offset(x: 60, y: -30)
                    }
                }

                // ── Multiplier breakdown ────────────────────────────────
                if let mb = result.multiplierBreakdown, mb.bestMultiplier > 1.0 {
                    Text("Base \(mb.baseScore)  ×  Best streak ×\(String(format: "%.4g", mb.bestMultiplier))  =  \(mb.finalScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                // ── Percentile ──────────────────────────────────────────
                Text(result.percentileText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)

                // ── Brain Score card ────────────────────────────────────
                if showBrainCard {
                    brainScoreCard
                        .padding(.top, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                // ── Action buttons ──────────────────────────────────────
                if showButtons {
                    buttonsSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Sub-views

    private var brainScoreCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Brain Score")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(result.brainScore)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(result.accentColor)
            }
            Spacer()
            if result.previousBrainScore > 0 {
                let delta = result.brainScore - result.previousBrainScore
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                    Text("\(abs(delta))")
                }
                .font(.subheadline.bold())
                .foregroundStyle(delta >= 0 ? .green : .orange)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button(action: onRetry) {
                Text("Play Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(result.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            ShareResultButton(
                gameName:      result.share.gameName,
                gameIcon:      result.share.icon,
                gameColor:     result.share.color,
                primaryValue:  result.share.primaryValue,
                primaryLabel:  result.share.primaryLabel,
                secondaryLine: result.share.secondaryLine
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        // Score counter: 0 → result over ~800ms
        let target = result.primaryScore
        let steps  = 28
        let stepMs = 800.0 / Double(steps)
        for i in 1...steps {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(stepMs * Double(i))))
                displayedScore = Int(Double(target) * Double(i) / Double(steps))
                if i == steps { displayedScore = target }
            }
        }

        if result.isNewBest {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(850))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { showBadge = true }
                showParticles = true
                SoundEngine.shared.playNewBest()
                Haptics.success()
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.30)) { showBrainCard = true }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.30)) { showButtons = true }
        }
    }
}
