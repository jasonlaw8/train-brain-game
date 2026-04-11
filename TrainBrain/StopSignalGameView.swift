import SwiftUI
import SwiftData

// Bug Catcher: Tap the butterfly on GO trials. Don't tap when the ladybug warning appears.
// 30 total trials, ~25% STOP rate (7–8 STOP trials), 1200 ms response window.

// MARK: - ViewModel

@MainActor
class StopSignalViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }
    enum TrialPhase { case blank, go, stop, feedback }

    @Published var gameState: GameState = .idle
    @Published var trialPhase: TrialPhase = .blank
    @Published var showStopSignal: Bool = false
    @Published var trialsCompleted: Int = 0
    @Published var correctCount: Int = 0
    @Published var totalTrials: Int = 30
    @Published var finalAccuracy: Int = 0
    @Published var finalBrainScore: Int = 0

    // Feedback state
    @Published var feedbackKind: FeedbackKind? = nil
    // Juice triggers (toggled to fire modifiers)
    @Published var bounceGO: Bool = false
    @Published var dimStop: Bool = false

    enum FeedbackKind {
        case correctGO        // green check
        case missedGO         // orange x
        case correctStop      // shield + "+15 Control"
        case falseAlarm       // red x
    }

    var onGameOver: ((Int) -> Void)?  // passes accuracy %

    private var difficulty: Difficulty = .medium
    private var eloStopDelay: Double = 0.225  // seconds
    private var currentIsStop: Bool = false
    private var playerTapped: Bool = false
    private var trialTask: Task<Void, Never>?

    func startGame(difficulty: Difficulty, stopDelay: Double) {
        self.difficulty = difficulty
        self.eloStopDelay = stopDelay
        trialsCompleted = 0
        correctCount = 0
        feedbackKind = nil
        gameState = .playing
        runNextTrial()
    }

    func playerTap() {
        guard gameState == .playing,
              trialPhase == .go || trialPhase == .stop else { return }
        playerTapped = true
    }

    private func runNextTrial() {
        trialTask?.cancel()
        trialTask = Task {
            // Blank interval
            trialPhase = .blank
            showStopSignal = false
            feedbackKind = nil
            playerTapped = false
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            // 25% chance of STOP trial
            currentIsStop = Int.random(in: 0..<4) == 0
            trialPhase = .go
            let startTime = Date()

            // For stop trials: show ladybug stop signal after delay
            if currentIsStop {
                try? await Task.sleep(for: .seconds(eloStopDelay))
                guard !Task.isCancelled else { return }
                if !playerTapped {
                    showStopSignal = true
                    trialPhase = .stop
                    Haptics.light()
                }
            }

            // Wait for remainder of 1200 ms response window
            let elapsed = Int(-startTime.timeIntervalSinceNow * 1000)
            let remaining = max(0, 1200 - elapsed)
            try? await Task.sleep(for: .milliseconds(remaining))
            guard !Task.isCancelled else { return }

            evaluateTrial()

            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            trialsCompleted += 1
            if trialsCompleted >= totalTrials {
                endGame()
            } else {
                runNextTrial()
            }
        }
    }

    private func evaluateTrial() {
        trialPhase = .feedback
        showStopSignal = false

        if currentIsStop {
            if playerTapped {
                // False alarm — tapped on stop
                feedbackKind = .falseAlarm
                dimStop = !dimStop
                SoundEngine.shared.playWrong()
                Haptics.error()
            } else {
                // Correct inhibition
                feedbackKind = .correctStop
                correctCount += 1
                SoundEngine.shared.playSuccess()
                Haptics.light()
            }
        } else {
            if playerTapped {
                // Correct GO tap
                feedbackKind = .correctGO
                correctCount += 1
                bounceGO = !bounceGO
                SoundEngine.shared.playCorrect()
                Haptics.medium()
            } else {
                // Miss — didn't tap on GO trial
                feedbackKind = .missedGO
                SoundEngine.shared.playWrong()
                Haptics.error()
            }
        }
    }

    private func endGame() {
        trialTask?.cancel()
        trialPhase = .blank
        feedbackKind = nil
        let accuracy = Int(Double(correctCount) / Double(totalTrials) * 100)
        finalAccuracy = accuracy
        finalBrainScore = PlayerStats.stopSignalBrainScore(accuracy: accuracy)
        onGameOver?(accuracy)
        gameState = .gameOver
    }
}

// MARK: - View

struct StopSignalGameView: View {
    @StateObject private var vm = StopSignalViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("stopSignalDifficulty") private var difficulty: Difficulty = .medium

    // Float animation for the GO butterfly target
    @State private var floatOffset: CGFloat = 0

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private var eloParams: EloSystem.StopSignalParams {
        EloSystem.stopSignalParams(stats.stopSignalEloRating)
    }

    var body: some View {
        ZStack {
            mainContent
        }
        .navigationTitle("Bug Catcher")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startFloatAnimation()
            vm.onGameOver = { accuracy in
                let isNewBest = accuracy > stats.stopSignalBestAccuracy
                let brainScore = PlayerStats.stopSignalBrainScore(accuracy: accuracy)
                let session = GameSession(
                    gameType: "stopsignal",
                    rawScore: accuracy,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordStopSignalGame(accuracy: accuracy)
                // Elo update
                stats.stopSignalEloRating = EloSystem.updated(
                    stats.stopSignalEloRating,
                    correct: Double(accuracy) / 100.0 > 0.80
                )
                if isNewBest && accuracy > 0 {
                    Haptics.success()
                }
            }
        }
    }

    private func startFloatAnimation() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = 4
        }
    }

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:     idleView
        case .playing:  playView
        case .gameOver: gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red)
                }

                Text("Bug Catcher")
                    .font(.largeTitle.bold())

                Text("Tap the butterfly when it appears.\nBut if a ladybug shows — DON'T tap!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if stats.stopSignalBestAccuracy > 0 {
                    Label("Best: \(stats.stopSignalBestAccuracy)% control", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }

                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                    Text("Auto difficulty")
                        .font(.caption.bold())
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.green.opacity(0.12), in: Capsule())
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button {
                vm.startGame(difficulty: difficulty, stopDelay: eloParams.stopDelay)
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 20) {
            HStack {
                StatBadge(label: "Trial", value: "\(vm.trialsCompleted + 1)/\(vm.totalTrials)", color: .green)
                Spacer()
                StatBadge(label: "Correct", value: "\(vm.correctCount)", color: .teal)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.stopSignalBestAccuracy)%", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(vm.trialsCompleted) / CGFloat(vm.totalTrials))
                        .animation(.linear(duration: 0.3), value: vm.trialsCompleted)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            Spacer()

            ZStack {
                // GO / STOP target area
                if vm.trialPhase == .go || vm.trialPhase == .stop {
                    Button {
                        vm.playerTap()
                    } label: {
                        goTargetView
                            .offset(y: floatOffset)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .juiceBounce(trigger: vm.bounceGO)
                    .juiceDim(trigger: vm.dimStop)
                }

                // Feedback overlay
                feedbackOverlay
            }
            .animation(.easeInOut(duration: 0.18), value: vm.trialPhase)
            .frame(height: 220)

            Text(instructionText)
                .font(.headline)
                .foregroundStyle(instructionColor)
                .animation(nil, value: vm.trialPhase)

            Spacer()
        }
    }

    // Butterfly (GO) target with optional ladybug (STOP) overlay
    var goTargetView: some View {
        ZStack {
            // Background garden circle
            Circle()
                .fill(
                    vm.showStopSignal
                        ? Color.red.opacity(0.15)
                        : Color.green.opacity(0.15)
                )
                .frame(width: 140, height: 140)

            // Butterfly (always visible during GO/STOP phase)
            Image(systemName: "figure.walk")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .rotationEffect(.degrees(-15))

            // Ladybug stop overlay
            if vm.showStopSignal {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: vm.showStopSignal)
    }

    // Feedback shown after a trial resolves
    @ViewBuilder
    var feedbackOverlay: some View {
        if vm.trialPhase == .feedback {
            switch vm.feedbackKind {
            case .correctGO:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))

            case .missedGO:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))

            case .correctStop:
                VStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("+15 Control")
                        .font(.headline.bold())
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))

            case .falseAlarm:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))

            case nil:
                EmptyView()
            }
        }
    }

    var instructionText: String {
        switch vm.trialPhase {
        case .blank:    return "Get ready..."
        case .go:       return "TAP!"
        case .stop:     return "STOP!"
        case .feedback: return ""
        }
    }

    var instructionColor: Color {
        switch vm.trialPhase {
        case .stop: return .red
        case .go:   return .green
        default:    return .secondary
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        let brainScore = PlayerStats.stopSignalBrainScore(accuracy: vm.finalAccuracy)
        let result = GameResult(
            gameTitle: "Bug Catcher",
            primaryScore: vm.finalAccuracy,
            primaryLabel: "% control",
            brainScore: brainScore,
            previousBrainScore: stats.stopSignalBrainScore,
            isNewBest: vm.finalAccuracy > 0 && vm.finalAccuracy >= stats.stopSignalBestAccuracy,
            multiplierBreakdown: nil,
            percentileText: PlayerStats.percentileLabel(for: brainScore),
            accentColor: .green,
            share: GameResult.ShareConfig(
                gameName: "Bug Catcher",
                icon: "ant.fill",
                color: .green,
                primaryValue: "\(vm.finalAccuracy)",
                primaryLabel: "% control",
                secondaryLine: "Impulse Control Score"
            )
        )
        return GameOverView(result: result) {
            vm.startGame(difficulty: difficulty, stopDelay: eloParams.stopDelay)
        }
    }
}

#Preview {
    NavigationStack { StopSignalGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
