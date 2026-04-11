import SwiftUI

// MARK: - ComboTracker

/// Tracks consecutive correct answers and calculates the active score multiplier.
/// Inject as `@StateObject` in each timed game view.
@MainActor
final class ComboTracker: ObservableObject {
    @Published private(set) var streak: Int = 0
    @Published private(set) var multiplier: Double = 1.0
    @Published private(set) var pulseUp: Bool = false
    @Published private(set) var shakeReset: Bool = false

    // Multiplier ladder: index = streak tier (capped at last entry)
    private let steps: [Double] = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0]

    func markCorrect() {
        streak += 1
        let newMult = steps[min(streak, steps.count - 1)]
        if newMult > multiplier {
            multiplier = newMult
            triggerPulse()
        }
        if streak == 5 || streak == 10 || streak == 20 {
            SoundEngine.shared.playStreakMilestone()
            Haptics.success()
        }
    }

    func markWrong() {
        if streak > 0 { triggerShake() }
        streak = 0
        multiplier = 1.0
    }

    func reset() {
        streak = 0; multiplier = 1.0
        pulseUp = false; shakeReset = false
    }

    /// Apply multiplier to a base point value.
    func apply(_ base: Int) -> Int { max(1, Int((Double(base) * multiplier).rounded())) }

    private func triggerPulse() {
        pulseUp = true
        Task { try? await Task.sleep(for: .milliseconds(340)); pulseUp = false }
    }

    private func triggerShake() {
        shakeReset = true
        Task { try? await Task.sleep(for: .milliseconds(440)); shakeReset = false }
    }
}

// MARK: - MultiplierBadgeView

/// Small pill badge showing the current multiplier. Pulses on increase, shakes on reset.
struct MultiplierBadgeView: View {
    @ObservedObject var combo: ComboTracker
    var color: Color = .orange

    @State private var scale: CGFloat = 1.0
    @State private var shakeX: CGFloat = 0

    var body: some View {
        let label = combo.multiplier == 1.0 ? "×1" : String(format: "×%.4g", combo.multiplier)
        Text(label)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.gradient, in: Capsule())
            .scaleEffect(scale)
            .offset(x: shakeX)
            .onChange(of: combo.pulseUp) { _, val in
                guard val else { return }
                withAnimation(.spring(response: 0.13, dampingFraction: 0.35)) { scale = 1.30 }
                withAnimation(.spring(response: 0.16, dampingFraction: 0.55).delay(0.13)) { scale = 1.0 }
            }
            .onChange(of: combo.shakeReset) { _, val in
                guard val else { return }
                Task {
                    withAnimation(.interpolatingSpring(stiffness: 600, damping: 8)) { shakeX = -9 }
                    try? await Task.sleep(for: .milliseconds(70))
                    withAnimation(.interpolatingSpring(stiffness: 600, damping: 8)) { shakeX =  9 }
                    try? await Task.sleep(for: .milliseconds(70))
                    withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) { shakeX =  0 }
                }
            }
    }
}
