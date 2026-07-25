import SwiftUI
import SwiftData

// Switchboard: task-switching game. A card appears in the top or bottom zone —
// the top zone asks "is it BLUE?", the bottom zone asks "is it ROUND?".
// Judge each card under its zone's rule for 60 seconds.

// MARK: - Trial model

enum SwitchZone {
    case top, bottom

    var other: SwitchZone { self == .top ? .bottom : .top }
    var displayName: String { self == .top ? "top" : "bottom" }
}

enum SwitchShape: CaseIterable {
    case circle, square, triangle, hexagon

    var symbolName: String {
        switch self {
        case .circle: "circle.fill"; case .square: "square.fill"
        case .triangle: "triangle.fill"; case .hexagon: "hexagon.fill"
        }
    }

    var displayName: String {
        switch self {
        case .circle: "circle"; case .square: "square"
        case .triangle: "triangle"; case .hexagon: "hexagon"
        }
    }

    var isRound: Bool { self == .circle }
}

enum SwitchCardColor: CaseIterable {
    case blue, red, green, orange

    var color: Color {
        switch self {
        case .blue: .blue; case .red: .red; case .green: .green; case .orange: .orange
        }
    }

    var displayName: String {
        switch self {
        case .blue: "blue"; case .red: "red"; case .green: "green"; case .orange: "orange"
        }
    }

    var isBlue: Bool { self == .blue }
}

struct SwitchTrial: Equatable {
    let zone: SwitchZone
    let shape: SwitchShape
    let cardColor: SwitchCardColor

    // Top zone judges color, bottom zone judges shape.
    var correctAnswer: Bool {
        zone == .top ? cardColor.isBlue : shape.isRound
    }
}

// MARK: - View model

@MainActor
final class SwitchboardViewModel: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var trial: SwitchTrial? = nil
    @Published var score: Int = 0           // points (with combo multiplier)
    @Published var correctCount: Int = 0    // recorded metric
    @Published var wrongCount: Int = 0
    @Published var streak: Int = 0
    @Published var bestCombo: Int = 0
    @Published var timeRemaining: Double = 60
    @Published var lastCorrect: Bool? = nil // nil=unanswered, true/false for flash
    @Published var isPaused = false
    @Published var isResuming = false       // fresh countdown running after pause
    @Published var showNewBest = false
    @Published var wasNewBest = false       // computed in onGameOver BEFORE stats update
    @Published var finalScore: Int = 0
    @Published var finalCorrect: Int = 0
    @Published var finalBrainScore: Int = 0
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    enum GameState { case idle, countdown, playing, gameOver }

    var onGameOver: ((Int) -> Void)?  // passes correct count

    private var timer: Timer?
    private var flashTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var difficulty: Difficulty = .medium
    private var lastZone: SwitchZone? = nil
    private var sameZoneRun = 0

    // 4-in-a-row doubles points, 8-in-a-row triples (cap).
    var multiplier: Int {
        if streak >= 8 { return 3 }
        if streak >= 4 { return 2 }
        return 1
    }

    // Per-trial response deadline; nil = untimed.
    private var trialDeadline: Double? {
        switch difficulty {
        case .easy:   nil
        case .medium: 2.0
        case .hard:   1.2
        }
    }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        score = 0; correctCount = 0; wrongCount = 0
        streak = 0; bestCombo = 0
        timeRemaining = 60
        lastCorrect = nil; trial = nil
        isPaused = false; isResuming = false; wasNewBest = false
        lastZone = nil; sameZoneRun = 0
        gameState = .countdown
    }

    // Called by the countdown overlay once 3-2-1 finishes.
    func beginPlay() {
        guard gameState == .countdown else { return }
        gameState = .playing
        nextTrial()
        startTimer()
    }

    func answer(_ saidYes: Bool) {
        guard gameState == .playing, !isPaused, !isResuming,
              lastCorrect == nil, let trial else { return }
        deadlineTask?.cancel()
        if saidYes == trial.correctAnswer {
            correctCount += 1
            streak += 1
            bestCombo = max(bestCombo, streak)
            score += 10 * multiplier
            lastCorrect = true
            Haptics.medium()
        } else {
            registerMiss()
        }
        scheduleFlashThenNext()
    }

    private func registerMiss() {
        wrongCount += 1
        streak = 0
        lastCorrect = false
        Haptics.error()
    }

    private func timedOut() {
        guard gameState == .playing, !isPaused, !isResuming, lastCorrect == nil else { return }
        registerMiss()
        scheduleFlashThenNext()
    }

    private func scheduleFlashThenNext() {
        flashTask?.cancel()
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            lastCorrect = nil
            nextTrial()
        }
    }

    private func nextTrial() {
        // 50/50 zones, but never more than 3 same-zone trials in a row.
        var zone: SwitchZone = Bool.random() ? .top : .bottom
        if let last = lastZone, sameZoneRun >= 3, zone == last {
            zone = last.other
        }
        sameZoneRun = (zone == lastZone) ? sameZoneRun + 1 : 1
        lastZone = zone

        let shape = SwitchShape.allCases.randomElement() ?? .circle
        let cardColor = SwitchCardColor.allCases.randomElement() ?? .blue
        trial = SwitchTrial(zone: zone, shape: shape, cardColor: cardColor)
        startDeadline()
    }

    private func startDeadline() {
        deadlineTask?.cancel()
        guard let limit = trialDeadline else { return }
        deadlineTask = Task {
            try? await Task.sleep(for: .seconds(limit))
            guard !Task.isCancelled else { return }
            self.timedOut()
        }
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

    // MARK: Pause / resume

    func pause() {
        guard gameState == .playing, !isPaused, !isResuming else { return }
        timer?.invalidate()
        timer = nil
        deadlineTask?.cancel()
        flashTask?.cancel()
        isPaused = true
    }

    func requestResume() {
        guard isPaused else { return }
        isPaused = false
        isResuming = true  // view runs a fresh countdown over the blurred field
    }

    func resumePlay() {
        guard gameState == .playing, isResuming else { return }
        isResuming = false
        startTimer()
        if lastCorrect != nil {
            // Paused mid-flash — clear it and move on.
            lastCorrect = nil
            nextTrial()
        } else {
            startDeadline()  // fresh deadline for the interrupted trial
        }
    }

    private func endGame() {
        timer?.invalidate(); timer = nil
        deadlineTask?.cancel(); deadlineTask = nil
        flashTask?.cancel(); flashTask = nil
        finalScore = score
        finalCorrect = correctCount
        finalBrainScore = PlayerStats.switchBrainScore(correct: correctCount)
        onGameOver?(correctCount)
        gameState = .gameOver
    }

    /// Tear everything down without recording — used by Quit and .onDisappear.
    func abandon() {
        timer?.invalidate(); timer = nil
        deadlineTask?.cancel(); deadlineTask = nil
        flashTask?.cancel(); flashTask = nil
        isPaused = false; isResuming = false
        lastCorrect = nil; trial = nil
        gameState = .idle
    }
}

// MARK: - View

struct SwitchboardGameView: View {
    @StateObject private var vm = SwitchboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("switchDifficulty") private var difficulty: Difficulty = .medium

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
        .navigationTitle("Switchboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correct in
                let isNewBest = correct > stats.switchBestScore
                vm.wasNewBest = isNewBest && correct > 0
                let session = GameSession(
                    gameType: "switch",
                    rawScore: correct,
                    brainScore: PlayerStats.switchBrainScore(correct: correct),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordSwitchGame(score: correct)
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
        case .idle:
            idleView
        case .countdown:
            playView
                .overlay { CountdownOverlay { vm.beginPlay() } }
        case .playing:
            ZStack {
                playView
                    .blur(radius: (vm.isPaused || vm.isResuming) ? 8 : 0)
                if vm.isPaused {
                    PauseOverlay(
                        onResume: { vm.requestResume() },
                        onQuit: { vm.abandon() }
                    )
                } else if vm.isResuming {
                    CountdownOverlay { vm.resumePlay() }
                }
            }
        case .gameOver:
            gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 72))
                    .foregroundStyle(.mint)
                Text("Switchboard")
                    .font(.largeTitle.bold())
                Text("Top zone: is the card blue? Bottom zone: is it round?\nKeep switching rules for 60 seconds.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.switchBestScore > 0 {
                    Label("Record: \(stats.switchBestScore) correct", systemImage: "trophy.fill")
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
                    .background(Color.mint, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 16) {
            // Top stats bar + pause
            HStack(spacing: 12) {
                StatBadge(label: "Score", value: "\(vm.score)", color: .mint)
                Spacer()
                StatBadge(label: "Correct", value: "\(vm.correctCount)", color: .green)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.switchBestScore)", color: .secondary)
                Spacer()
                Button { vm.pause() } label: {
                    Image(systemName: "pause.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Pause game")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            timerBar

            // Combo state (subtle)
            if vm.multiplier > 1 {
                Label("Combo ×\(vm.multiplier)", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            } else {
                Color.clear.frame(height: 16)
            }

            Spacer(minLength: 8)

            // Rule zones + card
            VStack(spacing: 12) {
                zoneView(.top)
                zoneView(.bottom)
            }
            .padding(.horizontal)

            // Answer feedback flash
            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 32)
            }

            Spacer(minLength: 8)

            // YES / NO
            HStack(spacing: 12) {
                answerButton(title: "YES", color: .green, value: true)
                answerButton(title: "NO", color: .red, value: false)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.lastCorrect)
        .animation(.easeInOut(duration: 0.2), value: vm.multiplier)
    }

    func zoneView(_ zone: SwitchZone) -> some View {
        let isActive = vm.trial?.zone == zone
        return VStack(spacing: 8) {
            Text(zone == .top ? "TOP — IS IT BLUE?" : "BOTTOM — IS IT ROUND?")
                .font(.caption.bold())
                .foregroundStyle(isActive ? Color.mint : Color.secondary)
            ZStack {
                if let trial = vm.trial, trial.zone == zone {
                    cardView(trial)
                }
            }
            .frame(height: 84)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isActive ? Color.mint : Color.clear, lineWidth: 2)
        )
    }

    func cardView(_ trial: SwitchTrial) -> some View {
        Image(systemName: trial.shape.symbolName)
            .font(.system(size: 52))
            .foregroundStyle(trial.cardColor.color)
            .frame(width: 92, height: 80)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(
                "\(trial.cardColor.displayName.capitalized) \(trial.shape.displayName) in \(trial.zone.displayName) zone — judge the \(trial.zone == .top ? "color" : "shape")"
            )
    }

    func answerButton(title: String, color: Color, value: Bool) -> some View {
        Button { vm.answer(value) } label: {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value ? "Yes" : "No")
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
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 56))
                    .foregroundStyle(.mint)

                Text("Time's Up!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    ResultRow(label: "Score",           value: "\(vm.finalScore)", color: .mint)
                    ResultRow(label: "Correct Answers", value: "\(vm.finalCorrect)", color: .green)
                    ResultRow(label: "Wrong Answers",   value: "\(vm.wrongCount)", color: .red)
                    ResultRow(label: "Best Combo",      value: "\(vm.bestCombo)", color: .orange)
                    Divider()
                    ResultRow(label: "Brain Score",     value: "\(vm.finalBrainScore)", color: .indigo)
                    ResultRow(label: "All-Time Best",   value: "\(stats.switchBestScore) correct", color: .secondary)
                    Divider()
                    ResultRow(label: "vs. Average",
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
                gameName: "Switchboard", gameIcon: "arrow.triangle.swap", gameColor: .mint,
                primaryValue: "\(vm.finalCorrect)", primaryLabel: "correct",
                secondaryLine: "Brain Score: \(vm.finalBrainScore)"
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button { vm.startGame(difficulty: difficulty) } label: {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mint, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    NavigationStack { SwitchboardGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
