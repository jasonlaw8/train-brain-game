import SwiftUI

// MARK: - ShapeShiftViewModel
// Task 4: Cognitive Flexibility (task-switching).
// Block A (6 trials): Sort by COLOR.  Block B (6 trials): Sort by SHAPE.
// Block C (12 trials): AABB pattern — rule alternates every 2 trials.

@MainActor
class ShapeShiftViewModel: ObservableObject {

    enum Block { case colorOnly, shapeOnly, mixed }
    enum SortRule { case color, shape }

    struct Trial {
        let block: Block
        let rule: SortRule
        let stimColor: String   // "red" | "blue" | "green" | "yellow"
        let stimShape: String   // "circle" | "square" | "triangle" | "star"
        let isSwitchTrial: Bool // true if rule differs from previous trial's rule
    }

    enum TaskState { case showing, interTrial, finished }

    @Published var taskState: TaskState = .showing
    @Published var currentTrial: Trial? = nil
    @Published var trialsDone: Int = 0
    @Published var currentRule: SortRule = .color
    @Published var cueBanner: String = "SORT BY COLOR"
    @Published var cueIcon: String = "paintpalette.fill"
    @Published var cueAnimID: Int = 0   // toggled to trigger animation

    let allColors   = ["red", "blue", "green", "yellow"]
    let allShapes   = ["circle", "square", "triangle", "star"]
    let totalTrials = 24
    var onComplete: (([TrialRecord]) -> Void)?

    private var trialSequence: [Trial] = []
    private var trials: [TrialRecord] = []
    private var trialAppearTime: Date?
    private var responseTask: Task<Void, Never>?
    private var responded: Bool = false

    // MARK: - Colors & shapes

    let colorValues: [String: Color] = [
        "red":    Color(red: 0.91, green: 0.30, blue: 0.24),
        "blue":   Color(red: 0.20, green: 0.60, blue: 0.86),
        "green":  Color(red: 0.15, green: 0.68, blue: 0.38),
        "yellow": Color(red: 0.95, green: 0.77, blue: 0.06)
    ]

    func shapeIcon(_ shape: String) -> String {
        switch shape {
        case "circle":   return "circle.fill"
        case "square":   return "square.fill"
        case "triangle": return "triangle.fill"
        default:         return "star.fill"
        }
    }

    // MARK: - Start

    func startTask() {
        trialSequence = buildSequence()
        trials = []
        trialsDone = 0
        showTrial(at: 0)
    }

    // MARK: - Sequence generation

    private func buildSequence() -> [Trial] {
        var seq: [Trial] = []

        // Block A: 6 color-only trials
        for _ in 0..<6 {
            seq.append(Trial(block: .colorOnly, rule: .color,
                             stimColor: allColors.randomElement()!,
                             stimShape: allShapes.randomElement()!,
                             isSwitchTrial: false))
        }

        // Block B: 6 shape-only trials
        for _ in 0..<6 {
            seq.append(Trial(block: .shapeOnly, rule: .shape,
                             stimColor: allColors.randomElement()!,
                             stimShape: allShapes.randomElement()!,
                             isSwitchTrial: false))
        }

        // Block C: 12 mixed trials, AABB pattern (2 color, 2 shape, repeat × 3)
        let mixedPattern: [SortRule] = [.color, .color, .shape, .shape,
                                         .color, .color, .shape, .shape,
                                         .color, .color, .shape, .shape]
        var prevRule: SortRule? = .shape   // last block B rule was .shape
        for rule in mixedPattern {
            let isSwitch = prevRule != nil && rule != prevRule!
            seq.append(Trial(block: .mixed, rule: rule,
                             stimColor: allColors.randomElement()!,
                             stimShape: allShapes.randomElement()!,
                             isSwitchTrial: isSwitch))
            prevRule = rule
        }

        return seq
    }

    // MARK: - Trial display

    private func showTrial(at index: Int) {
        guard index < trialSequence.count else { finish(); return }
        let trial = trialSequence[index]
        currentTrial = trial
        responded = false
        trialAppearTime = Date()
        taskState = .showing

        // Update cue banner if rule changed
        if trial.rule != currentRule || index == 0 {
            currentRule = trial.rule
            cueBanner = trial.rule == .color ? "SORT BY COLOR" : "SORT BY SHAPE"
            cueIcon   = trial.rule == .color ? "paintpalette.fill" : "square.on.circle.fill"
            cueAnimID += 1
        }

        responseTask?.cancel()
        responseTask = Task {
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled, !responded else { return }
            handleNoResponse()
        }
    }

    // MARK: - User response

    func respond(selection: String) {
        guard taskState == .showing, !responded, let trial = currentTrial,
              let t0 = trialAppearTime else { return }
        responded = true
        responseTask?.cancel()

        let rtMs = Int(Date().timeIntervalSince(t0) * 1000)
        let correct: Bool
        if trial.rule == .color {
            correct = selection == trial.stimColor
        } else {
            correct = selection == trial.stimShape
        }

        if correct { Haptics.medium() } else { Haptics.error() }
        appendTrial(trial: trial, response: selection, rtMs: rtMs, correct: correct, lapse: false)
        advanceWithPause()
    }

    private func handleNoResponse() {
        guard let trial = currentTrial else { return }
        responded = true
        appendTrial(trial: trial, response: "none", rtMs: 2501, correct: false, lapse: true)
        advanceWithPause()
    }

    private func advanceWithPause() {
        taskState = .interTrial

        responseTask?.cancel()
        responseTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            trialsDone += 1
            showTrial(at: trialsDone)
        }
    }

    // MARK: - Record

    private func appendTrial(trial: Trial, response: String, rtMs: Int, correct: Bool, lapse: Bool) {
        let blockStr: String
        switch trial.block {
        case .colorOnly: blockStr = "color"
        case .shapeOnly: blockStr = "shape"
        case .mixed:     blockStr = "mixed"
        }
        let record = TrialRecord(
            trialNumber: trials.count + 1,
            taskName: "shapeShift",
            phase: nil, orbColor: nil,
            trialType: nil, centerDirection: nil,
            cardRank: nil, cardSuit: nil, isTargetMatch: nil,
            block: blockStr,
            currentRule: trial.rule == .color ? "color" : "shape",
            stimulusColor: trial.stimColor,
            stimulusShape: trial.stimShape,
            isSwitchTrial: trial.isSwitchTrial,
            userResponse: response,
            reactionTimeMs: rtMs,
            isCorrect: correct,
            isAnticipatory: false,
            isLapse: lapse
        )
        trials.append(record)
    }

    private func finish() {
        taskState = .finished
        onComplete?(trials)
    }
}

// MARK: - ShapeShiftTaskView

struct ShapeShiftTaskView: View {
    @StateObject private var vm = ShapeShiftViewModel()
    let onComplete: ([TrialRecord]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Cue banner
            cueBannerView
                .animation(.easeInOut(duration: 0.2), value: vm.cueAnimID)
                .id(vm.cueAnimID)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))

            Spacer()

            // Progress
            Text("Trial \(min(vm.trialsDone + 1, vm.totalTrials)) / \(vm.totalTrials)")
                .font(.caption).foregroundStyle(.secondary)

            Spacer()

            // Stimulus
            if let trial = vm.currentTrial {
                stimulusView(trial: trial)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            Spacer()

            // Response buttons
            if let trial = vm.currentTrial {
                responseButtons(trial: trial)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: vm.trialsDone)
        .onAppear {
            vm.onComplete = onComplete
            vm.startTask()
        }
    }

    // MARK: Cue banner

    var cueBannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.cueIcon)
                .font(.system(size: 18, weight: .semibold))
            Text(vm.cueBanner)
                .font(.headline.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: vm.currentRule == .color
                    ? [Color.purple, Color.indigo]
                    : [Color.teal, Color.blue],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: Stimulus

    func stimulusView(trial: ShapeShiftViewModel.Trial) -> some View {
        let color = vm.colorValues[trial.stimColor] ?? .blue
        return Image(systemName: vm.shapeIcon(trial.stimShape))
            .font(.system(size: 120))
            .foregroundStyle(color)
            .frame(height: 140)
    }

    // MARK: Response buttons

    @ViewBuilder
    func responseButtons(trial: ShapeShiftViewModel.Trial) -> some View {
        if trial.rule == .color {
            colorButtons
        } else {
            shapeButtons
        }
    }

    var colorButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(vm.allColors, id: \.self) { color in
                Button { vm.respond(selection: color) } label: {
                    Circle()
                        .fill(vm.colorValues[color] ?? .gray)
                        .frame(height: 56)
                        .shadow(color: (vm.colorValues[color] ?? .gray).opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                .disabled(vm.taskState != .showing)
                .accessibilityLabel(color)
            }
        }
    }

    var shapeButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(vm.allShapes, id: \.self) { shape in
                Button { vm.respond(selection: shape) } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 56)
                        Image(systemName: vm.shapeIcon(shape))
                            .font(.system(size: 26))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.taskState != .showing)
            }
        }
    }
}
