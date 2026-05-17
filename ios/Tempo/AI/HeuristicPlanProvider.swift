import Foundation

/// The deterministic, rule-based planner that ships as the offline /
/// failure fallback. Implemented in `PlanGenerator` (see Models.swift) —
/// this file only adapts it to the `PlanProvider` interface so
/// `PlannerService` can treat it like any other tier.
///
/// Properties worth knowing:
///
///   • Always available — never throws, never blocks on a network call.
///   • Result is **not** cached: see `PlannerService.generate`. Caching
///     a heuristic plan would mean a flaky network on the morning of
///     today locks the user into a fallback for the rest of the day.
struct HeuristicPlanProvider: PlanProvider {
    /// Exposed so `PlannerService` can identify "is this the heuristic
    /// tier?" without string-comparing untrusted instance data.
    static let staticLabel = "Heuristic"

    var label: String { Self.staticLabel }

    func isAvailable() async -> Bool { true }

    func generatePlan(
        user: UserProfile,
        partner: PartnerProfile,
        day: Int
    ) async throws -> SessionPlan {
        PlanGenerator.generateNextSession(for: user, partner: partner, calendarDay: day)
    }
}
