import SwiftUI

/// Post-session summary. Renders the **just-completed** session — pulled
/// from `store.history.first` — as a hero card, a streak update, KPIs, and
/// a per-exercise breakdown. When the user is paired, the per-exercise
/// breakdown switches to a side-by-side view; solo runs render a single
/// column so we don't fake a partner that isn't there.
///
/// Nothing here is hardcoded. If `store.history.first` is `nil` (e.g. the
/// debug "Post-session" demo route triggered without an active session),
/// we render a minimal "no session yet" state rather than fabricating
/// numbers.
struct PostSessionView: View {
    var onDone: () -> Void
    @EnvironmentObject var store: SessionStore
    @State private var note: String = ""
    @FocusState private var noteFocused: Bool

    /// The session this screen is reporting on. We snapshot at appearance
    /// so a background refresh of `history` mid-render doesn't shuffle
    /// rows under us. `nil` only on the demo route.
    @State private var session: CompletedSession? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    if let s = session {
                        loaded(s)
                    } else {
                        empty
                    }
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }

            VStack {
                PrimaryCTA(title: "Done", trailingSystemImage: "checkmark", tall: true, action: onDone)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
            }
            .background(
                LinearGradient(colors: [Theme.Color.bg.opacity(0), Theme.Color.bg], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .onAppear {
            session = store.history.first
        }
    }

    // MARK: - States

    @ViewBuilder
    private func loaded(_ s: CompletedSession) -> some View {
        // Hero
        VStack(spacing: 6) {
            Text(heroOverline.uppercased()).overlineStyle(color: Theme.Color.accent)
            Text(formatDuration(s.durationSeconds))
                .font(.system(size: 64, weight: .semibold).monospacedDigit())
                .kerning(-2.6)
                .foregroundColor(Theme.Color.fg)
            Text(heroSubtitle(s)).labelStyle()
        }
        .padding(.top, 40)

        streakCard(s)

        KPIRow(kpis(for: s))

        HStack {
            Text(comparisonHeader.uppercased()).overlineStyle()
            Spacer()
        }
        .padding(.top, 8)

        VStack(spacing: 10) {
            ForEach(s.you) { ex in
                comparisonCard(for: ex, partner: matchingPartnerExercise(for: ex, in: s))
            }
        }

        // Reactions only make sense when there's a partner to send them to.
        if store.isPaired {
            reactionsRow
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 80)
            Text("Done".uppercased()).overlineStyle(color: Theme.Color.accent)
            Text("Nothing logged yet")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Theme.Color.fg)
            Text("Finish a session to see your summary here.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Hero copy

    /// Overline above the duration. "Done · in tempo" only makes sense
    /// when both partners trained on the same day — otherwise it's just
    /// "Done".
    private var heroOverline: String {
        if let s = session, !s.partnerTitle.isEmpty, store.isPaired {
            return "Done · in tempo"
        }
        return "Done"
    }

    /// Subtitle under the duration. Pulls from the real session title and
    /// drops the "· together" suffix when solo.
    private func heroSubtitle(_ s: CompletedSession) -> String {
        let trimmed = s.title.trimmingCharacters(in: .whitespaces)
        let title = trimmed.isEmpty ? "Session complete" : trimmed
        if !s.partnerTitle.isEmpty,
           store.isPaired,
           s.partnerTitle.lowercased() == s.title.lowercased() {
            // Both sides on the same theme — "· together" reads true.
            return "\(title) · together"
        }
        return title
    }

    /// Header above the per-exercise list. "Side-by-side" only when we
    /// actually have two columns to render.
    private var comparisonHeader: String {
        store.isPaired ? "Side-by-side" : "Your sets"
    }

    // MARK: - Streak

    @ViewBuilder
    private func streakCard(_ s: CompletedSession) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.Color.prDim)
                Image(systemName: "flame.fill").font(.system(size: 18)).foregroundColor(Theme.Color.pr)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(streakHeadline).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Text(streakSubtitle)
                    .font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
            }
            Spacer()
            if !streakDelta.isEmpty {
                Text(streakDelta)
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundColor(Theme.Color.fg)
            }
        }
        .card()
    }

    private var streakHeadline: String {
        let s = store.currentStreak
        return s == 0 ? "First session logged" : "\(s)-day streak"
    }

    private var streakSubtitle: String {
        let s = store.currentStreak
        switch s {
        case 0:        return "Welcome to Tempo — keep it rolling tomorrow"
        case 1:        return "Day one — every streak starts here"
        case 7, 14, 21, 30, 60, 90, 180, 365:
                       return "Milestone — \(s) days strong"
        default:       return "Keep it rolling tomorrow"
        }
    }

    private var streakDelta: String {
        store.currentStreak == 0 ? "" : "+1"
    }

    // MARK: - KPIs

    /// Real KPI strip computed from the actual completed session. We
    /// intentionally surface different KPIs solo vs. paired so we don't
    /// render an "8,650 · partner" tile when there's no partner.
    private func kpis(for s: CompletedSession) -> [(value: String, unit: String)] {
        let volume = totalVolume(s.you)
        let prCount = s.you.filter(\.isPR).count
        let activeMMSS = formatDurationCompact(s.durationSeconds)
        let unitsLabel = store.profile.units.weightUnit
        return [
            (value: formatVolume(volume), unit: "Volume \(unitsLabel) · you"),
            (value: "\(prCount)",         unit: prCount == 1 ? "PR hit" : "PRs hit"),
            (value: activeMMSS,           unit: "Active time"),
        ]
    }

    /// Sum of `weight × reps` over every non-skipped set. Bodyweight
    /// exercises (weight = 0) contribute zero to volume — that's the
    /// conventional definition. Cardio / stretching also contribute zero.
    private func totalVolume(_ exercises: [CompletedExercise]) -> Int {
        var v = 0
        for ex in exercises {
            for set in ex.sets where !set.skipped {
                v += set.reps * set.weight
            }
        }
        return v
    }

    // MARK: - Comparison

    /// Try to find the partner's analogue exercise in the same session
    /// snapshot. Currently `CompletedSession.partner` is empty in v1
    /// (partner data syncs as their own session record); when that
    /// changes this method automatically picks it up. Returns `nil`
    /// today, which makes the comparison card collapse to a single
    /// column.
    private func matchingPartnerExercise(
        for ex: CompletedExercise,
        in s: CompletedSession
    ) -> CompletedExercise? {
        // Match by catalog id first, then by name as a fallback.
        if let m = s.partner.first(where: { $0.catalogId == ex.catalogId }) {
            return m
        }
        return s.partner.first { $0.name.caseInsensitiveCompare(ex.name) == .orderedSame }
    }

    private func comparisonCard(
        for ex: CompletedExercise,
        partner partnerEx: CompletedExercise?
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(ex.name).font(Theme.Font.sans(14, .medium)).foregroundColor(Theme.Color.fg)
                if ex.isPR {
                    Text("★ Personal record")
                        .font(Theme.Font.mono(10, .medium))
                        .foregroundColor(Theme.Color.pr)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.Color.prDim)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Color.bgElev2)

            // Render two columns when we have real partner data, one
            // when we're solo or partner data didn't sync yet. Faking a
            // second column with placeholder strings would just lie.
            if store.isPaired, let partnerEx, !partnerEx.sets.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    column(label: store.profile.youLabel,
                           color: Theme.Color.you,
                           lines: setLines(for: ex))
                    Rectangle().fill(Theme.Color.hairline).frame(width: 1)
                    column(label: store.partner.name,
                           color: Theme.Color.partner,
                           lines: setLines(for: partnerEx))
                }
            } else {
                column(label: store.profile.youLabel,
                       color: Theme.Color.you,
                       lines: setLines(for: ex))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card(padding: 0)
    }

    /// Per-set summary text, "Set N · reps × weight" style. Bodyweight
    /// drops the weight, timed holds use seconds, and skipped sets are
    /// rendered as "Set N · skipped" rather than fabricating numbers.
    private func setLines(for ex: CompletedExercise) -> [String] {
        guard !ex.sets.isEmpty else { return ["No sets logged"] }
        let resolved = ExerciseCatalog.resolve(ex.catalogId, with: store.profile.customExercises)
        let kind = resolved?.kind ?? .strength
        return ex.sets.enumerated().map { idx, set in
            let n = idx + 1
            if set.skipped {
                return "Set \(n) · skipped"
            }
            switch kind {
            case .strength:
                return set.weight > 0
                    ? "Set \(n) · \(set.reps) × \(set.weight)"
                    : "Set \(n) · \(set.reps) reps"
            case .bodyweight:
                return "Set \(n) · \(set.reps) reps"
            case .timedHold:
                return "Set \(n) · \(set.reps)s"
            case .stretching:
                let mm = set.reps / 60
                let ss = set.reps % 60
                return mm > 0
                    ? "Set \(n) · \(mm)m \(String(format: "%02ds", ss))"
                    : "Set \(n) · \(set.reps)s"
            case .distance, .timeBased, .mobility:
                return set.weight > 0
                    ? "Set \(n) · \(set.reps) × \(set.weight)"
                    : "Set \(n) · \(set.reps)"
            }
        }
    }

    private func column(label: String, color: Color, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).labelStyle(color: color)
            ForEach(lines, id: \.self) { v in
                Text(v).font(Theme.Font.mono(12)).foregroundColor(Theme.Color.fg)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reactions

    private var reactionsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send \(store.partner.name) a reaction".uppercased()).overlineStyle()
            HStack(spacing: 6) {
                ForEach(["💪","🔥","👏","😮‍💨"], id: \.self) { e in
                    Button(action: { sendReaction(e) }) {
                        Text(e)
                            .font(.system(size: 18))
                            .frame(width: 44, height: 36)
                            .background(Theme.Color.bgElev2)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
                TextField("", text: $note,
                          prompt: Text("Type a note…").foregroundColor(Theme.Color.fgSoft))
                    .font(Theme.Font.sans(13))
                    .foregroundColor(Theme.Color.fg)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Theme.Color.bgElev2)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
                    .focused($noteFocused)
                    .submitLabel(.send)
                    .onSubmit(sendNote)
            }
        }
    }

    private func sendReaction(_ emoji: String) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        store.showToast("Sent \(emoji) to \(store.partner.name)", icon: "paperplane.fill")
    }

    private func sendNote() {
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.showToast("Note sent to \(store.partner.name)", icon: "paperplane.fill")
        note = ""
        noteFocused = false
    }

    // MARK: - Formatting

    /// Format duration as `mm:ss` for shorter sessions, `hh:mm:ss` once
    /// we cross an hour. Hero needs the bigger format because lifters
    /// regularly hit 60–90 min.
    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// Same logic but always `mm:ss` for the KPI strip (more compact in
    /// the smaller font).
    private func formatDurationCompact(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Comma-grouped weight number, e.g. 8650 → "8,650". Uses the
    /// device's locale so European users see "8.650" naturally.
    private func formatVolume(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}
