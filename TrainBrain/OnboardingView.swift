import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            Color.white.opacity(0.85)
                .ignoresSafeArea()

            // Skip button (pages 0 & 1 only)
            if currentPage < 2 {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            onComplete()
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                .transition(.opacity)
                .zIndex(1)
            }

            // Paged content
            TabView(selection: $currentPage) {
                MemoryOnboardingPage()
                    .tag(0)

                ColorOnboardingPage()
                    .tag(1)

                ReflexOnboardingPage(onComplete: onComplete)
                    .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
        }
    }
}

// MARK: - Page 1: Memory

private struct MemoryOnboardingPage: View {
    @State private var iconBounce = false
    @State private var litTiles: Set<Int> = []

    private let tileColors: [Color] = [
        .blue, .red, .green,
        .purple, .orange, .cyan,
        .pink, .yellow, .teal
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated icon
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear {
                    iconBounce.toggle()
                    startTileAnimation()
                }

            // Title & subtitle
            VStack(spacing: 8) {
                Text("Memory")
                    .font(.largeTitle.bold())
                Text("Watch the sequence,\nthen tap it back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 3x3 tile grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(72), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(0..<9) { i in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tileColors[i].opacity(litTiles.contains(i) ? 0.85 : 0.20))
                        .frame(width: 72, height: 72)
                        .scaleEffect(litTiles.contains(i) ? 1.08 : 1.0)
                        .shadow(
                            color: tileColors[i].opacity(litTiles.contains(i) ? 0.45 : 0),
                            radius: 8, x: 0, y: 4
                        )
                        .animation(.easeInOut(duration: 0.25), value: litTiles.contains(i))
                }
            }
            .padding(.horizontal, 32)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground).opacity(0.85))
            )
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // Cycle through a random sequence of tiles to hint at gameplay
    private func startTileAnimation() {
        let sequence = (0..<9).shuffled()
        for (step, tile) in sequence.enumerated() {
            let onDelay = Double(step) * 0.55
            let offDelay = onDelay + 0.38
            DispatchQueue.main.asyncAfter(deadline: .now() + onDelay) {
                litTiles.insert(tile)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + offDelay) {
                litTiles.remove(tile)
            }
        }
        // Restart after full sequence
        let restartDelay = Double(sequence.count) * 0.55 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + restartDelay) {
            startTileAnimation()
        }
    }
}

// MARK: - Page 2: Color (Stroop)

private struct ColorOnboardingPage: View {
    @State private var iconBounce = false
    @State private var selectedColor: Color? = nil
    @State private var feedbackScale: CGFloat = 1.0

    private let inkColor: Color = .red
    private let wordText = "BLUE"

    private let colorButtons: [(label: String, color: Color)] = [
        ("Red",    .red),
        ("Blue",   .blue),
        ("Green",  .green),
        ("Purple", .purple)
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated icon
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle() }

            // Title & subtitle
            VStack(spacing: 8) {
                Text("Color")
                    .font(.largeTitle.bold())
                Text("Tap the COLOR — not what it says")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Stroop demo card
            VStack(spacing: 20) {
                // The word in a conflicting ink color
                Text(wordText)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(inkColor)
                    .scaleEffect(feedbackScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: feedbackScale)

                // Color choice buttons
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(colorButtons, id: \.label) { item in
                        Button {
                            selectedColor = item.color
                            withAnimation { feedbackScale = 1.18 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation { feedbackScale = 1.0 }
                            }
                        } label: {
                            Text(item.label)
                                .font(.callout.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(item.color.opacity(
                                            selectedColor == item.color ? 1.0 : 0.75
                                        ))
                                )
                                .scaleEffect(selectedColor == item.color ? 1.04 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: selectedColor == item.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground).opacity(0.85))
            )
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Page 3: Reflex

private struct ReflexOnboardingPage: View {
    var onComplete: () -> Void

    @State private var iconBounce = false
    @State private var circleScale: CGFloat = 1.0
    @State private var circleGlow = false
    @State private var tapped = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: iconBounce)
                .onAppear { iconBounce.toggle() }

            // Title & subtitle
            VStack(spacing: 8) {
                Text("Reflex")
                    .font(.largeTitle.bold())
                Text("Tap the circle\nas fast as you can")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Interactive demo circle
            Button {
                tapped = true
                withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                    circleScale = 0.82
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        circleScale = 1.0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    tapped = false
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(tapped ? 1.0 : 0.85))
                        .frame(width: 120, height: 120)
                        .shadow(
                            color: Color.orange.opacity(circleGlow ? 0.6 : 0.25),
                            radius: circleGlow ? 22 : 10
                        )
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(circleScale)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.1)
                    .repeatForever(autoreverses: true)
                ) {
                    circleGlow.toggle()
                }
            }

            // Get Started button
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onComplete()
                }
            } label: {
                Text("Get Started")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
