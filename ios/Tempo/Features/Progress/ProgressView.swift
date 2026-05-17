import SwiftUI

/// Renamed to `ProgressView` (collides with SwiftUI's ProgressView at call sites —
/// we always reference it as `ProgressView` from inside the Tempo module so the
/// local symbol takes precedence). For safety we additionally namespace via filename.
///
/// Everything on this screen is computed from `store.history` — no hardcoded
/// numbers. When a user has zero logged sessions (the typical state on a
/// fresh phone install), the screen shows a single empty-state card instead
/// of the usual KPI/volume/lifts/coverage stack.
struct ProgressView: View {
    @EnvironmentObject var store: SessionStore
    @State private var range = "1M"
    @State private var liftForDetail: TopLift? = nil
    private let ranges = ["1W", "1M", "3M", "1Y"]

    var body: some View {
        let metrics = ProgressMetrics.compute(history: store.history, range: range)
        VStack(spacing: 0) {
            TopBar(
                title: "Progress",
                dateLine: nil,
                trailing: AnyView(RangeSegmented(ranges: ranges, selection: $range))
            )
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 18) {
                    if metrics.sessionCount == 0 {
                        emptyStateCard
                    } else {
                        kpiCard(metrics: metrics)

                        // Volume chart only earns its keep once the user has
                        // at least 2 sessions in the window — a single bar
                        // is not a "trend".
                        if metrics.totalVolume > 0 && metrics.sessionCount >= 2 {
                            volumeCard(metrics: metrics)
                        }

                        if !metrics.topLifts.isEmpty {
                            topLiftsCard(metrics: metrics)
                        }

                        if !metrics.coverage.isEmpty {
                            coverageCard(metrics: metrics)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .sheet(item: $liftForDetail) { lift in
            LiftDetailSheet(lift: lift, history: store.history)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.Color.bgElev1)
        }
    }

    // MARK: - Cards

    /// Big "you have no data yet" card. Replaces every chart on the screen
    /// when history is empty so the user isn't staring at "0 sessions ·
    /// 0h 0m · 0 PRs" with empty rectangles below.
    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress".uppercased()).overlineStyle()
            Text("No sessions yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.Color.fg)
            Text("Train and finish a session — your KPIs, top lifts, and muscle-group coverage will appear here.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .card(padding: 0)
    }

    private func kpiCard(metrics: ProgressMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(metrics.range.kpiHeader.uppercased()).overlineStyle()
            KPIRow([
                (value: "\(metrics.sessionCount)",        unit: metrics.sessionCount == 1 ? "Session" : "Sessions"),
                (value: formatDuration(metrics.activeSeconds), unit: "Active"),
                (value: "\(metrics.prCount)",             unit: metrics.prCount == 1 ? "PR" : "PRs"),
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(padding: 0)
    }

    private func volumeCard(metrics: ProgressMetrics) -> some View {
        let totalLabel = formatVolume(metrics.totalVolume)
        let deltaLabel = metrics.volumeDeltaLabel
        return ChartCard(
            title: "Volume · \(metrics.range.bucketGranularity)",
            value: totalLabel,
            delta: deltaLabel,
            onTap: nil
        ) {
            BarChartView(values: metrics.volumeBucketsNormalized)
                .frame(height: 90)
            HStack {
                ForEach(Array(metrics.volumeBucketLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(Theme.Font.mono(10))
                        .foregroundColor(Theme.Color.fgFaint)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private func topLiftsCard(metrics: ProgressMetrics) -> some View {
        VStack(spacing: 0) {
            SectionHead(title: "Top lifts", meta: "Tap for details")
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(metrics.topLifts) { lift in
                    Button(action: { liftForDetail = lift }) {
                        topLiftRow(lift)
                    }
                    .buttonStyle(.plain)
                    if lift.id != metrics.topLifts.last?.id {
                        Divider().background(Theme.Color.hairline)
                    }
                }
            }
            .card(padding: 0)
        }
    }

    private func coverageCard(metrics: ProgressMetrics) -> some View {
        ChartCard(
            title: "Coverage · \(metrics.range.shortLabel)",
            value: nil,
            delta: nil,
            meta: "By muscle group",
            onTap: nil
        ) {
            VStack(spacing: 8) {
                ForEach(metrics.coverage) { row in
                    heatmapRow(row.muscle, cells: row.cells, val: "\(row.total) session\(row.total == 1 ? "" : "s")")
                }
            }
        }
    }

    // MARK: - Sub-rows

    private func topLiftRow(_ lift: TopLift) -> some View {
        HStack {
            Text(lift.name).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(lift.best)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(Theme.Color.fg)
            Text(lift.delta)
                .font(Theme.Font.mono(11, .medium))
                .foregroundColor(deltaColor(lift.direction))
                .frame(width: 56, alignment: .trailing)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func deltaColor(_ d: TrendDirection) -> Color {
        switch d {
        case .up:   return Theme.Color.accent
        case .down: return Theme.Color.dangerSoft
        case .flat: return Theme.Color.fgFaint
        }
    }

    private func heatmapRow(_ name: String, cells: [Int], val: String) -> some View {
        Button(action: { store.showToast("\(name): \(val)", icon: "square.grid.3x3.fill") }) {
            HStack(spacing: 10) {
                Text(name).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgMute)
                    .frame(width: 86, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(0..<cells.count, id: \.self) { i in
                        Rectangle()
                            .fill(Theme.Color.accent.opacity(min(1.0, Double(cells[i]) / 4) * 0.85))
                            .frame(height: 20)
                            .overlay(
                                Rectangle().strokeBorder(Theme.Color.hairline, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(maxWidth: .infinity)
                Text(val).font(Theme.Font.mono(10.5)).foregroundColor(Theme.Color.fgSoft)
                    .frame(width: 76, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }

    private func formatVolume(_ pounds: Int) -> String {
        // Avoid Foundation's number formatter for one-off use; thousands
        // separator only.
        let s = "\(pounds)"
        guard pounds >= 1000 else { return s }
        var out = ""
        for (i, ch) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return String(out.reversed())
    }
}

// MARK: - Range model

private extension String {
    /// Map the segmented control's "1W" / "1M" / "3M" / "1Y" string into
    /// the typed `TimeRange` we use for math. Falls back to month so a
    /// stale/unexpected string doesn't crash.
    var asTimeRange: TimeRange {
        TimeRange(rawValue: self) ?? .month
    }
}

enum TimeRange: String {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"

    var days: Int {
        switch self {
        case .week:        return 7
        case .month:       return 30
        case .threeMonths: return 90
        case .year:        return 365
        }
    }

    /// Header text on the KPI card for this range.
    var kpiHeader: String {
        switch self {
        case .week:        return "This week"
        case .month:       return "This month"
        case .threeMonths: return "Last 3 months"
        case .year:        return "This year"
        }
    }

    /// Mid-card meta that says what the bar buckets actually represent.
    var bucketGranularity: String {
        switch self {
        case .week:        return "daily"
        case .month:       return "weekly"
        case .threeMonths: return "biweekly"
        case .year:        return "monthly"
        }
    }

    var shortLabel: String { rawValue.lowercased() }
}

// MARK: - Metrics

/// Output of `compute(history:range:)`. Pure values — no Views, no SwiftUI
/// types — so this can be unit-tested in isolation if we ever want to.
struct ProgressMetrics {
    let range: TimeRange

    // KPIs
    let sessionCount: Int
    let activeSeconds: Int
    let prCount: Int

    // Volume bar chart
    let totalVolume: Int               // sum of reps * weight across the window
    let prevTotalVolume: Int           // same metric for the *previous* window of the same length, for the delta arrow
    let volumeBucketsNormalized: [Double]   // 7 values in 0...1
    let volumeBucketLabels: [String]   // 7 short labels, one per bucket

    // Top lifts
    let topLifts: [TopLift]

    // Coverage heatmap
    struct CoverageRow: Identifiable {
        let id = UUID()
        let muscle: String
        /// Per-bucket session counts (same 7 buckets as the volume chart).
        let cells: [Int]
        /// Total sessions touching this muscle group across the window.
        let total: Int
    }
    let coverage: [CoverageRow]

    var volumeDeltaLabel: String? {
        guard prevTotalVolume > 0 else { return nil }   // can't compute % vs zero
        let delta = totalVolume - prevTotalVolume
        let pct = Double(delta) / Double(prevTotalVolume) * 100
        let arrow = delta > 0 ? "▲" : (delta < 0 ? "▼" : "—")
        return String(format: "%@ %.0f%%", arrow, abs(pct))
    }

    /// Bucket the window into 7 equal-sized time slices. Returns inclusive
    /// `[start, end)` Date pairs, oldest first.
    static func sevenBuckets(now: Date, range: TimeRange) -> [(Date, Date)] {
        let cal = Calendar.current
        let secondsTotal = TimeInterval(range.days) * 86_400
        let bucketSeconds = secondsTotal / 7
        let windowStart = now.addingTimeInterval(-secondsTotal)
        return (0..<7).map { i in
            let s = windowStart.addingTimeInterval(bucketSeconds * Double(i))
            let e = (i == 6) ? now : windowStart.addingTimeInterval(bucketSeconds * Double(i + 1))
            return (cal.startOfDay(for: s), e)
        }
    }

    static func compute(history: [CompletedSession], range rangeStr: String, now: Date = Date()) -> ProgressMetrics {
        let range = rangeStr.asTimeRange
        let cal = Calendar.current

        // Two windows: current (last `days` days) and previous (the equivalent
        // window immediately before that). The previous window powers the
        // `▲ N%` delta on the volume card.
        let windowEnd       = now
        let windowStart     = now.addingTimeInterval(-TimeInterval(range.days) * 86_400)
        let prevWindowStart = windowStart.addingTimeInterval(-TimeInterval(range.days) * 86_400)

        let inWindow = history.filter { $0.date >= windowStart && $0.date <= windowEnd }
        let inPrev   = history.filter { $0.date >= prevWindowStart && $0.date < windowStart }

        let sessionCount  = inWindow.count
        let activeSeconds = inWindow.reduce(0) { $0 + $1.durationSeconds }
        let prCount       = inWindow.reduce(0) { $0 + $1.prCount }

        let totalVolume     = sumVolume(inWindow)
        let prevTotalVolume = sumVolume(inPrev)

        // Bucket sessions onto a 7-cell histogram. Each bucket holds the
        // sum of session volumes whose `date` falls inside it.
        let buckets = sevenBuckets(now: now, range: range)
        var volumePerBucket = [Int](repeating: 0, count: 7)
        for s in inWindow {
            if let i = bucketIndex(for: s.date, buckets: buckets) {
                volumePerBucket[i] += sessionVolume(s)
            }
        }
        // Normalize 0...1 against the local max so the tallest bar is
        // always full-height (a typical visualization choice — readers
        // care about *relative* effort, not absolute pounds).
        let maxV = max(1, volumePerBucket.max() ?? 0)
        let normalized = volumePerBucket.map { Double($0) / Double(maxV) }
        let bucketLabels = bucketLabels(for: range, buckets: buckets, cal: cal)

        let topLifts = computeTopLifts(history: inWindow)
        let coverage = computeCoverage(history: inWindow, buckets: buckets)

        return ProgressMetrics(
            range: range,
            sessionCount: sessionCount,
            activeSeconds: activeSeconds,
            prCount: prCount,
            totalVolume: totalVolume,
            prevTotalVolume: prevTotalVolume,
            volumeBucketsNormalized: normalized,
            volumeBucketLabels: bucketLabels,
            topLifts: topLifts,
            coverage: coverage
        )
    }

    // MARK: helpers

    private static func sumVolume(_ sessions: [CompletedSession]) -> Int {
        sessions.reduce(0) { $0 + sessionVolume($1) }
    }

    /// "Volume" = sum of reps × weight across all non-skipped sets in a
    /// session, on both you and partner sides. This is the standard
    /// strength-training volume metric (e.g. 5 × 100 = 500).
    private static func sessionVolume(_ s: CompletedSession) -> Int {
        let yours    = s.you.reduce(0) { $0 + exerciseVolume($1) }
        let partners = s.partner.reduce(0) { $0 + exerciseVolume($1) }
        return yours + partners
    }

    private static func exerciseVolume(_ ex: CompletedExercise) -> Int {
        ex.sets.reduce(0) { acc, set in
            guard !set.skipped else { return acc }
            return acc + (set.reps * set.weight)
        }
    }

    private static func bucketIndex(for date: Date, buckets: [(Date, Date)]) -> Int? {
        for (i, b) in buckets.enumerated() where date >= b.0 && date < b.1 {
            return i
        }
        // Edge case: a session timestamped at exactly `now` falls past the
        // last bucket's end (which is also `now`). Snap it into the last
        // bucket so we don't drop today's volume.
        if let last = buckets.last, date >= last.0 && date <= last.1 {
            return buckets.count - 1
        }
        return nil
    }

    private static func bucketLabels(for range: TimeRange, buckets: [(Date, Date)], cal: Calendar) -> [String] {
        let f = DateFormatter()
        switch range {
        case .week:        f.dateFormat = "EEE"      // Mon, Tue, ...
        case .month:       f.dateFormat = "MMM d"    // Apr 14
        case .threeMonths: f.dateFormat = "MMM d"
        case .year:        f.dateFormat = "MMM"      // Jan, Feb, ...
        }
        return buckets.map { f.string(from: $0.0) }
    }

    /// Top 4 strength/bodyweight exercises by total volume in the window.
    /// "Best" is the heaviest *single set* (weight × reps); delta compares
    /// the latest occurrence's best to the previous one's best.
    private static func computeTopLifts(history: [CompletedSession]) -> [TopLift] {
        // Aggregate by `catalogId`: total volume + every (date, weight, reps)
        // tuple of non-skipped sets so we can find best & delta.
        struct Agg {
            var name: String = ""
            var totalVolume: Int = 0
            var attempts: [(date: Date, weight: Int, reps: Int)] = []
        }
        var byId: [String: Agg] = [:]

        for session in history {
            for ex in session.you {
                var a = byId[ex.catalogId] ?? Agg()
                a.name = ex.name
                for set in ex.sets where !set.skipped {
                    a.totalVolume += set.reps * set.weight
                    a.attempts.append((session.date, set.weight, set.reps))
                }
                byId[ex.catalogId] = a
            }
        }

        let topIds = byId.sorted { $0.value.totalVolume > $1.value.totalVolume }.prefix(4)
        return topIds.compactMap { (_, agg) -> TopLift? in
            guard !agg.attempts.isEmpty else { return nil }
            // Best = heaviest single set. For bodyweight (weight==0 across
            // the board) fall back to most reps.
            let isBodyweight = agg.attempts.allSatisfy { $0.weight == 0 }
            let best: (date: Date, weight: Int, reps: Int)
            if isBodyweight {
                best = agg.attempts.max(by: { $0.reps < $1.reps })!
            } else {
                best = agg.attempts.max(by: { $0.weight < $1.weight })!
            }
            // Delta: best from session(s) before `best.date` vs current best.
            let prior = agg.attempts.filter { $0.date < best.date }
            let priorBest = isBodyweight
                ? prior.max(by: { $0.reps < $1.reps })?.reps ?? 0
                : prior.max(by: { $0.weight < $1.weight })?.weight ?? 0
            let bestVal = isBodyweight ? best.reps : best.weight
            let diff = bestVal - priorBest
            let direction: TrendDirection = diff > 0 ? .up : (diff < 0 ? .down : .flat)
            let bestStr = isBodyweight
                ? "\(best.reps) reps"
                : "\(best.weight) lb × \(best.reps)"
            let deltaStr: String
            if priorBest == 0 {
                deltaStr = "new"
            } else if diff == 0 {
                deltaStr = "—"
            } else {
                let sign = diff > 0 ? "+" : "−"
                let unit = isBodyweight ? "" : " lb"
                deltaStr = "\(sign)\(abs(diff))\(unit)"
            }
            return TopLift(name: agg.name, best: bestStr, delta: deltaStr, direction: direction)
        }
    }

    /// Muscle-group coverage. For each session, every `CompletedExercise`
    /// contributes its catalog-mapped muscle groups to that session's
    /// bucket. Returns the top 6 muscle groups by total touches.
    private static func computeCoverage(history: [CompletedSession], buckets: [(Date, Date)]) -> [CoverageRow] {
        // muscle → per-bucket session counts (each unique session once, so
        // doing 5 chest exercises in one session still only counts once
        // for "Chest").
        var counts: [String: [Int]] = [:]   // muscle → [7 ints]
        for session in history {
            guard let bIdx = bucketIndex(for: session.date, buckets: buckets) else { continue }
            // Collect all muscle groups touched by this session via the
            // catalog (exercises log their `catalogId` at save time).
            var touched: Set<String> = []
            for ex in session.you {
                if let cat = ExerciseCatalog.all.first(where: { $0.id == ex.catalogId }) {
                    cat.muscleGroups.forEach { touched.insert($0) }
                }
            }
            for muscle in touched {
                if counts[muscle] == nil {
                    counts[muscle] = [Int](repeating: 0, count: 7)
                }
                counts[muscle]![bIdx] += 1
            }
        }

        let rows = counts.map { (muscle, cells) -> CoverageRow in
            CoverageRow(muscle: muscle, cells: cells, total: cells.reduce(0, +))
        }
        return rows.sorted { $0.total > $1.total }.prefix(6).map { $0 }
    }
}

// MARK: - Range segmented

private struct RangeSegmented: View {
    var ranges: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ranges, id: \.self) { r in
                Button(action: { selection = r }) {
                    Text(r)
                        .font(Theme.Font.mono(11, .medium))
                        .foregroundColor(selection == r ? Theme.Color.fg : Theme.Color.fgMute)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(selection == r ? Theme.Color.bgElev3 : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.Color.bgElev2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
        .frame(width: 168)
    }
}

// MARK: - Chart card

private struct ChartCard<Content: View>: View {
    var title: String
    var value: String? = nil
    var delta: String? = nil
    var meta: String? = nil
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased()).overlineStyle()
                Spacer()
                if let value, let delta {
                    HStack(spacing: 8) {
                        Text(value).font(.system(size: 14, weight: .medium).monospacedDigit()).foregroundColor(Theme.Color.fg)
                        Text(delta).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.accent)
                    }
                } else if let value {
                    Text(value).font(.system(size: 14, weight: .medium).monospacedDigit()).foregroundColor(Theme.Color.fg)
                } else if let meta {
                    Text(meta).font(Theme.Font.mono(10.5)).foregroundColor(Theme.Color.fgSoft)
                }
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Color.fgFaint)
                        .padding(.leading, 6)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card(padding: 0)

        if let onTap {
            Button(action: onTap) { card }
                .buttonStyle(PressableStyle())
        } else {
            card
        }
    }
}

// MARK: - Lift detail sheet

private struct LiftDetailSheet: View {
    let lift: TopLift
    let history: [CompletedSession]

    /// Pull every set this user has done for the lift. Reverse-chronological,
    /// most recent first, ignoring skipped sets.
    private var attempts: [(date: Date, weight: Int, reps: Int, isPR: Bool)] {
        var out: [(Date, Int, Int, Bool)] = []
        for s in history.sorted(by: { $0.date > $1.date }) {
            for ex in s.you where ex.name == lift.name {
                for set in ex.sets where !set.skipped {
                    out.append((s.date, set.weight, set.reps, ex.isPR))
                }
            }
        }
        return out.map { (date: $0.0, weight: $0.1, reps: $0.2, isPR: $0.3) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top lift".uppercased()).overlineStyle()
                    Text(lift.name).font(.system(size: 28, weight: .semibold)).foregroundColor(Theme.Color.fg)
                    HStack(spacing: 6) {
                        Text(lift.best)
                            .font(.system(size: 14, weight: .medium).monospacedDigit())
                            .foregroundColor(Theme.Color.fg)
                        Text("·").foregroundColor(Theme.Color.fgFaint)
                        Text(lift.delta).font(Theme.Font.mono(12, .medium)).foregroundColor(Theme.Color.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent attempts".uppercased()).overlineStyle()
                    if attempts.isEmpty {
                        Text("No logged sets yet.")
                            .font(Theme.Font.mono(12))
                            .foregroundColor(Theme.Color.fgSoft)
                    } else {
                        ForEach(Array(attempts.prefix(10).enumerated()), id: \.offset) { i, a in
                            attemptRow(a)
                            if i < min(9, attempts.count - 1) {
                                Divider().background(Theme.Color.hairline)
                            }
                        }
                    }
                }
                .padding(16)
                .card(padding: 0)
            }
            .padding(20)
        }
        .background(Theme.Color.bgElev1)
    }

    private func attemptRow(_ a: (date: Date, weight: Int, reps: Int, isPR: Bool)) -> some View {
        HStack {
            Text(formatDate(a.date)).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
            Spacer()
            if a.isPR {
                Text("PR")
                    .font(Theme.Font.mono(9, .medium))
                    .foregroundColor(Theme.Color.pr)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.Color.prDim)
                    .clipShape(Capsule())
            }
            Text(a.weight == 0 ? "\(a.reps) reps" : "\(a.weight) lb × \(a.reps)")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(Theme.Color.fg)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d)     { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}

// MARK: - Bar chart

struct BarChartView: View {
    var values: [Double]   // 0...1
    var body: some View {
        GeometryReader { geo in
            let w = max(0, geo.size.width - CGFloat(values.count - 1) * 12) / CGFloat(values.count)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<values.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == values.count - 1 ? Theme.Color.accent : Theme.Color.bgElev3)
                        .frame(width: w, height: max(8, values[i] * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Line chart (you + partner)

struct LineChartView: View {
    var you: [Double]
    var partner: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // gridlines
                ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { r in
                    Path { p in
                        let y = r * (h - 20) + 10
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .foregroundColor(Theme.Color.hairline)
                }

                // partner line
                line(points: partner, in: geo.size)
                    .stroke(Theme.Color.partner.opacity(0.65), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                // you area
                area(points: you, in: geo.size)
                    .fill(Theme.Color.accent.opacity(0.08))

                line(points: you, in: geo.size)
                    .stroke(Theme.Color.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // end dot
                if let last = you.last {
                    let y = CGFloat(last) / 100 * h
                    Circle().fill(Theme.Color.accent).frame(width: 8, height: 8)
                        .position(x: w - 4, y: y)
                }
            }
        }
    }

    private func line(points: [Double], in size: CGSize) -> Path {
        Path { p in
            let stepX = size.width / CGFloat(max(1, points.count - 1))
            for (i, v) in points.enumerated() {
                let pt = CGPoint(x: CGFloat(i) * stepX, y: CGFloat(v) / 100 * size.height)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }

    private func area(points: [Double], in size: CGSize) -> Path {
        Path { p in
            let stepX = size.width / CGFloat(max(1, points.count - 1))
            for (i, v) in points.enumerated() {
                let pt = CGPoint(x: CGFloat(i) * stepX, y: CGFloat(v) / 100 * size.height)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
    }
}
