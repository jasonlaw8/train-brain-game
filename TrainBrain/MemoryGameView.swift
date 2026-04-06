import SwiftUI

// Simon Says: watch the tile sequence light up, then repeat it.

@MainActor
class MemoryGameViewModel: ObservableObject {
    private let tileColors: [Color] = [
        .red, .orange, .yellow, .green, .teal,
        .blue, .indigo, .purple, .pink
    ]

    @Published var highlightedTile: Int? = nil
    @Published var playerTurn = false
    @Published var gameState: GameState = .idle
    @Published var level = 1
    @Published var score = 0
    @Published var message = "Tap Start to begin"

    enum GameState { case idle, playing, input, success, failure }

    private var sequence: [Int] = []
    private var playerInput: [Int] = []
    private var playbackTask: Task<Void, Never>?

    func tileColor(at index: Int) -> Color {
        let base = tileColors[index]
        if highlightedTile == index { return base }
        return base.opacity(playerTurn ? 0.45 : 0.25)
    }

    func startGame() {
        playbackTask?.cancel()
        sequence = []
        playerInput = []
        score = 0
        level = 1
        gameState = .playing
        addAndPlay()
    }

    func tileTapped(_ index: Int) {
        guard playerTurn, gameState == .input else { return }
        let expected = sequence[playerInput.count]
        playerInput.append(index)

        if index != expected {
            gameState = .failure
            playerTurn = false
            message = "Wrong! Score: \(score)"
            playbackTask = Task {
                highlightedTile = expected
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                highlightedTile = nil
                gameState = .idle
                message = "Game over! Tap Start to try again"
            }
            return
        }

        if playerInput.count == sequence.count {
            score += level * 10
            level += 1
            gameState = .success
            playerTurn = false
            message = "Nice! +\(sequence.count * 10) pts"
            playbackTask = Task {
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
                addAndPlay()
            }
        }
    }

    private func addAndPlay() {
        playerInput = []
        playerTurn = false
        gameState = .playing
        sequence.append(Int.random(in: 0..<9))
        message = "Watch carefully…"

        playbackTask = Task {
            try? await Task.sleep(for: .seconds(0.4))
            for (i, tile) in sequence.enumerated() {
                guard !Task.isCancelled else { return }
                highlightedTile = tile
                try? await Task.sleep(for: .seconds(0.55))
                guard !Task.isCancelled else { return }
                highlightedTile = nil
                try? await Task.sleep(for: .seconds(0.25))
                if i == sequence.count - 1 {
                    guard !Task.isCancelled else { return }
                    playerTurn = true
                    gameState = .input
                    message = "Your turn — \(sequence.count) tap\(sequence.count == 1 ? "" : "s")"
                }
            }
        }
    }
}

struct MemoryGameView: View {
    @StateObject private var vm = MemoryGameViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 20) {
            // Score bar
            HStack {
                StatBadge(label: "Score", value: "\(vm.score)", color: .blue)
                Spacer()
                StatBadge(label: "Level", value: "\(vm.level)", color: .indigo)
            }
            .padding(.horizontal)

            // Message
            Text(vm.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(messageColor)
                .animation(.easeInOut(duration: 0.2), value: vm.message)
                .frame(minHeight: 24)

            // Tile grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(vm.tileColor(at: index))
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(vm.highlightedTile == index ? 1.08 : 1.0)
                        .shadow(
                            color: vm.highlightedTile == index
                                ? vm.tileColor(at: index).opacity(0.6) : .clear,
                            radius: 12
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: vm.highlightedTile)
                        .onTapGesture {
                            vm.tileTapped(index)
                        }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                vm.startGame()
            } label: {
                Text(vm.gameState == .idle || vm.gameState == .failure ? "Start" : "Restart")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .disabled(vm.gameState == .playing || vm.gameState == .input || vm.gameState == .success)
            .opacity(vm.gameState == .playing || vm.gameState == .input || vm.gameState == .success ? 0.4 : 1)
        }
        .padding(.vertical)
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
    }

    var messageColor: Color {
        switch vm.gameState {
        case .failure: return .red
        case .success: return .green
        default: return .primary
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack { MemoryGameView() }
}
