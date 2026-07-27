import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameSession.date, order: .forward) private var sessions: [GameSession]
    @Query(sort: \SnapshotSession.date, order: .forward) private var snapshotSessions: [SnapshotSession]

    private var stats: PlayerStats {
        statsQuery.first ?? PlayerStats.fetchOrCreate(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground().ignoresSafeArea()
                Color(.systemBackground).opacity(0.82).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        overallScoreCard
                        metricChartsSection
                        vsAverageSection
                        streakCalendarSection
                        recentSessionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Overall Score Chart

    var overallScoreCard: some View {
        let overallSessions = computeOverallSeries()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Overall Brain Score")
                        .font(.headline)
                    if stats.overallBrainScore > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(stats.overallBrainScore)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text(trendArrow(for: overallSessions))
                                .font(.title2)
                                .foregroundStyle(trendColor(for: overallSessions))
                        }
                        Text(PlayerStats.percentileLabel(for: stats.overallBrainScore))
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(scoreColor(stats.overallBrainScore).opacity(0.15))
                            .foregroundStyle(scoreColor(stats.overallBrainScore))
                            .clipShape(Capsule())
                    } else {
                        Text("Play 3 scored games to unlock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if overallSessions.count >= 2 {
                Chart {
                    RuleMark(y: .value("Average", 100))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .trailing, alignment: .center) {
                            Text("avg").font(.caption2).foregroundStyle(.secondary)
                        }
                    ForEach(Array(overallSessions.enumerated()), id: \.offset) { i, pt in
                        LineMark(
                            x: .value("Session", i),
                            y: .value("Score",   pt.score)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Session", i),
                            yStart: .value("Base", 60),
                            yEnd:   .value("Score", pt.score)
                        )
                        .foregroundStyle(.blue.opacity(0.08))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Session", i),
                            y: .value("Score",   pt.score)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(30)
                    }
                }
                .chartYScale(domain: 60...150)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [70, 85, 100, 115, 130]) { val in
                        AxisGridLine().foregroundStyle(Color(.systemGray5))
                        AxisValueLabel()
                    }
                }
                .frame(height: 140)
            } else {
                emptyChartPlaceholder(message: "Play more games to see your trend")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Per-metric Charts

    /// Every scored game, newest-played first. Games never played are omitted
    /// rather than shown as empty charts.
    private var trackedMetrics: [(type: String, title: String, score: Int)] {
        [("memory",  "Memory",           stats.memoryBrainScore),
         ("spatial", "Spatial Memory",   stats.spatialBrainScore),
         ("nback",   "Working Memory",   stats.nbackBrainScore),
         ("bounce",  "Mental Simulation", stats.bounceBrainScore),
         ("flanker", "Attention",        stats.flankerBrainScore),
         ("switch",  "Flexibility",      stats.switchBrainScore),
         ("speed",   "Processing Speed", stats.speedBrainScore),
         ("visual",  "Visual Search",    stats.visualBrainScore),
         ("reflex",  "Reflex",           stats.reflexBrainScore),
         ("pattern", "Problem Solving",  stats.patternBrainScore)]
            .filter { $0.2 > 0 }
    }

    var metricChartsSection: some View {
        VStack(spacing: 16) {
            ForEach(trackedMetrics, id: \.type) { metric in
                metricChart(
                    title: metric.title,
                    icon: gameIcon(metric.type),
                    color: gameColor(metric.type),
                    currentScore: metric.score,
                    series: scoreSeries(for: metric.type)
                )
            }
        }
    }

    func metricChart(title: String, icon: String, color: Color, currentScore: Int, series: [ScorePoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                if currentScore > 0 {
                    Text("\(currentScore)")
                        .font(.subheadline.bold())
                        .foregroundStyle(color)
                    Text(PlayerStats.percentileLabel(for: currentScore))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if series.count >= 2 {
                Chart {
                    RuleMark(y: .value("Average", 100))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                        .foregroundStyle(.secondary.opacity(0.4))
                    ForEach(Array(series.enumerated()), id: \.offset) { i, pt in
                        LineMark(
                            x: .value("Session", i),
                            y: .value("Score", pt.score)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Session", i),
                            y: .value("Score", pt.score)
                        )
                        .foregroundStyle(color)
                        .symbolSize(20)
                    }
                }
                .chartYScale(domain: 60...150)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [70, 100, 130]) { val in
                        AxisGridLine().foregroundStyle(Color(.systemGray6))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: 80)
            } else {
                emptyChartPlaceholder(message: "Play \(title) games to see your trend")
                    .frame(height: 60)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - vs Average

    var vsAverageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("vs. Average Person")
                .font(.headline)

            let benchmarks: [(String, Int, Color)] = [
                ("Memory", stats.memoryBrainScore, .blue),
                ("Reflex", stats.reflexBrainScore, .orange),
                ("Speed",  stats.speedBrainScore,  .green),
            ]

            ForEach(benchmarks, id: \.0) { name, score, color in
                if score > 0 {
                    vsAverageRow(name: name, score: score, color: color)
                }
            }

            if stats.memoryBrainScore == 0 && stats.reflexBrainScore == 0 && stats.speedBrainScore == 0 {
                Text("Play games to see how you compare")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    func vsAverageRow(name: String, score: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(score)")
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(PlayerStats.percentileLabel(for: score))
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    // Average marker
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(100 - 60) / CGFloat(150 - 60))

                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(min(score, 145) - 60) / CGFloat(150 - 60)))
                        .animation(.easeOut(duration: 0.6), value: score)
                }
            }
            .frame(height: 8)
            HStack {
                Text("70").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("100 avg").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("145").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Streak Calendar (last 14 days)

    var streakCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity — Last 14 Days")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(stats.dailyStreakCount) day streak")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }

            let activeDays = activeDaySet()
            let today = Calendar.current.startOfDay(for: Date())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach((0..<14).reversed(), id: \.self) { daysBack in
                    let day = Calendar.current.date(byAdding: .day, value: -daysBack, to: today)!
                    let active = activeDays.contains(day)
                    let isToday = daysBack == 0

                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(active ? Color.blue : Color(.systemGray5))
                            .frame(height: 32)
                            .overlay(
                                isToday ? RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 2) : nil
                            )
                        Text(dayLabel(day))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Recent Sessions

    var recentSessionsSection: some View {
        let recent = Array(sessions.suffix(20).reversed())
        guard !recent.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Sessions")
                    .font(.headline)

                ForEach(recent) { session in
                    HStack(spacing: 12) {
                        Image(systemName: gameIcon(session.gameType))
                            .font(.subheadline)
                            .foregroundStyle(gameColor(session.gameType))
                            .frame(width: 32, height: 32)
                            .background(gameColor(session.gameType).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(gameName(session.gameType))
                                .font(.subheadline.bold())
                            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if session.brainScore > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(session.brainScore)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(gameColor(session.gameType))
                                Text("score")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    if recent.last?.persistentModelID != session.persistentModelID {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 20))
        )
    }

    // MARK: - Data helpers

    struct ScorePoint { let date: Date; let score: Int }

    func scoreSeries(for type: String) -> [ScorePoint] {
        sessions
            .filter { $0.gameType == type && $0.brainScore > 0 }
            .map { ScorePoint(date: $0.date, score: $0.brainScore) }
    }

    func computeOverallSeries() -> [ScorePoint] {
        // Group sessions by date (day), average all-metric scores per day
        let calendar = Calendar.current
        var byDay: [Date: [Int]] = [:]
        for s in sessions where s.brainScore > 0 {
            let day = calendar.startOfDay(for: s.date)
            byDay[day, default: []].append(s.brainScore)
        }
        return byDay.keys.sorted().compactMap { day in
            guard let scores = byDay[day], !scores.isEmpty else { return nil }
            return ScorePoint(date: day, score: scores.reduce(0, +) / scores.count)
        }
    }

    /// Days with any activity — training games *or* a Brain Snapshot, which
    /// previously rendered as an inactive day.
    func activeDaySet() -> Set<Date> {
        let calendar = Calendar.current
        var days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        days.formUnion(snapshotSessions.map { calendar.startOfDay(for: $0.date) })
        return days
    }

    func trendArrow(for series: [ScorePoint]) -> String {
        guard series.count >= 4 else { return "" }
        // Average over however many points each window actually has — dividing
        // by a fixed 3 made a 1-point prior window read as a third of its value.
        let recentPoints = series.suffix(3).map(\.score)
        let priorPoints  = series.dropLast(3).suffix(3).map(\.score)
        guard !recentPoints.isEmpty, !priorPoints.isEmpty else { return "" }
        let recent = recentPoints.reduce(0, +) / recentPoints.count
        let prior  = priorPoints.reduce(0, +) / priorPoints.count
        if recent > prior + 2 { return "↑" }
        if recent < prior - 2 { return "↓" }
        return "→"
    }

    func trendColor(for series: [ScorePoint]) -> Color {
        let arrow = trendArrow(for: series)
        if arrow == "↑" { return .green }
        if arrow == "↓" { return .red }
        return .secondary
    }


    func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    func gameIcon(_ type: String) -> String {
        switch type {
        case "memory":  return "square.grid.3x3.fill"
        case "reflex":  return "bolt.fill"
        case "speed":   return "function"
        case "color":   return "paintpalette.fill"
        case "flanker": return "arrow.left.and.right"
        case "spatial": return "square.grid.2x2.fill"
        case "visual":  return "eye.fill"
        case "pattern": return "puzzlepiece.fill"
        case "switch":  return "arrow.triangle.swap"
        case "nback":   return "square.grid.3x3.topleft.filled"
        case "bounce":  return "arrow.uturn.right.circle.fill"
        default:        return "gamecontroller.fill"
        }
    }

    func gameColor(_ type: String) -> Color {
        switch type {
        case "memory":  return .blue
        case "reflex":  return .orange
        case "speed":   return .green
        case "color":   return .purple
        case "flanker": return .teal
        case "spatial": return .cyan
        case "visual":  return .indigo
        case "pattern": return .pink
        case "switch":  return .mint
        case "nback":   return .purple
        case "bounce":  return .cyan
        default:        return .secondary
        }
    }

    func gameName(_ type: String) -> String {
        switch type {
        case "memory":  return "Simon Says"
        case "reflex":  return "Reaction Time"
        case "speed":   return "Math Blitz"
        case "color":   return "Stroop Challenge"
        case "flanker": return "Flanker Task"
        case "spatial": return "Spatial Memory"
        case "visual":  return "Visual Search"
        case "pattern": return "Pattern Match"
        case "switch":  return "Switchboard"
        case "nback":   return "N-Track"
        case "bounce":  return "Bounce Cast"
        default:        return type.capitalized
        }
    }

    func emptyChartPlaceholder(message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [PlayerStats.self, GameSession.self], inMemory: true)
}
