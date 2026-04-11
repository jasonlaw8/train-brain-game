import SwiftUI
import SwiftData

// Digit Span: Flash digits one at a time. Player reproduces the sequence by tapping digit buttons.

// MARK: - ViewModel

@MainActor
class DigitSpanViewModel: ObservableObject {
    enum GameState { case idle, flashing, input, feedback, gameOver }

    @Published var gameState: GameState = .idle
    @Published var currentLevel: Int = 3       // sequence length
    @Published var lives: Int = 2
    @Published var score: Int = 0             // max level reached
    @Published var flashedDigit: Int? = nil   // nil = blank, Int = showing digit
    @Published var playerInput: [Int] = []
    @Published var feedbackCorrect: Bool? = nil
    @Published var showNewBest = false
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0

    var onGameOver: ((Int) -> Void)?  // passes max level (score)

    private var currentSequence: [Int] = []
    private var flashTask: Task<Void, Never>?
    private var difficulty: Difficulty = .medium

    private var startLevel: Int { difficulty == .easy ? 3 : difficulty == .medium ? 4 : 5 }
    private var showMs: Int     { difficulty == .easy ? 900 : difficulty == .medium ? 700 : 500 }
    private var blankMs: Int    { difficulty == .easy ? 200 : difficulty == .medium ? 150 : 100 }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        currentLevel = startLevel
        lives = 2
        score = 0
        feedbackCorrect = nil
        gameState = .flashing
        startNewRound()
    }

    private func startNewRound() {
        playerInput = []
        currentSequence = generateSequence(length: currentLevel)
        flashSequence()
    }

    private func generateSequence(length: Int) -> [Int] {
        var digits = Array(0...9).shuffled()
        // Ensure no consecutive duplicates (already shuffled so just return first N)
        return Array(digits.prefix(length))
    }

    private func flashSequence() {
        flashTask?.cancel()
        flashTask = Task {
            for digit in currentSequence {
                guard !Task.isCancelled else { return }
                flashedDigit = digit
                Haptics.light()
                try? await Task.sleep(for: .milliseconds(showMs))
                guard !Task.isCancelled else { return }
                flashedDigit = nil
                try? await Task.sleep(for: .milliseconds(blankMs))
            }
            guard !Task.isCancelled else { return }
            gameState = .input
        }
    }

    func tapDigit(_ digit: Int) {
        guard gameState == .input else { return }
        let idx = playerInput.count
        playerInput.append(digit)

        if digit != currentSequence[idx] {
            // Wrong digit
            Haptics.error()
            lives -= 1
            feedbackCorrect = false
            gameState = .feedback
            flashTask?.cancel()
            flashTask = Task {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                feedbackCorrect = nil
                if self.lives <= 0 {
                    self.endGame()
                } else {
                    // Retry same level
                    self.gameState = .flashing
                    self.startNewRound()
                }
            }
        } else if playerInput.count == currentSequence.count {
            // Full sequence correct
            Haptics.success()
            if currentLevel > score { score = currentLevel }
            feedbackCorrect = true
            gameState = .feedback
            flashTask?.cancel()
            flashTask = Task {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                feedbackCorrect = nil
                self.currentLevel += 1
                self.gameState = .flashing
                self.startNewRound()
            }
        }
        // else partial correct input — keep waiting
    }

    private func endGame() {
        flashTask?.cancel()
        finalScore = score
        finalBrainScore = max(70, min(145, 52 + score * 9))
        onGameOver?(score)
        gameState = .gameOver
    }
}

// MARK: - View

struct DigitSpanGameView: View {
    @StateObject private var vm = DigitSpanViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("digitSpanDifficulty") private var difficulty: Difficulty = .medium

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
        .navigationTitle("Number Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { level in
                let isNewBest = level > stats.digitSpanBestLevel
                let session = GameSession(
                    gameType: "digitspan",
                    rawScore: level,
                    brainScore: max(70, min(145, 52 + level * 9)),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordDigitSpanGame(level: level)
                let newAchievements = checkAndUnlock(stats: stats)
                if isNewBest && level > 0 {
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
        case .idle:               idleView
        case .flashing:           flashingView
        case .input, .feedback:   inputView
        case .gameOver:           gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.mint)
                Text("Number Memory")
                    .font(.largeTitle.bold())
                Text("Watch the digits flash.\nReproduce them in order.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.digitSpanBestLevel > 0 {
                    Label("Best level: \(stats.digitSpanBestLevel)", systemImage: "trophy.fill")
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

    // MARK: - Flashing

    var flashingView: some View {
        VStack(spacing: 24) {
            HStack {
                StatBadge(label: "Level", value: "\(vm.currentLevel)", color: .mint)
                Spacer()
                livesView
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            Text("Watch the digits...")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 160, height: 160)

                if let digit = vm.flashedDigit {
                    Text("\(digit)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.mint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.12), value: vm.flashedDigit)

            Spacer()
        }
    }

    // MARK: - Input

    var inputView: some View {
        VStack(spacing: 20) {
            HStack {
                StatBadge(label: "Level", value: "\(vm.currentLevel)", color: .mint)
                Spacer()
                livesView
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Slot indicators
            HStack(spacing: 8) {
                ForEach(0..<vm.currentLevel, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(slotColor(for: i))
                            .frame(width: 36, height: 44)
                        if i < vm.playerInput.count {
                            Text("\(vm.playerInput[i])")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal)

            if let correct = vm.feedbackCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Text("Tap the digits in order")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Digit pad 0–9
            digitPad
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.feedbackCorrect)
    }

    var digitPad: some View {
        let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [0]]
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        Button {
                            vm.tapDigit(digit)
                        } label: {
                            Text("\(digit)")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.gameState != .input)
                    }
                }
            }
        }
    }

    func slotColor(for index: Int) -> Color {
        if index < vm.playerInput.count {
            if let correct = vm.feedbackCorrect {
                return correct ? .green : .red
            }
            return .mint
        }
        return Color(.systemGray4)
    }

    var livesView: some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { i in
                Image(systemName: i < vm.lives ? "heart.fill" : "heart")
                    .foregroundStyle(i < vm.lives ? .red : Color(.systemGray4))
            }
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.mint)

                Text("Game Over")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Max Level",    value: "\(vm.finalScore)",      color: .mint)
                    Divider()
                    resultRow("Brain Score",  value: "\(vm.finalBrainScore)", color: .indigo)
                    resultRow("All-Time Best", value: "Level \(stats.digitSpanBestLevel)", color: .secondary)
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.finalScore > 0 && vm.finalScore == stats.digitSpanBestLevel {
                    Label("New personal best!", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

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
    NavigationStack { DigitSpanGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
