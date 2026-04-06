import SwiftUI

// MARK: - LightningTapViewModel
// Task 1: Processing Speed. 30 trials — 15 simple RT (Phase A) + 15 choice RT (Phase B).
// Phase A: single orange orb, tap as fast as possible.
// Phase B: green orb = tap, red orb = ignore. 50/50 split guaranteed.

@MainActor
class LightningTapViewModel: ObservableObject {

    enum TaskPhase { case phaseA, phaseB }
    enum OrbColor  { case orange, green, red }

    // MARK: - Published
    @Published var taskPhase: TaskPhase = .phaseA
    @Published var phaseADone: Int = 0     // how many Phase A trials completed
    @Published var phaseBDone: Int = 0     // how many Phase B trials completed
    @Published var targetVisible: Bool = false
    @Published var targetX: CGFloat = 0
    @Published var targetY: CGFloat = 0
    @Published var orbColor: OrbColor = .orange
    @Published var statusText: String = "Get ready…"

    let targetSize: CGFloat = 88
    var containerSize: CGSize = CGSize(width: 300, height: 460)
    var onComplete: (([TrialRecord]) -> Void)?

    // MARK: - Internals
    private var targetAppearTime: Date?
    private var lapseTask: Task<Void, Never>?
    private var isiTask: Task<Void, Never>?
    private var trials: [TrialRecord] = []
    private var phaseBColors: [OrbColor] = []
    private var currentPhaseBIndex: Int = 0

    // MARK: - Start

    func startTask() {
        trials = []
        phaseADone = 0
        phaseBDone = 0
        currentPhaseBIndex = 0
        taskPhase = .phaseA

        // Pre-generate Phase B: 8 green + 7 red, shuffled (≈50/50 over 15 trials)
        var colors: [OrbColor] = Array(repeating: .green, count: 8) + Array(repeating: .red, count: 7)
        colors.shuffle()
        phaseBColors = colors

        scheduleNextTrial()
    }

    // MARK: - Trial flow

    private func scheduleNextTrial() {
        targetVisible = false
        statusText = "Get ready…"
        let isiMs = Int.random(in: 1000...3500)
        isiTask?.cancel()
        isiTask = Task {
            try? await Task.sleep(for: .milliseconds(isiMs))
            guard !Task.isCancelled else { return }
            showTarget()
        }
    }

    private func showTarget() {
        let pad: CGFloat = targetSize / 2 + 8
        targetX = CGFloat.random(in: pad...(containerSize.width - pad))
        targetY = CGFloat.random(in: pad...(containerSize.height - pad))

        if taskPhase == .phaseA {
            orbColor = .orange
            statusText = "TAP IT!"
        } else {
            let color = currentPhaseBIndex < phaseBColors.count
                ? phaseBColors[currentPhaseBIndex] : .green
            currentPhaseBIndex += 1
            orbColor = color
            statusText = color == .green ? "TAP!" : "DON'T TAP!"
        }

        targetVisible = true
        targetAppearTime = Date()

        lapseTask?.cancel()
        lapseTask = Task {
            try? await Task.sleep(for: .milliseconds(2000))
            guard !Task.isCancelled else { return }
            handleLapse()
        }
    }

    // MARK: - User interaction

    func targetTapped() {
        guard targetVisible, let t0 = targetAppearTime else { return }
        let rtMs = Int(Date().timeIntervalSince(t0) * 1000)
        lapseTask?.cancel()

        let isAnticipatory = rtMs < 100
        let isCorrect: Bool = taskPhase == .phaseA || orbColor == .green
        appendTrial(rtMs: rtMs, response: "tap", correct: isCorrect,
                    anticipatory: isAnticipatory, lapse: false)
        if isCorrect { Haptics.light() } else { Haptics.error() }
        advance()
    }

    private func handleLapse() {
        targetVisible = false
        // Phase B: not tapping a red orb within 2000ms = correct (correctly ignored)
        let isCorrect = taskPhase == .phaseB && orbColor == .red
        appendTrial(rtMs: 2001, response: "none", correct: isCorrect,
                    anticipatory: false, lapse: true)
        advance()
    }

    // MARK: - Record

    private func appendTrial(rtMs: Int, response: String, correct: Bool,
                              anticipatory: Bool, lapse: Bool) {
        let phaseStr = taskPhase == .phaseA ? "simple" : "choice"
        let orbStr: String? = taskPhase == .phaseA ? nil
            : (orbColor == .green ? "green" : "red")
        let record = TrialRecord(
            trialNumber: trials.count + 1,
            taskName: "lightningTap",
            phase: phaseStr, orbColor: orbStr,
            trialType: nil, centerDirection: nil,
            cardRank: nil, cardSuit: nil, isTargetMatch: nil,
            block: nil, currentRule: nil,
            stimulusColor: nil, stimulusShape: nil, isSwitchTrial: nil,
            userResponse: response,
            reactionTimeMs: rtMs,
            isCorrect: correct,
            isAnticipatory: anticipatory,
            isLapse: lapse
        )
        trials.append(record)
    }

    // MARK: - Advance

    private func advance() {
        targetVisible = false
        lapseTask?.cancel()

        if taskPhase == .phaseA {
            phaseADone += 1
            if phaseADone >= 15 {
                // Transition to Phase B with a brief instructional pause
                taskPhase = .phaseB
                statusText = "Phase 2: Green = tap, Red = ignore"
                isiTask?.cancel()
                isiTask = Task {
                    try? await Task.sleep(for: .milliseconds(2000))
                    guard !Task.isCancelled else { return }
                    scheduleNextTrial()
                }
            } else {
                scheduleNextTrial()
            }
        } else {
            phaseBDone += 1
            if phaseBDone >= 15 {
                statusText = "Done!"
                onComplete?(trials)
            } else {
                scheduleNextTrial()
            }
        }
    }
}

// MARK: - LightningTapTaskView

struct LightningTapTaskView: View {
    @StateObject private var vm = LightningTapViewModel()
    let onComplete: ([TrialRecord]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            arenaView
        }
        .onAppear {
            vm.onComplete = onComplete
            vm.startTask()
        }
    }

    // MARK: Header

    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.taskPhase == .phaseA ? "Phase 1 — Simple" : "Phase 2 — Choice")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                let done = vm.taskPhase == .phaseA ? vm.phaseADone : vm.phaseBDone
                Text("Trial \(min(done + 1, 15)) / 15")
                    .font(.subheadline.bold())
            }
            Spacer()
            if vm.taskPhase == .phaseB {
                HStack(spacing: 10) {
                    legendBadge(color: .green, label: "Tap")
                    legendBadge(color: .red,   label: "Skip")
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    func legendBadge(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Arena

    var arenaView: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6))

                VStack {
                    Text(vm.statusText)
                        .font(.headline).foregroundStyle(.secondary)
                        .padding(.top, 24)
                    Spacer()
                }

                if vm.targetVisible {
                    orbView
                        .frame(width: vm.targetSize, height: vm.targetSize)
                        .position(x: vm.targetX, y: vm.targetY)
                        .onTapGesture { vm.targetTapped() }
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                vm.containerSize = geo.size
            }
            .onChange(of: geo.size) { _, s in vm.containerSize = s }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: vm.targetVisible)
    }

    // MARK: Orb

    @ViewBuilder
    var orbView: some View {
        let size = vm.targetSize
        switch vm.orbColor {
        case .orange:
            Circle()
                .fill(RadialGradient(colors: [.yellow, .orange], center: .center,
                                     startRadius: 0, endRadius: size / 2))
                .shadow(color: .orange.opacity(0.6), radius: 16)
                .overlay(Image(systemName: "hand.tap.fill").font(.title2).foregroundStyle(.white))
        case .green:
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.4, green: 0.9, blue: 0.4), .green],
                                     center: .center, startRadius: 0, endRadius: size / 2))
                .shadow(color: Color.green.opacity(0.5), radius: 16)
                .overlay(Image(systemName: "checkmark").font(.title2.bold()).foregroundStyle(.white))
        case .red:
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.4), .red],
                                     center: .center, startRadius: 0, endRadius: size / 2))
                .shadow(color: Color.red.opacity(0.5), radius: 16)
                .overlay(Image(systemName: "xmark").font(.title2.bold()).foregroundStyle(.white))
        }
    }
}
