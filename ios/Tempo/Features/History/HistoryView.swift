import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: SessionStore

    @State private var filter: String = "All"
    @State private var sessionForDetail: CompletedSession? = nil
    @State private var showFilterSheet = false
    private let filters = ["All", "★ PR only", "Strength", "Cardio", "This month"]

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "History",
                dateLine: nil,
                trailing: AnyView(IconButton(systemName: "line.3.horizontal.decrease") {
                    showFilterSheet = true
                })
            )
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 18) {
                        KPI(value: "\(store.history.count)", unit: "Sessions · all time", valueSize: 28)
                        Rectangle().fill(Theme.Color.hairline).frame(width: 1, height: 30)
                        KPI(value: totalTimeString(), unit: "Together", valueSize: 28)
                        Spacer()
                    }
                    .padding(20)
                    .card(padding: 0)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { f in
                                Button(action: { filter = f }) {
                                    Text(f)
                                        .font(Theme.Font.mono(11, .medium))
                                        .tracking(0.5)
                                        .foregroundColor(filter == f ? Theme.Color.fg : Theme.Color.fgMute)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(filter == f ? Theme.Color.bgElev2 : Color.clear)
                                        .overlay(
                                            Capsule().strokeBorder(filter == f ? Theme.Color.border : Theme.Color.hairline, lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    let filtered = applyFilter(store.history)
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        let grouped = Dictionary(grouping: filtered, by: weekGroupLabel)
                        let order = grouped.keys.sorted { groupOrder($0) < groupOrder($1) }

                        ForEach(order, id: \.self) { group in
                            VStack(spacing: 8) {
                                SectionHead(
                                    title: group,
                                    meta: "\(grouped[group]?.count ?? 0) sessions · \(grouped[group]?.reduce(0) { $0 + $1.prCount } ?? 0) PR"
                                )
                                .padding(.top, 4)
                                ForEach(grouped[group] ?? []) { entry in
                                    Button(action: { sessionForDetail = entry }) {
                                        HistoryRow(entry: entry, partnerName: store.partner.name, paired: store.isPaired)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }
        .sheet(item: $sessionForDetail) { session in
            SessionDetailSheet(session: session, partnerName: store.partner.name, paired: store.isPaired)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(current: $filter, options: filters) {
                showFilterSheet = false
            }
            .presentationDetents([.fraction(0.45)])
            .presentationBackground(Theme.Color.bgElev1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundColor(Theme.Color.fgFaint)
            Text("No sessions logged yet")
                .font(Theme.Font.sans(15, .medium))
                .foregroundColor(Theme.Color.fgMute)
            Text("Start a session from Today to see it here.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    private func totalTimeString() -> String {
        let secs = store.history.reduce(0) { $0 + $1.durationSeconds }
        let mins = secs / 60
        return mins < 60 ? "\(mins)m" : "\(mins/60)h \(String(format: "%02dm", mins%60))"
    }

    private func applyFilter(_ sessions: [CompletedSession]) -> [CompletedSession] {
        switch filter {
        case "★ PR only": return sessions.filter { $0.prCount > 0 }
        case "Strength":  return sessions   // could refine by exercise kind
        case "Cardio":    return []         // none yet
        case "This month":
            return sessions.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        default: return sessions
        }
    }

    private func weekGroupLabel(_ s: CompletedSession) -> String {
        let cal = Calendar.current
        if cal.isDate(s.date, equalTo: Date(), toGranularity: .weekOfYear) { return "This week" }
        if let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: Date()),
           cal.isDate(s.date, equalTo: lastWeek, toGranularity: .weekOfYear) { return "Last week" }
        let f = DateFormatter(); f.dateFormat = "MMMM"
        return f.string(from: s.date)
    }

    private func groupOrder(_ s: String) -> Int {
        switch s {
        case "This week": return 0
        case "Last week": return 1
        default: return 2
        }
    }
}

private struct HistoryRow: View {
    var entry: CompletedSession
    var partnerName: String
    var paired: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(dayString).font(.system(size: 20, weight: .semibold).monospacedDigit()).foregroundColor(Theme.Color.fg)
                Text(monthString.uppercased()).font(Theme.Font.mono(9, .medium)).tracking(0.8).foregroundColor(Theme.Color.fgSoft)
            }
            .frame(width: 48, height: 48)
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Color.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(Theme.Font.sans(15, .medium)).foregroundColor(Theme.Color.fg)
                HStack(spacing: 6) {
                    Text(durationString).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                    Text("·").foregroundColor(Theme.Color.fgFaint)
                    Text("\(entry.you.count) ex").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                    if paired {
                        Text("·").foregroundColor(Theme.Color.fgFaint)
                        // When the pair was on different programs, name what
                        // the partner was doing instead of the generic
                        // "You + X" — preserves the social signal but tells
                        // the more interesting story.
                        if showsDivergence {
                            Text("\(partnerName): \(entry.partnerTitle.lowercased())")
                                .font(Theme.Font.mono(11))
                                .foregroundColor(Theme.Color.partner)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("You + \(partnerName)").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.you)
                        }
                    }
                }
            }
            Spacer()
            if entry.prCount > 0 {
                Text("★ \(entry.prCount)")
                    .font(Theme.Font.mono(11, .medium))
                    .foregroundColor(Theme.Color.pr)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.Color.prDim)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
        }
        .padding(14)
        .background(Theme.Color.bgElev1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }

    /// True when this entry has a partner title and it materially differs
    /// from the user's. Cheap string check — full muscle-group overlap math
    /// lives on `SessionPlan` and isn't worth re-deriving from a finished row.
    private var showsDivergence: Bool {
        guard !entry.partnerTitle.isEmpty else { return false }
        return entry.partnerTitle.caseInsensitiveCompare(entry.title) != .orderedSame
    }

    private var dayString: String {
        let f = DateFormatter(); f.dateFormat = "dd"; return f.string(from: entry.date)
    }
    private var monthString: String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: entry.date)
    }
    private var durationString: String {
        let m = entry.durationSeconds / 60, s = entry.durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Session detail sheet

struct SessionDetailSheet: View {
    let session: CompletedSession
    let partnerName: String
    let paired: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formattedDate(session.date).uppercased()).overlineStyle()
                    Text(session.title)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(Theme.Color.fg)
                    HStack(spacing: 8) {
                        Text(durationString).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                        Text("·").foregroundColor(Theme.Color.fgFaint)
                        Text("\(session.you.count) exercises").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                        if session.prCount > 0 {
                            Text("·").foregroundColor(Theme.Color.fgFaint)
                            Text("★ \(session.prCount) PR")
                                .font(Theme.Font.mono(11, .medium))
                                .foregroundColor(Theme.Color.pr)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your sets".uppercased()).overlineStyle()
                    VStack(spacing: 10) {
                        ForEach(session.you) { ex in
                            exerciseCard(ex)
                        }
                    }
                }

                if paired && !session.partner.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(partnerName)'s sets".uppercased()).overlineStyle()
                        VStack(spacing: 10) {
                            ForEach(session.partner) { ex in
                                exerciseCard(ex)
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .background(Theme.Color.bgElev1)
    }

    private func exerciseCard(_ ex: CompletedExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ex.name).font(Theme.Font.sans(15, .medium)).foregroundColor(Theme.Color.fg)
                if ex.isPR {
                    Text("★ PR")
                        .font(Theme.Font.mono(10, .medium))
                        .foregroundColor(Theme.Color.pr)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Theme.Color.prDim)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(ex.sets.enumerated()), id: \.offset) { idx, set in
                    HStack {
                        Text(isStretch(ex) ? "Stretch" : "Set \(idx + 1)")
                            .font(Theme.Font.mono(11))
                            .foregroundColor(Theme.Color.fgSoft)
                            .frame(width: 60, alignment: .leading)
                        Text(formatSet(set, isStretch: isStretch(ex)))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundColor(Theme.Color.fg)
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.bgElev2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }

    private var durationString: String {
        let m = session.durationSeconds / 60, s = session.durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE · MMM d, yyyy"
        return f.string(from: d)
    }

    /// Detect stretching entries from completed history. Catalog id prefix
    /// is the cheap discriminator for ad-hoc stretches; for custom-defined
    /// stretching exercises we'd need to consult the user's library, but
    /// that's a profile/store dependency we don't carry into this sheet —
    /// good enough for the common case.
    private func isStretch(_ ex: CompletedExercise) -> Bool {
        ex.catalogId.hasPrefix("stretch_")
    }

    /// Render one logged set. Stretching uses `reps` to store seconds, so we
    /// format as mm:ss instead of "N reps".
    private func formatSet(_ set: CompletedSet, isStretch: Bool) -> String {
        if isStretch {
            let s = set.reps
            return String(format: "%d:%02d", s / 60, s % 60)
        }
        return set.weight > 0 ? "\(set.reps) × \(set.weight) lb" : "\(set.reps) reps"
    }
}

// MARK: - Filter sheet

private struct FilterSheet: View {
    @Binding var current: String
    let options: [String]
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filter").font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Spacer()
                Button("Done", action: onDone)
                    .font(Theme.Font.sans(14, .semibold))
                    .foregroundColor(Theme.Color.accent)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(options, id: \.self) { opt in
                    Button(action: { current = opt; onDone() }) {
                        HStack {
                            Text(opt).font(Theme.Font.sans(15)).foregroundColor(Theme.Color.fg)
                            Spacer()
                            if current == opt {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Color.accent)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if opt != options.last { Divider().background(Theme.Color.hairline) }
                }
            }
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
