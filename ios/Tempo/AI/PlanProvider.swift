import Foundation

/// A pluggable session-plan generator. Implementations include:
///
///   • `FoundationModelsPlanProvider` — Apple Intelligence (iOS 26+).
///   • `AnthropicPlanProvider` — Sonnet 4.5 via the `generate-plan`
///     Supabase Edge Function. Used on devices that can't run Apple's
///     on-device model.
///   • `HeuristicPlanProvider` — the rule-based `PlanGenerator` we ship
///     as the offline / failure fallback. Always available.
///
/// `PlannerService` walks the tier list and returns the first valid plan;
/// `PlannedDayCache` short-circuits the whole thing once we already have a
/// plan for today so we never make two AI calls in a single day.
protocol PlanProvider {
    /// Stable identifier surfaced in Profile so users can see which engine
    /// produced today's plan ("AI trainer · Apple", "AI trainer · Sonnet 4.5",
    /// "AI trainer · Heuristic"). Also persisted in `PlannedDayCache`.
    var label: String { get }

    /// Whether this provider is reachable / configured at the moment. The
    /// service skips unavailable providers without trying them so we don't
    /// burn a network call only to fall through. Cheap to call repeatedly.
    func isAvailable() async -> Bool

    /// Build a `SessionPlan` for the given pair on the given calendar day.
    /// Throws on transport / model / validation failures so the service can
    /// fall through to the next provider.
    func generatePlan(
        user: UserProfile,
        partner: PartnerProfile,
        day: Int
    ) async throws -> SessionPlan
}

/// Errors thrown by AI providers. The service treats every case as a
/// signal to fall through to the next tier — we never surface these to
/// the user directly, but they show up in logs to help debug "why did we
/// land on the heuristic again?".
enum PlanProviderError: Error, CustomStringConvertible {
    case unavailable(String)
    case transport(Error)
    case decoding(String)
    case validationFailed(String)
    case rateLimited

    var description: String {
        switch self {
        case .unavailable(let reason): return "unavailable: \(reason)"
        case .transport(let err):      return "transport: \(err.localizedDescription)"
        case .decoding(let s):         return "decoding: \(s)"
        case .validationFailed(let s): return "invalid plan: \(s)"
        case .rateLimited:             return "rate-limited"
        }
    }
}

// MARK: - Service

/// The single entry point the rest of the app uses. Walks the tiered list
/// of `PlanProvider`s, applies the once-per-day cache, validates output,
/// and falls through to the heuristic when everything else fails.
///
/// `MainActor`-isolated because it touches `PlannedDayCache` (file IO is
/// fine off-actor; the cache is `MainActor` so it can safely poke at the
/// session store on writes).
@MainActor
final class PlannerService {
    static let shared = PlannerService()

    /// Result of a generation. `fromCache == true` means the plan was
    /// produced earlier today and we just returned the saved copy. The
    /// caller can use this to decide whether to surface a "plan is set —
    /// check back tomorrow" toast vs treating it as a fresh generation.
    struct Result {
        let plan: SessionPlan
        let providerLabel: String
        let fromCache: Bool
    }

    /// Override at app launch (`TempoApp`) to inject the user-id binding
    /// once `AuthStore.currentUserId` is known. Without it, the cache
    /// degrades to a global key — still functional but won't isolate
    /// users on shared devices. `nil` is fine in previews.
    var resolveUserId: (() -> UUID?)? = nil

    /// Whether the user has opted out of AI generation (Profile toggle).
    /// When false we skip both AI tiers and go straight to heuristic.
    var aiEnabled: () -> Bool = { true }

    /// Tier order. The default constructor wires up Apple → Anthropic →
    /// heuristic; tests can swap in mocks via `init(providers:)`.
    private let providers: [PlanProvider]

    init(providers: [PlanProvider]? = nil) {
        if let providers {
            self.providers = providers
        } else {
            var list: [PlanProvider] = []
            if #available(iOS 26.0, *) {
                list.append(FoundationModelsPlanProvider())
            }
            list.append(AnthropicPlanProvider())
            // Heuristic is always last and always available.
            list.append(HeuristicPlanProvider())
            self.providers = list
        }
    }

    /// Generate today's plan, honoring the once-per-day cache. Use the
    /// `force` flag for tests / debug paths that need to bypass the
    /// cache; production callers always leave it `false`.
    func generate(
        user: UserProfile,
        partner: PartnerProfile,
        day: Int = Calendar.current.component(.day, from: Date()),
        force: Bool = false
    ) async -> Result {
        let userId = resolveUserId?()

        // ── 1. Cache check (real AI plans only; heuristic never caches).
        if !force,
           let userId,
           let entry = PlannedDayCache.shared.entry(for: userId),
           entry.isFreshForToday {
            return Result(
                plan: entry.plan,
                providerLabel: entry.providerLabel,
                fromCache: true
            )
        }

        let allowAI = aiEnabled()

        // ── 2. Walk the tier list.
        for provider in providers {
            // Heuristic always runs last; let everything else short-circuit
            // when AI is disabled.
            let isHeuristic = (provider.label == HeuristicPlanProvider.staticLabel)
            if !isHeuristic && !allowAI { continue }

            let available = await provider.isAvailable()
            if !available { continue }

            do {
                let plan = try await provider.generatePlan(user: user, partner: partner, day: day)
                let validated = try Self.validate(plan, user: user)

                // Heuristic results bypass the cache so a transient
                // network failure today doesn't lock the user into a
                // heuristic plan for the rest of the day.
                if !isHeuristic, let userId {
                    let entry = PlannedDayCacheEntry(
                        dayKey: PlannedDayCache.todayKey(),
                        plan: validated,
                        providerLabel: provider.label,
                        generatedAt: Date()
                    )
                    PlannedDayCache.shared.write(entry, for: userId)
                }

                return Result(
                    plan: validated,
                    providerLabel: provider.label,
                    fromCache: false
                )
            } catch {
                // Log + fall through to the next tier. We deliberately do
                // not surface the error — the user just sees today's plan,
                // produced by whichever tier succeeds.
                #if DEBUG
                print("[PlannerService] \(provider.label) failed: \(error). Trying next tier.")
                #endif
                continue
            }
        }

        // Shouldn't be reachable — the heuristic provider doesn't throw —
        // but if every tier somehow fails we return whatever the heuristic
        // would have produced synchronously, uncached.
        let plan = PlanGenerator.generateNextSession(for: user, partner: partner, calendarDay: day)
        return Result(plan: plan, providerLabel: HeuristicPlanProvider.staticLabel, fromCache: false)
    }

    // MARK: - Validation

    /// Sanity-check a generated plan before we let it reach the UI / cache.
    /// Catches hallucinated catalog IDs and out-of-range values from the
    /// model tiers. Heuristic output goes through this too so the contract
    /// is uniform; it should always pass.
    static func validate(_ plan: SessionPlan, user: UserProfile) throws -> SessionPlan {
        var sanitized = plan

        // 1. Drop unresolvable catalog IDs from both sides. We resolve
        //    against the merged catalog (built-in + user customs) so
        //    custom-exercise IDs aren't treated as hallucinations.
        let resolveExisting: ([ExercisePlan]) -> [ExercisePlan] = { list in
            list.filter { ExerciseCatalog.resolve($0.catalogId, with: user.customExercises) != nil }
        }
        sanitized.youPlan     = resolveExisting(sanitized.youPlan)
        sanitized.partnerPlan = resolveExisting(sanitized.partnerPlan)

        // 2. Size bounds — refuse empty or extreme plans.
        if sanitized.youPlan.count < 3 || sanitized.youPlan.count > 12 {
            throw PlanProviderError.validationFailed(
                "youPlan.count = \(sanitized.youPlan.count) (need 3…12)"
            )
        }

        // 3. Duration bounds (in minutes).
        if sanitized.durationMinutes < 20 || sanitized.durationMinutes > 120 {
            throw PlanProviderError.validationFailed(
                "durationMinutes = \(sanitized.durationMinutes) (need 20…120)"
            )
        }

        // 4. Muscle groups can't be empty — drives all the title/subtitle
        //    chrome on Today + Schedule.
        if sanitized.muscleGroups.isEmpty {
            throw PlanProviderError.validationFailed("muscleGroups empty")
        }

        return sanitized
    }
}
