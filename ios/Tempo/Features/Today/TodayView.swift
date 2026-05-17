import SwiftUI

/// Today screen — entry-point with three states. Reads live plan from SessionStore.
struct TodayView: View {
    var onStart: () -> Void = {}
    var onPR: () -> Void = {}
    var onPost: () -> Void = {}
    var onOnboarding: () -> Void = {}

    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "Today",
                dateLine: dateLine(),
                trailing: AnyView(partnerTrailing)
            )
            .padding(.top, 8)

            // Demo-only state switcher. Release derives the state from
            // `store.recomputeTodayState()` (active session in progress?
            // session already done today? scheduled rest day?), so the
            // picker would just be a confusing god-mode toggle for
            // external testers. Internal builds keep it for debugging.
            #if DEBUG
            StatePicker(selection: $store.todayState)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
            #endif

            ScrollView {
                VStack(spacing: 16) {
                    switch store.todayState {
                    case .ready:
                        SessionReadyState(
                            plan: store.todayPlan,
                            youName: store.profile.youLabel,
                            partner: store.partner,
                            isPaired: store.isPaired,
                            partnerActivity: store.partnerActivity,
                            streakDays: store.currentStreak,
                            lastTogether: store.lastTogetherSession,
                            onStart: onStart
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    case .inProgress:
                        SessionInProgressState(
                            partnerName: store.partner.name,
                            firstUp: store.todayPlan.youPlan.first,
                            onJoin: onStart
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    case .rest:
                        RestDayState(history: store.history, partner: store.partner)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // Internal-only shortcuts to non-default flows (PR
                    // moment, post-session, onboarding replay). Hidden
                    // from Release builds so external TestFlight users
                    // never see the "Demo routes" header.
                    #if DEBUG
                    DemoActionsRow(onPR: onPR, onPost: onPost, onOnboarding: onOnboarding)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    #endif
                }
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var partnerTrailing: some View {
        if store.isPaired {
            PartnerPip(partner: Partner(name: store.partner.name, initial: store.partner.initial, online: store.partner.online))
        } else {
            Button(action: onOnboarding) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 12, weight: .medium))
                    Text("Pair up").font(Theme.Font.sans(12, .medium))
                }
                .foregroundColor(Theme.Color.fgMute)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Color.bgElev1)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
            }
        }
    }

    private func dateLine() -> String {
        let f = DateFormatter(); f.dateFormat = "EEE · MMM d"
        return f.string(from: Date())
    }
}

// MARK: - State picker

private struct StatePicker: View {
    @Binding var selection: TodayState
    var body: some View {
        HStack(spacing: 4) {
            pill("Ready", on: selection == .ready)       { selection = .ready }
            pill("In progress", on: selection == .inProgress) { selection = .inProgress }
            pill("Rest day", on: selection == .rest)     { selection = .rest }
        }
        .padding(4)
        .background(Theme.Color.bgElev2)
        .clipShape(Capsule())
    }

    private func pill(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.mono(10.5, .medium))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundColor(on ? Theme.Color.fg : Theme.Color.fgFaint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? Theme.Color.bg : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - State A: Session Ready

private struct SessionReadyState: View {
    let plan: SessionPlan
    let youName: String
    let partner: PartnerProfile
    let isPaired: Bool
    /// Live partner activity (from the realtime channel) — when non-nil
    /// the ready state shows a "currently working out" banner that
    /// displaces the regular presence line.
    let partnerActivity: PartnerActivity?
    /// Real consecutive-day workout streak (computed from `store.history`).
    /// Passed in instead of read here so this view stays free of
    /// `@EnvironmentObject` plumbing.
    let streakDays: Int
    /// Most recent session that snapshotted a partner title — drives the
    /// "Last together" card. `nil` when solo or no shared session yet.
    let lastTogether: CompletedSession?
    var onStart: () -> Void

    @State private var showPlanSheet = false

    var body: some View {
        VStack(spacing: 16) {
            // Hero card
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today's session".uppercased()).overlineStyle()
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(plan.durationMinutes) MIN").labelStyle()
                        Text("·").labelStyle(color: Theme.Color.fgFaint)
                        Text("\(plan.youPlan.count) EX").labelStyle()
                    }
                }

                (Text(plan.title)
                    .foregroundColor(Theme.Color.fg)
                 + Text("\n" + plan.subtitle)
                    .foregroundColor(Theme.Color.fgMute))
                    .font(.system(size: 36, weight: .semibold))
                    .kerning(-0.8)
                    .lineSpacing(0)

                // When the partner is *currently* training, surface that
                // first — it's the highest-signal thing on this screen
                // and overrides both the divergent-plan banner and the
                // "both ready" presence line below.
                if isPaired, let activity = partnerActivity {
                    PartnerLiveBanner(partnerName: partner.name, activity: activity)
                } else if isPaired && plan.themesDiverge {
                    divergentPartnerLine
                }

                HStack(spacing: 8) {
                    Avatar(initial: youName.first.map(String.init)?.uppercased() ?? "Y", size: 22, tone: .you)
                    if isPaired {
                        Avatar(initial: partner.initial, size: 22, tone: .partner)
                        Text(presenceLine).labelStyle().padding(.leading, 4)
                    } else {
                        Text("Solo session · pair up to sync").labelStyle().padding(.leading, 4)
                    }
                }

                PrimaryCTA(title: "Start Session", trailingSystemImage: "play.fill", action: onStart)
            }
            .padding(24)
            .card(padding: 0)

            // Plan preview — two-column side-by-side
            if isPaired && !plan.partnerPlan.isEmpty {
                VStack(spacing: 0) {
                    planHeader(showViewAll: true)

                    Divider().background(Theme.Color.hairline)

                    HStack(alignment: .top, spacing: 0) {
                        planColumn(
                            label: youName,
                            color: Theme.Color.you,
                            items: plan.youPlan,
                            theme: plan.themesDiverge ? "\(plan.title) · \(plan.durationMinutes)m" : nil
                        )
                        Rectangle().fill(Theme.Color.hairline).frame(width: 1)
                        planColumn(
                            label: partner.name,
                            color: Theme.Color.partner,
                            items: plan.partnerPlan,
                            theme: plan.themesDiverge ? "\(plan.partnerTitle) · \(plan.partnerDurationMinutes)m" : nil
                        )
                    }
                }
                .card(padding: 0)
            } else {
                // Solo: single column
                VStack(alignment: .leading, spacing: 0) {
                    planHeader(showViewAll: true)
                    Divider().background(Theme.Color.hairline)
                    planColumn(label: youName, color: Theme.Color.you, items: plan.youPlan, theme: nil)
                }
                .card(padding: 0)
            }

            // Streak + last-together
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").font(.system(size: 10)).foregroundColor(Theme.Color.pr)
                        Text("Streak").labelStyle()
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(streakDays)")
                            .font(.system(size: 32, weight: .semibold).monospacedDigit())
                            .foregroundColor(Theme.Color.fg)
                        Text(streakDays == 1 ? "day" : "days").labelStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(tight: true)

                lastTogetherCard
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(tight: true)
            }
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanSheet(plan: plan,
                      currentExerciseIndex: 0,
                      isPaired: isPaired,
                      partnerName: partner.name,
                      youName: youName)
                .presentationDetents([.fraction(0.78), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.bgElev1)
        }
    }

    /// "Last together" card content. Three states:
    ///
    ///   • Real shared session in history → title + "<weekday> · N PRs".
    ///   • Paired but no shared sessions yet → "Not yet · invite them to start".
    ///   • Solo (no partner) → the card is suppressed at the call site by
    ///     this builder rendering an empty placeholder so the streak card
    ///     fills the row width consistently.
    @ViewBuilder
    private var lastTogetherCard: some View {
        if let s = lastTogether {
            VStack(alignment: .leading, spacing: 10) {
                Text("Last together").labelStyle()
                Text(s.title)
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fg)
                    .lineLimit(1)
                Text("\(weekdayLabel(for: s.date)) · \(s.prCount) PR\(s.prCount == 1 ? "" : "s")")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                    .padding(.top, 2)
            }
        } else if isPaired {
            VStack(alignment: .leading, spacing: 10) {
                Text("Last together").labelStyle()
                Text("Not yet")
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fg)
                Text("complete a session to fill this in")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                    .padding(.top, 2)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Solo run").labelStyle()
                Text("Just you")
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fg)
                Text("invite a partner from Profile")
                    .font(Theme.Font.mono(11))
                    .foregroundColor(Theme.Color.fgSoft)
                    .padding(.top, 2)
            }
        }
    }

    /// "Today", "Yesterday", or the short weekday name (e.g. "Sun") for
    /// dates inside the last week; otherwise a `MMM d` short form.
    private func weekdayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let now = Date()
        let daysAgo = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        let f = DateFormatter()
        f.dateFormat = (0..<7).contains(daysAgo) ? "EEE" : "MMM d"
        return f.string(from: date)
    }

    private func planHeader(showViewAll: Bool) -> some View {
        Button(action: { showPlanSheet = true }) {
            HStack {
                Text("Today's plan".uppercased()).overlineStyle()
                Spacer()
                if showViewAll {
                    HStack(spacing: 4) {
                        Text("View all").font(Theme.Font.mono(10.5, .medium)).foregroundColor(Theme.Color.fgMute)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.Color.fgMute)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func planColumn(label: String, color: Color, items: [ExercisePlan], theme: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).labelStyle(color: color)
            }

            // Show the side's own theme + duration when the pair is on
            // different programs. Hidden in the goal-aligned case so we don't
            // repeat the giant title above twice.
            if let theme {
                Text(theme.uppercased())
                    .font(Theme.Font.mono(10, .medium))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.fgFaint)
                    .padding(.bottom, 2)
            }

            ForEach(items) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.name).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fg)
                    Text(e.meta).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Compact secondary line on the hero card showing the partner's
    /// alternate theme + duration. We dropped the "INDEPENDENT" chip that
    /// used to lead this row — the partner name + theme already tells the
    /// story, and the chip was framing furniture that read as engineer-speak.
    private var divergentPartnerLine: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.Color.partner).frame(width: 6, height: 6)
            Text("\(partner.name): \(plan.partnerTitle.lowercased()) · \(plan.partnerDurationMinutes)m")
                .font(Theme.Font.sans(13, .medium))
                .foregroundColor(Theme.Color.partner)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Color.partnerDim)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    /// Replaces the static "in tempo · both ready" label so the copy reads
    /// honestly when the pair is on different programs *or* when one of
    /// us is already mid-session (partner activity comes from the
    /// realtime channel; we surface a fuller banner above and shorten
    /// this line to a one-word state).
    private var presenceLine: String {
        if partnerActivity != nil { return "Partner training now" }
        return "In tempo · both ready"
    }
}

/// Compact "Alex is mid-session right now" banner. Replaces the
/// divergent-plan banner whenever the partner is actively working out
/// (i.e. they have a row in `public.live_sessions`).
private struct PartnerLiveBanner: View {
    let partnerName: String
    let activity: PartnerActivity

    var body: some View {
        HStack(spacing: 10) {
            PulsingDot()
            VStack(alignment: .leading, spacing: 2) {
                Text("\(partnerName.isEmpty ? "Partner" : partnerName) training now"
                    .uppercased())
                    .font(Theme.Font.mono(10, .medium))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.accent)
                Text(activity.compactStatus)
                    .font(Theme.Font.sans(13, .medium))
                    .foregroundColor(Theme.Color.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Text("\(activity.progressPct)%")
                .font(Theme.Font.mono(13, .medium).monospacedDigit())
                .foregroundColor(Theme.Color.fg)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.Color.accentDim)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Color.accent.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - State B: Session in progress

private struct SessionInProgressState: View {
    var partnerName: String
    var firstUp: ExercisePlan?
    var onJoin: () -> Void

    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    PulsingDot()
                    Text("Session live").overlineStyle(color: Theme.Color.accent)
                    Spacer()
                    Text("12:04 elapsed").labelStyle().monospacedDigit()
                }

                (Text("\(partnerName) set\n").foregroundColor(Theme.Color.fg)
                 + Text("the tempo.").foregroundColor(Theme.Color.accent))
                    .font(.system(size: 28, weight: .semibold))
                    .kerning(-0.6)
                    .lineSpacing(0)

                VStack(spacing: 14) {
                    progressRow(label: store.profile.youLabel, color: Theme.Color.you, value: 0, meta: "not started")
                    if let act = store.partnerActivity {
                        progressRow(
                            label: partnerName,
                            color: Theme.Color.partner,
                            value: Double(act.progressPct),
                            meta: act.compactStatus
                        )
                    } else {
                        progressRow(
                            label: partnerName,
                            color: Theme.Color.partner,
                            value: 0,
                            meta: "not started"
                        )
                    }
                }

                PrimaryCTA(title: "Join Session", trailingSystemImage: "arrow.right", action: onJoin)
            }
            .padding(22)
            .card(padding: 0)

            if let first = firstUp {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your first up".uppercased()).overlineStyle()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(first.name).font(.system(size: 20, weight: .semibold)).foregroundColor(Theme.Color.fg)
                            Text(first.meta).font(Theme.Font.mono(12)).foregroundColor(Theme.Color.fgSoft)
                        }
                        Spacer()
                        DemoTile()
                    }
                }
                .card(tight: true)
            }

            SecondaryCTA(title: "Skip warm-up · jump in cold") {
                store.showToast("Skipping warm-up — joining cold", icon: "bolt.fill")
                onJoin()
            }
        }
    }

    private func progressRow(label: String, color: Color, value: Double, meta: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).labelStyle(color: color)
                Spacer()
                Text(meta).font(Theme.Font.mono(12)).foregroundColor(Theme.Color.fgMute)
            }
            ProgressStrip(value: value / 100, color: color)
        }
    }
}

private struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.Color.accent)
            .frame(width: 8, height: 8)
            .overlay(
                Circle().fill(Theme.Color.accentDim).scaleEffect(on ? 2.4 : 1.4).opacity(on ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true }
            }
    }
}

private struct DemoTile: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12),
                         with: .color(Theme.Color.bgElev3))
                let stripe = Theme.Color.bgElev2
                var p = Path()
                let step: CGFloat = 12
                let n = Int(size.width / step) + Int(size.height / step) + 2
                for i in 0..<n {
                    let x = CGFloat(i) * step
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x - size.height, y: size.height))
                }
                ctx.clip(to: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12))
                ctx.stroke(p, with: .color(stripe), lineWidth: 6)
            }
            Text("DEMO")
                .font(Theme.Font.mono(9, .medium))
                .tracking(1)
                .foregroundColor(Theme.Color.fgFaint)
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - State C: Rest day

private struct RestDayState: View {
    var history: [CompletedSession]
    var partner: PartnerProfile

    @EnvironmentObject var store: SessionStore
    @State private var sessionForDetail: CompletedSession? = nil

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today".uppercased()).overlineStyle()
                (Text("Rest day.\n").foregroundColor(Theme.Color.fg)
                 + Text("Recover well.").foregroundColor(Theme.Color.fgMute))
                    .font(.system(size: 32, weight: .semibold))
                    .kerning(-0.7)
                    .lineSpacing(0)

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 11)).foregroundColor(Theme.Color.pr)
                    Text(restDayStreakLine(streak: store.currentStreak))
                        .font(Theme.Font.mono(12))
                        .foregroundColor(Theme.Color.fgMute)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .card(padding: 0)

            VStack(alignment: .leading, spacing: 14) {
                Text("This week, together".uppercased()).overlineStyle()
                KPIRow([
                    (value: "\(history.count)",                                  unit: "Sessions"),
                    (value: totalActive(),                                       unit: "Active"),
                    (value: "\(history.reduce(0) { $0 + $1.prCount })",          unit: "PRs"),
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .card(padding: 0)

            if !history.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Recent activity".uppercased()).overlineStyle()
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 6)

                    VStack(spacing: 0) {
                        ForEach(history.prefix(5)) { s in
                            Button(action: { sessionForDetail = s }) {
                                ActivityRow(
                                    color: Theme.Color.you,
                                    title: s.title,
                                    meta: "\(s.you.first?.name ?? "—") · \(timeAgo(s.date))",
                                    pr: s.prCount > 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .card(padding: 0)
            }

            SecondaryCTA(title: "Plan an extra session", leadingSystemImage: "plus") {
                store.regenerateTodayPlan()
                store.todayState = .ready
                store.showToast("Extra session added to Today", icon: "calendar.badge.plus")
            }
        }
        .sheet(item: $sessionForDetail) { session in
            SessionDetailSheet(session: session, partnerName: store.partner.name, paired: store.isPaired)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.Color.bgElev1)
        }
    }

    private func totalActive() -> String {
        let totalSec = history.reduce(0) { $0 + $1.durationSeconds }
        let m = totalSec / 60
        return m < 60 ? "\(m)m" : "\(m/60)h \(m%60)m"
    }

    private func timeAgo(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: d)
    }

    /// Streak line on the rest-day card. Three shapes:
    ///
    ///   • Active streak ("5-day streak — keep it going").
    ///   • Streak just lapsed (`history` non-empty but `streak == 0`):
    ///     "Recover well" framing — no number to broadcast.
    ///   • No history at all: a welcoming first-session prompt.
    private func restDayStreakLine(streak: Int) -> String {
        if streak > 0 {
            return "\(streak)-day streak — keep it rolling"
        }
        if history.isEmpty {
            return "Your first session is on the schedule"
        }
        return "Recovery day — fresh start tomorrow"
    }
}

private struct ActivityRow: View {
    var color: Color
    var title: String
    var meta: String
    var pr: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                Text(meta).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
            }
            Spacer()
            if pr {
                Text("PR")
                    .font(Theme.Font.mono(10, .medium))
                    .tracking(0.7)
                    .foregroundColor(Theme.Color.pr)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.Color.prDim)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
    }
}

// MARK: - Demo routes row

private struct DemoActionsRow: View {
    var onPR: () -> Void
    var onPost: () -> Void
    var onOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Demo routes".uppercased()).overlineStyle(color: Theme.Color.fgFaint)
            HStack(spacing: 10) {
                SecondaryCTA(title: "PR moment", action: onPR)
                SecondaryCTA(title: "Post-session", action: onPost)
            }
            SecondaryCTA(title: "Replay onboarding", action: onOnboarding)
        }
        .padding(.top, 8)
    }
}
