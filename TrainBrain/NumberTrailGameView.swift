import SwiftUI
import SwiftData

// MARK: - Dot Connect (was Number Trail)
// Connect the dots to reveal a hidden picture. 3 rounds, lower avg time is better.

// MARK: - DotPicture Library

struct DotPicture {
    let name: String
    let points: [CGPoint]   // normalized 0–1 coordinates
}

private let dotPictures: [DotPicture] = [
    DotPicture(name: "House", points: [
        CGPoint(x:0.5, y:0.1), CGPoint(x:0.9, y:0.4), CGPoint(x:0.8, y:0.4),
        CGPoint(x:0.8, y:0.9), CGPoint(x:0.2, y:0.9), CGPoint(x:0.2, y:0.4),
        CGPoint(x:0.1, y:0.4), CGPoint(x:0.5, y:0.1)
    ]),
    DotPicture(name: "Star", points: [
        CGPoint(x:0.5, y:0.05), CGPoint(x:0.62, y:0.35), CGPoint(x:0.95, y:0.35),
        CGPoint(x:0.69, y:0.55), CGPoint(x:0.79, y:0.88), CGPoint(x:0.5, y:0.68),
        CGPoint(x:0.21, y:0.88), CGPoint(x:0.31, y:0.55), CGPoint(x:0.05, y:0.35),
        CGPoint(x:0.38, y:0.35), CGPoint(x:0.5, y:0.05)
    ]),
    DotPicture(name: "Heart", points: [
        CGPoint(x:0.5, y:0.9), CGPoint(x:0.1, y:0.5), CGPoint(x:0.1, y:0.3),
        CGPoint(x:0.3, y:0.1), CGPoint(x:0.5, y:0.3), CGPoint(x:0.7, y:0.1),
        CGPoint(x:0.9, y:0.3), CGPoint(x:0.9, y:0.5), CGPoint(x:0.5, y:0.9)
    ]),
    DotPicture(name: "Fish", points: [
        CGPoint(x:0.1, y:0.5), CGPoint(x:0.2, y:0.3), CGPoint(x:0.4, y:0.2),
        CGPoint(x:0.6, y:0.2), CGPoint(x:0.8, y:0.3), CGPoint(x:0.9, y:0.5),
        CGPoint(x:0.8, y:0.7), CGPoint(x:0.6, y:0.8), CGPoint(x:0.4, y:0.8),
        CGPoint(x:0.2, y:0.7), CGPoint(x:0.1, y:0.5)
    ]),
    DotPicture(name: "Arrow", points: [
        CGPoint(x:0.5, y:0.05), CGPoint(x:0.95, y:0.5), CGPoint(x:0.7, y:0.5),
        CGPoint(x:0.7, y:0.95), CGPoint(x:0.3, y:0.95), CGPoint(x:0.3, y:0.5),
        CGPoint(x:0.05, y:0.5), CGPoint(x:0.5, y:0.05)
    ]),
    DotPicture(name: "Lightning", points: [
        CGPoint(x:0.6, y:0.05), CGPoint(x:0.3, y:0.5), CGPoint(x:0.55, y:0.5),
        CGPoint(x:0.4, y:0.95), CGPoint(x:0.7, y:0.4), CGPoint(x:0.45, y:0.4),
        CGPoint(x:0.6, y:0.05)
    ]),
    DotPicture(name: "Tree", points: [
        CGPoint(x:0.5, y:0.05), CGPoint(x:0.15, y:0.5), CGPoint(x:0.35, y:0.5),
        CGPoint(x:0.2, y:0.75), CGPoint(x:0.4, y:0.75), CGPoint(x:0.35, y:0.95),
        CGPoint(x:0.65, y:0.95), CGPoint(x:0.6, y:0.75), CGPoint(x:0.8, y:0.75),
        CGPoint(x:0.65, y:0.5), CGPoint(x:0.85, y:0.5), CGPoint(x:0.5, y:0.05)
    ]),
    DotPicture(name: "Moon", points: [
        CGPoint(x:0.7, y:0.1), CGPoint(x:0.4, y:0.15), CGPoint(x:0.2, y:0.3),
        CGPoint(x:0.1, y:0.5), CGPoint(x:0.2, y:0.7), CGPoint(x:0.4, y:0.85),
        CGPoint(x:0.7, y:0.9), CGPoint(x:0.65, y:0.75), CGPoint(x:0.55, y:0.6),
        CGPoint(x:0.5, y:0.5), CGPoint(x:0.55, y:0.4), CGPoint(x:0.65, y:0.25),
        CGPoint(x:0.7, y:0.1)
    ]),
]

// MARK: - Dot Identifier
// In alpha mode labels alternate: 1, A, 2, B, 3, C…

private func dotLabel(index: Int, alphaMode: Bool) -> String {
    if !alphaMode { return "\(index + 1)" }
    // index 0→"1", 1→"A", 2→"2", 3→"B" …
    let pair = index / 2
    if index % 2 == 0 {
        return "\(pair + 1)"
    } else {
        let letter = UnicodeScalar(Int(("A" as UnicodeScalar).value) + pair)!
        return String(letter)
    }
}

// MARK: - ViewModel

@MainActor
class NumberTrailViewModel: ObservableObject {
    enum GameState { case idle, playing, revealing, gameOver }

    struct Dot: Identifiable {
        let id: Int            // tap order (0-based)
        var position: CGPoint
        var tapped: Bool = false
        var bouncing: Bool = false
        let label: String
    }

    @Published var gameState: GameState = .idle
    @Published var dots: [Dot] = []
    @Published var nextTarget: Int = 0    // 0-based index of next dot to tap
    @Published var elapsed: Double = 0
    @Published var roundTimes: [Double] = []
    @Published var currentRound: Int = 0
    @Published var trailPoints: [CGPoint] = []
    @Published var currentPicture: DotPicture = dotPictures[0]
    @Published var showPictureName: Bool = false
    @Published var finalAvg: Double = 0
    @Published var finalBrainScore: Int = 0
    @Published var alphaMode: Bool = false

    // Bounce trigger per dot (map id → Bool toggle)
    @Published var bounceTriggers: [Int: Bool] = [:]

    let totalRounds = 3
    var onGameOver: ((Double) -> Void)?

    private var difficulty: Difficulty = .medium
    private var timerTask: Task<Void, Never>?
    private var arenaSize: CGSize = CGSize(width: 350, height: 550)
    private var roundIndex: Int = 0   // for picture selection
    private var eloCircleCount: Int = 12
    private var eloCircleSize: CGFloat = 36

    var circleCount: Int { eloCircleCount }
    var circleSize: CGFloat { eloCircleSize }

    func setArenaSize(_ size: CGSize) { arenaSize = size }

    // MARK: - Start

    func startGame(difficulty: Difficulty, trailElo: Double) {
        self.difficulty = difficulty
        let params = EloSystem.trailParams(trailElo)
        eloCircleCount = params.circleCount
        eloCircleSize  = params.circleSize
        alphaMode      = params.useAlphaMode
        currentRound   = 0
        roundIndex     = 0
        roundTimes     = []
        trailPoints    = []
        showPictureName = false
        gameState      = .playing
        startRound()
    }

    // MARK: - Round

    private func startRound() {
        timerTask?.cancel()
        elapsed     = 0
        nextTarget  = 0
        trailPoints = []
        showPictureName = false
        bounceTriggers = [:]

        // Pick picture for this round
        currentPicture = dotPictures[roundIndex % dotPictures.count]
        roundIndex += 1

        dots = makeDots()
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

    // MARK: - Tap

    func tap(dotID: Int) {
        guard gameState == .playing else { return }
        if dotID == nextTarget {
            // Correct tap
            if let idx = dots.firstIndex(where: { $0.id == dotID }) {
                dots[idx].tapped = true
                trailPoints.append(dots[idx].position)
            }
            // Trigger bounce
            bounceTriggers[dotID] = !(bounceTriggers[dotID] ?? false)
            SoundEngine.shared.playCorrect()
            Haptics.light()
            nextTarget += 1

            if nextTarget >= circleCount {
                // Round complete — reveal phase
                timerTask?.cancel()
                roundTimes.append(elapsed)
                gameState = .revealing
                SoundEngine.shared.playSuccess()
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    showPictureName = true
                    try? await Task.sleep(for: .seconds(1.8))
                    currentRound += 1
                    if currentRound >= totalRounds {
                        endGame()
                    } else {
                        gameState = .playing
                        startRound()
                    }
                }
            }
        } else {
            // Wrong tap
            SoundEngine.shared.playWrong()
            Haptics.error()
        }
    }

    // MARK: - End

    private func endGame() {
        timerTask?.cancel()
        let avg = roundTimes.isEmpty ? 0.0 : roundTimes.reduce(0, +) / Double(roundTimes.count)
        finalAvg = avg
        finalBrainScore = max(0, Int(110 - (avg - 20) * 2.5))
        onGameOver?(avg)
        gameState = .gameOver
    }

    // MARK: - Dot Placement from picture

    private func makeDots() -> [Dot] {
        let count = circleCount
        let pic   = currentPicture
        let picPoints = pic.points

        // Use picture points (scaled) for the first N dots (capped to count)
        let usedCount = min(count, picPoints.count)
        let margin    = circleSize / 2 + 6
        let w = arenaSize.width
        let h = arenaSize.height

        var positions: [CGPoint] = []

        // Scale picture points to arena
        for i in 0..<usedCount {
            let norm = picPoints[i]
            let x = margin + norm.x * (w - margin * 2)
            let y = margin + norm.y * (h - margin * 2)
            positions.append(CGPoint(x: x, y: y))
        }

        // If we need more than the picture provides, place randomly
        if count > usedCount {
            let minDist: CGFloat = max(circleSize * 1.5, 60)
            for _ in usedCount..<count {
                var placed = false
                for _ in 0..<300 {
                    let x = CGFloat.random(in: margin...(w - margin))
                    let y = CGFloat.random(in: margin...(h - margin))
                    let pt = CGPoint(x: x, y: y)
                    if !positions.contains(where: { dist($0, pt) < minDist }) {
                        positions.append(pt)
                        placed = true
                        break
                    }
                }
                if !placed {
                    positions.append(CGPoint(
                        x: CGFloat.random(in: margin...(w - margin)),
                        y: CGFloat.random(in: margin...(h - margin))
                    ))
                }
            }
        }

        return positions.indices.map { i in
            Dot(id: i,
                position: positions[i],
                label: dotLabel(index: i, alphaMode: alphaMode))
        }
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x; let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - Trail Canvas

private struct TrailCanvas: View {
    let points: [CGPoint]

    var body: some View {
        ZStack {
            // Outer glow layer
            Canvas { ctx, _ in
                drawPath(ctx: ctx, opacity: 0.2, lineWidth: 14)
            }
            // Mid glow layer
            Canvas { ctx, _ in
                drawPath(ctx: ctx, opacity: 0.4, lineWidth: 7)
            }
            // Core line
            Canvas { ctx, _ in
                drawPath(ctx: ctx, opacity: 1.0, lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawPath(ctx: GraphicsContext, opacity: Double, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Color.blue.opacity(opacity),
                    Color.purple.opacity(opacity)
                ]),
                startPoint: points.first ?? .zero,
                endPoint: points.last ?? .zero
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - View

struct NumberTrailGameView: View {
    @StateObject private var vm = NumberTrailViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]
    @AppStorage("numberTrailDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats(); modelContext.insert(s); return s
    }

    var body: some View {
        ZStack {
            mainContent
        }
        .navigationTitle("Dot Connect")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { avgSeconds in
                let brainScore = max(0, Int(110 - (avgSeconds - 20) * 2.5))
                let session = GameSession(
                    gameType: "numbertrail",
                    rawScore: Int(avgSeconds),
                    brainScore: brainScore,
                    difficulty: difficulty.rawValue
                )
                modelContext.insert(session)
                stats.recordNumberTrailGame(avgSeconds: avgSeconds)
                stats.numberTrailEloRating = EloSystem.updated(stats.numberTrailEloRating, correct: avgSeconds < 30)
            }
        }
    }

    @ViewBuilder
    var mainContent: some View {
        switch vm.gameState {
        case .idle:                idleView
        case .playing, .revealing: playView
        case .gameOver:            gameOverView
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.cyan)
                Text("Dot Connect")
                    .font(.largeTitle.bold())
                Text("Tap the dots in order to reveal\na hidden picture. 3 rounds.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if vm.alphaMode || EloSystem.trailParams(stats.numberTrailEloRating).useAlphaMode {
                    Label("Alpha Trail: 1→A→2→B…", systemImage: "textformat.alt")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }

                if stats.numberTrailBestTime > 0 {
                    Label(String(format: "Best: %.1fs avg", stats.numberTrailBestTime), systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }
            Spacer()

            DifficultyPicker(difficulty: $difficulty)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Button {
                vm.startGame(difficulty: difficulty, trailElo: stats.numberTrailEloRating)
            } label: {
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
        VStack(spacing: 0) {
            // Stats bar
            HStack {
                StatBadge(label: "Round", value: "\(vm.currentRound + 1)/\(vm.totalRounds)", color: .cyan)
                Spacer()
                if vm.alphaMode {
                    Text("1→A→2→B")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
                Spacer()
                StatBadge(label: "Time", value: String(format: "%.1fs", vm.elapsed), color: .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Arena
            GeometryReader { geo in
                ZStack {
                    Color(.secondarySystemBackground)
                        .ignoresSafeArea(edges: .bottom)

                    // Trail lines
                    TrailCanvas(points: vm.trailPoints)

                    // Dots
                    ForEach(vm.dots) { dot in
                        dotCircleView(dot, geo: geo)
                            .position(dot.position)
                    }

                    // Reveal name
                    if vm.showPictureName {
                        Text("You drew a \(vm.currentPicture.name)!")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .shadow(color: .blue.opacity(0.5), radius: 12)
                            .transition(.scale.combined(with: .opacity))
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.82)
                    }
                }
                .onAppear {
                    vm.setArenaSize(geo.size)
                }
                .contentShape(Rectangle())
            }
        }
        .animation(.spring(response: 0.4), value: vm.showPictureName)
    }

    @ViewBuilder
    func dotCircleView(_ dot: NumberTrailViewModel.Dot, geo: GeometryProxy) -> some View {
        let isTapped = dot.tapped
        let isNext   = dot.id == vm.nextTarget
        let bounce   = vm.bounceTriggers[dot.id] ?? false
        let size     = vm.circleSize

        ZStack {
            Circle()
                .fill(isTapped ? Color.cyan : (isNext ? Color.blue : Color(.secondarySystemBackground)))
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(isTapped ? Color.cyan : Color.blue, lineWidth: 2)
                )
                .shadow(
                    color: isTapped ? Color.cyan.opacity(0.5) : (isNext ? Color.blue.opacity(0.4) : .clear),
                    radius: isTapped ? 8 : 4
                )

            Text(dot.label)
                .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
                .foregroundStyle(isTapped ? .white : (isNext ? .white : Color.blue))
                .opacity(isTapped ? 0.0 : 1.0)   // fade label after tap
        }
        .juiceBounce(trigger: bounce)
        .animation(.easeInOut(duration: 0.25), value: isTapped)
        .onTapGesture {
            if !isTapped { vm.tap(dotID: dot.id) }
        }
    }

    // MARK: - Game Over

    var gameOverView: some View {
        let avg = vm.finalAvg
        let brainScore = max(0, Int(110 - (avg - 20) * 2.5))
        let primaryScore = brainScore

        let result = GameResult(
            gameTitle: "Dot Connect",
            primaryScore: primaryScore,
            primaryLabel: "score",
            brainScore: brainScore,
            previousBrainScore: stats.numberTrailBrainScore,
            isNewBest: stats.numberTrailBestTime > 0 && avg < stats.numberTrailBestTime,
            multiplierBreakdown: nil,
            percentileText: PlayerStats.percentileLabel(for: brainScore),
            accentColor: .cyan,
            share: GameResult.ShareConfig(
                gameName: "Dot Connect",
                icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                color: .cyan,
                primaryValue: String(format: "%.1f", avg),
                primaryLabel: "avg sec",
                secondaryLine: "Brain Score \(brainScore)"
            )
        )

        return GameOverView(result: result) {
            vm.startGame(difficulty: difficulty, trailElo: stats.numberTrailEloRating)
        }
    }
}

// MARK: - ShakeEffect (kept for compatibility)

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
