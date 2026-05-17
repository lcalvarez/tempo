import SwiftUI
import UIKit
import UserNotifications

// MARK: - Share sheet

/// Identifiable wrapper so we can drive `.sheet(item:)` with a single
/// state value. Some share targets (Mail, Files) want a `URL` — both
/// `file://` (CSV export) and `https://` (App Store invite link) work
/// with `UIActivityViewController`.
struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Thin SwiftUI wrapper around `UIActivityViewController`. We use a
/// custom one (vs. `ShareLink`) because we need it to present from a
/// `confirmationDialog` action, where `ShareLink` doesn't compose.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CSV export

/// Flattens `[CompletedSession]` into a CSV. Includes per-set rows so the
/// output is useful in a spreadsheet — one "wide" row per session with
/// embedded JSON wouldn't be much better than the in-app history view.
enum CSVExporter {
    static func csv(for sessions: [CompletedSession]) -> String {
        var rows: [String] = [
            "session_id,session_date,session_title,duration_seconds,exercise_id,exercise_name,is_pr,set_index,reps,weight,skipped"
        ]
        let formatter = ISO8601DateFormatter()
        for s in sessions {
            for (exIdx, ex) in s.you.enumerated() {
                if ex.sets.isEmpty {
                    rows.append(line(
                        sessionId: s.id, date: formatter.string(from: s.date),
                        title: s.title, durationSeconds: s.durationSeconds,
                        exerciseId: ex.catalogId, exerciseName: ex.name,
                        isPR: ex.isPR, setIndex: exIdx, reps: 0, weight: 0, skipped: true
                    ))
                } else {
                    for (setIdx, set) in ex.sets.enumerated() {
                        rows.append(line(
                            sessionId: s.id, date: formatter.string(from: s.date),
                            title: s.title, durationSeconds: s.durationSeconds,
                            exerciseId: ex.catalogId, exerciseName: ex.name,
                            isPR: ex.isPR, setIndex: setIdx, reps: set.reps,
                            weight: set.weight, skipped: set.skipped
                        ))
                    }
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    private static func line(
        sessionId: UUID, date: String, title: String, durationSeconds: Int,
        exerciseId: String, exerciseName: String, isPR: Bool,
        setIndex: Int, reps: Int, weight: Int, skipped: Bool
    ) -> String {
        let escapedTitle = csvEscape(title)
        let escapedName = csvEscape(exerciseName)
        return [
            sessionId.uuidString, date, escapedTitle, String(durationSeconds),
            exerciseId, escapedName, isPR ? "1" : "0",
            String(setIndex), String(reps), String(weight), skipped ? "1" : "0"
        ].joined(separator: ",")
    }

    /// Wrap a value in double quotes if it contains anything that would
    /// confuse a parser. Doubled quotes follow RFC 4180.
    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return s
    }
}

// MARK: - Support links

/// Tiny namespace for the Help / Feedback / Share URLs so they aren't
/// scattered across views. Feedback uses a `mailto:` so iOS hands it to
/// whatever mail app the user has set up — no MFMailComposeViewController
/// wrapper needed.
enum SupportLinks {
    static let appStoreURL = URL(string: "https://tempo.app")!
    static let helpURL = URL(string: "https://tempo.app/help")!

    /// Pre-fills subject + body so it's clear what build the user is on.
    /// Returns `nil` if URL composition fails (effectively impossible
    /// barring a UTF-8 bug, but the optional keeps callsites honest).
    static func feedbackMailtoURL() -> URL? {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        let body = """


        ---
        Tempo \(appVersion) (\(buildNumber)) · \(device)
        """
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = "feedback@tempo.app"
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Tempo feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return c.url
    }
}

// MARK: - Notifications

/// Local-notification permission gate. Lifted out of `ProfileView` so any
/// future caller (Schedule, Today) can request the same permission
/// without copy-pasting the system call.
enum NotificationManager {
    /// Asks for `.alert + .badge + .sound` if we haven't asked yet.
    /// No-ops on subsequent calls. Safe to call from any actor.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        default:
            break
        }
    }
}
