import SwiftUI
import SwiftData

// Echo Grid — Simon-says tile memory with musical tones, game modes, Elo, and combo scoring.

// MARK: - Game Mode

enum EchoGridMode: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case reverse = "Reverse"
    case chaos   = "Chaos"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .classic: return "Repeat the sequence forward"
        case .reverse: return "Replay backwards · 1.5× bonus"
        case .chaos:   return "Tiles shuffle after each round"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "square.grid.3x3.fill"
        case .reverse: return "arrow.uturn.backward"
        case .chaos:   return "shuffle"
        }
    }
}

// MARK: - ViewModel

@MainActor
class MemoryGameViewModel: ObservableObject {

    // Base tile colors (9 tiles)
    private let tileColors: [Color] = [
        .red, .orange, .yellow, .green, .teal,
        .blue, .indigo, .purple, .pink
    ]

    // Chaos mode: visual position mapping (index in grid → tile identity)
    @Published var tileOrder: [Int] = Array(0..<9)   // tileOrder[gridPosition] = tileIdentity

    @Published var highlightedTile: Int? = nil         // tile identity
    @Published var playerTurn = false
    @Published var gameState: GameState = .idle
    @Published var level = 1
    @Published var totalScore = 0
    @Published var message = "Tap Start to begin"
    @Published var finalScore = 0
    @Published var finalLevel = 0
    @Published var cascadeFlash: [Int] = []            // grid positions being cascade-flashed
    @Published var activeGameMode: EchoGridMode = .classic
    @Published var lastEarnedScore: Int? = nil

    enum GameState { case idle, playing, input, success, failure, gameOver }

    var sequence: [Int] = []           // tile identities in order
    private var playerInput: [Int] = []
    private var playbackTask: Task<Void, Never>?
    private var eloParams: EloSystem.MemoryParams = EloSystem.memoryParams(1000)

    var inputProgress: Int { playerInput.count }
    var sequenceLength: Int { sequence.count }
    var onGameOver: ((Int, Int) -> Void)?
    var onRoundSuccess: ((Int, EchoGridMode) -> Void)?  // passes level & mode for scoring

    // MARK: Color helpers

    func tileColor(at identity: Int) -> Color {
        tileColors[identity % tileColors.count]
    }

    /// Opacity for a tile at a given grid position (used during idle/input phases).
    func gridTileOpacity(at gridPosition: Int) -> Double {
        let identity = tileOrder[gridPosition]
        if highlightedTile == identity { return 1.0 }
        return 0.15
    }

    func gridTileIsHighlighted(at gridPosition: Int) -> Bool {
        tileOrder[gridPosition] == highlightedTile
    }

    // MARK: Start

    func startGame(mode: EchoGridMode, eloParams: EloSystem.MemoryParams) {
        self.eloParams = eloParams
        self.activeGameMode = mode
        playbackTask?.cancel()
        sequence = []
        playerInput = []
        totalScore = 0
        level = 1
        tileOrder = Array(0..<9)
        cascadeFlash = []
        lastEarnedScore = nil
        gameState = .playing
        addAndPlay()
    }

    // MARK: Tile tap

    func tileTapped(at gridPosition: Int) {
        guard playerTurn, gameState == .input else { return }
        let identity = tileOrder[gridPosition]

        // In reverse mode the expected order is reversed
        let inputIndex = playerInput.count
        let expectedIdentity: Int
        if activeGameMode == .reverse {
            expectedIdentity = sequence[sequence.count - 1 - inputIndex]
        } else {
            expectedIdentity = sequence[inputIndex]
        }

        playerInput.append(identity)

        if identity != expectedIdentity {
            SoundEngine.shared.playWrong()
            Haptics.error()
            finalScore = totalScore
            finalLevel = level
            onGameOver?(totalScore, level)
            gameState = .gameOver
            playerTurn = false
            playbackTask?.cancel()
            return
        }

        // Play tile tone on correct tap
        SoundEngine.shared.playTone(frequency: SoundEngine.pentatonic[identity % SoundEngine.pentatonic.count],
                                    duration: 0.18)
        Haptics.medium()

        if playerInput.count == sequence.count {
            // Round complete — callback to view for combo+scoring
            onRoundSuccess?(level, activeGameMode)
            gameState = .success
            playerTurn = false
            // Trigger cascade flash then advance
            playbackTask = Task {
                await triggerCascadeFlash()
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }
                level += 1
                addAndPlay()
            }
        }
    }

    // MARK: Cascade flash

    private func triggerCascadeFlash() async {
        SoundEngine.shared.playMelodyCascade(tileCount: 9)
        for pos in 0..<9 {
            cascadeFlash.append(pos)
            try? await Task.sleep(for: .milliseconds(50))
        }
        try? await Task.sleep(for: .milliseconds(300))
        cascadeFlash = []
    }

    // MARK: Add & play sequence

    private func addAndPlay() {
        playerInput = []
        playerTurn = false
        gameState = .playing
        sequence.append(Int.random(in: 0..<9))
        message = "Watch carefully…"

        // Chaos mode: shuffle after success (not on first round)
        if activeGameMode == .chaos && sequence.count > 1 {
            tileOrder.shuffle()
        }

        let highlight = eloParams.highlightDuration
        let pause     = eloParams.pauseDuration

        playbackTask = Task {
            try? await Task.sleep(for: .seconds(0.4))
            for (i, tileIdentity) in sequence.enumerated() {
                guard !Task.isCancelled else { return }
                highlightedTile = tileIdentity
                // Play each tile's unique pentatonic tone
                SoundEngine.shared.playTone(
                    frequency: SoundEngine.pentatonic[tileIdentity % SoundEngine.pentatonic.count],
                    duration: 0.18
                )
                try? await Task.sleep(for: .seconds(highlight))
                guard !Task.isCancelled else { return }
                highlightedTile = nil
                try? await Task.sleep(for: .seconds(pause))
                if i == sequence.count - 1 {
                    guard !Task.isCancelled else { return }
                    playerTurn = true
                    gameState = .input
                    let tapCount = sequence.count
                    if activeGameMode == .reverse {
                        message = "↩ REVERSE — \(tapCount) tap\(tapCount == 1 ? "" : "s") backwards"
                    } else {
                        message = "Your turn — \(tapCount) tap\(tapCount == 1 ? "" : "s")"
                    }
                }
            }
        }
    }
}

// MARK: - View

struct MemoryGameView: View {
    @StateObject private var vm    = MemoryGameViewModel()
    @StateObject private var combo = ComboTracker()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @Query(sort: \GameSession.date, order: .reverse) private var sessions: [GameSession]
    @AppStorage("memoryDifficulty") private var difficulty: Difficulty = .medium
    @State private var selectedMode: EchoGridMode = .classic
    @State private var showGameOver = false
    @State private var gameResult: GameResult? = nil

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            if showGameOver, let result = gameResult {
                GameOverView(result: result) {
                    showGameOver = false
                    gameResult = nil
                    startGame()
                }
                .transition(.opacity)
            } else {
                playScreen
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGameOver)
        .navigationTitle("Echo Grid")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupHandlers()
        }
    }

    // MARK: - Setup

    private func setupHandlers() {
        vm.onRoundSuccess = { level, mode in
            combo.markCorrect()
            let base = level * 10
            let modeMultiplied = mode == .reverse ? Int(Double(base) * 1.5) : base
            let earned = combo.apply(modeMultiplied)
            vm.totalScore += earned
            vm.lastEarnedScore = earned
            vm.message = "+\(earned) pts"
        }

        vm.onGameOver = { score, level in
            combo.markWrong()
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

            // Update Elo
            stats.memoryEloRating = EloSystem.updated(stats.memoryEloRating, correct: level >= 5)

            let result = GameResult(
                gameTitle: "Echo Grid",
                primaryScore: score,
                primaryLabel: "pts",
                brainScore: brainScore,
                previousBrainScore: stats.memoryBrainScore,
                isNewBest: isNewBest,
                multiplierBreakdown: nil,
                percentileText: PlayerStats.percentileLabel(for: brainScore),
                accentColor: .blue,
                share: .init(
                    gameName: "Echo Grid",
                    icon: "square.grid.3x3.fill",
                    color: .blue,
                    primaryValue: "\(score)",
                    primaryLabel: "pts",
                    secondaryLine: "Level \(level)"
                )
            )
            gameResult = result
            withAnimation { showGameOver = true }
        }
    }

    private func startGame() {
        let params = EloSystem.memoryParams(stats.memoryEloRating)
        combo.reset()
        vm.startGame(mode: selectedMode, eloParams: params)
    }

    // MARK: - Play Screen

    var playScreen: some View {
        VStack(spacing: 16) {
            // Top bar: score, level, best + combo badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    AnimatedScoreText(value: vm.totalScore, font: .title2.bold(), color: .blue)
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
            .overlay(alignment: .topTrailing) {
                MultiplierBadgeView(combo: combo, color: .blue)
                    .offset(y: -8)
            }

            // Mode-specific banner or message
            VStack(spacing: 4) {
                if vm.gameState == .input && vm.activeGameMode == .reverse {
                    Text("↩ REVERSE")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.purple.gradient, in: Capsule())
                }
                Text(vm.message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(messageColor)
                    .animation(.easeInOut(duration: 0.2), value: vm.message)
            }
            .frame(minHeight: 40)

            // Progress dots during input
            if vm.gameState == .input {
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
                ForEach(0..<9, id: \.self) { gridPosition in
                    let identity = vm.tileOrder[gridPosition]
                    let tileColor = vm.tileColor(at: identity)
                    let isHighlighted = vm.highlightedTile == identity
                    let isCascade = vm.cascadeFlash.contains(gridPosition)

                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            (isHighlighted || isCascade)
                                ? tileColor
                                : tileColor.opacity(vm.gridTileOpacity(at: gridPosition))
                        )
                        .aspectRatio(1, contentMode: .fit)
                        // Always-on inner glow
                        .shadow(
                            color: tileColor.opacity(0.10),
                            radius: 4
                        )
                        // Highlight/cascade colored shadow
                        .shadow(
                            color: (isHighlighted || isCascade) ? tileColor.opacity(0.40) : .clear,
                            radius: 8
                        )
                        .scaleEffect(isHighlighted ? 1.08 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHighlighted)
                        .animation(.easeOut(duration: 0.1), value: isCascade)
                        .onTapGesture {
                            guard vm.playerTurn else { return }
                            vm.tileTapped(at: gridPosition)
                        }
                }
            }
            .padding(.horizontal)

            Spacer()

            // Pre-game controls
            if vm.gameState == .idle {
                VStack(spacing: 12) {
                    // Mode picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.caption.smallCaps())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(EchoGridMode.allCases) { mode in
                                    ModeChip(
                                        mode: mode,
                                        isSelected: selectedMode == mode
                                    ) { selectedMode = mode }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Elo tier badge
                    EloBadge(rating: stats.memoryEloRating, color: .blue)
                        .padding(.horizontal)

                    DifficultyPicker(difficulty: $difficulty)
                        .padding(.horizontal)
                }
            }

            Button {
                startGame()
            } label: {
                Text(vm.gameState == .idle ? "Start" : "Restart")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .disabled(vm.gameState == .playing || vm.gameState == .input || vm.gameState == .success)
            .opacity(vm.gameState == .playing || vm.gameState == .input || vm.gameState == .success ? 0.4 : 1)
        }
        .padding(.vertical)
    }

    var messageColor: Color {
        switch vm.gameState {
        case .failure: return .red
        case .success: return .green
        default:       return .primary
        }
    }
}

// MARK: - Mode Chip

private struct ModeChip: View {
    let mode: EchoGridMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: mode.icon)
                        .font(.caption2)
                    Text(mode.rawValue)
                        .font(.subheadline.bold())
                }
                Text(mode.description)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.blue.gradient
                    : Color(.secondarySystemBackground).gradient,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 150)
    }
}

// MARK: - Elo Badge

struct EloBadge: View {
    let rating: Double
    let color: Color

    private var tier: String {
        switch rating {
        case ..<900:      return "Beginner"
        case 900..<1100:  return "Intermediate"
        case 1100..<1300: return "Advanced"
        default:          return "Expert"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.caption)
            Text("Auto · \(tier)")
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Shared UI helpers

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
