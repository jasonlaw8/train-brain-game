import SwiftUI
import SwiftData

// Vault Cracker: Flash digits one at a time with colour + tone encoding.
// Player reproduces the sequence (forward or reverse). Dark vault aesthetic.

// MARK: - Digit colour palette (0–9)

private let digitColors: [Color] = [
    .gray,   // 0
    .red,    // 1
    .orange, // 2
    .yellow, // 3
    .green,  // 4
    .teal,   // 5
    .blue,   // 6
    .indigo, // 7
    .purple, // 8
    .pink    // 9
]

// MARK: - ViewModel

@MainActor
class DigitSpanViewModel: ObservableObject {
    enum GameState { case idle, preGame, flashing, input, feedback, gameOver }

    @Published var gameState: GameState = .idle
    @Published var currentLevel: Int = 3
    @Published var lives: Int = 2
    @Published var score: Int = 0             // max level reached
    @Published var flashedDigit: Int? = nil
    @Published var playerInput: [Int] = []
    @Published var feedbackCorrect: Bool? = nil
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0
    @Published var isReverseMode: Bool = false
    @Published var isNewRecord: Bool = false
    @Published var flashRecord: Bool = false   // juiceFlash trigger

    // Near-miss messaging
    @Published var nearMissMessage: String? = nil
    @Published var showVaultOpen: Bool = false

    // Pre-game mode selection
    @Published var pendingReverse: Bool = false

    var onGameOver: ((Int) -> Void)?  // passes max level (score)

    private var currentSequence: [Int] = []
    private var flashTask: Task<Void, Never>?
    private var eloParams: EloSystem.DigitSpanParams = .init(startLength: 4, displayTime: 0.70, lives: 2)
    private var personalBest: Int = 0

    func configure(params: EloSystem.DigitSpanParams, best: Int) {
        eloParams = params
        personalBest = best
    }

    func startGame(reverseMode: Bool) {
        isReverseMode = reverseMode
        currentLevel = eloParams.startLength
        lives = eloParams.lives
        score = 0
        feedbackCorrect = nil
        isNewRecord = false
        nearMissMessage = nil
        showVaultOpen = false
        gameState = .flashing
        startNewRound()
    }

    private func startNewRound() {
        playerInput = []
        nearMissMessage = nil
        showVaultOpen = false
        currentSequence = generateSequence(length: currentLevel)
        flashSequence()
    }

    private func generateSequence(length: Int) -> [Int] {
        // Avoid consecutive duplicates by shuffling
        return Array(Array(0...9).shuffled().prefix(length))
    }

    private func flashSequence() {
        flashTask?.cancel()
        flashTask = Task {
            let showMs = Int(eloParams.displayTime * 1000)
            let blankMs = max(100, showMs / 5)
            for digit in currentSequence {
                guard !Task.isCancelled else { return }
                flashedDigit = digit
                Haptics.light()
                SoundEngine.shared.playTone(
                    frequency: SoundEngine.digitTones[digit],
                    duration: eloParams.displayTime * 0.8
                )
                try? await Task.sleep(for: .milliseconds(showMs))
                guard !Task.isCancelled else { return }
                flashedDigit = nil
                try? await Task.sleep(for: .milliseconds(blankMs))
            }
            guard !Task.isCancelled else { return }
            gameState = .input
        }
    }

    func tapDigit(_ digit: Int) {
        guard gameState == .input else { return }
        // Play tone for the tapped digit
        SoundEngine.shared.playTone(
            frequency: SoundEngine.digitTones[digit],
            duration: 0.08
        )
        let idx = playerInput.count
        playerInput.append(digit)

        // In reverse mode, compare to reversed sequence
        let targetSequence = isReverseMode ? currentSequence.reversed() : currentSequence

        if digit != targetSequence[idx] {
            // Wrong digit
            Haptics.error()
            lives -= 1
            feedbackCorrect = false
            gameState = .feedback
            SoundEngine.shared.playWrong()

            // Near-miss calculation
            let correctSoFar = idx  // digits correct before this wrong one
            let total = currentLevel
            if correctSoFar == total - 1 {
                nearMissMessage = "SO CLOSE! 1 digit away!"
            } else if correctSoFar >= total - 3 && correctSoFar > 0 {
                nearMissMessage = "Almost! \(correctSoFar) of \(total) correct!"
            }

            flashTask?.cancel()
            flashTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                feedbackCorrect = nil
                nearMissMessage = nil
                if self.lives <= 0 {
                    self.endGame()
                } else {
                    self.gameState = .flashing
                    self.startNewRound()
                }
            }
        } else if playerInput.count == currentSequence.count {
            // Full sequence correct
            Haptics.success()
            if currentLevel > score { score = currentLevel }

            // Check personal best
            let xp = isReverseMode ? currentLevel * 24 : currentLevel * 12
            _ = xp  // XP applied in view's onGameOver

            let reachedOrBeatenBest = currentLevel >= personalBest && personalBest > 0
            if reachedOrBeatenBest {
                isNewRecord = true
                flashRecord = !flashRecord
            }

            if currentLevel > personalBest {
                nearMissMessage = "NEW RECORD!"
            }

            feedbackCorrect = true
            showVaultOpen = true
            gameState = .feedback
            SoundEngine.shared.playVaultOpen()

            flashTask?.cancel()
            flashTask = Task {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                feedbackCorrect = nil
                showVaultOpen = false
                nearMissMessage = nil
                self.currentLevel += 1
                self.gameState = .flashing
                self.startNewRound()
            }
        }
        // else partial correct input — keep waiting
    }

    private func endGame() {
        flashTask?.cancel()
        finalScore = score
        finalBrainScore = PlayerStats.digitSpanBrainScore(level: score)
        onGameOver?(score)
        gameState = .gameOver
    }
}

// MARK: - View

struct DigitSpanGameView: View {
    @StateObject private var vm = DigitSpanViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("digitSpanDifficulty") private var difficulty: Difficulty = .medium

    // Pre-game reverse toggle
    @State private var reverseMode: Bool = false

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private var eloParams: EloSystem.DigitSpanParams {
        EloSystem.digitSpanParams(stats.digitSpanEloRating)
    }

    // Gold border when at/beyond personal best
    private var showGoldBorder: Bool { vm.isNewRecord && vm.gameState == .input }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            mainContent
        }
        .navigationTitle("Vault Cracker")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.configure(params: eloParams, best: stats.digitSpanBestLevel)
            vm.onGameOver = { level in
                let isNewBest = level > stats.digitSpanBestLevel
                let brainScore = PlayerStats.digitSpanBrainScore(level: level)
                let session = GameSession(
                    gameType: "digitspan",
                    rawScore: level,
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordDigitSpanGame(level: level)
                stats.digitSpanEloRating = EloSystem.updated(
                    stats.digitSpanEloRating,
                    correct: level >= 6
                )
                if isNewBest && level > 0 {
                    Haptics.success()
                    SoundEngine.shared.playNewBest()
                }
            }
        }
    }

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:               idleView
        case .preGame:            idleView   // handled in idle
        case .flashing:           flashingView
        case .input, .feedback:   inputView
        case .gameOver:           gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 72))
                    .foregroundStyle(.indigo)
                Text("Vault Cracker")
                    .font(.largeTitle.bold())
                Text("Watch the digits flash.\nCrack the vault combination.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if stats.digitSpanBestLevel > 0 {
                    Label("Your Record: \(stats.digitSpanBestLevel) digits", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }

                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                    Text("Auto difficulty")
                        .font(.caption.bold())
                }
                .foregroundStyle(.indigo)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.indigo.opacity(0.12), in: Capsule())

                // Reverse mode toggle
                HStack(spacing: 10) {
                    Button {
                        reverseMode = false
                    } label: {
                        Text("Forward")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(
                                !reverseMode ? Color.indigo : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundStyle(!reverseMode ? .white : .secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        reverseMode = true
                    } label: {
                        Text("↩ Reverse  (2× XP)")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(
                                reverseMode ? Color.indigo : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundStyle(reverseMode ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button {
                vm.configure(params: eloParams, best: stats.digitSpanBestLevel)
                vm.startGame(reverseMode: reverseMode)
            } label: {
                Text("Crack the Vault")
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

    // MARK: - Flashing

    var flashingView: some View {
        VStack(spacing: 24) {
            HStack {
                StatBadge(label: "Level", value: "\(vm.currentLevel)", color: .indigo)
                Spacer()
                if vm.isReverseMode {
                    Text("↩ REVERSE")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.12), in: Capsule())
                }
                Spacer()
                livesView
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if stats.digitSpanBestLevel > 0 {
                Text("Your Record: \(stats.digitSpanBestLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Watch the combination...")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Digit display area
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 180, height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(.systemGray4), lineWidth: 2)
                    )

                if let digit = vm.flashedDigit {
                    Text("\(digit)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(digitColors[digit])
                        .shadow(color: digitColors[digit].opacity(0.4), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.12), value: vm.flashedDigit)

            Spacer()
        }
    }

    // MARK: - Input

    var inputView: some View {
        VStack(spacing: 16) {
            HStack {
                StatBadge(label: "Level", value: "\(vm.currentLevel)", color: .indigo)
                Spacer()
                if vm.isReverseMode {
                    Text("↩ REVERSE")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.12), in: Capsule())
                }
                Spacer()
                livesView
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if stats.digitSpanBestLevel > 0 {
                Text("Your Record: \(stats.digitSpanBestLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Digit display slots
            let slots = digitSlots
            slots
                .padding(.horizontal)
                .juiceFlash(trigger: vm.flashRecord, color: .yellow)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            showGoldBorder
                                ? Color.yellow.opacity(0.8)
                                : Color.clear,
                            lineWidth: showGoldBorder ? 3 : 0
                        )
                        .animation(
                            showGoldBorder
                                ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                                : .default,
                            value: showGoldBorder
                        )
                        .padding(.horizontal)
                )

            // Vault open / feedback
            if vm.showVaultOpen {
                VStack(spacing: 4) {
                    Text("🔓")
                        .font(.system(size: 48))
                        .transition(.scale.combined(with: .opacity))
                    Text("VAULT OPEN!")
                        .font(.headline.bold())
                        .foregroundStyle(.green)
                }
            } else if let correct = vm.feedbackCorrect, !correct {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 52)
            }

            // Near-miss message
            if let msg = vm.nearMissMessage {
                Text(msg)
                    .font(.headline.bold())
                    .foregroundStyle(
                        msg.contains("RECORD") ? .yellow
                        : msg.contains("CLOSE") ? .orange
                        : Color.yellow.opacity(0.8)
                    )
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            if vm.gameState == .input {
                Text(vm.isReverseMode ? "Enter digits in REVERSE order" : "Enter the digits in order")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Digit pad 0–9
            digitPad
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.15), value: vm.feedbackCorrect)
        .animation(.easeInOut(duration: 0.15), value: vm.showVaultOpen)
        .animation(.easeInOut(duration: 0.15), value: vm.nearMissMessage)
    }

    var digitSlots: some View {
        // Scroll if level > 7
        let slotWidth: CGFloat = vm.currentLevel > 7 ? 36 : 44
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<vm.currentLevel, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(slotFill(for: i))
                            .frame(width: slotWidth, height: slotWidth + 8)
                        if i < vm.playerInput.count {
                            let d = vm.playerInput[i]
                            Text("\(d)")
                                .font(.system(size: slotWidth * 0.5, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    vm.feedbackCorrect == nil ? digitColors[d] : .white
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 60)
    }

    func slotFill(for index: Int) -> Color {
        if index < vm.playerInput.count {
            if let correct = vm.feedbackCorrect {
                return correct ? .green : .red
            }
            let d = vm.playerInput[index]
            return digitColors[d].opacity(0.25)
        }
        return Color(.systemGray5)
    }

    var digitPad: some View {
        let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [0]]
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        Button {
                            vm.tapDigit(digit)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                                Text("\(digit)")
                                    .font(.title2.bold())
                                    .foregroundStyle(digitColors[digit])
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.gameState != .input)
                    }
                }
            }
        }
    }

    var livesView: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(1, eloParams.lives), id: \.self) { i in
                Image(systemName: i < vm.lives ? "heart.fill" : "heart")
                    .foregroundStyle(i < vm.lives ? .red : Color(.systemGray4))
            }
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        let brainScore = vm.finalBrainScore
        let isNewBest = vm.finalScore > 0 && vm.finalScore > stats.digitSpanBestLevel
        // Note: stats already updated in onGameOver closure; compare before update not possible here
        // so we use: finalScore >= bestLevel after recording
        let result = GameResult(
            gameTitle: "Vault Cracker",
            primaryScore: vm.finalScore,
            primaryLabel: "digits",
            brainScore: brainScore,
            previousBrainScore: stats.digitSpanBrainScore,
            isNewBest: isNewBest,
            multiplierBreakdown: vm.isReverseMode
                ? GameResult.MultiplierBreakdown(
                    baseScore: vm.finalScore,
                    bestMultiplier: 2.0,
                    finalScore: vm.finalScore
                  )
                : nil,
            percentileText: PlayerStats.percentileLabel(for: brainScore),
            accentColor: .indigo,
            share: GameResult.ShareConfig(
                gameName: "Vault Cracker",
                icon: "lock.rotation",
                color: .indigo,
                primaryValue: "\(vm.finalScore)",
                primaryLabel: "digits",
                secondaryLine: vm.isReverseMode ? "Reverse Mode" : nil
            )
        )
        return GameOverView(result: result) {
            vm.configure(params: eloParams, best: stats.digitSpanBestLevel)
            vm.startGame(reverseMode: reverseMode)
        }
    }
}

#Preview {
    NavigationStack { DigitSpanGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
