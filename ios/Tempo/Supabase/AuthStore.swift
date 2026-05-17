import Foundation
import SwiftUI
import Combine
import Supabase
import AuthenticationServices

/// Owns the user's authentication state and brokers Sign in with Apple →
/// Supabase Auth. Exposes a single `currentUserId` published property the
/// rest of the app can react to (via `@EnvironmentObject`).
///
/// In the simulator, Sign in with Apple isn't reliable, so the bootstrap
/// path (`ensureSignedIn`) creates an anonymous Supabase session up front;
/// that session is converted to a real account from `SignInScreen` /
/// Profile → "Save your account" via `linkEmailToCurrentUser`.
@MainActor
final class AuthStore: ObservableObject {

    @Published private(set) var currentUserId: UUID?
    @Published private(set) var isAuthenticating = false
    @Published var lastError: String?

    private var authTask: Task<Void, Never>?

    init() {
        currentUserId = TempoSupabase.client.auth.currentSession?.user.id
        observeAuthChanges()
    }

    deinit { authTask?.cancel() }

    // MARK: - State observation

    private func observeAuthChanges() {
        authTask = Task { [weak self] in
            for await (event, session) in TempoSupabase.client.auth.authStateChanges {
                guard let self else { return }
                // Always trust the SDK's view of "is there a session?" rather
                // than reacting per-event. Events arrive on a separate task
                // and can race with `ensureSignedIn`'s sign-out-then-sign-in
                // sequence, where a delayed `.signedOut` event would clobber
                // a fresh `currentUserId` set by the in-flight sign-in.
                _ = event
                self.currentUserId = session?.user.id
                    ?? TempoSupabase.client.auth.currentSession?.user.id
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Exchange an `ASAuthorizationAppleIDCredential` (obtained via SwiftUI's
    /// `SignInWithAppleButton`) for a Supabase session.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            lastError = "Apple sign-in returned no identity token."
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            _ = try await TempoSupabase.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
        } catch {
            lastError = "Apple sign-in failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Email / password

    /// Whether the current session is anonymous (vs. tied to a real
    /// identity like email/password or Apple). Useful for gating
    /// "Save your account" prompts.
    var isAnonymous: Bool {
        TempoSupabase.client.auth.currentSession?.user.isAnonymous ?? true
    }

    /// The email associated with the current session, when there is one.
    /// `nil` for anonymous sessions and for identities that aren't bound
    /// to email (e.g. Apple-only when we eventually wire it).
    var currentEmail: String? {
        let raw = TempoSupabase.client.auth.currentSession?.user.email
        return raw?.isEmpty == false ? raw : nil
    }

    /// Sign into an existing email/password account. If no such account
    /// exists, returns a localized error. The caller (Sign-In screen) is
    /// expected to surface the error inline.
    ///
    /// NOTE: This is a *destructive* path for users currently in an
    /// anonymous session — switching identities means the previous anon
    /// user's profile/sessions/partnership rows stop being reachable from
    /// this device. Use `linkEmailToCurrentUser` instead if you want to
    /// preserve the anonymous data.
    func signIn(email: String, password: String) async -> String? {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            _ = try await TempoSupabase.client.auth.signIn(email: email, password: password)
            lastError = nil
            return nil
        } catch {
            let msg = "Sign-in failed: \(error.localizedDescription)"
            lastError = msg
            return msg
        }
    }

    /// Upgrade the current anonymous user to a permanent email/password
    /// account, preserving all of their data (profile, sessions, partnership).
    ///
    /// Internally calls `updateUser` with the new email + password, which
    /// stamps the existing `auth.users` row instead of creating a new one.
    /// The `auth.uid()` stays stable so all RLS-bound rows remain owned by
    /// this same user.
    ///
    /// Returns `nil` on success, a user-facing error string otherwise.
    func linkEmailToCurrentUser(email: String, password: String) async -> String? {
        guard isAnonymous else {
            return "You're already signed in to a permanent account."
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let attrs = UserAttributes(email: email, password: password)
            _ = try await TempoSupabase.client.auth.update(user: attrs)
            lastError = nil
            return nil
        } catch {
            let msg = "Couldn't save account: \(error.localizedDescription)"
            lastError = msg
            return msg
        }
    }

    /// Send a password-recovery email. Supabase always returns success
    /// here even when the address isn't on file (anti-enumeration), so
    /// we mirror that and treat "sent" as the only happy path from the
    /// caller's perspective. Surfaces network/rate-limit errors so the
    /// UI can show them inline.
    ///
    /// Returns `nil` on success, a user-facing error string otherwise.
    func sendPasswordReset(email: String) async -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter your email first." }
        do {
            try await TempoSupabase.client.auth.resetPasswordForEmail(trimmed)
            return nil
        } catch {
            return "Couldn't send reset email: \(error.localizedDescription)"
        }
    }

    /// Sign up a brand-new email/password account from scratch (no anon
    /// data to preserve). Used when the user explicitly chooses
    /// "Sign in with email" and isn't currently anonymous.
    func signUp(email: String, password: String) async -> String? {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            _ = try await TempoSupabase.client.auth.signUp(email: email, password: password)
            lastError = nil
            return nil
        } catch {
            let msg = "Sign-up failed: \(error.localizedDescription)"
            lastError = msg
            return msg
        }
    }

    /// Bootstrap path used at app launch in dev: if there's no existing session,
    /// create an anonymous one so we have a real `auth.uid()` to write rows
    /// against. The session is persisted by `supabase-swift` in Keychain so on
    /// the next launch this returns immediately.
    ///
    /// We verify any cached session by calling `auth.user()` server-side. If
    /// that fails (e.g. the database was reset and the JWT now references a
    /// user that no longer exists), we sign out and create a fresh anonymous
    /// session. Without this check the app would silently get 401s on every
    /// write for the rest of the run.
    ///
    /// In production we'll replace this with Sign in with Apple as the gate
    /// before the user can use the app, but for the simulator round-trip this
    /// is the simplest thing that works.
    func ensureSignedIn() async {
        if let cached = TempoSupabase.client.auth.currentSession?.user.id {
            do {
                _ = try await TempoSupabase.client.auth.user()
                currentUserId = cached
                return
            } catch {
                // Cached session is stale (DB reset, user deleted, JWT
                // signing key rotated). Drop it and fall through.
                try? await TempoSupabase.client.auth.signOut()
                currentUserId = nil
            }
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let session = try await TempoSupabase.client.auth.signInAnonymously()
            currentUserId = session.user.id
        } catch {
            lastError = "Anon sign-in failed: \(error.localizedDescription)"
        }
    }

    /// Sign out of the current account. Bootstraps a fresh anonymous
    /// session immediately afterwards so the app remains usable —
    /// otherwise we'd be stuck with no `auth.uid()` until the user signs
    /// back in.
    ///
    /// Also wipes the on-device AI plan cache for the outgoing user, so
    /// the next user on the same physical device doesn't see the
    /// previous user's plan.
    func signOut() async {
        let outgoing = currentUserId
        try? await TempoSupabase.client.auth.signOut()
        currentUserId = nil
        if let outgoing {
            PlannedDayCache.shared.clear(for: outgoing)
        }
        await ensureSignedIn()
    }

    /// Permanently delete the signed-in user's account via the
    /// `delete-user` Supabase Edge Function. The function uses the
    /// service-role key server-side to call `auth.admin.deleteUser` —
    /// the row's `id` is taken from the JWT, so an attacker can't ask
    /// us to delete somebody else's account.
    ///
    /// On success we sign out and bootstrap a fresh anonymous session,
    /// matching `signOut()`'s contract. Returns `nil` on success or a
    /// user-facing error string.
    func deleteAccount() async -> String? {
        guard currentUserId != nil else { return "Not signed in." }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await TempoSupabase.client.functions.invoke("delete-user")
        } catch let error as FunctionsError {
            if case .httpError(let code, _) = error {
                return "Couldn't delete account (HTTP \(code))."
            }
            return "Couldn't delete account: \(error.localizedDescription)"
        } catch {
            return "Couldn't delete account: \(error.localizedDescription)"
        }
        await signOut()
        return nil
    }
}
