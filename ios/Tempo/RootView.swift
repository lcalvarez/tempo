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
    @State private var prPayload: PRPayload = PRPayload(name: "Back squat", reps: 6, weight: 200, previous: 195)
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

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .today:
            TodayView(
                onStart:     { showActiveSession = true },
                onPR:        {
                    prPayload = PRPayload(name: "Back squat", reps: 6, weight: 200, previous: 195)
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
