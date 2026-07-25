import SwiftUI
import SwiftData

// Bounce Cast: memorize hidden diagonal bumpers, then predict where the ball
// exits a 5x5 grid after bouncing through them (working memory + mental simulation).

// MARK: - Board Model

enum BounceDirection: Equatable {
    case up, down, left, right

    // Row 0 is the top of the board: "up" decreases row, "down" increases row.
    var dx: Int {
        switch self {
        case .left:  return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up:   return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }

    var spokenName: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
}

enum BounceBumper: CaseIterable {
    case slash      // "/"
    case backslash  // "\"
}

struct BounceCell: Hashable {
    let row: Int
    let col: Int

    var isInside: Bool { (0..<5).contains(row) && (0..<5).contains(col) }
}

enum BounceEdge: Hashable {
    case top, bottom, left, right

    var spokenName: String {
        switch self {
        case .top: return "top"
        case .bottom: return "bottom"
        case .left: return "left"
        case .right: return "right"
        }
    }
}

struct BounceEdgeSlot: Hashable {
    let edge: BounceEdge
    let index: Int  // column for top/bottom, row for left/right (0-based)

    var entryDirection: BounceDirection {
        switch edge {
        case .top: return .down
        case .bottom: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    var entryCell: BounceCell {
        switch edge {
        case .top: return BounceCell(row: 0, col: index)
        case .bottom: return BounceCell(row: 4, col: index)
        case .left: return BounceCell(row: index, col: 0)
        case .right: return BounceCell(row: index, col: 4)
        }
    }

    var entryArrowIcon: String {
        switch edge {
        case .top: return "arrow.down"
        case .bottom: return "arrow.up"
        case .left: return "arrow.right"
        case .right: return "arrow.left"
        }
    }

    var positionDescription: String {
        switch edge {
        case .top, .bottom: return "column \(index + 1)"
        case .left, .right: return "row \(index + 1)"
        }
    }
}

// MARK: - View Model

@MainActor
final class BounceCastViewModel: ObservableObject {
    enum GameState { case idle, countdown, playing, gameOver }
    enum Phase { case memorize, predict, reveal }

    @Published var gameState: GameState = .idle
    @Published var phase: Phase = .memorize
    @Published var round: Int = 1
    @Published var correctCount: Int = 0
    @Published var totalBumpersCrossed: Int = 0
    @Published var bumpers: [BounceCell: BounceBumper] = [:]
    @Published var entrySlot: BounceEdgeSlot? = nil
    @Published var exitSlot: BounceEdgeSlot? = nil
    @Published var selectedSlot: BounceEdgeSlot? = nil
    @Published var ballCell: BounceCell? = nil
    @Published var roundResult: Bool? = nil   // nil until the reveal lands
    @Published var memorizeProgress: Double = 1
    @Published var showNewBest = false
    @Published var wasNewBest = false
    @Published var finalCorrect: Int = 0
    @Published var finalBrainScore: Int = 0
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    static let totalRounds = 8

    var onGameOver: ((Int) -> Void)?  // passes correct round count

    private var difficulty: Difficulty = .medium
    private var path: [BounceCell] = []
    private var roundBumpersCrossed = 0
    private var memorizeTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?

    var bumpersVisible: Bool { phase == .memorize || phase == .reveal }

    var memorizeDuration: Double {
        switch difficulty {
        case .easy: return 2.5
        case .medium: return 2.0
        case .hard: return 1.5
        }
    }

    private var bumperCountRange: ClosedRange<Int> {
        switch difficulty {
        case .easy: return 2...3
        case .medium: return 3...4
        case .hard: return 4...5
        }
    }

    private var minCrossings: Int {
        difficulty == .easy ? 1 : 2
    }

    // MARK: Flow

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        memorizeTask?.cancel()
        revealTask?.cancel()
        round = 1
        correctCount = 0
        totalBumpersCrossed = 0
        showNewBest = false
        wasNewBest = false
        bumpers = [:]
        entrySlot = nil
        exitSlot = nil
        selectedSlot = nil
        ballCell = nil
        roundResult = nil
        phase = .memorize
        gameState = .countdown
    }

    func beginPlay() {
        guard gameState == .countdown else { return }
        gameState = .playing
        startRound()
    }

    func abandon() {
        memorizeTask?.cancel()
        memorizeTask = nil
        revealTask?.cancel()
        revealTask = nil
    }

    private func startRound() {
        let generated = Self.generateRound(
            bumperCount: Int.random(in: bumperCountRange),
            minCrossings: minCrossings
        )
        bumpers = generated.bumpers
        entrySlot = generated.entry
        exitSlot = generated.exit
        path = generated.path
        roundBumpersCrossed = generated.bumpersCrossed
        selectedSlot = nil
        ballCell = nil
        roundResult = nil
        memorizeProgress = 1
        phase = .memorize

        memorizeTask?.cancel()
        memorizeTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            self.memorizeProgress = 0  // view animates the drain
            try? await Task.sleep(for: .seconds(self.memorizeDuration))
            guard !Task.isCancelled else { return }
            self.phase = .predict
        }
    }

    func selectSlot(_ slot: BounceEdgeSlot) {
        guard gameState == .playing, phase == .predict, selectedSlot == nil else { return }
        selectedSlot = slot
        Haptics.light()
        startReveal()
    }

    private func startReveal() {
        phase = .reveal
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            guard let self else { return }
            for cell in self.path {
                guard !Task.isCancelled else { return }
                self.ballCell = cell
                try? await Task.sleep(for: .milliseconds(120))
            }
            guard !Task.isCancelled else { return }
            self.ballCell = nil
            let correct = self.selectedSlot == self.exitSlot
            self.roundResult = correct
            self.totalBumpersCrossed += self.roundBumpersCrossed
            if correct {
                self.correctCount += 1
                Haptics.success()
            } else {
                Haptics.error()
            }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            if self.round >= Self.totalRounds {
                self.endGame()
            } else {
                self.round += 1
                self.startRound()
            }
        }
    }

    private func endGame() {
        memorizeTask?.cancel()
        memorizeTask = nil
        finalCorrect = correctCount
        finalBrainScore = PlayerStats.bounceBrainScore(correct: correctCount)
        onGameOver?(correctCount)
        gameState = .gameOver
    }

    // MARK: - Physics (pure)

    static func reflect(_ direction: BounceDirection, off bumper: BounceBumper) -> BounceDirection {
        switch bumper {
        case .slash:      // "/"  right→up, up→right, left→down, down→left
            switch direction {
            case .right: return .up
            case .up:    return .right
            case .left:  return .down
            case .down:  return .left
            }
        case .backslash:  // "\"  right→down, down→right, left→up, up→left
            switch direction {
            case .right: return .down
            case .down:  return .right
            case .left:  return .up
            case .up:    return .left
            }
        }
    }

    static func exitSlot(leaving cell: BounceCell, moving direction: BounceDirection) -> BounceEdgeSlot {
        switch direction {
        case .up:    return BounceEdgeSlot(edge: .top, index: cell.col)
        case .down:  return BounceEdgeSlot(edge: .bottom, index: cell.col)
        case .left:  return BounceEdgeSlot(edge: .left, index: cell.row)
        case .right: return BounceEdgeSlot(edge: .right, index: cell.row)
        }
    }

    static func simulate(
        entry: BounceEdgeSlot,
        bumpers: [BounceCell: BounceBumper]
    ) -> (exit: BounceEdgeSlot, path: [BounceCell], bumpersCrossed: Int) {
        var direction = entry.entryDirection
        var cell = entry.entryCell
        var visited: [BounceCell] = []
        var crossed = 0
        var steps = 0
        while steps < 100 {  // mirror mazes cannot loop; cap is a safety net
            steps += 1
            visited.append(cell)
            if let bumper = bumpers[cell] {
                crossed += 1
                direction = Self.reflect(direction, off: bumper)
            }
            let next = BounceCell(row: cell.row + direction.dy, col: cell.col + direction.dx)
            if !next.isInside {
                return (Self.exitSlot(leaving: cell, moving: direction), visited, crossed)
            }
            cell = next
        }
        return (Self.exitSlot(leaving: cell, moving: direction), visited, crossed)
    }

    static func randomEdgeSlot() -> BounceEdgeSlot {
        let edges: [BounceEdge] = [.top, .bottom, .left, .right]
        let edge = edges.randomElement() ?? .top
        return BounceEdgeSlot(edge: edge, index: Int.random(in: 0...4))
    }

    static func randomBumpers(count: Int) -> [BounceCell: BounceBumper] {
        var cells: [BounceCell] = []
        for row in 0..<5 {
            for col in 0..<5 {
                cells.append(BounceCell(row: row, col: col))
            }
        }
        var result: [BounceCell: BounceBumper] = [:]
        for cell in cells.shuffled().prefix(count) {
            result[cell] = BounceBumper.allCases.randomElement() ?? .slash
        }
        return result
    }

    static func generateRound(
        bumperCount: Int,
        minCrossings: Int
    ) -> (bumpers: [BounceCell: BounceBumper], entry: BounceEdgeSlot, exit: BounceEdgeSlot, path: [BounceCell], bumpersCrossed: Int) {
        let entry = randomEdgeSlot()
        var bumpers = randomBumpers(count: bumperCount)
        var result = simulate(entry: entry, bumpers: bumpers)
        var attempts = 0
        while result.bumpersCrossed < minCrossings && attempts < 50 {
            attempts += 1
            bumpers = randomBumpers(count: bumperCount)
            result = simulate(entry: entry, bumpers: bumpers)
        }
        return (bumpers, entry, result.exit, result.path, result.bumpersCrossed)
    }
}

// MARK: - Bumper Shape

struct BounceBumperStroke: Shape {
    let orientation: BounceBumper

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch orientation {
        case .slash:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .backslash:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return p
    }
}

// MARK: - View

struct BounceCastGameView: View {
    @StateObject private var vm = BounceCastViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("bounceDifficulty") private var difficulty: Difficulty = .medium

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
        .navigationTitle("Bounce Cast")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { correct in
                vm.wasNewBest = correct > 0 && correct > stats.bounceBestScore
                let session = GameSession(
                    gameType: "bounce",
                    rawScore: correct,
                    brainScore: PlayerStats.bounceBrainScore(correct: correct),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordBounceGame(correct: correct)
                let newAchievements = checkAndUnlock(stats: stats)
                if vm.wasNewBest {
                    vm.showNewBest = true
                    Haptics.success()
                    Task { try? await Task.sleep(for: .seconds(2)); vm.showNewBest = false }
                }
                if leveledUp {
                    vm.leveledUpTo = stats.playerLevel
                    Task { try? await Task.sleep(for: .seconds(2.5)); vm.leveledUpTo = nil }
                }
                if let first = newAchievements.first {
                    let delay = (vm.wasNewBest || leveledUp) ? 2.8 : 0.3
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
            ZStack {
                playView.opacity(0.25)
                CountdownOverlay { vm.beginPlay() }
            }
        case .playing:
            playView
        case .gameOver:
            gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "arrow.uturn.right.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.cyan)
                Text("Bounce Cast")
                    .font(.largeTitle.bold())
                Text("Memorize the bumpers, then predict\nwhere the ball exits.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.bounceBestScore > 0 {
                    Label("Record: \(stats.bounceBestScore)/8", systemImage: "trophy.fill")
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
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 16) {
            HStack {
                StatBadge(label: "Round", value: "\(vm.round)/\(BounceCastViewModel.totalRounds)", color: .cyan)
                Spacer()
                StatBadge(label: "Correct", value: "\(vm.correctCount)", color: .green)
                Spacer()
                StatBadge(label: "Best", value: "\(stats.bounceBestScore)/8", color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text(phasePrompt)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(height: 24)

            memorizeBar

            boardView

            Spacer(minLength: 12)
        }
    }

    var phasePrompt: String {
        switch vm.phase {
        case .memorize:
            return "Memorize the bumpers"
        case .predict:
            return "Tap where the ball will exit"
        case .reveal:
            if let result = vm.roundResult {
                return result ? "Correct!" : "Missed!"
            }
            return "Watch the ball…"
        }
    }

    var memorizeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                if vm.phase == .memorize {
                    Capsule()
                        .fill(Color.cyan)
                        .frame(width: max(0, geo.size.width) * CGFloat(vm.memorizeProgress))
                }
            }
        }
        .frame(height: 6)
        .padding(.horizontal)
        .animation(.linear(duration: vm.memorizeDuration), value: vm.memorizeProgress)
    }

    // MARK: - Board

    var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            if side > 0 {
                let cellSize = side / 7
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { col in
                                gridCell(row: row, col: col, size: cellSize)
                            }
                        }
                    }
                }
                .frame(width: side, height: side)
                .overlay {
                    if let result = vm.roundResult {
                        RoundedRectangle(cornerRadius: 16)
                            .fill((result ? Color.green : Color.red).opacity(0.15))
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: vm.roundResult)
    }

    private func boardCell(row: Int, col: Int) -> BounceCell? {
        guard (1...5).contains(row), (1...5).contains(col) else { return nil }
        return BounceCell(row: row - 1, col: col - 1)
    }

    private func edgeSlot(row: Int, col: Int) -> BounceEdgeSlot? {
        if row == 0, (1...5).contains(col) { return BounceEdgeSlot(edge: .top, index: col - 1) }
        if row == 6, (1...5).contains(col) { return BounceEdgeSlot(edge: .bottom, index: col - 1) }
        if col == 0, (1...5).contains(row) { return BounceEdgeSlot(edge: .left, index: row - 1) }
        if col == 6, (1...5).contains(row) { return BounceEdgeSlot(edge: .right, index: row - 1) }
        return nil
    }

    @ViewBuilder
    private func gridCell(row: Int, col: Int, size: CGFloat) -> some View {
        if let cell = boardCell(row: row, col: col) {
            innerCell(cell, size: size)
        } else if let slot = edgeSlot(row: row, col: col) {
            slotView(slot, size: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func innerCell(_ cell: BounceCell, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(Color(.secondarySystemBackground))
                .padding(2)
            if vm.bumpersVisible, let orientation = vm.bumpers[cell] {
                BounceBumperStroke(orientation: orientation)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: max(3, size * 0.1), lineCap: .round))
                    .padding(size * 0.24)
            }
            if vm.ballCell == cell {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: size * 0.45, height: size * 0.45)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func slotView(_ slot: BounceEdgeSlot, size: CGFloat) -> some View {
        Button { vm.selectSlot(slot) } label: {
            ZStack {
                Circle()
                    .fill(slotFill(slot))
                if vm.selectedSlot == slot {
                    Circle().stroke(Color.cyan, lineWidth: 3)
                }
                if vm.entrySlot == slot {
                    Image(systemName: slot.entryArrowIcon)
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size * 0.62, height: size * 0.62)
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(slotAccessibilityLabel(slot))
    }

    private func slotFill(_ slot: BounceEdgeSlot) -> Color {
        if vm.entrySlot == slot { return .cyan }
        if let result = vm.roundResult {
            if vm.exitSlot == slot { return .green }
            if !result && vm.selectedSlot == slot { return .red }
        }
        if vm.selectedSlot == slot { return Color.cyan.opacity(0.35) }
        return Color(.systemGray4)
    }

    private func slotAccessibilityLabel(_ slot: BounceEdgeSlot) -> String {
        if vm.entrySlot == slot {
            let dir = slot.entryDirection.spokenName
            return "Ball enters from \(slot.edge.spokenName) edge, \(slot.positionDescription), moving \(dir)"
        }
        return "Exit slot, \(slot.edge.spokenName) edge, \(slot.positionDescription)"
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "arrow.uturn.right.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.cyan)

                Text("Results")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    ResultRow(label: "Correct Rounds", value: "\(vm.finalCorrect)/8", color: .cyan)
                    ResultRow(label: "Bumpers Navigated", value: "\(vm.totalBumpersCrossed)", color: .teal)
                    Divider()
                    ResultRow(label: "Brain Score", value: "\(vm.finalBrainScore)", color: .indigo)
                    ResultRow(label: "All-Time Best", value: "\(stats.bounceBestScore)/8", color: .secondary)
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
                gameName: "Bounce Cast", gameIcon: "arrow.uturn.right.circle.fill", gameColor: .cyan,
                primaryValue: "\(vm.finalCorrect)/8", primaryLabel: "rounds",
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
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    NavigationStack { BounceCastGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
