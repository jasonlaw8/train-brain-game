import SwiftUI
import SwiftData

// Stroop Challenge — tap the ink color, not the word meaning.
// Round-based rule escalation, combo multiplier, streak flames, and Zen Mode.

struct ColorOption: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let color: Color
}

// MARK: - ViewModel

@MainActor
class ColorGameViewModel: ObservableObject {
    private let allOptions: [ColorOption] = [
        ColorOption(name: "RED",    color: .red),
        ColorOption(name: "BLUE",   color: .blue),
        ColorOption(name: "GREEN",  color: .green),
        ColorOption(name: "YELLOW", color: .yellow),
        ColorOption(name: "PURPLE", color: .purple),
        ColorOption(name: "ORANGE", color: .orange),
    ]

    // Non-color words for rounds 6-10 variation
    private let nonColorWords = ["TREE", "HOUSE", "CLOUD", "FISH", "BIRD", "STAR", "MOON", "ROCK"]

    @Published var wordText = ""
    @Published var inkColor: Color = .red
    @Published var choices: [ColorOption] = []
    @Published var score = 0
    @Published var timeRemaining: Double = 30
    @Published var totalDuration: Double = 30
    @Published var gameState: GameState = .idle
    @Published var lastCorrect: Bool? = nil
    @Published var lastTappedId: UUID? = nil
    @Published var lastWrongId: UUID? = nil
    @Published var answerCount = 0           // total answered (correct + wrong)
    @Published var correctAttempts = 0
    @Published var totalAttempts = 0
    @Published var mistakeCount = 0          // for Zen Mode end condition
    @Published var currentRule: StroopRule = .tapInkColor
    @Published var showRuleBanner = false
    @Published var ruleBannerText = ""
    @Published var gameResult: GameResult? = nil
    @Published var bestMultiplier: Double = 1.0
    @Published var isZenMode: Bool = false

    private var correctOption: ColorOption?
    private var timer: Timer?
    private var difficulty: Difficulty = .medium

    enum StroopRule: Equatable {
        case tapInkColor        // rounds 1-5, 6-10, odd rounds 11-15
        case tapWordMeaning     // even rounds 11-15
        case speedStroop        // rounds 16+
    }

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts)
    }

    var accuracyPercent: Int { Int(accuracy * 100) }

    enum GameState { case idle, playing, gameOver }
    var onGameOver: ((Int, Double) -> Void)?    // (finalScore, accuracy)

    func startGame(difficulty: Difficulty, zenMode: Bool) {
        self.difficulty = difficulty
        self.isZenMode = zenMode
        totalDuration = difficulty.colorTimerDuration
        score = 0
        answerCount = 0
        correctAttempts = 0
        totalAttempts = 0
        mistakeCount = 0
        bestMultiplier = 1.0
        timeRemaining = difficulty.colorTimerDuration
        currentRule = .tapInkColor
        showRuleBanner = false
        gameResult = nil
        gameState = .playing
        nextQuestion()
        if !zenMode {
            startTimer()
        }
    }

    // Called by view when player selects a button
    func selectColor(_ option: ColorOption) -> Bool {
        guard gameState == .playing else { return false }
        let correct = option.id == correctOption?.id
        lastCorrect = correct
        lastTappedId = option.id
        totalAttempts += 1

        if correct {
            correctAttempts += 1
        } else {
            lastWrongId = option.id
            mistakeCount += 1
        }
        return correct
    }

    // Called by view after combo updates, applies score and advances question
    func applyResult(correct: Bool, combo: ComboTracker) {
        guard gameState == .playing else { return }
        let base = 10
        if correct {
            let pts = combo.apply(base)
            score += pts
            bestMultiplier = max(bestMultiplier, combo.multiplier)
        } else {
            score = max(0, score - 5)
            // Zen mode: end on 3rd mistake
            if isZenMode && mistakeCount >= 3 {
                endGame()
                return
            }
        }

        answerCount += 1
        updateRule()

        let delay = difficulty.colorQuestionDelay
        if delay == 0 {
            nextQuestion()
        } else {
            Task {
                try? await Task.sleep(for: .seconds(delay))
                guard gameState == .playing else { return }
                nextQuestion()
            }
        }
    }

    private func updateRule() {
        let prevRule = currentRule
        switch answerCount {
        case ..<5:
            currentRule = .tapInkColor
        case 5..<10:
            // Rounds 6-10: non-color words in colors, still tap ink color
            currentRule = .tapInkColor
        case 10..<15:
            // Rounds 11-15: alternating — even index=tapWord, odd=tapInk
            currentRule = (answerCount % 2 == 0) ? .tapWordMeaning : .tapInkColor
        default:
            // Rounds 16+: Speed Stroop
            currentRule = .speedStroop
        }

        // Show rule-switch banner when rule changes
        if currentRule != prevRule {
            let bannerText: String
            switch currentRule {
            case .tapWordMeaning:
                bannerText = "TAP WORD"
            case .tapInkColor, .speedStroop:
                bannerText = "TAP COLOR"
            }
            ruleBannerText = bannerText
            withAnimation(.easeInOut(duration: 0.2)) { showRuleBanner = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 0.2)) { showRuleBanner = false }
            }
        }
    }

    private func nextQuestion() {
        lastCorrect = nil
        lastTappedId = nil
        lastWrongId = nil
        let pool = Array(allOptions.prefix(difficulty.colorOptionCount))

        switch currentRule {
        case .tapInkColor, .speedStroop:
            let useNonColor = (5..<10).contains(answerCount)
            if useNonColor {
                wordText = nonColorWords.randomElement()!
            } else {
                let word = pool.randomElement()!
                wordText = word.name
            }
            var ink: ColorOption
            repeat { ink = pool.randomElement()! } while (!useNonColor && ink.name == wordText)
            inkColor = ink.color
            correctOption = ink

        case .tapWordMeaning:
            // Even rounds 11-15: tap the named color, not the ink
            let word = pool.randomElement()!
            var ink: ColorOption
            repeat { ink = pool.randomElement()! } while ink.id == word.id
            wordText = word.name
            inkColor = ink.color
            correctOption = word  // correct answer = match the word meaning
        }

        var others = pool.filter { $0.id != correctOption?.id }
        others.shuffle()
        choices = ([correctOption!] + Array(others.prefix(3))).shuffled()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.timeRemaining = max(0, self.timeRemaining - 0.05)
                if self.timeRemaining == 0 { self.endGame() }
            }
        }
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        gameState = .gameOver
        onGameOver?(score, accuracy)
    }
}

// MARK: - View

struct ColorGameView: View {
    @StateObject private var vm = ColorGameViewModel()
    @StateObject private var combo = ComboTracker()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("colorDifficulty") private var difficulty: Difficulty = .medium

    @State private var zenMode = false
    @State private var showGameOver = false

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch vm.gameState {
                case .idle:
                    idleView
                case .playing:
                    playingView
                case .gameOver:
                    Color.clear
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.gameState)

            // Screen-edge warm glow at streak 5+
            if vm.gameState == .playing && combo.streak >= 5 {
                streakEdgeGlow
                    .zIndex(5)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if showGameOver, let result = vm.gameResult {
                GameOverView(result: result) {
                    showGameOver = false
                    vm.gameState = .idle
                    combo.reset()
                }
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGameOver)
        .navigationTitle("Stroop Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { finalScore, accuracy in
                let isNewBest = finalScore > stats.colorBestScore
                let session = GameSession(
                    gameType: "color",
                    rawScore: finalScore,
                    brainScore: 0,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordColorGame(score: finalScore, streak: combo.streak)
                // Elo update: correct if accuracy > 75%
                stats.stroopEloRating = EloSystem.updated(stats.stroopEloRating, correct: accuracy > 0.75)

                let breakdown: GameResult.MultiplierBreakdown? = vm.bestMultiplier > 1.0
                    ? GameResult.MultiplierBreakdown(
                        baseScore: Int(Double(finalScore) / vm.bestMultiplier),
                        bestMultiplier: vm.bestMultiplier,
                        finalScore: finalScore
                      )
                    : nil

                let result = GameResult(
                    gameTitle: "Stroop Challenge",
                    primaryScore: finalScore,
                    primaryLabel: "pts",
                    brainScore: 0,
                    previousBrainScore: 0,
                    isNewBest: isNewBest,
                    multiplierBreakdown: breakdown,
                    percentileText: "\(Int(accuracy * 100))% accuracy",
                    accentColor: .purple,
                    share: GameResult.ShareConfig(
                        gameName: "Stroop Challenge",
                        icon: "paintpalette.fill",
                        color: .purple,
                        primaryValue: "\(finalScore)",
                        primaryLabel: "pts",
                        secondaryLine: "\(Int(accuracy * 100))% accuracy"
                    )
                )
                vm.gameResult = result
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation { showGameOver = true }
                }
            }
        }
    }

    // MARK: - Screen-edge streak glow

    private var streakEdgeGlow: some View {
        let glowOpacity = min(0.3, Double(combo.streak - 5) / 15.0 * 0.22 + 0.08)
        return GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [.orange.opacity(glowOpacity), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 60)
                .frame(maxWidth: .infinity, alignment: .leading)

                LinearGradient(
                    colors: [.clear, .orange.opacity(glowOpacity)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 60)
                .frame(maxWidth: .infinity, alignment: .trailing)

                LinearGradient(
                    colors: [.clear, .red.opacity(glowOpacity)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: combo.streak)
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.purple)
                Text("Stroop Challenge")
                    .font(.largeTitle.bold())
                Text("Tap the COLOR the word is written in\n— not what it says!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.colorBestScore > 0 {
                    Label("Best: \(stats.colorBestScore) pts", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
                // Auto difficulty badge
                StroopAutoDiffBadge(eloRating: stats.stroopEloRating)

                // Mode toggle
                HStack {
                    Toggle(isOn: $zenMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zenMode ? "Zen Mode" : "Rush Mode")
                                .font(.subheadline.bold())
                            Text(zenMode ? "No timer — 3 mistakes ends game" : "30-second time limit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.purple)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            Spacer()
            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)
            Button {
                showGameOver = false
                combo.reset()
                vm.startGame(difficulty: difficulty, zenMode: zenMode)
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Playing

    var playingView: some View {
        VStack(spacing: 0) {
            // Header: score, streak flame, multiplier
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    AnimatedScoreText(value: vm.score, font: .title2.bold(), color: .purple)
                }

                Spacer()

                StreakFlameBadge(streak: combo.streak)

                Spacer()

                MultiplierBadgeView(combo: combo, color: .purple)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Rule switch banner
            if vm.showRuleBanner {
                Text(vm.ruleBannerText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Color.purple.gradient, in: Capsule())
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Timer bar (Rush Mode) or mistake dots (Zen Mode)
            if !vm.isZenMode {
                timerSection
            } else {
                zenMistakeDots
            }

            Spacer()

            // Current rule cue
            Text(ruleLabel)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            // Word display
            Text(vm.wordText)
                .font(.system(size: 80, weight: .black))
                .foregroundStyle(vm.inkColor)
                .shadow(color: vm.inkColor.opacity(0.25), radius: 10)
                .id(vm.wordText + vm.answerCount.description)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.3), value: vm.wordText)

            // Feedback icon
            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? Color.green : Color.red)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.25), value: vm.lastCorrect)
            }

            Spacer()

            // Answer buttons
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.choices) { option in
                    StroopAnswerButton(
                        option: option,
                        lastTappedId: vm.lastTappedId,
                        lastWrongId: vm.lastWrongId,
                        lastCorrect: vm.lastCorrect
                    ) {
                        let correct = vm.selectColor(option)
                        if correct {
                            combo.markCorrect()
                        } else {
                            combo.markWrong()
                        }
                        vm.applyResult(correct: correct, combo: combo)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showRuleBanner)
    }

    private var timerSection: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(timerBarColor)
                        .frame(width: geo.size.width * CGFloat(vm.timeRemaining / vm.totalDuration))
                }
            }
            .frame(height: 8)
            .animation(.linear(duration: 0.05), value: vm.timeRemaining)

            Text(String(format: "%.1fs", vm.timeRemaining))
                .font(.caption.monospacedDigit())
                .foregroundStyle(timerBarColor)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var zenMistakeDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < vm.mistakeCount ? "xmark.circle.fill" : "circle")
                    .foregroundStyle(i < vm.mistakeCount ? Color.red : Color(.systemGray3))
                    .animation(.spring(response: 0.3), value: vm.mistakeCount)
            }
            Text("mistakes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var ruleLabel: String {
        switch vm.currentRule {
        case .tapWordMeaning: return "Tap what the word MEANS"
        case .tapInkColor:    return "Tap the ink COLOR"
        case .speedStroop:    return "SPEED — tap the ink COLOR"
        }
    }

    var timerBarColor: Color {
        let fraction = vm.timeRemaining / vm.totalDuration
        if fraction > 0.5 { return .green }
        if fraction > 0.25 { return .orange }
        return .red
    }
}

// MARK: - StroopAnswerButton

struct StroopAnswerButton: View {
    let option: ColorOption
    let lastTappedId: UUID?
    let lastWrongId: UUID?
    let lastCorrect: Bool?
    let onTap: () -> Void

    @State private var bouncing = false
    @State private var flashing = false
    @State private var dimming = false

    var body: some View {
        Button { onTap() } label: {
            RoundedRectangle(cornerRadius: 16)
                .fill(option.color)
                .overlay(
                    Text(option.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                )
                .frame(height: 72)
        }
        .buttonStyle(.plain)
        .juiceBounce(trigger: bouncing)
        .juiceFlash(trigger: flashing, color: .white)
        .juiceDim(trigger: dimming)
        .onChange(of: lastTappedId) { _, newId in
            guard newId == option.id, lastCorrect == true else { return }
            bouncing = true; flashing = true
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                bouncing = false; flashing = false
            }
        }
        .onChange(of: lastWrongId) { _, newId in
            guard newId == option.id else { return }
            dimming = true
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                dimming = false
            }
        }
    }
}

// MARK: - StroopAutoDiffBadge

private struct StroopAutoDiffBadge: View {
    let eloRating: Double

    private var label: String {
        switch eloRating {
        case ..<1000: return "Auto · Easy"
        case 1000..<1200: return "Auto · Medium"
        default: return "Auto · Hard"
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(.systemGray5), in: Capsule())
    }
}

#Preview {
    NavigationStack { ColorGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
