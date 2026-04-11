import SwiftUI
import SwiftData

// Stop Signal (Brake Test): Tap the circle on GO trials. Don't tap on STOP trials (red border).
// 30 total trials, roughly 22–23 GO + 7–8 STOP.

// MARK: - ViewModel

@MainActor
class StopSignalViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }
    enum TrialPhase { case blank, go, stop, feedback }

    @Published var gameState: GameState = .idle
    @Published var trialPhase: TrialPhase = .blank
    @Published var showStopBorder: Bool = false
    @Published var feedbackIcon: String? = nil   // "checkmark.circle.fill", "xmark.circle.fill"
    @Published var feedbackColor: Color = .green
    @Published var trialsCompleted: Int = 0
    @Published var correctCount: Int = 0
    @Published var totalTrials: Int = 30
    @Published var showNewBest = false
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil
    @Published var finalAccuracy: Int = 0
    @Published var finalBrainScore: Int = 0

    var onGameOver: ((Int) -> Void)?  // passes accuracy %

    private var difficulty: Difficulty = .medium
    private var currentIsStop: Bool = false
    private var playerTapped: Bool = false
    private var trialTask: Task<Void, Never>?

    // Stop signal delay in ms
    private var stopDelayMs: Int {
        switch difficulty {
        case .easy:   return 250
        case .medium: return 200
        case .hard:   return 150
        }
    }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        trialsCompleted = 0
        correctCount = 0
        feedbackIcon = nil
        gameState = .playing
        runNextTrial()
    }

    func playerTap() {
        guard gameState == .playing, trialPhase == .go || trialPhase == .stop else { return }
        playerTapped = true
    }

    private func runNextTrial() {
        trialTask?.cancel()
        trialTask = Task {
            // Blank interval
            trialPhase = .blank
            showStopBorder = false
            feedbackIcon = nil
            playerTapped = false
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            // 25% chance of STOP trial
            currentIsStop = Int.random(in: 0..<4) == 0
            trialPhase = .go
            let startTime = Date()

            // For stop trials: show stop border after delay
            if currentIsStop {
                try? await Task.sleep(for: .milliseconds(stopDelayMs))
                guard !Task.isCancelled else { return }
                if !playerTapped {
                    showStopBorder = true
                    trialPhase = .stop
                    Haptics.light()
                }
            }

            // Wait for remainder of 1200ms response window
            let elapsed = Int(-startTime.timeIntervalSinceNow * 1000)
            let remaining = max(0, 1200 - elapsed)
            try? await Task.sleep(for: .milliseconds(remaining))
            guard !Task.isCancelled else { return }

            // Evaluate result
            evaluateTrial()

            // Feedback duration
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            trialsCompleted += 1
            if trialsCompleted >= totalTrials {
                endGame()
            } else {
                runNextTrial()
            }
        }
    }

    private func evaluateTrial() {
        trialPhase = .feedback
        showStopBorder = false

        if currentIsStop {
            if playerTapped {
                // False alarm — tapped on stop
                feedbackIcon = "xmark.circle.fill"
                feedbackColor = .red
                Haptics.error()
            } else {
                // Correct inhibition
                feedbackIcon = "checkmark.circle.fill"
                feedbackColor = .green
                correctCount += 1
                Haptics.light()
            }
        } else {
            if playerTapped {
                // Correct go
                feedbackIcon = "checkmark.circle.fill"
                feedbackColor = .green
                correctCount += 1
                Haptics.light()
            } else {
                // Miss — didn't tap on go trial
                feedbackIcon = "xmark.circle.fill"
                feedbackColor = .orange
                Haptics.error()
            }
        }
    }

    private func endGame() {
        trialTask?.cancel()
        trialPhase = .blank
        feedbackIcon = nil
        let accuracy = Int(Double(correctCount) / Double(totalTrials) * 100)
        finalAccuracy = accuracy
        finalBrainScore = max(70, min(145, accuracy + 18))
        onGameOver?(accuracy)
        gameState = .gameOver
    }
}

// MARK: - View

struct StopSignalGameView: View {
    @StateObject private var vm = StopSignalViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("stopSignalDifficulty") private var difficulty: Difficulty = .medium

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
        .navigationTitle("Brake Test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { accuracy in
                let isNewBest = accuracy > stats.stopSignalBestAccuracy
                let session = GameSession(
                    gameType: "stopsignal",
                    rawScore: accuracy,
                    brainScore: max(70, min(145, accuracy + 18)),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordStopSignalGame(accuracy: accuracy)
                let newAchievements = checkAndUnlock(stats: stats)
                if isNewBest && accuracy > 0 {
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
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)
                Text("Brake Test")
                    .font(.largeTitle.bold())
                Text("Tap the circle when it appears.\nBut if a red border flashes — STOP!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.stopSignalBestAccuracy > 0 {
                    Label("Best: \(stats.stopSignalBestAccuracy)% accuracy", systemImage: "trophy.fill")
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
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 20) {
            HStack {
                StatBadge(label: "Trial", value: "\(vm.trialsCompleted + 1)/\(vm.totalTrials)", color: .red)
                Spacer()
                StatBadge(label: "Correct", value: "\(vm.correctCount)", color: .green)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.stopSignalBestAccuracy)%", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.red)
                        .frame(width: geo.size.width * CGFloat(vm.trialsCompleted) / CGFloat(vm.totalTrials))
                        .animation(.linear(duration: 0.3), value: vm.trialsCompleted)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            Spacer()

            ZStack {
                // Main circle (only visible during go/stop)
                if vm.trialPhase == .go || vm.trialPhase == .stop {
                    Button {
                        vm.playerTap()
                    } label: {
                        Circle()
                            .fill(Color.red.opacity(0.85))
                            .frame(width: 140, height: 140)
                            .overlay(
                                Circle()
                                    .stroke(vm.showStopBorder ? Color.red : Color.clear, lineWidth: 8)
                                    .scaleEffect(vm.showStopBorder ? 1.12 : 1.0)
                                    .animation(.easeOut(duration: 0.1), value: vm.showStopBorder)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                // Feedback icon
                if let icon = vm.feedbackIcon {
                    Image(systemName: icon)
                        .font(.system(size: 64))
                        .foregroundStyle(vm.feedbackColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: vm.trialPhase)
            .animation(.easeInOut(duration: 0.15), value: vm.feedbackIcon)
            .frame(height: 180)

            Text(instructionText)
                .font(.headline)
                .foregroundStyle(.secondary)
                .animation(nil, value: vm.trialPhase)

            Spacer()
        }
    }

    var instructionText: String {
        switch vm.trialPhase {
        case .blank:    return "Get ready..."
        case .go:       return "TAP!"
        case .stop:     return "STOP!"
        case .feedback: return ""
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)

                Text("Test Complete!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Accuracy",     value: "\(vm.finalAccuracy)%",    color: .red)
                    resultRow("Correct",      value: "\(vm.correctCount)/\(vm.totalTrials)", color: .green)
                    Divider()
                    resultRow("Brain Score",  value: "\(vm.finalBrainScore)",   color: .indigo)
                    resultRow("All-Time Best", value: "\(stats.stopSignalBestAccuracy)% accuracy", color: .secondary)
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.finalAccuracy > 0 && vm.finalAccuracy == stats.stopSignalBestAccuracy {
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
                gameName: "Brake Test",
                gameIcon: "stop.circle.fill",
                gameColor: .red,
                primaryValue: "\(vm.finalAccuracy)",
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
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
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
    NavigationStack { StopSignalGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
