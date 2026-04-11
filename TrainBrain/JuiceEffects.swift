import SwiftUI

// MARK: - View Extensions

extension View {
    /// Spring scale bounce (1.0 → 1.15 → 1.0) triggered by a Bool flip to true.
    func juiceBounce(trigger: Bool) -> some View {
        modifier(JuiceBounceModifier(trigger: trigger))
    }

    /// Brief white/color flash overlay triggered by a Bool flip to true.
    func juiceFlash(trigger: Bool, color: Color = .white) -> some View {
        modifier(JuiceFlashModifier(trigger: trigger, color: color))
    }

    /// Dim to 50% opacity for `duration` seconds, then restore.
    func juiceDim(trigger: Bool, duration: Double = 0.20) -> some View {
        modifier(JuiceDimModifier(trigger: trigger, duration: duration))
    }
}

// MARK: - Bounce

struct JuiceBounceModifier: ViewModifier {
    let trigger: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, newVal in
                guard newVal else { return }
                withAnimation(.spring(response: 0.12, dampingFraction: 0.38)) { scale = 1.15 }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.60).delay(0.12)) { scale = 1.0 }
            }
    }
}

// MARK: - Flash

struct JuiceFlashModifier: ViewModifier {
    let trigger: Bool
    let color: Color
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(color.opacity(0.30 * opacity).clipShape(RoundedRectangle(cornerRadius: 12)))
            .onChange(of: trigger) { _, newVal in
                guard newVal else { return }
                opacity = 1
                withAnimation(.easeOut(duration: 0.12)) { opacity = 0 }
            }
    }
}

// MARK: - Dim (wrong answer)

struct JuiceDimModifier: ViewModifier {
    let trigger: Bool
    let duration: Double
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.50 : 1.0)
            .onChange(of: trigger) { _, newVal in
                guard newVal else { return }
                withAnimation(.easeOut(duration: 0.06)) { dimmed = true }
                Task {
                    try? await Task.sleep(for: .seconds(duration))
                    withAnimation(.easeIn(duration: 0.10)) { dimmed = false }
                }
            }
    }
}

// MARK: - Particle Burst

/// Radiating confetti particles. Shown as an overlay on correct answers / new best.
struct ParticleBurst: View {
    var color: Color = .yellow
    var count: Int = 10

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                FlyingParticle(particle: p, color: color)
            }
        }
        .onAppear {
            particles = (0..<count).map { i in
                Particle(
                    angle: Double(i) / Double(count) * 2 * .pi + Double.random(in: -0.25...0.25),
                    distance: .random(in: 36...80),
                    size: .random(in: 4...8)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FlyingParticle: View {
    let particle: ParticleBurst.Particle
    let color: Color
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: particle.size, height: particle.size)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.42)) {
                    offset = CGSize(
                        width:  cos(particle.angle) * particle.distance,
                        height: sin(particle.angle) * particle.distance
                    )
                    opacity = 0
                }
            }
    }
}

// MARK: - Streak Flame Badge

/// Flame icon that grows with increasing streak count (used by Stroop Challenge).
struct StreakFlameBadge: View {
    let streak: Int
    var accentColor: Color = .orange

    private var intensity: Double { min(1.0, Double(streak) / 20.0) }
    private var size: CGFloat { 16 + CGFloat(min(streak, 20)) * 0.8 }

    var body: some View {
        if streak >= 3 {
            Image(systemName: "flame.fill")
                .font(.system(size: size))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, accentColor, .red],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: accentColor.opacity(0.6 * intensity), radius: 6)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
