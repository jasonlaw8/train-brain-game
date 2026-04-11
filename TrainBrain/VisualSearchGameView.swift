import SwiftUI
import SwiftData

// Odd One Out — find the different item before time runs out. 8 themed rounds.

// MARK: - ViewModel

@MainActor
class VisualSearchViewModel: ObservableObject {
    static let totalRounds = 8

    @Published var gameState: GameState = .idle
    @Published var round = 0
    @Published var correctCount = 0
    @Published var totalPoints = 0
    @Published var roundTimeRemaining: Double = 5.0
    @Published var cells: [SearchCell] = []
    @Published var targetIndex: Int = 0
    @Published var tappedIndex: Int? = nil
    @Published var roundResult: Bool? = nil    // true=correct false=wrong/timeout nil=in progress
    @Published var speedLabel: String? = nil   // "EAGLE EYE!", "SHARP!", etc.
    @Published var showGameOver = false
    @Published var gameResult: GameResult? = nil

    struct SearchCell: Identifiable {
        let id = UUID()
        let symbol: String
        let color: Color
        let isTarget: Bool
        let rotation: Double   // degrees; non-zero only for Set D target
    }

    enum GameState { case idle, playing, roundResult, finished }

    var onGameOver: ((Int, Int) -> Void)?   // (correctCount, totalPoints)

    private var timerTask: Task<Void, Never>?
    private var roundStartTime: Date?

    // Themed visual sets
    struct ThemeSet {
        let distractorSymbol: String
        let targetSymbol: String
        let distractorColor: Color
        let targetColor: Color
        let targetRotation: Double  // extra rotation for set D
        let differenceLabel: String
    }

    private let themeSets: [ThemeSet] = [
        // Set A (rounds 1-2): gems
        ThemeSet(distractorSymbol: "diamond.fill", targetSymbol: "star.fill",
                 distractorColor: .blue, targetColor: .orange,
                 targetRotation: 0, differenceLabel: "different shape"),
        // Set B (rounds 3-4): shapes
        ThemeSet(distractorSymbol: "hexagon.fill", targetSymbol: "pentagon.fill",
                 distractorColor: .indigo, targetColor: .indigo,
                 targetRotation: 0, differenceLabel: "different shape"),
        // Set C (rounds 5-6): subtle shape
        ThemeSet(distractorSymbol: "circle.fill", targetSymbol: "square.fill",
                 distractorColor: .teal, targetColor: .teal,
                 targetRotation: 0, differenceLabel: "different shape"),
        // Set D (rounds 7-8): compound difference (color + rotation)
        ThemeSet(distractorSymbol: "triangle.fill", targetSymbol: "triangle.fill",
                 distractorColor: .cyan, targetColor: .pink,
                 targetRotation: 180, differenceLabel: "rotated + different color"),
    ]

    // MARK: - Public interface

    func startGame(eloRating: Double) {
        let params = EloSystem.visualSearchParams(eloRating)
        _ = params   // used for reference; we use round-based progression below
        round = 0
        correctCount = 0
        totalPoints = 0
        tappedIndex = nil
        roundResult = nil
        speedLabel = nil
        gameResult = nil
        showGameOver = false
        beginNextRound()
    }

    func cellTapped(index: Int, combo: ComboTracker) {
        guard gameState == .playing else { return }
        timerTask?.cancel()
        tappedIndex = index
        let correct = cells[index].isTarget
        roundResult = correct

        if correct {
            correctCount += 1
            let elapsed = roundStartTime.map { Date().timeIntervalSince($0) } ?? 99
            let (pts, label) = speedPoints(elapsed: elapsed, combo: combo)
            totalPoints += pts
            speedLabel = label
            combo.markCorrect()
            SoundEngine.shared.playCorrect(streak: combo.streak)
            Haptics.light()
        } else {
            combo.markWrong()
            speedLabel = nil
            SoundEngine.shared.playWrong()
            Haptics.error()
        }

        gameState = .roundResult

        timerTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            speedLabel = nil
            advanceAfterResult()
        }
    }

    // MARK: - Private

    private func beginNextRound() {
        round += 1
        tappedIndex = nil
        roundResult = nil
        speedLabel = nil
        cells = buildGrid(round: round)
        roundTimeRemaining = roundDuration(round: round)
        roundStartTime = Date()
        gameState = .playing
        startTimer()
    }

    private func roundDuration(round: Int) -> Double {
        switch round {
        case 1, 2: return 5.0
        case 3, 4: return 4.0
        case 5, 6: return 4.0
        default:   return 3.0   // rounds 7-8
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        let duration = roundTimeRemaining
        timerTask = Task {
            let tickInterval = 0.05
            var elapsed = 0.0
            while roundTimeRemaining > 0 {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard !Task.isCancelled else { return }
                elapsed += tickInterval
                roundTimeRemaining = max(0, duration - elapsed)
            }
            guard !Task.isCancelled, gameState == .playing else { return }
            // Time expired — wrong
            tappedIndex = nil
            roundResult = false
            speedLabel = nil
            SoundEngine.shared.playWrong()
            Haptics.error()
            gameState = .roundResult
            timerTask = Task {
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled else { return }
                advanceAfterResult()
            }
        }
    }

    private func advanceAfterResult() {
        if round >= Self.totalRounds {
            gameState = .finished
            onGameOver?(correctCount, totalPoints)
        } else {
            beginNextRound()
        }
    }

    // MARK: - Speed-based scoring

    private func speedPoints(elapsed: Double, combo: ComboTracker) -> (Int, String?) {
        let base: Int
        let label: String?
        if elapsed < 0.5 {
            base = 100; label = "EAGLE EYE!"
        } else if elapsed < 1.0 {
            base = 75; label = "SHARP!"
        } else if elapsed < 2.0 {
            base = 50; label = nil
        } else if elapsed < 3.0 {
            base = 25; label = nil
        } else {
            return (0, nil)
        }
        return (combo.apply(base), label)
    }

    // MARK: - Grid builder

    private func buildGrid(round: Int) -> [SearchCell] {
        let cellCount = gridCellCount(round: round)
        let setIndex = (round - 1) / 2  // 0-indexed theme set
        let theme = themeSets[min(setIndex, themeSets.count - 1)]

        var result: [SearchCell] = (0..<(cellCount - 1)).map { _ in
            SearchCell(symbol: theme.distractorSymbol, color: theme.distractorColor,
                       isTarget: false, rotation: 0)
        }
        let target = SearchCell(symbol: theme.targetSymbol, color: theme.targetColor,
                                isTarget: true, rotation: theme.targetRotation)
        let insertPos = Int.random(in: 0...result.count)
        result.insert(target, at: insertPos)
        targetIndex = insertPos
        return result
    }

    private func gridCellCount(round: Int) -> Int {
        switch round {
        case 1, 2: return 9    // 3×3
        case 3, 4: return 16   // 4×4
        case 5, 6: return 16   // 4×4
        default:   return 25   // 5×5
        }
    }

    func columnCount(for cellCount: Int) -> Int {
        switch cellCount {
        case 9:  return 3
        case 16: return 4
        case 25: return 5
        default: return 3
        }
    }
}

// MARK: - View

struct VisualSearchGameView: View {
    @StateObject private var vm = VisualSearchViewModel()
    @StateObject private var combo = ComboTracker()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("visualDifficulty") private var difficulty: Difficulty = .medium

    @State private var showGameOver = false
    @State private var gridRevealTrigger: UUID = UUID()  // changes each new round to trigger stagger

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        ZStack {
            switch vm.gameState {
            case .idle:
                idleView
            case .playing, .roundResult:
                playingView
            case .finished:
                Color.clear
            }
        }
        .overlay {
            if showGameOver, let result = vm.gameResult {
                GameOverView(result: result) {
                    showGameOver = false
                    vm.gameState = .idle
                    combo.reset()
                }
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGameOver)
        .navigationTitle("Odd One Out")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correctCount, totalPoints in
                let isNewBest = totalPoints > stats.visualBestScore
                let brainScore = PlayerStats.visualBrainScore(correct: correctCount)
                let session = GameSession(
                    gameType: "visual",
                    rawScore: totalPoints,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordVisualGame(correct: correctCount)
                // Elo update: correct if 6+ rounds found
                stats.visualSearchEloRating = EloSystem.updated(
                    stats.visualSearchEloRating,
                    correct: correctCount >= 6
                )

                let result = GameResult(
                    gameTitle: "Odd One Out",
                    primaryScore: totalPoints,
                    primaryLabel: "pts",
                    brainScore: brainScore,
                    previousBrainScore: stats.visualBrainScore,
                    isNewBest: isNewBest,
                    multiplierBreakdown: nil,
                    percentileText: PlayerStats.percentileLabel(for: brainScore),
                    accentColor: .pink,
                    share: GameResult.ShareConfig(
                        gameName: "Odd One Out",
                        icon: "eye.fill",
                        color: .pink,
                        primaryValue: "\(totalPoints)",
                        primaryLabel: "pts",
                        secondaryLine: "\(correctCount)/\(VisualSearchViewModel.totalRounds) found"
                    )
                )
                vm.gameResult = result
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation { showGameOver = true }
                }
            }
        }
        .onChange(of: vm.round) { _, _ in
            gridRevealTrigger = UUID()
        }
    }

    // MARK: - Idle View

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.pink)
                Text("Odd One Out")
                    .font(.largeTitle.bold())
                Text("Find the item that doesn't belong\nbefore time runs out.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.visualBestScore > 0 {
                    Label("Best: \(stats.visualBestScore) pts", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
                // Auto difficulty badge
                VisualAutoDiffBadge(eloRating: stats.visualSearchEloRating)
            }
            Spacer()
            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)
            Button {
                showGameOver = false
                combo.reset()
                vm.startGame(eloRating: stats.visualSearchEloRating)
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Playing View

    var playingView: some View {
        VStack(spacing: 0) {
            // Stat badges + multiplier
            HStack {
                StatBadge(
                    label: "Round",
                    value: "\(min(vm.round, VisualSearchViewModel.totalRounds))/\(VisualSearchViewModel.totalRounds)",
                    color: .pink
                )
                Spacer()
                // Speed label flash
                if let label = vm.speedLabel {
                    Text(label)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange.opacity(0.6), radius: 4)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: label)
                }
                Spacer()
                MultiplierBadgeView(combo: combo, color: .pink)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Points + timer row
            HStack {
                StatBadge(label: "Points", value: "\(vm.totalPoints)", color: .pink)
                Spacer()
                StatBadge(label: "Found", value: "\(vm.correctCount)", color: .green)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Timer bar
            timerBar
                .padding(.horizontal)
                .padding(.bottom, 12)

            // Grid
            gridView
                .padding(.horizontal)

            Spacer()
        }
    }

    var timerBar: some View {
        let totalDur = roundDuration(for: vm.round)
        let fraction = totalDur > 0 ? vm.roundTimeRemaining / totalDur : 0
        let barColor: Color = fraction > 0.5 ? .pink : fraction > 0.25 ? .orange : .red

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

    private func roundDuration(for round: Int) -> Double {
        switch round {
        case 1, 2: return 5.0
        case 3, 4: return 4.0
        case 5, 6: return 4.0
        default:   return 3.0
        }
    }

    var gridView: some View {
        let cellCount = vm.cells.count
        let cols = vm.columnCount(for: cellCount)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: cols)
        let centerIndex = cellCount / 2

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(vm.cells.enumerated()), id: \.element.id) { index, cell in
                cellView(cell: cell, index: index, centerIndex: centerIndex)
            }
        }
        .id(gridRevealTrigger)  // force full re-render on new round for stagger animation
    }

    @ViewBuilder
    func cellView(cell: VisualSearchViewModel.SearchCell, index: Int, centerIndex: Int) -> some View {
        let tapped = vm.tappedIndex == index
        let isRoundOver = vm.gameState == .roundResult
        let flashColor: Color? = {
            guard isRoundOver, tapped else { return nil }
            return (vm.roundResult == true) ? .green : .red
        }()
        let showMissedTarget = isRoundOver && vm.roundResult == false && vm.tappedIndex == nil && cell.isTarget
        let staggerDelay = Double(abs(index - centerIndex)) * 0.030

        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(flashColor.map { $0.opacity(0.2) } ?? Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            showMissedTarget ? Color.red.opacity(0.6) :
                            (flashColor.map { $0.opacity(0.6) } ?? Color(.systemGray4)),
                            lineWidth: showMissedTarget || tapped ? 2 : 1
                        )
                )

            Image(systemName: cell.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(cell.color)
                .rotationEffect(.degrees(cell.rotation))
        }
        .frame(height: 56)
        .scaleEffect(tapped ? 1.12 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: tapped)
        .juiceBounce(trigger: tapped && cell.isTarget)
        .onTapGesture {
            guard vm.gameState == .playing else { return }
            vm.cellTapped(index: index, combo: combo)
        }
        // Staggered pop-in animation from center outward
        .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
        .animation(
            .spring(response: 0.35, dampingFraction: 0.65)
            .delay(staggerDelay),
            value: gridRevealTrigger
        )
    }
}

// MARK: - VisualAutoDiffBadge

private struct VisualAutoDiffBadge: View {
    let eloRating: Double

    private var label: String {
        switch eloRating {
        case ..<1000: return "Auto · Easy"
        case 1000..<1100: return "Auto · Medium"
        default: return "Auto · Hard"
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(.systemGray5), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { VisualSearchGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
