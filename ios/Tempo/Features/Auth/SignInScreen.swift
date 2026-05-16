import SwiftUI

// `SignInSheet` (instead of `SignInScreen`) to avoid colliding with the
// onboarding flow's own private `SignInScreen` placeholder, which uses
// Apple-only and lives in a different lifecycle phase.

/// Email/password authentication surface. We split intent into three
/// explicit modes instead of one ambiguous "Continue" button:
///
///   • `.saveAccount` — anonymous user wants to upgrade in place. We
///      call `linkEmailToCurrentUser`, which keeps `auth.uid()` stable
///      so all of their guest-mode data (profile, sessions, partnership)
///      carries over.
///
///   • `.signIn` — user already has an account on another device and
///      wants their data on this one. **If they're currently anonymous
///      this is destructive** — the guest account on this device gets
///      orphaned (its rows are still on the server, but this device
///      will be bound to a different `auth.uid()` afterwards). We make
///      that consequence visible and require an explicit confirmation
///      tap before performing it.
///
///   • `.switchAccount` — user is *already* on a permanent account and
///      wants to log in as somebody else. Mostly a clean call: sign out,
///      then sign in with the new credentials. (We treat the sign-out
///      as implicit; the user already understands they're logging out.)
///
/// We deliberately keep the visuals minimal — Apple Sign In is the
/// long-term primary path; this is the email/password fallback that
/// works in the simulator and as an account-portability escape hatch.
struct SignInSheet: View {
    var onClose: () -> Void

    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var store: SessionStore
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var mode: Mode
    @State private var inFlight = false
    @State private var inlineError: String?
    @State private var showAbandonConfirm = false
    @FocusState private var focusedField: Field?

    init(onClose: @escaping () -> Void, initialMode: InitialMode = .auto) {
        self.onClose = onClose
        // Initial mode is computed once. Once the sheet is shown, the
        // user can toggle freely; we don't try to flip back if their
        // anon state changes mid-sheet (they shouldn't be able to).
        switch initialMode {
        case .auto:          _mode = State(initialValue: .saveAccount)
        case .signIn:        _mode = State(initialValue: .signIn)
        case .switchAccount: _mode = State(initialValue: .switchAccount)
        }
    }

    /// Public-facing initial-mode hint. Mirrors the private `Mode` enum
    /// but with a `.auto` default that resolves to "save my account."
    enum InitialMode { case auto, signIn, switchAccount }

    private enum Mode {
        case saveAccount      // anon → permanent (data preserved)
        case signIn           // sign in to existing (anon = destructive)
        case switchAccount    // permanent → permanent (sign out + sign in)
    }
    private enum Field { case email, password }

    private var headerTitle: String {
        switch mode {
        case .saveAccount:   return "Save your account"
        case .signIn:        return "Sign in"
        case .switchAccount: return "Switch account"
        }
    }

    private var primaryTitle: String {
        switch mode {
        case .saveAccount:   return "Save my account"
        case .signIn:        return auth.isAnonymous ? "Sign in (replaces guest)" : "Sign in"
        case .switchAccount: return "Sign out & sign in"
        }
    }

    private var canSubmit: Bool {
        !inFlight
            && email.contains("@")
            && password.count >= 6
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    explainer

                    field(label: "Email",
                          systemImage: "envelope",
                          text: $email,
                          isSecure: false,
                          contentType: .emailAddress,
                          keyboard: .emailAddress,
                          focused: .email)

                    field(label: "Password",
                          systemImage: "lock",
                          text: $password,
                          isSecure: true,
                          contentType: .password,
                          keyboard: .default,
                          focused: .password)

                    if let inlineError {
                        Label(inlineError, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.Font.sans(12))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }

                    Button(action: handlePrimary) {
                        HStack(spacing: 8) {
                            if inFlight {
                                ProgressView().controlSize(.small).tint(Theme.Color.fg)
                            }
                            Text(primaryTitle).font(Theme.Font.sans(15, .semibold))
                        }
                        .foregroundColor(Theme.Color.fg)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(canSubmit ? Theme.Color.accent : Theme.Color.bgElev2)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }
                    .disabled(!canSubmit)

                    modeToggle
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .alert("Replace guest data?", isPresented: $showAbandonConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Replace", role: .destructive) {
                Task { await performSignIn(replaceAnon: true) }
            }
        } message: {
            Text(replaceConfirmCopy)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(Theme.Font.display(22, .semibold))
                .foregroundColor(Theme.Color.fg)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Color.fgFaint)
                    .frame(width: 32, height: 32)
                    .background(Theme.Color.bgElev2)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// One short paragraph explaining the consequence of the chosen mode.
    /// We deliberately spell out the destructive case ("guest data won't
    /// follow you") instead of relying on the alert alone — readers who
    /// skim past alerts still see it here.
    @ViewBuilder
    private var explainer: some View {
        switch mode {
        case .saveAccount where auth.isAnonymous:
            Text("You've been training as a guest. Add an email and password and your workouts, partner, and goals follow you to any device.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
        case .saveAccount:
            // Non-anon hitting "save account" doesn't really happen
            // (we hide the entry point), but cover it harmlessly.
            Text("Create a new account with this email and password.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
        case .signIn where auth.isAnonymous:
            Text("Sign in to an account you already created. Heads up — your current guest progress on this device won't follow you to that account.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
        case .signIn:
            Text("Welcome back. Sign in with the email you used last time and your data syncs down on this device.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
        case .switchAccount:
            Text("Sign out of \(auth.currentEmail ?? "your current account") and sign in as somebody else. We'll keep your account safe — you can come back any time.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
        }
    }

    /// One or two text-button toggles depending on what mode the user is
    /// in — keeps the surface area small while still being explicit.
    @ViewBuilder
    private var modeToggle: some View {
        HStack(spacing: 16) {
            switch mode {
            case .saveAccount:
                toggleButton("I already have an account") { setMode(.signIn) }
            case .signIn:
                toggleButton(auth.isAnonymous ? "Save guest account instead" : "Create a new account") { setMode(.saveAccount) }
                if !auth.isAnonymous {
                    toggleButton("Switch accounts") { setMode(.switchAccount) }
                }
            case .switchAccount:
                toggleButton("Cancel — keep current account", role: .cancel) { onClose() }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func toggleButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(Theme.Font.sans(13, .medium))
                .foregroundColor(Theme.Color.fgSoft)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func field(label: String,
                       systemImage: String,
                       text: Binding<String>,
                       isSecure: Bool,
                       contentType: UITextContentType,
                       keyboard: UIKeyboardType,
                       focused: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Theme.Font.mono(10, .medium))
                .tracking(0.6)
                .foregroundColor(Theme.Color.fgFaint)
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Color.fgFaint)
                Group {
                    if isSecure {
                        SecureField("", text: text)
                    } else {
                        TextField("", text: text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .focused($focusedField, equals: focused)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .font(Theme.Font.sans(15))
                .foregroundColor(Theme.Color.fg)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Theme.Color.bgElev1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Color.hairline, lineWidth: 1))
        }
    }

    // MARK: - Mode handling

    private func setMode(_ next: Mode) {
        inlineError = nil
        mode = next
    }

    /// "Are you sure?" copy keyed to the user's current state. Concrete
    /// language about *what* will happen ("guest progress on this
    /// device", not "your data") so a skimmer can decide quickly.
    private var replaceConfirmCopy: String {
        if store.history.isEmpty && !store.isPaired {
            return "You haven't logged any sessions on this device yet, so nothing will be lost."
        }
        var bits: [String] = []
        if !store.history.isEmpty { bits.append("\(store.history.count) saved \(store.history.count == 1 ? "session" : "sessions")") }
        if store.isPaired { bits.append("your pairing with \(store.partner.name.isEmpty ? "your partner" : store.partner.name)") }
        let things = bits.joined(separator: " and ")
        return "Signing in will leave your current guest data — \(things) — behind on this device. The account you sign into will replace it."
    }

    // MARK: - Actions

    private func handlePrimary() {
        guard canSubmit else { return }
        inlineError = nil

        switch mode {
        case .saveAccount:
            inFlight = true
            Task {
                let err: String?
                if auth.isAnonymous {
                    err = await auth.linkEmailToCurrentUser(email: email, password: password)
                } else {
                    err = await auth.signUp(email: email, password: password)
                }
                handleResult(err, successMessage: "Account saved")
            }

        case .signIn:
            // From an anonymous session, signing in to a different
            // account is destructive — we route through a confirmation
            // alert before doing anything.
            if auth.isAnonymous {
                showAbandonConfirm = true
            } else {
                Task { await performSignIn(replaceAnon: false) }
            }

        case .switchAccount:
            Task {
                inFlight = true
                await auth.signOut()
                let err = await auth.signIn(email: email, password: password)
                handleResult(err, successMessage: "Signed in")
            }
        }
    }

    private func performSignIn(replaceAnon: Bool) async {
        inFlight = true
        // If the caller is replacing a guest account, sign out of it
        // first so we don't end up linking the new email to the same
        // anonymous row.
        if replaceAnon {
            await auth.signOut()
        }
        let err = await auth.signIn(email: email, password: password)
        handleResult(err, successMessage: "Signed in")
    }

    private func handleResult(_ err: String?, successMessage: String) {
        inFlight = false
        if let err {
            inlineError = friendly(err)
            return
        }
        store.showToast(successMessage, icon: "checkmark.circle.fill")
        onClose()
    }

    /// Map raw Supabase error strings to short, scan-friendly copy.
    /// Falls back to the original string when it doesn't match a pattern
    /// — better to show something honest than to swallow.
    private func friendly(_ raw: String) -> String {
        let l = raw.lowercased()
        if l.contains("invalid login credentials") { return "That email or password didn't match." }
        if l.contains("user already registered") || l.contains("already registered") { return "That email is already in use. Try signing in instead." }
        if l.contains("password should be at least") { return "Password must be at least 6 characters." }
        if l.contains("invalid email") { return "That email doesn't look right." }
        if l.contains("rate limit") { return "Too many attempts. Wait a moment and try again." }
        return raw
    }
}
