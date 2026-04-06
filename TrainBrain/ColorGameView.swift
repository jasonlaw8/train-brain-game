import SwiftUI
import SwiftData

// Stroop test: the word's INK color is what you tap — not what it says.

struct ColorOption: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let color: Color
}

@MainActor
class ColorGameViewModel: ObservableObject {
    private let allOptions: [ColorOption] = [
        ColorOption(name: "RED",    color: .red),
        ColorOption(name: "BLUE",   color: .blue),
        ColorOption(name: "GREEN",  color: .green),
        ColorOption(name: "YELLOW", color: .yellow),
        ColorOption(name: "PURPLE", color: .purple),
        ColorOption(name: "ORANGE", color: .orange),
    ]

    @Published var wordText = ""
    @Published var inkColor: Color = .red
    @Published var choices: [ColorOption] = []
    @Published var score = 0
    @Published var streak = 0
    @Published var bestStreak = 0
    @Published var timeRemaining: Double = 30
    @Published var gameState: GameState = .idle
    @Published var lastCorrect: Bool? = nil
    @Published var showNewBest = false

    private var correctOption: ColorOption?
    private var timer: Timer?
    private var totalAttempts = 0
    private var correctAttempts = 0

    var accuracy: Int {
        guard totalAttempts > 0 else { return 0 }
        return Int(Double(correctAttempts) / Double(totalAttempts) * 100)
    }

    enum GameState { case idle, playing, gameOver }

    var onGameOver: ((Int, Int) -> Void)?  // (score, streak)

    func startGame() {
        score = 0
        streak = 0
        bestStreak = 0
        totalAttempts = 0
        correctAttempts = 0
        timeRemaining = 30
        gameState = .playing
        nextQuestion()
        startTimer()
    }

    func selectColor(_ option: ColorOption) {
        guard gameState == .playing else { return }
        let correct = option == correctOption
        lastCorrect = correct
        totalAttempts += 1

        if correct {
            correctAttempts += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            let bonus = streak >= 5 ? 30 : streak >= 3 ? 20 : 10
            score += bonus
            Haptics.medium()
        } else {
            streak = 0
            score = max(0, score - 5)
            Haptics.error()
        }

        Task {
            try? await Task.sleep(for: .milliseconds(220))
            guard gameState == .playing else { return }
            nextQuestion()
        }
    }

    private func nextQuestion() {
        lastCorrect = nil
        let word = allOptions.randomElement()!
        var ink: ColorOption
        repeat { ink = allOptions.randomElement()! } while ink == word

        wordText = word.name
        inkColor = ink.color
        correctOption = ink

        var pool = allOptions.filter { $0 != ink }
        pool.shuffle()
        choices = ([ink] + Array(pool.prefix(3))).shuffled()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.timeRemaining = max(0, self.timeRemaining - 0.05)
                if self.timeRemaining == 0 { self.endGame() }
            }
        }
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        onGameOver?(score, bestStreak)
        gameState = .gameOver
    }
}

struct ColorGameView: View {
    @StateObject private var vm = ColorGameViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header stats
                HStack {
                    StatBadge(label: "Score", value: "\(vm.score)", color: .purple)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Streak")
                            .font(.caption.smallCaps())
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                            Text("\(vm.streak)")
                        }
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch vm.gameState {
                    case .idle:     idleView
                    case .playing:  playingView
                    case .gameOver: gameOverView
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: vm.gameState)
            }

            if vm.showNewBest {
                NewBestBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4), value: vm.showNewBest)
        .navigationTitle("Color")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { score, streak in
                let isNewBest = score > stats.colorBestScore
                stats.recordColorGame(score: score, streak: streak)
                if isNewBest && score > 0 {
                    vm.showNewBest = true
                    Haptics.success()
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        vm.showNewBest = false
                    }
                }
            }
        }
    }

    // MARK: Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.purple)
                Text("Stroop Challenge")
                    .font(.largeTitle.bold())
                Text("Tap the COLOR the word is written in\n— not what it says!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.colorBestScore > 0 {
                    Label("Best: \(stats.colorBestScore) pts", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()
            startButton(label: "Start", color: .purple)
        }
    }

    // MARK: Playing

    var playingView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(timerBarColor)
                            .frame(width: geo.size.width * CGFloat(vm.timeRemaining / 30))
                    }
                }
                .frame(height: 8)
                .animation(.linear(duration: 0.05), value: vm.timeRemaining)

                Text(String(format: "%.1fs", vm.timeRemaining))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(timerBarColor)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer()

            ZStack {
                Text(vm.wordText)
                    .font(.system(size: 80, weight: .black))
                    .foregroundStyle(vm.inkColor)
                    .shadow(color: vm.inkColor.opacity(0.25), radius: 10)
                    .id(vm.wordText + vm.inkColor.description)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            .animation(.spring(response: 0.3), value: vm.wordText)

            if let correct = vm.lastCorrect {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(correct ? Color.green : Color.red)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.choices) { option in
                    Button {
                        vm.selectColor(option)
                    } label: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(option.color)
                            .overlay(
                                Text(option.name)
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                            )
                            .frame(height: 72)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("Time's Up!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    resultRow(label: "Score", value: "\(vm.score)", color: .purple)
                    resultRow(label: "Accuracy", value: "\(vm.accuracy)%", color: .blue)
                    HStack {
                        Text("Best Streak").foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                            Text("\(vm.bestStreak)")
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                    }
                    Divider()
                    resultRow(label: "All-Time Best", value: "\(stats.colorBestScore)", color: .secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.score >= 100 {
                    Label("Excellent!", systemImage: "trophy.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                } else if vm.score >= 60 {
                    Label("Good job!", systemImage: "hand.thumbsup.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            startButton(label: "Play Again", color: .purple)
        }
    }

    // MARK: Helpers

    func startButton(label: String, color: Color) -> some View {
        Button { vm.startGame() } label: {
            Text(label)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

    var timerBarColor: Color {
        if vm.timeRemaining > 15 { return .green }
        if vm.timeRemaining > 7  { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack { ColorGameView() }
        .modelContainer(for: PlayerStats.self, inMemory: true)
}
