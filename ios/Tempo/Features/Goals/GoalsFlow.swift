import SwiftUI

/// Goals questionnaire (4 screens). Editing goals regenerates the AI plan.
struct GoalsFlow: View {
    var onFinish: () -> Void
    @EnvironmentObject var store: SessionStore
    @State private var step = 0
    @State private var showManualPicker = false
    private let total = 5

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                screen
                    .id(step)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showManualPicker) {
            ManualBuilderSheet(profile: $store.profile) {
                showManualPicker = false
                advance()
            }
            .presentationDetents([.large])
            .presentationBackground(Theme.Color.bgElev1)
        }
    }

    private var topBar: some View {
        HStack {
            IconButton(systemName: "chevron.left", size: 36) {
                if step == 0 { onFinish() }
                else { withAnimation { step -= 1 } }
            }
            Spacer()
            Text("\(step + 1) of \(total)").overlineStyle()
            Spacer()
            Button("Skip", action: advance)
                .font(Theme.Font.sans(14))
                .foregroundColor(Theme.Color.fgMute)
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var screen: some View {
        switch step {
        case 0: FocusScreen(profile: $store.profile, onContinue: advance)
        case 1: FrequencyScreen(profile: $store.profile, onContinue: advance)
        case 2: IntensityScreen(profile: $store.profile, onContinue: advance)
        case 3: PlanningModeScreen(
                    profile: $store.profile,
                    onPickAI: { store.profile.planningMode = .ai; advance() },
                    onPickManual: {
                        store.profile.planningMode = .manual
                        showManualPicker = true
                    })
        case 4: StylesScreen(profile: $store.profile, onGenerate: finishAndGenerate)
        default: FocusScreen(profile: $store.profile, onContinue: advance)
        }
    }

    private func advance() {
        withAnimation {
            if step < total - 1 { step += 1 } else { finishAndGenerate() }
        }
    }

    private func finishAndGenerate() {
        store.regenerateTodayPlan()
        onFinish()
    }
}

// MARK: - 1. Primary focus

private struct FocusScreen: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    var body: some View {
        ScaffoldHead(stepLabel: "Goals · 1 of 5",
                     title: "What are you\ntraining for?",
                     subtitle: "Pick up to 2 — your AI trainer will balance them.") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(TrainingFocus.allCases, id: \.self) { f in
                    let on = profile.focuses.contains(f)
                    Button(action: { toggle(f) }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Text(f.subtitle).font(Theme.Font.sans(11.5)).foregroundColor(Theme.Color.fgSoft)
                                Spacer()
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.Color.accent)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(f.label).font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.Color.fg)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 110)
                        .padding(14)
                        .background(on ? Theme.Color.accentDim : Theme.Color.bgElev1)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .strokeBorder(on ? Theme.Color.accentRing : Theme.Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Spacer(minLength: 12)
            PrimaryCTA(title: "Continue", trailingSystemImage: "arrow.right", tall: true, action: onContinue)
                .opacity(profile.focuses.isEmpty ? 0.6 : 1)
                .disabled(profile.focuses.isEmpty)
        }
    }

    private func toggle(_ f: TrainingFocus) {
        if profile.focuses.contains(f) {
            profile.focuses.remove(f)
        } else if profile.focuses.count < 2 {
            profile.focuses.insert(f)
        } else {
            // Replace oldest to enforce "up to 2"
            if let first = profile.focuses.first { profile.focuses.remove(first) }
            profile.focuses.insert(f)
        }
    }
}

// MARK: - 2. Frequency

private struct FrequencyScreen: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    private let dayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
    private let dayShort  = ["M","T","W","T","F","S","S"]

    /// Becomes true the first time the user empties their selection (or hits
    /// Continue with nothing picked). Used to surface the inline error and
    /// nudge the day row with a shake.
    @State private var showError = false
    @State private var shakeNonce = 0

    private var isValid: Bool { !profile.trainingDays.isEmpty }

    var body: some View {
        ScaffoldHead(stepLabel: "Goals · 2 of 5",
                     title: "Which days\ndo you train?",
                     subtitle: "Tap the days you'll actually show up. Your AI trainer plans around them.") {

            VStack(alignment: .leading, spacing: 12) {
                Text("Your training week").labelStyle()
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        dayButton(i)
                    }
                }
                .modifier(ShakeEffect(animatableData: CGFloat(shakeNonce)))
            }
            .padding(.vertical, 8)

            if isValid {
                HStack(spacing: 6) {
                    Text("\(profile.trainingDays.count)")
                        .font(.system(size: 28, weight: .semibold).monospacedDigit())
                        .foregroundColor(Theme.Color.fg)
                    Text(profile.trainingDays.count == 1 ? "day per week" : "days per week")
                        .font(Theme.Font.sans(14))
                        .foregroundColor(Theme.Color.fgMute)
                    Spacer()
                }
            } else if showError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Color.dangerSoft)
                    Text("Pick at least one day to keep going.")
                        .font(Theme.Font.sans(13))
                        .foregroundColor(Theme.Color.dangerSoft)
                    Spacer()
                }
            } else {
                Text("Pick at least one day.")
                    .font(Theme.Font.sans(13))
                    .foregroundColor(Theme.Color.fgMute)
            }

            Spacer(minLength: 12)
            PrimaryCTA(title: "Continue", trailingSystemImage: "arrow.right", tall: true) {
                guard isValid else {
                    showError = true
                    withAnimation(.default) { shakeNonce += 1 }
                    return
                }
                onContinue()
            }
            .opacity(isValid ? 1 : 0.5)
        }
    }

    private func dayButton(_ i: Int) -> some View {
        let on = profile.trainingDays.contains(i)
        return Button(action: { toggle(i) }) {
            VStack(spacing: 6) {
                Text(dayShort[i])
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(on ? Theme.Color.accent : Theme.Color.fg)
                Text(dayLabels[i].uppercased())
                    .font(Theme.Font.mono(9, .medium))
                    .tracking(0.6)
                    .foregroundColor(on ? Theme.Color.accent : Theme.Color.fgFaint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(on ? Theme.Color.accentDim : Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(borderColor(on: on), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func borderColor(on: Bool) -> Color {
        if on { return Theme.Color.accentRing }
        // Tint the empty cells red while the error is visible, so the user
        // can see *what* needs their attention without reading the message.
        if showError && !isValid { return Theme.Color.danger.opacity(0.4) }
        return Theme.Color.hairline
    }

    private func toggle(_ i: Int) {
        if profile.trainingDays.contains(i) {
            profile.trainingDays.remove(i)
        } else {
            profile.trainingDays.insert(i)
        }
        profile.sessionsPerWeek = max(1, profile.trainingDays.count)
        // Clear the error as soon as they have a valid selection again, but
        // surface it the moment they drop back to zero so they're not left
        // wondering why Continue isn't doing anything.
        showError = !isValid
    }
}

/// Horizontal shake — bumped via an Int nonce to retrigger after each
/// invalid Continue tap. Pure SwiftUI, no haptics required.
private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

// MARK: - 3. Intensity

private struct IntensityScreen: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    var body: some View {
        ScaffoldHead(stepLabel: "Goals · 3 of 5",
                     title: "How hard\ndo you want it?",
                     subtitle: "This sets the difficulty curve — you can change it anytime.") {
            VStack(spacing: 8) {
                ForEach(Intensity.allCases, id: \.self) { intensity in
                    let on = profile.intensity == intensity
                    Button(action: { profile.intensity = intensity }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(intensity.label).font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.Color.fg)
                                Text(intensity.subtitle).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgSoft)
                            }
                            Spacer()
                            if on {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.Color.accent)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(on ? Theme.Color.accentDim : Theme.Color.bgElev1)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .strokeBorder(on ? Theme.Color.accentRing : Theme.Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            Text("Your AI trainer dials this up or down based on how you log RPE")
                .font(Theme.Font.mono(10.5))
                .foregroundColor(Theme.Color.fgFaint)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            Spacer(minLength: 12)
            PrimaryCTA(title: "Continue", trailingSystemImage: "arrow.right", tall: true, action: onContinue)
        }
    }
}

// MARK: - 4. Styles (3-state chips)

private struct StylesScreen: View {
    @Binding var profile: UserProfile
    var onGenerate: () -> Void

    private let allStyles = [
        "Free weights", "Machines", "Conditioning", "HIIT",
        "Bodyweight", "Long cardio", "Cycling", "Rowing",
        "Yoga", "Mobility", "Burpees", "Box jumps"
    ]

    var body: some View {
        ScaffoldHead(stepLabel: "Goals · 5 of 5",
                     title: "What do you\nlove and hate?",
                     subtitle: "Tap once to ❤️, again to 🚫.") {
            section("You like", chips: Array(profile.enjoyedStyles), tone: .like)
            section("You'd rather skip", chips: Array(profile.avoidedStyles), tone: .avoid)

            VStack(alignment: .leading, spacing: 8) {
                Text("Everything else").labelStyle()
                FlowLayout(spacing: 8) {
                    let remaining = allStyles.filter {
                        !profile.enjoyedStyles.contains($0) && !profile.avoidedStyles.contains($0)
                    }
                    ForEach(remaining, id: \.self) { s in
                        chip(s, tone: .neutral)
                    }
                }
            }

            Spacer(minLength: 12)
            PrimaryCTA(title: "Generate first plan", trailingSystemImage: "sparkles", tall: true, action: onGenerate)
        }
    }

    enum ChipTone { case like, avoid, neutral }

    @ViewBuilder
    private func section(_ label: String, chips: [String], tone: ChipTone) -> some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(label).labelStyle()
                FlowLayout(spacing: 8) {
                    ForEach(chips, id: \.self) { s in chip(s, tone: tone) }
                }
            }
        }
    }

    private func chip(_ s: String, tone: ChipTone) -> some View {
        let (bg, border, fg, icon): (Color, Color, Color, String?) = {
            switch tone {
            case .like:    return (Theme.Color.accentDim, Theme.Color.accentRing, Theme.Color.accent, "heart.fill")
            case .avoid:   return (Theme.Color.danger.opacity(0.16), Theme.Color.danger.opacity(0.35), Theme.Color.dangerSoft, "nosign")
            case .neutral: return (Theme.Color.bgElev2, Theme.Color.hairline, Theme.Color.fgMute, nil)
            }
        }()
        return Button(action: { advance(s, currentTone: tone) }) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
                Text(s).font(Theme.Font.sans(13, .medium))
            }
            .foregroundColor(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bg)
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    /// Cycle: neutral → like → avoid → neutral.
    private func advance(_ s: String, currentTone: ChipTone) {
        profile.enjoyedStyles.remove(s)
        profile.avoidedStyles.remove(s)
        switch currentTone {
        case .neutral: profile.enjoyedStyles.insert(s)
        case .like:    profile.avoidedStyles.insert(s)
        case .avoid:   break    // back to neutral
        }
    }
}

// MARK: - 4. Planning mode (AI vs Manual)

private struct PlanningModeScreen: View {
    @Binding var profile: UserProfile
    var onPickAI: () -> Void
    var onPickManual: () -> Void

    var body: some View {
        ScaffoldHead(stepLabel: "Goals · 4 of 5",
                     title: "Who designs\nyour sessions?",
                     subtitle: "You can change this anytime.") {

            ForEach(PlanningMode.allCases, id: \.self) { mode in
                let isOn = profile.planningMode == mode
                Button(action: { mode == .ai ? onPickAI() : onPickManual() }) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            if let badge = mode.badge {
                                Text(badge.uppercased())
                                    .labelStyle(color: mode == .ai ? Theme.Color.accent : Theme.Color.fgMute)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(mode == .ai ? Theme.Color.accent : Theme.Color.fgMute)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: mode == .ai ? "sparkles" : "slider.horizontal.3")
                                .font(.system(size: 22))
                                .foregroundColor(mode == .ai ? Theme.Color.accent : Theme.Color.fg)
                                .frame(width: 36, height: 36)
                                .background(mode == .ai ? Theme.Color.accentDim : Theme.Color.bgElev3)
                                .clipShape(Circle())

                            Text(mode.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Theme.Color.fg)
                        }

                        Text(mode.subtitle)
                            .font(Theme.Font.sans(13))
                            .foregroundColor(Theme.Color.fgMute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(isOn ? Theme.Color.accentDim : Theme.Color.bgElev1)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .strokeBorder(
                                mode == .ai
                                    ? Theme.Color.accent.opacity(0.4)
                                    : Theme.Color.hairline,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(PressableStyle())
            }

            if profile.planningMode == .manual && !profile.manualExerciseIds.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(Theme.Color.accent)
                    Text("\(profile.manualExerciseIds.count) exercises picked")
                        .font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgMute)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Manual exercise builder

struct ManualBuilderSheet: View {
    @Binding var profile: UserProfile
    var onDone: () -> Void
    @State private var search: String = ""
    @State private var picked: [String]

    init(profile: Binding<UserProfile>, onDone: @escaping () -> Void) {
        _profile = profile
        self.onDone = onDone
        _picked = State(initialValue: profile.wrappedValue.manualExerciseIds)
    }

    /// Merged list: built-in catalog + user's custom exercises. Custom
    /// entries are tagged via `customIds` so the row UI can show a CUSTOM
    /// badge without having to re-cross-reference the profile.
    private var customIds: Set<String> {
        Set(profile.customExercises.map(\.id))
    }
    private var mergedCatalog: [CatalogExercise] {
        ExerciseCatalog.all + profile.customExercises.map { $0.asCatalog() }
    }
    private var filteredCatalog: [CatalogExercise] {
        let q = search.lowercased()
        return mergedCatalog.filter { c in
            q.isEmpty || c.name.lowercased().contains(q) || c.muscleGroups.contains { $0.lowercased().contains(q) }
        }
    }

    private var groupedByMuscle: [(String, [CatalogExercise])] {
        // Pull customs into their own visually distinct section at the top,
        // so the user's library is always one glance away.
        let customs = filteredCatalog.filter { customIds.contains($0.id) }
        let builtins = filteredCatalog.filter { !customIds.contains($0.id) }
        var groups: [(String, [CatalogExercise])] = []
        if !customs.isEmpty { groups.append(("Your library", customs)) }
        let byGroup = Dictionary(grouping: builtins) { $0.muscleGroups.first ?? "Other" }
        groups.append(contentsOf: byGroup.sorted { $0.key < $1.key })
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                    ForEach(groupedByMuscle, id: \.0) { group, items in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.uppercased()).overlineStyle()
                                .padding(.horizontal, 20)
                            VStack(spacing: 0) {
                                ForEach(items) { ex in
                                    row(ex)
                                    if ex.id != items.last?.id {
                                        Divider().background(Theme.Color.hairline)
                                    }
                                }
                            }
                            .background(Theme.Color.bgElev2)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                            .padding(.horizontal, 20)
                        }
                    }
                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
            }

            VStack {
                PrimaryCTA(
                    title: "Done · \(picked.count) exercise\(picked.count == 1 ? "" : "s")",
                    trailingSystemImage: "checkmark",
                    tall: true
                ) {
                    profile.manualExerciseIds = picked
                    onDone()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(colors: [Theme.Color.bgElev1.opacity(0), Theme.Color.bgElev1],
                               startPoint: .top, endPoint: .center)
            )
        }
        .background(Theme.Color.bgElev1)
    }

    private var header: some View {
        HStack {
            Button(action: onDone) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Color.fgMute)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.bgElev2)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Build your session").font(Theme.Font.sans(17, .semibold)).foregroundColor(Theme.Color.fg)
                Text("Tap to add or remove").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var searchField: some View {
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
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Color.fgFaint)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Theme.Color.bgElev2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func row(_ ex: CatalogExercise) -> some View {
        let isPicked = picked.contains(ex.id)
        return Button(action: { toggle(ex.id) }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isPicked ? Theme.Color.accent : Theme.Color.hairline, lineWidth: isPicked ? 0 : 1)
                        .background(Circle().fill(isPicked ? Theme.Color.accent : Color.clear))
                    if isPicked {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.Color.accentInk)
                    }
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(ex.name).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                        if customIds.contains(ex.id) {
                            Text("CUSTOM")
                                .font(Theme.Font.mono(9, .medium)).tracking(0.6)
                                .foregroundColor(Theme.Color.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Color.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(metaLabel(ex)).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func metaLabel(_ ex: CatalogExercise) -> String {
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

    private func toggle(_ id: String) {
        if let i = picked.firstIndex(of: id) {
            picked.remove(at: i)
        } else {
            picked.append(id)
        }
    }
}

// MARK: - Shared scaffold

private struct ScaffoldHead<Content: View>: View {
    var stepLabel: String
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stepLabel.uppercased()).overlineStyle()
                Text(title)
                    .font(.system(size: 32, weight: .semibold))
                    .kerning(-0.8)
                    .foregroundColor(Theme.Color.fg)
                if let subtitle {
                    Text(subtitle).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fgMute).padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }
}
