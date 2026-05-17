import SwiftUI

struct ProfileView: View {
    var onEditGoals: () -> Void = {}
    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var auth: AuthStore
    @State private var showUnpair = false
    @State private var showUnits = false
    @State private var showAppearance = false
    @State private var showLibrary = false
    @State private var showAccountConfirm: AccountAction? = nil
    @State private var showProfileMenu = false
    @State private var showRelationshipPicker = false
    @State private var showInviteSheet = false
    @State private var showSignIn = false
    @State private var signInInitialMode: SignInSheet.InitialMode = .auto
    @State private var deletingAccount = false
    @State private var exportShareItem: ExportShareItem? = nil

    /// Bindings into `store.profile.*` for the toggle rows. Centralizing
    /// them here keeps the body concise and ensures every flip both
    /// persists (via `SessionStore.profile`'s `didSet`) and triggers a
    /// debounced server PATCH (via `RemoteSync.markProfileDirty`).
    private var sessionReminders: Binding<Bool> {
        Binding(get: { store.profile.sessionRemindersEnabled },
                set: { store.profile.sessionRemindersEnabled = $0 })
    }
    private var partnerActivity: Binding<Bool> {
        Binding(get: { store.profile.partnerActivityNotifs },
                set: { store.profile.partnerActivityNotifs = $0 })
    }
    private var showRPE: Binding<Bool> {
        Binding(get: { store.profile.showRPE },
                set: { store.profile.showRPE = $0 })
    }
    private var plateCalc: Binding<Bool> {
        Binding(get: { store.profile.plateCalcEnabled },
                set: { store.profile.plateCalcEnabled = $0 })
    }
    private var aiPlanning: Binding<Bool> {
        Binding(get: { store.profile.aiPlanningEnabled },
                set: { store.profile.aiPlanningEnabled = $0 })
    }

    private enum AccountAction: Identifiable {
        case signOut, delete
        var id: Int { self == .signOut ? 0 : 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "Profile",
                dateLine: nil,
                trailing: AnyView(IconButton(systemName: "ellipsis") {
                    showProfileMenu = true
                })
            )
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    HStack(spacing: 14) {
                        Avatar(initial: youInitial, size: 56, tone: monogramTone)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName).font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.Color.fg)
                            Text("\(store.profile.age) · \(store.profile.fitnessLevel.label)")
                                .font(Theme.Font.mono(11))
                                .foregroundColor(Theme.Color.fgSoft)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    if store.isPaired {
                        VStack(spacing: 12) {
                            SectionHead(title: "Partner", meta: "Connected · \(daysPaired()) days")
                            partnerCard
                        }
                    } else {
                        VStack(spacing: 12) {
                            SectionHead(title: "Partner")
                            unpairedCard
                        }
                    }

                    // Goals section — tap rows to open the goals flow
                    settingsSection(title: "Goals", meta: "Edit to regenerate plan") {
                        Button(action: onEditGoals) { chevRow("Primary focus", value: focusSummary) }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: onEditGoals) { chevRow("Sessions per week", value: "\(store.profile.sessionsPerWeek)") }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: onEditGoals) { chevRow("Intensity", value: store.profile.intensity.label) }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: onEditGoals) { chevRow("Planning", value: planningSummary) }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: onEditGoals) { chevRow("Styles I enjoy", value: store.profile.enjoyedStyles.isEmpty ? "—" : Array(store.profile.enjoyedStyles).joined(separator: " · ")) }.buttonStyle(.plain)
                    }

                    settingsSection(title: "Preferences") {
                        Button(action: { showUnits = true }) { chevRow("Units", value: store.profile.units.label) }
                            .buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: { showAppearance = true }) { chevRow("Appearance", value: store.profile.appearance.label) }
                            .buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        toggleRow("Session reminders", hint: "20 min before scheduled start", value: sessionReminders)
                        Divider().background(Theme.Color.hairline)
                        toggleRow("Partner activity", hint: "When \(store.partner.name) logs a PR or finishes", value: partnerActivity)
                        Divider().background(Theme.Color.hairline)
                        toggleRow("AI trainer", hint: "Use Apple Intelligence / Sonnet 4.5 to plan", value: aiPlanning)
                    }

                    settingsSection(title: "Library", meta: "Your custom exercises") {
                        Button(action: { showLibrary = true }) {
                            chevRow("Custom exercises",
                                    value: store.profile.customExercises.isEmpty
                                           ? "None"
                                           : "\(store.profile.customExercises.count)")
                        }.buttonStyle(.plain)
                    }

                    settingsSection(title: "Advanced", meta: "Optional") {
                        toggleRow("Show RPE field", hint: "Rate of perceived exertion per set", value: showRPE)
                        Divider().background(Theme.Color.hairline)
                        toggleRow("Plate calculator", hint: nil, value: plateCalc)
                        Divider().background(Theme.Color.hairline)
                        Button(action: { exportShareItem = makeExportShareItem() }) {
                            chevRow("Export data", value: "CSV")
                        }.buttonStyle(.plain)
                    }

                    settingsSection(title: "Account") {
                        if auth.isAnonymous {
                            // Guest mode: surface the upsell up top so users
                            // realize their data isn't persisted to a real
                            // identity yet.
                            Button(action: {
                                signInInitialMode = .auto
                                showSignIn = true
                            }) {
                                chevRow("Save your account", value: "Guest")
                            }.buttonStyle(.plain)
                            Divider().background(Theme.Color.hairline)
                            Button(action: {
                                signInInitialMode = .signIn
                                showSignIn = true
                            }) {
                                chevRow("Sign in to existing account", value: nil)
                            }.buttonStyle(.plain)
                            Divider().background(Theme.Color.hairline)
                        } else {
                            chevRow("Signed in as",
                                    value: auth.currentEmail ?? "—")
                                .padding(.horizontal, 0)
                            Divider().background(Theme.Color.hairline)
                            Button(action: {
                                signInInitialMode = .switchAccount
                                showSignIn = true
                            }) {
                                chevRow("Switch account", value: nil)
                            }.buttonStyle(.plain)
                            Divider().background(Theme.Color.hairline)
                        }
                        Button(action: { showAccountConfirm = .signOut }) { chevRow("Sign out", value: nil) }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: { showAccountConfirm = .delete }) { chevRow("Delete account", value: nil, danger: true) }.buttonStyle(.plain)
                    }

                    // Debug-only — hidden from Release/TestFlight so external
                    // testers don't see internal toggles. Internal builds
                    // (debug schemes from Xcode + the simulator) keep them.
                    #if DEBUG
                    settingsSection(title: "Debug", meta: "Demo only") {
                        Button(action: { store.regenerateTodayPlan() }) {
                            HStack {
                                Text("Regenerate today's plan").font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        // Quick toggle so the planner can be exercised against
                        // both pair patterns without spinning up a real second
                        // user. Aligned = same focuses as me; divergent = the
                        // opposite end (endurance + mobility).
                        Button(action: togglePartnerGoals) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Partner goals: \(partnerGoalsMode)")
                                        .font(Theme.Font.sans(14))
                                        .foregroundColor(Theme.Color.fg)
                                    Text(partnerFocusSummary)
                                        .font(Theme.Font.mono(11))
                                        .foregroundColor(Theme.Color.fgSoft)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.Color.fgFaint)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }.buttonStyle(.plain)
                        Divider().background(Theme.Color.hairline)
                        Button(action: { store.resetOnboarding() }) {
                            HStack {
                                Text("Reset (replay onboarding, clear history)").font(Theme.Font.sans(14)).foregroundColor(Theme.Color.dangerSoft)
                                Spacer()
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }.buttonStyle(.plain)
                    }
                    #endif

                    Text("Tempo · v1.0.0")
                        .labelStyle(color: Theme.Color.fgFaint)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showUnpair) {
            UnpairSheet(partnerName: store.partner.name) {
                // Snapshot the partner name before the unpair clears it
                // so the toast still reads correctly.
                let name = store.partner.name
                Task {
                    if let err = await store.unpair() {
                        store.showToast("Couldn't unpair: \(err)",
                                        icon: "exclamationmark.triangle.fill")
                    } else {
                        store.showToast("Unpaired from \(name)",
                                        icon: "link.badge.plus")
                    }
                    showUnpair = false
                }
            } onCancel: {
                showUnpair = false
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showRelationshipPicker) {
            RelationshipPickerSheet { label, custom in
                store.setRelationshipLabel(label, custom: custom)
                showRelationshipPicker = false
                let noun = RelationshipLabel.noun(label, custom: custom)
                store.showToast("\(store.partner.name) is your \(noun)", icon: "person.2.fill")
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showUnits) {
            UnitsSheet(current: store.profile.units) { newUnits in
                store.profile.units = newUnits
                showUnits = false
                store.showToast("Units set to \(newUnits.label)", icon: "ruler")
            } onCancel: { showUnits = false }
            .presentationDetents([.fraction(0.35)])
            .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showAppearance) {
            AppearanceSheet(current: store.profile.appearance) { mode in
                store.profile.appearance = mode
                showAppearance = false
                store.showToast("Appearance: \(mode.label)", icon: mode.icon)
            } onCancel: { showAppearance = false }
            .presentationDetents([.fraction(0.45)])
            .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showLibrary) {
            CustomExerciseLibrary(onClose: { showLibrary = false })
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $showSignIn) {
            SignInSheet(onClose: { showSignIn = false }, initialMode: signInInitialMode)
                .environmentObject(auth)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.bgElev1)
        }
        .confirmationDialog(
            showProfileMenu ? "Profile" : "",
            isPresented: $showProfileMenu,
            titleVisibility: .hidden
        ) {
            // The system share sheet is wired through a tiny helper view
            // because `confirmationDialog` only takes plain `Button`s.
            Button("Share Tempo with a friend") {
                exportShareItem = ExportShareItem(url: SupportLinks.appStoreURL)
            }
            Button("Send feedback") {
                if let url = SupportLinks.feedbackMailtoURL(),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else {
                    store.showToast("No mail account on this device", icon: "envelope.fill")
                }
            }
            Button("Help & FAQ") {
                UIApplication.shared.open(SupportLinks.helpURL)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(get: { showAccountConfirm != nil }, set: { if !$0 { showAccountConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if showAccountConfirm == .signOut {
                Button("Sign out", role: .destructive) {
                    showAccountConfirm = nil
                    Task {
                        await auth.signOut()
                        store.showToast("Signed out", icon: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else if showAccountConfirm == .delete {
                Button("Delete account", role: .destructive) {
                    showAccountConfirm = nil
                    deletingAccount = true
                    Task {
                        let err = await auth.deleteAccount()
                        deletingAccount = false
                        if let err {
                            store.showToast(err, icon: "exclamationmark.triangle.fill")
                        } else {
                            // Server side deleted the auth.users row;
                            // wipe local state too so the app lands on
                            // onboarding fresh.
                            store.resetOnboarding()
                            store.showToast("Account deleted", icon: "trash.fill")
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { showAccountConfirm = nil }
        }
        .onChange(of: store.profile.sessionRemindersEnabled) { _, v in
            store.showToast(v ? "Session reminders on" : "Session reminders off", icon: "bell.fill")
            if v { Task { await NotificationManager.requestAuthorizationIfNeeded() } }
        }
        .onChange(of: store.profile.partnerActivityNotifs) { _, v in
            store.showToast(v ? "Partner activity on" : "Partner activity off", icon: "person.2.fill")
        }
        .onChange(of: store.profile.aiPlanningEnabled) { _, v in
            store.showToast(v ? "AI trainer on" : "AI trainer off", icon: "sparkles")
        }
        .onChange(of: store.profile.showRPE) { _, v in
            store.showToast(v ? "RPE field on" : "RPE field off", icon: "gauge")
        }
        .onChange(of: store.profile.plateCalcEnabled) { _, v in
            store.showToast(v ? "Plate calculator on" : "Plate calculator off", icon: "circle.hexagongrid.fill")
        }
        .sheet(item: $exportShareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    /// Build a CSV of the user's history and write it into a temp file.
    /// Returned to the share sheet so iOS handles "Save to Files / Mail /
    /// AirDrop" without us reinventing it. The file lives in the temp
    /// directory so it gets cleaned up automatically.
    private func makeExportShareItem() -> ExportShareItem? {
        let csv = CSVExporter.csv(for: store.history)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("tempo-history-\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return ExportShareItem(url: url)
        } catch {
            store.showToast("Couldn't build CSV", icon: "exclamationmark.triangle.fill")
            return nil
        }
    }

    private var confirmTitle: String {
        switch showAccountConfirm {
        case .signOut: return "Sign out?"
        case .delete:  return "Delete account?"
        case .none:    return ""
        }
    }

    private var displayName: String { store.profile.youLabel }
    private var youInitial: String  { store.profile.youInitial }

    // ── Debug helpers: partner goal toggling ─────────────────────────────
    //
    // We compare *sets* of focuses rather than requiring exact equality
    // because the planner only cares whether the pair lands on the same
    // body theme — small overlap is "aligned enough".
    private var partnerGoalsMode: String {
        partnerIsAligned ? "Aligned" : "Divergent"
    }
    private var partnerFocusSummary: String {
        let names = store.partner.focuses.map(\.label).sorted().joined(separator: " · ")
        return names.isEmpty ? "No focuses set" : names
    }
    private var partnerIsAligned: Bool {
        let mine = store.profile.focuses
        let theirs = store.partner.focuses
        guard !mine.isEmpty, !theirs.isEmpty else { return false }
        let overlap = mine.intersection(theirs).count
        let union = mine.union(theirs).count
        return Double(overlap) / Double(union) >= 0.5
    }
    private func togglePartnerGoals() {
        if partnerIsAligned {
            // Push the partner to the *opposite* axis from the user's
            // current focuses. Endurance + mobility is the most visually
            // distinct theme set vs strength/hypertrophy.
            store.partner.focuses = [.endurance, .mobility]
            store.partner.intensity = .easy
        } else {
            // Mirror the user's focuses 1:1 → goal-aligned pair.
            store.partner.focuses = store.profile.focuses
            store.partner.intensity = store.profile.intensity
        }
        store.regenerateTodayPlan()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        store.showToast("Partner goals → \(partnerGoalsMode)", icon: "person.2.fill")
    }
    private var monogramTone: AvatarTone {
        switch store.profile.monogramTone {
        case "you": return .you
        case "partner": return .partner
        case "accent": return .accent
        default: return .neutral
        }
    }
    private var focusSummary: String {
        let f = Array(store.profile.focuses).sorted { $0.rawValue < $1.rawValue }
        return f.isEmpty ? "—" : f.map(\.label).joined(separator: " · ")
    }

    private var planningSummary: String {
        switch store.profile.planningMode {
        case .ai:
            // Surface which planner produced today's plan so users can
            // tell the difference between Apple's on-device tier and the
            // server LLM. `lastPlannerLabel` is empty until the first
            // generation completes — fall back to plain "AI trainer".
            let label = store.lastPlannerLabel
            return label.isEmpty ? "AI trainer" : "AI trainer · \(label)"
        case .manual:
            return "Manual · \(store.profile.manualExerciseIds.count)"
        }
    }

    /// Days since the partnership was created. Reads from
    /// `partner.pairedSinceDate` (set by `applyRemotePartner` from the
    /// server's `pairedSince` timestamp); falls back to 0 when we don't
    /// have a real date yet (just-loaded, never paired, etc.).
    private func daysPaired() -> Int {
        guard let since = store.partner.pairedSinceDate else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let then = cal.startOfDay(for: since)
        return max(0, cal.dateComponents([.day], from: then, to: today).day ?? 0)
    }

    private var partnerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Avatar(initial: store.partner.initial, size: 44, tone: .partner, showDot: true, online: store.partner.online)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.partner.name).font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.Color.fg)
                    Text(partnerSubtitle)
                        .font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                }
                Spacer()
            }

            // Relationship label row (tap to change)
            Button(action: { showRelationshipPicker = true }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13)).foregroundColor(Theme.Color.fgMute)
                    Text(relationshipDescription)
                        .font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fg)
                    Spacer()
                    Text("Change").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgFaint)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(Theme.Color.bgElev2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(PressableStyle())

            HStack {
                statRow("\(store.partner.totalSessions)", "Sessions")
                Spacer()
                statRow(activeTimeString(), "Together")
                Spacer()
                statRow("\(store.partner.jointPRs)", "PRs · joint")
            }

            Button(action: { showUnpair = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                    Text("Unpair from \(store.partner.name)").font(Theme.Font.sans(14, .medium))
                }
                .foregroundColor(Theme.Color.dangerSoft)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Theme.Color.danger.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.danger.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(18)
        .card(padding: 0)
    }

    private var unpairedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You're training solo")
                .font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.Color.fg)
            Text("Invite anyone you'd actually text about a workout — wife, friend, coach. They get their own plan paced to yours.")
                .font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
                .lineSpacing(3)

            ShareLink(item: store.inviteURL,
                      message: Text(store.inviteMessage()),
                      preview: SharePreview("Be my Tempo partner",
                                            image: Image(systemName: "figure.strengthtraining.traditional"))) {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill").font(.system(size: 14, weight: .semibold))
                    Text("Invite via Messages").font(Theme.Font.sans(15, .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Theme.Color.bg)
                .frame(maxWidth: .infinity).frame(height: 48)
                .padding(.horizontal, 18)
                .background(Theme.Color.fg)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(PressableStyle())
            .simultaneousGesture(TapGesture().onEnded {
                if store.pendingInviteToken == nil { store.generatePendingCode() }
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card(padding: 0)
    }

    /// Subtitle shown under the partner's name. Includes the chosen label
    /// when there is one, e.g. "Your wife · in tempo since Mar 28".
    private var partnerSubtitle: String {
        let online = store.partner.online ? "online" : "offline"
        let since  = "since \(store.partner.pairedSinceISO)"
        if store.partner.relationshipLabel != nil || store.partner.relationshipCustom != nil {
            return "Your \(store.partner.noun) · \(since) · \(online)"
        }
        return "In tempo \(since) · \(online)"
    }

    /// Sentence shown on the relationship-label row.
    private var relationshipDescription: String {
        if store.partner.relationshipLabel == nil && store.partner.relationshipCustom == nil {
            return "Tag your relationship with \(store.partner.name)"
        }
        return "\(store.partner.name) is your \(store.partner.noun)"
    }

    private func activeTimeString() -> String {
        let m = store.partner.togetherTimeMinutes
        return "\(m/60)h \(String(format: "%02dm", m%60))"
    }

    private func statRow(_ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 18, weight: .semibold).monospacedDigit()).foregroundColor(Theme.Color.fg)
            Text(unit.uppercased()).font(Theme.Font.mono(10)).tracking(0.8).foregroundColor(Theme.Color.fgSoft)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        meta: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            SectionHead(title: title, meta: meta)
            VStack(spacing: 0) { content() }
                .card(padding: 0)
        }
    }

    private func chevRow(_ label: String, value: String?, danger: Bool = false) -> some View {
        HStack {
            Text(label).font(Theme.Font.sans(14)).foregroundColor(danger ? Theme.Color.dangerSoft : Theme.Color.fg)
            Spacer()
            if let value { Text(value).font(Theme.Font.mono(12)).foregroundColor(Theme.Color.fgSoft).lineLimit(1) }
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func toggleRow(_ label: String, hint: String?, value: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                if let hint { Text(hint).font(Theme.Font.sans(12)).foregroundColor(Theme.Color.fgSoft) }
            }
            Spacer()
            Toggle("", isOn: value).labelsHidden().tint(Theme.Color.accent)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Unpair sheet

private struct UnpairSheet: View {
    var partnerName: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @State private var typed = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: -6) {
                Avatar(initial: "Y", size: 56, tone: .you)
                ZStack {
                    Rectangle().fill(Theme.Color.danger.opacity(0.7)).frame(width: 28, height: 2)
                    Text("✕")
                        .font(Theme.Font.mono(16))
                        .foregroundColor(Theme.Color.dangerSoft)
                        .padding(.horizontal, 4)
                        .background(Theme.Color.bgElev1)
                }
                Avatar(initial: String(partnerName.prefix(1)), size: 56, tone: .partner)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                Text("Unpair from \(partnerName)?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.Color.fg)
                Text("You'll no longer share sessions. Your individual workout history stays.")
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.sans(13))
                    .foregroundColor(Theme.Color.fgSoft)
                    .padding(.horizontal, 8)
            }

            confirmField

            Button(action: onConfirm) {
                Text("Unpair")
                    .font(Theme.Font.sans(16, .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Theme.Color.danger.opacity(typed.uppercased() == partnerName.uppercased() ? 1 : 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(PressableStyle())
            .disabled(typed.uppercased() != partnerName.uppercased())

            Button("Cancel", action: onCancel)
                .font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fgMute)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
    }

    private var confirmField: some View {
        let base = TextField("", text: $typed,
                              prompt: Text(partnerName.uppercased()).foregroundColor(Theme.Color.fgFaint))
            .font(.system(size: 16, weight: .medium).monospacedDigit())
            .foregroundColor(Theme.Color.fg)
            .padding(.horizontal, 14).frame(height: 48)
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
            .autocorrectionDisabled()
        #if os(iOS)
        return AnyView(base.textInputAutocapitalization(.characters))
        #else
        return AnyView(base)
        #endif
    }
}

// MARK: - Units sheet

private struct UnitsSheet: View {
    let current: Units
    var onPick: (Units) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Units").font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fgMute)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Units.allCases, id: \.self) { u in
                    Button(action: { onPick(u) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.label).font(Theme.Font.sans(15)).foregroundColor(Theme.Color.fg)
                                Text("Weight in \(u.weightUnit) · distance in \(u.distanceUnit)")
                                    .font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                            }
                            Spacer()
                            if u == current {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Color.accent)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if u != Units.allCases.last { Divider().background(Theme.Color.hairline) }
                }
            }
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Appearance sheet

private struct AppearanceSheet: View {
    let current: AppearanceMode
    var onPick: (AppearanceMode) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Appearance").font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fgMute)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button(action: { onPick(mode) }) {
                        HStack(spacing: 14) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.Color.fg)
                                .frame(width: 36, height: 36)
                                .background(Theme.Color.bgElev3)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.label).font(Theme.Font.sans(15)).foregroundColor(Theme.Color.fg)
                                Text(mode.subtitle)
                                    .font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                            }
                            Spacer()
                            if mode == current {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Color.accent)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if mode != AppearanceMode.allCases.last { Divider().background(Theme.Color.hairline) }
                }
            }
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Custom exercise library

/// Profile sub-screen for managing the user's custom exercises. List + edit
/// + delete + new. Reuses the same `CustomExerciseSheet` used in-session, so
/// there's exactly one definition surface.
struct CustomExerciseLibrary: View {
    var onClose: () -> Void
    @EnvironmentObject var store: SessionStore

    @State private var editing: CustomExercise? = nil
    @State private var creating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom exercises")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.Color.fg)
                Spacer()
                Button(action: { creating = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("New").font(Theme.Font.sans(13, .semibold))
                    }
                    .foregroundColor(Theme.Color.accentInk)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(Theme.Color.accent)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            if store.profile.customExercises.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.profile.customExercises) { c in
                            row(c)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
                }
            }
        }
        .background(Theme.Color.bgElev1)
        .sheet(item: $editing) { ex in
            CustomExerciseSheet(
                existing: ex,
                onSave: { updated in
                    store.updateCustomExercise(updated)
                    editing = nil
                    store.showToast("Updated \(updated.name)", icon: "checkmark.circle.fill")
                },
                onCancel: { editing = nil }
            )
            .presentationDetents([.large])
            .presentationBackground(Theme.Color.bgElev1)
        }
        .sheet(isPresented: $creating) {
            CustomExerciseSheet(
                existing: nil,
                onSave: { new in
                    store.addCustomExercise(new)
                    creating = false
                    store.showToast("Saved \(new.name)", icon: "plus.circle.fill")
                },
                onCancel: { creating = false }
            )
            .presentationDetents([.large])
            .presentationBackground(Theme.Color.bgElev1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28))
                .foregroundColor(Theme.Color.fgFaint)
            Text("Your library is empty")
                .font(Theme.Font.sans(15, .medium))
                .foregroundColor(Theme.Color.fgMute)
            Text("Tap New to define an exercise that lives in your library forever.\nTag it with muscle groups and the AI trainer can use it too.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    private func row(_ c: CustomExercise) -> some View {
        Button(action: { editing = c }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.name).font(Theme.Font.sans(15, .medium)).foregroundColor(Theme.Color.fg)
                    Text(meta(c)).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Color.fgFaint)
            }
            .padding(14)
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Swipe-to-delete keeps the row compact while still offering destructive
        // action. Confirmation isn't strictly necessary — the entry can be
        // re-created identically — but we soften with a haptic.
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                store.deleteCustomExercise(id: c.id)
                store.showToast("Deleted \(c.name)", icon: "trash")
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func meta(_ c: CustomExercise) -> String {
        let muscles = c.muscleGroups.isEmpty ? "no muscle groups" : c.muscleGroups.joined(separator: " · ")
        switch c.kind {
        case .strength:   return "\(c.kind.label) · \(c.defaultSets)×\(c.defaultReps) · \(c.defaultWeight)lb · \(muscles)"
        case .stretching: return "Stretch · \(muscles)"
        default:          return "\(c.kind.label) · \(muscles)"
        }
    }
}
