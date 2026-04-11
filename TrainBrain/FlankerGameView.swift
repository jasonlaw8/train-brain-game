import SwiftUI
import SwiftData

// Fish School — Flanker attention task with fish symbols, swipe gestures, 60-second timer,
// combo scoring, Elo-driven difficulty, and dynamic ocean background.

// MARK: - ViewModel

@MainActor
class FlankerGameViewModel: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var timeRemaining: Double = 60
    @Published var totalScore: Int = 0
    @Published var correctCount: Int = 0
    @Published var wrongCount: Int = 0
    @Published var lastCorrect: Bool? = nil
    @Published var isCongruent: Bool = true      // current trial type
    @Published var fishDirections: [Direction] = []
    @Published var centerDirection: Direction = .right
    @Published var bounceCenter: Bool = false
    @Published var showHint: Bool = true          // shown only on first trial

    private var trialCount: Int = 0

    enum Direction { case left, right }
    enum GameState { case idle, playing, gameOver }

    var accuracy: Double {
        let total = correctCount + wrongCount
        guard total > 0 else { return 1.0 }
        return Double(correctCount) / Double(total)
    }

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }

    var accuracyBonus: Int {
        if accuracy > 0.95 { return 100 }
        if accuracy > 0.90 { return 50 }
        return 0
    }

    var onGameOver: ((Double) -> Void)?

    private var eloParams: EloSystem.FlankerParams = EloSystem.flankerParams(1000)
    private var timerTask: Task<Void, Never>?
    private var responseTask: Task<Void, Never>?

    // MARK: - Start

    func startGame(eloParams: EloSystem.FlankerParams) {
        self.eloParams = eloParams
        totalScore = 0
        correctCount = 0
        wrongCount = 0
        timeRemaining = 60
        lastCorrect = nil
        trialCount = 0
        showHint = true
        gameState = .playing
        startTimerLoop()
        generateTrial()
    }

    // MARK: - Trial generation

    func generateTrial() {
        let isCongruent = Double.random(in: 0..<1) < eloParams.congruentRatio
        self.isCongruent = isCongruent

        let center: Direction = Bool.random() ? .left : .right
        let flanker: Direction = isCongruent ? center : (center == .left ? .right : .left)

        centerDirection = center
        fishDirections = [flanker, flanker, center, flanker, flanker]

        if trialCount > 0 { showHint = false }
        trialCount += 1
    }

    // MARK: - Response (called by swipe gesture)

    func respond(direction: Direction, combo: ComboTracker) {
        guard gameState == .playing else { return }
        responseTask?.cancel()

        // Bounce center fish regardless of correctness
        bounceCenter = false
        Task { @MainActor in
            bounceCenter = true
            try? await Task.sleep(for: .milliseconds(50))
            bounceCenter = false
        }

        if direction == centerDirection {
            // Correct
            correctCount += 1
            lastCorrect = true
            Haptics.medium()
            combo.markCorrect()
            SoundEngine.shared.playCorrect(streak: combo.streak)

            let baseScore = isCongruent ? 10 : 20
            let earned = combo.apply(baseScore)
            totalScore += earned
        } else {
            // Wrong
            wrongCount += 1
            lastCorrect = false
            Haptics.error()
            combo.markWrong()
            SoundEngine.shared.playWrong()
            totalScore = max(0, totalScore - 5)
        }

        responseTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            lastCorrect = nil
            guard gameState == .playing else { return }
            generateTrial()
        }
    }

    // MARK: - Timer loop (async/await, no DispatchQueue)

    private func startTimerLoop() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                timeRemaining -= 0.1
                if timeRemaining <= 0 {
                    timeRemaining = 0
                    endGame()
                    return
                }
            }
        }
    }

    private func endGame() {
        timerTask?.cancel()
        responseTask?.cancel()
        timerTask = nil
        responseTask = nil
        gameState = .gameOver
        onGameOver?(accuracy)
    }
}

// MARK: - View

struct FlankerGameView: View {
    @StateObject private var vm    = FlankerGameViewModel()
    @StateObject private var combo = ComboTracker()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @Query(sort: \GameSession.date, order: .reverse) private var sessions: [GameSession]
    @AppStorage("flankerDifficulty") private var difficulty: Difficulty = .medium
    @State private var showGameOver = false
    @State private var gameResult: GameResult? = nil

    // Bioluminescence particles (streak 10+)
    @State private var bioParticles: [BioParticle] = (0..<5).map { _ in BioParticle() }
    @State private var bioAnimate: Bool = false

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        ZStack {
            // Dynamic ocean background
            oceanBackground
                .ignoresSafeArea()

            // Bioluminescence (streak 10+)
            if combo.streak >= 10 {
                bioluminescenceLayer
            }

            if showGameOver, let result = gameResult {
                GameOverView(result: result) {
                    showGameOver = false
                    gameResult = nil
                    startGame()
                }
                .transition(.opacity)
                .zIndex(20)
            } else {
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGameOver)
        .navigationTitle("Fish School")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupGameOverHandler()
            bioAnimate = true
        }
    }

    // MARK: - Ocean Background

    @ViewBuilder
    var oceanBackground: some View {
        let baseColor = Color(red: 0.7, green: 0.88, blue: 0.98)

        ZStack {
            baseColor

            // Streak 5+: sunset tint overlay
            if combo.streak >= 5 {
                Color(red: 0.98, green: 0.75, blue: 0.50)
                    .opacity(0.3)
                    .transition(.opacity)
            }

            // Streak 10+: deeper ocean
            if combo.streak >= 10 {
                Color(red: 0.1, green: 0.25, blue: 0.55)
                    .opacity(0.55)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: combo.streak >= 5)
        .animation(.easeInOut(duration: 0.8), value: combo.streak >= 10)
    }

    // MARK: - Bioluminescence

    var bioluminescenceLayer: some View {
        GeometryReader { geo in
            ForEach(bioParticles) { p in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 3, height: 3)
                    .offset(
                        x: p.x * geo.size.width,
                        y: bioAnimate ? p.yEnd * geo.size.height : p.yStart * geo.size.height
                    )
                    .animation(
                        .easeInOut(duration: p.duration)
                        .repeatForever(autoreverses: true)
                        .delay(p.delay),
                        value: bioAnimate
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Main Content

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:    idleView
        case .playing: playView
        case .gameOver: Color.clear  // handled by GameOverView overlay
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text("Fish School")
                    .font(.largeTitle.bold())

                Text("Swipe LEFT or RIGHT based on the\nCENTER fish — ignore the others.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Example fish preview
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        FishSymbol(
                            direction: i == 2 ? .right : .left,
                            isCenter: i == 2
                        )
                    }
                }
                .padding(.vertical, 4)

                if stats.flankerBestAccuracy > 0 {
                    Label("Best: \(stats.flankerBestAccuracy)% accuracy", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }

                EloBadge(rating: stats.flankerEloRating, color: .teal)
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button { startGame() } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play View

    var playView: some View {
        VStack(spacing: 20) {
            // Top bar: score + accuracy + combo badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    AnimatedScoreText(value: vm.totalScore, font: .title2.bold(), color: .teal)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Accuracy").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text("\(vm.accuracyPercent)%")
                        .font(.title2.bold())
                        .foregroundStyle(.cyan)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text("\(stats.flankerBestAccuracy)%")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .overlay(alignment: .topTrailing) {
                MultiplierBadgeView(combo: combo, color: .teal)
                    .offset(y: -8)
            }

            // Timer bar
            timerBar

            Spacer()

            // Fish row — swipe gesture applied here
            fishRow
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            let h = value.translation.width
                            let v = value.translation.height
                            if abs(h) > abs(v) {
                                vm.respond(direction: h > 0 ? .right : .left, combo: combo)
                            }
                        }
                )

            // Feedback
            feedbackIcon

            // Hint (first trial only)
            if vm.showHint {
                Text("← Swipe →")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else {
                Color.clear.frame(height: 20)
            }

            Spacer()
        }
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.15), value: vm.lastCorrect)
        .animation(.easeInOut(duration: 0.3), value: vm.showHint)
    }

    // MARK: - Fish Row

    var fishRow: some View {
        HStack(spacing: 6) {
            ForEach(vm.fishDirections.indices, id: \.self) { i in
                let isCenter = (i == 2)
                FishSymbol(direction: vm.fishDirections[i], isCenter: isCenter)
                    .juiceBounce(trigger: isCenter ? vm.bounceCenter : false)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(nil, value: vm.fishDirections.map { $0 == .left })
    }

    // MARK: - Feedback Icon

    @ViewBuilder
    var feedbackIcon: some View {
        if let correct = vm.lastCorrect {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(correct ? .green : .red)
                .transition(.scale.combined(with: .opacity))
        } else {
            Color.clear.frame(height: 32)
        }
    }

    // MARK: - Timer Bar

    var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.3))
                Capsule()
                    .fill(timerBarColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining / 60))
                    .animation(.linear(duration: 0.1), value: vm.timeRemaining)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
        .overlay(alignment: .trailing) {
            Text(String(format: "%.0fs", vm.timeRemaining))
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(timerBarColor)
                .padding(.trailing, 20)
        }
    }

    var timerBarColor: Color {
        if vm.timeRemaining > 20 { return .green }
        if vm.timeRemaining > 10 { return .orange }
        return .red
    }

    // MARK: - Setup & Game Start

    private func setupGameOverHandler() {
        vm.onGameOver = { accuracy in
            let bonus = vm.accuracyBonus
            let finalScore = vm.totalScore + bonus
            let isNewBest = vm.accuracyPercent > stats.flankerBestAccuracy && (vm.correctCount + vm.wrongCount) > 0
            let brainScore = PlayerStats.flankerBrainScore(accuracy: vm.accuracyPercent)

            let session = GameSession(
                gameType: "flanker",
                rawScore: vm.correctCount,
                brainScore: brainScore,
                difficulty: difficulty.rawValue
            )
            modelContext.insert(session)
            stats.recordFlankerGame(accuracy: vm.accuracyPercent)

            // Update Elo
            stats.flankerEloRating = EloSystem.updated(stats.flankerEloRating, correct: accuracy > 0.75)

            let result = GameResult(
                gameTitle: "Fish School",
                primaryScore: finalScore,
                primaryLabel: "pts",
                brainScore: brainScore,
                previousBrainScore: stats.flankerBrainScore,
                isNewBest: isNewBest,
                multiplierBreakdown: nil,
                percentileText: PlayerStats.percentileLabel(for: brainScore),
                accentColor: .teal,
                share: .init(
                    gameName: "Fish School",
                    icon: "water.waves",
                    color: .teal,
                    primaryValue: "\(finalScore)",
                    primaryLabel: "pts",
                    secondaryLine: "Accuracy \(vm.accuracyPercent)%"
                )
            )
            gameResult = result
            withAnimation { showGameOver = true }
        }
    }

    private func startGame() {
        let params = EloSystem.flankerParams(stats.flankerEloRating)
        combo.reset()
        vm.startGame(eloParams: params)
    }
}

// MARK: - Fish Symbol

private struct FishSymbol: View {
    let direction: FlankerGameViewModel.Direction
    let isCenter: Bool

    var body: some View {
        Image(systemName: "fish.fill")
            .font(.system(size: isCenter ? 46 : 30))
            .foregroundStyle(Color.teal.opacity(isCenter ? 1.0 : 0.55))
            .scaleEffect(x: direction == .right ? 1 : -1, y: 1)
            .brightness(isCenter ? 0.15 : 0)
    }
}

// MARK: - Bioluminescence Particle Model

private struct BioParticle: Identifiable {
    let id = UUID()
    let x: CGFloat     = CGFloat.random(in: 0.05...0.95)
    let yStart: CGFloat = CGFloat.random(in: 0.1...0.5)
    let yEnd: CGFloat   = CGFloat.random(in: 0.5...0.95)
    let duration: Double = Double.random(in: 3.0...6.0)
    let delay: Double    = Double.random(in: 0.0...3.0)
}

// MARK: - Preview

#Preview {
    NavigationStack { FlankerGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
