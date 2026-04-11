import SwiftUI
import SwiftData

// Star Map — Spatial memory game with night-sky theme, partial-credit scoring,
// constellation lines, Delayed Recall mode, Elo difficulty, and combo scoring.

// MARK: - Recall Mode

enum StarMapRecallMode: String, CaseIterable, Identifiable {
    case instant = "Instant"
    case delayed = "Delayed"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .instant: return "Recall immediately"
        case .delayed: return "Solve a math problem first"
        }
    }
}

// MARK: - GameState

extension SpatialMemoryViewModel {
    enum GameState: Equatable {
        case idle, showing, distractor, input, feedback, gameOver
    }
}

// MARK: - Distractor Question

private struct DistractorQuestion {
    let text: String
    let correctAnswer: Int
    let options: [Int]

    static func random() -> DistractorQuestion {
        let a = Int.random(in: 2...12)
        let b = Int.random(in: 2...12)
        let answer = a + b
        var opts = Set([answer])
        while opts.count < 2 {
            opts.insert(answer + Int.random(in: -4...4).nonZero)
        }
        let shuffled = opts.sorted().shuffled()
        return DistractorQuestion(text: "\(a) + \(b) = ?", correctAnswer: answer, options: shuffled)
    }
}

private extension Int {
    var nonZero: Int { self == 0 ? 1 : self }
}

// MARK: - ViewModel

@MainActor
class SpatialMemoryViewModel: ObservableObject {

    // MARK: Published state
    @Published var gameState: GameState = .idle
    @Published var round: Int = 1
    @Published var totalScore: Int = 0
    @Published var targetCells: Set<Int> = []
    @Published var litCells: Set<Int> = []
    @Published var tappedCells: [Int] = []   // ordered for constellation lines
    @Published var correctTaps: Set<Int> = []
    @Published var missedCells: Set<Int> = []
    @Published var falseAlarms: Set<Int> = []
    @Published var roundScorePercent: Int = 0
    @Published var showFeedback: Bool = false
    @Published var distractorQuestion: DistractorQuestion? = nil
    @Published var twinklePhase: Bool = false

    // Elo-driven params
    var gridSize: Int = 4
    var cellCount: Int = 4
    var displayTime: Double = 1.5

    // Game over
    @Published var finalScore: Int = 0
    @Published var roundScores: [Int] = []    // to compute avg
    var onGameOver: ((Int, Double) -> Void)?  // finalScore, avgRoundScore

    private var playbackTask: Task<Void, Never>?
    private var recallMode: StarMapRecallMode = .instant

    var totalCells: Int { gridSize * gridSize }

    var avgRoundScore: Double {
        guard !roundScores.isEmpty else { return 0 }
        return Double(roundScores.reduce(0, +)) / Double(roundScores.count)
    }

    // MARK: Status message
    var statusMessage: String {
        switch gameState {
        case .idle:       return "Tap Start to begin"
        case .showing:    return "Watch carefully…"
        case .distractor: return "Solve this first!"
        case .input:      return "Tap the stars!"
        case .feedback:   return roundScorePercent >= 50 ? "Round complete!" : "Game Over"
        case .gameOver:   return "Session complete"
        }
    }

    // MARK: Configure from Elo params
    func configure(params: EloSystem.SpatialParams, mode: StarMapRecallMode) {
        gridSize = params.gridSize
        cellCount = params.cellCount
        displayTime = params.displayTime
        recallMode = mode
    }

    // MARK: Start Game
    func startGame(params: EloSystem.SpatialParams, mode: StarMapRecallMode) {
        configure(params: params, mode: mode)
        totalScore = 0
        round = 1
        roundScores = []
        finalScore = 0
        gameState = .showing
        beginShowPhase()
    }

    // MARK: Show Phase
    private func beginShowPhase() {
        tappedCells = []
        correctTaps = []
        missedCells = []
        falseAlarms = []
        showFeedback = false

        // Pick `cellCount` distinct random cells
        let indices = Array(0..<totalCells).shuffled()
        let chosen = Set(indices.prefix(cellCount))
        targetCells = chosen

        playbackTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.18)) {
                litCells = chosen
            }
            // Twinkle: oscillate scale by toggling phase repeatedly
            for _ in 0..<4 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(200))
                twinklePhase.toggle()
            }
            try? await Task.sleep(for: .seconds(max(0, displayTime - 0.8)))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.25)) {
                litCells = []
            }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            if recallMode == .delayed {
                distractorQuestion = DistractorQuestion.random()
                gameState = .distractor
                // Auto-advance after 3 seconds if not answered
                try? await Task.sleep(for: .seconds(3.2))
                guard !Task.isCancelled else { return }
                if gameState == .distractor {
                    distractorQuestion = nil
                    gameState = .input
                }
            } else {
                gameState = .input
            }
        }
    }

    // MARK: Distractor answer
    func answerDistractor(_ answer: Int) {
        playbackTask?.cancel()
        distractorQuestion = nil
        gameState = .input
    }

    // MARK: Cell tap
    func cellTapped(_ index: Int) {
        guard gameState == .input else { return }
        guard !tappedCells.contains(index) else { return }

        tappedCells.append(index)
        Haptics.medium()

        if tappedCells.count == targetCells.count {
            evaluateRound()
        }
    }

    // MARK: Partial credit evaluation
    private func evaluateRound() {
        let tappedSet = Set(tappedCells)
        let correct = tappedSet.intersection(targetCells)
        let missed  = targetCells.subtracting(tappedSet)
        let false_  = tappedSet.subtracting(targetCells)

        correctTaps = correct
        missedCells = missed
        falseAlarms = false_

        let pct = max(0, (correct.count - false_.count)) * 100 / max(1, targetCells.count)
        roundScorePercent = pct
        totalScore += pct
        roundScores.append(pct)

        showFeedback = true
        gameState = .feedback

        if pct >= 50 {
            SoundEngine.shared.playCorrect()
            SoundEngine.shared.playMelodyCascade(tileCount: 5)
            Haptics.success()
        } else {
            SoundEngine.shared.playWrong()
            Haptics.error()
        }

        playbackTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if pct >= 50 {
                round += 1
                gameState = .showing
                beginShowPhase()
            } else {
                finalScore = totalScore
                gameState = .gameOver
                onGameOver?(totalScore, avgRoundScore)
            }
        }
    }
}

// MARK: - View

struct SpatialMemoryGameView: View {
    @StateObject private var vm = SpatialMemoryViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("spatialDifficulty") private var difficulty: Difficulty = .medium
    @State private var recallMode: StarMapRecallMode = .instant
    @State private var showGameOver = false
    @State private var gameResult: GameResult? = nil

    // Floating star particles
    @State private var starParticles: [StarParticle] = (0..<10).map { _ in StarParticle() }
    @State private var starAnimate: Bool = false

    // Constellation line trim animation
    @State private var lineTrim: CGFloat = 0.0

    private static let navyBackground = Color(red: 0.03, green: 0.04, blue: 0.12)

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        ZStack {
            // Night sky background
            Self.navyBackground
                .ignoresSafeArea()

            // Floating star particles
            starParticleLayer

            if showGameOver, let result = gameResult {
                GameOverView(result: result) {
                    showGameOver = false
                    gameResult = nil
                    startGame()
                }
                .background(Self.navyBackground.ignoresSafeArea())
                .transition(.opacity)
                .zIndex(20)
            } else {
                gameContent
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGameOver)
        .navigationTitle("Star Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            setupGameOverHandler()
            starAnimate = true
        }
    }

    // MARK: - Star Particle Layer

    var starParticleLayer: some View {
        GeometryReader { geo in
            ForEach(starParticles) { p in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 2, height: 2)
                    .offset(
                        x: p.x * geo.size.width,
                        y: starAnimate ? p.yEnd * geo.size.height : p.yStart * geo.size.height
                    )
                    .animation(
                        .easeInOut(duration: p.duration)
                        .repeatForever(autoreverses: true)
                        .delay(p.delay),
                        value: starAnimate
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Content Router

    @ViewBuilder
    var gameContent: some View {
        switch vm.gameState {
        case .idle:
            idleScreen
        case .distractor:
            distractorView
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
                            .fill(Color.indigo.opacity(0.20))
                            .frame(width: 96, height: 96)
                        Image(systemName: "star.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.yellow.gradient)
                    }

                    Text("Star Map")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Watch which stars light up, then tap them from memory.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                }

                if stats.spatialBestLevel > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Best: Round \(stats.spatialBestLevel)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.indigo.opacity(0.30), in: Capsule())
                }

                // Recall mode toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recall Mode")
                        .font(.caption.smallCaps())
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 10) {
                        ForEach(StarMapRecallMode.allCases) { mode in
                            Button {
                                recallMode = mode
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.rawValue)
                                        .font(.subheadline.bold())
                                    Text(mode.description)
                                        .font(.caption2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(recallMode == mode ? .white.opacity(0.85) : .secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    recallMode == mode
                                        ? Color.indigo.gradient
                                        : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .foregroundStyle(recallMode == mode ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)

                // Elo badge
                EloBadge(rating: stats.spatialEloRating, color: .indigo)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    DifficultyPicker(difficulty: $difficulty)
                        .padding(.horizontal)

                    Button {
                        startGame()
                    } label: {
                        Text("Start")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - Distractor View

    var distractorView: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Solve this first!")
                .font(.title2.bold())
                .foregroundStyle(.white)

            if let q = vm.distractorQuestion {
                Text(q.text)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)

                HStack(spacing: 20) {
                    ForEach(q.options, id: \.self) { opt in
                        Button {
                            vm.answerDistractor(opt)
                        } label: {
                            Text("\(opt)")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .frame(width: 90, height: 56)
                                .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Play Screen

    var playScreen: some View {
        VStack(spacing: 16) {
            // Top bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption.smallCaps()).foregroundStyle(.white.opacity(0.6))
                    AnimatedScoreText(value: vm.totalScore, font: .title2.bold(), color: .yellow)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Round").font(.caption.smallCaps()).foregroundStyle(.white.opacity(0.6))
                    Text("\(vm.round)")
                        .font(.title2.bold())
                        .foregroundStyle(.indigo)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best").font(.caption.smallCaps()).foregroundStyle(.white.opacity(0.6))
                    Text("\(stats.spatialBestLevel)")
                        .font(.title2.bold())
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal)

            // Status message
            Text(vm.statusMessage)
                .font(.headline)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: vm.statusMessage)
                .frame(minHeight: 24)

            // Grid
            starGrid

            // Constellation lines (feedback phase)
            if vm.gameState == .feedback {
                constellationOverlay
            }

            // Feedback legend
            if vm.showFeedback {
                feedbackLegend
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding(.vertical)
        .animation(.easeInOut(duration: 0.3), value: vm.showFeedback)
        .onChange(of: vm.gameState) { _, newState in
            if newState == .feedback {
                lineTrim = 0
                withAnimation(.easeInOut(duration: 0.3)) {
                    lineTrim = 1.0
                }
            }
        }
    }

    // MARK: - Star Grid

    var starGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: vm.gridSize)
        return GeometryReader { geo in
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<vm.totalCells, id: \.self) { index in
                    starCell(at: index, geo: geo)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: starGridHeight)
    }

    private var starGridHeight: CGFloat {
        let cellSize: CGFloat = (UIScreen.main.bounds.width - 40) / CGFloat(vm.gridSize)
        return cellSize * CGFloat(vm.gridSize) + 10 * CGFloat(vm.gridSize - 1)
    }

    @ViewBuilder
    private func starCell(at index: Int, geo: GeometryProxy) -> some View {
        let isLit = vm.litCells.contains(index)
        let isTapped = vm.tappedCells.contains(index)
        let isCorrect = vm.correctTaps.contains(index)
        let isMissed = vm.showFeedback && vm.missedCells.contains(index)
        let isFalse = vm.showFeedback && vm.falseAlarms.contains(index)

        ZStack {
            // Background cell: faint circle
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)

            // Lit star
            if isLit {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.6), radius: 8)
                    // 4-point radial glow: cross shape
                    .overlay(
                        ZStack {
                            Capsule().fill(Color.white.opacity(0.4))
                                .frame(width: 3, height: 20)
                            Capsule().fill(Color.white.opacity(0.4))
                                .frame(width: 20, height: 3)
                        }
                    )
                    .scaleEffect(vm.twinklePhase ? 1.12 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: vm.twinklePhase)
            }

            // Feedback overlays
            if isFalse {
                Circle().fill(Color.red.opacity(0.7))
            } else if isCorrect && vm.showFeedback {
                Circle().fill(Color.green.opacity(0.7))
            } else if isTapped && !isFalse && !isCorrect {
                Circle().fill(Color.white.opacity(0.35))
            } else if isMissed {
                Circle().fill(Color.orange.opacity(0.5))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isLit ? 1.15 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isLit)
        .onTapGesture {
            vm.cellTapped(index)
        }
        .allowsHitTesting(vm.gameState == .input)
    }

    // MARK: - Constellation Overlay

    var constellationOverlay: some View {
        GeometryReader { geo in
            let positions = cellCenters(gridSize: vm.gridSize, containerSize: geo.size)
            let tapped = vm.tappedCells

            Canvas { ctx, size in
                guard tapped.count > 1 else { return }
                var path = Path()
                for i in 0..<(tapped.count - 1) {
                    let from = positions[tapped[i]]
                    let to   = positions[tapped[i + 1]]
                    path.move(to: from)
                    path.addLine(to: to)
                }
                ctx.stroke(
                    path,
                    with: .color(.white.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }
            .mask(
                Rectangle()
                    .trim(from: 0, to: lineTrim)
                    .animation(.easeInOut(duration: 0.3), value: lineTrim)
            )
        }
        .frame(height: starGridHeight)
        .allowsHitTesting(false)
    }

    private func cellCenters(gridSize: Int, containerSize: CGSize) -> [CGPoint] {
        let padding: CGFloat = 16
        let spacing: CGFloat = 10
        let available = containerSize.width - padding * 2
        let cellSize  = (available - spacing * CGFloat(gridSize - 1)) / CGFloat(gridSize)

        var points = [CGPoint]()
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = padding + CGFloat(col) * (cellSize + spacing) + cellSize / 2
                let y = CGFloat(row) * (cellSize + spacing) + cellSize / 2
                points.append(CGPoint(x: x, y: y))
            }
        }
        return points
    }

    // MARK: - Feedback Legend

    var feedbackLegend: some View {
        HStack(spacing: 16) {
            legendDot(color: .green,  label: "Correct")
            legendDot(color: .orange, label: "Missed")
            legendDot(color: .red,    label: "Wrong")
            Spacer()
            Text("\(vm.roundScorePercent)%")
                .font(.title3.bold())
                .foregroundStyle(vm.roundScorePercent >= 50 ? .green : .red)
        }
        .font(.caption.bold())
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Status Color

    var statusColor: Color {
        switch vm.gameState {
        case .feedback: return vm.roundScorePercent >= 50 ? .green : .red
        case .gameOver: return .red
        default:        return .white
        }
    }

    // MARK: - Game Over Handler

    private func setupGameOverHandler() {
        vm.onGameOver = { score, avg in
            let isNewBest = vm.round > stats.spatialBestLevel
            let brainScore = PlayerStats.spatialBrainScore(level: vm.round)

            let session = GameSession(
                gameType: "spatial",
                rawScore: vm.round,
                brainScore: brainScore,
                difficulty: difficulty.rawValue
            )
            modelContext.insert(session)
            stats.recordSpatialGame(level: vm.round)

            // Update Elo
            stats.spatialEloRating = EloSystem.updated(stats.spatialEloRating, correct: avg >= 70)

            let result = GameResult(
                gameTitle: "Star Map",
                primaryScore: score,
                primaryLabel: "pts",
                brainScore: brainScore,
                previousBrainScore: stats.spatialBrainScore,
                isNewBest: isNewBest,
                multiplierBreakdown: nil,
                percentileText: PlayerStats.percentileLabel(for: brainScore),
                accentColor: .indigo,
                share: .init(
                    gameName: "Star Map",
                    icon: "star.fill",
                    color: .indigo,
                    primaryValue: "\(score)",
                    primaryLabel: "pts",
                    secondaryLine: "Round \(vm.round)"
                )
            )
            gameResult = result
            withAnimation { showGameOver = true }
        }
    }

    private func startGame() {
        let params = EloSystem.spatialParams(stats.spatialEloRating)
        vm.startGame(params: params, mode: recallMode)
    }
}

// MARK: - Star Particle Model

private struct StarParticle: Identifiable {
    let id = UUID()
    let x: CGFloat      = CGFloat.random(in: 0.02...0.98)
    let yStart: CGFloat = CGFloat.random(in: 0.0...0.45)
    let yEnd: CGFloat   = CGFloat.random(in: 0.55...1.0)
    let duration: Double = Double.random(in: 3.5...7.0)
    let delay: Double    = Double.random(in: 0.0...4.0)
}

// MARK: - Preview

#Preview {
    NavigationStack { SpatialMemoryGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
