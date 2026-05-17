import Foundation
import Supabase

/// Server-side LLM tier. Hits the `generate-plan` Supabase Edge Function,
/// which authenticates the request via Supabase JWT and forwards to
/// Anthropic Sonnet 4.5 with the API key held server-side.
///
/// Why through an Edge Function (vs. calling Anthropic directly):
///
///   1. We never embed the Anthropic API key in the iOS bundle.
///   2. Supabase's JWT verification gives us per-user rate limits for
///      free (the function logs each `auth.uid()` per local day in
///      `plan_generation_log` and refuses a second call). Even if the
///      device cache is bypassed, runaway cost is bounded.
///   3. We can swap providers (or add a Claude / Gemini fallback) on the
///      server without shipping a new app build.
struct AnthropicPlanProvider: PlanProvider {
    var label: String { "Sonnet 4.5" }

    func isAvailable() async -> Bool {
        // We require a signed-in user — the Edge Function refuses
        // anonymous calls for cost-control reasons. The auth check is
        // local; an actual reachability ping would be wasteful.
        TempoSupabase.client.auth.currentSession != nil
    }

    func generatePlan(
        user: UserProfile,
        partner: PartnerProfile,
        day: Int
    ) async throws -> SessionPlan {

        // Build the exact JSON the Edge Function expects. We deliberately
        // send `{ user, partner, day, catalog }` instead of letting the
        // server fetch the user's profile — that would require an extra
        // round-trip and leave us with two sources of truth for what the
        // user wants.
        let body = RequestBody(
            user: .from(user),
            partner: .from(partner),
            day: day,
            catalog: ExerciseCatalog.all.map { CatalogItem(c: $0) }
                + user.customExercises.map { CatalogItem(custom: $0) }
        )

        let response: GeneratePlanResponse
        do {
            response = try await TempoSupabase.client.functions.invoke(
                "generate-plan",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: body,
                    encoder: JSONEncoder.snakeCaseISO
                ),
                decoder: JSONDecoder.snakeCaseISO
            )
        } catch let error as FunctionsError {
            // The function returns 429 on rate limit so we can fall
            // through to the heuristic without touching Anthropic again
            // until tomorrow.
            if case .httpError(let code, _) = error, code == 429 {
                throw PlanProviderError.rateLimited
            }
            throw PlanProviderError.transport(error)
        } catch {
            throw PlanProviderError.transport(error)
        }

        return Self.convert(response.plan, user: user)
    }

    // MARK: - Wire types

    struct RequestBody: Encodable {
        let user: SidePayload
        let partner: SidePayload
        let day: Int
        let catalog: [CatalogItem]
    }

    /// What we send the Edge Function for one side of the pair. Mirrors
    /// the fields `PlanGenerator.PlanInputs` uses today, plus a couple
    /// extra (equipment, name) the LLM tier can use for richer copy.
    struct SidePayload: Encodable {
        let name: String
        let fitnessLevel: String
        let intensity: String
        let focuses: [String]
        let avoidedStyles: [String]
        let equipment: [String]

        static func from(_ u: UserProfile) -> SidePayload {
            SidePayload(
                name: u.youLabel,
                fitnessLevel: u.fitnessLevel.rawValue,
                intensity: u.intensity.rawValue,
                focuses: u.focuses.map(\.rawValue).sorted(),
                avoidedStyles: u.avoidedStyles.sorted(),
                equipment: u.equipment.sorted()
            )
        }

        static func from(_ p: PartnerProfile) -> SidePayload {
            SidePayload(
                name: p.displayName,
                fitnessLevel: p.fitnessLevel.rawValue,
                intensity: p.intensity.rawValue,
                focuses: p.focuses.map(\.rawValue).sorted(),
                avoidedStyles: p.avoidedStyles.sorted(),
                equipment: p.equipment.sorted()
            )
        }
    }

    struct CatalogItem: Encodable {
        let id: String
        let name: String
        let muscleGroups: [String]
        let kind: String
        let defaultSets: Int
        let defaultReps: Int
        let defaultWeight: Int

        init(c: CatalogExercise) {
            self.id = c.id
            self.name = c.name
            self.muscleGroups = c.muscleGroups
            self.kind = c.kind.rawValue
            self.defaultSets = c.defaultSets
            self.defaultReps = c.defaultReps
            self.defaultWeight = c.defaultWeight
        }

        init(custom: CustomExercise) {
            self.id = custom.id
            self.name = custom.name
            self.muscleGroups = custom.muscleGroups
            self.kind = custom.kind.rawValue
            self.defaultSets = custom.defaultSets
            self.defaultReps = custom.defaultReps
            self.defaultWeight = custom.defaultWeight
        }
    }

    struct GeneratePlanResponse: Decodable {
        let plan: GeneratedPlan
    }

    /// Mirror of what the Edge Function returns. We re-validate every id
    /// through `ExerciseCatalog.resolve` before letting the plan reach
    /// the rest of the app — the LLM occasionally invents catalog ids
    /// despite the system prompt forbidding it.
    struct GeneratedPlan: Decodable {
        let title: String
        let subtitle: String
        let durationMinutes: Int
        let muscleGroups: [String]
        let youPlan: [GeneratedExercise]
        let partnerTitle: String
        let partnerSubtitle: String
        let partnerDurationMinutes: Int
        let partnerMuscleGroups: [String]
        let partnerPlan: [GeneratedExercise]
    }

    struct GeneratedExercise: Decodable {
        let catalogId: String
        let name: String
        let sets: Int
        let reps: Int
        let weight: Int
        let kind: String
    }

    /// Map the wire shape into our canonical `SessionPlan`, dropping any
    /// unresolvable catalog ids along the way.
    static func convert(_ g: GeneratedPlan, user: UserProfile) -> SessionPlan {
        let youPlan = g.youPlan.compactMap { mapExercise($0, with: user.customExercises) }
        let partnerPlan = g.partnerPlan.compactMap { mapExercise($0, with: user.customExercises) }
        return SessionPlan(
            title: g.title,
            subtitle: g.subtitle,
            durationMinutes: g.durationMinutes,
            youPlan: youPlan,
            muscleGroups: g.muscleGroups,
            partnerTitle: g.partnerTitle,
            partnerSubtitle: g.partnerSubtitle,
            partnerDurationMinutes: g.partnerDurationMinutes,
            partnerPlan: partnerPlan,
            partnerMuscleGroups: g.partnerMuscleGroups
        )
    }

    static func mapExercise(_ g: GeneratedExercise, with custom: [CustomExercise]) -> ExercisePlan? {
        guard let resolved = ExerciseCatalog.resolve(g.catalogId, with: custom) else {
            return nil
        }
        let kind = ExerciseKind(rawValue: g.kind) ?? resolved.kind
        return ExercisePlan(
            catalogId: resolved.id,
            name: resolved.name,
            sets: max(1, min(6, g.sets)),
            reps: max(1, min(60, g.reps)),
            weight: max(0, g.weight),
            kind: kind
        )
    }
}

// MARK: - Coder helpers

private extension JSONEncoder {
    /// Matches Supabase / PostgREST conventions used elsewhere in the
    /// app: snake_case keys, ISO-8601 timestamps. Keeps the Edge
    /// Function's request schema honest.
    static let snakeCaseISO: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let snakeCaseISO: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
