import SwiftUI
import SwiftData

// Simon Says: watch the tile sequence light up, then repeat it.
// Scoring: each game records a GameSession with normalized brainScore based on level reached.

@MainActor
class MemoryGameViewModel: ObservableObject {
    private let tileColors: [Color] = [
        .red, .orange, .yellow, .green, .teal,
        .blue, .indigo, .purple, .pink
    ]

    @Published var highlightedTile: Int? = nil
    @Published var playerTurn = false
    @Published var gameState: GameState = .idle
    @Published var level = 1
    @Published var score = 0
    @Published var message = "Tap Start to begin"
    @Published var showNewBest = false
    @Published var finalScore = 0
    @Published var finalLevel = 0

    enum GameState { case idle, playing, input, success, failure, gameOver }

    private var sequence: [Int] = []
    private var playerInput: [Int] = []
    private var playbackTask: Task<Void, Never>?
    private var difficulty: Difficulty = .medium

    var inputProgress: Int { playerInput.count }
    var sequenceLength: Int { sequence.count }
    var onGameOver: ((Int, Int) -> Void)?

    func tileColor(at index: Int) -> Color {
        let base = tileColors[index]
        if highlightedTile == index { return base }
        return base.opacity(playerTurn ? 0.45 : 0.25)
    }

    func startGame(difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
        playbackTask?.cancel()
        sequence = []
        playerInput = []
        score = 0
        level = 1
        gameState = .playing
        addAndPlay()
    }

    func tileTapped(_ index: Int) {
        guard playerTurn, gameState == .input else { return }
        let expected = sequence[playerInput.count]
        playerInput.append(index)

        if index != expected {
            Haptics.error()
            finalScore = score
            finalLevel = level
            onGameOver?(score, level)
            gameState = .gameOver
            playerTurn = false
            playbackTask?.cancel()
            return
        }

        Haptics.medium()

        if playerInput.count == sequence.count {
            score += level * 10
            level += 1
            gameState = .success
            playerTurn = false
            message = "Nice! +\(sequence.count * 10) pts"
            playbackTask = Task {
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
                addAndPlay()
            }
        }
    }

    private func addAndPlay() {
        playerInput = []
        playerTurn = false
        gameState = .playing
        sequence.append(Int.random(in: 0..<9))
        message = "Watch carefully…"

        let highlight = difficulty.memoryHighlightDuration
        let pause = difficulty.memoryPauseDuration

        playbackTask = Task {
            try? await Task.sleep(for: .seconds(0.4))
            for (i, tile) in sequence.enumerated() {
                guard !Task.isCancelled else { return }
                highlightedTile = tile
                try? await Task.sleep(for: .seconds(highlight))
                guard !Task.isCancelled else { return }
                highlightedTile = nil
                try? await Task.sleep(for: .seconds(pause))
                if i == sequence.count - 1 {
                    guard !Task.isCancelled else { return }
                    playerTurn = true
                    gameState = .input
                    message = "Your turn — \(sequence.count) tap\(sequence.count == 1 ? "" : "s")"
                }
            }
        }
    }
}

struct MemoryGameView: View {
    @StateObject private var vm = MemoryGameViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @Query(sort: \GameSession.date, order: .reverse) private var sessions: [GameSession]
    @AppStorage("memoryDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            gameContent

            if vm.showNewBest {
                NewBestBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4), value: vm.showNewBest)
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { score, level in
                let isNewBest = score > stats.memoryBestScore
                let brainScore = PlayerStats.memoryBrainScore(level: level)
                let session = GameSession(
                    gameType: "memory",
                    rawScore: level,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordMemoryGame(score: score, level: level)
                if isNewBest && score > 0 {
                    vm.showNewBest = true
                    Haptics.success()
                    Task { try? await Task.sleep(for: .seconds(2)); vm.showNewBest = false }
                }
            }
        }
    }

    @ViewBuilder
    var gameContent: some View {
        if vm.gameState == .gameOver {
            gameOverScreen
        } else {
            playScreen
        }
    }

    // MARK: - Play Screen

    var playScreen: some View {
        VStack(spacing: 20) {
            // Score row with animated numbers
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    AnimatedScoreText(value: vm.score, font: .title2.bold(), color: .blue)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Level").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    AnimatedScoreText(value: vm.level, font: .title2.bold(), color: .indigo)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text("\(stats.memoryBestScore)")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Text(vm.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(messageColor)
                .animation(.easeInOut(duration: 0.2), value: vm.message)
                .frame(minHeight: 24)

            // Progress dots during input
            if vm.playerTurn || vm.gameState == .input {
                HStack(spacing: 6) {
                    ForEach(0..<vm.sequenceLength, id: \.self) { i in
                        Circle()
                            .fill(i < vm.inputProgress ? Color.blue : Color(.systemGray4))
                            .frame(width: 10, height: 10)
                    }
                }
                .animation(.easeInOut, value: vm.inputProgress)
            } else {
                Color.clear.frame(height: 10)
            }

            // Tile grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(vm.tileColor(at: index))
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(vm.highlightedTile == index ? 1.08 : 1.0)
                        .shadow(
                            color: vm.highlightedTile == index
                                ? vm.tileColor(at: index).opacity(0.6) : .clear,
                            radius: 12
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: vm.highlightedTile)
                        .onTapGesture { vm.tileTapped(index) }
                }
            }
            .padding(.horizontal)

            Spacer()

            // Difficulty + Start
            if vm.gameState == .idle {
                DifficultyPicker(difficulty: $difficulty)
                    .padding(.horizontal)
            }

            Button {
                vm.startGame(difficulty: difficulty)
            } label: {
                Text(vm.gameState == .idle ? "Start" : "Restart")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .disabled(vm.gameState == .playing || vm.gameState == .input || vm.gameState == .success)
            .opacity(vm.gameState == .playing || vm.gameState == .input || vm.gameState == .success ? 0.4 : 1)
        }
        .padding(.vertical)
    }

    // MARK: - Game Over Screen

    var gameOverScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "brain")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Game Over")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow(label: "Score",         value: "\(vm.finalScore)", color: .blue)
                    resultRow(label: "Level Reached", value: "\(vm.finalLevel)", color: .indigo)
                    Divider()
                    let bs = PlayerStats.memoryBrainScore(level: vm.finalLevel)
                    resultRow(label: "Brain Score",   value: "\(bs)", color: .blue)
                    resultRow(label: "vs. Average",
                              value: PlayerStats.percentileLabel(for: bs),
                              color: bs >= 100 ? .green : .orange)
                    Divider()
                    resultRow(label: "All-Time Best", value: "\(stats.memoryBestScore)", color: .secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.finalScore > 0 && vm.finalScore == stats.memoryBestScore {
                    Label("New personal best!", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button {
                vm.startGame(difficulty: difficulty)
            } label: {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

    var messageColor: Color {
        switch vm.gameState {
        case .failure: return .red
        case .success: return .green
        default: return .primary
        }
    }
}

// MARK: - Shared UI

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.smallCaps()).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).foregroundStyle(color)
        }
    }
}

struct NewBestBanner: View {
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                Text("New Personal Best!")
                    .font(.subheadline.bold())
                Image(systemName: "star.fill")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: .orange.opacity(0.4), radius: 10)
            .padding(.top, 8)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack { MemoryGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
