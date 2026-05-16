import SwiftUI

/// Time-axis surface for the app: past, present, and future at a glance.
///
/// Replaces the History tab. Designed as a **vertical timeline**, newest-at-top:
///
///   ┌───── past ────────┐
///   │ Mon · session     │   tap → SessionDetailSheet
///   │ × 2 days off      │   compacted rest run
///   │ Thu · session     │
///   │ ─── TODAY ───     │   sticky-feel anchor (when it scrolls into view)
///   │ Sat · planned     │
///   │ × 4 days off      │
///   └─── future ────────┘
///
/// The day-by-day horizontal strip we shipped first read as a calendar, not a
/// timeline — users couldn't feel momentum and didn't know which direction
/// was "forward." Rebuilt as a single scrolling list with a left rail that
/// gives each entry an obvious node on the spine.
struct ScheduleView: View {
    @EnvironmentObject var store: SessionStore

    /// How many days backward and forward the timeline covers. 30 each side
    /// is enough for "is the AI planning a month ahead" without making the
    /// scroll cognitively expensive.
    private let pastWindow = 30
    private let futureWindow = 30

    @State private var showFullHistory = false
    @State private var sessionForDetail: CompletedSession? = nil

    /// Stable identifier the `ScrollViewReader` jumps to on appear so today
    /// always lands centered when the page opens. Must match the `id` we
    /// assign to the today row when constructing `rows` below.
    private let todayAnchor = "today"

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "Schedule",
                dateLine: monthLine,
                trailing: AnyView(
                    IconButton(systemName: "calendar") {
                        // No-op anchor for now; the scroll-to-today is wired
                        // via `ScrollViewReader` below. Kept as a button
                        // because it reads as the conventional "today" affordance.
                    }
                )
            )
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            TimelineRailRow(row: row,
                                            partnerName: store.partner.name,
                                            youName: store.profile.youLabel) { tapped in
                                handleTap(tapped)
                            }
                            .id(row.id)
                        }

                        Divider()
                            .background(Theme.Color.hairline)
                            .padding(.vertical, 18)

                        streakCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        viewAllHistoryRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                    .padding(.top, 8)
                }
                .onAppear {
                    // Land on today immediately. `.center` keeps both past
                    // and future visible — the user sees the timeline goes
                    // both directions without having to scroll first.
                    DispatchQueue.main.async {
                        proxy.scrollTo(todayAnchor, anchor: .center)
                    }
                }
            }
        }
        .sheet(isPresented: $showFullHistory) {
            HistoryView()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(item: $sessionForDetail) { session in
            SessionDetailSheet(
                session: session,
                partnerName: store.partner.name,
                paired: store.isPaired
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.Color.bgElev1)
        }
    }

    // MARK: - Top bar metadata

    private var monthLine: String? {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    // MARK: - Row construction

    /// Turns the day window into a compacted timeline:
    ///   - sessions render as their own row
    ///   - today is always its own row (the visual anchor, even on rest days)
    ///   - future planned days each get a row
    ///   - runs of rest days collapse into a single "× days off" gap row
    ///
    /// Order: newest-at-top. Past is rendered above today, future below.
    private var rows: [TimelineRow] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let allDays: [Date] = (-pastWindow ... futureWindow).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
        }

        let sessionsByDay: [Date: CompletedSession] = {
            var map: [Date: CompletedSession] = [:]
            for s in store.history { map[cal.startOfDay(for: s.date)] = s }
            return map
        }()

        // Walk newest → oldest so the resulting list is already in
        // top-to-bottom render order (today near the top once we splice in
        // future days; past below).
        let descending = allDays.reversed()
        var built: [TimelineRow] = []
        var pendingRestRun: (start: Date, end: Date, count: Int)? = nil

        func flushRestRun() {
            guard let run = pendingRestRun else { return }
            // Only collapse runs of 2+ — a single rest day is too short to
            // bother compressing and looks weird as a "× 1 day off" row.
            if run.count >= 2 {
                built.append(.restGap(id: "rest_\(run.start.timeIntervalSince1970)_\(run.end.timeIntervalSince1970)",
                                      count: run.count,
                                      start: run.start,
                                      end: run.end))
            } else {
                // Single rest day → drop a tiny placeholder so the rail
                // doesn't break, but no full card.
                built.append(.restSingle(id: "rest1_\(run.start.timeIntervalSince1970)",
                                         date: run.start))
            }
            pendingRestRun = nil
        }

        for day in descending {
            let isToday = cal.isDate(day, inSameDayAs: today)
            let isPast  = day < today
            let isFuture = day > today
            let session = sessionsByDay[day]
            let planned = shouldBePlanned(day)

            // Anything that's NOT a rest-only day flushes the pending run
            // before rendering its own row.
            if isToday {
                flushRestRun()
                built.append(.today(id: "today",
                                    date: day,
                                    plan: store.todayPlan,
                                    isPaired: store.isPaired))
            } else if let session {
                flushRestRun()
                built.append(.completed(id: "session_\(session.id.uuidString)",
                                        date: day,
                                        session: session))
            } else if isFuture && planned {
                flushRestRun()
                built.append(.planned(id: "planned_\(day.timeIntervalSince1970)",
                                      date: day,
                                      plan: store.todayPlan,
                                      isPaired: store.isPaired))
            } else if isPast || isFuture {
                // Rest-only day — accumulate.
                if pendingRestRun == nil {
                    pendingRestRun = (start: day, end: day, count: 1)
                } else {
                    // Walking newest→oldest, so `day` is always older than
                    // the existing run's start; widen the run accordingly.
                    pendingRestRun = (start: day,
                                      end: pendingRestRun!.end,
                                      count: pendingRestRun!.count + 1)
                }
            }
        }
        flushRestRun()

        return built
    }

    // MARK: - Side surfaces

    private var streakCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("This week").labelStyle()
                Text("\(weekSessionCount()) of \(store.profile.sessionsPerWeek)")
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundColor(Theme.Color.fg)
                Text("sessions logged · target \(store.profile.sessionsPerWeek)/wk")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
            }
            Spacer()
        }
        .padding(20)
        .card(padding: 0)
    }

    private var viewAllHistoryRow: some View {
        Button(action: { showFullHistory = true }) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Color.fgMute)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View all history")
                        .font(Theme.Font.sans(14, .medium))
                        .foregroundColor(Theme.Color.fg)
                    Text("\(store.history.count) session\(store.history.count == 1 ? "" : "s") logged · filter & search")
                        .font(Theme.Font.mono(11))
                        .foregroundColor(Theme.Color.fgSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Color.fgFaint)
            }
            .padding(16)
            .background(Theme.Color.bgElev1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Theme.Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Actions

    private func handleTap(_ row: TimelineRow) {
        switch row {
        case .completed(_, _, let session):
            sessionForDetail = session
        case .today, .planned, .restGap, .restSingle:
            // Today opens nothing here — Start lives on the Today tab and we
            // don't want Schedule competing as a launcher. Future planned
            // and rest rows are passive previews.
            break
        }
    }

    // MARK: - Helpers

    /// Mock "is this a planned training day?" predictor — spreads
    /// `sessionsPerWeek` across Mon-first weekdays. Real implementation
    /// will consult a recurring-schedule preference once we add one.
    private func shouldBePlanned(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sun…7=Sat
        let perWeek = max(1, min(7, store.profile.sessionsPerWeek))
        let order = [2, 3, 5, 4, 6, 7, 1] // Mon, Tue, Thu, Wed, Fri, Sat, Sun
        let training = Array(order.prefix(perWeek))
        return training.contains(weekday)
    }

    /// Sessions logged in the calendar week of today.
    private func weekSessionCount() -> Int {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return store.history.filter { interval.contains($0.date) }.count
    }
}

// MARK: - Timeline data model

/// One renderable row in the vertical timeline. Identifies itself with a
/// stable ID string so SwiftUI's `LazyVStack` can diff efficiently as the
/// user scrolls and as `store.history` updates.
enum TimelineRow: Identifiable {
    case completed(id: String, date: Date, session: CompletedSession)
    case today(id: String, date: Date, plan: SessionPlan, isPaired: Bool)
    case planned(id: String, date: Date, plan: SessionPlan, isPaired: Bool)
    /// Compressed run of rest days. `count` is the total days, `start`/`end`
    /// are the inclusive endpoints (start is older, end is newer).
    case restGap(id: String, count: Int, start: Date, end: Date)
    /// Single rest day rendered as a hairline divider — too short to compress
    /// into a "× 1 day off" card.
    case restSingle(id: String, date: Date)

    var id: String {
        switch self {
        case .completed(let id, _, _),
             .today(let id, _, _, _),
             .planned(let id, _, _, _),
             .restGap(let id, _, _, _),
             .restSingle(let id, _):
            return id
        }
    }
}

// MARK: - Timeline row view

/// One row of the timeline. Renders the left-side rail (vertical line + node)
/// in a fixed-width gutter so all cards align, and the day card to the right.
struct TimelineRailRow: View {
    var row: TimelineRow
    var partnerName: String
    var youName: String
    var onTap: (TimelineRow) -> Void

    /// Gutter width must stay in sync with the node size below; the rail
    /// line is centered in this column.
    private let gutterWidth: CGFloat = 38
    private let nodeSize: CGFloat = 12

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
            content
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
    }

    // MARK: rail

    private var rail: some View {
        ZStack(alignment: .top) {
            // Continuous spine — drawn full-height behind the node so
            // adjacent rows visually connect.
            Rectangle()
                .fill(Theme.Color.hairline)
                .frame(width: 1.5)
                .frame(maxHeight: .infinity)

            // Node sits at the top of the row, aligned with the card's
            // header text — feels like "this is when this thing happened."
            node
                .padding(.top, 14)
        }
        .frame(width: gutterWidth)
    }

    @ViewBuilder
    private var node: some View {
        switch row {
        case .completed:
            Circle()
                .fill(Theme.Color.you)
                .frame(width: nodeSize, height: nodeSize)
        case .today:
            // Bigger accent-tone disc with a soft halo so today reads as
            // the visual anchor when scrolling past it.
            ZStack {
                Circle()
                    .fill(Theme.Color.accent.opacity(0.25))
                    .frame(width: nodeSize + 10, height: nodeSize + 10)
                Circle()
                    .fill(Theme.Color.accent)
                    .frame(width: nodeSize + 2, height: nodeSize + 2)
            }
        case .planned:
            Circle()
                .strokeBorder(Theme.Color.you, lineWidth: 1.5)
                .frame(width: nodeSize, height: nodeSize)
        case .restGap, .restSingle:
            Circle()
                .fill(Theme.Color.fgFaint.opacity(0.6))
                .frame(width: 6, height: 6)
                .padding(.leading, (nodeSize - 6) / 2)
        }
    }

    // MARK: content

    @ViewBuilder
    private var content: some View {
        switch row {
        case .completed(_, let date, let session):
            Button(action: { onTap(row) }) {
                CompletedRowCard(date: date, session: session, partnerName: partnerName)
            }
            .buttonStyle(PressableStyle())

        case .today(_, _, let plan, let isPaired):
            TodayRowCard(plan: plan, isPaired: isPaired,
                         youName: youName, partnerName: partnerName)

        case .planned(_, let date, let plan, let isPaired):
            PlannedRowCard(date: date, plan: plan, isPaired: isPaired,
                           youName: youName, partnerName: partnerName)

        case .restGap(_, let count, let start, let end):
            RestGapRowCard(count: count, start: start, end: end)

        case .restSingle(_, let date):
            RestSingleRow(date: date)
        }
    }
}

// MARK: - Row cards

/// A logged session. Tappable → `SessionDetailSheet` (handled by the parent).
private struct CompletedRowCard: View {
    var date: Date
    var session: CompletedSession
    var partnerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(formattedDate(date).uppercased()).overlineStyle()
                Spacer()
                if session.prCount > 0 {
                    Text("★ \(session.prCount) PR")
                        .font(Theme.Font.mono(10, .medium))
                        .foregroundColor(Theme.Color.pr)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Theme.Color.prDim)
                        .clipShape(Capsule())
                }
            }
            Text(session.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.Color.fg)
            HStack(spacing: 8) {
                Text(durationString(session.durationSeconds))
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                Text("·").foregroundColor(Theme.Color.fgFaint)
                Text("\(session.you.count) ex")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                if !session.partnerTitle.isEmpty,
                   session.partnerTitle.caseInsensitiveCompare(session.title) != .orderedSame {
                    Text("·").foregroundColor(Theme.Color.fgFaint)
                    Text("\(partnerName): \(session.partnerTitle.lowercased())")
                        .font(Theme.Font.mono(11))
                        .foregroundColor(Theme.Color.partner)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.bgElev1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Color.hairline, lineWidth: 1)
        )
    }

    private func durationString(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Today's anchor card. Larger, accent-colored overline so it reads as the
/// "you are here" pin on the timeline.
private struct TodayRowCard: View {
    var plan: SessionPlan
    var isPaired: Bool
    var youName: String
    var partnerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY").overlineStyle(color: Theme.Color.accent)
                Spacer()
                Text("\(plan.durationMinutes) MIN · \(plan.youPlan.count) EX").labelStyle()
            }
            (Text(plan.title)
                .foregroundColor(Theme.Color.fg)
             + Text("\n" + plan.subtitle)
                .foregroundColor(Theme.Color.fgMute))
                .font(.system(size: 24, weight: .semibold))
                .kerning(-0.5)
                .lineSpacing(0)
            if isPaired && plan.themesDiverge {
                Text("\(partnerName): \(plan.partnerTitle.lowercased()) · \(plan.partnerDurationMinutes)m")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.partner)
            }
            Text("Open Today to start")
                .font(Theme.Font.mono(11, .medium))
                .tracking(0.5)
                .foregroundColor(Theme.Color.fgFaint)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Color.accent.opacity(0.4), lineWidth: 1.2)
        )
    }
}

/// A future planned session. Same overline-with-date pattern as completed,
/// but quieter visual weight (transparent background) so the focus stays on
/// today + recent history.
private struct PlannedRowCard: View {
    var date: Date
    var plan: SessionPlan
    var isPaired: Bool
    var youName: String
    var partnerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate(date).uppercased()).overlineStyle()
                Spacer()
                Text("PLANNED").labelStyle(color: Theme.Color.fgFaint)
            }
            Text(plan.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.Color.fg)
            HStack(spacing: 8) {
                Text("\(plan.durationMinutes) min")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                Text("·").foregroundColor(Theme.Color.fgFaint)
                Text("\(plan.youPlan.count) ex")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                if isPaired && plan.themesDiverge {
                    Text("·").foregroundColor(Theme.Color.fgFaint)
                    Text("\(partnerName): \(plan.partnerTitle.lowercased())")
                        .font(Theme.Font.mono(11))
                        .foregroundColor(Theme.Color.partner)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.bgElev1.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Color.hairline.opacity(0.6),
                              style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
    }
}

/// Compressed rest run — "× 4 days off · Mon → Thu". Renders short and
/// quiet so it reads as connective tissue, not a card.
private struct RestGapRowCard: View {
    var count: Int
    var start: Date
    var end: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.Color.fgFaint)
            Text("\(count) days off")
                .font(Theme.Font.mono(11, .medium))
                .foregroundColor(Theme.Color.fgSoft)
            Text("·").foregroundColor(Theme.Color.fgFaint)
            Text("\(shortDate(start))–\(shortDate(end))")
                .font(Theme.Font.mono(11))
                .foregroundColor(Theme.Color.fgFaint)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}

/// Tiny single rest-day spacer. No card chrome — keeps the rail unbroken
/// without adding visual weight.
private struct RestSingleRow: View {
    var date: Date

    var body: some View {
        HStack {
            Text("Rest day")
                .font(Theme.Font.mono(10.5))
                .foregroundColor(Theme.Color.fgFaint)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Date helpers

fileprivate func formattedDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE · MMM d"
    return f.string(from: date)
}
