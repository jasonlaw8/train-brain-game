import SwiftUI

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

    private var correctOption: ColorOption?
    private var timer: Timer?

    enum GameState { case idle, playing, gameOver }

    func startGame() {
        score = 0
        streak = 0
        bestStreak = 0
        timeRemaining = 30
        gameState = .playing
        nextQuestion()
        startTimer()
    }

    func selectColor(_ option: ColorOption) {
        guard gameState == .playing else { return }
        let correct = option == correctOption
        lastCorrect = correct

        if correct {
            streak += 1
            bestStreak = max(bestStreak, streak)
            let bonus = streak >= 5 ? 30 : streak >= 3 ? 20 : 10
            score += bonus
        } else {
            streak = 0
            score = max(0, score - 5)
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
        gameState = .gameOver
    }
}

struct ColorGameView: View {
    @StateObject private var vm = ColorGameViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            // Header stats
            HStack {
                StatBadge(label: "Score", value: "\(vm.score)", color: .purple)
                Spacer()
                StatBadge(label: "Streak", value: "🔥 \(vm.streak)", color: .orange)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch vm.gameState {
                case .idle:    idleView
                case .playing: playingView
                case .gameOver: gameOverView
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.gameState)
        }
        .navigationTitle("Color")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text("🎨")
                    .font(.system(size: 80))
                Text("Stroop Challenge")
                    .font(.largeTitle.bold())
                Text("Tap the COLOR the word is written in\n— not what it says!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            Spacer()
            startButton(label: "Start", color: .purple)
        }
    }

    // MARK: Playing

    var playingView: some View {
        VStack(spacing: 20) {
            // Timer bar
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

            // Stroop word
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

            // Feedback
            if let correct = vm.lastCorrect {
                Text(correct ? "✓" : "✗")
                    .font(.title.bold())
                    .foregroundStyle(correct ? Color.green : Color.red)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Color choice buttons
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
                    resultRow(label: "Final Score", value: "\(vm.score)", color: .purple)
                    resultRow(label: "Best Streak", value: "🔥 \(vm.bestStreak)", color: .orange)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.score >= 100 {
                    Text("🏆 Excellent!")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                } else if vm.score >= 60 {
                    Text("👍 Good job!")
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
}
