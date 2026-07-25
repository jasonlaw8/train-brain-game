import SwiftUI
import SwiftData

// MARK: - OnboardingView
// Brain-facts intro slides (our content) + animated game-demo pages (polished interactive previews).
// Uses onComplete callback; onboarding state is tracked via @AppStorage("hasOnboarded") in TrainBrainApp.

struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var statsQuery: [PlayerStats]

    private var stats: PlayerStats {
        statsQuery.first ?? PlayerStats.fetchOrCreate(in: modelContext)
    }

    @State private var currentPage = 0
    @State private var selectedAgeRange: String = ""
    @State private var launchSnapshot = false

    // Pages: 0-2 = brain facts, 3 = age range, 4-11 = game demos, 12 = brain snapshot intro
    private let totalPages = 13

    var body: some View {
        ZStack(alignment: .top) {
            AnimatedGradientBackground().ignoresSafeArea()
            Color(.systemBackground).opacity(0.88).ignoresSafeArea()

            // Skip button (not on last two pages)
            if currentPage < totalPages - 2 {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.35)) { onComplete() }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                .transition(.opacity)
                .zIndex(1)
            }

            TabView(selection: $currentPage) {
                // Brain-facts slides
                BrainFactSlide(
                    icon: "brain.filled.head.profile", iconColor: .blue,
                    title: "Your Brain Is a Muscle",
                    message: "Just like physical fitness, cognitive fitness improves with consistent training. Scientists call this neuroplasticity — your brain physically rewires itself with practice.",
                    fact: "People who train their memory for 5 minutes a day show measurable improvement in as little as 2 weeks."
                ) { withAnimation { currentPage += 1 } }
                    .tag(0)

                BrainFactSlide(
                    icon: "chart.line.uptrend.xyaxis", iconColor: .indigo,
                    title: "Track Your Brain Score",
                    message: "Train Brain measures four cognitive domains and gives you a Brain Score from 0 to 1000. Compare to people your age.",
                    fact: "Studies show that tracking progress increases training consistency by up to 40%."
                ) { withAnimation { currentPage += 1 } }
                    .tag(1)

                BrainFactSlide(
                    icon: "flame.fill", iconColor: .red,
                    title: "Consistency Is Everything",
                    message: "Five minutes a day beats two hours on the weekend. Daily challenges keep your streak alive and your brain in peak condition.",
                    fact: "Habit research shows a 7-day streak makes you 80% more likely to stick with a new routine long-term."
                ) { withAnimation { currentPage += 1 } }
                    .tag(2)

                // Age range page (for norm-referenced scoring)
                AgeRangeOnboardingPage(selectedAgeRange: $selectedAgeRange) {
                    if !selectedAgeRange.isEmpty {
                        stats.ageRange = selectedAgeRange
                    }
                    withAnimation { currentPage += 1 }
                }
                .tag(3)

                // Animated game-demo pages
                MemoryOnboardingPage()
                    .tag(4)

                ColorOnboardingPage()
                    .tag(5)

                SpatialMemoryOnboardingPage()
                    .tag(6)

                FlankerOnboardingPage()
                    .tag(7)

                ReflexOnboardingPage()
                    .tag(8)

                MathBlitzOnboardingPage()
                    .tag(9)

                VisualSearchOnboardingPage()
                    .tag(10)

                PatternMatchOnboardingPage(onComplete: { withAnimation { currentPage += 1 } })
                    .tag(11)

                // Brain Snapshot intro — final page
                BrainSnapshotOnboardingPage(
                    ageRange: selectedAgeRange,
                    onStartSnapshot: {
                        // Persist age range to PlayerStats before completing onboarding
                        if !selectedAgeRange.isEmpty {
                            stats.ageRange = selectedAgeRange
                        }
                        onComplete()
                    }
                )
                .tag(12)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
        }
    }
}

// MARK: - Brain Fact Slide (our content)

private struct BrainFactSlide: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let fact: String
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse)

            VStack(spacing: 14) {
                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.footnote)
                    .padding(.top, 2)
                Text(fact)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 8)

            Spacer()
            Spacer()

            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 16)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Page: Memory (animated tile demo)

private struct MemoryOnboardingPage: View {
    @State private var iconBounce = false
    @State private var litTiles: Set<Int> = []

    private let tileColors: [Color] = [
        .blue, .red, .green, .purple, .orange, .cyan, .pink, .yellow, .teal
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle(); startTileAnimation() }

            VStack(spacing: 8) {
                Text("Memory")
                    .font(.largeTitle.bold())
                Text("Watch the sequence,\nthen tap it back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(72), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(0..<9) { i in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tileColors[i].opacity(litTiles.contains(i) ? 0.85 : 0.20))
                        .frame(width: 72, height: 72)
                        .scaleEffect(litTiles.contains(i) ? 1.08 : 1.0)
                        .shadow(color: tileColors[i].opacity(litTiles.contains(i) ? 0.45 : 0),
                                radius: 8, x: 0, y: 4)
                        .animation(.easeInOut(duration: 0.25), value: litTiles.contains(i))
                }
            }
            .padding(.horizontal, 32)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func startTileAnimation() {
        let sequence = (0..<9).shuffled()
        for (step, tile) in sequence.enumerated() {
            let onDelay  = Double(step) * 0.55
            let offDelay = onDelay + 0.38
            DispatchQueue.main.asyncAfter(deadline: .now() + onDelay)  { litTiles.insert(tile) }
            DispatchQueue.main.asyncAfter(deadline: .now() + offDelay) { litTiles.remove(tile) }
        }
        let restart = Double(sequence.count) * 0.55 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + restart) { startTileAnimation() }
    }
}

// MARK: - Page: Color / Stroop demo

private struct ColorOnboardingPage: View {
    @State private var iconBounce = false
    @State private var selectedColor: Color? = nil
    @State private var feedbackScale: CGFloat = 1.0

    private let colorButtons: [(label: String, color: Color)] = [
        ("Red", .red), ("Blue", .blue), ("Green", .green), ("Purple", .purple)
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "paintpalette.fill")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle() }

            VStack(spacing: 8) {
                Text("Color")
                    .font(.largeTitle.bold())
                Text("Tap the COLOR — not what it says")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            VStack(spacing: 20) {
                Text("BLUE")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.red)
                    .scaleEffect(feedbackScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: feedbackScale)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(colorButtons, id: \.label) { item in
                        Button {
                            selectedColor = item.color
                            withAnimation { feedbackScale = 1.18 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation { feedbackScale = 1.0 }
                            }
                        } label: {
                            Text(item.label)
                                .font(.callout.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(item.color.opacity(selectedColor == item.color ? 1.0 : 0.75)))
                                .scaleEffect(selectedColor == item.color ? 1.04 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: selectedColor == item.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Page: Reflex demo (intermediate — no Get Started)

private struct ReflexOnboardingPage: View {
    @State private var iconBounce = false
    @State private var circleScale: CGFloat = 1.0
    @State private var circleGlow = false
    @State private var tapped = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle() }

            VStack(spacing: 8) {
                Text("Reflex")
                    .font(.largeTitle.bold())
                Text("Tap the circle\nas fast as you can")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            Button {
                tapped = true
                withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { circleScale = 0.82 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { circleScale = 1.0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { tapped = false }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(tapped ? 1.0 : 0.85))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.orange.opacity(circleGlow ? 0.6 : 0.25),
                                radius: circleGlow ? 22 : 10)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(circleScale)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    circleGlow.toggle()
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Page: Math Blitz demo (intermediate)

private struct MathBlitzOnboardingPage: View {
    @State private var iconBounce = false
    @State private var currentProblemIndex = 0
    @State private var highlightedAnswer: Int? = nil

    private let problems: [(question: String, answers: [Int], correctIndex: Int)] = [
        ("7 + 3", [10, 8, 12, 5], 0),
        ("12 − 5", [9, 7, 6, 8], 1),
        ("4 × 6", [18, 28, 24, 20], 2),
    ]

    private var current: (question: String, answers: [Int], correctIndex: Int) {
        problems[currentProblemIndex]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "function")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle(); startDemoLoop() }

            VStack(spacing: 8) {
                Text("Math Blitz")
                    .font(.largeTitle.bold())
                Text("Answer as many problems as you can\nin 60 seconds")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text("\(current.question) = ?")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .animation(nil, value: currentProblemIndex)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(current.answers.enumerated()), id: \.offset) { i, answer in
                        Text("\(answer)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(highlightedAnswer == i
                                          ? Color.green
                                          : Color(.tertiarySystemBackground))
                            )
                            .foregroundStyle(highlightedAnswer == i ? .white : .primary)
                            .animation(.easeInOut(duration: 0.25), value: highlightedAnswer)
                    }
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func startDemoLoop() {
        func showAnswer() {
            highlightedAnswer = current.correctIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                highlightedAnswer = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    currentProblemIndex = (currentProblemIndex + 1) % problems.count
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showAnswer() }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showAnswer() }
    }
}

// MARK: - Page: Spatial Memory demo

private struct SpatialMemoryOnboardingPage: View {
    @State private var iconBounce = false
    @State private var litCells: Set<Int> = []
    @State private var phase: Int = 0   // 0=show, 1=hide

    private let gridSize = 4   // 4×4

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.cyan)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle(); startAnimation() }

            VStack(spacing: 8) {
                Text("Spatial Memory")
                    .font(.largeTitle.bold())
                Text("Memorize the highlighted cells,\nthen tap them from memory")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(56), spacing: 8), count: gridSize),
                spacing: 8
            ) {
                ForEach(0..<(gridSize * gridSize), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(litCells.contains(i) ? Color.cyan.opacity(0.85) : Color(.systemGray5))
                        .frame(width: 56, height: 56)
                        .scaleEffect(litCells.contains(i) ? 1.06 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: litCells.contains(i))
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func startAnimation() {
        let targets = Array((0..<(gridSize * gridSize)).shuffled().prefix(5))
        withAnimation { litCells = Set(targets) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { litCells = [] }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { startAnimation() }
        }
    }
}

// MARK: - Page: Flanker Task demo

private struct FlankerOnboardingPage: View {
    @State private var iconBounce = false
    @State private var arrowIndex = 0
    @State private var highlight: Bool = false

    // (flankers, center) pairs cycling through congruent/incongruent/neutral
    private let trials: [(flanker: String, center: String, label: String)] = [
        ("→ → ", "→", "→ →  — congruent"),
        ("← ← ", "→", "← →  — incongruent"),
        ("— — ", "←", "—  ←  — neutral"),
    ]

    private var current: (flanker: String, center: String, label: String) { trials[arrowIndex] }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.teal)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle(); startLoop() }

            VStack(spacing: 8) {
                Text("Flanker Task")
                    .font(.largeTitle.bold())
                Text("Which way does the CENTER arrow point?\nIgnore the flanking arrows")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            VStack(spacing: 20) {
                // Arrow display
                HStack(spacing: 0) {
                    Text(current.flanker)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(current.center)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.teal)
                    Text(String(current.flanker.reversed()))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .animation(nil, value: arrowIndex)

                Text(current.label)
                    .font(.caption).foregroundStyle(.secondary).italic()
                    .animation(nil, value: arrowIndex)

                HStack(spacing: 16) {
                    Text("←")
                        .font(.title.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.teal.opacity(0.8)))
                    Text("→")
                        .font(.title.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.teal.opacity(0.8)))
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func startLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            arrowIndex = (arrowIndex + 1) % trials.count
            startLoop()
        }
    }
}

// MARK: - Page: Visual Search demo

private struct VisualSearchOnboardingPage: View {
    @State private var iconBounce = false
    @State private var targetIndex = 0
    @State private var symbols: [String] = []

    private let distractorSymbol = "circle.fill"
    private let targetSymbol = "star.fill"
    private let gridCount = 12

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "eye.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle(); generateGrid(); startLoop() }

            VStack(spacing: 8) {
                Text("Visual Search")
                    .font(.largeTitle.bold())
                Text("Find the odd symbol\nbefore time runs out")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(0..<gridCount, id: \.self) { i in
                    Image(systemName: symbols.indices.contains(i) ? symbols[i] : distractorSymbol)
                        .font(.system(size: 28))
                        .foregroundStyle(i == targetIndex ? Color.indigo : Color(.systemGray3))
                        .frame(width: 52, height: 52)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .scaleEffect(i == targetIndex ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: targetIndex)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.tertiarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func generateGrid() {
        targetIndex = Int.random(in: 0..<gridCount)
        symbols = (0..<gridCount).map { i in i == targetIndex ? targetSymbol : distractorSymbol }
    }

    private func startLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            generateGrid()
            startLoop()
        }
    }
}

// MARK: - Page: Pattern Match demo + Get Started

private struct PatternMatchOnboardingPage: View {
    var onComplete: () -> Void

    @State private var iconBounce = false
    @State private var problemIndex = 0
    @State private var highlightedChoice: Int? = nil

    private let problems: [(sequence: String, choices: [Int], correctIndex: Int)] = [
        ("2,  4,  6,  ?", [8, 5, 10, 7], 0),
        ("3,  6,  12,  ?", [24, 15, 18, 9], 0),
        ("10,  7,  4,  ?", [1, 3, 0, 2], 0),
    ]

    private var current: (sequence: String, choices: [Int], correctIndex: Int) {
        problems[problemIndex]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle(); startDemoLoop() }

            VStack(spacing: 8) {
                Text("Pattern Match")
                    .font(.largeTitle.bold())
                Text("Find the rule and pick\nthe next number in the sequence")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text(current.sequence)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .animation(nil, value: problemIndex)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(current.choices.enumerated()), id: \.offset) { i, val in
                        Text("\(val)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(highlightedChoice == i
                                          ? Color.pink
                                          : Color(.tertiarySystemBackground))
                            )
                            .foregroundStyle(highlightedChoice == i ? .white : .primary)
                            .animation(.easeInOut(duration: 0.25), value: highlightedChoice)
                    }
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.85)))
            .padding(.horizontal, 32)

            Button {
                withAnimation(.easeInOut(duration: 0.35)) { onComplete() }
            } label: {
                Text("Get Started")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.pink))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32).padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func startDemoLoop() {
        func showAnswer() {
            highlightedChoice = current.correctIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                highlightedChoice = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    problemIndex = (problemIndex + 1) % problems.count
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showAnswer() }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showAnswer() }
    }
}

// MARK: - Page: Age Range (norm-referenced scoring)

private struct AgeRangeOnboardingPage: View {
    @Binding var selectedAgeRange: String
    let onNext: () -> Void

    private let ageRanges = ["18-24", "25-34", "35-44", "45-54", "55+"]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)

            VStack(spacing: 10) {
                Text("What's Your Age Range?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("We use this to compare your Brain Score with people your age. Your data stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 10) {
                ForEach(ageRanges, id: \.self) { range in
                    Button {
                        selectedAgeRange = range
                    } label: {
                        HStack {
                            Text(range)
                                .font(.body.bold())
                            Spacer()
                            if selectedAgeRange == range {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedAgeRange == range
                                      ? Color.indigo.opacity(0.12)
                                      : Color(.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedAgeRange == range
                                                ? Color.indigo.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text(selectedAgeRange.isEmpty ? "Skip for now" : "Continue")
                    Image(systemName: "chevron.right")
                }
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 16)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Page: Brain Snapshot intro (final onboarding page)

private struct BrainSnapshotOnboardingPage: View {
    let ageRange: String
    let onStartSnapshot: () -> Void

    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle() }

            VStack(spacing: 10) {
                Text("Your Brain Snapshot")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("4 quick tasks to measure your baseline across all four cognitive domains. Takes about 4 minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 12) {
                snapshotPoint(icon: "bolt.fill", color: .orange,
                              text: "Lightning Tap — Processing Speed")
                snapshotPoint(icon: "arrow.left.and.right", color: .indigo,
                              text: "Arrow Storm — Attention & Focus")
                snapshotPoint(icon: "rectangle.portrait.on.rectangle.portrait.fill", color: .blue,
                              text: "Card Match — Working Memory")
                snapshotPoint(icon: "square.on.circle.fill", color: .purple,
                              text: "Shape Shift — Cognitive Flexibility")
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            Button(action: onStartSnapshot) {
                Text("Let's Go!")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .blue],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 20)
    }

    func snapshotPoint(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
