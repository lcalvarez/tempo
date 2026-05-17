import SwiftUI
import PhotosUI

/// Interactive onboarding flow (7 screens). Reads/writes the live SessionStore
/// so every input persists through to the rest of the app.
struct OnboardingFlow: View {
    var onFinish: () -> Void
    @EnvironmentObject var store: SessionStore

    @State private var step = 0
    private let total = 7

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if step > 0 {
                    progressDots
                }

                screen(for: step)
                    .id(step)
                    .transition(.opacity)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Rectangle()
                    .fill(i <= step ? Theme.Color.accent : Theme.Color.bgElev3)
                    .frame(width: 16, height: 3)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func screen(for i: Int) -> some View {
        switch i {
        case 0: WelcomeScreen(onContinue: { advance() })
        case 1: SignInScreen(onContinue: { advance() })
        case 2: PhotoScreen(profile: $store.profile, onContinue: { advance() })
        case 3: AboutYouScreen(profile: $store.profile, onContinue: { advance() })
        case 4: PairChoiceScreen(onSendInvite: {
                    store.generatePendingCode()
                    advance()
                }, onPaired: {
                    step = 6   // partner accepted my code, jump to Ready
                }, onPairLater: {
                    step = 6   // skip to ready
                })
        case 5: PendingCodeScreen(code: store.pendingCode ?? "",
                                  onSkipForNow: { advance() })
        case 6: ReadyScreen(profile: store.profile, partner: store.partner, onContinue: finish)
        default: WelcomeScreen(onContinue: { advance() })
        }
    }

    private func advance() {
        withAnimation { step = min(total - 1, step + 1) }
    }

    private func finish() {
        store.completeOnboarding()
        onFinish()
    }
}

// MARK: - 1. Welcome

private struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandMark()
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)

            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text("Train with anyone · in rhythm".uppercased()).overlineStyle()
                (Text("Train together.\n").foregroundColor(Theme.Color.fg)
                 + Text("In tempo.").foregroundColor(Theme.Color.fgMute))
                    .font(.system(size: 44, weight: .semibold))
                    .kerning(-1.3)
                    .lineSpacing(0)

                HStack(spacing: 6) {
                    Capsule().fill(Theme.Color.you).frame(height: 4)
                    Capsule().fill(Theme.Color.partner).frame(height: 4)
                }
                .padding(.vertical, 8)

                Text("Two people, one timeline. Different workouts paced to the same rhythm — so you start, sweat, and finish in sync.")
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fgMute)
                    .lineSpacing(4)
                Spacer()
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                PrimaryCTA(title: "Get started", trailingSystemImage: "arrow.right", tall: true, action: onContinue)
                Button("I already have an account") {}
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fgMute)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - 2. Sign in

private struct SignInScreen: View {
    var onContinue: () -> Void

    @State private var showEmailSheet = false

    var body: some View {
        // Two real paths in v1:
        //   • "Continue with email" → opens the SignInSheet (sign-up
        //     creates a real auth.users row tied to email; the onboarding
        //     advances when the sheet closes).
        //   • "Continue as guest" → the anonymous-sign-in path. The user
        //     can convert later from Profile → "Save your account".
        //
        // Sign in with Apple is intentionally *not* shown here. The
        // capability + AuthStore method exist, but the onboarding wiring
        // and Apple Developer Services-ID config aren't done yet, and
        // shipping a button that does nothing is worse than not shipping
        // it. We'll add it back in v1.1.
        OBScaffold(stepLabel: "Step 1 of 5", title: "Sign in to\nget started",
                   subtitle: "Or continue as a guest — you can save later.") {
            Spacer(minLength: 36)

            PrimaryCTA(title: "Continue with email") {
                showEmailSheet = true
            }

            HStack {
                Rectangle().fill(Theme.Color.hairline).frame(height: 1)
                Text("or").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                Rectangle().fill(Theme.Color.hairline).frame(height: 1)
            }
            .padding(.vertical, 4)

            SecondaryCTA(title: "Continue as guest", height: 56, action: onContinue)

            Text("By continuing, you agree to our Terms and Privacy Policy.")
                .font(Theme.Font.sans(12))
                .foregroundColor(Theme.Color.fgFaint)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showEmailSheet) {
            SignInSheet(
                onClose: {
                    showEmailSheet = false
                    // Whether the user signed up or backed out, they've
                    // had their chance — let onboarding move forward so
                    // they can finish setup. Worst case (sheet dismissed
                    // without action) they're still on the anon session
                    // they had on launch, exactly the "guest" path.
                    onContinue()
                },
                initialMode: .auto
            )
        }
    }
}

// MARK: - 3. Photo

private struct PhotoScreen: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    private let tones: [(String, AvatarTone)] = [
        ("you", .you), ("partner", .partner), ("accent", .accent), ("neutral", .neutral)
    ]

    /// Selection from `PhotosPicker`. We watch this with `.onChange` and
    /// load the selected image into a compressed JPEG that we stash on
    /// `profile.avatarData`. The picker resets to `nil` after each load
    /// so the user can pick a different photo without our state caring
    /// what the old item was.
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var loading = false

    var body: some View {
        OBScaffold(
            stepLabel: "Step 2 of 5 · Photo",
            title: "Pick a photo\n(or skip).",
            subtitle: "So your partner can recognize you when you pair. You can change it anytime."
        ) {
            // Avatar preview. Tapping the circle is the main affordance —
            // it opens the system photo picker. If a photo is already
            // chosen we render it inside the circle and fall back to the
            // dashed placeholder otherwise.
            HStack {
                Spacer()
                PhotosPicker(selection: $pickerItem,
                             matching: .images,
                             photoLibrary: .shared()) {
                    avatarPreview
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 12)

            HStack(spacing: 10) {
                // PhotosPicker again, formatted as a secondary CTA so
                // the user has a labeled affordance even if the circle
                // doesn't read as tappable. Camera is a separate path.
                PhotosPicker(selection: $pickerItem,
                             matching: .images,
                             photoLibrary: .shared()) {
                    SecondaryCTALabel(title: "Choose from library",
                                      leadingSystemImage: "photo",
                                      height: 48)
                }
                if profile.avatarData != nil {
                    SecondaryCTA(title: "Remove",
                                 leadingSystemImage: "trash",
                                 height: 48) {
                        profile.avatarData = nil
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Or pick a monogram").labelStyle()
                HStack(spacing: 10) {
                    Spacer()
                    ForEach(0..<tones.count, id: \.self) { i in
                        let (id, tone) = tones[i]
                        let initial = profile.name.first.map(String.init)?.uppercased() ?? "A"
                        Button(action: { profile.monogramTone = id }) {
                            Avatar(initial: initial, size: 48, tone: tone)
                                .overlay(
                                    Circle().strokeBorder(
                                        profile.monogramTone == id ? Theme.Color.accent : Theme.Color.hairline,
                                        lineWidth: profile.monogramTone == id ? 2 : 1
                                    )
                                )
                        }
                        .buttonStyle(PressableStyle())
                    }
                    Spacer()
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 20)
            PrimaryCTA(title: "Continue", trailingSystemImage: "arrow.right", tall: true, action: onContinue)
            Button("Skip — I'll add a photo later", action: onContinue)
                .font(Theme.Font.sans(14))
                .foregroundColor(Theme.Color.fgMute)
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            loading = true
            Task { @MainActor in
                defer { loading = false; pickerItem = nil }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let img = UIImage(data: data),
                   let resized = img.resizedAndCompressedJPEG(maxSide: 512, quality: 0.7) {
                    profile.avatarData = resized
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        ZStack {
            if let data = profile.avatarData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 168, height: 168)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.Color.border, lineWidth: 1.5))
            } else {
                Circle().fill(Theme.Color.bgElev1)
                Circle().strokeBorder(Theme.Color.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                VStack(spacing: 8) {
                    Image(systemName: "camera").font(.system(size: 36)).foregroundColor(Theme.Color.fgSoft)
                    Text(loading ? "Loading…" : "Tap to add").labelStyle(color: Theme.Color.fgMute)
                }
            }
        }
        .frame(width: 168, height: 168)
    }
}

/// Static label that mirrors `SecondaryCTA`'s look without consuming the
/// tap (the wrapping `PhotosPicker` handles tap). Pulled out so the
/// outer button doesn't double-trigger.
private struct SecondaryCTALabel: View {
    let title: String
    let leadingSystemImage: String
    var height: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: leadingSystemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title).font(Theme.Font.sans(15, .semibold))
        }
        .foregroundColor(Theme.Color.fg)
        .frame(maxWidth: .infinity).frame(height: height)
        .background(Theme.Color.bgElev2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(Theme.Color.border, lineWidth: 1)
        )
    }
}

private extension UIImage {
    /// Downscale + JPEG-compress so the avatar isn't a 4 MB chunk on
    /// every Profile load. 512px on the longest edge is plenty for
    /// retina rendering at the largest size we use (168pt).
    func resizedAndCompressedJPEG(maxSide: CGFloat, quality: CGFloat) -> Data? {
        let scale = min(maxSide / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

// MARK: - 4. About you (the real form)

private struct AboutYouScreen: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void
    @FocusState private var nameFocused: Bool
    @FocusState private var ageFocused: Bool

    private let equipmentOptions = ["Full gym", "Home rack", "Dumbbells", "Bands", "Bodyweight only"]
    private let timeOptions = ["Early morning", "Morning", "Midday", "Evening", "Late"]

    var body: some View {
        OBScaffold(
            stepLabel: "Step 3 of 5 · About you",
            title: "A few things\nabout you.",
            subtitle: "So your AI trainer can plan workouts that fit."
        ) {
            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Name").labelStyle()
                TextField("", text: $profile.name,
                          prompt: Text("Your name").foregroundColor(Theme.Color.fgFaint))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Theme.Color.fg)
                    .focused($nameFocused)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Theme.Color.bgElev2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(nameFocused ? Theme.Color.accent : Theme.Color.hairline, lineWidth: 1))
            }

            // Age + Units
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age").labelStyle()
                    TextField("", value: $profile.age, format: .number,
                              prompt: Text("30").foregroundColor(Theme.Color.fgFaint))
                        .font(.system(size: 17, weight: .medium).monospacedDigit())
                        .foregroundColor(Theme.Color.fg)
                        .keyboardType(.numberPad)
                        .focused($ageFocused)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Theme.Color.bgElev2)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .strokeBorder(ageFocused ? Theme.Color.accent : Theme.Color.hairline, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Units").labelStyle()
                    SegmentedControl(
                        options: Units.allCases.map { ($0.label, $0) },
                        selection: $profile.units
                    )
                }
                .frame(maxWidth: .infinity)
            }

            // Fitness level
            VStack(alignment: .leading, spacing: 8) {
                Text("Fitness level").labelStyle()
                SegmentedControl(
                    options: FitnessLevel.allCases.map { ($0.label, $0) },
                    selection: $profile.fitnessLevel
                )
            }

            // Equipment
            VStack(alignment: .leading, spacing: 8) {
                Text("Equipment").labelStyle()
                ChipMultiSelect(options: equipmentOptions, selection: $profile.equipment)
            }

            // Workout times
            VStack(alignment: .leading, spacing: 8) {
                Text("Usual workout times").labelStyle()
                ChipMultiSelect(options: timeOptions, selection: $profile.workoutTimes)
            }

            // Injuries
            VStack(alignment: .leading, spacing: 8) {
                Text("Injuries / limitations (optional)").labelStyle()
                TextEditorView(text: $profile.injuries, placeholder: "e.g. lower back, right knee")
                    .frame(height: 72)
                    .background(Theme.Color.bgElev2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
            }

            Spacer(minLength: 12)
            PrimaryCTA(title: "Continue", trailingSystemImage: "arrow.right", tall: true,
                       action: { dismissKeyboard(); onContinue() })
        }
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private func dismissKeyboard() {
        nameFocused = false
        ageFocused = false
    }
}

// MARK: - 5. Pair choice

private struct PairChoiceScreen: View {
    var onSendInvite: () -> Void
    /// Called after the user successfully redeems a code from their partner.
    var onPaired: () -> Void
    var onPairLater: () -> Void

    @State private var showEnterCode = false

    var body: some View {
        OBScaffold(
            stepLabel: "Step 4 of 5 · Pair up",
            title: "Connect with\nyour partner.",
            subtitle: "You'll train in sync. They get a personalized plan too."
        ) {
            Button(action: onSendInvite) {
                pairCard(
                    label: "Recommended",
                    labelColor: Theme.Color.accent,
                    title: "Send your partner an invite",
                    subtitle: "We'll generate a code you can text them. They sign up and you're connected.",
                    borderColor: Theme.Color.accent.opacity(0.4)
                )
            }.buttonStyle(PressableStyle())

            Button(action: { showEnterCode = true }) {
                pairCard(
                    label: "If they invited you",
                    labelColor: Theme.Color.fgMute,
                    title: "Enter their code",
                    subtitle: "Got a 6-letter code from your partner? Enter it to connect.",
                    borderColor: Theme.Color.hairline
                )
            }.buttonStyle(PressableStyle())

            Spacer()
            Button("Pair later — let me look around first", action: onPairLater)
                .font(Theme.Font.sans(14))
                .foregroundColor(Theme.Color.fgSoft)
        }
        .sheet(isPresented: $showEnterCode) {
            EnterCodeSheet(onSuccess: {
                showEnterCode = false
                onPaired()
            })
            .presentationDetents([.medium])
            .presentationBackground(Theme.Color.bgElev1)
        }
    }

    private func pairCard(label: String, labelColor: Color, title: String, subtitle: String, borderColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label.uppercased()).labelStyle(color: labelColor)
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold)).foregroundColor(labelColor)
            }
            Text(title).font(.system(size: 22, weight: .semibold)).foregroundColor(Theme.Color.fg)
            Text(subtitle).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.bgElev1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(borderColor, lineWidth: 1))
    }
}

// MARK: - Enter-code sheet (counterpart to "Send your partner an invite")
//
// Presented from `PairChoiceScreen` when the user picks "Enter their code".
// Calls the live `accept_pair_invite` RPC via `SessionStore.acceptPartner`,
// surfaces the server's error string inline on failure, and dismisses on
// success so the onboarding flow can advance to ReadyScreen.

private struct EnterCodeSheet: View {
    var onSuccess: () -> Void

    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var submitting = false
    @State private var errorText: String? = nil
    @FocusState private var focused: Bool

    /// Server expects A–Z + 0–9, 6 chars (matches `create_pair_invite`).
    private var normalized: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    private var canSubmit: Bool { normalized.count == 6 && !submitting }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Enter their code".uppercased()).overlineStyle()
                Text("Pair up").font(.system(size: 26, weight: .semibold)).foregroundColor(Theme.Color.fg)
                Text("Type the 6-character code your partner sent you.")
                    .font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
            }

            TextField("ABC123", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .font(.system(size: 28, weight: .semibold).monospaced())
                .multilineTextAlignment(.center)
                .focused($focused)
                .padding(.vertical, 14)
                .background(Theme.Color.bgElev2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
                .onChange(of: code) { _, newValue in
                    let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    if cleaned != newValue { code = cleaned }
                    errorText = nil
                }

            if let errorText {
                Text(errorText)
                    .font(Theme.Font.sans(13))
                    .foregroundColor(Theme.Color.dangerSoft)
            }

            Spacer()

            PrimaryCTA(
                title: submitting ? "Connecting…" : "Connect",
                trailingSystemImage: submitting ? nil : "arrow.right",
                tall: true,
                action: submit
            )
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .padding(24)
        .onAppear { focused = true }
    }

    private func submit() {
        guard canSubmit else { return }
        submitting = true
        errorText = nil
        Task { @MainActor in
            let err = await store.acceptPartner(code: normalized)
            submitting = false
            if let err {
                errorText = err
            } else {
                onSuccess()
            }
        }
    }
}

// MARK: - 6. Pending code

private struct PendingCodeScreen: View {
    var code: String
    var onSkipForNow: () -> Void

    var body: some View {
        OBScaffold(
            stepLabel: "Step 5 of 5 · Almost there",
            title: "Send this code\nto your partner.",
            subtitle: nil
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    let split = splitCode(code)
                    ForEach(0..<split.first.count, id: \.self) { i in codeDigit(String(split.first[i])) }
                    Text("—").font(.system(size: 28, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
                    ForEach(0..<split.second.count, id: \.self) { i in codeDigit(String(split.second[i])) }
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Theme.Color.bgElev1)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.Color.hairline, lineWidth: 1))

                Text("Expires in 24 hours").labelStyle()
            }

            HStack(spacing: 14) {
                Avatar(initial: "?", size: 44, tone: .neutral)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waiting for your partner".uppercased()).overlineStyle(color: Theme.Color.fg)
                    Text("Send them the code — Tempo pairs you automatically once they enter it.")
                        .font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                SecondaryCTA(title: "Copy", leadingSystemImage: "doc.on.doc") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = code
                    #endif
                }
                ShareLink(item: "Pair with me on Tempo — code: \(code)") {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                        Text("Share").font(Theme.Font.sans(15, .medium))
                    }
                    .foregroundColor(Theme.Color.fg)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Theme.Color.bgElev2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.border, lineWidth: 1))
                }
            }

            Spacer()
            PrimaryCTA(title: "I'll do this later",
                       trailingSystemImage: "arrow.right",
                       action: onSkipForNow)

            Text("Your partner accepts on their phone — once they do, the app updates automatically.")
                .font(Theme.Font.sans(12))
                .foregroundColor(Theme.Color.fgMute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private func splitCode(_ code: String) -> (first: [Character], second: [Character]) {
        let chars = Array(code.isEmpty ? "AX7K9P" : code)
        let mid = chars.count / 2
        return (Array(chars.prefix(mid)), Array(chars.suffix(chars.count - mid)))
    }

    private func codeDigit(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 36, weight: .semibold).monospacedDigit())
            .frame(width: 44, height: 60)
            .background(Theme.Color.bgElev2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Color.hairline, lineWidth: 1))
            .foregroundColor(Theme.Color.fg)
    }
}

// MARK: - 7. Ready

private struct ReadyScreen: View {
    var profile: UserProfile
    var partner: PartnerProfile
    var onContinue: () -> Void
    @EnvironmentObject var store: SessionStore

    /// Show a "you + partner" celebration only if pairing actually completed.
    /// Users who picked "I'll pair later" land here too — for them we want a
    /// simpler "your profile is ready" framing, no fake partner avatar.
    private var hasRealPartner: Bool { store.isPaired }

    var body: some View {
        VStack {
            Spacer()
            if hasRealPartner {
                HStack(spacing: -8) {
                    Avatar(initial: profile.name.first.map(String.init)?.uppercased() ?? "Y", size: 64, tone: .you)
                    Rectangle().fill(Theme.Color.accent).frame(width: 40, height: 2)
                    Avatar(initial: partner.initial, size: 64, tone: .partner)
                }
                .padding(.bottom, 24)

                Text("Paired".uppercased()).overlineStyle(color: Theme.Color.accent)
                (Text("You and \(partner.name)\n").foregroundColor(Theme.Color.fg)
                 + Text("are ready.").foregroundColor(Theme.Color.fgMute))
                    .font(.system(size: 32, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .kerning(-0.8)
                    .padding(.top, 8)
            } else {
                Avatar(initial: profile.name.first.map(String.init)?.uppercased() ?? "Y", size: 72, tone: .you)
                    .padding(.bottom, 24)

                Text("Profile saved".uppercased()).overlineStyle(color: Theme.Color.accent)
                (Text("You're\n").foregroundColor(Theme.Color.fg)
                 + Text("ready.").foregroundColor(Theme.Color.fgMute))
                    .font(.system(size: 32, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .kerning(-0.8)
                    .padding(.top, 8)
            }

            Text(hasRealPartner
                 ? "Next: a quick goals questionnaire so we can plan your first session together."
                 : "Next: a quick goals questionnaire so we can plan your first session. You can invite a partner anytime from your profile.")
                .font(Theme.Font.sans(14))
                .foregroundColor(Theme.Color.fgMute)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            Spacer()
            PrimaryCTA(title: "Set your goals", trailingSystemImage: "arrow.right", tall: true, action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    private func miniStat(_ v: String, _ u: String) -> some View {
        VStack(spacing: 4) {
            Text(v).font(.system(size: 22, weight: .semibold).monospacedDigit()).foregroundColor(Theme.Color.fg)
            Text(u.uppercased()).labelStyle()
        }
    }
}

// MARK: - Scaffold + reusable controls

private struct OBScaffold<Content: View>: View {
    var stepLabel: String
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
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
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .padding(.horizontal, 24)
            }
        }
    }
}

/// Generic segmented control that binds to any Hashable.
struct SegmentedControl<T: Hashable>: View {
    var options: [(String, T)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { i in
                let opt = options[i]
                Button(action: { selection = opt.1 }) {
                    Text(opt.0)
                        .font(Theme.Font.sans(13, .medium))
                        .foregroundColor(selection == opt.1 ? Theme.Color.fg : Theme.Color.fgMute)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(selection == opt.1 ? Theme.Color.bgElev3 : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.Color.bgElev2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }
}

/// Wrap-flow of selectable chips; toggles membership in `selection`.
struct ChipMultiSelect: View {
    var options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let on = selection.contains(opt)
                Button(action: { toggle(opt) }) {
                    Text(opt)
                        .font(Theme.Font.sans(13, .medium))
                        .foregroundColor(on ? Theme.Color.accent : Theme.Color.fgMute)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(on ? Theme.Color.accentDim : Theme.Color.bgElev2)
                        .overlay(
                            Capsule().strokeBorder(on ? Theme.Color.accentRing : Theme.Color.hairline, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func toggle(_ value: String) {
        if selection.contains(value) { selection.remove(value) }
        else { selection.insert(value) }
    }
}

/// Simple flow / wrap layout for chip groups.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let result = arrange(subviews: subviews, in: width)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (idx, sub) in subviews.enumerated() {
            sub.place(at: CGPoint(x: bounds.minX + result.offsets[idx].x,
                                  y: bounds.minY + result.offsets[idx].y),
                      proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> (size: CGSize, offsets: [CGPoint]) {
        var offsets: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 {
                x = 0; y += lineH + spacing; lineH = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return (CGSize(width: width, height: y + lineH), offsets)
    }
}

/// Cross-platform multiline text editor wrapper.
struct TextEditorView: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Theme.Font.sans(14))
                    .foregroundColor(Theme.Color.fgFaint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            TextEditor(text: $text)
                .font(Theme.Font.sans(14))
                .foregroundColor(Theme.Color.fg)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .scrollContentBackground(.hidden)
        }
    }
}
