import SwiftUI
import SwiftData

// Mental Rotation (Shape Flip): Two 4×4 shapes side by side. Tap "Same" or "Mirror".
// The right shape is either rotated or mirrored+rotated.

// MARK: - Shapes and Rotation Logic

struct RotationShape {
    let cells: [(row: Int, col: Int)]  // cells on a 4×4 grid
}

// 6 distinct asymmetric shapes (similar to tetrominoes/pentominoes)
let baseShapes: [RotationShape] = [
    // L shape
    RotationShape(cells: [(row: 0, col: 0), (row: 1, col: 0), (row: 2, col: 0), (row: 2, col: 1)]),
    // S shape
    RotationShape(cells: [(row: 0, col: 1), (row: 0, col: 2), (row: 1, col: 0), (row: 1, col: 1)]),
    // T+arm (asymmetric pentomino)
    RotationShape(cells: [(row: 0, col: 0), (row: 0, col: 1), (row: 0, col: 2), (row: 1, col: 1), (row: 2, col: 1)]),
    // J shape
    RotationShape(cells: [(row: 0, col: 1), (row: 1, col: 1), (row: 2, col: 1), (row: 2, col: 0)]),
    // F pentomino
    RotationShape(cells: [(row: 0, col: 1), (row: 0, col: 2), (row: 1, col: 0), (row: 1, col: 1), (row: 2, col: 1)]),
    // Z shape
    RotationShape(cells: [(row: 0, col: 0), (row: 0, col: 1), (row: 1, col: 1), (row: 1, col: 2)]),
]

private func rotateCells(_ cells: [(row: Int, col: Int)], turns: Int) -> [(row: Int, col: Int)] {
    var result = cells
    for _ in 0..<(turns % 4) {
        // 90° clockwise on 4×4: (r,c) -> (c, 3-r)
        result = result.map { (row: $0.col, col: 3 - $0.row) }
    }
    return result
}

private func mirrorCells(_ cells: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
    // Mirror horizontally: (r,c) -> (r, 3-c)
    return cells.map { (row: $0.row, col: 3 - $0.col) }
}

// MARK: - ViewModel

@MainActor
class MentalRotationViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }
    enum TrialResult { case pending, correct, wrong, timedOut }

    struct Trial {
        let leftCells: [(row: Int, col: Int)]
        let rightCells: [(row: Int, col: Int)]
        let isSame: Bool     // true = same shape rotated; false = mirrored
    }

    @Published var gameState: GameState = .idle
    @Published var currentTrial: Trial? = nil
    @Published var trialIndex: Int = 0
    @Published var score: Int = 0
    @Published var lastResult: TrialResult = .pending
    @Published var timeRemaining: Double = 4.0
    @Published var currentTimeLimit: Double = 4.0
    @Published var showNewBest = false
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0

    let totalTrials = 20
    var onGameOver: ((Int) -> Void)?

    private var difficulty: Difficulty = .medium
    private var timerTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    private var timeLimit: Double {
        switch difficulty {
        case .easy:   return 5.0
        case .medium: return 4.0
        case .hard:   return 3.0
        }
    }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        trialIndex = 0
        score = 0
        lastResult = .pending
        currentTimeLimit = timeLimit
        gameState = .playing
        nextTrial()
    }

    func answer(_ same: Bool) {
        guard gameState == .playing, let trial = currentTrial, lastResult == .pending else { return }
        timerTask?.cancel()
        if same == trial.isSame {
            score += 1
            lastResult = .correct
            Haptics.success()
        } else {
            lastResult = .wrong
            Haptics.error()
        }
        advanceAfterFeedback()
    }

    private func nextTrial() {
        timerTask?.cancel()
        feedbackTask?.cancel()
        lastResult = .pending
        currentTrial = generateTrial()
        currentTimeLimit = timeLimit
        timeRemaining = timeLimit
        startCountdown()
    }

    private func generateTrial() -> Trial {
        let base = baseShapes.randomElement()!
        let turns = Int.random(in: 0...3)
        let isSame = Bool.random()

        let leftCells = base.cells
        let rightCells: [(row: Int, col: Int)]
        if isSame {
            rightCells = rotateCells(base.cells, turns: turns)
        } else {
            let mirrored = mirrorCells(base.cells)
            rightCells = rotateCells(mirrored, turns: turns)
        }
        return Trial(leftCells: leftCells, rightCells: rightCells, isSame: isSame)
    }

    private func startCountdown() {
        timerTask = Task {
            let interval = 0.05
            var elapsed = 0.0
            let limit = currentTimeLimit
            while elapsed < limit {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                elapsed += interval
                timeRemaining = max(0, limit - elapsed)
            }
            guard !Task.isCancelled else { return }
            // Timed out
            lastResult = .timedOut
            Haptics.error()
            advanceAfterFeedback()
        }
    }

    private func advanceAfterFeedback() {
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
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
        finalBrainScore = max(70, min(145, 40 + score * 5))
        onGameOver?(score)
        gameState = .gameOver
    }
}

// MARK: - Shape Grid View

struct ShapeGridView: View {
    let cells: [(row: Int, col: Int)]
    let color: Color
    let size: CGFloat

    var body: some View {
        let cellSet = Set(cells.map { "\($0.row),\($0.col)" })
        VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellSet.contains("\(row),\(col)") ? color : Color(.systemGray5))
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}

// MARK: - View

struct MentalRotationGameView: View {
    @StateObject private var vm = MentalRotationViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("mentalRotationDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        ZStack {
            mainContent

            if vm.showNewBest {
                NewBestBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
            if let level = vm.leveledUpTo {
                LevelUpBanner(level: level)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(11)
            }
            if let achievement = vm.unlockedAchievement {
                AchievementUnlockedBanner(achievement: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(12)
            }
        }
        .animation(.spring(response: 0.4), value: vm.showNewBest)
        .animation(.spring(response: 0.4), value: vm.leveledUpTo)
        .animation(.spring(response: 0.4), value: vm.unlockedAchievement?.id)
        .navigationTitle("Shape Flip")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correct in
                let isNewBest = correct > stats.mentalRotationBestScore
                let session = GameSession(
                    gameType: "mentalrotation",
                    rawScore: correct,
                    brainScore: max(70, min(145, 40 + correct * 5)),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordMentalRotationGame(correct: correct)
                let newAchievements = checkAndUnlock(stats: stats)
                if isNewBest && correct > 0 {
                    vm.showNewBest = true
                    Haptics.success()
                    Task { try? await Task.sleep(for: .seconds(2)); vm.showNewBest = false }
                }
                if leveledUp {
                    vm.leveledUpTo = stats.playerLevel
                    Task { try? await Task.sleep(for: .seconds(2.5)); vm.leveledUpTo = nil }
                }
                if let first = newAchievements.first {
                    let delay = (isNewBest || leveledUp) ? 2.8 : 0.3
                    Task {
                        try? await Task.sleep(for: .seconds(delay))
                        vm.unlockedAchievement = first
                        Haptics.success()
                        try? await Task.sleep(for: .seconds(3))
                        vm.unlockedAchievement = nil
                    }
                }
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
                Image(systemName: "rotate.3d")
                    .font(.system(size: 72))
                    .foregroundStyle(.yellow)
                Text("Shape Flip")
                    .font(.largeTitle.bold())
                Text("Are the two shapes the same (rotated)\nor a mirror image?")
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

            Button { vm.startGame(difficulty: difficulty) } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
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
            HStack {
                StatBadge(label: "Trial", value: "\(vm.trialIndex + 1)/\(vm.totalTrials)", color: .yellow)
                Spacer()
                StatBadge(label: "Score", value: "\(vm.score)", color: .green)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.mentalRotationBestScore)", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(timerColor)
                        .frame(width: vm.currentTimeLimit > 0
                               ? geo.size.width * CGFloat(vm.timeRemaining / vm.currentTimeLimit)
                               : 0)
                        .animation(.linear(duration: 0.05), value: vm.timeRemaining)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)

            Spacer()

            // Shape display
            if let trial = vm.currentTrial {
                HStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Reference")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ShapeGridView(cells: trial.leftCells, color: .yellow, size: 38)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 8) {
                        Text("Compare")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ShapeGridView(cells: trial.rightCells, color: .yellow, size: 38)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                // Feedback
                if vm.lastResult != .pending {
                    feedbackView
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer()

            // Answer buttons
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
                .disabled(vm.lastResult != .pending)

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
                .disabled(vm.lastResult != .pending)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.lastResult)
    }

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

    var timerColor: Color {
        let fraction = vm.currentTimeLimit > 0 ? vm.timeRemaining / vm.currentTimeLimit : 1.0
        if fraction > 0.5 { return .yellow }
        if fraction > 0.25 { return .orange }
        return .red
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "rotate.3d")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow)

                Text("Done!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Correct",       value: "\(vm.finalScore)/\(vm.totalTrials)", color: .yellow)
                    Divider()
                    resultRow("Brain Score",   value: "\(vm.finalBrainScore)",              color: .indigo)
                    resultRow("All-Time Best", value: "\(stats.mentalRotationBestScore)/20", color: .secondary)
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.finalScore > 0 && vm.finalScore == stats.mentalRotationBestScore {
                    Label("New personal best!", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            ShareResultButton(
                gameName: "Shape Flip",
                gameIcon: "rotate.3d",
                gameColor: .yellow,
                primaryValue: "\(vm.finalScore)/20",
                primaryLabel: "correct",
                secondaryLine: "Brain Score: \(vm.finalBrainScore)"
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button { vm.startGame(difficulty: difficulty) } label: {
                Text("Play Again")
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

    func resultRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

    func scoreColor(_ score: Int) -> Color {
        if score >= 120 { return .green }
        if score >= 100 { return .teal }
        if score >= 85  { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack { MentalRotationGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
