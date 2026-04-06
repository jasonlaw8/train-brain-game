import SwiftUI

// MARK: - ArrowStormViewModel
// Task 2: Attention & Inhibitory Control (Flanker paradigm).
// 24 fixed trials: 12 congruent + 12 incongruent, randomized.
// Response: horizontal swipe (min 30pt). Haptic feedback only.

@MainActor
class ArrowStormViewModel: ObservableObject {

    struct Trial {
        let trialType: String      // "congruent" | "incongruent"
        let centerDirection: String // "left" | "right"
        let arrows: [String]       // 5 arrow strings (← or →)
    }

    enum TaskState { case ready, showing, blank, finished }

    @Published var taskState: TaskState = .ready
    @Published var currentTrial: Trial? = nil
    @Published var trialsDone: Int = 0
    @Published var showBlank: Bool = false
    @Published var feedbackIcon: String? = nil  // unused visually per spec, kept for debug

    let totalTrials = 24
    var onComplete: (([TrialRecord]) -> Void)?

    private var trialSequence: [Trial] = []
    private var trials: [TrialRecord] = []
    private var trialAppearTime: Date?
    private var responseTask: Task<Void, Never>?
    private var responded: Bool = false

    // MARK: - Start

    func startTask() {
        trialSequence = buildTrialSequence()
        trials = []
        trialsDone = 0
        showNextTrial()
    }

    // MARK: - Trial sequence generation

    private func buildTrialSequence() -> [Trial] {
        // Build base pool: 12 congruent (6 left, 6 right) + 12 incongruent (6 left, 6 right)
        var pool: [Trial] = []
        for dir in ["left", "right"] {
            for _ in 0..<6 {
                pool.append(makeTrial(type: "congruent", center: dir))
                pool.append(makeTrial(type: "incongruent", center: dir))
            }
        }
        pool.shuffle()

        // Enforce: no more than 3 consecutive same-type trials
        var result: [Trial] = []
        var remaining = pool

        while !remaining.isEmpty {
            let last3Types = result.suffix(3).map { $0.trialType }
            let allSameType = last3Types.count == 3 && Set(last3Types).count == 1

            if allSameType {
                let blockedType = last3Types[0]
                if let idx = remaining.firstIndex(where: { $0.trialType != blockedType }) {
                    result.append(remaining.remove(at: idx))
                } else {
                    // Can't satisfy constraint — just take next
                    result.append(remaining.removeFirst())
                }
            } else {
                result.append(remaining.removeFirst())
            }
        }

        return result
    }

    private func makeTrial(type: String, center: String) -> Trial {
        let centerArrow = center == "left" ? "←" : "→"
        let flankerArrow: String
        if type == "congruent" {
            flankerArrow = centerArrow
        } else {
            flankerArrow = center == "left" ? "→" : "←"
        }
        return Trial(
            trialType: type,
            centerDirection: center,
            arrows: [flankerArrow, flankerArrow, centerArrow, flankerArrow, flankerArrow]
        )
    }

    // MARK: - Trial display

    private func showNextTrial() {
        guard trialsDone < trialSequence.count else { finish(); return }
        let trial = trialSequence[trialsDone]
        currentTrial = trial
        trialAppearTime = Date()
        responded = false
        taskState = .showing

        // 1500ms response window
        responseTask?.cancel()
        responseTask = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, !responded else { return }
            handleNoResponse()
        }
    }

    // MARK: - User response (called from DragGesture)

    func respond(direction: String) {
        guard taskState == .showing, !responded, let trial = currentTrial,
              let t0 = trialAppearTime else { return }
        responded = true
        responseTask?.cancel()

        let rtMs = Int(Date().timeIntervalSince(t0) * 1000)
        let isCorrect = direction == trial.centerDirection

        if isCorrect { Haptics.medium() } else { Haptics.error() }

        appendTrial(trial: trial, response: direction, rtMs: rtMs, correct: isCorrect, lapse: false)
        advanceWithBlank()
    }

    private func handleNoResponse() {
        guard let trial = currentTrial else { return }
        responded = true
        appendTrial(trial: trial, response: "none", rtMs: 1501, correct: false, lapse: true)
        advanceWithBlank()
    }

    private func advanceWithBlank() {
        trialsDone += 1
        taskState = .blank
        currentTrial = nil

        responseTask?.cancel()
        responseTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            showNextTrial()
        }
    }

    // MARK: - Record

    private func appendTrial(trial: Trial, response: String, rtMs: Int, correct: Bool, lapse: Bool) {
        let record = TrialRecord(
            trialNumber: trials.count + 1,
            taskName: "arrowStorm",
            phase: nil, orbColor: nil,
            trialType: trial.trialType,
            centerDirection: trial.centerDirection,
            cardRank: nil, cardSuit: nil, isTargetMatch: nil,
            block: nil, currentRule: nil,
            stimulusColor: nil, stimulusShape: nil, isSwitchTrial: nil,
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

// MARK: - ArrowStormTaskView

struct ArrowStormTaskView: View {
    @StateObject private var vm = ArrowStormViewModel()
    let onComplete: ([TrialRecord]) -> Void

    // Swipe state
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swipe the CENTER arrow's direction")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Trial \(min(vm.trialsDone + 1, vm.totalTrials)) / \(vm.totalTrials)")
                        .font(.subheadline.bold())
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Spacer()

            // Arrow display
            if let trial = vm.currentTrial {
                arrowRow(trial: trial)
                    .transition(.opacity)
            } else if vm.taskState == .blank {
                Color.clear.frame(height: 80)
            }

            Spacer()

            // Swipe instruction
            HStack(spacing: 20) {
                swipeHint(direction: "← Swipe left", icon: "arrow.left")
                swipeHint(direction: "Swipe right →", icon: "arrow.right")
            }
            .padding(.bottom, 48)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let h = value.translation.width
                    let v = abs(value.translation.height)
                    guard abs(h) > v else { return }
                    vm.respond(direction: h < 0 ? "left" : "right")
                }
        )
        .onAppear {
            vm.onComplete = onComplete
            vm.startTask()
        }
        .animation(.easeInOut(duration: 0.15), value: vm.currentTrial?.centerDirection)
    }

    func arrowRow(trial: ArrowStormViewModel.Trial) -> some View {
        HStack(spacing: 2) {
            ForEach(trial.arrows.indices, id: \.self) { i in
                Text(trial.arrows[i])
                    .font(.system(size: i == 2 ? 56 : 36, weight: .bold))
                    .foregroundStyle(i == 2 ? Color.indigo : Color.indigo.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    func swipeHint(direction: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline)
            Text(direction).font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
