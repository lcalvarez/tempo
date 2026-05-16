import SwiftUI

/// Active session — strength · between sets. Records real sets to history,
/// detects PRs against the user's all-time best, and triggers the PR moment.
struct ActiveSessionView: View {
    var onClose: () -> Void
    var onPR: (String, Int, Int) -> Void   // exercise name, reps, weight
    var onComplete: () -> Void

    @EnvironmentObject var store: SessionStore

    @State private var exerciseIndex: Int = 0
    @State private var currentSet: Int = 1
    @State private var sessionStart = Date()
    @State private var elapsedText = "00:00"
    @State private var showPlanSheet = false
    @State private var showAdjustSheet = false
    @State private var showAddSheet = false

    /// Live, editable reps/weight for the current set. Seeded from the plan
    /// when the exercise/set changes; persists user edits until they log.
    @State private var liveReps: Int = 0
    @State private var liveWeight: Int = 0

    /// Stopwatch state for `.stretching` exercises. `liveStretchSeconds` is
    /// the elapsed value the user is about to log; running/start time drive
    /// the visible mm:ss countup. Reset on exercise/set change.
    @State private var liveStretchSeconds: Int = 0
    @State private var stretchRunning: Bool = false
    @State private var stretchStart: Date? = nil

    /// Per-exercise overrides for sets/reps/weight (when the user uses Adjust).
    @State private var planOverrides: [Int: ExercisePlan] = [:]

    /// Logged sets, per exercise index.
    @State private var loggedSets: [Int: [CompletedSet]] = [:]
    @State private var prFlaggedExercises: Set<Int> = []

    private var plan: SessionPlan { store.todayPlan }
    private var currentExercise: ExercisePlan? {
        guard plan.youPlan.indices.contains(exerciseIndex) else { return nil }
        return planOverrides[exerciseIndex] ?? plan.youPlan[exerciseIndex]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                ActiveTopBar(
                    elapsed: elapsedText,
                    current: exerciseIndex + 1,
                    total: plan.youPlan.count,
                    partner: Partner(name: store.partner.name, initial: store.partner.initial, online: store.partner.online),
                    isPaired: store.isPaired,
                    onClose: onClose
                )
                .padding(.top, 4)

                ScrollView {
                    VStack(spacing: 18) {
                        if store.isPaired {
                            // Independent-mode pill — only when the two
                            // sides are on different programs today. Keeps
                            // the planner's posture transparent at a glance.
                            if plan.themesDiverge {
                                divergenceBanner
                            }

                            DualProgress(
                                youPct: youProgressPct,
                                partnerPct: store.partnerProgressPct,
                                youName: store.profile.youLabel,
                                partnerName: store.partner.name,
                                youMeta: youProgressMeta,
                                partnerMeta: partnerProgressMeta
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Progress").labelStyle(color: Theme.Color.you)
                                    Spacer()
                                    Text("\(Int(youProgressPct))%").monoNumeric(11).foregroundColor(Theme.Color.fgSoft)
                                }
                                ProgressStrip(value: youProgressPct / 100, color: Theme.Color.you)
                            }
                        }

                        if let ex = currentExercise {
                            VStack(spacing: 6) {
                                if ex.kind.isStopwatch {
                                    Text(ex.name).labelStyle()
                                } else {
                                    Text("Set \(currentSet) of \(ex.sets) · \(ex.name)").labelStyle()
                                }
                            }
                            .padding(.top, 4)

                            if ex.kind.isStopwatch {
                                // Stretching mode — open stopwatch, no
                                // prescribed sets/reps. Tap to start; tap
                                // again to pause; "Log stretch" persists.
                                StretchHero(
                                    seconds: liveStretchSeconds,
                                    running: stretchRunning,
                                    onToggle: toggleStretchTimer,
                                    onReset: resetStretchTimer
                                )
                            } else {
                                HeroNumbers(
                                    reps: $liveReps,
                                    weight: $liveWeight,
                                    showWeight: ex.weight > 0 || ex.kind == .strength,
                                    units: heroUnits(for: ex)
                                )

                                Text("Tap a number to edit")
                                    .font(Theme.Font.mono(10, .medium))
                                    .tracking(0.9)
                                    .foregroundColor(Theme.Color.fgFaint)

                                SetChips(
                                    currentSet: currentSet,
                                    total: ex.sets,
                                    liveReps: liveReps,
                                    liveWeight: liveWeight,
                                    logged: loggedSets[exerciseIndex] ?? [],
                                    onTap: { jumpToSet($0) },
                                    onAddSet: addSet
                                )
                            }
                        } else {
                            Text("Session complete").font(.system(size: 22, weight: .semibold)).foregroundColor(Theme.Color.fg)
                        }

                        Spacer(minLength: 220)
                    }
                    .padding(.horizontal, 20)
                }
            }

            if let ex = currentExercise {
                ActionDock(
                    cta: ctaLabel(for: ex),
                    partner: Partner(name: store.partner.name, initial: store.partner.initial, online: store.partner.online),
                    isPaired: store.isPaired,
                    onLog: { primaryAction(for: ex) },
                    onAdjust: { showAdjustSheet = true },
                    onSkip: skipSet,
                    onPlanSheet: { showPlanSheet = true },
                    onEnd: finishSession
                )
            } else {
                VStack(spacing: 12) {
                    PrimaryCTA(title: "Finish session", trailingSystemImage: "checkmark", tall: true, action: finishSession)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanSheet(plan: plan,
                      currentExerciseIndex: exerciseIndex,
                      isPaired: store.isPaired,
                      partnerName: store.partner.name,
                      youName: store.profile.youLabel,
                      onAdd: {
                          // Close the plan sheet first so the add sheet
                          // doesn't stack on top of it (visually noisy + iOS
                          // gets cranky about double-presented detents).
                          showPlanSheet = false
                          // Present the add sheet on the next runloop tick to
                          // give the dismissal a frame to settle.
                          DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                              showAddSheet = true
                          }
                      })
                // Two detents so users can comfortably read longer plans —
                // default to the larger one because this view's job is
                // "show me everything in today's session". The medium detent
                // stays as a quick-peek option.
                .presentationDetents([.large, .fraction(0.78)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showAddSheet) {
            AddExerciseSheet(
                onAdd: { plan in
                    store.appendToTodayPlan(plan)
                    store.showToast("Added \(plan.name)", icon: "plus.circle.fill")
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showAdjustSheet) {
            if let ex = currentExercise {
                AdjustExerciseSheet(
                    exerciseName: ex.name,
                    sets: ex.sets,
                    reps: ex.reps,
                    weight: ex.weight,
                    showWeight: ex.kind == .strength || ex.weight > 0,
                    onApply: { newSets, newReps, newWeight in
                        applyAdjustment(sets: newSets, reps: newReps, weight: newWeight)
                        showAdjustSheet = false
                    }
                )
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.bgElev1)
            }
        }
        .onAppear {
            sessionStart = Date()
            startTimers()
            seedLiveValues()
            publishLiveSnapshot()
        }
        .onDisappear {
            // If the user backgrounds out of the session without
            // finishing, tear our `live_sessions` row down so the partner
            // doesn't see a ghost workout for the rest of the day.
            // `finishSession` calls `clearLiveSession` *before* this, so
            // the duplicate call here is a no-op.
            Task { await store.clearLiveSession?() }
        }
        .onChange(of: exerciseIndex) { _, _ in
            seedLiveValues()
            publishLiveSnapshot()
        }
        .onChange(of: currentSet) { _, _ in
            seedLiveValues()
            publishLiveSnapshot()
        }
        .onChange(of: loggedTotalSets) { _, _ in
            // Set logging changes the visible progress bar; mirror that
            // out so the partner's banner moves in sync.
            publishLiveSnapshot()
        }
    }

    /// Push the current "what I'm doing" snapshot through the
    /// `publishLiveSession` hook installed by `RemoteSync`. The hook
    /// handles auth, debouncing, and the actual upsert; we just shape
    /// the payload the partner UI cares about.
    private func publishLiveSnapshot() {
        guard let publish = store.publishLiveSession else { return }
        let exName = currentExercise?.name
        let total  = currentExercise?.sets
        let pct    = Int(youProgressPct.rounded())
        let setIdx = currentSet
        Task { await publish(exName, setIdx, total, pct) }
    }

    // MARK: - Computed

    private var totalSets: Int {
        plan.youPlan.reduce(0) { $0 + $1.sets }
    }
    private var loggedTotalSets: Int {
        loggedSets.values.reduce(0) { $0 + $1.count }
    }
    private var youProgressPct: Double {
        guard totalSets > 0 else { return 0 }
        return Double(loggedTotalSets) / Double(totalSets) * 100
    }

    /// Per-side meta strings shown under the dual-progress bars. We surface
    /// the side's *own* exercise count so users can see at a glance that
    /// each plan is its own length when goals diverge.
    private var youProgressMeta: String {
        "\(min(exerciseIndex + 1, plan.youPlan.count))/\(plan.youPlan.count) · \(Int(youProgressPct))%"
    }
    private var partnerProgressMeta: String {
        let total = max(plan.partnerPlan.count, 1)
        let raw = Int((store.partnerProgressPct / 100) * Double(total))
        let cur = max(0, min(total, raw))
        return "\(cur)/\(total) · \(Int(store.partnerProgressPct))%"
    }

    /// Banner shown above the dual progress bars when the pair is on
    /// different programs. We removed the "Independent · different programs"
    /// heading that used to sit above this row — it was engineer-speak, and
    /// the per-side theme line below already says everything that matters.
    private var divergenceBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Color.partner)
            Text("\(store.profile.youLabel): \(plan.title.lowercased()) · \(store.partner.name): \(plan.partnerTitle.lowercased())")
                .font(Theme.Font.sans(12, .medium))
                .foregroundColor(Theme.Color.fg)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Color.partnerDim)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func heroUnits(for ex: ExercisePlan) -> String {
        switch ex.kind {
        case .strength: return "reps × \(store.profile.units.weightUnit)"
        case .bodyweight: return "reps"
        case .timedHold: return "seconds"
        case .distance: return store.profile.units.distanceUnit
        case .timeBased: return "minutes"
        case .mobility: return "reps"
        case .stretching: return "stopwatch"
        }
    }

    // MARK: - Actions

    /// Routes the dock CTA to the right action based on exercise kind and
    /// stretching state. For a stretching exercise that hasn't started yet,
    /// the first tap *starts* the timer; subsequent taps log it.
    private func primaryAction(for ex: ExercisePlan) {
        if ex.kind.isStopwatch && liveStretchSeconds == 0 && !stretchRunning {
            toggleStretchTimer()
            return
        }
        logSet()
    }

    private func logSet() {
        guard let ex = currentExercise else { return }

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        // Stretching takes a different path: store seconds in `reps`, never
        // PR-detect, advance to next exercise (no concept of multiple sets).
        if ex.kind.isStopwatch {
            // Snapshot the live elapsed value if the timer is still running.
            if stretchRunning, let start = stretchStart {
                liveStretchSeconds = Int(Date().timeIntervalSince(start))
            }
            // Don't log a 0-second stretch — treat as a no-op.
            guard liveStretchSeconds > 0 else { return }
            let entry = CompletedSet(reps: liveStretchSeconds, weight: 0)
            loggedSets[exerciseIndex] = [entry]
            // Reset stopwatch state before moving on so the next exercise
            // doesn't inherit a half-finished timer.
            resetStretchTimer()
            advance(ex: ex)
            return
        }

        // Append (or replace, if user is editing a previously logged set) using
        // the *live* values the user actually performed.
        var sets = loggedSets[exerciseIndex] ?? []
        let entry = CompletedSet(reps: liveReps, weight: liveWeight)
        let i = currentSet - 1
        if sets.indices.contains(i) {
            sets[i] = entry
        } else {
            sets.append(entry)
        }
        loggedSets[exerciseIndex] = sets

        // PR detection — any set that beats the user's all-time best for this lift.
        if ex.kind == .strength {
            let previousBest = store.bestLift(catalogId: ex.catalogId)
            if liveWeight > previousBest && !prFlaggedExercises.contains(exerciseIndex) {
                prFlaggedExercises.insert(exerciseIndex)
                onPR(ex.name, liveReps, liveWeight)
            }
        }

        advance(ex: ex)
    }

    private func skipSet() {
        guard let ex = currentExercise else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        advance(ex: ex)
    }

    private func advance(ex: ExercisePlan) {
        // Stretching is always a single "set" — the stopwatch entry — so
        // it skips the multi-set loop and goes straight to the next exercise.
        let isOneShot = ex.kind.isStopwatch
        if !isOneShot && currentSet < ex.sets {
            currentSet += 1
            store.partnerProgressPct = min(100, store.partnerProgressPct + 5)
        } else if exerciseIndex + 1 < plan.youPlan.count {
            exerciseIndex += 1
            currentSet = 1
        } else {
            exerciseIndex = plan.youPlan.count
        }
    }

    private func jumpToSet(_ set: Int) {
        guard let ex = currentExercise, set >= 1, set <= ex.sets else { return }
        currentSet = set
    }

    private func seedLiveValues() {
        guard let ex = currentExercise else { return }
        // Stretching: reset the stopwatch any time we land on a new
        // stretching exercise, but preserve previously-logged seconds so the
        // user can revisit a finished entry.
        if ex.kind.isStopwatch {
            if let logged = loggedSets[exerciseIndex]?.first {
                liveStretchSeconds = logged.reps
            } else {
                liveStretchSeconds = 0
            }
            stretchStart = nil
            stretchRunning = false
            return
        }
        // If this set was already logged, load those numbers so the user can
        // re-edit. Otherwise fall back to the prescribed plan values.
        if let logged = loggedSets[exerciseIndex]?[safe: currentSet - 1] {
            liveReps = logged.reps
            liveWeight = logged.weight
        } else {
            liveReps = ex.reps
            liveWeight = ex.weight
        }
    }

    private func addSet() {
        guard let ex = currentExercise else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        var copy = ex
        copy.sets = ex.sets + 1
        planOverrides[exerciseIndex] = copy
    }

    private func applyAdjustment(sets: Int, reps: Int, weight: Int) {
        guard let ex = currentExercise else { return }
        var copy = ex
        copy.sets = max(1, sets)
        copy.reps = max(1, reps)
        copy.weight = max(0, weight)
        planOverrides[exerciseIndex] = copy
        liveReps = copy.reps
        liveWeight = copy.weight
        if currentSet > copy.sets { currentSet = copy.sets }
    }

    private func ctaLabel(for ex: ExercisePlan) -> String {
        if ex.kind.isStopwatch {
            // Show the live elapsed value so users know exactly what they're
            // about to commit. Disabled-feeling phrasing when 0s.
            let s = liveStretchSeconds
            let mmss = String(format: "%d:%02d", s / 60, s % 60)
            let alreadyLogged = (loggedSets[exerciseIndex]?.first != nil)
            let verb = alreadyLogged ? "Update stretch" : "Log stretch"
            return s > 0 ? "\(verb) · \(mmss)" : "Start stopwatch"
        }
        let alreadyLogged = (loggedSets[exerciseIndex]?.indices.contains(currentSet - 1)) ?? false
        let prefix = alreadyLogged ? "Update Set" : "Log Set"
        if liveWeight > 0 {
            return "\(prefix) \(currentSet) · \(liveReps) × \(liveWeight)"
        }
        return "\(prefix) \(currentSet) · \(liveReps) \(ex.kind == .timedHold ? "sec" : "reps")"
    }

    private func finishSession() {
        // Persist completed session into history.
        let duration = Int(Date().timeIntervalSince(sessionStart))
        let completedExercises: [CompletedExercise] = plan.youPlan.enumerated().map { idx, ex in
            CompletedExercise(
                catalogId: ex.catalogId,
                name: ex.name,
                sets: loggedSets[idx] ?? [],
                isPR: prFlaggedExercises.contains(idx)
            )
        }.filter { !$0.sets.isEmpty }   // only save exercises with at least one set

        if !completedExercises.isEmpty {
            let session = CompletedSession(
                title: "\(plan.title) \(plan.subtitle)".trimmingCharacters(in: .whitespaces),
                partnerTitle: store.isPaired
                    ? "\(plan.partnerTitle) \(plan.partnerSubtitle)".trimmingCharacters(in: .whitespaces)
                    : "",
                date: Date(),
                durationSeconds: max(60, duration),
                you: completedExercises,
                partner: []   // partner session would come from realtime in v1
            )
            store.saveCompletedSession(session)
            store.regenerateTodayPlan()   // queue tomorrow's session
        }
        // Tear down the realtime row before navigating away so the
        // partner banner flips to "rest" the moment we hit Finish, not
        // whenever the next subscription tick happens to fire.
        Task { await store.clearLiveSession?() }
        onComplete()
    }

    private func startTimers() {
        // Single 1Hz tick drives both the session header clock and the
        // stretching stopwatch. Keeping them in one timer avoids drift
        // between the two displays.
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let seconds = Int(Date().timeIntervalSince(sessionStart))
            elapsedText = String(format: "%02d:%02d", seconds / 60, seconds % 60)

            if stretchRunning, let start = stretchStart {
                liveStretchSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    // MARK: - Stretching controls

    /// Tap-to-toggle the stopwatch. We freeze the elapsed value on pause so
    /// users can pause/resume across multiple bouts and only log the total
    /// when they're done.
    private func toggleStretchTimer() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        if stretchRunning {
            // Pause — accumulate elapsed into liveStretchSeconds, drop start.
            if let start = stretchStart {
                liveStretchSeconds = Int(Date().timeIntervalSince(start))
            }
            stretchStart = nil
            stretchRunning = false
        } else {
            // Resume — anchor "start" backwards by however much was already
            // logged, so the displayed value continues from where it paused.
            stretchStart = Date().addingTimeInterval(-Double(liveStretchSeconds))
            stretchRunning = true
        }
    }

    private func resetStretchTimer() {
        liveStretchSeconds = 0
        stretchStart = nil
        stretchRunning = false
    }
}

// MARK: - Top bar

struct ActiveTopBar: View {
    var elapsed: String
    var current: Int
    var total: Int
    var partner: Partner
    var isPaired: Bool
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            IconButton(systemName: "xmark", size: 36, action: onClose)
            Text(elapsed)
                .font(Theme.Font.mono(11, .medium).monospacedDigit())
                .tracking(0.9)
                .foregroundColor(Theme.Color.fg)
            Text("·").overlineStyle(color: Theme.Color.fgFaint)
            Text("\(current) / \(total)")
                .font(Theme.Font.mono(11, .medium).monospacedDigit())
                .tracking(0.9)
                .foregroundColor(Theme.Color.fgSoft)
            Spacer()
            if isPaired {
                PartnerPip(partner: partner)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Hero numbers

struct HeroNumbers: View {
    @Binding var reps: Int
    @Binding var weight: Int
    var showWeight: Bool
    var units: String

    @State private var editing: Field?
    enum Field { case reps, weight }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                numberTap(value: reps, isActive: editing == .reps) {
                    editing = (editing == .reps) ? nil : .reps
                }
                if showWeight {
                    Text("×").font(.system(size: 32, weight: .regular)).foregroundColor(Theme.Color.fgFaint)
                    numberTap(value: weight, isActive: editing == .weight) {
                        editing = (editing == .weight) ? nil : .weight
                    }
                }
            }
            Text(units.uppercased())
                .font(Theme.Font.mono(11, .medium)).tracking(2.0).foregroundColor(Theme.Color.fgSoft)

            if let field = editing {
                Stepper(
                    field: field,
                    reps: $reps,
                    weight: $weight,
                    onDone: { editing = nil }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.18), value: editing)
    }

    private func numberTap(value: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 96, weight: .semibold).monospacedDigit())
                .kerning(-3.8)
                .foregroundColor(isActive ? Theme.Color.accent : Theme.Color.fg)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .buttonStyle(.plain)
    }
}

/// Stopwatch UI used in place of `HeroNumbers` when the active exercise's
/// kind is `.stretching`. Big mm:ss readout with a Start/Pause control and a
/// reset affordance — stays visually consistent with the rest of the active
/// session (same height, same vertical rhythm) so the layout doesn't pop.
struct StretchHero: View {
    var seconds: Int
    var running: Bool
    var onToggle: () -> Void
    var onReset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(formatted)
                .font(.system(size: 76, weight: .semibold).monospacedDigit())
                .kerning(-2.4)
                .foregroundColor(running ? Theme.Color.accent : Theme.Color.fg)
                .contentTransition(.numericText())
                .animation(.snappy, value: seconds)

            Text("STOPWATCH")
                .font(Theme.Font.mono(11, .medium))
                .tracking(2.0)
                .foregroundColor(Theme.Color.fgSoft)

            HStack(spacing: 10) {
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: running ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(running ? "Pause" : (seconds > 0 ? "Resume" : "Start"))
                            .font(Theme.Font.sans(13, .semibold))
                    }
                    .foregroundColor(Theme.Color.accentInk)
                    .padding(.horizontal, 18).frame(height: 40)
                    .background(Theme.Color.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableStyle())

                if seconds > 0 {
                    Button(action: onReset) {
                        Text("Reset")
                            .font(Theme.Font.sans(13, .medium))
                            .foregroundColor(Theme.Color.fgMute)
                            .padding(.horizontal, 16).frame(height: 40)
                            .background(Theme.Color.bgElev2)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var formatted: String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct Stepper: View {
    let field: HeroNumbers.Field
    @Binding var reps: Int
    @Binding var weight: Int
    var onDone: () -> Void

    private var stepSize: Int { field == .weight ? 5 : 1 }

    var body: some View {
        HStack(spacing: 14) {
            stepButton("minus") { adjust(-stepSize) }
            Text(field == .weight ? "WEIGHT" : "REPS")
                .font(Theme.Font.mono(10, .medium)).tracking(1.4)
                .foregroundColor(Theme.Color.fgSoft)
                .frame(width: 70)
            stepButton("plus")  { adjust(stepSize) }

            Button(action: onDone) {
                Text("Done")
                    .font(Theme.Font.sans(12, .semibold))
                    .foregroundColor(Theme.Color.accentInk)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Theme.Color.accent)
                    .clipShape(Capsule())
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.Color.bgElev2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.Color.fg)
                .frame(width: 44, height: 44)
                .background(Theme.Color.bgElev3)
                .clipShape(Circle())
        }
        .buttonStyle(PressableStyle())
    }

    private func adjust(_ delta: Int) {
        switch field {
        case .reps:   reps = max(1, reps + delta)
        case .weight: weight = max(0, weight + delta)
        }
    }
}

// MARK: - Set chips

private struct SetChips: View {
    var currentSet: Int
    var total: Int
    var liveReps: Int
    var liveWeight: Int
    var logged: [CompletedSet]
    var onTap: (Int) -> Void
    var onAddSet: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                chip(i)
            }
            addChip
        }
    }

    private var addChip: some View {
        Button(action: onAddSet) {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Color.fgMute)
                Text("Add")
                    .font(Theme.Font.mono(9, .medium))
                    .tracking(0.9)
                    .foregroundColor(Theme.Color.fgMute)
            }
            .frame(width: 56).frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Theme.Color.hairline,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(PressableStyle())
    }

    private func chip(_ i: Int) -> some View {
        let loggedHere = logged.indices.contains(i - 1) ? logged[i - 1] : nil
        let isDone = loggedHere != nil
        let isCurrent = i == currentSet
        let setValue: String = {
            if let s = loggedHere {
                return s.weight > 0 ? "\(s.reps) × \(s.weight)" : "\(s.reps)"
            }
            if isCurrent {
                return liveWeight > 0 ? "\(liveReps) × \(liveWeight)" : "\(liveReps)"
            }
            return "—"
        }()
        let labelColor: Color = isCurrent ? Theme.Color.fg : (isDone ? Theme.Color.accent : Theme.Color.fgFaint)
        return Button(action: { onTap(i) }) {
            VStack(spacing: 3) {
                Text("Set \(i)".uppercased())
                    .font(Theme.Font.mono(9, .medium))
                    .tracking(0.9)
                    .foregroundColor(labelColor)
                Text(setValue)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundColor(labelColor)
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(
                ZStack {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.Color.bgElev3)
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Color.fg.opacity(0.5), lineWidth: 1.5)
                    } else if isDone {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.Color.accentDim)
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Color.accentRing, lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.Color.bgElev2)
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Color.hairline, lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Action dock

private struct ActionDock: View {
    var cta: String
    var partner: Partner
    var isPaired: Bool
    var onLog: () -> Void
    var onAdjust: () -> Void
    var onSkip: () -> Void
    var onPlanSheet: () -> Void
    var onEnd: () -> Void

    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack(spacing: 14) {
            if isPaired {
                HStack(spacing: 10) {
                    Avatar(initial: partner.initial, size: 22, tone: .partner)
                    Text("\(partner.name) · Goblet squat · set 3 of 4")
                        .font(Theme.Font.sans(12)).foregroundColor(Theme.Color.fgMute)
                    Spacer()
                    IconButton(systemName: "bubble.left", size: 32) {
                        store.showToast("Quick chat with \(partner.name) coming soon", icon: "bubble.left.fill")
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.Color.bgElev2)
                .clipShape(Capsule())
            }

            Button(action: onLog) {
                HStack {
                    Text(cta).font(Theme.Font.sans(17, .semibold)).foregroundColor(Theme.Color.accentInk)
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.Color.accentInk)
                }
                .padding(.horizontal, 22).frame(height: 64)
                .frame(maxWidth: .infinity)
                .background(Theme.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .shadow(color: Theme.Color.accent.opacity(0.28), radius: 14, y: 8)
            }
            .buttonStyle(PressableStyle())

            HStack(spacing: 14) {
                Button("Adjust", action: onAdjust).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
                Text("·").foregroundColor(Theme.Color.fgFaint)
                Button("Skip set", action: onSkip).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
                Text("·").foregroundColor(Theme.Color.fgFaint)
                Button("Plan", action: onPlanSheet).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
                Text("·").foregroundColor(Theme.Color.fgFaint)
                Button("End session", action: onEnd).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.dangerSoft)
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 32)
        .background(
            LinearGradient(colors: [Theme.Color.bg.opacity(0), Theme.Color.bg], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Plan sheet

struct PlanSheet: View {
    var plan: SessionPlan
    var currentExerciseIndex: Int
    var isPaired: Bool
    var partnerName: String
    var youName: String = "You"
    /// When non-nil, the sheet shows a "+ Add exercise" CTA at the bottom.
    /// The Today preview passes `nil` to keep that surface read-only; the
    /// Active session passes a closure that opens `AddExerciseSheet`.
    var onAdd: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today's plan").font(.system(size: 22, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Spacer()
                Text("\(plan.durationMinutes) min · \(plan.youPlan.count) ex")
                    .font(Theme.Font.mono(10.5, .medium))
                    .foregroundColor(Theme.Color.fgSoft)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)

            HStack(spacing: 12) {
                Text("#").labelStyle().frame(width: 28, alignment: .center)
                HStack(spacing: 6) {
                    Circle().fill(Theme.Color.you).frame(width: 6, height: 6)
                    Text(youName).labelStyle(color: Theme.Color.you)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if isPaired {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.Color.partner).frame(width: 6, height: 6)
                        Text(partnerName).labelStyle(color: Theme.Color.partner)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<plan.youPlan.count, id: \.self) { i in
                        PlanRow(
                            idx: i + 1,
                            you: plan.youPlan[i],
                            par: isPaired ? plan.partnerPlan[safe: i] : nil,
                            status: i == currentExerciseIndex ? .current : (i < currentExerciseIndex ? .done : .upcoming)
                        )
                        if i < plan.youPlan.count - 1 { Divider().background(Theme.Color.hairline) }
                    }
                    // Bottom inset so the last row never sits flush against
                    // the sticky CTA — gives the gradient fade room to read.
                    Spacer(minLength: onAdd == nil ? 24 : 96)
                }
                .padding(.horizontal, 18)
            }

            // Sticky add-exercise CTA. Pinned so it's reachable regardless
            // of how many exercises the plan has, and how tall the user has
            // dragged the sheet. Suppressed when `onAdd` is nil (Today's
            // read-only preview) so the chrome doesn't appear out of context.
            if let onAdd {
                addCTA(onAdd: onAdd)
            }
        }
        .background(Theme.Color.bgElev1)
    }

    private func addCTA(onAdd: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // Top fade so the scroll content visually dissolves into the CTA
            // surface instead of getting hard-clipped.
            LinearGradient(
                colors: [Theme.Color.bgElev1.opacity(0), Theme.Color.bgElev1],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 18)
            .allowsHitTesting(false)

            Button(action: onAdd) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Color.accentInk)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Add exercise")
                            .font(Theme.Font.sans(15, .semibold))
                            .foregroundColor(Theme.Color.accentInk)
                        Text("Stretching · custom · from catalog")
                            .font(Theme.Font.mono(10.5))
                            .foregroundColor(Theme.Color.accentInk.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Color.accentInk.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Theme.Color.bgElev1)
        }
    }
}

private enum PlanStatus { case done, current, upcoming }

private struct PlanRow: View {
    var idx: Int
    var you: ExercisePlan
    var par: ExercisePlan?
    var status: PlanStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", idx))
                .font(Theme.Font.mono(11, .medium))
                .foregroundColor(Theme.Color.fgFaint)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            cell(name: you.name, meta: you.meta, color: Theme.Color.you)
            if let par {
                cell(name: par.name, meta: par.meta, color: Theme.Color.partner)
            }
        }
        .padding(.vertical, 10)
    }

    private func cell(name: String, meta: String, color: Color) -> some View {
        HStack(spacing: 8) {
            statusDot(color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.Font.sans(13))
                    .foregroundColor(status == .upcoming ? Theme.Color.fgFaint : Theme.Color.fg)
                Text(meta)
                    .font(Theme.Font.mono(11))
                    .foregroundColor(status == .upcoming ? Theme.Color.fgFaint.opacity(0.7) : Theme.Color.fgSoft)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusDot(color: Color) -> some View {
        switch status {
        case .done:    Circle().fill(color).frame(width: 10, height: 10)
        case .current: Circle().strokeBorder(color, lineWidth: 2).frame(width: 10, height: 10)
        case .upcoming: Circle().strokeBorder(Theme.Color.hairline, lineWidth: 1).frame(width: 10, height: 10)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Adjust exercise sheet

private struct AdjustExerciseSheet: View {
    let exerciseName: String
    @State var sets: Int
    @State var reps: Int
    @State var weight: Int
    let showWeight: Bool
    let onApply: (Int, Int, Int) -> Void

    init(exerciseName: String, sets: Int, reps: Int, weight: Int, showWeight: Bool, onApply: @escaping (Int, Int, Int) -> Void) {
        self.exerciseName = exerciseName
        self._sets   = State(initialValue: sets)
        self._reps   = State(initialValue: reps)
        self._weight = State(initialValue: weight)
        self.showWeight = showWeight
        self.onApply = onApply
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Adjust exercise").font(.system(size: 20, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Text(exerciseName).font(Theme.Font.mono(11, .medium)).tracking(0.9).foregroundColor(Theme.Color.fgSoft)
            }
            .padding(.top, 18)

            VStack(spacing: 10) {
                AdjustRow(label: "Sets",   value: $sets,   step: 1, min: 1)
                AdjustRow(label: "Reps",   value: $reps,   step: 1, min: 1)
                if showWeight {
                    AdjustRow(label: "Weight (lb)", value: $weight, step: 5, min: 0)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            PrimaryCTA(title: "Apply", trailingSystemImage: "checkmark", tall: true) {
                onApply(sets, reps, weight)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AdjustRow: View {
    let label: String
    @Binding var value: Int
    let step: Int
    let min: Int

    var body: some View {
        HStack {
            Text(label).font(Theme.Font.sans(15)).foregroundColor(Theme.Color.fg)
            Spacer()
            HStack(spacing: 12) {
                circleButton("minus") { value = Swift.max(min, value - step) }
                Text("\(value)")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundColor(Theme.Color.fg)
                    .frame(minWidth: 48)
                circleButton("plus")  { value = value + step }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.Color.bgElev2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.Color.fg)
                .frame(width: 36, height: 36)
                .background(Theme.Color.bgElev3)
                .clipShape(Circle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Add exercise sheet

/// Sheet presented from the plan view to splice a new exercise into today's
/// session. Three sections, top-down by frequency-of-use:
///   1. **Stretching** — area chips → instant add (most-used in-session)
///   2. **Custom** — user's saved customs + "Create new"
///   3. **Catalog** — searchable, grouped by muscle (full library)
struct AddExerciseSheet: View {
    var onAdd: (ExercisePlan) -> Void
    var onCancel: () -> Void

    @EnvironmentObject var store: SessionStore
    @State private var search: String = ""
    @State private var showCustomCreator = false
    @State private var showAreaCreator = false
    @State private var newAreaName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stretchingSection
                    customSection
                    catalogSection
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .background(Theme.Color.bgElev1)
        .sheet(isPresented: $showCustomCreator) {
            CustomExerciseSheet(
                existing: nil,
                onSave: { custom in
                    store.addCustomExercise(custom)
                    showCustomCreator = false
                    onAdd(planFromCustom(custom))
                },
                onCancel: { showCustomCreator = false }
            )
            .presentationDetents([.large])
            .presentationBackground(Theme.Color.bgElev1)
        }
        .alert("New stretch area", isPresented: $showAreaCreator) {
            TextField("e.g. Glutes", text: $newAreaName)
            Button("Cancel", role: .cancel) { newAreaName = "" }
            Button("Save") {
                let trimmed = newAreaName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                store.addStretchArea(trimmed)
                newAreaName = ""
            }
        } message: {
            Text("We'll save this so it appears next time you stretch.")
        }
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Color.fgMute)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.bgElev2)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Add to plan")
                .font(Theme.Font.sans(17, .semibold))
                .foregroundColor(Theme.Color.fg)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
    }

    // ── Stretching section ───────────────────────────────────────────────

    private var stretchingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STRETCHING").overlineStyle()
                Spacer()
                Text("Tap an area to add").labelStyle(color: Theme.Color.fgFaint)
            }
            // FlowLayout is defined in OnboardingFlow.swift — same internal
            // wrapping component used by the goals chips.
            FlowLayout(spacing: 8) {
                ForEach(StretchArea.allCases) { area in
                    chip(area.label, system: "figure.flexibility") {
                        addStretch(area: area.label, group: area.muscleGroup)
                    }
                }
                ForEach(store.profile.customStretchAreas, id: \.self) { area in
                    chip(area, system: "figure.flexibility") {
                        addStretch(area: area, group: area)
                    }
                }
                chip("+ Add area…", system: nil, accent: true) {
                    showAreaCreator = true
                }
            }
        }
    }

    // ── Custom exercises section ────────────────────────────────────────

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR EXERCISES").overlineStyle()
                Spacer()
                Button(action: { showCustomCreator = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("New").font(Theme.Font.mono(10.5, .medium)).tracking(0.5)
                    }
                    .foregroundColor(Theme.Color.accent)
                }
            }
            if store.profile.customExercises.isEmpty {
                Text("Nothing saved yet — tap New to define an exercise that lives in your library forever.")
                    .font(Theme.Font.sans(13))
                    .foregroundColor(Theme.Color.fgSoft)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .background(Theme.Color.bgElev2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                VStack(spacing: 0) {
                    ForEach(store.profile.customExercises) { c in
                        Button(action: { onAdd(planFromCustom(c)) }) {
                            row(name: c.name, meta: customMeta(c), badge: "CUSTOM")
                        }.buttonStyle(.plain)
                        if c.id != store.profile.customExercises.last?.id {
                            Divider().background(Theme.Color.hairline)
                        }
                    }
                }
                .background(Theme.Color.bgElev2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    // ── Catalog browse section ──────────────────────────────────────────

    private var filteredCatalog: [CatalogExercise] {
        let q = search.lowercased()
        return ExerciseCatalog.all.filter {
            q.isEmpty ||
            $0.name.lowercased().contains(q) ||
            $0.muscleGroups.contains(where: { $0.lowercased().contains(q) })
        }
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CATALOG").overlineStyle()
                Spacer()
                Text("\(filteredCatalog.count) exercises").labelStyle(color: Theme.Color.fgFaint)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(Theme.Color.fgSoft)
                TextField("", text: $search,
                          prompt: Text("Search exercises or muscle group").foregroundColor(Theme.Color.fgFaint))
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fg)
                    .autocorrectionDisabled()
                if !search.isEmpty {
                    Button(action: { search = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14)).foregroundColor(Theme.Color.fgFaint)
                    }
                }
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))

            VStack(spacing: 0) {
                ForEach(filteredCatalog) { ex in
                    Button(action: { onAdd(planFromCatalog(ex)) }) {
                        row(name: ex.name, meta: catalogMeta(ex), badge: nil)
                    }.buttonStyle(.plain)
                    if ex.id != filteredCatalog.last?.id {
                        Divider().background(Theme.Color.hairline)
                    }
                }
            }
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private func chip(_ label: String, system: String?, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let system { Image(systemName: system).font(.system(size: 11, weight: .semibold)) }
                Text(label).font(Theme.Font.sans(13, .medium))
            }
            .foregroundColor(accent ? Theme.Color.accent : Theme.Color.fg)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(accent ? Theme.Color.accent.opacity(0.15) : Theme.Color.bgElev2)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(accent ? Theme.Color.accent.opacity(0.4) : Theme.Color.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func row(name: String, meta: String, badge: String?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                    if let badge {
                        Text(badge)
                            .font(Theme.Font.mono(9, .medium)).tracking(0.6)
                            .foregroundColor(Theme.Color.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.Color.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(meta).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
            }
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.Color.fgMute)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func customMeta(_ c: CustomExercise) -> String {
        let muscles = c.muscleGroups.isEmpty ? c.kind.label : c.muscleGroups.joined(separator: " · ")
        switch c.kind {
        case .strength:   return "\(c.defaultSets) × \(c.defaultReps) · \(c.defaultWeight) lb · \(muscles)"
        case .bodyweight: return "\(c.defaultSets) × \(c.defaultReps) · \(muscles)"
        case .timedHold:  return "\(c.defaultSets) × \(c.defaultReps)s · \(muscles)"
        case .stretching: return "Stretch · stopwatch"
        default:          return "\(c.kind.label) · \(muscles)"
        }
    }

    private func catalogMeta(_ ex: CatalogExercise) -> String {
        let muscles = ex.muscleGroups.joined(separator: " · ")
        switch ex.kind {
        case .strength:   return "\(ex.defaultSets) × \(ex.defaultReps) · \(ex.defaultWeight) lb · \(muscles)"
        case .bodyweight: return "\(ex.defaultSets) × \(ex.defaultReps) · \(muscles)"
        case .timedHold:  return "\(ex.defaultSets) × \(ex.defaultReps)s · \(muscles)"
        case .distance, .timeBased: return "Cardio · \(muscles)"
        case .mobility:   return "Mobility · \(muscles)"
        case .stretching: return "Stretch · stopwatch"
        }
    }

    /// Synthesize an `ExercisePlan` for an ad-hoc stretching entry. We don't
    /// add it to the catalog or customs — it's just a one-off attached to
    /// today's plan. The catalogId pattern is `stretch_<area>` so the
    /// completed-session row can recover the area name later.
    private func addStretch(area: String, group: String) {
        let id = "stretch_\(area.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let plan = ExercisePlan(
            catalogId: id, name: "\(area) stretch",
            sets: 1, reps: 0, weight: 0, kind: .stretching
        )
        onAdd(plan)
    }

    private func planFromCustom(_ c: CustomExercise) -> ExercisePlan {
        ExercisePlan(
            catalogId: c.id, name: c.name,
            sets: max(1, c.defaultSets),
            reps: c.kind.isStopwatch ? 0 : max(1, c.defaultReps),
            weight: c.defaultWeight,
            kind: c.kind
        )
    }

    private func planFromCatalog(_ ex: CatalogExercise) -> ExercisePlan {
        ExercisePlan(
            catalogId: ex.id, name: ex.name,
            sets: ex.defaultSets, reps: ex.defaultReps,
            weight: ex.defaultWeight, kind: ex.kind
        )
    }
}

// MARK: - Custom exercise sheet

/// Define a brand-new exercise the catalog doesn't ship. Survives across
/// sessions on `UserProfile.customExercises`. Required: name + kind.
/// Optional: muscle groups (which makes it AI-eligible) and defaults.
struct CustomExerciseSheet: View {
    /// Pass an existing entry to edit; nil = create flow.
    var existing: CustomExercise?
    var onSave: (CustomExercise) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var kind: ExerciseKind = .strength
    @State private var muscleGroups: Set<String> = []
    @State private var defaultSets: Int = 3
    @State private var defaultReps: Int = 8
    @State private var defaultWeight: Int = 0

    /// Canonical muscle groups — same vocabulary the planner uses, so a user
    /// who tags their custom exercise here makes it eligible for AI selection.
    private let availableGroups = [
        "Quads","Glutes","Hamstrings","Calves",
        "Chest","Back","Shoulders",
        "Core","Cardio","Mobility"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nameField
                    kindPicker
                    musclePicker
                    if !kind.isStopwatch {
                        defaultsBlock
                    }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20).padding(.top, 16)
            }

            VStack {
                PrimaryCTA(
                    title: existing == nil ? "Save & add" : "Save changes",
                    trailingSystemImage: "checkmark",
                    tall: true,
                    action: save
                )
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(LinearGradient(colors: [Theme.Color.bgElev1.opacity(0), Theme.Color.bgElev1],
                                       startPoint: .top, endPoint: .center))
        }
        .background(Theme.Color.bgElev1)
        .onAppear {
            if let ex = existing {
                name = ex.name
                kind = ex.kind
                muscleGroups = Set(ex.muscleGroups)
                defaultSets = ex.defaultSets
                defaultReps = ex.defaultReps
                defaultWeight = ex.defaultWeight
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Color.fgMute)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.bgElev2)
                    .clipShape(Circle())
            }
            Spacer()
            Text(existing == nil ? "New exercise" : "Edit exercise")
                .font(Theme.Font.sans(17, .semibold))
                .foregroundColor(Theme.Color.fg)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME").overlineStyle()
            TextField("", text: $name,
                      prompt: Text("e.g. Banded pull-aparts").foregroundColor(Theme.Color.fgFaint))
                .font(Theme.Font.sans(15))
                .foregroundColor(Theme.Color.fg)
                .padding(.horizontal, 14).frame(height: 48)
                .background(Theme.Color.bgElev2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KIND").overlineStyle()
            FlowLayout(spacing: 8) {
                ForEach(ExerciseKind.allCases) { k in
                    Button(action: { kind = k }) {
                        Text(k.label)
                            .font(Theme.Font.sans(13, .medium))
                            .foregroundColor(kind == k ? Theme.Color.accentInk : Theme.Color.fg)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(kind == k ? Theme.Color.accent : Theme.Color.bgElev2)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(kind == k ? Color.clear : Theme.Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var musclePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MUSCLE GROUPS").overlineStyle()
                Spacer()
                Text("Optional · enables AI suggestions").labelStyle(color: Theme.Color.fgFaint)
            }
            FlowLayout(spacing: 8) {
                ForEach(availableGroups, id: \.self) { g in
                    Button(action: { toggleMuscle(g) }) {
                        Text(g)
                            .font(Theme.Font.sans(13, .medium))
                            .foregroundColor(muscleGroups.contains(g) ? Theme.Color.accentInk : Theme.Color.fg)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(muscleGroups.contains(g) ? Theme.Color.accent : Theme.Color.bgElev2)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(muscleGroups.contains(g) ? Color.clear : Theme.Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var defaultsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEFAULTS").overlineStyle()
            HStack(spacing: 10) {
                stepperField("Sets", value: $defaultSets, min: 1, step: 1)
                stepperField("Reps", value: $defaultReps, min: 1, step: 1)
                if kind == .strength {
                    stepperField("Weight", value: $defaultWeight, min: 0, step: 5)
                }
            }
        }
    }

    private func stepperField(_ label: String, value: Binding<Int>, min minimum: Int, step: Int) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(Theme.Font.mono(10, .medium)).tracking(1.0)
                .foregroundColor(Theme.Color.fgSoft)
            HStack(spacing: 10) {
                Button(action: {
                    value.wrappedValue = Swift.max(minimum, value.wrappedValue - step)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Color.fg)
                        .frame(width: 28, height: 28)
                        .background(Theme.Color.bgElev3)
                        .clipShape(Circle())
                }.buttonStyle(PressableStyle())
                Text("\(value.wrappedValue)")
                    .font(Theme.Font.sans(18, .semibold).monospacedDigit())
                    .foregroundColor(Theme.Color.fg)
                    .frame(minWidth: 32)
                Button(action: { value.wrappedValue += step }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Color.fg)
                        .frame(width: 28, height: 28)
                        .background(Theme.Color.bgElev3)
                        .clipShape(Circle())
                }.buttonStyle(PressableStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
        }
    }

    private func toggleMuscle(_ g: String) {
        if muscleGroups.contains(g) { muscleGroups.remove(g) } else { muscleGroups.insert(g) }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let entry = CustomExercise(
            id: existing?.id ?? CustomExercise.newID(),
            name: trimmed,
            kind: kind,
            muscleGroups: Array(muscleGroups).sorted(),
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            defaultWeight: defaultWeight
        )
        onSave(entry)
    }
}
