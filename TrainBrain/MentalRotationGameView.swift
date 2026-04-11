import SwiftUI
import SwiftData

// MARK: - Block Builder (was Shape Flip / Mental Rotation)
// 3D isometric block shapes. Same or Mirror — plus confidence slider.

// MARK: - Shapes

struct RotationShape {
    let cells: [(row: Int, col: Int)]
}

let baseShapes: [RotationShape] = [
    // L shape
    RotationShape(cells: [(0,0),(1,0),(2,0),(2,1)]),
    // S shape
    RotationShape(cells: [(0,1),(0,2),(1,0),(1,1)]),
    // T+arm (asymmetric pentomino)
    RotationShape(cells: [(0,0),(0,1),(0,2),(1,1),(2,1)]),
    // J shape
    RotationShape(cells: [(0,1),(1,1),(2,1),(2,0)]),
    // F pentomino
    RotationShape(cells: [(0,1),(0,2),(1,0),(1,1),(2,1)]),
    // Z shape
    RotationShape(cells: [(0,0),(0,1),(1,1),(1,2)]),
]

private func rotateCells(_ cells: [(row: Int, col: Int)], turns: Int) -> [(row: Int, col: Int)] {
    var result = cells
    for _ in 0..<(turns % 4) {
        result = result.map { (row: $0.col, col: 3 - $0.row) }
    }
    return result
}

private func mirrorCells(_ cells: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
    cells.map { (row: $0.row, col: 3 - $0.col) }
}

// MARK: - ViewModel

@MainActor
class MentalRotationViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }
    enum TrialResult { case pending, correct, wrong, timedOut }
    enum AnswerPhase { case answering, confidence, feedback }

    struct Trial {
        let leftCells:  [(row: Int, col: Int)]
        let rightCells: [(row: Int, col: Int)]
        let isSame: Bool
        let rotationTurns: Int    // for 3D tilt on right shape
    }

    @Published var gameState: GameState = .idle
    @Published var currentTrial: Trial? = nil
    @Published var trialIndex: Int = 0
    @Published var score: Int = 0
    @Published var lastResult: TrialResult = .pending
    @Published var timeRemaining: Double = 6.0
    @Published var currentTimeLimit: Double = 6.0
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0

    // Confidence
    @Published var answerPhase: AnswerPhase = .answering
    @Published var confidence: Double = 0.75
    @Published var lastWasCorrect: Bool = false
    @Published var lastBounce: Bool = false

    // 3D turntable angle (animates in view)
    @Published var turntableAngle: Double = 0

    // Elo params
    @Published var use3D: Bool = false

    let totalTrials = 20
    var onGameOver: ((Int) -> Void)?

    private var difficulty: Difficulty = .medium
    private var timerTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var confidenceTask: Task<Void, Never>?
    private var eloTimeLimit: Double = 6.0

    // MARK: - Start

    func startGame(difficulty: Difficulty, rotationElo: Double) {
        self.difficulty = difficulty
        let params = EloSystem.rotationParams(rotationElo)
        use3D = params.use3D
        eloTimeLimit = params.timeLimit
        trialIndex = 0
        score = 0
        lastResult = .pending
        answerPhase = .answering
        confidence = 0.75
        currentTimeLimit = eloTimeLimit
        turntableAngle = 0
        gameState = .playing
        nextTrial()
    }

    func answer(_ same: Bool) {
        guard gameState == .playing, let trial = currentTrial, lastResult == .pending else { return }
        timerTask?.cancel()
        lastWasCorrect = (same == trial.isSame)
        if lastWasCorrect {
            lastResult = .correct
            Haptics.success()
            lastBounce.toggle()
        } else {
            lastResult = .wrong
            Haptics.error()
        }
        // Show confidence slider
        answerPhase = .confidence
        confidence = 0.75
        startConfidenceCountdown()
    }

    func submitConfidence() {
        confidenceTask?.cancel()
        applyConfidenceScoring()
    }

    // MARK: - Private

    private func startConfidenceCountdown() {
        confidenceTask?.cancel()
        confidenceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            applyConfidenceScoring()
        }
    }

    private func applyConfidenceScoring() {
        let conf = confidence
        let wasCorrect = lastWasCorrect

        var points = 10
        if wasCorrect {
            if conf > 0.80 { points = Int((Double(points) * 1.5).rounded()) }
            else if conf < 0.60 { points = Int((Double(points) * 0.8).rounded()) }
            score += points
        } else {
            if conf > 0.80 { score = max(0, score - 5) }
        }

        answerPhase = .feedback
        advanceAfterFeedback()
    }

    private func nextTrial() {
        timerTask?.cancel()
        feedbackTask?.cancel()
        lastResult = .pending
        answerPhase = .answering
        confidence = 0.75
        lastBounce = false
        currentTrial = generateTrial()
        currentTimeLimit = eloTimeLimit
        timeRemaining = eloTimeLimit
        startCountdown()
    }

    private func generateTrial() -> Trial {
        let base  = baseShapes.randomElement()!
        let turns = Int.random(in: 0...3)
        let isSame = Bool.random()

        let rightCells: [(row: Int, col: Int)]
        if isSame {
            rightCells = rotateCells(base.cells, turns: turns)
        } else {
            rightCells = rotateCells(mirrorCells(base.cells), turns: turns)
        }
        return Trial(leftCells: base.cells, rightCells: rightCells, isSame: isSame, rotationTurns: turns)
    }

    private func startCountdown() {
        timerTask = Task {
            let interval = 0.05
            var elapsed  = 0.0
            let limit    = currentTimeLimit
            while elapsed < limit {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                elapsed += interval
                timeRemaining = max(0, limit - elapsed)
            }
            guard !Task.isCancelled else { return }
            lastResult = .timedOut
            lastWasCorrect = false
            Haptics.error()
            answerPhase = .feedback
            advanceAfterFeedback()
        }
    }

    private func advanceAfterFeedback() {
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            trialIndex += 1
            if trialIndex >= totalTrials {
                endGame()
            } else {
                nextTrial()
            }
        }
    }

    private func endGame() {
        timerTask?.cancel()
        feedbackTask?.cancel()
        finalScore = score
        finalBrainScore = max(70, min(145, 40 + score * 3))
        onGameOver?(score)
        gameState = .gameOver
    }
}

// MARK: - 3D Block Shape Grid

struct BlockShapeGridView: View {
    let cells: [(row: Int, col: Int)]
    let color: Color
    let size: CGFloat
    var rotationDegrees: Double = 0   // static Y-axis angle for right shape
    var turntableAngle: Double = 0    // animating angle for left shape

    var body: some View {
        let cellSet = Set(cells.map { "\($0.row),\($0.col)" })
        VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { col in
                        let filled = cellSet.contains("\(row),\(col)")
                        RoundedRectangle(cornerRadius: 3)
                            .fill(filled ? color : Color(.systemGray5))
                            .frame(width: size, height: size)
                            .shadow(
                                color: filled ? Color.black.opacity(0.3) : .clear,
                                radius: 4, x: 4, y: 4
                            )
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 6, x: 2, y: 4)
    }
}

// MARK: - View

struct MentalRotationGameView: View {
    @StateObject private var vm = MentalRotationViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("mentalRotationDifficulty") private var difficulty: Difficulty = .medium

    @State private var turntableAngle: Double = 0

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats(); modelContext.insert(s); return s
    }

    var body: some View {
        ZStack {
            mainContent
        }
        .navigationTitle("Block Builder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correct in
                let brainScore = max(70, min(145, 40 + correct * 3))
                let session = GameSession(
                    gameType: "mentalrotation",
                    rawScore: vm.finalScore,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordMentalRotationGame(correct: correct)
                stats.rotationEloRating = EloSystem.updated(stats.rotationEloRating, correct: correct >= 14)
            }
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
                Image(systemName: "cube.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.yellow)
                Text("Block Builder")
                    .font(.largeTitle.bold())
                Text("Are the two block shapes the same\n(rotated) or a mirror image?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.mentalRotationBestScore > 0 {
                    Label("Best: \(stats.mentalRotationBestScore)/20 correct", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button {
                vm.startGame(difficulty: difficulty, rotationElo: stats.rotationEloRating)
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.yellow, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 16) {
            // Top stats bar
            HStack {
                StatBadge(label: "Trial", value: "\(vm.trialIndex + 1)/\(vm.totalTrials)", color: .yellow)
                Spacer()
                StatBadge(label: "Score", value: "\(vm.score)", color: .green)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            timerBar

            Spacer()

            // Shape display
            if let trial = vm.currentTrial {
                HStack(spacing: 24) {
                    // Left: turntable rotation
                    VStack(spacing: 8) {
                        Text("Reference")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        BlockShapeGridView(
                            cells: trial.leftCells,
                            color: .yellow,
                            size: vm.use3D ? 36 : 40,
                            turntableAngle: turntableAngle
                        )
                        .rotation3DEffect(
                            Angle(degrees: turntableAngle),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.6
                        )
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .onAppear {
                        withAnimation(
                            .linear(duration: 8)
                            .repeatForever(autoreverses: false)
                        ) {
                            turntableAngle = 360
                        }
                    }

                    // Right: static rotation + slight secondary tilt
                    VStack(spacing: 8) {
                        Text("Compare")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        BlockShapeGridView(
                            cells: trial.rightCells,
                            color: .yellow,
                            size: vm.use3D ? 36 : 40
                        )
                        .rotation3DEffect(
                            Angle(degrees: Double(trial.rotationTurns) * 90),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .rotation3DEffect(
                            vm.use3D ? Angle(degrees: 12) : .zero,
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.4
                        )
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .juiceBounce(trigger: vm.lastBounce)
                }
                .padding(.horizontal)

                // Feedback (correct/wrong)
                if vm.lastResult != .pending && vm.answerPhase == .feedback {
                    feedbackView
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer()

            // Confidence slider or answer buttons
            if vm.answerPhase == .confidence {
                confidenceSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal)
            } else {
                answerButtons
                    .disabled(vm.lastResult != .pending || vm.answerPhase != .answering)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.answerPhase)
        .animation(.easeInOut(duration: 0.15), value: vm.lastResult)
    }

    // MARK: - Confidence Slider

    var confidenceSection: some View {
        VStack(spacing: 10) {
            Text("How sure are you?")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            HStack {
                Text("50%").font(.caption).foregroundStyle(.secondary)
                Slider(value: $vm.confidence, in: 0.5...1.0)
                    .tint(.yellow)
                Text("100%").font(.caption).foregroundStyle(.secondary)
            }
            Text(String(format: "%.0f%%", vm.confidence * 100))
                .font(.title3.bold())
                .foregroundStyle(.yellow)
            Button(action: vm.submitConfidence) {
                Text("Confirm")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color.yellow, in: Capsule())
            }
            .padding(.bottom, 16)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Answer Buttons

    var answerButtons: some View {
        HStack(spacing: 16) {
            Button { vm.answer(true) } label: {
                VStack(spacing: 4) {
                    Text("Same")
                        .font(.title3.bold())
                    Text("Rotated")
                        .font(.caption)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)

            Button { vm.answer(false) } label: {
                VStack(spacing: 4) {
                    Text("Mirror")
                        .font(.title3.bold())
                    Text("Flipped")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    // MARK: - Feedback

    @ViewBuilder
    var feedbackView: some View {
        switch vm.lastResult {
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
        case .wrong, .timedOut:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
        case .pending:
            EmptyView()
        }
    }

    // MARK: - Timer Bar

    var timerBar: some View {
        let fraction = vm.currentTimeLimit > 0 ? vm.timeRemaining / vm.currentTimeLimit : 1.0
        let color: Color = fraction > 0.5 ? .yellow : (fraction > 0.25 ? .orange : .red)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(fraction))
                    .animation(.linear(duration: 0.05), value: vm.timeRemaining)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
    }

    // MARK: - Game Over

    var gameOverView: some View {
        let brainScore = vm.finalBrainScore
        let result = GameResult(
            gameTitle: "Block Builder",
            primaryScore: vm.finalScore,
            primaryLabel: "pts",
            brainScore: brainScore,
            previousBrainScore: stats.mentalRotationBrainScore,
            isNewBest: vm.finalScore > 0 && vm.finalScore >= stats.mentalRotationBestScore,
            multiplierBreakdown: nil,
            percentileText: PlayerStats.percentileLabel(for: brainScore),
            accentColor: .yellow,
            share: GameResult.ShareConfig(
                gameName: "Block Builder",
                icon: "cube.fill",
                color: .yellow,
                primaryValue: "\(vm.finalScore)",
                primaryLabel: "pts",
                secondaryLine: "\(vm.trialIndex) trials · Brain Score \(brainScore)"
            )
        )

        return GameOverView(result: result) {
            vm.startGame(difficulty: difficulty, rotationElo: stats.rotationEloRating)
        }
    }
}

#Preview {
    NavigationStack { MentalRotationGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
