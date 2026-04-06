import SwiftUI

// MARK: - Difficulty

enum Difficulty: String, CaseIterable, Codable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    // Memory: how long each tile stays lit
    var memoryHighlightDuration: Double {
        switch self { case .easy: 0.70; case .medium: 0.55; case .hard: 0.35 }
    }
    var memoryPauseDuration: Double {
        switch self { case .easy: 0.30; case .medium: 0.25; case .hard: 0.18 }
    }

    // Color: timer length, number of color options, delay between questions
    var colorTimerDuration: Double {
        switch self { case .easy: 45; case .medium: 30; case .hard: 20 }
    }
    var colorOptionCount: Int {
        switch self { case .easy: 4; case .medium: 6; case .hard: 6 }
    }
    var colorQuestionDelay: Double {
        switch self { case .easy: 0.35; case .medium: 0.22; case .hard: 0.0 }
    }

    // Reflex: random wait range, target diameter
    var reflexDelayRange: ClosedRange<Double> {
        switch self { case .easy: 1.0...4.0; case .medium: 1.0...3.5; case .hard: 0.5...2.5 }
    }
    var reflexTargetSize: CGFloat {
        switch self { case .easy: 104; case .medium: 88; case .hard: 64 }
    }

    // Math Blitz: describes the operation set per difficulty
    var speedDescription: String {
        switch self {
        case .easy:   return "Addition only (1–9)"
        case .medium: return "Addition & subtraction (1–20)"
        case .hard:   return "Add, subtract & multiply (1–12)"
        }
    }

    var description: String {
        switch self {
        case .easy:   return "Slower pace, more time"
        case .medium: return "Standard challenge"
        case .hard:   return "Fast & unforgiving"
        }
    }

    var color: Color {
        switch self { case .easy: .green; case .medium: .orange; case .hard: .red }
    }
}

// MARK: - DifficultyPicker

struct DifficultyPicker: View {
    @Binding var difficulty: Difficulty

    var body: some View {
        VStack(spacing: 8) {
            Picker("Difficulty", selection: $difficulty) {
                ForEach(Difficulty.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.segmented)

            Text(difficulty.description)
                .font(.caption)
                .foregroundStyle(difficulty.color)
                .animation(.easeInOut(duration: 0.2), value: difficulty)
        }
    }
}

// MARK: - Animated Home Background

struct AnimatedGradientBackground: View {
    @State private var animate = false

    private struct Blob {
        let color: Color
        let size: CGFloat
        let start: CGSize
        let end: CGSize
        let duration: Double
        let delay: Double
    }

    private let blobs: [Blob] = [
        Blob(color: .blue,   size: 320, start: CGSize(width: -80, height: -130), end: CGSize(width:  60, height:  70), duration: 8, delay: 0.0),
        Blob(color: .purple, size: 280, start: CGSize(width: 110, height:  50),  end: CGSize(width: -70, height: -60), duration: 10, delay: 0.6),
        Blob(color: .orange, size: 260, start: CGSize(width: -20, height: 140),  end: CGSize(width:  50, height: -80), duration: 9, delay: 1.2),
    ]

    var body: some View {
        ZStack {
            ForEach(blobs.indices, id: \.self) { i in
                let b = blobs[i]
                Circle()
                    .fill(b.color.opacity(0.18))
                    .frame(width: b.size, height: b.size)
                    .offset(animate ? b.end : b.start)
                    .blur(radius: 55)
                    .animation(
                        .easeInOut(duration: b.duration)
                        .repeatForever(autoreverses: true)
                        .delay(b.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Animated Score Text

struct AnimatedScoreText: View {
    let value: Int
    let font: Font
    let color: Color

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(value)))
            .animation(.easeOut(duration: 0.35), value: value)
    }
}
