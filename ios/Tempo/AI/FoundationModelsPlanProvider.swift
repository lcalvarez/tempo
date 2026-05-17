import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device LLM tier, backed by Apple's `FoundationModels` framework
/// (introduced in iOS 26 alongside Apple Intelligence). Runs entirely on
/// the device — zero network, zero per-call cost — but only when:
///
///   • the device hardware supports Apple Intelligence
///     (iPhone 15 Pro / 15 Pro Max and later),
///   • the user has Apple Intelligence enabled in Settings,
///   • the model has finished its (one-time) on-device download.
///
/// On every device that doesn't meet that bar (or on iOS < 26),
/// `isAvailable()` returns `false` and `PlannerService` falls through to
/// the Anthropic Edge Function tier without trying us.
///
/// We deploy this as a normal `PlanProvider` and gate every
/// `FoundationModels`-using line behind `#available(iOS 26.0, *)` so the
/// file compiles back to our iOS 17 deployment target.
struct FoundationModelsPlanProvider: PlanProvider {
    var label: String { "Apple" }

    func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // Apple's enum exposes `.available` plus a handful of
            // "unavailable because…" cases. We only treat the explicit
            // available state as green; anything else (download pending,
            // model removed, hardware incapable, user opted out) sends us
            // to the next tier.
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    func generatePlan(
        user: UserProfile,
        partner: PartnerProfile,
        day: Int
    ) async throws -> SessionPlan {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await Self.generateWithFoundationModels(
                user: user,
                partner: partner,
                day: day
            )
        }
        #endif
        throw PlanProviderError.unavailable("FoundationModels not available on this build")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private extension FoundationModelsPlanProvider {

    /// Mirror of `SessionPlan` shaped for `@Generable` guided generation.
    /// We accept slightly looser types here (e.g. `[String]` instead of
    /// `Set<TrainingFocus>`) and convert/sanitize back into the canonical
    /// `SessionPlan` once the model is done.
    @Generable
    struct GeneratedSessionPlan {
        @Guide(description: "Short title for the user's session, e.g. 'Lower body'.")
        var title: String

        @Guide(description: "Subtitle, e.g. '& core' or 'push day'. Keep it short.")
        var subtitle: String

        @Guide(description: "Total user session duration in minutes. Between 20 and 120.")
        var durationMinutes: Int

        @Guide(description: "Primary muscle groups the user trains today, e.g. ['Quads', 'Glutes'].")
        var muscleGroups: [String]

        @Guide(description: "User's exercises, in order.", .count(3...12))
        var youPlan: [GeneratedExercise]

        @Guide(description: "Partner's session title, e.g. 'Conditioning'.")
        var partnerTitle: String

        @Guide(description: "Partner subtitle.")
        var partnerSubtitle: String

        @Guide(description: "Partner total duration in minutes (20–120).")
        var partnerDurationMinutes: Int

        @Guide(description: "Partner's primary muscle groups.")
        var partnerMuscleGroups: [String]

        @Guide(description: "Partner's exercises, in order.", .count(3...12))
        var partnerPlan: [GeneratedExercise]
    }

    @Generable
    struct GeneratedExercise {
        @Guide(description: "Catalog id from the supplied catalog. Use only ids from that list.")
        var catalogId: String
        @Guide(description: "Display name. Must match the catalog name for catalogId.")
        var name: String
        @Guide(description: "Number of sets (1–6).")
        var sets: Int
        @Guide(description: "Reps per set (1–30) — or seconds for timed/stretching kinds.")
        var reps: Int
        @Guide(description: "Working weight in user's units. 0 for bodyweight.")
        var weight: Int
        @Guide(description: "Exercise kind: 'strength', 'bodyweight', 'timedHold', 'distance', 'timeBased', 'mobility', 'stretching'.")
        var kind: String
    }

    static func generateWithFoundationModels(
        user: UserProfile,
        partner: PartnerProfile,
        day: Int
    ) async throws -> SessionPlan {

        // Build the catalog text the model is allowed to draw from.
        // Including a trimmed CSV (id · name · groups · kind) is dramatically
        // more reliable than letting the model invent ids.
        let catalogLines = ExerciseCatalog.all.map { c in
            "\(c.id) | \(c.name) | \(c.muscleGroups.joined(separator: "/")) | \(c.kind.rawValue)"
        }
        let customLines = user.customExercises.map { c in
            "\(c.id) | \(c.name) | \(c.muscleGroups.joined(separator: "/")) | \(c.kind.rawValue)"
        }
        let catalogText = (catalogLines + customLines).joined(separator: "\n")

        let instructions = """
        You are Tempo's on-device session planner. Build TWO independent
        session plans — one for the user, one for their partner — based on
        their goals, fitness level, intensity, and what they want to avoid.

        Rules:
        • Each side gets its OWN plan. Don't mirror exercises.
        • Pick exercises ONLY from the supplied catalog. Use the listed
          catalogId verbatim. Never invent new ids.
        • Match the user's listed focuses (strength, hypertrophy, endurance,
          weight loss, mobility, general). If multiple focuses are listed,
          pick a primary one for today.
        • Respect avoidedStyles — never pick anything whose name contains
          one of those substrings.
        • Scale weights to fitnessLevel: new ~0.55x catalog defaults,
          some ~0.85x, strong ~1.0x, advanced ~1.15x. Round to 5.
        • 4–8 exercises per side is typical; never fewer than 3 or more
          than 12. Total duration 30–75 minutes typically.
        • Keep titles + subtitles short (2–4 words each).
        """

        let prompt = """
        DAY: \(day)
        USER:
          name: \(user.name.isEmpty ? "the user" : user.name)
          fitnessLevel: \(user.fitnessLevel.rawValue)
          intensity: \(user.intensity.rawValue)
          focuses: \(user.focuses.map(\.rawValue).sorted().joined(separator: ", "))
          equipment: \(user.equipment.sorted().joined(separator: ", "))
          avoidedStyles: \(user.avoidedStyles.sorted().joined(separator: ", "))
        PARTNER:
          name: \(partner.name.isEmpty ? "the partner" : partner.name)
          fitnessLevel: \(partner.fitnessLevel.rawValue)
          intensity: \(partner.intensity.rawValue)
          focuses: \(partner.focuses.map(\.rawValue).sorted().joined(separator: ", "))
          avoidedStyles: \(partner.avoidedStyles.sorted().joined(separator: ", "))

        CATALOG (id | name | muscleGroups | kind):
        \(catalogText)

        Produce a GeneratedSessionPlan now.
        """

        let session = LanguageModelSession(instructions: instructions)
        let response: LanguageModelSession.Response<GeneratedSessionPlan>
        do {
            response = try await session.respond(
                to: prompt,
                generating: GeneratedSessionPlan.self
            )
        } catch {
            throw PlanProviderError.transport(error)
        }

        return convert(response.content, user: user)
    }

    /// Map a `GeneratedSessionPlan` into the canonical `SessionPlan`,
    /// resolving each exercise through `ExerciseCatalog.resolve` so any
    /// hallucinated ids quietly drop out (validation in `PlannerService`
    /// then catches "too few exercises remaining" and falls through).
    static func convert(_ g: GeneratedSessionPlan, user: UserProfile) -> SessionPlan {
        let youPlan = g.youPlan.compactMap {
            mapExercise($0, with: user.customExercises)
        }
        let partnerPlan = g.partnerPlan.compactMap {
            mapExercise($0, with: user.customExercises)
        }
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
#endif
