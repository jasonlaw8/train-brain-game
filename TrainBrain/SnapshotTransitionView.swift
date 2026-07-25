import SwiftUI

// MARK: - SnapshotTask
// Identifies which task is coming next, for the transition screen.

enum SnapshotTask {
    case lightningTap
    case arrowStorm
    case cardMatch
    case shapeShift

    var title: String {
        switch self {
        case .lightningTap: return "Lightning Tap"
        case .arrowStorm:   return "Arrow Storm"
        case .cardMatch:    return "Card Match"
        case .shapeShift:   return "Shape Shift"
        }
    }

    var domain: String {
        switch self {
        case .lightningTap: return "Testing: Processing Speed"
        case .arrowStorm:   return "Testing: Attention & Focus"
        case .cardMatch:    return "Testing: Working Memory"
        case .shapeShift:   return "Testing: Cognitive Flexibility"
        }
    }

    var icon: String {
        switch self {
        case .lightningTap: return "bolt.fill"
        case .arrowStorm:   return "arrow.left.and.right"
        case .cardMatch:    return "rectangle.portrait.on.rectangle.portrait.fill"
        case .shapeShift:   return "square.on.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .lightningTap: return .orange
        case .arrowStorm:   return .indigo
        case .cardMatch:    return .blue
        case .shapeShift:   return .purple
        }
    }
}

// MARK: - SnapshotTransitionView
// Shown between tasks. Displays a looping demo animation, then 3-2-1 countdown.
// Calls onReady() when countdown completes.

struct SnapshotTransitionView: View {
    let nextTask: SnapshotTask
    let onReady: () -> Void

    @State private var countdown: Int = 3
    @State private var showCountdown: Bool = false
    @State private var demoAnimating: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            Image(systemName: nextTask.icon)
                .font(.system(size: 64))
                .foregroundStyle(nextTask.accentColor)
                .symbolEffect(.bounce, value: demoAnimating)

            // Task name + domain
            VStack(spacing: 6) {
                Text("Up Next")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(nextTask.title)
                    .font(.largeTitle.bold())
                Text(nextTask.domain)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            // Looping demo animation
            demoView
                .padding(.horizontal, 32)

            Spacer()

            // Countdown or "Get ready"
            if showCountdown {
                ZStack {
                    Circle()
                        .fill(nextTask.accentColor.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Text("\(countdown)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(nextTask.accentColor)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.25), value: countdown)
                }
                .padding(.bottom, 32)
            } else {
                Text("Watch how it works…")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            demoAnimating = true
            // Show demo for 5 seconds, then start countdown
            Task {
                try? await Task.sleep(for: .seconds(5))
                showCountdown = true
                Haptics.medium()
                for tick in stride(from: 3, through: 1, by: -1) {
                    countdown = tick
                    if tick < 3 {
                        Haptics.medium()
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
                onReady()
            }
        }
    }

    // MARK: - Demo animations (one per task)

    @ViewBuilder
    var demoView: some View {
        switch nextTask {
        case .lightningTap:  LightningTapDemoView(color: nextTask.accentColor)
        case .arrowStorm:    ArrowStormDemoView(color: nextTask.accentColor)
        case .cardMatch:     CardMatchDemoView(color: nextTask.accentColor)
        case .shapeShift:    ShapeShiftDemoView(color: nextTask.accentColor)
        }
    }
}

// MARK: - Lightning Tap Demo

private struct LightningTapDemoView: View {
    @State private var isVisible = true
    let color: Color
    @State private var visible = false
    @State private var x: CGFloat = 0.5
    @State private var y: CGFloat = 0.5

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6))
            if visible {
                Circle()
                    .fill(RadialGradient(colors: [.yellow, color], center: .center,
                                         startRadius: 0, endRadius: 44))
                    .shadow(color: color.opacity(0.5), radius: 12)
                    .frame(width: 72, height: 72)
                    .offset(x: (x - 0.5) * 180, y: (y - 0.5) * 80)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { animate() }
        .onDisappear { isVisible = false }
    }

    private func animate() {
        guard isVisible else { return }
        withAnimation(.spring(response: 0.3)) {
            visible = true
            x = CGFloat.random(in: 0.2...0.8)
            y = CGFloat.random(in: 0.2...0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) { visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animate() }
        }
    }
}

// MARK: - Arrow Storm Demo

private struct ArrowStormDemoView: View {
    @State private var isVisible = true
    let color: Color
    @State private var arrows: [String] = ["←","←","←","←","←"]
    @State private var highlight = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(arrows.indices, id: \.self) { i in
                    Text(arrows[i])
                        .font(.system(size: i == 2 ? 44 : 28, weight: .bold))
                        .foregroundStyle(i == 2 ? color : color.opacity(0.4))
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

            Text("Swipe in the center arrow's direction")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { cycleDemos() }
        .onDisappear { isVisible = false }
    }

    private func cycleDemos() {
        let examples: [[String]] = [
            ["←","←","←","←","←"],
            ["→","→","←","→","→"],
            ["←","←","→","←","←"],
            ["→","→","→","→","→"]
        ]
        var idx = 0
        func next() {
            guard isVisible else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                arrows = examples[idx % examples.count]
                idx += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { next() }
        }
        next()
    }
}

// MARK: - Card Match Demo

private struct CardMatchDemoView: View {
    @State private var isVisible = true
    let color: Color
    @State private var cardIndex = 0
    @State private var showCard = true

    private let demoCards = [("7","♥","red"), ("7","♥","red"), ("Q","♠","primary"), ("Q","♠","primary")]
    private let labels = ["", "Match!", "New", "Match!"]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Card
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                        .frame(width: 70, height: 95)
                    if showCard {
                        VStack(spacing: 2) {
                            Text(demoCards[cardIndex % demoCards.count].0)
                                .font(.system(size: 22, weight: .bold))
                            Text(demoCards[cardIndex % demoCards.count].1)
                                .font(.system(size: 28))
                        }
                        .foregroundStyle(demoCards[cardIndex % demoCards.count].2 == "red"
                                         ? Color.red : Color.primary)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showCard)

                // Label
                if cardIndex > 0 {
                    Text(labels[cardIndex % labels.count])
                        .font(.headline.bold())
                        .foregroundStyle(labels[cardIndex % labels.count] == "Match!" ? .green : .blue)
                }
            }

            HStack(spacing: 12) {
                Text("Match").font(.callout.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
                Text("New").font(.callout.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .onAppear { cycleCards() }
        .onDisappear { isVisible = false }
    }

    private func cycleCards() {
        guard isVisible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showCard = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                cardIndex += 1
                showCard = true
                cycleCards()
            }
        }
    }
}

// MARK: - Shape Shift Demo

private struct ShapeShiftDemoView: View {
    @State private var isVisible = true
    let color: Color
    @State private var ruleIdx = 0
    @State private var shapeIdx = 0

    private let rules   = ["SORT BY COLOR", "SORT BY SHAPE", "SORT BY COLOR"]
    private let icons   = ["paintpalette.fill", "square.on.circle.fill", "paintpalette.fill"]
    private let shapes  = ["circle.fill", "square.fill", "triangle.fill"]
    private let colors: [Color] = [.red, .blue, .green]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icons[ruleIdx % icons.count])
                Text(rules[ruleIdx % rules.count])
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
            .animation(.easeInOut(duration: 0.3), value: ruleIdx)

            Image(systemName: shapes[shapeIdx % shapes.count])
                .font(.system(size: 64))
                .foregroundStyle(colors[shapeIdx % colors.count])
                .animation(.spring(response: 0.3), value: shapeIdx)
        }
        .onAppear { cycleDemos() }
        .onDisappear { isVisible = false }
    }

    private func cycleDemos() {
        guard isVisible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            shapeIdx += 1
            if shapeIdx % 2 == 0 { ruleIdx += 1 }
            cycleDemos()
        }
    }
}
