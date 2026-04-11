import SwiftUI
import SwiftData

// Code Cracker: Identify the rule in a sequence and choose the correct hidden element.
// Spy/terminal aesthetic — dark background, green tinted monospaced font.

// MARK: - Spy Color Constants

private let spyGreen  = Color(red: 0.2, green: 0.9, blue: 0.4)
private let spyBG     = Color(red: 0.051, green: 0.067, blue: 0.090)   // #0D1117

// MARK: - ViewModel

@MainActor
class PatternMatchViewModel: ObservableObject {
    static let totalQuestions = 10

    @Published var gameState: GameState = .idle
    @Published var questionIndex = 0
    @Published var correctCount = 0
    @Published var finalScore = 0
    @Published var currentPattern: CodePattern? = nil
    @Published var choices: [Int] = []
    @Published var answeredCorrect: Bool? = nil     // nil = not yet answered
    @Published var lastTappedAnswer: Int? = nil
    @Published var showRuleBanner = false
    @Published var ruleBannerText = ""
    @Published var timeRemaining: Double = 15
    @Published var newUnlockedPattern: String? = nil  // toast for newly unlocked pattern type
    @Published var bounceButton: Int? = nil            // index in choices to bounce

    // Combo
    let combo = ComboTracker()

    enum GameState { case idle, playing, gameOver }

    struct CodePattern {
        let fullSequence: [Int]       // all 4 elements (complete)
        let hiddenIndex: Int          // which index is hidden (0, middle, or last)
        let answer: Int               // the value at hiddenIndex
        let rule: String
        let category: EloSystem.PatternCategory
    }

    var onGameOver: ((Int, Int) -> Void)?  // passes (correctCount, finalScore)

    private var difficulty: Difficulty = .medium
    private var eloCategories: [EloSystem.PatternCategory] = [.addition]
    private var eloTimeLimit: Double? = nil
    private var flashTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    // MARK: - Public API

    func startGame(difficulty: Difficulty, params: EloSystem.PatternParams) {
        self.difficulty = difficulty
        self.eloCategories = params.categories
        self.eloTimeLimit = params.timeLimit
        questionIndex = 0
        correctCount = 0
        finalScore = 0
        answeredCorrect = nil
        lastTappedAnswer = nil
        bounceButton = nil
        combo.reset()
        gameState = .playing
        nextQuestion()
    }

    func selectAnswer(_ answer: Int) {
        guard gameState == .playing, let pattern = currentPattern,
              answeredCorrect == nil else { return }
        timerTask?.cancel()
        flashTask?.cancel()

        let correct = answer == pattern.answer
        answeredCorrect = correct
        lastTappedAnswer = answer

        if correct {
            correctCount += 1
            combo.markCorrect()
            let pts = combo.apply(10)
            finalScore += pts
            SoundEngine.shared.playCorrect(streak: combo.streak)
            Haptics.medium()
            // Find the index of the tapped answer and bounce it
            if let idx = choices.firstIndex(of: answer) {
                bounceButton = idx
            }
        } else {
            combo.markWrong()
            SoundEngine.shared.playWrong()
            Haptics.error()
        }

        // Show rule banner for 2 seconds, then advance
        ruleBannerText = "Rule: \(pattern.rule)"
        showRuleBanner = true

        flashTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            showRuleBanner = false
            bounceButton = nil
            advanceQuestion()
            answeredCorrect = nil
            lastTappedAnswer = nil
        }
    }

    func timeExpired() {
        guard gameState == .playing, answeredCorrect == nil else { return }
        // Count as wrong
        combo.markWrong()
        SoundEngine.shared.playWrong()
        answeredCorrect = false
        lastTappedAnswer = nil
        ruleBannerText = "Rule: \(currentPattern?.rule ?? "")"
        showRuleBanner = true
        flashTask?.cancel()
        flashTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            showRuleBanner = false
            advanceQuestion()
            answeredCorrect = nil
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
        timeRemaining = eloTimeLimit ?? 999
        let pattern = generatePattern()
        currentPattern = pattern
        choices = makeChoices(correct: pattern.answer)
        bounceButton = nil
        // Start timer if there's a time limit
        if let limit = eloTimeLimit {
            startTimer(limit: limit)
        }
    }

    private func startTimer(limit: Double) {
        timerTask?.cancel()
        timerTask = Task {
            let steps = Int(limit * 10)
            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                timeRemaining = limit - Double(i) * 0.1
                if timeRemaining <= 0 {
                    timeRemaining = 0
                    timeExpired()
                    return
                }
            }
        }
    }

    private func generatePattern() -> CodePattern {
        let category = eloCategories.randomElement() ?? .addition
        return buildPattern(category: category)
    }

    // Vary the hidden position: 50% last, 30% middle, 20% first
    private func hiddenIndex(sequenceLength: Int) -> Int {
        let r = Double.random(in: 0..<1)
        if r < 0.50 { return sequenceLength - 1 }
        if r < 0.80 { return sequenceLength / 2 }
        return 0
    }

    private func buildPattern(_ category: EloSystem.PatternCategory) -> CodePattern {
        switch category {
        case .addition:
            return buildAdditionPattern()
        case .multiplication:
            return buildMultiplicationPattern()
        case .fibonacci:
            return buildFibonacciPattern()
        case .alternating:
            return buildAlternatingPattern()
        case .squares:
            return buildSquaresPattern()
        }
    }

    private func buildAdditionPattern() -> CodePattern {
        let step = Int.random(in: 2...9)
        let start = Int.random(in: 1...15)
        let full = [start, start + step, start + step * 2, start + step * 3]
        let hIdx = hiddenIndex(sequenceLength: 4)
        return CodePattern(
            fullSequence: full,
            hiddenIndex: hIdx,
            answer: full[hIdx],
            rule: "+\(step) each time",
            category: .addition
        )
    }

    private func buildMultiplicationPattern() -> CodePattern {
        let factor = Int.random(in: 2...3)
        let start = Int.random(in: 2...7)
        let full = [start, start * factor, start * factor * factor, start * factor * factor * factor]
        let hIdx = hiddenIndex(sequenceLength: 4)
        return CodePattern(
            fullSequence: full,
            hiddenIndex: hIdx,
            answer: full[hIdx],
            rule: "×\(factor) each time",
            category: .multiplication
        )
    }

    private func buildFibonacciPattern() -> CodePattern {
        let a = Int.random(in: 1...5)
        let b = Int.random(in: 1...5)
        let c = a + b
        let d = b + c
        let full = [a, b, c, d]
        let hIdx = hiddenIndex(sequenceLength: 4)
        return CodePattern(
            fullSequence: full,
            hiddenIndex: hIdx,
            answer: full[hIdx],
            rule: "add previous two",
            category: .fibonacci
        )
    }

    private func buildAlternatingPattern() -> CodePattern {
        let stepA = Int.random(in: 2...5)
        let stepB = Int.random(in: 3...7)
        let start = Int.random(in: 1...12)
        let e1 = start
        let e2 = e1 + stepA
        let e3 = e2 + stepB
        let e4 = e3 + stepA
        let full = [e1, e2, e3, e4]
        let hIdx = hiddenIndex(sequenceLength: 4)
        return CodePattern(
            fullSequence: full,
            hiddenIndex: hIdx,
            answer: full[hIdx],
            rule: "+\(stepA), +\(stepB) alternating",
            category: .alternating
        )
    }

    private func buildSquaresPattern() -> CodePattern {
        // n², (n+1)², (n+2)², (n+3)²
        let n = Int.random(in: 2...6)
        let full = [n*n, (n+1)*(n+1), (n+2)*(n+2), (n+3)*(n+3)]
        let hIdx = hiddenIndex(sequenceLength: 4)
        return CodePattern(
            fullSequence: full,
            hiddenIndex: hIdx,
            answer: full[hIdx],
            rule: "perfect squares",
            category: .squares
        )
    }

    private func makeChoices(correct: Int) -> [Int] {
        var set = Set<Int>([correct])
        var attempts = 0
        while set.count < 4 && attempts < 300 {
            attempts += 1
            let spread = max(4, correct / 3)
            let offset = Int.random(in: -spread...spread)
            let candidate = correct + offset
            if candidate != correct && candidate > 0 {
                set.insert(candidate)
            }
        }
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

    private func endGame() {
        timerTask?.cancel()
        flashTask?.cancel()
        onGameOver?(correctCount, finalScore)
        gameState = .gameOver
    }
}

// MARK: - View

struct PatternMatchGameView: View {
    @StateObject private var vm = PatternMatchViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("patternDifficulty") private var difficulty: Difficulty = .medium
    @AppStorage("unlockedPatternCodes") private var unlockedPatternCodes: String = ""

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private var eloParams: EloSystem.PatternParams {
        EloSystem.patternParams(stats.patternEloRating)
    }

    // Parse/store unlocked pattern types as comma-separated names
    private var unlockedSet: Set<String> {
        Set(unlockedPatternCodes.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private func checkUnlockPattern(_ category: EloSystem.PatternCategory) -> Bool {
        let key = category.rawValue
        if unlockedSet.contains(key) { return false }
        var current = unlockedSet
        current.insert(key)
        unlockedPatternCodes = current.sorted().joined(separator: ",")
        return true
    }

    var body: some View {
        ZStack {
            spyBG.ignoresSafeArea()
            mainContent

            // New pattern unlocked toast
            if let name = vm.newUnlockedPattern {
                VStack {
                    Spacer()
                    Text("NEW PATTERN UNLOCKED: \(name.uppercased())")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(spyGreen, in: Capsule())
                        .padding(.bottom, 60)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.4), value: vm.newUnlockedPattern)
        .navigationTitle("Code Cracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(spyBG, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            vm.onGameOver = { correct, score in
                let isNewBest = correct > stats.patternBestScore
                let brainScore = PlayerStats.patternBrainScore(correct: correct)
                let session = GameSession(
                    gameType: "pattern",
                    rawScore: correct,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordPatternGame(correct: correct)
                stats.patternEloRating = EloSystem.updated(
                    stats.patternEloRating,
                    correct: correct >= 7
                )
                if isNewBest && correct > 0 {
                    Haptics.success()
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
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(spyGreen)

                Text("Code Cracker")
                    .font(.system(.largeTitle, design: .monospaced).bold())
                    .foregroundStyle(spyGreen)

                Text("Identify the encryption rule.\nDecrypt the sequence.")
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(spyGreen.opacity(0.7))
                    .padding(.horizontal)

                if stats.patternBestScore > 0 {
                    Label("Best: \(stats.patternBestScore)/10", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }

                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                    Text("Auto difficulty")
                        .font(.caption.bold())
                }
                .foregroundStyle(spyGreen)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(spyGreen.opacity(0.12), in: Capsule())

                // Patterns cracked count
                let crackedCount = unlockedSet.count
                if crackedCount > 0 {
                    Text("Patterns Cracked: \(crackedCount)/\(EloSystem.PatternCategory.allCases.count)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(spyGreen.opacity(0.6))
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button {
                vm.startGame(difficulty: difficulty, params: eloParams)
            } label: {
                Text("INITIATE MISSION")
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(spyGreen, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 16) {
            // Header row
            HStack {
                StatBadge(
                    label: "Mission",
                    value: "\(vm.questionIndex + 1)/\(PatternMatchViewModel.totalQuestions)",
                    color: spyGreen
                )
                Spacer()
                // Patterns cracked
                VStack(alignment: .center, spacing: 2) {
                    Text("CRACKED").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text("\(unlockedSet.count)").font(.title2.bold()).foregroundStyle(spyGreen)
                }
                Spacer()
                MultiplierBadgeView(combo: vm.combo, color: spyGreen)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar (only if time-limited)
            if eloParams.timeLimit != nil {
                timerBar
            }

            Spacer()

            // Sequence display
            if let pattern = vm.currentPattern {
                VStack(spacing: 10) {
                    // Question prompt
                    let promptText: String = {
                        switch pattern.hiddenIndex {
                        case 0:  return "What is the first number?"
                        case pattern.fullSequence.count - 1: return "What comes next?"
                        default: return "What is the missing number?"
                        }
                    }()
                    Text(promptText)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(spyGreen.opacity(0.7))

                    sequenceRow(pattern: pattern)
                        .padding(.horizontal)
                }

                // Rule banner shown after answer
                if vm.showRuleBanner {
                    Text(vm.ruleBannerText)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(
                            vm.answeredCorrect == true ? spyGreen : .orange
                        )
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill((vm.answeredCorrect == true ? spyGreen : Color.orange).opacity(0.12))
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                // Answer feedback text
                if let correct = vm.answeredCorrect {
                    Text(correct ? "DECRYPTED ✓" : "ENCRYPTION HOLDS")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(correct ? spyGreen : .red.opacity(0.85))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Color.clear.frame(height: 24)
                }
            }

            Spacer()

            // Answer choices 2×2
            let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(Array(vm.choices.enumerated()), id: \.offset) { idx, choice in
                    choiceButton(choice: choice, index: idx)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.18), value: vm.answeredCorrect)
        .animation(.easeInOut(duration: 0.18), value: vm.showRuleBanner)
    }

    @ViewBuilder
    func choiceButton(choice: Int, index: Int) -> some View {
        let bg = choiceBackground(for: choice)
        let fg = choiceForeground(for: choice)
        Button {
            vm.selectAnswer(choice)
            // Check if this category is newly unlocked
            if let category = vm.currentPattern?.category {
                if checkUnlockPattern(category) {
                    vm.newUnlockedPattern = category.rawValue
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        vm.newUnlockedPattern = nil
                    }
                }
            }
        } label: {
            Text("\(choice)")
                .font(.system(.title2, design: .monospaced).bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(bg)
                .foregroundStyle(fg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(vm.answeredCorrect != nil)
        .juiceBounce(trigger: vm.bounceButton == index)
    }

    func choiceBackground(for choice: Int) -> some View {
        Group {
            if let fc = flashColor(for: choice) {
                RoundedRectangle(cornerRadius: 14).fill(fc)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(spyGreen.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(spyGreen.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    func choiceForeground(for choice: Int) -> Color {
        if flashColor(for: choice) != nil { return .black }
        return spyGreen
    }

    func flashColor(for choice: Int) -> Color? {
        guard vm.answeredCorrect != nil, let pattern = vm.currentPattern else { return nil }
        if choice == pattern.answer { return spyGreen }
        if choice == vm.lastTappedAnswer { return .orange }
        return nil
    }

    @ViewBuilder
    func sequenceRow(pattern: PatternMatchViewModel.CodePattern) -> some View {
        let seq = pattern.fullSequence
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(seq.indices, id: \.self) { i in
                    if i > 0 {
                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                            .foregroundStyle(spyGreen.opacity(0.5))
                    }
                    if i == pattern.hiddenIndex {
                        // Placeholder card
                        Text("_?")
                            .font(.system(.title, design: .monospaced).bold())
                            .foregroundStyle(spyGreen)
                            .frame(width: 72, height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(spyGreen.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                            .foregroundStyle(spyGreen.opacity(0.7))
                                            .modifier(PulsingBorderModifier())
                                    )
                            )
                    } else {
                        Text("\(seq[i])")
                            .font(.system(.title, design: .monospaced).bold())
                            .foregroundStyle(spyGreen)
                            .frame(width: 72, height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(spyGreen.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(spyGreen.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    var timerBar: some View {
        let limit = eloParams.timeLimit ?? 15
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5).opacity(0.3))
                Capsule()
                    .fill(timerColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining / limit))
                    .animation(.linear(duration: 0.1), value: vm.timeRemaining)
            }
        }
        .frame(height: 6)
        .padding(.horizontal)
        .overlay(alignment: .trailing) {
            Text(String(format: "%.0fs", vm.timeRemaining))
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(timerColor)
                .padding(.trailing, 20)
        }
    }

    var timerColor: Color {
        let limit = eloParams.timeLimit ?? 15
        let ratio = vm.timeRemaining / limit
        if ratio > 0.5 { return spyGreen }
        if ratio > 0.25 { return .orange }
        return .red
    }

    // MARK: - Game Over

    var gameOverView: some View {
        let brainScore = PlayerStats.patternBrainScore(correct: vm.correctCount)
        let bestMult = vm.combo.multiplier  // best multiplier reached (approximation)
        let result = GameResult(
            gameTitle: "Code Cracker",
            primaryScore: vm.finalScore,
            primaryLabel: "pts",
            brainScore: brainScore,
            previousBrainScore: stats.patternBrainScore,
            isNewBest: vm.finalScore > 0 && vm.correctCount >= stats.patternBestScore,
            multiplierBreakdown: bestMult > 1.0
                ? GameResult.MultiplierBreakdown(
                    baseScore: vm.correctCount * 10,
                    bestMultiplier: bestMult,
                    finalScore: vm.finalScore
                  )
                : nil,
            percentileText: PlayerStats.percentileLabel(for: brainScore),
            accentColor: spyGreen,
            share: GameResult.ShareConfig(
                gameName: "Code Cracker",
                icon: "lock.open.fill",
                color: spyGreen,
                primaryValue: "\(vm.finalScore)",
                primaryLabel: "pts",
                secondaryLine: "\(vm.correctCount)/10 decrypted"
            )
        )
        return GameOverView(result: result) {
            vm.startGame(difficulty: difficulty, params: eloParams)
        }
    }
}

// MARK: - Pulsing border animation modifier (shared)

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
