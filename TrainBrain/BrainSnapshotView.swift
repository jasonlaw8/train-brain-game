import SwiftUI
import SwiftData

// MARK: - BrainSnapshotView
// Main orchestration view. State machine drives the full assessment flow:
// intro → task1 → transition → task2 → transition → task3 → transition → task4 → scoring → results

struct BrainSnapshotView: View {

    enum Phase: Equatable {
        case intro
        case task1
        case transition(SnapshotTask)
        case task2
        case task3
        case task4
        case scoring
        case results(SnapshotSession)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.intro, .intro), (.task1, .task1), (.task2, .task2),
                 (.task3, .task3), (.task4, .task4), (.scoring, .scoring):
                return true
            case (.transition(let a), .transition(let b)):
                return a.title == b.title
            case (.results, .results):
                return true
            default:
                return false
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var statsQuery: [PlayerStats]

    private var stats: PlayerStats {
        statsQuery.first ?? PlayerStats.fetchOrCreate(in: modelContext)
    }

    @State private var phase: Phase = .intro
    @State private var unlockedAchievement: Achievement? = nil

    // Trial data accumulated across tasks
    @State private var task1Trials: [TrialRecord] = []
    @State private var task2Trials: [TrialRecord] = []
    @State private var task3Trials: [TrialRecord] = []
    @State private var task4Trials: [TrialRecord] = []

    var body: some View {
        ZStack {
            AnimatedGradientBackground().ignoresSafeArea()
            Color(.systemBackground).opacity(0.88).ignoresSafeArea()

            phaseContent
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: phase)

            // Achievement banner
            if let achievement = unlockedAchievement {
                AchievementUnlockedBanner(achievement: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: unlockedAchievement?.id)
                    .zIndex(20)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Phase content

    @ViewBuilder
    var phaseContent: some View {
        switch phase {
        case .intro:
            introView

        case .task1:
            VStack(spacing: 0) {
                taskHeader(number: 1, title: "Lightning Tap", color: .orange)
                LightningTapTaskView { trials in
                    task1Trials = trials
                    withAnimation { phase = .transition(.arrowStorm) }
                }
            }

        case .transition(let nextTask):
            SnapshotTransitionView(nextTask: nextTask) {
                withAnimation {
                    switch nextTask {
                    case .arrowStorm:   phase = .task2
                    case .cardMatch:    phase = .task3
                    case .shapeShift:   phase = .task4
                    case .lightningTap: phase = .task1
                    }
                }
            }

        case .task2:
            VStack(spacing: 0) {
                taskHeader(number: 2, title: "Arrow Storm", color: .indigo)
                ArrowStormTaskView { trials in
                    task2Trials = trials
                    withAnimation { phase = .transition(.cardMatch) }
                }
            }

        case .task3:
            VStack(spacing: 0) {
                taskHeader(number: 3, title: "Card Match", color: .blue)
                CardMatchTaskView { trials in
                    task3Trials = trials
                    withAnimation { phase = .transition(.shapeShift) }
                }
            }

        case .task4:
            VStack(spacing: 0) {
                taskHeader(number: 4, title: "Shape Shift", color: .purple)
                ShapeShiftTaskView { trials in
                    task4Trials = trials
                    withAnimation { phase = .scoring }
                    computeAndSave()
                }
            }

        case .scoring:
            scoringView

        case .results(let session):
            SnapshotResultsView(session: session, stats: stats) {
                dismiss()
            }
        }
    }

    // MARK: - Intro screen

    var introView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.pulse)

            VStack(spacing: 10) {
                Text("Brain Snapshot")
                    .font(.largeTitle.bold())
                Text("4 quick tasks, about 4 minutes")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                taskPreviewRow(number: 1, title: "Lightning Tap", domain: "Processing Speed",
                               icon: "bolt.fill", color: .orange)
                taskPreviewRow(number: 2, title: "Arrow Storm", domain: "Attention & Focus",
                               icon: "arrow.left.and.right", color: .indigo)
                taskPreviewRow(number: 3, title: "Card Match", domain: "Working Memory",
                               icon: "rectangle.portrait.on.rectangle.portrait.fill", color: .blue)
                taskPreviewRow(number: 4, title: "Shape Shift", domain: "Cognitive Flexibility",
                               icon: "square.on.circle.fill", color: .purple)
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            if stats.snapshotSessionCount == 0 {
                Label("This establishes your Brain Baseline", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else if stats.snapshotSessionCount == 1 {
                Label("Session 2 of 2 to complete your baseline", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.blue)
            }

            Spacer()

            Button {
                withAnimation { phase = .task1 }
            } label: {
                Text("Start Brain Snapshot")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
            }
            .padding(.horizontal)

            Button { dismiss() } label: {
                Text("Cancel").font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    func taskPreviewRow(number: Int, title: String, domain: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                Text("\(number)").font(.subheadline.bold()).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(domain).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 16))
        }
    }

    // MARK: - Task header (progress indicator)

    func taskHeader(number: Int, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ForEach(1...4, id: \.self) { n in
                Capsule()
                    .fill(n == number ? color : (n < number ? color.opacity(0.4) : Color(.systemGray5)))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Scoring screen

    var scoringView: some View {
        VStack(spacing: 20) {
            Spacer()
            SwiftUI.ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            Text("Calculating your Brain Score…")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Compute & save

    func computeAndSave() {
        Task { @MainActor in
            // Give the scoring view time to render
            try? await Task.sleep(for: .milliseconds(600))

            let ageBand = stats.ageRange.isEmpty ? "35-44" : stats.ageRange

            // Build TaskResults from trial records
            let results = buildTaskResults()
            let output = SnapshotScoringEngine.computeScores(from: results, ageBand: ageBand)

            // Create session
            let sessionNum = stats.snapshotSessionCount + 1
            let isCalibration = sessionNum <= 2
            let isBaseline = sessionNum == 2

            let session = SnapshotSession(
                sessionNumber: sessionNum,
                isCalibration: isCalibration,
                isBaseline: isBaseline
            )

            // Fill task scores
            session.ltMedianSimpleRT          = output.session.ltMedianSimpleRT
            session.ltMedianChoiceRT          = output.session.ltMedianChoiceRT
            session.ltCoefficientOfVariation  = output.session.ltCV
            session.ltValidTrials             = output.session.ltValidTrials
            session.asIncongruentAccuracy     = output.session.asAccuracy
            session.asMedianIncongruentRT     = output.session.asMedianRT
            session.asFlankerScore            = output.session.asFlankerScore
            session.cmHitRate                 = output.session.cmHitRate
            session.cmFalseAlarmRate          = output.session.cmFARate
            session.cmDPrime                  = output.session.cmDPrime
            session.cmMedianMatchRT           = output.session.cmMatchRT
            session.ssMixedAccuracy           = output.session.ssMixedAccuracy
            session.ssMixedMedianRT           = output.session.ssMixedMedianRT
            session.ssEfficiencyScore         = output.session.ssEfficiency
            session.speedPercentile           = output.percentiles.speed
            session.attentionPercentile       = output.percentiles.attention
            session.memoryPercentile          = output.percentiles.memory
            session.flexibilityPercentile     = output.percentiles.flex
            session.brainScore                = output.brainScore
            session.brainAge                  = output.brainAge

            // Store raw trial JSON
            let allTrials = task1Trials + task2Trials + task3Trials + task4Trials
            session.rawTrialData = try? JSONEncoder().encode(allTrials)

            modelContext.insert(session)

            // Update PlayerStats
            let leveledUp = stats.recordSnapshotSession(brainScore: output.brainScore)
            _ = leveledUp

            // Schedule next snapshot reminder (weekly for sessions 1–4, biweekly for 5+)
            let daysUntilNext = sessionNum >= 5 ? 14 : 7
            NotificationManager.shared.scheduleSnapshotReminder(
                sessionCount: sessionNum,
                daysFromNow: daysUntilNext
            )

            // Show results first — the achievement banner overlays them rather
            // than holding a "Calculating…" spinner for ~4 seconds.
            withAnimation { phase = .results(session) }

            let newAchievements = checkAndUnlock(stats: stats)
            if let first = newAchievements.first {
                try? await Task.sleep(for: .milliseconds(500))
                unlockedAchievement = first
                Haptics.success()
                try? await Task.sleep(for: .seconds(3))
                unlockedAchievement = nil
            }
        }
    }

    // MARK: - Build TaskResults from trial records

    func buildTaskResults() -> SnapshotScoringEngine.TaskResults {
        // Task 1 — Lightning Tap
        let ltSimpleValid = task1Trials.filter {
            $0.phase == "simple" && $0.isCorrect && !$0.isAnticipatory && !$0.isLapse
        }.map { Double($0.reactionTimeMs) }

        let ltChoiceValid = task1Trials.filter {
            $0.phase == "choice" && $0.orbColor == "green" && $0.isCorrect && !$0.isAnticipatory && !$0.isLapse
        }.map { Double($0.reactionTimeMs) }

        let ltAllValid = task1Trials.filter { !$0.isAnticipatory && !$0.isLapse }
            .map { Double($0.reactionTimeMs) }

        // Task 2 — Arrow Storm
        let incongruent = task2Trials.filter { $0.trialType == "incongruent" }
        let incongruentCorrect = incongruent.filter { $0.isCorrect }.count
        let incongruentRTs = incongruent.filter { $0.isCorrect && !$0.isLapse }
            .map { Double($0.reactionTimeMs) }

        // Task 3 — Card Match (exclude trial 1 from scoring)
        let matchTrials = task3Trials.dropFirst()
        let targets    = matchTrials.filter { $0.isTargetMatch == true }
        let nonTargets = matchTrials.filter { $0.isTargetMatch == false }
        let hits       = targets.filter { $0.userResponse == "match" }.count
        let falseAlarms = nonTargets.filter { $0.userResponse == "match" }.count
        let matchRTs   = targets.filter { $0.isCorrect && !$0.isLapse }
            .map { Double($0.reactionTimeMs) }

        // Task 4 — Shape Shift
        let mixedTrials    = task4Trials.filter { $0.block == "mixed" }
        let mixedCorrect   = mixedTrials.filter { $0.isCorrect }.count
        let mixedCorrectRTs = mixedTrials.filter { $0.isCorrect && !$0.isLapse }
            .map { Double($0.reactionTimeMs) }

        return SnapshotScoringEngine.TaskResults(
            ltValidSimpleRTs: ltSimpleValid,
            ltValidChoiceRTs: ltChoiceValid,
            ltAllValidRTs: ltAllValid,
            asIncongruentCorrect: incongruentCorrect,
            asIncongruentTotal: max(1, incongruent.count),
            asIncongruentRTs: incongruentRTs,
            cmHits: hits,
            cmTargets: targets.count,
            cmFalseAlarms: falseAlarms,
            cmNonTargets: nonTargets.count,
            cmCorrectMatchRTs: Array(matchRTs),
            ssCorrectMixed: mixedCorrect,
            ssMixedTotal: max(1, mixedTrials.count),
            ssMixedCorrectRTs: mixedCorrectRTs
        )
    }
}
