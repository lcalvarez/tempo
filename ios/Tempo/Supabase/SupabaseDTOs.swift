import Foundation

/// "Close to the metal" DTOs that mirror Postgres rows exactly.
///
/// We deliberately keep these separate from the UI-facing types in
/// `Models.swift`. The UI types are tuned for SwiftUI ergonomics (Sets,
/// enums, computed properties); the DTOs are tuned for round-tripping
/// JSON via `convertFromSnakeCase`.
///
/// Conversion happens in `init(profile:)` / `toProfile()` style helpers
/// rather than a generic mapper — it's a one-time, ~50-line boundary that
/// makes drift obvious in code review.

// MARK: - Profile

/// Mirrors `public.profiles`.
///
/// Decoded fields use `?` for columns that may be missing from older snapshots
/// (e.g. `appearance` was added in a later migration). The `toProfile`
/// converter substitutes the same defaults `UserProfile()` would.
///
/// `updatedAt` is read-only: the server trigger sets it and the column is
/// `not null`, so we explicitly skip it in `encode(to:)` rather than
/// transmitting `null` and triggering a constraint violation.
struct ProfileRow: Codable {
    var id: UUID
    var name: String
    var age: Int
    var units: String
    var fitnessLevel: String
    var monogramTone: String
    var equipment: [String]
    var preferredWorkoutTimes: [String]
    var injuries: String
    var focuses: [String]
    var sessionsPerWeek: Int
    var intensity: String
    var enjoyedStyles: [String]
    var avoidedStyles: [String]
    var planningMode: String
    var manualExerciseIds: [String]
    var hasOnboarded: Bool
    var appearance: String?
    var customStretchAreas: [String]?
    /// User-defined exercises, stored on the profile row as jsonb.
    /// Decoded back into the local `customExercises` array.
    var customExercises: [CustomExercise]?
    /// Read-only echo of `profiles.updated_at`. Never included on writes.
    var updatedAt: Date?

    /// Property names match the camelCase form the global
    /// `convertFromSnakeCase`/`convertToSnakeCase` strategies expect.
    /// We rely on those strategies for key transformation and only override
    /// `encode(to:)` to drop `updatedAt`, which is server-managed.
    enum CodingKeys: String, CodingKey {
        case id, name, age, units
        case fitnessLevel, monogramTone, equipment
        case preferredWorkoutTimes
        case injuries, focuses
        case sessionsPerWeek, intensity
        case enjoyedStyles, avoidedStyles
        case planningMode, manualExerciseIds, hasOnboarded
        case appearance, customStretchAreas, customExercises
        case updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(age, forKey: .age)
        try c.encode(units, forKey: .units)
        try c.encode(fitnessLevel, forKey: .fitnessLevel)
        try c.encode(monogramTone, forKey: .monogramTone)
        try c.encode(equipment, forKey: .equipment)
        try c.encode(preferredWorkoutTimes, forKey: .preferredWorkoutTimes)
        try c.encode(injuries, forKey: .injuries)
        try c.encode(focuses, forKey: .focuses)
        try c.encode(sessionsPerWeek, forKey: .sessionsPerWeek)
        try c.encode(intensity, forKey: .intensity)
        try c.encode(enjoyedStyles, forKey: .enjoyedStyles)
        try c.encode(avoidedStyles, forKey: .avoidedStyles)
        try c.encode(planningMode, forKey: .planningMode)
        try c.encode(manualExerciseIds, forKey: .manualExerciseIds)
        try c.encode(hasOnboarded, forKey: .hasOnboarded)
        try c.encodeIfPresent(appearance, forKey: .appearance)
        try c.encodeIfPresent(customStretchAreas, forKey: .customStretchAreas)
        try c.encodeIfPresent(customExercises, forKey: .customExercises)
        // Intentionally do NOT encode updatedAt: server-managed, not-null.
    }

    init(id: UUID, profile: UserProfile, hasOnboarded: Bool) {
        self.id = id
        self.name = profile.name
        self.age = profile.age
        self.units = profile.units.rawValue
        self.fitnessLevel = profile.fitnessLevel.rawValue
        self.monogramTone = profile.monogramTone
        self.equipment = Array(profile.equipment)
        self.preferredWorkoutTimes = Array(profile.workoutTimes)
        self.injuries = profile.injuries
        self.focuses = profile.focuses.map(\.rawValue)
        self.sessionsPerWeek = profile.sessionsPerWeek
        self.intensity = profile.intensity.rawValue
        self.enjoyedStyles = Array(profile.enjoyedStyles)
        self.avoidedStyles = Array(profile.avoidedStyles)
        self.planningMode = profile.planningMode.rawValue
        self.manualExerciseIds = profile.manualExerciseIds
        self.hasOnboarded = hasOnboarded
        self.appearance = profile.appearance.rawValue
        self.customStretchAreas = profile.customStretchAreas
        self.customExercises = profile.customExercises
        self.updatedAt = nil  // server-managed; we never send this on writes
    }

    func toProfile() -> UserProfile {
        var p = UserProfile()
        p.name = name
        p.age = age
        p.units = Units(rawValue: units) ?? .imperial
        p.fitnessLevel = FitnessLevel(rawValue: fitnessLevel) ?? .some
        p.monogramTone = monogramTone
        p.equipment = Set(equipment)
        p.workoutTimes = Set(preferredWorkoutTimes)
        p.injuries = injuries
        p.focuses = Set(focuses.compactMap(TrainingFocus.init(rawValue:)))
        p.sessionsPerWeek = sessionsPerWeek
        p.intensity = Intensity(rawValue: intensity) ?? .moderate
        p.enjoyedStyles = Set(enjoyedStyles)
        p.avoidedStyles = Set(avoidedStyles)
        p.planningMode = PlanningMode(rawValue: planningMode) ?? .ai
        p.manualExerciseIds = manualExerciseIds
        p.appearance = appearance.flatMap(AppearanceMode.init(rawValue:)) ?? .system
        p.customStretchAreas = customStretchAreas ?? []
        p.customExercises = customExercises ?? []
        return p
    }
}

// MARK: - Sessions / Exercises / Sets

struct SessionRow: Codable {
    var id: UUID
    var userId: UUID
    var partnerId: UUID?
    var title: String
    var startedAt: Date
    var durationSeconds: Int
}

struct ExerciseRow: Codable {
    var id: UUID
    var sessionId: UUID
    var catalogId: String
    var name: String
    var isPr: Bool
    var orderIndex: Int
}

struct SetRow: Codable {
    var id: UUID
    var exerciseId: UUID
    var setIndex: Int
    var reps: Int
    var weight: Int
    var skipped: Bool
}

// MARK: - Pairing

struct PairInviteRow: Codable {
    var id: UUID
    var fromUser: UUID
    var code: String
    var token: String
    var expiresAt: Date
    var acceptedBy: UUID?
    var acceptedAt: Date?
}

struct PartnershipRow: Codable {
    var id: UUID
    var userA: UUID
    var userB: UUID
    var pairedSince: Date
    var userALabel: String?
    var userALabelCustom: String?
    var userBLabel: String?
    var userBLabelCustom: String?

    /// Resolves "what does `me` call the other person?" given which side `me`
    /// sits on (user_a or user_b). Returns the canonical label + free-text.
    func myLabel(for me: UUID) -> (label: RelationshipLabel?, custom: String?) {
        let raw = (me == userA) ? userALabel : userBLabel
        let custom = (me == userA) ? userALabelCustom : userBLabelCustom
        return (raw.flatMap(RelationshipLabel.init(rawValue:)), custom)
    }
}

// MARK: - Live session (realtime)

struct LiveSessionRow: Codable {
    var userId: UUID
    var partnerId: UUID?
    var startedAt: Date
    var progressPct: Int
    var currentExerciseName: String?
    var currentSet: Int?
    var totalSets: Int?
    var updatedAt: Date?
}
