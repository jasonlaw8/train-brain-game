import SwiftUI
import SwiftData

// Find the odd one out before time runs out. 8 rounds, then results.

// MARK: - ViewModel

@MainActor
class VisualSearchViewModel: ObservableObject {
    static let totalRounds = 8

    @Published var gameState: GameState = .idle
    @Published var round = 0
    @Published var correctCount = 0
    @Published var roundTimeRemaining: Double = 5.0
    @Published var cells: [SearchCell] = []
    @Published var targetIndex: Int = 0
    @Published var tappedIndex: Int? = nil
    @Published var roundResult: Bool? = nil    // true=correct false=wrong nil=in progress
    @Published var showNewBest = false
    @Published var wasNewBest = false   // set before stats update, so ties do not count
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    struct SearchCell: Identifiable {
        let id = UUID()
        let symbol: String
        let color: Color
        let isTarget: Bool
    }

    enum GameState { case idle, playing, roundResult, finished }

    var onGameOver: ((Int) -> Void)?

    private var timerTask: Task<Void, Never>?
    private var difficulty: Difficulty = .medium

    // Symbol pool — one picked per round for distractors; target uses same symbol, different color
    private let symbolPool = ["circle.fill", "square.fill", "triangle.fill", "star.fill"]

    // MARK: - Public interface

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        round = 0
        correctCount = 0
        tappedIndex = nil
        roundResult = nil
        beginNextRound()
    }

    func cellTapped(index: Int) {
        guard gameState == .playing else { return }
        timerTask?.cancel()
        tappedIndex = index
        let correct = cells[index].isTarget
        roundResult = correct
        if correct { correctCount += 1; Haptics.light() } else { Haptics.error() }
        gameState = .roundResult

        timerTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            advanceAfterResult()
        }
    }

    // MARK: - Private

    private func beginNextRound() {
        round += 1
        tappedIndex = nil
        roundResult = nil
        cells = buildGrid(round: round)
        roundTimeRemaining = roundDuration
        gameState = .playing
        startTimer()
    }

    private var roundDuration: Double {
        switch difficulty {
        case .easy:   return 5.0
        case .medium: return 4.0
        case .hard:   return 3.0
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            let tickInterval = 0.05
            while roundTimeRemaining > 0 {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard !Task.isCancelled else { return }
                roundTimeRemaining = max(0, roundTimeRemaining - tickInterval)
            }
            guard !Task.isCancelled, gameState == .playing else { return }
            // Time expired — count as wrong
            tappedIndex = nil
            roundResult = false
            Haptics.error()
            gameState = .roundResult
            timerTask = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                advanceAfterResult()
            }
        }
    }

    private func advanceAfterResult() {
        if round >= Self.totalRounds {
            gameState = .finished
            onGameOver?(correctCount)
        } else {
            beginNextRound()
        }
    }

    // MARK: - Grid builder

    private func buildGrid(round: Int) -> [SearchCell] {
        let cellCount = gridCellCount(round: round)
        let symbol = symbolPool[(round - 1) % symbolPool.count]
        // The target is coded by shape as well as color. Colour alone made the
        // odd one out invisible to colorblind players.
        let targetSymbol = outlineVariant(of: symbol)
        let distractorColor: Color = .blue
        let targetColor: Color = (round % 2 == 0) ? .red : .orange

        var result: [SearchCell] = (0..<(cellCount - 1)).map { _ in
            SearchCell(symbol: symbol, color: distractorColor, isTarget: false)
        }
        let target = SearchCell(symbol: targetSymbol, color: targetColor, isTarget: true)
        let insertPos = Int.random(in: 0...result.count)
        result.insert(target, at: insertPos)
        targetIndex = insertPos
        return result
    }

    /// Hollow counterpart of a filled symbol, so the target differs in form.
    private func outlineVariant(of symbol: String) -> String {
        symbol.hasSuffix(".fill") ? String(symbol.dropLast(5)) : symbol
    }

    private func gridCellCount(round: Int) -> Int {
        switch difficulty {
        case .hard:
            switch round {
            case 1, 2: return 12
            case 3, 4: return 12
            case 5, 6: return 16
            default:   return 20
            }
        default:
            switch round {
            case 1, 2: return 9
            case 3, 4: return 12
            case 5, 6: return 16
            default:   return 20
            }
        }
    }

    func columnCount(for cellCount: Int) -> Int {
        switch cellCount {
        case 9:  return 3
        case 12: return 3
        case 16: return 4
        case 20: return 4
        default: return 3
        }
    }

    /// Tears down every timer and task without recording a result.
    /// Called from .onDisappear so leaving mid-game never writes a session.
    func abandon() {
        timerTask?.cancel()
        timerTask = nil
        gameState = .idle
    }
}

// MARK: - View

struct VisualSearchGameView: View {
    @StateObject private var vm = VisualSearchViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("visualDifficulty") private var difficulty: Difficulty = .medium
    @State private var pendingStart = false

    private var stats: PlayerStats {
        statsQuery.first ?? PlayerStats.fetchOrCreate(in: modelContext)
    }

    var body: some View {
        ZStack {
            switch vm.gameState {
            case .idle:
                idleView
            case .playing, .roundResult:
                playingView
            case .finished:
                resultsView
            }

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
        .navigationTitle("Visual Search")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            // 3-2-1 before the clock starts, so the first stimulus
            // is not simultaneous with the timer going live.
            if pendingStart {
                CountdownOverlay {
                    pendingStart = false
                    vm.startGame(difficulty: difficulty)
                }
            }
        }
        .onAppear {
            vm.onGameOver = { correct in
                let isNewBest = correct > stats.visualBestScore
                vm.wasNewBest = isNewBest
                let leveledUp = stats.recordVisualGame(correct: correct)
                let session = GameSession(
                    gameType: "visual",
                    rawScore: correct,
                    brainScore: PlayerStats.visualBrainScore(correct: correct),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
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

    // MARK: - Idle View

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.indigo)

                Text("Visual Search")
                    .font(.largeTitle.bold())

                Text("Find the odd one out before time runs out.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if stats.visualBestScore > 0 {
                    Label("Best: \(stats.visualBestScore)/\(VisualSearchViewModel.totalRounds)", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button { pendingStart = true } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Playing View

    var playingView: some View {
        VStack(spacing: 0) {
            // Stat badges
            HStack {
                StatBadge(
                    label: "Round",
                    value: "\(min(vm.round, VisualSearchViewModel.totalRounds))/\(VisualSearchViewModel.totalRounds)",
                    color: .indigo
                )
                Spacer()
                StatBadge(
                    label: "Correct",
                    value: "\(vm.correctCount)",
                    color: .green
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Timer bar
            timerBar
                .padding(.horizontal)
                .padding(.bottom, 16)

            // Grid
            gridView
                .padding(.horizontal)

            Spacer()
        }
    }

    var timerBar: some View {
        let fraction = vm.roundTimeRemaining / roundDuration(for: difficulty)
        let barColor: Color = fraction > 0.5 ? .indigo : fraction > 0.25 ? .orange : .red

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(max(0, fraction)), height: 8)
                    .animation(.linear(duration: 0.05), value: vm.roundTimeRemaining)
            }
        }
        .frame(height: 8)
    }

    private func roundDuration(for d: Difficulty) -> Double {
        switch d {
        case .easy:   return 5.0
        case .medium: return 4.0
        case .hard:   return 3.0
        }
    }

    var gridView: some View {
        let cellCount = vm.cells.count
        let cols = vm.columnCount(for: cellCount)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: cols)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(vm.cells.enumerated()), id: \.element.id) { index, cell in
                cellView(cell: cell, index: index)
            }
        }
    }

    @ViewBuilder
    func cellView(cell: VisualSearchViewModel.SearchCell, index: Int) -> some View {
        let tapped = vm.tappedIndex == index
        let isRoundOver = vm.gameState == .roundResult
        let flashColor: Color? = {
            guard isRoundOver, tapped else { return nil }
            return (vm.roundResult == true) ? .green : .red
        }()
        // Also flash the target red when time expired (tappedIndex is nil, roundResult false)
        let showMissedTarget = isRoundOver && vm.roundResult == false && vm.tappedIndex == nil && cell.isTarget

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(flashColor.map { $0.opacity(0.2) } ?? Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            showMissedTarget ? Color.red.opacity(0.6) :
                            (flashColor.map { $0.opacity(0.6) } ?? Color(.systemGray4)),
                            lineWidth: showMissedTarget || tapped ? 2 : 1
                        )
                )

            Image(systemName: cell.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(cell.color)
        }
        .frame(height: 64)
        .scaleEffect(tapped ? 1.12 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: tapped)
        .onTapGesture {
            guard vm.gameState == .playing else { return }
            vm.cellTapped(index: index)
        }
    }

    // MARK: - Results View

    var resultsView: some View {
        VStack(spacing: 0) {
            Spacer()

            resultsContent

            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            ShareResultButton(
                gameName: "Visual Search",
                gameIcon: "eye.fill",
                gameColor: .indigo,
                primaryValue: "\(vm.correctCount)/\(VisualSearchViewModel.totalRounds)",
                primaryLabel: "correct",
                secondaryLine: "Brain Score: \(PlayerStats.visualBrainScore(correct: vm.correctCount))"
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button { pendingStart = true } label: {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    var resultsContent: some View {
        VStack(spacing: 20) {
            Text("Results").font(.largeTitle.bold())

            VStack(spacing: 10) {
                resultRow(
                    "Correct",
                    value: "\(vm.correctCount)/\(VisualSearchViewModel.totalRounds)",
                    color: scoreColor(vm.correctCount)
                )

                let bs = PlayerStats.visualBrainScore(correct: vm.correctCount)
                resultRow("Brain Score", value: "\(bs)", color: bs >= 100 ? .green : .orange)
                resultRow("vs. Average", value: PlayerStats.percentileLabel(for: bs), color: bs >= 100 ? .green : .orange)

                Divider()
                resultRow("Average (5/8)", value: "100", color: .secondary)

                if stats.visualBestScore > 0 {
                    Divider()
                    resultRow(
                        "All-Time Best",
                        value: "\(stats.visualBestScore)/\(VisualSearchViewModel.totalRounds)",
                        color: .yellow
                    )
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    func resultRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit().bold()).foregroundStyle(color)
        }
    }

    func scoreColor(_ correct: Int) -> Color {
        switch correct {
        case 7...: return .green
        case 5...: return .teal
        case 3...: return .orange
        default:   return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { VisualSearchGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
