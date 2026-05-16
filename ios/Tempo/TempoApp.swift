import SwiftUI
import UIKit

/// Pure-UIKit deep link sink. Required on iOS 26 because SwiftUI's
/// `.onOpenURL` is unreliable in the simulator (URLs delivered via
/// `simctl openurl` reach `UIApplicationDelegate.application(_:open:options:)`
/// but never propagate to the SwiftUI hierarchy). The delegate dispatches
/// to a static handler that the SwiftUI app sets up on launch.
final class DeepLinkAppDelegate: NSObject, UIApplicationDelegate {
    /// Set once by `TempoApp` after the SwiftUI scene comes up. URLs that
    /// arrived before this is set are queued.
    static var handler: ((URL) -> Void)?
    static var queue: [URL] = []

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                     [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let url = launchOptions?[.url] as? URL { Self.deliver(url) }
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Self.deliver(url)
        return true
    }

    static func deliver(_ url: URL) {
        if let handler = handler {
            handler(url)
        } else {
            queue.append(url)
        }
    }
}

@main
struct TempoApp: App {
    @UIApplicationDelegateAdaptor(DeepLinkAppDelegate.self) private var deepLinkDelegate
    @StateObject private var session = SessionStore()
    @StateObject private var auth: AuthStore
    @StateObject private var remote: RemoteSync

    init() {
        // `auth` and `remote` share the same `AuthStore` instance so
        // `RemoteSync` calls go through the token-aware client. Building
        // both in `init()` lets us pass that reference into `RemoteSync`
        // before SwiftUI starts observing them.
        let authStore = AuthStore()
        _auth = StateObject(wrappedValue: authStore)
        _remote = StateObject(wrappedValue: RemoteSync(auth: authStore))
    }

    /// Routes `tempo://pair?t=<token>` URLs into the accept-invite flow.
    /// Called from the WindowGroup-level `.onOpenURL` so the handler is
    /// attached to a stable view that doesn't get recomposed when
    /// onboarding finishes or full-screen covers come and go.
    private func handleDeepLink(_ url: URL) {
        appendDeepLinkLog("scene onOpenURL: \(url.absoluteString)")
        guard url.scheme == "tempo", url.host == "pair" else { return }
        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "t" })?
            .value
        guard let token, !token.isEmpty else {
            session.showToast("Invalid invite link", icon: "exclamationmark.triangle.fill")
            return
        }
        Task {
            if let err = await session.acceptPartner(token: token) {
                session.showToast("Couldn't accept invite", icon: "exclamationmark.triangle.fill")
                appendDeepLinkLog("acceptPartner failed: \(err)")
            } else {
                session.showToast("Paired up", icon: "checkmark.circle.fill")
                appendDeepLinkLog("acceptPartner succeeded")
            }
        }
    }

    #if DEBUG
    /// File-based driver for the email/password link path. Tests drop a
    /// `Documents/test-link-account.json` file with `{email, password}`;
    /// the app calls `linkEmailToCurrentUser`, preserving `auth.uid()` and
    /// flipping `is_anonymous` to false. Mirrors the existing test affordances.
    @MainActor
    private func drainPendingTestLinkAccount() async {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = dir.appendingPathComponent("test-link-account.json")
        guard let data = try? Data(contentsOf: path) else { return }
        struct Payload: Decodable { let email: String; let password: String }
        do {
            let p = try JSONDecoder().decode(Payload.self, from: data)
            try? FileManager.default.removeItem(at: path)
            appendDeepLinkLog("test-link-account: email=\(p.email)")
            if let err = await auth.linkEmailToCurrentUser(email: p.email, password: p.password) {
                appendDeepLinkLog("test-link-account failed: \(err)")
            } else {
                appendDeepLinkLog("test-link-account: linked successfully")
            }
        } catch {
            appendDeepLinkLog("test-link-account decode failed: \(error)")
        }
    }

    /// File-based driver for the custom-exercise write path. The test drops
    /// a `Documents/test-custom-exercise.json` file containing a JSON-encoded
    /// `CustomExercise`; the app appends it to `profile.customExercises`
    /// (which triggers the regular write-through to Supabase) and removes
    /// the file. Used by `scripts/smoke-custom-exercise-with-app.sh`.
    @MainActor
    private func drainPendingTestCustomExercise() async {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = dir.appendingPathComponent("test-custom-exercise.json")
        guard let data = try? Data(contentsOf: path) else { return }
        do {
            let ex = try JSONDecoder().decode(CustomExercise.self, from: data)
            try? FileManager.default.removeItem(at: path)
            session.addCustomExercise(ex)
            appendDeepLinkLog("test-custom-exercise: appended \(ex.id) (\(ex.name))")
            // Wait for the debounced profile push (≈0.6s) to flush.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            appendDeepLinkLog("test-custom-exercise: flush window elapsed")
        } catch {
            appendDeepLinkLog("test-custom-exercise decode failed: \(error)")
        }
    }

    /// File-based driver for the `saveCompletedSession` write path. Tests
    /// drop a JSON-encoded `CompletedSession` at
    /// `Documents/test-save-session.json`; the app decodes it, calls
    /// `saveCompletedSession` (which writes locally and pushes via
    /// `RemoteSync`), and removes the file. Mirrors the
    /// `test-pair-token.txt` mechanism — same rationale.
    @MainActor
    private func drainPendingTestSession() async {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = dir.appendingPathComponent("test-save-session.json")
        guard let data = try? Data(contentsOf: path) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        do {
            let s = try dec.decode(CompletedSession.self, from: data)
            try? FileManager.default.removeItem(at: path)
            appendDeepLinkLog("test-save-session: id=\(s.id) title=\(s.title)")
            session.saveCompletedSession(s)
            // Wait briefly for the push to finish so the smoke test can
            // observe the resulting log line on the same launch.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            appendDeepLinkLog("test-save-session: dispatched")
        } catch {
            appendDeepLinkLog("test-save-session decode failed: \(error)")
        }
    }

    /// File-based fallback for driving the deep-link path from tests on
    /// iOS 26 simulators where `simctl openurl` doesn't reliably reach
    /// `.onOpenURL` or `application(_:open:)`. Tests drop a file at
    /// `Documents/test-pair-token.txt` containing just the invite token;
    /// the app reads it on launch, runs `acceptPartner`, and deletes the
    /// file so a relaunch doesn't re-process it.
    @MainActor
    private func drainPendingTestPairToken() async {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = dir.appendingPathComponent("test-pair-token.txt")
        guard let data = try? Data(contentsOf: path),
              let raw = String(data: data, encoding: .utf8) else { return }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        appendDeepLinkLog("test-pair-token: token=\(token.prefix(8))…")
        try? FileManager.default.removeItem(at: path)
        if let err = await session.acceptPartner(token: token) {
            appendDeepLinkLog("test-pair-token acceptPartner failed: \(err)")
        } else {
            appendDeepLinkLog("test-pair-token acceptPartner succeeded")
        }
    }
    #endif

    /// Mirrors a line into `~/Documents/remote-sync.log` so the app-level
    /// smoke pairing script can confirm the deep link landed even before
    /// `RemoteSync` has anything to log.
    private func appendDeepLinkLog(_ msg: String) {
        #if DEBUG
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("remote-sync.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) [App] \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(auth)
                .environmentObject(remote)
                .preferredColorScheme(session.profile.appearance.swiftUIScheme)
                .tint(Theme.Color.accent)
                .task {
                    // Wire all model -> backend hooks in one place. Idempotent;
                    // if the scene reattaches (it doesn't on iOS today), this
                    // simply reinstalls the same closures.
                    remote.attach(session: session)
                    // Pull the canonical state from the server. Backend wins.
                    await remote.refreshAll()
                    // Install the deep-link bridge and drain any queued URLs
                    // that arrived before the scene was ready.
                    DeepLinkAppDelegate.handler = { url in
                        Task { @MainActor in handleDeepLink(url) }
                    }
                    for url in DeepLinkAppDelegate.queue { handleDeepLink(url) }
                    DeepLinkAppDelegate.queue.removeAll()
                    #if DEBUG
                    await drainPendingTestPairToken()
                    await drainPendingTestSession()
                    await drainPendingTestCustomExercise()
                    await drainPendingTestLinkAccount()
                    #endif
                }
                .onOpenURL { url in
                    // SwiftUI path — works on device but flaky on iOS 26
                    // simulator. Deduped by the same handler.
                    handleDeepLink(url)
                }
        }
    }
}
