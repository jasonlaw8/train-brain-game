import SwiftUI
import SwiftData

// Word Scramble: Tap letters in order to spell a scrambled word. 60s (Hard: 45s) timer.

// MARK: - ViewModel

@MainActor
class WordScrambleViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }

    @Published var gameState: GameState = .idle
    @Published var scrambledLetters: [LetterTile] = []
    @Published var playerAnswer: [String] = []
    @Published var score: Int = 0
    @Published var timeRemaining: Double = 60
    @Published var flashCorrect: Bool? = nil   // nil, true=green, false=red
    @Published var showNewBest = false
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0

    struct LetterTile: Identifiable {
        let id = UUID()
        let letter: String
        var isUsed: Bool = false
    }

    var onGameOver: ((Int) -> Void)?

    private var difficulty: Difficulty = .medium
    private var currentWord: String = ""
    private var wordQueue: [String] = []
    private var timer: Timer?
    private var feedbackTask: Task<Void, Never>?

    private let wordBank: [String] = [
        "BRAIN", "FOCUS", "LEARN", "THINK", "QUICK", "SHARP", "LOGIC", "SPEED", "TRAIN", "SCORE",
        "SKILL", "LEVEL", "SMART", "RAPID", "ALERT", "AGILE", "POWER", "LASER", "PRIME", "CRACK",
        "SWIFT", "JUDGE", "GRASP", "BOOST", "VITAL"
    ]

    private var totalTime: Double { difficulty == .hard ? 45.0 : 60.0 }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        score = 0
        timeRemaining = totalTime
        flashCorrect = nil
        wordQueue = wordBank.shuffled()
        gameState = .playing
        loadNextWord()
        startTimer()
    }

    private func loadNextWord() {
        feedbackTask?.cancel()
        playerAnswer = []
        if wordQueue.isEmpty { wordQueue = wordBank.shuffled() }
        currentWord = wordQueue.removeFirst()
        scrambledLetters = makeScramble(from: currentWord)
        flashCorrect = nil
    }

    private func makeScramble(from word: String) -> [LetterTile] {
        var letters = word.map { String($0) }
        // Ensure scrambled != original
        var attempts = 0
        repeat {
            letters.shuffle()
            attempts += 1
        } while letters.joined() == word && attempts < 20
        return letters.map { LetterTile(letter: $0) }
    }

    func tapLetter(id: UUID) {
        guard gameState == .playing, flashCorrect == nil else { return }
        guard let idx = scrambledLetters.firstIndex(where: { $0.id == id && !$0.isUsed }) else { return }
        scrambledLetters[idx].isUsed = true
        playerAnswer.append(scrambledLetters[idx].letter)
        Haptics.light()
        checkAnswer()
    }

    func deleteLast() {
        guard gameState == .playing, !playerAnswer.isEmpty, flashCorrect == nil else { return }
        let removed = playerAnswer.removeLast()
        // Re-enable the last used tile with that letter
        if let idx = scrambledLetters.indices.reversed().first(where: {
            scrambledLetters[$0].isUsed && scrambledLetters[$0].letter == removed
        }) {
            scrambledLetters[idx].isUsed = false
        }
        Haptics.light()
    }

    private func checkAnswer() {
        let answer = playerAnswer.joined()
        let target = currentWord

        if answer == target {
            // Correct!
            score += 1
            flashCorrect = true
            Haptics.success()
            feedbackTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                loadNextWord()
            }
        } else if answer.count == target.count {
            // Wrong full-length answer
            flashCorrect = false
            Haptics.error()
            feedbackTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                // Reset answer
                for i in scrambledLetters.indices { scrambledLetters[i].isUsed = false }
                playerAnswer = []
                flashCorrect = nil
            }
        }
        // else partial — just keep going
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
        feedbackTask?.cancel()
        finalScore = score
        finalBrainScore = max(70, min(145, 40 + score * 15))
        onGameOver?(score)
        gameState = .gameOver
    }
}

// MARK: - View

struct WordScrambleGameView: View {
    @StateObject private var vm = WordScrambleViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("wordScrambleDifficulty") private var difficulty: Difficulty = .medium

    private let gameColor = Color(red: 0.15, green: 0.65, blue: 0.35)

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
        .navigationTitle("Word Scramble")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { score in
                let isNewBest = score > stats.wordScrambleBestScore
                let session = GameSession(
                    gameType: "wordscramble",
                    rawScore: score,
                    brainScore: max(70, min(145, 40 + score * 15)),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordWordScrambleGame(score: score)
                let newAchievements = checkAndUnlock(stats: stats)
                if isNewBest && score > 0 {
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
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(gameColor)
                Text("Word Scramble")
                    .font(.largeTitle.bold())
                Text("Tap letters in the right order\nto spell the scrambled word.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.wordScrambleBestScore > 0 {
                    Label("Best: \(stats.wordScrambleBestScore) words", systemImage: "trophy.fill")
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
                    .background(gameColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 16) {
            HStack {
                StatBadge(label: "Words", value: "\(vm.score)", color: gameColor)
                Spacer()
                StatBadge(label: "Best",  value: "\(stats.wordScrambleBestScore)", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Timer bar
            timerBar

            Spacer()

            // Answer slots
            answerSlots

            // Flash feedback icon
            if let correct = vm.flashCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(correct ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 44)
            }

            Spacer()

            // Scrambled letter buttons
            letterTiles

            // Delete button
            Button { vm.deleteLast() } label: {
                Image(systemName: "delete.left.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 60, height: 44)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.flashCorrect)
    }

    var answerSlots: some View {
        HStack(spacing: 6) {
            ForEach(0..<vm.scrambledLetters.count, id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(slotBackground(for: i))
                        .frame(width: 38, height: 46)
                    if i < vm.playerAnswer.count {
                        Text(vm.playerAnswer[i])
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    var letterTiles: some View {
        let columns = [
            GridItem(.adaptive(minimum: 52, maximum: 60), spacing: 10)
        ]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(vm.scrambledLetters) { tile in
                Button {
                    vm.tapLetter(id: tile.id)
                } label: {
                    Text(tile.letter)
                        .font(.title2.bold())
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(tile.isUsed ? Color(.systemGray4) : gameColor)
                        )
                        .foregroundStyle(tile.isUsed ? Color(.systemGray2) : .white)
                }
                .buttonStyle(.plain)
                .disabled(tile.isUsed || vm.flashCorrect != nil)
            }
        }
        .padding(.horizontal)
    }

    func slotBackground(for index: Int) -> Color {
        if index < vm.playerAnswer.count {
            if let correct = vm.flashCorrect {
                return correct ? .green : .red
            }
            return gameColor
        }
        return Color(.systemGray4)
    }

    var timerBar: some View {
        let total = difficulty == .hard ? 45.0 : 60.0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(timerColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining / total))
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
        if vm.timeRemaining > 20 { return gameColor }
        if vm.timeRemaining > 10 { return .orange }
        return .red
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(gameColor)

                Text("Time's Up!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow("Words Completed", value: "\(vm.finalScore)", color: gameColor)
                    Divider()
                    resultRow("Brain Score",     value: "\(vm.finalBrainScore)", color: .indigo)
                    resultRow("All-Time Best",   value: "\(stats.wordScrambleBestScore) words", color: .secondary)
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.finalScore > 0 && vm.finalScore == stats.wordScrambleBestScore {
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
                gameName: "Word Scramble",
                gameIcon: "character.book.closed.fill",
                gameColor: gameColor,
                primaryValue: "\(vm.finalScore)",
                primaryLabel: "words",
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
                    .background(gameColor, in: RoundedRectangle(cornerRadius: 16))
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
    NavigationStack { WordScrambleGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
