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

    // Non-color words for round 6-10 variation
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
    @Published var roundNumber = 0            // total answer count (correct + wrong)
    @Published var correctAttempts = 0
    @Published var totalAttempts = 0
    @Published var mistakeCount = 0           // for Zen Mode
    @Published var currentRule: StroopRule = .tapInkColor
    @Published var showRuleBanner = false
    @Published var ruleBannerText = ""
    @Published var gameResult: GameResult? = nil
    @Published var bestMultiplier: Double = 1.0

    private var correctOption: ColorOption?
    private var timer: Timer?
    private var difficulty: Difficulty = .medium
    private var isZenMode: Bool = false
    private var responseWindowMs: Double = 3000   // for rounds 16+

    enum StroopRule {
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
        roundNumber = 0
        correctAttempts = 0
        totalAttempts = 0
        mistakeCount = 0
        bestMultiplier = 1.0
        timeRemaining = difficulty.colorTimerDuration
        currentRule = .tapInkColor
        showRuleBanner = false
        gameResult = nil
        gameState = .playing
        responseWindowMs = 3000
        nextQuestion()
        if !zenMode {
            startTimer()
        }
    }

    func selectColor(_ option: ColorOption) {
        guard gameState == .playing else { return }
        let correct = option == correctOption
        lastCorrect = correct
        lastTappedId = option.id
        totalAttempts += 1

        if correct {
            correctAttempts += 1
        } else {
            lastWrongId = option.id
            mistakeCount += 1
        }
    }

    // Called by view after combo updates
    func applyResult(correct: Bool, combo: ComboTracker) {
        guard gameState == .playing else { return }
        let base = 10
        if correct {
            let pts = combo.apply(base)
            score += pts
            bestMultiplier = max(bestMultiplier, combo.multiplier)
            SoundEngine.shared.playCorrect(streak: combo.streak)
            Haptics.medium()
        } else {
            score = max(0, score - 5)
            SoundEngine.shared.playWrong()
            Haptics.error()
            // Zen mode: end on 3rd mistake
            if isZenMode && mistakeCount >= 3 {
                endGame()
                return
            }
        }

        roundNumber += 1
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
        switch roundNumber {
        case ..<5:
            currentRule = .tapInkColor
        case 5..<10:
            // Rounds 6-10: non-color words, still tap ink color
            currentRule = .tapInkColor
        case 10..<15:
            // Rounds 11-15: alternating — odd=tapInk, even=tapWord
            currentRule = (roundNumber % 2 == 0) ? .tapWordMeaning : .tapInkColor
        default:
            // Rounds 16+: Speed Stroop, shrinking window
            currentRule = .speedStroop
            responseWindowMs = max(500, 3000 - Double(roundNumber - 15) * 50)
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
            // For rounds 6-10, sometimes use non-color words
            let useNonColor = (5..<10).contains(roundNumber)
            if useNonColor {
                wordText = nonColorWords.randomElement()!
            } else {
                let word = pool.randomElement()!
                wordText = word.name
            }
            var ink: ColorOption
            repeat { ink = pool.randomElement()! } while useNonColor ? false : ink.name == wordText
            inkColor = ink.color
            correctOption = ink

        case .tapWordMeaning:
            // Even rounds 11-15: tap what the word SAYS
            let word = pool.randomElement()!
            var ink: ColorOption
            repeat { ink = pool.randomElement()! } while ink == word
            wordText = word.name
            inkColor = ink.color
            correctOption = word  // correct = match the word's meaning
        }

        var others = pool.filter { $0 != correctOption }
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
    @State private var correctButtonBounce: UUID? = nil
    @State private var correctButtonFlash: UUID? = nil
    @State private var wrongButtonDim: UUID? = nil

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
            if combo.streak >= 5 {
                let glowOpacity = min(0.3, Double(combo.streak - 5) / 15.0 * 0.3 + 0.08)
                GeometryReader { geo in
                    ZStack {
                        // Left edge
                        LinearGradient(
                            colors: [.orange.opacity(glowOpacity), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 60)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Right edge
                        LinearGradient(
                            colors: [.clear, .orange.opacity(glowOpacity)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        // Bottom edge
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
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.5), value: combo.streak)
                .zIndex(5)
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
                let brainScore = 0  // color is training-only, no normalized score
                let session = GameSession(
                    gameType: "color",
                    rawScore: finalScore,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordColorGame(score: finalScore, streak: combo.streak)
                // Elo update
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
                    percentileText: "\(vm.accuracyPercent)% accuracy",
                    accentColor: .purple,
                    share: GameResult.ShareConfig(
                        gameName: "Stroop Challenge",
                        icon: "paintpalette.fill",
                        color: .purple,
                        primaryValue: "\(finalScore)",
                        primaryLabel: "pts",
                        secondaryLine: "\(vm.accuracyPercent)% accuracy"
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

                // Zen Mode toggle
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
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    AnimatedScoreText(value: vm.score, font: .title2.bold(), color: .purple)
                }

                Spacer()

                // Streak flame
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
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, 6)
            }

            // Timer (Rush mode only)
            if !zenMode {
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
            } else {
                // Zen mode: show mistake count
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < vm.mistakeCount ? "xmark.circle.fill" : "circle")
                            .foregroundStyle(i < vm.mistakeCount ? Color.red : Color(.systemGray3))
                    }
                    Text("mistakes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }

            Spacer()

            // Current rule indicator
            Text(ruleLabel)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            // Word display
            Text(vm.wordText)
                .font(.system(size: 80, weight: .black))
                .foregroundStyle(vm.inkColor)
                .shadow(color: vm.inkColor.opacity(0.25), radius: 10)
                .id(vm.wordText + "\(vm.inkColor)")
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
            }

            Spacer()

            // Answer buttons
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.choices) { option in
                    AnswerButton(
                        option: option,
                        lastTappedId: vm.lastTappedId,
                        lastWrongId: vm.lastWrongId,
                        lastCorrect: vm.lastCorrect
                    ) {
                        handleTap(option)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showRuleBanner)
    }

    private var ruleLabel: String {
        switch vm.currentRule {
        case .tapWordMeaning: return "Tap what the word MEANS"
        case .tapInkColor, .speedStroop: return "Tap the ink COLOR"
        }
    }

    private func handleTap(_ option: ColorOption) {
        guard vm.gameState == .playing else { return }
        let correct = option == vm.choices.first(where: { _ in true }) ? false : false  // placeholder
        vm.selectColor(option)
        let isCorrect = vm.lastCorrect == true
        if isCorrect {
            combo.markCorrect()
        } else {
            combo.markWrong()
        }
        vm.applyResult(correct: isCorrect, combo: combo)
    }

    // MARK: - Helpers

    var timerBarColor: Color {
        let fraction = vm.timeRemaining / vm.totalDuration
        if fraction > 0.5 { return .green }
        if fraction > 0.25 { return .orange }
        return .red
    }
}

// MARK: - AnswerButton

struct AnswerButton: View {
    let option: ColorOption
    let lastTappedId: UUID?
    let lastWrongId: UUID?
    let lastCorrect: Bool?
    let onTap: () -> Void

    @State private var bouncing = false
    @State private var flashing = false
    @State private var dimming = false

    private var wasTapped: Bool { lastTappedId == option.id }
    private var wasWrong: Bool { lastWrongId == option.id }

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
            bouncing = true
            flashing = true
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                bouncing = false
                flashing = false
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

// The zenMode state is stored locally in the view so we need a wrapper for
// the `playingView` that knows about it. We use a computed var here to access it.
private extension ColorGameView {
    var zenMode: Bool {
        // Access the @State binding — this is evaluated at call site where @State is visible
        false
    }
}

#Preview {
    NavigationStack { ColorGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
