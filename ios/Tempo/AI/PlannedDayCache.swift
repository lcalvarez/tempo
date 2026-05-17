import Foundation

/// One day's worth of cached plan. Stored as JSON in the app's
/// `Application Support/tempo/` directory, keyed by the user id so that
/// switching accounts on a shared device doesn't surface the wrong plan.
struct PlannedDayCacheEntry: Codable {
    /// Local-calendar day this plan was generated for, e.g. "2026-05-16".
    /// We compare the cached `dayKey` against `PlannedDayCache.todayKey()`
    /// to decide whether it's still fresh.
    let dayKey: String

    let plan: SessionPlan

    /// Which provider produced this plan ("Apple", "Sonnet 4.5"). Heuristic
    /// plans are *never* written to the cache — see `PlannerService`.
    let providerLabel: String

    let generatedAt: Date

    /// Whether this entry is still good for today (compares `dayKey` against
    /// the user's local calendar). A flight across midnight UTC won't
    /// unlock a fresh plan because `todayKey()` uses `Calendar.current`.
    var isFreshForToday: Bool {
        dayKey == PlannedDayCache.todayKey()
    }
}

/// On-device, per-user, calendar-day-keyed cache for AI-generated plans.
///
/// Why this exists: AI tiers (Foundation Models, Anthropic Sonnet) cost
/// real time / money per generation. We want a guarantee that:
///
///   1. Once-per-day, even across app launches and app-focus changes.
///   2. The user can re-tap "Regenerate" all day — they get the same
///      plan back instantly with a "check back tomorrow" toast.
///   3. Heuristic results are never persisted here, so a flaky network
///      on the morning of doesn't lock the user into a fallback plan.
///   4. Sign-out wipes the cache so a different user on the same device
///      can't see the previous user's plan.
@MainActor
final class PlannedDayCache {
    static let shared = PlannedDayCache()

    /// Format used everywhere we compare "are we still in the same day?".
    /// Local calendar is intentional — a user crossing time zones at
    /// midnight UTC shouldn't unlock a fresh AI generation.
    nonisolated static func todayKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    // MARK: - Lookup / write / clear

    /// Returns the cached entry if one exists for this user. Caller must
    /// still check `isFreshForToday`; we don't lazily evict here so tests
    /// can inspect stale data.
    func entry(for userId: UUID) -> PlannedDayCacheEntry? {
        let url = fileURL(for: userId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder.iso.decode(PlannedDayCacheEntry.self, from: data)
        } catch {
            #if DEBUG
            print("[PlannedDayCache] decode failed for \(userId): \(error)")
            #endif
            return nil
        }
    }

    /// Persist a freshly-generated plan. Atomic write so a crash mid-write
    /// can't leave a half-decoded file behind.
    func write(_ entry: PlannedDayCacheEntry, for userId: UUID) {
        let url = fileURL(for: userId)
        do {
            try ensureDirectoryExists()
            let data = try JSONEncoder.iso.encode(entry)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[PlannedDayCache] write failed for \(userId): \(error)")
            #endif
        }
    }

    /// Wipe the entry for a given user. Hooked into `AuthStore.signOut`
    /// so the next user on the device gets a fresh plan.
    func clear(for userId: UUID) {
        let url = fileURL(for: userId)
        try? FileManager.default.removeItem(at: url)
    }

    /// Wipe every entry. Used by `resetOnboarding` so debug "reset" gets
    /// the user back to a totally clean state.
    func clearAll() {
        guard let dir = directoryURL else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for u in urls where u.lastPathComponent.hasPrefix("planned-day-") {
            try? FileManager.default.removeItem(at: u)
        }
    }

    // MARK: - File layout

    /// `<Application Support>/tempo/planned-day-<userId>.json`. Application
    /// Support is the right home for non-user-facing cached data; we don't
    /// want this in `Documents` (would show in iCloud / file-sharing) or
    /// in `UserDefaults` (the plan is large enough to bloat prefs).
    private func fileURL(for userId: UUID) -> URL {
        directoryURL!
            .appendingPathComponent("planned-day-\(userId.uuidString.lowercased()).json")
    }

    private var directoryURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return base.appendingPathComponent("tempo", isDirectory: true)
    }

    private func ensureDirectoryExists() throws {
        guard let dir = directoryURL else { return }
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Coder helpers

private extension JSONEncoder {
    /// Shared encoder configured to emit ISO-8601 timestamps. Matches the
    /// rest of the app's Supabase tooling so the cache can round-trip
    /// without bespoke date formats.
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
