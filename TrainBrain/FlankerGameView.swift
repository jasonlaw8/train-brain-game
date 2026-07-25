import SwiftUI
import SwiftData

// Flanker Task: five arrows displayed in a row. Tap LEFT or RIGHT based on the CENTER arrow only.
// Flanking arrows may conflict (incongruent) or agree (congruent) with the center.
// 60-second timer, score = number of correct taps.

// MARK: - ViewModel

@MainActor
class FlankerGameViewModel: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var timeRemaining: Double = 60
    @Published var score: Int = 0           // correct answers
    @Published var wrongCount: Int = 0
    @Published var lastCorrect: Bool? = nil  // nil=unanswered, true/false for brief flash
    @Published var showNewBest = false
    @Published var wasNewBest = false   // set before stats update, so ties do not count
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0

    // Current trial
    @Published var arrows: [Arrow] = []
    @Published var centerDirection: Direction = .right

    enum Direction { case left, right }

    struct Arrow {
        let direction: Direction
        let isCenter: Bool
    }

    enum GameState { case idle, playing, gameOver }

    // Answering nothing scores 0, not 100 — otherwise idling for 60s
    // recorded a perfect run.
    var accuracy: Int {
        let total = score + wrongCount
        guard total > 0 else { return 0 }
        return score * 100 / total
    }

    var onGameOver: ((Int) -> Void)?  // passes accuracy %

    private var timer: Timer?
    private var difficulty: Difficulty = .medium
    private var flashTask: Task<Void, Never>?

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        score = 0
        wrongCount = 0
        timeRemaining = 60
        lastCorrect = nil
        gameState = .playing
        generateTrial()
        startTimer()
    }

    func answer(_ direction: Direction) {
        guard gameState == .playing else { return }
        flashTask?.cancel()
        if direction == centerDirection {
            score += 1
            lastCorrect = true
            Haptics.medium()
        } else {
            wrongCount += 1
            lastCorrect = false
            Haptics.error()
        }
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            generateTrial()
            lastCorrect = nil
        }
    }

    func generateTrial() {
        // Decide congruency based on difficulty
        let congruentProbability: Double
        switch difficulty {
        case .easy:   congruentProbability = 0.80
        case .medium: congruentProbability = 0.50
        case .hard:   congruentProbability = 0.30
        }
        let isCongruent = Double.random(in: 0..<1) < congruentProbability

        let center: Direction = Bool.random() ? .left : .right
        let flanker: Direction = isCongruent ? center : (center == .left ? .right : .left)

        centerDirection = center
        arrows = [
            Arrow(direction: flanker, isCenter: false),
            Arrow(direction: flanker, isCenter: false),
            Arrow(direction: center,  isCenter: true),
            Arrow(direction: flanker, isCenter: false),
            Arrow(direction: flanker, isCenter: false),
        ]
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
        finalBrainScore = PlayerStats.flankerBrainScore(accuracy: accuracy)
        onGameOver?(accuracy)
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

struct FlankerGameView: View {
    @StateObject private var vm = FlankerGameViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @Query(sort: \GameSession.date, order: .reverse) private var sessions: [GameSession]
    @AppStorage("flankerDifficulty") private var difficulty: Difficulty = .medium

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
        .navigationTitle("Flanker Task")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { accuracy in
                let totalAttempts = vm.finalScore + vm.wrongCount
                let safeAccuracy = totalAttempts > 0 ? vm.finalScore * 100 / totalAttempts : 0
                let isNewBest = safeAccuracy > stats.flankerBestAccuracy && totalAttempts > 0
                vm.wasNewBest = isNewBest
                let session = GameSession(
                    gameType: "flanker",
                    rawScore: vm.finalScore,
                    brainScore: PlayerStats.flankerBrainScore(accuracy: safeAccuracy),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordFlankerGame(accuracy: safeAccuracy)
                let newAchievements = checkAndUnlock(stats: stats)
                if isNewBest {
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
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 72))
                    .foregroundStyle(.teal)

                Text("Flanker Task")
                    .font(.largeTitle.bold())

                Text("Tap the direction of the CENTER arrow\n— ignore the others.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Example trial preview
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        Text(i == 2 ? "→" : "←")
                            .font(.system(size: i == 2 ? 36 : 24))
                            .foregroundStyle(i == 2 ? Color.teal : Color.teal.opacity(0.45))
                    }
                }
                .padding(.vertical, 4)

                if stats.flankerBestAccuracy > 0 {
                    Label("Best: \(stats.flankerBestAccuracy)% accuracy", systemImage: "trophy.fill")
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
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 20) {
            // Stat badges
            HStack {
                StatBadge(label: "Correct",  value: "\(vm.score)",      color: .teal)
                Spacer()
                StatBadge(label: "Accuracy", value: "\(vm.accuracy)%",  color: .cyan)
                Spacer()
                StatBadge(label: "Best",     value: "\(stats.flankerBestAccuracy)%", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            timerBar

            Spacer()

            // Arrow display
            arrowRow
                .animation(nil, value: vm.arrows.map { $0.direction == .left })

            // Feedback flash
            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 32)
            }

            Spacer()

            // Left / Right answer buttons
            HStack(spacing: 12) {
                answerButton(label: "←", direction: .left)
                answerButton(label: "→", direction: .right)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.lastCorrect)
    }

    var arrowRow: some View {
        HStack(spacing: 6) {
            ForEach(vm.arrows.indices, id: \.self) { i in
                let arrow = vm.arrows[i]
                Text(arrow.direction == .left ? "←" : "→")
                    .font(.system(size: arrow.isCenter ? 64 : 40))
                    .foregroundStyle(Color.teal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    func answerButton(label: String, direction: FlankerGameViewModel.Direction) -> some View {
        Button { vm.answer(direction) } label: {
            Text(label)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.teal, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
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
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(.teal)

                Text("Time's Up!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Correct",      value: "\(vm.finalScore)",          color: .teal)
                    resultRow("Wrong",        value: "\(vm.wrongCount)",          color: .red)
                    resultRow("Accuracy",     value: "\(vm.accuracy)%",           color: .cyan)
                    Divider()
                    resultRow("Brain Score",  value: "\(vm.finalBrainScore)",     color: .indigo)
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                    Divider()
                    resultRow("All-Time Best",
                              value: "\(stats.flankerBestAccuracy)% accuracy",   color: .secondary)
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
                gameName: "Flanker",
                gameIcon: "brain.head.profile",
                gameColor: .teal,
                primaryValue: "\(vm.accuracy)",
                primaryLabel: "% accuracy",
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
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 16))
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

// MARK: - Preview

#Preview {
    NavigationStack { FlankerGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
