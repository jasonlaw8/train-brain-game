import SwiftUI

// Tap the orange circle as fast as you can. 8 rounds, then results.

@MainActor
class ReflexGameViewModel: ObservableObject {
    static let totalRounds = 8

    @Published var gameState: GameState = .idle
    @Published var targetVisible = false
    @Published var targetX: CGFloat = 0
    @Published var targetY: CGFloat = 0
    @Published var lastReactionMs: Double? = nil
    @Published var tooEarly = false
    @Published var reactionTimes: [Double] = []

    var containerSize: CGSize = CGSize(width: 300, height: 460)
    private var targetAppearTime: Date?
    private var waitTask: Task<Void, Never>?

    enum GameState { case idle, waiting, targetShowing, roundResult, finished }

    var currentRound: Int { reactionTimes.count + (isActiveRound ? 1 : 0) }
    var isActiveRound: Bool { gameState == .waiting || gameState == .targetShowing }
    var bestTime: Double? { reactionTimes.min() }
    var averageTime: Double? {
        guard !reactionTimes.isEmpty else { return nil }
        return reactionTimes.reduce(0, +) / Double(reactionTimes.count)
    }

    func startGame() {
        reactionTimes = []
        lastReactionMs = nil
        tooEarly = false
        nextRound()
    }

    func nextRound() {
        targetVisible = false
        tooEarly = false
        lastReactionMs = nil
        gameState = .waiting

        let delay = Double.random(in: 1.0...3.5)
        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, gameState == .waiting else { return }
            showTarget()
        }
    }

    private func showTarget() {
        let pad: CGFloat = 55
        targetX = CGFloat.random(in: pad...(containerSize.width - pad))
        targetY = CGFloat.random(in: pad...(containerSize.height - pad))
        targetVisible = true
        targetAppearTime = Date()
        gameState = .targetShowing
    }

    func targetTapped() {
        guard gameState == .targetShowing, let t0 = targetAppearTime else { return }
        let ms = Date().timeIntervalSince(t0) * 1000
        lastReactionMs = ms
        reactionTimes.append(ms)
        targetVisible = false
        gameState = .roundResult

        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            if reactionTimes.count >= Self.totalRounds {
                gameState = .finished
            } else {
                nextRound()
            }
        }
    }

    func backgroundTapped() {
        guard gameState == .waiting else { return }
        waitTask?.cancel()
        tooEarly = true
        waitTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            nextRound()
        }
    }
}

struct ReflexGameView: View {
    @StateObject private var vm = ReflexGameViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                StatBadge(
                    label: "Round",
                    value: "\(min(vm.currentRound, ReflexGameViewModel.totalRounds))/\(ReflexGameViewModel.totalRounds)",
                    color: .orange
                )
                Spacer()
                if let best = vm.bestTime {
                    StatBadge(
                        label: "Best",
                        value: String(format: "%.0f ms", best),
                        color: reactionColor(best)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if vm.gameState == .idle || vm.gameState == .finished {
                idleOrResultView
            } else {
                arenaView
            }
        }
        .navigationTitle("Reflex")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Arena

    var arenaView: some View {
        GeometryReader { geo in
            ZStack {
                // Tappable background (too-early zone)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .onTapGesture { vm.backgroundTapped() }

                // Status message
                VStack {
                    statusMessage
                        .padding(.top, 24)
                    Spacer()

                    // Recent times row
                    if !vm.reactionTimes.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(vm.reactionTimes.suffix(5).enumerated()), id: \.offset) { _, t in
                                Text(String(format: "%.0f", t))
                                    .font(.caption.monospacedDigit().bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(reactionColor(t).opacity(0.15))
                                    .foregroundStyle(reactionColor(t))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }

                // Target circle
                if vm.targetVisible {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow, .orange],
                                center: .center,
                                startRadius: 0,
                                endRadius: 44
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: .orange.opacity(0.6), radius: 16)
                        .overlay(
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        )
                        .position(x: vm.targetX, y: vm.targetY)
                        .onTapGesture { vm.targetTapped() }
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.vertical, 12)
            .onAppear {
                vm.containerSize = geo.size
            }
            .onChange(of: geo.size) { _, newSize in
                vm.containerSize = newSize
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: vm.targetVisible)
    }

    @ViewBuilder
    var statusMessage: some View {
        switch vm.gameState {
        case .waiting:
            if vm.tooEarly {
                Label("Too early! Wait…", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)
            } else {
                Text("Get ready…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        case .targetShowing:
            Text("TAP IT!")
                .font(.title2.bold())
                .foregroundStyle(.orange)
        case .roundResult:
            if let ms = vm.lastReactionMs {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f ms", ms))
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(reactionColor(ms))
                    Text(speedLabel(ms))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: Idle / Results

    var idleOrResultView: some View {
        VStack(spacing: 0) {
            Spacer()

            if vm.gameState == .finished {
                resultsContent
            } else {
                introContent
            }

            Spacer()

            Button {
                vm.startGame()
            } label: {
                Text(vm.gameState == .idle ? "Start" : "Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    var introContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
            Text("Reflex Test")
                .font(.largeTitle.bold())
            Text("Tap the circle as fast as you can.\n\(ReflexGameViewModel.totalRounds) rounds — don't tap too early!")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    var resultsContent: some View {
        VStack(spacing: 20) {
            Text("Results")
                .font(.largeTitle.bold())

            VStack(spacing: 10) {
                if let avg = vm.averageTime {
                    resultRow("Average", value: String(format: "%.0f ms", avg), color: reactionColor(avg))
                }
                if let best = vm.bestTime {
                    resultRow("Best", value: String(format: "%.0f ms", best), color: reactionColor(best))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(Array(vm.reactionTimes.enumerated()), id: \.offset) { i, t in
                    HStack {
                        Text("Round \(i + 1)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f ms", t))
                            .font(.subheadline.monospacedDigit().bold())
                            .foregroundStyle(reactionColor(t))
                    }
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
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
        }
    }

    func reactionColor(_ ms: Double) -> Color {
        if ms < 200 { return .green }
        if ms < 300 { return .teal }
        if ms < 450 { return .orange }
        return .red
    }

    func speedLabel(_ ms: Double) -> String {
        if ms < 200 { return "Lightning fast!" }
        if ms < 300 { return "Very quick" }
        if ms < 450 { return "Not bad" }
        return "Keep practicing"
    }
}

#Preview {
    NavigationStack { ReflexGameView() }
}
