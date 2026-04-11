import SwiftUI
import SwiftData

// MARK: - Number Rush (was Math Blitz)
// Answer arithmetic and real-world scenario problems as fast as possible.

// MARK: - Problem Model

private struct MathProblem {
    let questionText: String
    let correctAnswer: Int
    let choices: [Int]          // 4 options (empty when useNumberPad=true)
    let isBoss: Bool
}

// MARK: - Scenario Templates

private enum ScenarioTemplate: CaseIterable {
    case tipping, shopping, splitting, time

    func generate() -> (question: String, answer: Int) {
        switch self {
        case .tipping:
            let bill = Int.random(in: 2...19) * 5   // $10–$95 in $5 steps
            let tip  = bill / 5
            return ("Bill is $\(bill). 20% tip?", tip)

        case .shopping:
            let price = Int.random(in: 2...20) * 5  // $10–$100 in $5 steps
            let pay   = Int((Double(price) * 0.7).rounded())
            return ("$\(price) item at 30% off. You pay?", pay)

        case .splitting:
            let people = Int.random(in: 2...6)
            let total  = people * Int.random(in: 5...25)  // divisible
            let share  = total / people
            return ("$\(total) dinner split \(people) ways?", share)

        case .time:
            let startH = Int.random(in: 8...16)
            let startM = [0, 15, 30, 45].randomElement()!
            let travel = Int.random(in: 1...11) * 15       // 15–165 min
            let answer = travel
            let endTotalM = startH * 60 + startM + travel
            let endH = (endTotalM / 60) % 24
            let endM = endTotalM % 60
            return (
                String(format: "Leave %d:%02d. Arrive %d:%02d later. Minutes traveled?",
                       startH, startM, endH, endM),
                answer
            )
        }
    }
}

// MARK: - ViewModel

@MainActor
class MathBlitzViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }

    @Published var gameState: GameState = .idle
    @Published var currentProblem: MathProblem = MathProblem(questionText: "", correctAnswer: 0, choices: [], isBoss: false)
    @Published var typedAnswer: String = ""           // number-pad input
    @Published var correctCount: Int = 0
    @Published var wrongCount: Int = 0
    @Published var totalScore: Int = 0
    @Published var timeRemaining: Double = 60
    @Published var timerSeconds: Double = 60
    @Published var lastCorrect: Bool? = nil           // flash feedback
    @Published var dimmedChoiceIndex: Int? = nil      // wrong choice index
    @Published var bouncedChoiceIndex: Int? = nil     // correct choice index
    @Published var showNumberPad: Bool = false

    // Power-ups
    @Published var showTimeFreezeButton: Bool = false
    @Published var timeFrozen: Bool = false
    @Published var showDoublePointsBanner: Bool = false
    @Published var showBossBanner: Bool = false

    // End of game
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0
    @Published var bestMultiplier: Double = 1.0

    let combo = ComboTracker()
    var onGameOver: ((Int) -> Void)?

    private var difficulty: Difficulty = .medium
    private var timer: Timer?
    private var flashTask: Task<Void, Never>?
    private var timeFreezeTask: Task<Void, Never>?
    private var powerUpTask: Task<Void, Never>?
    private var totalAnswered: Int = 0     // correct + wrong, for boss timing
    private var consecutiveCorrect: Int = 0   // running tally for power-ups

    // Elo-driven params (set at game start)
    private var eloMaxNumber: Int = 20
    private var eloIncludeMultiply: Bool = false
    private var eloUseScenarios: Bool = false

    var accuracy: Int {
        let total = correctCount + wrongCount
        guard total > 0 else { return 100 }
        return Int(Double(correctCount) / Double(total) * 100)
    }

    // MARK: - Start / Stop

    func startGame(difficulty: Difficulty, mathElo: Double) {
        self.difficulty = difficulty
        let params = EloSystem.mathParams(mathElo)
        eloMaxNumber = params.maxNumber
        eloIncludeMultiply = params.includeMultiply
        eloUseScenarios = params.useScenarios
        showNumberPad = params.useNumberPad
        timerSeconds = params.timerSeconds
        timeRemaining = params.timerSeconds

        correctCount = 0
        wrongCount = 0
        totalScore = 0
        totalAnswered = 0
        consecutiveCorrect = 0
        bestMultiplier = 1.0
        typedAnswer = ""
        lastCorrect = nil
        dimmedChoiceIndex = nil
        bouncedChoiceIndex = nil
        showTimeFreezeButton = false
        timeFrozen = false
        showDoublePointsBanner = false
        showBossBanner = false
        combo.reset()
        gameState = .playing
        nextProblem()
        startTimer()
    }

    // MARK: - Answer handling

    func selectChoice(_ index: Int) {
        guard gameState == .playing else { return }
        let choice = currentProblem.choices[index]
        if choice == currentProblem.correctAnswer {
            bouncedChoiceIndex = index
            handleCorrect()
        } else {
            dimmedChoiceIndex = index
            handleWrong()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            bouncedChoiceIndex = nil
            dimmedChoiceIndex = nil
            nextProblem()
            lastCorrect = nil
        }
    }

    func submitNumberPad() {
        guard gameState == .playing, let val = Int(typedAnswer) else {
            typedAnswer = ""
            return
        }
        if val == currentProblem.correctAnswer {
            handleCorrect()
        } else {
            handleWrong()
        }
        typedAnswer = ""
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            nextProblem()
            lastCorrect = nil
        }
    }

    func numberPadTap(_ digit: String) {
        guard typedAnswer.count < 6 else { return }
        typedAnswer += digit
    }

    func numberPadBackspace() {
        if !typedAnswer.isEmpty { typedAnswer.removeLast() }
    }

    // MARK: - Time Freeze power-up

    func activateTimeFreeze() {
        guard showTimeFreezeButton else { return }
        showTimeFreezeButton = false
        timeFrozen = true
        SoundEngine.shared.playTick()
        Haptics.success()
        timeFreezeTask?.cancel()
        timeFreezeTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            timeFrozen = false
        }
    }

    // MARK: - Private helpers

    private func handleCorrect() {
        flashTask?.cancel()
        combo.markCorrect()
        if combo.multiplier > bestMultiplier { bestMultiplier = combo.multiplier }
        consecutiveCorrect += 1

        var base = currentProblem.isBoss ? 50 : 10
        // 10-in-a-row double points ON TOP of multiplier
        if consecutiveCorrect % 10 == 0 { base *= 2 }
        let points = combo.apply(base)
        totalScore += points
        correctCount += 1
        totalAnswered += 1
        lastCorrect = true
        SoundEngine.shared.playCorrect(streak: combo.streak)
        Haptics.medium()
        checkPowerUps()
    }

    private func handleWrong() {
        combo.markWrong()
        consecutiveCorrect = 0
        wrongCount += 1
        totalAnswered += 1
        lastCorrect = false
        SoundEngine.shared.playWrong()
        Haptics.error()
    }

    private func checkPowerUps() {
        // 5-in-a-row: show time freeze button for 10s
        if combo.streak == 5 {
            showTimeFreezeButton = true
            powerUpTask?.cancel()
            powerUpTask = Task {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                showTimeFreezeButton = false
            }
        }
        // 10-in-a-row: double points banner
        if combo.streak == 10 {
            showDoublePointsBanner = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                showDoublePointsBanner = false
            }
        }
    }

    private func nextProblem() {
        showBossBanner = false
        // Boss every 15 correct answers
        let isBoss = correctCount > 0 && correctCount % 15 == 0
        if isBoss { showBossBanner = true }

        let problem: MathProblem
        if eloUseScenarios && !isBoss && Bool.random() {
            problem = makeScenarioProblem(isBoss: false)
        } else if isBoss {
            problem = makeBossProblem()
        } else {
            problem = makeEquationProblem(isBoss: false)
        }
        currentProblem = problem
        typedAnswer = ""
    }

    private func makeEquationProblem(isBoss: Bool) -> MathProblem {
        let (lhs, rhs, op, answer) = generateEquation()
        let text = "\(lhs) \(op) \(rhs) = ?"
        let choices = showNumberPad ? [] : makeChoices(correct: answer)
        return MathProblem(questionText: text, correctAnswer: answer, choices: choices, isBoss: isBoss)
    }

    private func makeScenarioProblem(isBoss: Bool) -> MathProblem {
        let template = ScenarioTemplate.allCases.randomElement()!
        let (q, answer) = template.generate()
        let choices = showNumberPad ? [] : makeChoices(correct: answer)
        return MathProblem(questionText: q, correctAnswer: answer, choices: choices, isBoss: isBoss)
    }

    private func makeBossProblem() -> MathProblem {
        // Multi-step: e.g. "(A + B) × C"
        let a = Int.random(in: 2...12)
        let b = Int.random(in: 2...12)
        let c = Int.random(in: 2...5)
        let answer = (a + b) * c
        let text = "(\(a) + \(b)) × \(c) = ?"
        let choices = showNumberPad ? [] : makeChoices(correct: answer)
        return MathProblem(questionText: text, correctAnswer: answer, choices: choices, isBoss: true)
    }

    private func generateEquation() -> (Int, Int, String, Int) {
        let max = eloMaxNumber
        let useMultiply = eloIncludeMultiply && Bool.random()

        if useMultiply {
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...12)
            return (a, b, "×", a * b)
        }

        let useSub = Bool.random()
        if useSub {
            let a = Int.random(in: max / 2 ... max)
            let b = Int.random(in: 1 ... max / 2)
            return (a, b, "−", a - b)
        } else {
            let a = Int.random(in: 1...max)
            let b = Int.random(in: 1...max)
            return (a, b, "+", a + b)
        }
    }

    private func makeChoices(correct: Int) -> [Int] {
        var set = Set<Int>([correct])
        var attempts = 0
        while set.count < 4 && attempts < 200 {
            attempts += 1
            let offset = Int.random(in: -15...15)
            let candidate = correct + offset
            if candidate != correct && candidate >= 0 { set.insert(candidate) }
        }
        return set.shuffled()
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.gameState == .playing else { return }
                if self.timeFrozen { return }
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
        timeFreezeTask?.cancel()
        powerUpTask?.cancel()
        finalScore = totalScore
        finalBrainScore = PlayerStats.speedBrainScore(correct: correctCount)
        onGameOver?(correctCount)
        gameState = .gameOver
    }
}

// MARK: - View

struct MathBlitzGameView: View {
    @StateObject private var vm = MathBlitzViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("speedDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats(); modelContext.insert(s); return s
    }

    var body: some View {
        ZStack {
            mainContent
        }
        .navigationTitle("Number Rush")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correctCount in
                let brainScore = PlayerStats.speedBrainScore(correct: correctCount)
                let prevBrain  = stats.speedBrainScore
                let session = GameSession(
                    gameType: "speed",
                    rawScore: vm.totalScore,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordSpeedGame(score: correctCount)
                stats.mathEloRating = EloSystem.updated(stats.mathEloRating, correct: correctCount >= 15)
                _ = prevBrain   // suppress warning
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
                Image(systemName: "function")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                Text("Number Rush")
                    .font(.largeTitle.bold())
                Text("Answer as many math problems\nas you can before time runs out.")
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

            Button {
                vm.startGame(difficulty: difficulty, mathElo: stats.mathEloRating)
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
        VStack(spacing: 0) {
            // Top bar: stats + multiplier badge
            HStack {
                StatBadge(label: "Score", value: "\(vm.totalScore)", color: .green)
                Spacer()
                StatBadge(label: "Correct", value: "\(vm.correctCount)", color: .teal)
                Spacer()
                MultiplierBadgeView(combo: vm.combo, color: .green)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Timer bar
            timerBar
                .padding(.bottom, 8)

            // Power-up banners
            if vm.showTimeFreezeButton {
                Button(action: vm.activateTimeFreeze) {
                    Label("TIME FREEZE ⏸", systemImage: "pause.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.blue.gradient, in: Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            }

            if vm.showDoublePointsBanner {
                Text("DOUBLE POINTS!")
                    .font(.title3.bold())
                    .foregroundStyle(.yellow)
                    .padding(.vertical, 4)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Question card
            let isBoss = vm.currentProblem.isBoss
            VStack(spacing: 8) {
                if isBoss {
                    Text("⚡ BOSS PROBLEM!")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
                Text(vm.currentProblem.questionText)
                    .font(.system(size: isBoss ? 34 : 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(
                        isBoss
                        ? AnyShapeStyle(Color.black.opacity(0.85))
                        : AnyShapeStyle(Color(.secondarySystemBackground))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        isBoss
                        ? RoundedRectangle(cornerRadius: 16).stroke(Color.yellow, lineWidth: 2)
                        : nil
                    )
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.15), value: vm.currentProblem.questionText)

            // Feedback indicator
            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, 8)
            } else {
                Color.clear.frame(height: 36).padding(.top, 8)
            }

            Spacer()

            // Answers: number pad or choice grid
            if vm.showNumberPad {
                numberPadSection
            } else {
                choiceGrid
            }
        }
        .animation(.easeInOut(duration: 0.15), value: vm.lastCorrect)
        .animation(.spring(response: 0.3), value: vm.showTimeFreezeButton)
        .animation(.spring(response: 0.3), value: vm.showDoublePointsBanner)
    }

    // MARK: - Timer Bar

    var timerBar: some View {
        let fraction = vm.timerSeconds > 0 ? vm.timeRemaining / vm.timerSeconds : 1.0
        let color: Color = fraction > 0.5 ? .green : (fraction > 0.25 ? .orange : .red)
        let isPulsing = fraction < 0.1

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(fraction))
                    .animation(.linear(duration: 0.1), value: vm.timeRemaining)
                    .modifier(PulsingModifier(active: isPulsing, rate: fraction < 0.05 ? 3.0 : 2.0))
            }
        }
        .frame(height: 10)
        .padding(.horizontal)
        .overlay(alignment: .trailing) {
            Text(String(format: "%.0fs", max(0, vm.timeRemaining)))
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(color)
                .padding(.trailing, 20)
        }
    }

    // MARK: - Multiple Choice Grid

    var choiceGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(vm.currentProblem.choices.indices, id: \.self) { idx in
                let choice = vm.currentProblem.choices[idx]
                let isCorrectBounce = vm.bouncedChoiceIndex == idx
                let isWrongDim = vm.dimmedChoiceIndex == idx

                Button {
                    vm.selectChoice(idx)
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
                .juiceBounce(trigger: isCorrectBounce)
                .juiceFlash(trigger: isCorrectBounce, color: .green)
                .juiceDim(trigger: isWrongDim)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    // MARK: - Number Pad

    var numberPadSection: some View {
        VStack(spacing: 12) {
            // Display field
            HStack {
                Text(vm.typedAnswer.isEmpty ? "—" : vm.typedAnswer)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(vm.typedAnswer.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .juiceBounce(trigger: vm.lastCorrect == true)
                    .juiceFlash(trigger: vm.lastCorrect == true, color: .green)
            }
            .padding(.horizontal)

            // Digit buttons
            let rows: [[String]] = [
                ["7","8","9"],
                ["4","5","6"],
                ["1","2","3"],
                ["⌫","0","✓"]
            ]
            VStack(spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                if key == "⌫" {
                                    vm.numberPadBackspace()
                                } else if key == "✓" {
                                    vm.submitNumberPad()
                                } else {
                                    vm.numberPadTap(key)
                                }
                            } label: {
                                Text(key)
                                    .font(.title2.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        key == "✓"
                                        ? Color.green.opacity(0.85)
                                        : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .foregroundStyle(key == "✓" ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        let brainScore = PlayerStats.speedBrainScore(correct: vm.correctCount)
        let result = GameResult(
            gameTitle: "Number Rush",
            primaryScore: vm.finalScore,
            primaryLabel: "pts",
            brainScore: brainScore,
            previousBrainScore: stats.speedBrainScore,
            isNewBest: vm.totalScore > 0 && vm.totalScore >= stats.speedBestScore,
            multiplierBreakdown: vm.bestMultiplier > 1.0
                ? GameResult.MultiplierBreakdown(
                    baseScore: vm.correctCount * 10,
                    bestMultiplier: vm.bestMultiplier,
                    finalScore: vm.finalScore
                  )
                : nil,
            percentileText: PlayerStats.percentileLabel(for: brainScore),
            accentColor: .green,
            share: GameResult.ShareConfig(
                gameName: "Number Rush",
                icon: "function",
                color: .green,
                primaryValue: "\(vm.finalScore)",
                primaryLabel: "pts",
                secondaryLine: "\(vm.correctCount) correct · Brain Score \(brainScore)"
            )
        )

        return GameOverView(result: result) {
            vm.startGame(difficulty: difficulty, mathElo: stats.mathEloRating)
        }
    }
}

// MARK: - PulsingModifier

private struct PulsingModifier: ViewModifier {
    let active: Bool
    let rate: Double   // Hz
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear { startPulse() }
            .onChange(of: active) { _, _ in startPulse() }
            .onChange(of: rate)   { _, _ in startPulse() }
    }

    private func startPulse() {
        guard active else { scale = 1.0; return }
        withAnimation(
            .easeInOut(duration: 1.0 / (rate * 2.0))
            .repeatForever(autoreverses: true)
        ) {
            scale = 1.04
        }
    }
}

#Preview {
    NavigationStack { MathBlitzGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
