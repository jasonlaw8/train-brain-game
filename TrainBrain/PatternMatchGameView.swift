import SwiftUI
import SwiftData

// Pattern Match: identify the rule in a 3-item sequence and choose the correct 4th item.

// MARK: - ViewModel

@MainActor
class PatternMatchViewModel: ObservableObject {
    static let totalQuestions = 10

    @Published var gameState: GameState = .idle
    @Published var questionIndex = 0
    @Published var correctCount = 0
    @Published var currentPattern: Pattern? = nil
    @Published var choices: [Int] = []         // 4 numeric answer choices
    @Published var lastCorrect: Bool? = nil    // brief feedback flash
    @Published var lastTappedAnswer: Int? = nil // which choice was tapped (for color flash)
    @Published var timeRemaining: Double = 30  // only used on Hard
    @Published var showNewBest = false
    @Published var wasNewBest = false   // set before stats update, so ties do not count
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    struct Pattern {
        let sequence: [Int]   // 3 displayed items
        let answer: Int       // correct 4th item
        let rule: String      // human-readable rule for subtitle (e.g. "+4 each time")
    }

    enum GameState { case idle, playing, gameOver }

    var onGameOver: ((Int) -> Void)?  // passes correctCount

    private var difficulty: Difficulty = .medium
    private var timer: Timer?
    private var flashTask: Task<Void, Never>?

    // MARK: - Public API

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        questionIndex = 0
        correctCount = 0
        lastCorrect = nil
        lastTappedAnswer = nil
        timeRemaining = 30
        gameState = .playing
        nextQuestion()
        if difficulty == .hard {
            startTimer()
        }
    }

    func selectAnswer(_ answer: Int) {
        guard gameState == .playing, let pattern = currentPattern else { return }
        flashTask?.cancel()
        let correct = answer == pattern.answer
        lastCorrect = correct
        lastTappedAnswer = answer
        if correct {
            correctCount += 1
            Haptics.medium()
        } else {
            Haptics.error()
        }
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            advanceQuestion()
            lastCorrect = nil
            lastTappedAnswer = nil
        }
    }

    // MARK: - Private

    private func advanceQuestion() {
        if questionIndex + 1 >= PatternMatchViewModel.totalQuestions {
            endGame()
        } else {
            questionIndex += 1
            nextQuestion()
        }
    }

    private func nextQuestion() {
        let pattern = generatePattern()
        currentPattern = pattern
        choices = makeChoices(correct: pattern.answer)
    }

    private func generatePattern() -> Pattern {
        switch difficulty {
        case .easy:
            return generateArithmeticEasy()
        case .medium:
            return generateArithmeticMedium()
        case .hard:
            return generateArithmeticHard()
        }
    }

    // Easy: simple arithmetic +2, +3, +5; start 1–10
    private func generateArithmeticEasy() -> Pattern {
        let steps = [2, 3, 5]
        let step = steps.randomElement()!
        let start = Int.random(in: 1...10)
        let seq = [start, start + step, start + step * 2]
        let answer = start + step * 3
        return Pattern(sequence: seq, answer: answer, rule: "+\(step) each time")
    }

    // Medium: +4 to +9 or ×2
    private func generateArithmeticMedium() -> Pattern {
        let useMultiply = Bool.random()
        if useMultiply {
            let start = Int.random(in: 2...8)
            let seq = [start, start * 2, start * 4]
            let answer = start * 8
            return Pattern(sequence: seq, answer: answer, rule: "×2 each time")
        } else {
            let step = Int.random(in: 4...9)
            let start = Int.random(in: 2...15)
            let seq = [start, start + step, start + step * 2]
            let answer = start + step * 3
            return Pattern(sequence: seq, answer: answer, rule: "+\(step) each time")
        }
    }

    // Hard: ×2, ×3, fibonacci-like, or alternating two rules (+3/+5)
    private func generateArithmeticHard() -> Pattern {
        let variant = Int.random(in: 0...3)
        switch variant {
        case 0: // ×2
            let start = Int.random(in: 2...6)
            let seq = [start, start * 2, start * 4]
            let answer = start * 8
            return Pattern(sequence: seq, answer: answer, rule: "×2 each time")
        case 1: // ×3
            let start = Int.random(in: 1...4)
            let seq = [start, start * 3, start * 9]
            let answer = start * 27
            return Pattern(sequence: seq, answer: answer, rule: "×3 each time")
        case 2: // fibonacci-like: each item = sum of previous two
            let a = Int.random(in: 1...5)
            let b = Int.random(in: 1...5)
            let c = a + b
            let answer = b + c
            return Pattern(sequence: [a, b, c], answer: answer, rule: "add previous two")
        default: // alternating +3, +5, +3, +5 — sequence shows positions 0,1,2; answer is position 3
            // positions: s, s+3, s+3+5=s+8, answer = s+8+3=s+11
            let stepA = 3
            let stepB = 5
            let start = Int.random(in: 1...12)
            let seq = [start, start + stepA, start + stepA + stepB]
            let answer = start + stepA + stepB + stepA
            return Pattern(sequence: seq, answer: answer, rule: "+\(stepA), +\(stepB) alternating")
        }
    }

    private func makeChoices(correct: Int) -> [Int] {
        var set = Set<Int>([correct])
        var attempts = 0
        while set.count < 4 && attempts < 200 {
            attempts += 1
            // Vary the spread based on the magnitude of the correct answer to keep distractors plausible
            let spread = max(5, correct / 3)
            let offset = Int.random(in: -spread...spread)
            let candidate = correct + offset
            if candidate != correct && candidate > 0 {
                set.insert(candidate)
            }
        }
        // Fallback: if still short, add sequential offsets
        var fallback = 1
        while set.count < 4 {
            if !set.contains(correct + fallback) && correct + fallback > 0 {
                set.insert(correct + fallback)
            } else if !set.contains(correct - fallback) && correct - fallback > 0 {
                set.insert(correct - fallback)
            }
            fallback += 1
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
        onGameOver?(correctCount)
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

// MARK: - View

struct PatternMatchGameView: View {
    @StateObject private var vm = PatternMatchViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("patternDifficulty") private var difficulty: Difficulty = .medium

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
        .navigationTitle("Pattern Match")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correct in
                let isNewBest = correct > stats.patternBestScore
                vm.wasNewBest = isNewBest
                let leveledUp = stats.recordPatternGame(correct: correct)
                let session = GameSession(
                    gameType: "pattern",
                    rawScore: correct,
                    brainScore: PlayerStats.patternBrainScore(correct: correct),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
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
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.pink)
                Text("Pattern Match")
                    .font(.largeTitle.bold())
                Text("Find the rule and complete the sequence.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.patternBestScore > 0 {
                    Label("Best: \(stats.patternBestScore)/10", systemImage: "trophy.fill")
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
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 20) {
            // Top progress bar
            HStack {
                StatBadge(
                    label: "Question",
                    value: "\(vm.questionIndex + 1)/\(PatternMatchViewModel.totalQuestions)",
                    color: .pink
                )
                Spacer()
                StatBadge(label: "Correct", value: "\(vm.correctCount)", color: .green)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar — only on Hard
            if difficulty == .hard {
                timerBar
            }

            Spacer()

            // Pattern display with rule subtitle
            if let pattern = vm.currentPattern {
                VStack(spacing: 6) {
                    Text("What comes next?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Rule: \(pattern.rule)")
                        .font(.caption.bold())
                        .foregroundStyle(.pink.opacity(0.8))
                }

                // Sequence display
                sequenceRow(pattern: pattern)
                    .padding(.horizontal)
            }

            // Feedback flash icon
            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 32)
            }

            Spacer()

            // Answer choices 2×2
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
                                choiceBackground(for: choice)
                            )
                            .foregroundStyle(choiceForeground(for: choice))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.lastCorrect != nil)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.lastCorrect)
    }

    func choiceBackground(for choice: Int) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(flashColor(for: choice) ?? Color(.secondarySystemBackground))
    }

    func choiceForeground(for choice: Int) -> Color {
        if let _ = flashColor(for: choice) { return .white }
        return .primary
    }

    /// Returns a highlight color during the post-tap flash window, nil otherwise.
    /// - Correct answer always shown green once an answer is tapped.
    /// - The tapped wrong answer is shown red.
    func flashColor(for choice: Int) -> Color? {
        guard vm.lastCorrect != nil, let pattern = vm.currentPattern else { return nil }
        if choice == pattern.answer {
            return .green
        }
        if choice == vm.lastTappedAnswer {
            return .red
        }
        return nil
    }

    @ViewBuilder
    func sequenceRow(pattern: PatternMatchViewModel.Pattern) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(pattern.sequence.enumerated()), id: \.offset) { index, item in
                sequenceCard(text: "\(item)", dashed: false)
                if index < pattern.sequence.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "arrow.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            questionCard
        }
        .frame(maxWidth: .infinity)
    }

    func sequenceCard(text: String, dashed: Bool) -> some View {
        Text(text)
            .font(.title.bold())
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }

    var questionCard: some View {
        Text("?")
            .font(.title.bold())
            .foregroundStyle(.pink)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.pink.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(Color.pink.opacity(0.7))
                    .modifier(PulsingBorderModifier())
            )
    }

    var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(timerColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining / 30.0))
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
        if vm.timeRemaining > 15 { return .green }
        if vm.timeRemaining > 8  { return .orange }
        return .red
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.pink)

                Text("Results")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Correct", value: "\(vm.correctCount)/\(PatternMatchViewModel.totalQuestions)", color: .pink)
                    resultRow("Accuracy", value: "\(accuracy)%", color: .teal)
                    Divider()
                    resultRow("Brain Score",
                              value: "\(PlayerStats.patternBrainScore(correct: vm.correctCount))",
                              color: .indigo)
                    resultRow("All-Time Best", value: "\(stats.patternBestScore)/10", color: .secondary)
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(
                                for: PlayerStats.patternBrainScore(correct: vm.correctCount)
                              ),
                              color: scoreColor(PlayerStats.patternBrainScore(correct: vm.correctCount)))
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
                gameName: "Pattern Match",
                gameIcon: "puzzlepiece.fill",
                gameColor: .pink,
                primaryValue: "\(vm.correctCount)/10",
                primaryLabel: "correct",
                secondaryLine: nil
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button { vm.startGame(difficulty: difficulty) } label: {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    var accuracy: Int {
        guard vm.questionIndex > 0 || vm.gameState == .gameOver else { return 100 }
        let attempted = vm.gameState == .gameOver
            ? PatternMatchViewModel.totalQuestions
            : vm.questionIndex
        guard attempted > 0 else { return 100 }
        return Int(Double(vm.correctCount) / Double(attempted) * 100)
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

// MARK: - Pulsing border animation modifier

struct PulsingBorderModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { PatternMatchGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
