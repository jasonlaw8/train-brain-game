import SwiftUI

// MARK: - OnboardingView
// Brain-facts intro slides (our content) + animated game-demo pages (polished interactive previews).
// Uses onComplete callback; onboarding state is tracked via @AppStorage("hasOnboarded") in TrainBrainApp.

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    // Pages: 0-2 = brain facts (ours), 3-5 = animated game demos (theirs)
    private let totalPages = 6

    var body: some View {
        ZStack(alignment: .top) {
            AnimatedGradientBackground().ignoresSafeArea()
            Color(.systemBackground).opacity(0.88).ignoresSafeArea()

            // Skip button (not on last page)
            if currentPage < totalPages - 1 {
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
                    body: "Just like physical fitness, cognitive fitness improves with consistent training. Scientists call this neuroplasticity — your brain physically rewires itself with practice.",
                    fact: "People who train their memory for 5 minutes a day show measurable improvement in as little as 2 weeks."
                ) { withAnimation { currentPage += 1 } }
                    .tag(0)

                BrainFactSlide(
                    icon: "chart.line.uptrend.xyaxis", iconColor: .indigo,
                    title: "Track Your Brain Score",
                    body: "Train Brain measures three core cognitive metrics — Memory, Reflex Speed, and Processing Speed — and gives you a single Brain Score. 100 is average.",
                    fact: "Studies show that tracking progress increases training consistency by up to 40%."
                ) { withAnimation { currentPage += 1 } }
                    .tag(1)

                BrainFactSlide(
                    icon: "flame.fill", iconColor: .red,
                    title: "Consistency Is Everything",
                    body: "Five minutes a day beats two hours on the weekend. Daily challenges keep your streak alive and your brain in peak condition.",
                    fact: "Habit research shows a 7-day streak makes you 80% more likely to stick with a new routine long-term."
                ) { withAnimation { currentPage += 1 } }
                    .tag(2)

                // Animated game-demo pages
                MemoryOnboardingPage()
                    .tag(3)

                ColorOnboardingPage()
                    .tag(4)

                ReflexOnboardingPage(onComplete: onComplete)
                    .tag(5)
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
    let body: String
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
                Text(body)
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

// MARK: - Page: Reflex demo + Get Started

private struct ReflexOnboardingPage: View {
    var onComplete: () -> Void

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

            Button {
                withAnimation(.easeInOut(duration: 0.35)) { onComplete() }
            } label: {
                Text("Get Started")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32).padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
