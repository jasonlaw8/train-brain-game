import SwiftUI
import SwiftData

// Spatial Memory Grid: a grid of cells lights up briefly; remember and tap them.
// Each correct round adds one more cell. Wrong tap = game over.

// MARK: - GameState

extension SpatialMemoryViewModel {
    enum GameState: Equatable {
        case idle, showing, input, success, gameOver
    }
}

// MARK: - ViewModel

@MainActor
class SpatialMemoryViewModel: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var level = 1
    @Published var litCells: Set<Int> = []
    @Published var tappedCells: Set<Int> = []
    @Published var targetCells: Set<Int> = []
    @Published var wrongCell: Int? = nil
    @Published var finalLevel: Int = 0
    @Published var showNewBest = false
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    var gridSize: Int = 4
    var onGameOver: ((Int) -> Void)?

    private var showDuration: Double = 1.2
    private var playbackTask: Task<Void, Never>?

    // MARK: Difficulty-derived config

    private func configure(difficulty: Difficulty) {
        switch difficulty {
        case .easy:
            gridSize = 4
            showDuration = 1.5
        case .medium:
            gridSize = 4
            showDuration = 1.2
        case .hard:
            gridSize = 5
            showDuration = 0.9
        }
    }

    var startingLevel: Int {
        gridSize == 5 ? 4 : 3
    }

    var totalCells: Int { gridSize * gridSize }

    // MARK: Start / restart

    func startGame(difficulty: Difficulty) {
        playbackTask?.cancel()
        configure(difficulty: difficulty)
        level = startingLevel
        tappedCells = []
        targetCells = []
        litCells = []
        wrongCell = nil
        finalLevel = 0
        gameState = .showing
        beginShowPhase()
    }

    // MARK: Show phase

    private func beginShowPhase() {
        tappedCells = []
        wrongCell = nil

        // Pick `level` distinct random cells
        let indices = Array(0..<totalCells).shuffled()
        let chosen = Set(indices.prefix(level))
        targetCells = chosen

        playbackTask = Task {
            // Brief pre-show pause
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            // Light them all up at once
            withAnimation(.easeIn(duration: 0.15)) {
                litCells = chosen
            }

            try? await Task.sleep(for: .seconds(showDuration))
            guard !Task.isCancelled else { return }

            // Fade out
            withAnimation(.easeOut(duration: 0.25)) {
                litCells = []
            }

            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            gameState = .input
        }
    }

    // MARK: Cell tap

    func cellTapped(_ index: Int) {
        guard gameState == .input else { return }
        guard !tappedCells.contains(index) else { return }

        if targetCells.contains(index) {
            // Correct
            Haptics.medium()
            tappedCells.insert(index)

            if tappedCells == targetCells {
                // Completed the set — advance
                gameState = .success
                playbackTask = Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    level += 1
                    gameState = .showing
                    beginShowPhase()
                }
            }
        } else {
            // Wrong tap
            Haptics.error()
            wrongCell = index
            finalLevel = level
            gameState = .gameOver
            playbackTask?.cancel()
            onGameOver?(level)
            // Clear wrong cell flash after a moment (view stays on game-over screen)
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                wrongCell = nil
            }
        }
    }

    // MARK: Status message

    var statusMessage: String {
        switch gameState {
        case .idle:    return "Tap Start to begin"
        case .showing: return "Watch carefully…"
        case .input:   return "Your turn!"
        case .success: return "Level \(level - 1) complete!"
        case .gameOver: return "Game Over"
        }
    }
}

// MARK: - View

struct SpatialMemoryGameView: View {
    @StateObject private var vm = SpatialMemoryViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("spatialDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        ZStack {
            gameContent

            if vm.showNewBest {
                NewBestBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
            if let lvl = vm.leveledUpTo {
                LevelUpBanner(level: lvl)
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
        .navigationTitle("Spatial Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { level in
                let isNewBest = level > stats.spatialBestLevel
                let leveledUp = stats.recordSpatialGame(level: level)
                let session = GameSession(
                    gameType: "spatial",
                    rawScore: level,
                    brainScore: PlayerStats.spatialBrainScore(level: level),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
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

    // MARK: - Content router

    @ViewBuilder
    var gameContent: some View {
        switch vm.gameState {
        case .idle:
            idleScreen
        case .gameOver:
            gameOverScreen
        default:
            playScreen
        }
    }

    // MARK: - Idle Screen

    var idleScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 96, height: 96)
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.cyan)
                    }

                    Text("Spatial Memory")
                        .font(.largeTitle.bold())

                    Text("Watch which cells light up, then tap them from memory.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }

                if stats.spatialBestLevel > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.cyan)
                            .font(.caption)
                        Text("Best: Level \(stats.spatialBestLevel)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.cyan)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.12), in: Capsule())
                }

                VStack(spacing: 16) {
                    DifficultyPicker(difficulty: $difficulty)
                        .padding(.horizontal)

                    Button {
                        vm.startGame(difficulty: difficulty)
                    } label: {
                        Text("Start")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - Play Screen

    var playScreen: some View {
        VStack(spacing: 20) {
            // Stat badges
            HStack {
                StatBadge(label: "Round", value: "\(vm.level)", color: .cyan)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.spatialBestLevel)", color: .secondary)
            }
            .padding(.horizontal)

            // Status message
            Text(vm.statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(messageColor)
                .animation(.easeInOut(duration: 0.2), value: vm.statusMessage)
                .frame(minHeight: 24)

            // Progress dots during input phase
            if vm.gameState == .input {
                HStack(spacing: 6) {
                    ForEach(0..<vm.targetCells.count, id: \.self) { i in
                        Circle()
                            .fill(i < vm.tappedCells.count ? Color.cyan : Color(.systemGray4))
                            .frame(width: 10, height: 10)
                    }
                }
                .animation(.easeInOut, value: vm.tappedCells.count)
            } else {
                Color.clear.frame(height: 10)
            }

            // Grid
            spatialGrid

            Spacer()
        }
        .padding(.vertical)
    }

    var spatialGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: vm.gridSize
        )
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<vm.totalCells, id: \.self) { index in
                RoundedRectangle(cornerRadius: 12)
                    .fill(cellColor(for: index))
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(vm.litCells.contains(index) ? 1.05 : 1.0)
                    .shadow(
                        color: cellShadowColor(for: index),
                        radius: vm.litCells.contains(index) ? 10 : 0
                    )
                    .animation(
                        .spring(response: 0.25, dampingFraction: 0.65),
                        value: cellAnimationKey(for: index)
                    )
                    .onTapGesture {
                        vm.cellTapped(index)
                    }
                    .allowsHitTesting(vm.gameState == .input)
            }
        }
        .padding(.horizontal)
    }

    // MARK: Cell appearance helpers

    func cellColor(for index: Int) -> Color {
        if vm.wrongCell == index {
            return .red
        }
        if vm.litCells.contains(index) {
            return .blue
        }
        if vm.tappedCells.contains(index) {
            return .green
        }
        return Color(.systemGray5)
    }

    func cellShadowColor(for index: Int) -> Color {
        if vm.litCells.contains(index) { return .blue.opacity(0.5) }
        if vm.tappedCells.contains(index) { return .green.opacity(0.4) }
        return .clear
    }

    func cellAnimationKey(for index: Int) -> Int {
        var key = 0
        if vm.litCells.contains(index)   { key |= 1 }
        if vm.tappedCells.contains(index) { key |= 2 }
        if vm.wrongCell == index          { key |= 4 }
        return key
    }

    var messageColor: Color {
        switch vm.gameState {
        case .success:  return .green
        case .gameOver: return .red
        default:        return .primary
        }
    }

    // MARK: - Game Over Screen

    var gameOverScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "brain")
                    .font(.system(size: 56))
                    .foregroundStyle(.cyan)

                Text("Game Over")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow(
                        label: "Level Reached",
                        value: "\(vm.finalLevel)",
                        color: .cyan
                    )
                    Divider()
                    let bs = PlayerStats.spatialBrainScore(level: vm.finalLevel)
                    resultRow(
                        label: "Brain Score",
                        value: "\(bs)",
                        color: .cyan
                    )
                    resultRow(
                        label: "vs. Average",
                        value: PlayerStats.percentileLabel(for: bs),
                        color: bs >= 100 ? .green : .orange
                    )
                    Divider()
                    resultRow(
                        label: "All-Time Best",
                        value: "\(stats.spatialBestLevel)",
                        color: .secondary
                    )
                }
                .padding()
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .padding(.horizontal)

                if vm.finalLevel > 0 && vm.finalLevel == stats.spatialBestLevel {
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
                gameName: "Spatial Memory",
                gameIcon: "square.grid.2x2.fill",
                gameColor: .cyan,
                primaryValue: "\(vm.finalLevel)",
                primaryLabel: "levels",
                secondaryLine: nil
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button {
                vm.startGame(difficulty: difficulty)
            } label: {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16))
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
}

// MARK: - Preview

#Preview {
    NavigationStack { SpatialMemoryGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
