import SwiftUI

/// Four-tab shell + global routes for full-screen experiences.
struct RootView: View {
    @State private var tab: Tab = .today
    @State private var showOnboardingOverlay = false
    @State private var showGoalsOverlay = false
    @State private var showInvite = false
    @State private var showRelationshipPicker = false
    @State private var showActiveSession = false
    @State private var showPostSession = false
    @State private var showPR = false
    /// PR overlay payload. Set by the active session's `onPR` from a real
    /// logged set (`name`, `reps`, `weight` are live values; `previous`
    /// is read off `store.bestLift`). The debug demo path also synthesizes
    /// one from history. Default is an empty placeholder — never shown
    /// because `showPR` only flips after a real assignment.
    @State private var prPayload: PRPayload = PRPayload(name: "", reps: 0, weight: 0, previous: 0)
    @EnvironmentObject var store: SessionStore

    enum Tab: String, CaseIterable, Hashable {
        case today, schedule, progress, profile

        var label: String {
            switch self {
            case .today: return "Today"
            case .schedule: return "Schedule"
            case .progress: return "Progress"
            case .profile: return "Profile"
            }
        }

        var iconName: String {
            switch self {
            case .today: return "scope"
            // Calendar glyph for the time-axis view; replaces the History
            // hamburger because Schedule subsumes the past-week surface and
            // funnels the full History list into a sheet.
            case .schedule: return "calendar"
            case .progress: return "chart.bar.fill"
            case .profile: return "person.crop.circle"
            }
        }
    }

    var body: some View {
        Group {
            if !store.hasOnboarded {
                OnboardingFlow {
                    showGoalsOverlay = true
                }
                .environmentObject(store)
                .transition(.opacity)
            } else {
                mainShell
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.hasOnboarded)
        .preferredColorScheme(store.profile.appearance.swiftUIScheme)
    }

    private var mainShell: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()

            tabContent
                // Bottom inset clears the tab bar (icon + label + safe area).
                // Tightened back down after the wordmark was removed from the
                // bar — content can now reach closer to the tab row.
                .padding(.bottom, 84)

            TabBar(active: tab) { tab = $0 }

            ToastOverlay()
                .environmentObject(store)
                .allowsHitTesting(false)
        }
        .fullScreenCover(isPresented: $showActiveSession) {
            ActiveSessionView(
                onClose: { showActiveSession = false },
                onPR:    { name, reps, weight in
                    prPayload = PRPayload(
                        name: name, reps: reps, weight: weight,
                        previous: store.bestLift(catalogId: store.todayPlan.youPlan.first { $0.name == name }?.catalogId ?? "") 
                    )
                    showPR = true
                },
                onComplete: { showActiveSession = false; showPostSession = true }
            )
            .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showPostSession) {
            PostSessionView { showPostSession = false }
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showPR) {
            PRMomentView(payload: prPayload) { showPR = false }
        }
        .fullScreenCover(isPresented: $showOnboardingOverlay) {
            OnboardingFlow { showOnboardingOverlay = false }
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showGoalsOverlay,
                         onDismiss: { presentInviteIfNeeded() }) {
            GoalsFlow {
                showGoalsOverlay = false
            }
            .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showInvite) {
            InvitePartnerScreen(
                onSent: { showInvite = false },
                onSolo: { showInvite = false }
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showRelationshipPicker) {
            RelationshipPickerSheet { label, custom in
                store.setRelationshipLabel(label, custom: custom)
                showRelationshipPicker = false
            }
            .environmentObject(store)
        }
        .onChange(of: store.isPaired) { _, paired in
            if paired && store.partner.relationshipLabel == nil {
                showRelationshipPicker = true
            }
        }
    }


    /// Show the invite screen after goals finish — but only the first time
    /// (user hasn't paired yet and hasn't explicitly chosen solo).
    private func presentInviteIfNeeded() {
        guard !store.isPaired && !store.isSolo else { return }
        showInvite = true
    }

    /// Build a PR payload for the DEBUG demo route. Walks the user's
    /// completed history backwards looking for the first entry flagged
    /// `isPR` and surfaces those real numbers. Falls back to today's
    /// first planned exercise (with zero history) so brand-new accounts
    /// still see something coherent.
    private func demoPRPayload() -> PRPayload {
        for s in store.history {
            for ex in s.you where ex.isPR {
                let bestSet = ex.sets.max(by: { $0.weight < $1.weight }) ?? ex.sets.first
                let weight = bestSet?.weight ?? 0
                let reps = bestSet?.reps ?? 0
                return PRPayload(
                    name: ex.name,
                    reps: reps,
                    weight: weight,
                    previous: max(0, weight - 5)
                )
            }
        }
        let first = store.todayPlan.youPlan.first
        return PRPayload(
            name: first?.name ?? "Lift",
            reps: first?.reps ?? 0,
            weight: first?.weight ?? 0,
            previous: 0
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .today:
            TodayView(
                onStart:     { showActiveSession = true },
                // DEBUG-only "PR moment" demo. We synthesize a payload
                // from the most recent PR in history so the UI still
                // shows real numbers, falling back to a placeholder
                // only for a brand-new account with zero sessions.
                onPR:        {
                    prPayload = demoPRPayload()
                    showPR = true
                },
                onPost:      { showPostSession = true },
                onOnboarding:{ showOnboardingOverlay = true }
            )
        case .schedule:
            ScheduleView()
        case .progress:
            ProgressView()
        case .profile:
            ProfileView(onEditGoals: { showGoalsOverlay = true })
        }
    }
}

// MARK: - PR payload

struct PRPayload {
    var name: String
    var reps: Int
    var weight: Int
    var previous: Int
}

// MARK: - Tab bar

struct TabBar: View {
    var active: RootView.Tab
    var onSelect: (RootView.Tab) -> Void

    var body: some View {
        // Tab row only — the wordmark used to live below this row but it
        // competed visually with the tab labels and read as clutter, so the
        // brand presence now stays in onboarding/marketing surfaces only.
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases, id: \.self) { tab in
                TabBarItem(tab: tab, active: tab == active) {
                    onSelect(tab)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 18)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            Theme.Color.bg.opacity(0.85)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle().frame(height: 1).foregroundColor(Theme.Color.hairline),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabBarItem: View {
    var tab: RootView.Tab
    var active: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(active ? Theme.Color.accent : Theme.Color.fgFaint)
                Text(tab.label.uppercased())
                    .font(Theme.Font.mono(10, .medium))
                    .tracking(0.6)
                    .foregroundColor(active ? Theme.Color.fg : Theme.Color.fgFaint)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
