import SwiftUI
import SwiftData

// Math Blitz: answer as many simple arithmetic problems as possible in 60 seconds.

@MainActor
class MathBlitzViewModel: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var questionText: String = ""
    @Published var choices: [Int] = []
    @Published var correctAnswer: Int = 0
    @Published var score: Int = 0          // correct answers
    @Published var wrongCount: Int = 0
    @Published var timeRemaining: Double = 60
    @Published var lastCorrect: Bool? = nil // nil=unanswered, true/false for flash
    @Published var showNewBest = false
    @Published var wasNewBest = false   // set before stats update, so ties do not count
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    enum GameState { case idle, playing, gameOver }

    var onGameOver: ((Int) -> Void)?  // passes correct count

    private var timer: Timer?
    private var difficulty: Difficulty = .medium
    private var flashTask: Task<Void, Never>?

    var accuracy: Int {
        let total = score + wrongCount
        guard total > 0 else { return 100 }
        return Int(Double(score) / Double(total) * 100)
    }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        score = 0
        wrongCount = 0
        timeRemaining = 60
        lastCorrect = nil
        gameState = .playing
        nextQuestion()
        startTimer()
    }

    func selectAnswer(_ answer: Int) {
        guard gameState == .playing else { return }
        flashTask?.cancel()
        if answer == correctAnswer {
            score += 1
            lastCorrect = true
            Haptics.medium()
        } else {
            wrongCount += 1
            lastCorrect = false
            Haptics.error()
        }
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            nextQuestion()
            lastCorrect = nil
        }
    }

    private func nextQuestion() {
        let (lhs, rhs, op, answer) = generateProblem()
        questionText = "\(lhs) \(op) \(rhs)"
        correctAnswer = answer
        choices = makeChoices(correct: answer)
    }

    private func generateProblem() -> (Int, Int, String, Int) {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 1...9)
            let b = Int.random(in: 1...9)
            return (a, b, "+", a + b)
        case .medium:
            let ops = ["+", "-"]
            let op = ops.randomElement()!
            if op == "+" {
                let a = Int.random(in: 1...20)
                let b = Int.random(in: 1...20)
                return (a, b, "+", a + b)
            } else {
                let a = Int.random(in: 5...25)
                let b = Int.random(in: 1...a)
                return (a, b, "−", a - b)
            }
        case .hard:
            let ops = ["+", "−", "×"]
            let op = ops.randomElement()!
            switch op {
            case "+":
                let a = Int.random(in: 10...50)
                let b = Int.random(in: 10...50)
                return (a, b, "+", a + b)
            case "−":
                let a = Int.random(in: 10...50)
                let b = Int.random(in: 1...a)
                return (a, b, "−", a - b)
            default: // ×
                let a = Int.random(in: 2...12)
                let b = Int.random(in: 2...12)
                return (a, b, "×", a * b)
            }
        }
    }

    private func makeChoices(correct: Int) -> [Int] {
        var set = Set<Int>([correct])
        while set.count < 4 {
            let offset = Int.random(in: -15...15)
            let candidate = correct + offset
            if candidate != correct && candidate >= 0 {
                set.insert(candidate)
            }
        }
        return set.shuffled()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.endGame()
                }
            }
        }
    }

    private func endGame() {
        timer?.invalidate()
        timer = nil
        flashTask?.cancel()
        finalScore = score
        finalBrainScore = PlayerStats.speedBrainScore(correct: score)
        onGameOver?(score)
        gameState = .gameOver
    }

    /// Tears down every timer and task without recording a result.
    /// Called from .onDisappear so leaving mid-game never writes a session.
    func abandon() {
        timer?.invalidate()
        timer = nil
        flashTask?.cancel()
        flashTask = nil
        gameState = .idle
    }
}

struct MathBlitzGameView: View {
    @StateObject private var vm = MathBlitzViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("speedDifficulty") private var difficulty: Difficulty = .medium
    @State private var pendingStart = false

    private var stats: PlayerStats {
        statsQuery.first ?? PlayerStats.fetchOrCreate(in: modelContext)
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
        .navigationTitle("Math Blitz")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            // 3-2-1 before the clock starts, so the first stimulus
            // is not simultaneous with the timer going live.
            if pendingStart {
                CountdownOverlay {
                    pendingStart = false
                    vm.startGame(difficulty: difficulty)
                }
            }
        }
        .onAppear {
            vm.onGameOver = { correct in
                let isNewBest = correct > stats.speedBestScore
                vm.wasNewBest = isNewBest
                let session = GameSession(
                    gameType: "speed",
                    rawScore: correct,
                    brainScore: PlayerStats.speedBrainScore(correct: correct),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordSpeedGame(score: correct)
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
        .onDisappear { vm.abandon() }
    }

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:    idleView
        case .playing: playView
        case .gameOver: gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "function")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                Text("Math Blitz")
                    .font(.largeTitle.bold())
                Text("Answer as many math problems\nas you can in 60 seconds.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.speedBestScore > 0 {
                    Label("Record: \(stats.speedBestScore) correct", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button { pendingStart = true } label: {
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
            // Top stats bar
            HStack {
                StatBadge(label: "Correct", value: "\(vm.score)", color: .green)
                Spacer()
                StatBadge(label: "Accuracy", value: "\(vm.accuracy)%", color: .teal)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.speedBestScore)", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            timerBar

            Spacer()

            // Question
            Text(vm.questionText + " = ?")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .animation(nil, value: vm.questionText)

            // Answer feedback flash
            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 32)
            }

            Spacer()

            // Answer choices
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.choices, id: \.self) { choice in
                    Button {
                        vm.selectAnswer(choice)
                    } label: {
                        Text("\(choice)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.lastCorrect)
    }

    var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(timerColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining / 60))
                    .animation(.linear(duration: 0.1), value: vm.timeRemaining)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
        .overlay(alignment: .trailing) {
            Text(String(format: "%.0fs", vm.timeRemaining))
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(timerColor)
                .padding(.trailing, 20)
        }
    }

    var timerColor: Color {
        if vm.timeRemaining > 20 { return .green }
        if vm.timeRemaining > 10 { return .orange }
        return .red
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "function")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("Time's Up!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Correct Answers", value: "\(vm.finalScore)", color: .green)
                    resultRow("Wrong Answers",   value: "\(vm.wrongCount)", color: .red)
                    resultRow("Accuracy",        value: "\(vm.accuracy)%",  color: .teal)
                    Divider()
                    resultRow("Brain Score",     value: "\(vm.finalBrainScore)", color: .indigo)
                    resultRow("All-Time Best",   value: "\(stats.speedBestScore) correct", color: .secondary)
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.wasNewBest {
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
                gameName: "Math Blitz", gameIcon: "function", gameColor: .green,
                primaryValue: "\(vm.finalScore)", primaryLabel: "correct",
                secondaryLine: "Brain Score: \(vm.finalBrainScore)"
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button { pendingStart = true } label: {
                Text("Play Again")
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

    func resultRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

}

#Preview {
    NavigationStack { MathBlitzGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
