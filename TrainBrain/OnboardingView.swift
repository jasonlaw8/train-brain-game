import SwiftUI
import SwiftData

// MARK: - Onboarding Flow
// Shown once on first launch. Swipeable slides with brain facts + an optional initial assessment.

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page: Int = 0
    @State private var showAssessment = false

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            icon: "brain.filled.head.profile",
            iconColor: .blue,
            title: "Your Brain Is a Muscle",
            body: "Just like physical fitness, cognitive fitness improves with consistent training. Scientists call this neuroplasticity — your brain physically rewires itself with practice.",
            fact: "People who train their memory for 5 minutes a day show measurable improvement in as little as 2 weeks."
        ),
        OnboardingSlide(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .indigo,
            title: "Track Your Brain Score",
            body: "Train Brain measures three core cognitive metrics — Memory, Reflex Speed, and Processing Speed — and gives you a single Brain Score, normalized so 100 is the average person.",
            fact: "Studies show that tracking progress increases training consistency by up to 40%."
        ),
        OnboardingSlide(
            icon: "bolt.fill",
            iconColor: .orange,
            title: "Reflexes Slow With Age",
            body: "Reaction time peaks around age 24 and gradually slows. But research shows regular reflex training can reverse this trend — athletes in their 40s often outperform sedentary 20-year-olds.",
            fact: "Formula 1 drivers have average reaction times of ~200ms — far faster than the 250ms average human."
        ),
        OnboardingSlide(
            icon: "function",
            iconColor: .green,
            title: "Processing Speed Is Trainable",
            body: "How quickly you can solve a simple problem under pressure is a strong predictor of overall cognitive performance. Regular mental arithmetic keeps this skill sharp at any age.",
            fact: "Chess grandmasters process complex positions up to 3× faster than beginners — purely from training."
        ),
        OnboardingSlide(
            icon: "flame.fill",
            iconColor: .red,
            title: "Consistency Is Everything",
            body: "Five minutes a day beats two hours on the weekend. Daily challenges keep your streak alive and your brain in peak condition. Missing just one day resets your momentum.",
            fact: "Habit research shows a 7-day streak makes you 80% more likely to stick with a new routine long-term."
        ),
        OnboardingSlide(
            icon: "star.fill",
            iconColor: .yellow,
            title: "Ready to Begin?",
            body: "Take a quick Brain Assessment to establish your baseline score — or dive straight into training. Either way, come back daily to watch your Brain Score climb.",
            fact: nil,
            isLast: true
        ),
    ]

    var body: some View {
        ZStack {
            AnimatedGradientBackground().ignoresSafeArea()
            Color(.systemBackground).opacity(0.88).ignoresSafeArea()

            if showAssessment {
                AssessmentIntroView(isOnboardingComplete: $isComplete)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    // Slides
                    TabView(selection: $page) {
                        ForEach(slides.indices, id: \.self) { i in
                            slideView(slides[i]).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.35), value: page)

                    // Dots + buttons
                    VStack(spacing: 20) {
                        // Progress dots
                        HStack(spacing: 8) {
                            ForEach(slides.indices, id: \.self) { i in
                                Capsule()
                                    .fill(i == page ? Color.blue : Color(.systemGray4))
                                    .frame(width: i == page ? 20 : 8, height: 8)
                                    .animation(.spring(response: 0.3), value: page)
                            }
                        }

                        if slides[page].isLast {
                            // Final page: two options
                            VStack(spacing: 12) {
                                Button {
                                    withAnimation { showAssessment = true }
                                } label: {
                                    Text("Take Brain Assessment")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                                }

                                Button {
                                    isComplete = true
                                } label: {
                                    Text("Skip — Go to Training")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            // Navigation buttons
                            HStack(spacing: 16) {
                                if page > 0 {
                                    Button {
                                        withAnimation { page -= 1 }
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.title3.bold())
                                            .foregroundStyle(.blue)
                                            .frame(width: 52, height: 52)
                                            .background(Color(.secondarySystemBackground),
                                                        in: Circle())
                                    }
                                }
                                Spacer()
                                Button {
                                    withAnimation { page += 1 }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("Next")
                                            .font(.title3.bold())
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAssessment)
    }

    func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: slide.icon)
                .font(.system(size: 72))
                .foregroundStyle(slide.iconColor)
                .symbolEffect(.pulse)

            VStack(spacing: 14) {
                Text(slide.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(slide.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }

            if let fact = slide.fact {
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
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Slide model

struct OnboardingSlide {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
    let fact: String?
    var isLast: Bool = false
}

// MARK: - Assessment Intro

struct AssessmentIntroView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var step: AssessmentStep = .intro

    enum AssessmentStep { case intro, memory, reflex, speed, results }

    // Collect raw scores during assessment
    @State private var memoryLevel: Int = 0
    @State private var reflexAvgMs: Double = 0
    @State private var speedCorrect: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .intro:
                    assessmentIntro
                case .memory:
                    MemoryGameView()
                        .onDisappear {
                            // After memory game, move to reflex
                            if step == .memory { step = .reflex }
                        }
                case .reflex:
                    ReflexGameView()
                        .onDisappear {
                            if step == .reflex { step = .speed }
                        }
                case .speed:
                    MathBlitzGameView()
                        .onDisappear {
                            if step == .speed { step = .results }
                        }
                case .results:
                    assessmentResults
                }
            }
            .navigationTitle(step == .intro ? "Brain Assessment" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step == .intro {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") { isOnboardingComplete = true }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var assessmentIntro: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "brain")
                .font(.system(size: 72))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            VStack(spacing: 14) {
                Text("Your Baseline Assessment")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("We'll run three quick tests — Memory, Reflex, and Processing Speed — to calculate your starting Brain Score.\n\nEach test takes about 1–2 minutes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)
            }

            VStack(spacing: 10) {
                assessmentStep("1", label: "Simon Says", subtitle: "Memory", color: .blue,   icon: "square.grid.3x3.fill")
                assessmentStep("2", label: "Reaction Time", subtitle: "Reflex", color: .orange, icon: "bolt.fill")
                assessmentStep("3", label: "Math Blitz", subtitle: "Processing Speed", color: .green, icon: "function")
            }
            .padding(.horizontal)

            Spacer()

            Button { step = .memory } label: {
                Text("Start Assessment")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    func assessmentStep(_ number: String, label: String, subtitle: String, color: Color, icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 44, height: 44)
                Text(number).font(.title3.bold()).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon).foregroundStyle(color)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    var assessmentResults: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Assessment Complete!")
                .font(.largeTitle.bold())

            Text("Your baseline Brain Score has been recorded. Come back daily to watch it improve.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button { isOnboardingComplete = true } label: {
                Text("Start Training")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
