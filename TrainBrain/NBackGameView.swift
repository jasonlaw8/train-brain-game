import SwiftUI
import SwiftData

// N-Track: positional n-back. A tile lights up each interval; press MATCH when the
// lit position equals the position N steps back. Staircase difficulty across 3 rounds.

@MainActor
final class NBackViewModel: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var currentN: Int = 1
    @Published var roundIndex: Int = 1          // 1...3
    @Published var trialIndex: Int = 0          // within current round
    @Published var litTile: Int? = nil
    @Published var flashIndex: Int? = nil
    @Published var flashKind: FlashKind? = nil
    @Published var isPaused = false
    @Published var hasResponded = false         // one response per trial
    @Published var hits = 0
    @Published var falseAlarms = 0
    @Published var misses = 0
    @Published var correctRejections = 0
    @Published var levelChange = 0              // -1 / 0 / +1, shown on interstitial
    @Published var showNewBest = false
    @Published var wasNewBest = false
    @Published var finalMaxN = 1
    @Published var finalAccuracy = 0
    @Published var finalBrainScore = 0
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil

    enum GameState { case idle, countdown, playing, interstitial, gameOver }
    enum FlashKind { case hit, falseAlarm, miss }

    var onGameOver: ((Int, Int) -> Void)?  // (maxN, accuracy %)

    // MARK: - Private state

    private var difficulty: Difficulty = .medium
    private var sequence: [Int] = []
    private var awaitingResponse = false
    private var stimulusTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var interstitialTask: Task<Void, Never>?

    // Per-round tallies
    private var roundHits = 0
    private var roundFalseAlarms = 0
    private var roundMisses = 0
    private var roundCorrectRejections = 0
    private var roundScoreableResolved = 0
    private var completedRounds: [(n: Int, accuracy: Double)] = []

    private let totalRounds = 3
    private let litDuration = 0.6
    private let missFlashLead = 0.35   // gap after resolving, so the miss flash is visible

    private var stimulusInterval: Double {
        switch difficulty {
        case .easy:   return 2.4
        case .medium: return 2.0
        case .hard:   return 1.6
        }
    }

    var trialsInRound: Int { sequence.count }

    var roundProgress: Double {
        guard !sequence.isEmpty else { return 0 }
        return Double(trialIndex) / Double(sequence.count)
    }

    // MARK: - Lifecycle

    func startGame(difficulty: Difficulty, startN: Int) {
        cancelAllTasks()
        self.difficulty = difficulty
        currentN = max(1, min(4, startN))
        roundIndex = 1
        hits = 0
        falseAlarms = 0
        misses = 0
        correctRejections = 0
        completedRounds = []
        levelChange = 0
        showNewBest = false
        wasNewBest = false
        isPaused = false
        prepareRound()
        gameState = .countdown
    }

    /// Called when a CountdownOverlay finishes — starts (or resumes) the trial loop.
    func beginPlay() {
        guard gameState == .countdown else { return }
        gameState = .playing
        runTrials()
    }

    func pauseGame() {
        guard gameState == .playing, !isPaused else { return }
        stimulusTask?.cancel()
        stimulusTask = nil
        // Void the in-flight trial; resume continues from the next one.
        if awaitingResponse {
            if hasResponded && trialIndex >= currentN {
                roundScoreableResolved += 1  // response was already tallied at press time
            }
            awaitingResponse = false
            trialIndex += 1
        }
        litTile = nil
        clearFlash()
        isPaused = true
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        gameState = .countdown  // fresh countdown, then beginPlay() continues the round
    }

    /// Cancels everything and returns to idle. Abandoned games record nothing.
    func abandon() {
        cancelAllTasks()
        litTile = nil
        flashIndex = nil
        flashKind = nil
        awaitingResponse = false
        isPaused = false
        if gameState != .gameOver && gameState != .idle {
            gameState = .idle
        }
    }

    private func cancelAllTasks() {
        stimulusTask?.cancel()
        stimulusTask = nil
        flashTask?.cancel()
        flashTask = nil
        interstitialTask?.cancel()
        interstitialTask = nil
    }

    // MARK: - Trial engine

    private func prepareRound() {
        sequence = makeSequence(n: currentN)
        trialIndex = 0
        awaitingResponse = false
        hasResponded = false
        roundHits = 0
        roundFalseAlarms = 0
        roundMisses = 0
        roundCorrectRejections = 0
        roundScoreableResolved = 0
        litTile = nil
        clearFlash()
    }

    private func runTrials() {
        stimulusTask?.cancel()
        stimulusTask = Task { [weak self] in
            guard let self else { return }
            while let step = await self.nextTrialStep() {
                guard step else { return }  // cancelled or paused mid-trial
            }
        }
    }

    /// Runs one trial. Returns nil when the round is finished, false when interrupted.
    private func nextTrialStep() async -> Bool? {
        guard trialIndex < sequence.count else {
            finishRound()
            return nil
        }
        guard gameState == .playing, !isPaused, !Task.isCancelled else { return false }

        let i = trialIndex
        litTile = sequence[i]
        awaitingResponse = true
        hasResponded = false

        try? await Task.sleep(for: .seconds(litDuration))
        guard !Task.isCancelled else { return false }
        litTile = nil

        let tail = max(0.2, stimulusInterval - litDuration - missFlashLead)
        try? await Task.sleep(for: .seconds(tail))
        guard !Task.isCancelled, awaitingResponse else { return false }

        resolveTrial(i)
        trialIndex = i + 1

        try? await Task.sleep(for: .seconds(missFlashLead))
        guard !Task.isCancelled else { return false }
        return true
    }

    func matchPressed() {
        guard gameState == .playing, !isPaused, awaitingResponse, !hasResponded else { return }
        hasResponded = true
        let i = trialIndex
        guard i >= currentN else {
            Haptics.light()  // warm-up trial, not scoreable
            return
        }
        if sequence[i] == sequence[i - currentN] {
            hits += 1
            roundHits += 1
            flash(.hit, at: sequence[i])
            Haptics.medium()
        } else {
            falseAlarms += 1
            roundFalseAlarms += 1
            flash(.falseAlarm, at: sequence[i])
            Haptics.error()
        }
    }

    /// Closes the response window for trial i and scores no-press outcomes.
    private func resolveTrial(_ i: Int) {
        awaitingResponse = false
        guard i >= currentN else { return }
        roundScoreableResolved += 1
        let isMatch = sequence[i] == sequence[i - currentN]
        if isMatch && !hasResponded {
            misses += 1
            roundMisses += 1
            flash(.miss, at: sequence[i])  // gentle teaching cue, no error haptic
        } else if !isMatch && !hasResponded {
            correctRejections += 1
            roundCorrectRejections += 1
        }
    }

    private func flash(_ kind: FlashKind, at index: Int) {
        flashTask?.cancel()
        flashIndex = index
        flashKind = kind
        flashTask = Task {
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            clearFlash()
        }
    }

    private func clearFlash() {
        flashIndex = nil
        flashKind = nil
    }

    // MARK: - Round end + staircase

    private func finishRound() {
        stimulusTask?.cancel()
        stimulusTask = nil
        litTile = nil
        let accuracy = roundScoreableResolved > 0
            ? Double(roundHits + roundCorrectRejections) / Double(roundScoreableResolved)
            : 0
        completedRounds.append((n: currentN, accuracy: min(1, accuracy)))

        if roundIndex >= totalRounds {
            endGame()
            return
        }

        // Staircase: >= 80% steps up (cap 4), <= 50% steps down (floor 1).
        let previousN = currentN
        if accuracy >= 0.8 {
            currentN = min(4, currentN + 1)
        } else if accuracy <= 0.5 {
            currentN = max(1, currentN - 1)
        }
        levelChange = currentN - previousN
        roundIndex += 1
        gameState = .interstitial
        Haptics.light()

        interstitialTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            prepareRound()
            gameState = .countdown
        }
    }

    private func endGame() {
        cancelAllTasks()
        // Highest N completed at >= 60% accuracy, minimum 1.
        let qualified = completedRounds.filter { $0.accuracy >= 0.6 }.map(\.n)
        finalMaxN = max(1, qualified.max() ?? 1)
        // Mean round accuracy; zero responses stays 0, never 100.
        if completedRounds.isEmpty {
            finalAccuracy = 0
        } else {
            let mean = completedRounds.map(\.accuracy).reduce(0, +) / Double(completedRounds.count)
            finalAccuracy = Int(mean * 100)
        }
        finalBrainScore = PlayerStats.nbackBrainScore(maxN: finalMaxN, accuracy: finalAccuracy)
        onGameOver?(finalMaxN, finalAccuracy)
        gameState = .gameOver
    }

    // MARK: - Sequence generation

    /// 20 + n positions; ~30% match rate among scoreable trials, at least 4 matches,
    /// never more than 2 matches in a row.
    private func makeSequence(n: Int) -> [Int] {
        let flags = matchFlags(count: 20)
        var seq = (0..<n).map { _ in Int.random(in: 0..<9) }
        for i in 0..<flags.count {
            let reference = seq[i]  // position n steps back from trial n + i
            if flags[i] {
                seq.append(reference)
            } else {
                var position = Int.random(in: 0..<9)
                while position == reference {
                    position = Int.random(in: 0..<9)
                }
                seq.append(position)
            }
        }
        return seq
    }

    private func matchFlags(count: Int) -> [Bool] {
        for _ in 0..<200 {
            let flags = (0..<count).map { _ in Double.random(in: 0..<1) < 0.3 }
            let matches = flags.filter { $0 }.count
            guard matches >= 4 && matches <= count / 2 else { continue }
            var run = 0
            var valid = true
            for flag in flags {
                run = flag ? run + 1 : 0
                if run > 2 { valid = false; break }
            }
            if valid { return flags }
        }
        // Deterministic fallback: evenly spaced matches.
        var flags = Array(repeating: false, count: count)
        for i in stride(from: 1, to: count, by: 4) { flags[i] = true }
        return flags
    }
}

struct NBackGameView: View {
    @StateObject private var vm = NBackViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @Query(sort: \GameSession.date, order: .reverse) private var sessions: [GameSession]
    @AppStorage("nbackDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        statsQuery.first ?? PlayerStats.fetchOrCreate(in: modelContext)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

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
        .navigationTitle("N-Track")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { maxN, accuracy in
                let isNewBest = maxN > stats.nbackBestLevel
                vm.wasNewBest = isNewBest
                let session = GameSession(
                    gameType: "nback",
                    rawScore: maxN,
                    brainScore: PlayerStats.nbackBrainScore(maxN: maxN, accuracy: accuracy),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordNBackGame(maxN: maxN, accuracy: accuracy)
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

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:         idleView
        case .countdown:    playArea
        case .playing:      playArea
        case .interstitial: interstitialView
        case .gameOver:     gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.system(size: 72))
                    .foregroundStyle(.purple)
                Text("N-Track")
                    .font(.largeTitle.bold())
                Text("Press Match when the lit square is in the\nsame spot as N steps ago. The level adapts to you.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.nbackBestLevel > 0 {
                    Label("Record: \(stats.nbackBestLevel)-Back", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            VStack(spacing: 6) {
                DifficultyPicker(difficulty: $difficulty)
                Text("Difficulty controls the pace of the sequence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Button {
                let startN = stats.nbackBestLevel >= 2 ? 2 : 1  // warm start
                vm.startGame(difficulty: difficulty, startN: startN)
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playArea: some View {
        ZStack {
            VStack(spacing: 20) {
                hud
                progressBar

                Spacer()

                tileGrid
                    .blur(radius: vm.isPaused ? 6 : 0)

                Spacer()

                matchButton
            }
            .padding(.vertical)

            if vm.gameState == .countdown {
                CountdownOverlay { vm.beginPlay() }
            }
            if vm.isPaused {
                PauseOverlay(
                    onResume: { vm.resumeGame() },
                    onQuit: { vm.abandon() }
                )
            }
        }
    }

    var hud: some View {
        HStack(spacing: 12) {
            Text("\(vm.currentN)-Back")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.purple))
            Text("Round \(vm.roundIndex)/3")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
            StatBadge(label: "Hits", value: "\(vm.hits)", color: .green)
            Button {
                vm.pauseGame()
            } label: {
                Image(systemName: "pause.circle.fill")
                    .font(.title)
                    .foregroundStyle(.purple)
            }
            .disabled(vm.gameState != .playing || vm.isPaused)
            .accessibilityLabel("Pause game")
        }
        .padding(.horizontal)
    }

    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(Color.purple)
                    .frame(width: geo.size.width * vm.roundProgress)
                    .animation(.linear(duration: 0.2), value: vm.roundProgress)
            }
        }
        .frame(height: 6)
        .padding(.horizontal)
    }

    var tileGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 18)
                    .fill(tileFill(index))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                missFlash(index) ? Color.orange : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .scaleEffect(vm.litTile == index ? 1.08 : 1.0)
                    .shadow(
                        color: vm.litTile == index ? Color.purple.opacity(0.5) : .clear,
                        radius: 12
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: vm.litTile)
                    .animation(.easeInOut(duration: 0.15), value: vm.flashIndex)
                    .accessibilityLabel("Tile row \(index / 3 + 1) column \(index % 3 + 1)")
                    .accessibilityValue(vm.litTile == index ? "lit" : "")
            }
        }
        .padding(.horizontal)
    }

    private func tileFill(_ index: Int) -> Color {
        if vm.flashIndex == index, let kind = vm.flashKind {
            switch kind {
            case .hit:        return .green.opacity(0.85)
            case .falseAlarm: return .red.opacity(0.85)
            case .miss:       break  // handled by the amber outline
            }
        }
        if vm.litTile == index { return .purple }
        return Color(.secondarySystemBackground)
    }

    private func missFlash(_ index: Int) -> Bool {
        vm.flashIndex == index && vm.flashKind == .miss
    }

    var matchButton: some View {
        Button {
            vm.matchPressed()
        } label: {
            Text("MATCH")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.purple, in: RoundedRectangle(cornerRadius: 20))
        }
        .opacity(vm.hasResponded ? 0.6 : 1)
        .disabled(vm.gameState != .playing || vm.isPaused)
        .accessibilityLabel("Match — press when the position repeats from N back")
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Interstitial

    var interstitialView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Round \(vm.roundIndex) of 3")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("now \(vm.currentN)-Back!")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.purple)
            levelChangeLabel
            Spacer()
        }
        .transition(.opacity)
    }

    @ViewBuilder
    var levelChangeLabel: some View {
        switch vm.levelChange {
        case let change where change > 0:
            Label("Stepping up!", systemImage: "arrow.up.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
        case let change where change < 0:
            Label("Stepping down", systemImage: "arrow.down.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
        default:
            Label("Holding steady", systemImage: "minus.circle.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple)

                Text("Session Complete")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    ResultRow(label: "Top Level",    value: "\(vm.finalMaxN)-Back",       color: .purple)
                    ResultRow(label: "Accuracy",     value: "\(vm.finalAccuracy)%",       color: .teal)
                    ResultRow(label: "Hits",         value: "\(vm.hits)",                 color: .green)
                    ResultRow(label: "False Alarms", value: "\(vm.falseAlarms)",          color: .red)
                    Divider()
                    ResultRow(label: "Brain Score",  value: "\(vm.finalBrainScore)",      color: .indigo)
                    ResultRow(label: "All-Time Best", value: "\(stats.nbackBestLevel)-Back", color: .secondary)
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
                gameName: "N-Track", gameIcon: "square.grid.3x3.topleft.filled", gameColor: .purple,
                primaryValue: "\(vm.finalMaxN)-Back", primaryLabel: "level",
                secondaryLine: "Brain Score: \(vm.finalBrainScore)"
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            Button {
                let startN = stats.nbackBestLevel >= 2 ? 2 : 1
                vm.startGame(difficulty: difficulty, startN: startN)
            } label: {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    NavigationStack { NBackGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
