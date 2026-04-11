import SwiftUI
import SwiftData

// Number Trail: Tap numbered circles in order (1→N) as fast as possible.
// 3 rounds. Score = average completion time.

// MARK: - ViewModel

@MainActor
class NumberTrailViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }

    struct Circle: Identifiable {
        let id: Int      // also the number label
        var position: CGPoint
        var tapped: Bool = false
        var shaking: Bool = false
    }

    @Published var gameState: GameState = .idle
    @Published var circles: [Circle] = []
    @Published var nextTarget: Int = 1
    @Published var elapsed: Double = 0
    @Published var roundTimes: [Double] = []
    @Published var currentRound: Int = 0
    @Published var shakeTargetID: Int? = nil
    @Published var showNewBest = false
    @Published var unlockedAchievement: Achievement? = nil
    @Published var leveledUpTo: Int? = nil
    @Published var finalAvg: Double = 0
    @Published var finalBrainScore: Int = 0

    let totalRounds = 3
    var onGameOver: ((Double) -> Void)?

    private var difficulty: Difficulty = .medium
    private var timerTask: Task<Void, Never>?
    private var arenaSize: CGSize = CGSize(width: 350, height: 600)

    var circleCount: Int {
        switch difficulty { case .easy: return 9; case .medium: return 12; case .hard: return 15 }
    }

    var circleSize: CGFloat {
        switch difficulty { case .easy: return 64; case .medium: return 52; case .hard: return 44 }
    }

    func setArenaSize(_ size: CGSize) {
        arenaSize = size
    }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        currentRound = 0
        roundTimes = []
        gameState = .playing
        startRound()
    }

    private func startRound() {
        timerTask?.cancel()
        elapsed = 0
        nextTarget = 1
        circles = placedCircles()
        startStopwatch()
    }

    private func startStopwatch() {
        timerTask = Task {
            let tick = 0.05
            while true {
                try? await Task.sleep(for: .seconds(tick))
                guard !Task.isCancelled else { return }
                elapsed += tick
            }
        }
    }

    func tap(circleID: Int) {
        guard gameState == .playing else { return }
        if circleID == nextTarget {
            // Correct tap
            if let idx = circles.firstIndex(where: { $0.id == circleID }) {
                circles[idx].tapped = true
            }
            Haptics.light()
            nextTarget += 1
            if nextTarget > circleCount {
                // Round complete
                timerTask?.cancel()
                roundTimes.append(elapsed)
                currentRound += 1
                if currentRound >= totalRounds {
                    endGame()
                } else {
                    // Brief pause then next round
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        guard self.gameState == .playing else { return }
                        self.startRound()
                    }
                }
            }
        } else {
            // Wrong tap — shake
            Haptics.error()
            shakeTargetID = circleID
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                self.shakeTargetID = nil
            }
        }
    }

    private func endGame() {
        timerTask?.cancel()
        let avg = roundTimes.isEmpty ? 0.0 : roundTimes.reduce(0, +) / Double(roundTimes.count)
        finalAvg = avg
        finalBrainScore = max(70, min(145, Int(110.0 - (avg - 20.0) * 2.5)))
        onGameOver?(avg)
        gameState = .gameOver
    }

    // MARK: - Circle placement (rejection sampling, min 80pt apart)

    private func placedCircles() -> [Circle] {
        let r = circleSize / 2
        let margin = r + 8
        let minDist: CGFloat = 80
        var positions: [CGPoint] = []
        var circles: [Circle] = []
        let maxAttempts = 500

        for num in 1...circleCount {
            var placed = false
            for _ in 0..<maxAttempts {
                let x = CGFloat.random(in: margin...(arenaSize.width - margin))
                let y = CGFloat.random(in: margin...(arenaSize.height - margin))
                let pt = CGPoint(x: x, y: y)
                let tooClose = positions.contains { dist($0, pt) < minDist }
                if !tooClose {
                    positions.append(pt)
                    circles.append(Circle(id: num, position: pt))
                    placed = true
                    break
                }
            }
            if !placed {
                // Fallback: just place it (rare)
                let x = CGFloat.random(in: margin...(arenaSize.width - margin))
                let y = CGFloat.random(in: margin...(arenaSize.height - margin))
                positions.append(CGPoint(x: x, y: y))
                circles.append(Circle(id: num, position: CGPoint(x: x, y: y)))
            }
        }
        return circles
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - View

struct NumberTrailGameView: View {
    @StateObject private var vm = NumberTrailViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("numberTrailDifficulty") private var difficulty: Difficulty = .medium

    private let gameColor = Color(red: 0.75, green: 0.5, blue: 0.1)

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats()
        modelContext.insert(s)
        return s
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
        .navigationTitle("Number Trail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { avgSeconds in
                let isNewBest: Bool
                if stats.numberTrailBestTime == 0 {
                    isNewBest = true
                } else {
                    isNewBest = avgSeconds < stats.numberTrailBestTime
                }
                let session = GameSession(
                    gameType: "numbertrail",
                    rawScore: Int(avgSeconds),
                    brainScore: max(70, min(145, Int(110.0 - (avgSeconds - 20.0) * 2.5))),
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                let leveledUp = stats.recordNumberTrailGame(avgSeconds: avgSeconds)
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
    }

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:     idleView
        case .playing:  playView
        case .gameOver: gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 72))
                    .foregroundStyle(gameColor)
                Text("Number Trail")
                    .font(.largeTitle.bold())
                Text("Tap the numbered circles in order,\n1 → 2 → 3 → … as fast as you can.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if stats.numberTrailBestTime > 0 {
                    Label(String(format: "Best: %.1f s avg", stats.numberTrailBestTime), systemImage: "trophy.fill")
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
                    .background(gameColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Play

    var playView: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack {
                StatBadge(label: "Round", value: "\(vm.currentRound + 1)/\(vm.totalRounds)", color: gameColor)
                Spacer()
                StatBadge(label: "Next", value: "\(vm.nextTarget)", color: .primary)
                Spacer()
                StatBadge(label: "Time", value: String(format: "%.1fs", vm.elapsed), color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Arena
            GeometryReader { geo in
                ZStack {
                    Color(.secondarySystemBackground)
                        .ignoresSafeArea(edges: .bottom)

                    ForEach(vm.circles) { circle in
                        circleView(circle)
                            .position(circle.position)
                    }
                }
                .onAppear {
                    vm.setArenaSize(geo.size)
                }
                .contentShape(Rectangle())
            }
        }
    }

    func circleView(_ circle: NumberTrailViewModel.Circle) -> some View {
        let isTapped = circle.tapped
        let isNext = circle.id == vm.nextTarget
        let isShaking = vm.shakeTargetID == circle.id

        return ZStack {
            SwiftUI.Circle()
                .fill(isTapped ? Color.green : (isNext ? gameColor : Color(.secondarySystemBackground)))
                .frame(width: vm.circleSize, height: vm.circleSize)
                .overlay(
                    SwiftUI.Circle()
                        .stroke(isTapped ? Color.green : gameColor, lineWidth: 2)
                )

            Text("\(circle.id)")
                .font(.system(size: vm.circleSize * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(isTapped ? .white : (isNext ? .white : gameColor))
        }
        .modifier(ShakeEffect(animating: isShaking))
        .onTapGesture {
            if !isTapped { vm.tap(circleID: circle.id) }
        }
        .animation(.easeInOut(duration: 0.2), value: isTapped)
    }

    // MARK: - Game Over

    var gameOverView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 56))
                    .foregroundStyle(gameColor)

                Text("Done!")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    // Round times
                    ForEach(vm.roundTimes.indices, id: \.self) { i in
                        resultRow("Round \(i + 1)", value: String(format: "%.2f s", vm.roundTimes[i]), color: gameColor)
                    }
                    Divider()
                    resultRow("Avg Time",     value: String(format: "%.2f s", vm.finalAvg),    color: .primary)
                    Divider()
                    resultRow("Brain Score",  value: "\(vm.finalBrainScore)",                  color: .indigo)
                    if stats.numberTrailBestTime > 0 {
                        resultRow("All-Time Best", value: String(format: "%.2f s", stats.numberTrailBestTime), color: .secondary)
                    }
                    Divider()
                    resultRow("vs. Average",
                              value: PlayerStats.percentileLabel(for: vm.finalBrainScore),
                              color: scoreColor(vm.finalBrainScore))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            ShareResultButton(
                gameName: "Number Trail",
                gameIcon: "arrow.triangle.branch",
                gameColor: gameColor,
                primaryValue: String(format: "%.1f s", vm.finalAvg),
                primaryLabel: "avg",
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
                    .background(gameColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    func resultRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

    func scoreColor(_ score: Int) -> Color {
        if score >= 120 { return .green }
        if score >= 100 { return .teal }
        if score >= 85  { return .orange }
        return .red
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var animating: Bool
    var amount: CGFloat = 8
    var shakesPerUnit = 3

    var animatableData: CGFloat {
        get { animating ? 1 : 0 }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    NavigationStack { NumberTrailGameView() }
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
