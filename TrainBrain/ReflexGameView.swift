import SwiftUI
import SwiftData

// Lightning Tap — tap the glowing energy sphere as fast as you can.
// 8 normal rounds + 2 red gotcha rounds (randomly placed). Score 0-1000.

@MainActor
class ReflexGameViewModel: ObservableObject {
    static let normalRounds = 8
    static let gotchaCount  = 2
    static let totalRounds  = normalRounds + gotchaCount   // 10 total

    // MARK: Published State
    @Published var gameState: GameState = .idle
    @Published var targetVisible    = false
    @Published var isGotchaRound    = false
    @Published var targetX: CGFloat = 0
    @Published var targetY: CGFloat = 0
    @Published var lastReactionMs: Double? = nil
    @Published var tooEarly         = false
    @Published var reactionTimes: [Double] = []          // normal-round times only
    @Published var gotchaPenalties: [Double] = []        // 500ms added per gotcha tap
    @Published var currentCelebration: String? = nil
    @Published var showParticles    = false
    @Published var flashText: String? = nil
    @Published var flashId: UUID = UUID()
    @Published var orbBounce        = false
    @Published var gameResult: GameResult? = nil

    var containerSize: CGSize = CGSize(width: 300, height: 460)
    private var targetAppearTime: Date?
    private var waitTask: Task<Void, Never>?
    private var roundOrder: [Bool] = []   // false = normal, true = gotcha
    private var roundIndex = 0
    private(set) var targetSize: CGFloat = 88
    private var delayRange: ClosedRange<Double> = 1.0...3.0
    // Red orb avoidance tracking: when a gotcha appears this is set and we wait it out
    private var gotchaTimerTask: Task<Void, Never>?
    private var correctAvoidanceCount = 0

    enum GameState { case idle, waiting, targetShowing, gotchaShowing, roundResult, finished }

    var currentRound: Int { roundIndex + 1 }
    var isActiveRound: Bool { gameState == .waiting || gameState == .targetShowing || gameState == .gotchaShowing }

    var medianRT: Double {
        let sorted = reactionTimes.sorted()
        guard !sorted.isEmpty else { return 999 }
        let mid = sorted.count / 2
        return sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2.0
            : sorted[mid]
    }

    var averageRT: Double? {
        guard !reactionTimes.isEmpty else { return nil }
        return reactionTimes.reduce(0, +) / Double(reactionTimes.count)
    }

    var reflexScore: Int {
        max(0, min(1000, 1000 - Int((medianRT - 150) * 4)))
    }

    var letterGrade: String {
        switch reflexScore {
        case 900...: return "S"
        case 700..<900: return "A"
        case 500..<700: return "B"
        case 300..<500: return "C"
        default: return "D"
        }
    }

    var onGameOver: ((Double, Double, Int) -> Void)?   // (bestMs, medianMs, reflexScore)

    // MARK: - Game Flow

    func startGame(eloRating: Double) {
        let params = EloSystem.reflexParams(eloRating)
        targetSize = params.targetSize
        delayRange = params.delayMin...params.delayMax
        reactionTimes = []
        gotchaPenalties = []
        lastReactionMs = nil
        tooEarly = false
        currentCelebration = nil
        showParticles = false
        flashText = nil
        correctAvoidanceCount = 0
        gameResult = nil
        buildRoundOrder()
        roundIndex = 0
        nextRound()
    }

    private func buildRoundOrder() {
        var gotchaPositions = Set<Int>()
        while gotchaPositions.count < Self.gotchaCount {
            gotchaPositions.insert(Int.random(in: 0..<Self.totalRounds))
        }
        var full: [Bool] = []
        for i in 0..<Self.totalRounds {
            full.append(gotchaPositions.contains(i))
        }
        roundOrder = full
    }

    func nextRound() {
        guard roundIndex < Self.totalRounds else { return }
        targetVisible = false
        isGotchaRound = false
        tooEarly = false
        lastReactionMs = nil
        currentCelebration = nil
        showParticles = false
        gameState = .waiting

        let delay = Double.random(in: delayRange)
        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, gameState == .waiting else { return }
            showTarget()
        }
    }

    private func showTarget() {
        let pad: CGFloat = targetSize / 2 + 8
        targetX = CGFloat.random(in: pad...(containerSize.width - pad))
        targetY = CGFloat.random(in: pad...(containerSize.height - pad))
        isGotchaRound = roundOrder[roundIndex]
        targetVisible = true
        orbBounce = true
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            orbBounce = false
        }
        targetAppearTime = Date()
        gameState = isGotchaRound ? .gotchaShowing : .targetShowing

        if isGotchaRound {
            // Auto-advance after 1.8s if player doesn't tap (good avoidance)
            gotchaTimerTask?.cancel()
            gotchaTimerTask = Task {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled, gameState == .gotchaShowing else { return }
                gotchaAvoided()
            }
        }
    }

    // MARK: - Tap Handlers

    func targetTapped() {
        guard gameState == .targetShowing, let t0 = targetAppearTime else { return }
        let ms = Date().timeIntervalSince(t0) * 1000
        lastReactionMs = ms
        reactionTimes.append(ms)
        targetVisible = false
        gameState = .roundResult

        SoundEngine.shared.playCorrect()
        Haptics.light()

        flashText = String(format: "%.0fms", ms)
        flashId = UUID()
        showCelebration(for: ms)

        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled else { return }
            advanceAfterResult()
        }
    }

    func gotchaTapped() {
        guard gameState == .gotchaShowing else { return }
        gotchaTimerTask?.cancel()
        let penalty = 500.0
        gotchaPenalties.append(penalty)
        targetVisible = false
        gameState = .roundResult
        lastReactionMs = penalty

        SoundEngine.shared.playWrong()
        Haptics.error()

        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled else { return }
            advanceAfterResult()
        }
    }

    private func gotchaAvoided() {
        guard gameState == .gotchaShowing else { return }
        correctAvoidanceCount += 1
        targetVisible = false
        gameState = .roundResult
        lastReactionMs = nil   // no time to display

        SoundEngine.shared.playCorrect()
        Haptics.light()

        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            advanceAfterResult()
        }
    }

    func backgroundTapped() {
        guard gameState == .waiting else { return }
        waitTask?.cancel()
        tooEarly = true
        Haptics.error()
        SoundEngine.shared.playWrong()
        waitTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            nextRound()
        }
    }

    private func advanceAfterResult() {
        roundIndex += 1
        if roundIndex >= Self.totalRounds {
            finishGame()
        } else {
            nextRound()
        }
    }

    private func finishGame() {
        gameState = .finished
        let bestMs = reactionTimes.min() ?? 999
        let med    = medianRT
        let score  = reflexScore
        onGameOver?(bestMs, med, score)
    }

    // MARK: - Celebration

    private func showCelebration(for ms: Double) {
        guard ms < 250 else { return }
        if ms < 150 {
            currentCelebration = "SUPERHUMAN"
            showParticles = true
        } else if ms < 200 {
            currentCelebration = "INCREDIBLE"
        } else {
            currentCelebration = "FAST"
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            currentCelebration = nil
            showParticles = false
        }
    }
}

// MARK: - View

struct ReflexGameView: View {
    @StateObject private var vm = ReflexGameViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("reflexDifficulty") private var difficulty: Difficulty = .medium

    @State private var pulsingScale: CGFloat = 1.0
    @State private var showGameOver = false

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if vm.gameState == .idle {
                    idleView
                } else if vm.gameState == .finished || showGameOver {
                    Color.clear
                } else {
                    arenaHeader
                    arenaView
                }
            }

            // Celebration overlay
            if let cel = vm.currentCelebration {
                celebrationText(cel)
                    .allowsHitTesting(false)
                    .zIndex(20)
            }
        }
        .overlay {
            if showGameOver, let result = vm.gameResult {
                GameOverView(result: result) {
                    showGameOver = false
                    vm.gameState = .idle
                }
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showGameOver)
        .navigationTitle("Lightning Tap")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { bestMs, medianMs, score in
                let isNewBest = stats.reflexBestTimeMs == 0 || bestMs < stats.reflexBestTimeMs
                let brainScore = PlayerStats.reflexBrainScore(avgMs: medianMs)
                let session = GameSession(
                    gameType: "reflex",
                    rawScore: score,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordReflexGame(bestMs: bestMs, avgMs: medianMs)
                // Elo update: correct if median under 300ms
                stats.reflexEloRating = EloSystem.updated(stats.reflexEloRating, correct: medianMs < 300)

                let result = GameResult(
                    gameTitle: "Lightning Tap",
                    primaryScore: score,
                    primaryLabel: "score",
                    brainScore: brainScore,
                    previousBrainScore: stats.reflexBrainScore,
                    isNewBest: isNewBest,
                    multiplierBreakdown: nil,
                    percentileText: PlayerStats.percentileLabel(for: brainScore),
                    accentColor: .orange,
                    share: GameResult.ShareConfig(
                        gameName: "Lightning Tap",
                        icon: "bolt.fill",
                        color: .orange,
                        primaryValue: "\(score)",
                        primaryLabel: "score",
                        secondaryLine: String(format: "Median %.0f ms", medianMs)
                    )
                )
                vm.gameResult = result
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation { showGameOver = true }
                }
            }
        }
    }

    // MARK: - Arena Header

    private var arenaHeader: some View {
        HStack(alignment: .top) {
            StatBadge(
                label: "Round",
                value: "\(min(vm.roundIndex + 1, ReflexGameViewModel.totalRounds))/\(ReflexGameViewModel.totalRounds)",
                color: .orange
            )
            Spacer()
            // Running average RT
            if let avg = vm.averageRT {
                VStack(spacing: 1) {
                    Text("Avg RT")
                        .font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text(String(format: "%.0f ms", avg))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(reactionColor(avg))
                        .contentTransition(.numericText(value: avg))
                        .animation(.easeOut(duration: 0.35), value: avg)
                }
            }
            Spacer()
            // Elo-derived difficulty label
            AutoDiffBadge(eloRating: stats.reflexEloRating)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Arena

    private var arenaView: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .onTapGesture { vm.backgroundTapped() }

                VStack {
                    statusMessage.padding(.top, 24)
                    Spacer()
                    // Recent RT pills
                    if !vm.reactionTimes.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(vm.reactionTimes.suffix(5).enumerated()), id: \.offset) { _, t in
                                Text(String(format: "%.0f", t))
                                    .font(.caption.monospacedDigit().bold())
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(reactionColor(t).opacity(0.15))
                                    .foregroundStyle(reactionColor(t))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }

                // Target orb
                if vm.targetVisible {
                    orbView
                        .position(x: vm.targetX, y: vm.targetY)
                        .onTapGesture {
                            if vm.gameState == .targetShowing { vm.targetTapped() }
                            else if vm.gameState == .gotchaShowing { vm.gotchaTapped() }
                        }
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .juiceBounce(trigger: vm.orbBounce)
                }

                // Flash RT text at orb position
                if let flash = vm.flashText {
                    Text(flash)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .position(x: vm.targetX, y: vm.targetY - 50)
                        .transition(.opacity)
                        .id(vm.flashId)
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .milliseconds(600))
                                vm.flashText = nil
                            }
                        }
                }

                // Particle burst for sub-150ms
                if vm.showParticles {
                    ParticleBurst(color: .yellow, count: 16)
                        .position(x: vm.targetX, y: vm.targetY)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.vertical, 12)
            .onAppear { vm.containerSize = geo.size }
            .onChange(of: geo.size) { _, s in vm.containerSize = s }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: vm.targetVisible)
    }

    // MARK: - Orb

    private var orbView: some View {
        let size = vm.targetSize
        return ZStack {
            if vm.isGotchaRound {
                // Red gotcha orb
                Circle()
                    .fill(RadialGradient(
                        colors: [.orange, .red],
                        center: .center, startRadius: 0, endRadius: size / 2
                    ))
                    .frame(width: size, height: size)
                    .shadow(color: .red.opacity(0.7), radius: 18)
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: size > 80 ? 24 : 18))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                    .scaleEffect(pulsingScale)
            } else {
                // Energy sphere: yellow center → electric blue edge
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            .yellow,
                            Color(hue: 0.58, saturation: 1, brightness: 1),
                            Color(hue: 0.61, saturation: 1, brightness: 0.85)
                        ],
                        center: .center, startRadius: 0, endRadius: size / 2
                    ))
                    .frame(width: size, height: size)
                    .shadow(color: Color(hue: 0.6, saturation: 1, brightness: 1).opacity(0.7), radius: 20)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: size > 80 ? 28 : 20, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .yellow, radius: 4)
                    )
                    .scaleEffect(pulsingScale)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
            ) {
                pulsingScale = 1.05
            }
        }
        .onDisappear {
            pulsingScale = 1.0
        }
    }

    // MARK: - Status Message

    @ViewBuilder
    private var statusMessage: some View {
        switch vm.gameState {
        case .waiting:
            if vm.tooEarly {
                Label("Too early! Wait…", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.headline)
            } else {
                Text("Get ready…").font(.headline).foregroundStyle(.secondary)
            }
        case .targetShowing:
            Text("TAP IT!")
                .font(.title2.bold()).foregroundStyle(.orange)
        case .gotchaShowing:
            Text("DON'T TAP!")
                .font(.title2.bold()).foregroundStyle(.red)
        case .roundResult:
            if vm.isGotchaRound {
                if vm.gotchaPenalties.last != nil {
                    Text("Too Early! +500ms penalty")
                        .font(.headline.bold()).foregroundStyle(.orange)
                } else {
                    Text("Good Control!")
                        .font(.headline.bold()).foregroundStyle(.green)
                }
            } else if let ms = vm.lastReactionMs {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f ms", ms))
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(reactionColor(ms))
                    Text(speedLabel(ms))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 72)).foregroundStyle(.orange)
                Text("Lightning Tap").font(.largeTitle.bold())
                Text("Tap the sphere as fast as you can.\n8 rounds — avoid the red orbs!")
                    .font(.body).multilineTextAlignment(.center)
                    .foregroundStyle(.secondary).padding(.horizontal)
                if stats.reflexBestTimeMs > 0 {
                    Label(String(format: "Record: %.0f ms", stats.reflexBestTimeMs), systemImage: "trophy.fill")
                        .font(.subheadline.bold()).foregroundStyle(.yellow)
                }
                // Auto difficulty badge
                AutoDiffBadge(eloRating: stats.reflexEloRating)
            }
            Spacer()
            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal).padding(.bottom, 12)
            Button {
                showGameOver = false
                vm.startGame(eloRating: stats.reflexEloRating)
            } label: {
                Text("Start")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal).padding(.bottom, 20)
        }
    }

    // MARK: - Celebration

    @ViewBuilder
    private func celebrationText(_ text: String) -> some View {
        let isGold = text == "SUPERHUMAN" || text == "INCREDIBLE"
        VStack {
            Text(text)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(isGold ? Color.yellow : Color(white: 0.85))
                .shadow(color: isGold ? .orange.opacity(0.8) : .black.opacity(0.3), radius: 6)
                .padding(.top, 120)
            Spacer()
        }
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: text)
    }

    // MARK: - Helpers

    func reactionColor(_ ms: Double) -> Color {
        if ms < 200 { return .green }
        if ms < 300 { return .teal }
        if ms < 450 { return .orange }
        return .red
    }

    func speedLabel(_ ms: Double) -> String {
        if ms < 150 { return "Superhuman!" }
        if ms < 200 { return "Lightning fast!" }
        if ms < 300 { return "Very quick" }
        if ms < 450 { return "Not bad" }
        return "Keep practicing"
    }
}

// MARK: - AutoDiffBadge

private struct AutoDiffBadge: View {
    let eloRating: Double

    private var label: String {
        switch eloRating {
        case ..<1000: return "Auto · Easy"
        case 1000..<1200: return "Auto · Medium"
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

#Preview {
    NavigationStack { ReflexGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
