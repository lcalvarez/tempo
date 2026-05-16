import Foundation
import SwiftUI

// MARK: - Catalog

enum ExerciseKind: String, Codable, CaseIterable, Identifiable {
    case strength
    case bodyweight
    case timedHold
    case distance
    case timeBased
    case mobility
    /// Open-ended stopwatch. No prescribed reps/weight — user starts the
    /// timer, stretches until they're done, taps to log elapsed seconds.
    /// Persisted in `CompletedSet.reps` (as seconds) so existing storage and
    /// PR detection are unaffected.
    case stretching

    var id: String { rawValue }

    /// Human-friendly name for use in pickers and the custom-exercise sheet.
    var label: String {
        switch self {
        case .strength:   return "Strength"
        case .bodyweight: return "Bodyweight"
        case .timedHold:  return "Timed hold"
        case .distance:   return "Distance"
        case .timeBased:  return "Time-based"
        case .mobility:   return "Mobility"
        case .stretching: return "Stretching"
        }
    }

    /// Whether this kind shows the live stopwatch UI in the active session
    /// instead of the editable rep/weight numbers.
    var isStopwatch: Bool { self == .stretching }
}

/// Static exercise catalog. Real product would seed this from a server.
/// `defaultReps` / `defaultWeight` are mid-range starting points the planner
/// adjusts based on the user's fitness level + history.
struct CatalogExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: ExerciseKind
    let muscleGroups: [String]
    var defaultReps: Int = 8
    var defaultWeight: Int = 45
    var defaultSets: Int = 3
}

enum ExerciseCatalog {
    static let all: [CatalogExercise] = [
        // Lower body — barbell
        CatalogExercise(id: "back_squat",      name: "Back squat",          kind: .strength,   muscleGroups: ["Quads","Glutes"], defaultReps: 6, defaultWeight: 135, defaultSets: 4),
        CatalogExercise(id: "front_squat",     name: "Front squat",         kind: .strength,   muscleGroups: ["Quads"],          defaultReps: 6, defaultWeight: 115, defaultSets: 4),
        CatalogExercise(id: "deadlift",        name: "Deadlift",            kind: .strength,   muscleGroups: ["Hamstrings","Back","Glutes"], defaultReps: 5, defaultWeight: 185, defaultSets: 3),
        CatalogExercise(id: "romanian_dl",     name: "Romanian deadlift",   kind: .strength,   muscleGroups: ["Hamstrings","Glutes"], defaultReps: 8, defaultWeight: 135, defaultSets: 3),
        CatalogExercise(id: "hip_thrust",      name: "Hip thrust",          kind: .strength,   muscleGroups: ["Glutes"],         defaultReps: 10, defaultWeight: 95, defaultSets: 3),

        // Lower body — dumbbell / bodyweight
        CatalogExercise(id: "goblet_squat",    name: "Goblet squat",        kind: .strength,   muscleGroups: ["Quads","Glutes"], defaultReps: 8, defaultWeight: 35, defaultSets: 4),
        CatalogExercise(id: "walking_lunge",   name: "Walking lunge",       kind: .bodyweight, muscleGroups: ["Quads","Glutes"], defaultReps: 20, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "reverse_lunge",   name: "Reverse lunge",       kind: .bodyweight, muscleGroups: ["Quads","Glutes"], defaultReps: 16, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "bulgarian_split", name: "Bulgarian split squat",kind: .bodyweight,muscleGroups: ["Quads","Glutes"], defaultReps: 10, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "calf_raise",      name: "Calf raise",          kind: .bodyweight, muscleGroups: ["Calves"],         defaultReps: 12, defaultWeight: 0, defaultSets: 4),
        CatalogExercise(id: "step_up",         name: "Step-up",             kind: .strength,   muscleGroups: ["Quads","Glutes"], defaultReps: 12, defaultWeight: 20, defaultSets: 3),

        // Upper body — push
        CatalogExercise(id: "bench_press",     name: "Bench press",         kind: .strength,   muscleGroups: ["Chest"],          defaultReps: 5, defaultWeight: 135, defaultSets: 4),
        CatalogExercise(id: "incline_db_press",name: "Incline DB press",    kind: .strength,   muscleGroups: ["Chest"],          defaultReps: 10, defaultWeight: 40, defaultSets: 3),
        CatalogExercise(id: "overhead_press",  name: "Overhead press",      kind: .strength,   muscleGroups: ["Shoulders"],      defaultReps: 6, defaultWeight: 75, defaultSets: 4),
        CatalogExercise(id: "push_up",         name: "Push-up",             kind: .bodyweight, muscleGroups: ["Chest"],          defaultReps: 12, defaultWeight: 0, defaultSets: 3),

        // Upper body — pull
        CatalogExercise(id: "pull_up",         name: "Pull-up",             kind: .bodyweight, muscleGroups: ["Back"],           defaultReps: 8, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "barbell_row",     name: "Barbell row",         kind: .strength,   muscleGroups: ["Back"],           defaultReps: 8, defaultWeight: 95, defaultSets: 4),
        CatalogExercise(id: "lat_pulldown",    name: "Lat pulldown",        kind: .strength,   muscleGroups: ["Back"],           defaultReps: 10, defaultWeight: 100, defaultSets: 3),

        // Core
        CatalogExercise(id: "plank",           name: "Plank",               kind: .timedHold,  muscleGroups: ["Core"],           defaultReps: 45, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "side_plank",      name: "Side plank",          kind: .timedHold,  muscleGroups: ["Core"],           defaultReps: 30, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "hanging_leg",     name: "Hanging leg raise",   kind: .bodyweight, muscleGroups: ["Core"],           defaultReps: 12, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "dead_bug",        name: "Dead bug",            kind: .bodyweight, muscleGroups: ["Core"],           defaultReps: 12, defaultWeight: 0, defaultSets: 3),
        CatalogExercise(id: "bridge",          name: "Bridge",              kind: .bodyweight, muscleGroups: ["Glutes","Core"],  defaultReps: 15, defaultWeight: 0, defaultSets: 3),

        // Cardio
        CatalogExercise(id: "easy_run",        name: "Easy run",            kind: .distance,   muscleGroups: ["Cardio"],         defaultReps: 0, defaultWeight: 0, defaultSets: 1),
        CatalogExercise(id: "bike",            name: "Stationary bike",     kind: .timeBased,  muscleGroups: ["Cardio"],         defaultReps: 0, defaultWeight: 0, defaultSets: 1),
        CatalogExercise(id: "row_erg",         name: "Rowing",              kind: .distance,   muscleGroups: ["Cardio","Back"],  defaultReps: 0, defaultWeight: 0, defaultSets: 1),

        // Mobility
        CatalogExercise(id: "world_greatest",  name: "World's greatest stretch", kind: .mobility, muscleGroups: ["Mobility"],   defaultReps: 10, defaultWeight: 0, defaultSets: 2),
        CatalogExercise(id: "couch_stretch",   name: "Couch stretch",       kind: .mobility,   muscleGroups: ["Mobility"],       defaultReps: 30, defaultWeight: 0, defaultSets: 2),
    ]

    static func find(_ id: String) -> CatalogExercise? {
        all.first { $0.id == id }
    }

    static func byKind(_ k: ExerciseKind) -> [CatalogExercise] { all.filter { $0.kind == k } }

    /// Look up an exercise across both the static catalog and the user's
    /// custom exercises. Use this everywhere you'd previously call `find()`
    /// — most callsites now need to resolve user-defined IDs the catalog
    /// doesn't know about (history rows from old custom exercises, etc.).
    static func resolve(_ id: String, with custom: [CustomExercise]) -> CatalogExercise? {
        if let c = find(id) { return c }
        return custom.first(where: { $0.id == id })?.asCatalog()
    }
}

// MARK: - Stretching

/// Canonical body areas the stretching picker offers as one-tap chips.
/// Users can add their own areas via `UserProfile.customStretchAreas`; the
/// merge happens at picker render time so the canonical list stays stable.
enum StretchArea: String, CaseIterable, Codable, Identifiable {
    case hamstrings, hips, shoulders, back, chest, quads, calves, neck, fullBody

    var id: String { rawValue }
    var label: String {
        switch self {
        case .hamstrings: return "Hamstrings"
        case .hips:       return "Hips"
        case .shoulders:  return "Shoulders"
        case .back:       return "Back"
        case .chest:      return "Chest"
        case .quads:      return "Quads"
        case .calves:     return "Calves"
        case .neck:       return "Neck"
        case .fullBody:   return "Full body"
        }
    }
    /// Muscle group used for grouping in history / future analytics. Aligns
    /// with the strings used elsewhere so reports can roll up cleanly.
    var muscleGroup: String { label }
}

// MARK: - Custom user exercises

/// User-defined exercise. Stored on the profile (locally for now, syncs
/// to Supabase later as one row per entry). Surfaced everywhere the catalog
/// is — manual-mode picker, in-session add, and the AI planner picks them
/// up via `ExerciseCatalog.resolve` if the user assigned muscle groups.
struct CustomExercise: Identifiable, Codable, Hashable {
    /// Stable string ID (`custom_<uuid>`) so it can sit alongside catalog
    /// IDs in `manualExerciseIds`, completed-session exercises, etc.
    var id: String
    var name: String
    var kind: ExerciseKind
    /// Optional — empty means "don't surface to AI suggestions".
    var muscleGroups: [String]
    var defaultSets: Int = 3
    var defaultReps: Int = 8
    var defaultWeight: Int = 0

    static func newID() -> String { "custom_\(UUID().uuidString.prefix(12))" }

    /// Adapt to a `CatalogExercise` so existing planner / picker code paths
    /// don't need to know whether an entry is built-in or user-defined.
    func asCatalog() -> CatalogExercise {
        CatalogExercise(
            id: id, name: name, kind: kind, muscleGroups: muscleGroups,
            defaultReps: defaultReps, defaultWeight: defaultWeight, defaultSets: defaultSets
        )
    }
}

// MARK: - Domain types

enum Units: String, Codable, CaseIterable {
    case imperial, metric
    var label: String { self == .imperial ? "lbs · mi" : "kg · km" }
    var weightUnit: String { self == .imperial ? "lb" : "kg" }
    var distanceUnit: String { self == .imperial ? "mi" : "km" }
}

/// User-controlled appearance. Defaults to `.system` so we follow whatever
/// the OS is doing — most users' expectation in 2026.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    var subtitle: String {
        switch self {
        case .system: return "Follow iOS"
        case .light:  return "Always light"
        case .dark:   return "Always dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    /// SwiftUI `preferredColorScheme` value. `nil` means "follow system".
    var swiftUIScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum FitnessLevel: String, Codable, CaseIterable {
    case new, some, strong, advanced
    var label: String { self == .new ? "New" : self == .some ? "Some" : self == .strong ? "Strong" : "Advanced" }
    /// Multiplier applied to the catalog's default weights.
    var weightMultiplier: Double {
        switch self {
        case .new: return 0.55
        case .some: return 0.85
        case .strong: return 1.0
        case .advanced: return 1.15
        }
    }
}

enum TrainingFocus: String, Codable, CaseIterable {
    case strength, hypertrophy, endurance, weightLoss, mobility, general
    var label: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance: return "Endurance"
        case .weightLoss: return "Weight loss"
        case .mobility: return "Mobility"
        case .general: return "General"
        }
    }
    var subtitle: String {
        switch self {
        case .strength: return "Heavier · fewer reps"
        case .hypertrophy: return "Build muscle · 8–12 reps"
        case .endurance: return "Conditioning · capacity"
        case .weightLoss: return "Calorie deficit, retain"
        case .mobility: return "Range · injury-proofing"
        case .general: return "Just stay healthy"
        }
    }
}

/// How sessions get planned. Most users will pick `.ai`; advanced users who
/// want to design every workout themselves pick `.manual`.
enum PlanningMode: String, Codable, CaseIterable {
    case ai
    case manual

    var title: String {
        switch self {
        case .ai:     return "Let your AI trainer plan it"
        case .manual: return "I'll plan it myself"
        }
    }

    var subtitle: String {
        switch self {
        case .ai:     return "Your AI trainer builds each session from your goals and adjusts as you progress."
        case .manual: return "Pick exercises from the full catalog. Best for advanced lifters with a specific program."
        }
    }

    var badge: String? {
        switch self {
        case .ai:     return "Recommended"
        case .manual: return "Advanced"
        }
    }
}

enum Intensity: String, Codable, CaseIterable {
    case easy, moderate, hard, brutal
    var label: String { self == .easy ? "Easy" : self == .moderate ? "Moderate" : self == .hard ? "Hard" : "Brutal" }
    var subtitle: String {
        switch self {
        case .easy: return "Light · sustainable"
        case .moderate: return "Solid effort"
        case .hard: return "Pushing limits"
        case .brutal: return "No survivors"
        }
    }
    var setMultiplier: Double {
        switch self {
        case .easy: return 0.75
        case .moderate: return 1.0
        case .hard: return 1.15
        case .brutal: return 1.3
        }
    }
}

/// Per-user profile, populated by onboarding and editable in Profile/Goals.
struct UserProfile: Codable {
    var name: String = ""
    var age: Int = 30
    var units: Units = .imperial
    var fitnessLevel: FitnessLevel = .some
    var equipment: Set<String> = ["Full gym"]
    var workoutTimes: Set<String> = ["Morning", "Evening"]
    var injuries: String = ""
    var monogramTone: String = "you"   // "you" / "partner" / "accent" / "neutral"

    // Goals
    var focuses: Set<TrainingFocus> = [.strength, .hypertrophy]
    var sessionsPerWeek: Int = 4
    var intensity: Intensity = .moderate
    var enjoyedStyles: Set<String> = ["Free weights", "Conditioning"]
    var avoidedStyles: Set<String> = ["Long cardio"]

    // Planning mode
    var planningMode: PlanningMode = .ai

    // Appearance — `.system` follows iOS Light/Dark.
    var appearance: AppearanceMode = .system

    /// When `planningMode == .manual`, this is the user's hand-picked list of
    /// exercise IDs. The planner uses these directly instead of choosing from
    /// the catalog. Empty means "I haven't built one yet — fall back to AI."
    var manualExerciseIds: [String] = []

    /// User-defined exercises. Available everywhere the catalog is.
    var customExercises: [CustomExercise] = []

    /// Extra body areas the user has added to the stretching picker beyond
    /// the canonical `StretchArea` list. Persists across sessions so frequent
    /// areas show up as one-tap chips next time.
    var customStretchAreas: [String] = []

    /// What we display for "you" everywhere (chips, plan columns, comparison
    /// rows, etc.). Falls back to "You" when name hasn't been entered yet.
    var youLabel: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "You" : trimmed
    }

    /// First letter for the avatar monogram. Same fallback rules as `youLabel`.
    var youInitial: String {
        String(youLabel.prefix(1)).uppercased()
    }
}

/// What you call the other person in the partnership. Each side picks their
/// own label — you might call her "Wife" while she calls you "Husband" — so
/// this lives on `PartnerProfile` (the local view of who they are *to me*),
/// not on a shared partnership object.
///
/// `.other` carries a free-form `customLabel` string for everything we
/// don't enumerate ("training buddy", "sister-in-law", "kid", …).
enum RelationshipLabel: String, Codable, CaseIterable, Identifiable {
    case wife, husband, spouse
    case partner
    case friend
    case sibling
    case parent, child
    case trainer
    case other

    var id: String { rawValue }

    /// Singular noun used inline ("your wife Andrea", "your friend Sam").
    /// For `.other` we fall back to "partner" — caller is expected to use
    /// `noun(custom:)` instead when they have the user's free-text label.
    var noun: String {
        switch self {
        case .wife: return "wife"
        case .husband: return "husband"
        case .spouse: return "spouse"
        case .partner: return "partner"
        case .friend: return "friend"
        case .sibling: return "sibling"
        case .parent: return "parent"
        case .child: return "child"
        case .trainer: return "trainer"
        case .other: return "partner"
        }
    }

    /// Picker-friendly title for the `RelationshipPickerSheet`.
    var pickerTitle: String {
        switch self {
        case .wife: return "Wife"
        case .husband: return "Husband"
        case .spouse: return "Spouse"
        case .partner: return "Partner"
        case .friend: return "Friend"
        case .sibling: return "Sibling"
        case .parent: return "Parent"
        case .child: return "Child"
        case .trainer: return "Trainer / Coach"
        case .other: return "Other…"
        }
    }

    /// Cluster the picker rows so the sheet doesn't read as one long list.
    var section: RelationshipSection {
        switch self {
        case .wife, .husband, .spouse, .partner: return .romantic
        case .friend, .sibling, .parent, .child: return .personal
        case .trainer: return .professional
        case .other: return .freeform
        }
    }

    /// Resolves the noun to use, preferring user-typed custom text when set.
    static func noun(_ label: RelationshipLabel?, custom: String?) -> String {
        if let custom = custom?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom.lowercased()
        }
        return label?.noun ?? "partner"
    }
}

enum RelationshipSection: String, CaseIterable {
    case romantic, personal, professional, freeform

    var title: String {
        switch self {
        case .romantic: return "Romantic"
        case .personal: return "Family & friends"
        case .professional: return "Professional"
        case .freeform: return "Other"
        }
    }
}

/// Pairing state — set when partner accepts a code.
///
/// Note: this is a local mirror of *what we know about* the other person.
/// In production the partner's authoritative profile lives in their own
/// Postgres row; we read the parts we need (goals, level, equipment) via
/// the `my_partner` view to plan an independent session for them.
struct PartnerProfile: Codable {
    var name: String = "Andrea"
    var initial: String { String(name.prefix(1)).uppercased() }
    var pairedSinceISO: String = "Mar 28"
    var online: Bool = true
    var totalSessions: Int = 23
    var togetherTimeMinutes: Int = 1144   // 19h 04m
    var jointPRs: Int = 7

    // ── The partner's own goals/level (drives independent planning) ──────
    //
    // These mirror the equivalents on `UserProfile`. They're populated by
    // `SyncStore.fetchPartner()` against Supabase; default values exist so
    // the seeded demo partner ("Andrea") can showcase a goal-divergent pair
    // out-of-the-box.
    var fitnessLevel: FitnessLevel = .some
    var focuses: Set<TrainingFocus> = [.endurance, .general]   // diverges from default user (.strength + .hypertrophy)
    var intensity: Intensity = .moderate
    var equipment: Set<String> = ["Full gym"]
    var avoidedStyles: Set<String> = []

    /// What I call this person. `nil` means "not yet picked" — UI should
    /// show the `RelationshipPickerSheet` to capture it.
    var relationshipLabel: RelationshipLabel? = nil
    /// Free-form text used when `relationshipLabel == .other`.
    var relationshipCustom: String? = nil

    /// Convenience for inline copy. Call this everywhere we say "partner".
    var noun: String { RelationshipLabel.noun(relationshipLabel, custom: relationshipCustom) }
}

// MARK: - Plans & sessions

struct ExercisePlan: Identifiable, Hashable, Codable {
    var id = UUID()
    var catalogId: String
    var name: String
    var sets: Int
    var reps: Int
    var weight: Int       // in user's units; 0 for bodyweight
    var kind: ExerciseKind
    var meta: String {
        switch kind {
        case .strength: return "\(sets) × \(reps) · \(weight) \(weight > 0 ? "lb" : "")".trimmingCharacters(in: .whitespaces)
        case .bodyweight: return "\(sets) × \(reps)"
        case .timedHold: return "\(sets) × \(reps)s"
        case .distance, .timeBased: return "\(reps) min"
        case .mobility: return "\(sets) × \(reps)"
        case .stretching: return "Stretch · stopwatch"
        }
    }
}

struct SessionPlan: Identifiable, Codable {
    var id = UUID()

    /// User's session theme + duration.
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var youPlan: [ExercisePlan]
    var muscleGroups: [String] = []

    /// Partner's session theme + duration. Independently generated from the
    /// partner's own `focuses` / `fitnessLevel` / `intensity` — may match the
    /// user's theme exactly (goal-aligned pair) or look completely different
    /// (goal-divergent pair).
    var partnerTitle: String = ""
    var partnerSubtitle: String = ""
    var partnerDurationMinutes: Int = 0
    var partnerPlan: [ExercisePlan]
    var partnerMuscleGroups: [String] = []

    var generatedAt: Date = Date()

    /// True when the user and partner ended up on different body themes for
    /// this session. Drives whether the UI shows two subtitles, two timers,
    /// and the "Independent" mode chip.
    var themesDiverge: Bool {
        let yours    = Set(muscleGroups)
        let theirs   = Set(partnerMuscleGroups)
        // Consider them diverged when the muscle-group sets share <50%.
        if yours.isEmpty || theirs.isEmpty { return false }
        let overlap = yours.intersection(theirs).count
        let union   = yours.union(theirs).count
        return Double(overlap) / Double(union) < 0.5
    }
}

/// One completed set — stored per exercise inside `CompletedSession`.
struct CompletedSet: Codable, Identifiable {
    var id = UUID()
    var reps: Int
    var weight: Int
    var skipped: Bool = false
}

struct CompletedExercise: Codable, Identifiable {
    var id = UUID()
    var catalogId: String
    var name: String
    var sets: [CompletedSet]
    var isPR: Bool = false
}

struct CompletedSession: Codable, Identifiable {
    var id = UUID()
    var title: String
    /// Partner's session title at the time it was completed. Empty for solo
    /// sessions or for legacy entries written before independent planning
    /// landed. When non-empty *and* different from `title`, history rows
    /// surface the divergence ("Push day · Andrea was on conditioning").
    var partnerTitle: String = ""
    var date: Date
    var durationSeconds: Int
    var you: [CompletedExercise]
    var partner: [CompletedExercise]
    var prCount: Int { you.filter(\.isPR).count + partner.filter(\.isPR).count }
}

// MARK: - History entries (legacy display type)
struct HistoryEntry: Identifiable {
    let id = UUID()
    var day: String
    var month: String
    var title: String
    var duration: String
    var exerciseCount: Int
    var prCount: Int
    var weekGroup: String
}

struct TopLift: Identifiable {
    let id = UUID()
    var name: String
    var best: String
    var delta: String
    var direction: TrendDirection
}
enum TrendDirection { case up, down, flat }

// MARK: - Today state

enum TodayState { case ready, inProgress, rest }

/// Lightweight display-side value type used by `PartnerPip` and `Avatar`.
/// The persisted full record is `PartnerProfile`; we convert at the boundary.
struct Partner {
    var name: String
    var initial: String
    var online: Bool
}

// MARK: - Mock AI planner

/// Generates a session plan for both partners.
///
/// Each side gets its **own** theme generated from its **own** focuses,
/// fitness level, intensity, and avoided styles. There's no goal mirroring
/// between partners — Tempo's "in tempo" promise is about presence and
/// rhythm, not about doing identical workouts.
///
/// Deterministic-ish — same inputs produce the same plan within a day,
/// rotating through focus areas across days of the week.
enum PlanGenerator {

    /// Goal-bearing inputs for one side of a paired session. We accept this
    /// reduced struct (rather than passing `UserProfile` and `PartnerProfile`
    /// separately) so the planner has zero coupling to whose plan it's
    /// building — same code path runs twice per pair.
    struct PlanInputs {
        var focuses: Set<TrainingFocus>
        var fitnessLevel: FitnessLevel
        var intensity: Intensity
        var avoidedStyles: Set<String>

        /// Adapter from the live `UserProfile` (the user) and `PartnerProfile`
        /// (the partner) so callsites stay readable.
        init(user: UserProfile) {
            self.focuses = user.focuses
            self.fitnessLevel = user.fitnessLevel
            self.intensity = user.intensity
            self.avoidedStyles = user.avoidedStyles
        }

        init(partner: PartnerProfile) {
            self.focuses = partner.focuses
            self.fitnessLevel = partner.fitnessLevel
            self.intensity = partner.intensity
            self.avoidedStyles = partner.avoidedStyles
        }
    }

    static func generateNextSession(for user: UserProfile, partner: PartnerProfile, calendarDay: Int = Calendar.current.component(.day, from: Date())) -> SessionPlan {
        // Manual mode: build the user's plan from their hand-picked list, but
        // still let the partner have an independently-planned session.
        if user.planningMode == .manual && !user.manualExerciseIds.isEmpty {
            return manualPlan(for: user, partner: partner, calendarDay: calendarDay)
        }

        // Generate each side independently.
        let you  = buildSide(inputs: PlanInputs(user: user),
                             calendarDay: calendarDay,
                             seedSalt: "you")
        let them = buildSide(inputs: PlanInputs(partner: partner),
                             calendarDay: calendarDay,
                             seedSalt: "partner")

        return SessionPlan(
            title: you.title,
            subtitle: you.subtitle,
            durationMinutes: you.durationMinutes,
            youPlan: you.exercises,
            muscleGroups: you.theme.muscleGroups,
            partnerTitle: them.title,
            partnerSubtitle: them.subtitle,
            partnerDurationMinutes: them.durationMinutes,
            partnerPlan: them.exercises,
            partnerMuscleGroups: them.theme.muscleGroups
        )
    }

    /// Result of building one side's plan. Internal — never escapes the planner.
    private struct SideResult {
        var title: String
        var subtitle: String
        var durationMinutes: Int
        var exercises: [ExercisePlan]
        var theme: BodyTheme
    }

    /// Single code path for either side. Picks a theme from `inputs.focuses`,
    /// scales by their fitness level + intensity, returns an estimated total
    /// session duration. `seedSalt` lets us produce different exercise
    /// orderings for two people on the same theme so they don't see literally
    /// identical lists.
    private static func buildSide(inputs: PlanInputs, calendarDay: Int, seedSalt: String) -> SideResult {
        // Pick a focus area by rotating through what they chose.
        let focuses = Array(inputs.focuses).sorted { $0.rawValue < $1.rawValue }
        let primary: TrainingFocus = focuses.isEmpty ? .general : focuses[calendarDay % max(1, focuses.count)]
        let theme = themeForDay(calendarDay, primary: primary)

        let setBudget = max(4, Int(8.0 * inputs.intensity.setMultiplier))
        let exercises = pickExercises(
            theme: theme,
            count: setBudget,
            avoiding: inputs.avoidedStyles,
            seedSalt: seedSalt
        ).map { ex in adjust(ex, inputs: inputs) }

        let (title, subtitle) = theme.titleAndSubtitle()
        return SideResult(
            title: title,
            subtitle: subtitle,
            durationMinutes: max(30, setBudget * 5),
            exercises: exercises,
            theme: theme
        )
    }

    // MARK: theme

    enum BodyTheme {
        case lower, upperPush, upperPull, fullBody, conditioning, mobility

        var muscleGroups: [String] {
            switch self {
            case .lower:        return ["Quads","Glutes","Hamstrings"]
            case .upperPush:    return ["Chest","Shoulders"]
            case .upperPull:    return ["Back"]
            case .fullBody:     return ["Quads","Chest","Back","Core"]
            case .conditioning: return ["Cardio","Core"]
            case .mobility:     return ["Mobility"]
            }
        }

        func titleAndSubtitle() -> (String, String) {
            switch self {
            case .lower:        return ("Lower body", "& core")
            case .upperPush:    return ("Upper body", "push day")
            case .upperPull:    return ("Pull day", "& accessories")
            case .fullBody:     return ("Full body", "circuit")
            case .conditioning: return ("Conditioning", "& core")
            case .mobility:     return ("Mobility", "+ recovery")
            }
        }
    }

    private static func themeForDay(_ day: Int, primary: TrainingFocus) -> BodyTheme {
        switch primary {
        case .mobility: return .mobility
        case .endurance, .weightLoss: return day % 2 == 0 ? .conditioning : .fullBody
        case .strength, .hypertrophy, .general:
            switch day % 4 {
            case 0: return .lower
            case 1: return .upperPush
            case 2: return .upperPull
            default: return .fullBody
            }
        }
    }

    // MARK: exercise selection

    private static func pickExercises(theme: BodyTheme, count: Int, avoiding: Set<String>, seedSalt: String = "") -> [ExercisePlan] {
        let pool = ExerciseCatalog.all.filter { ex in
            theme.muscleGroups.contains(where: { ex.muscleGroups.contains($0) })
                && !avoiding.contains(where: { ex.name.lowercased().contains($0.lowercased()) })
        }
        // Stable, semi-rotated selection. Salting the seed lets two people on
        // the same theme see different orderings (and thus different first
        // exercises), which keeps "we're both doing legs" feeling distinct.
        let seed = theme.muscleGroups.joined() + seedSalt
        let rotated = Array(pool.shuffled(seed: seed).prefix(count))
        return rotated.map { c in
            ExercisePlan(
                catalogId: c.id, name: c.name,
                sets: c.defaultSets, reps: c.defaultReps,
                weight: c.defaultWeight, kind: c.kind
            )
        }
    }

    /// Scale a raw catalog exercise to a side's level + focus bias. Single
    /// path for user and partner — driven by `PlanInputs`, not whose plan it is.
    private static func adjust(_ ex: ExercisePlan, inputs: PlanInputs) -> ExercisePlan {
        var copy = ex
        let mult = inputs.fitnessLevel.weightMultiplier
        if copy.weight > 0 {
            copy.weight = Int((Double(copy.weight) * mult / 5).rounded()) * 5
        }
        // Hypertrophy bias: more reps, slightly less weight.
        if inputs.focuses.contains(.hypertrophy) && copy.kind == .strength {
            copy.reps = min(12, copy.reps + 2)
            let lighter = (Double(copy.weight) * 0.9 / 5.0).rounded(.up) * 5.0
            copy.weight = Int(lighter)
        }
        // Strength bias (without hypertrophy): fewer reps, hold the weight.
        if inputs.focuses.contains(.strength) && copy.kind == .strength && !inputs.focuses.contains(.hypertrophy) {
            copy.reps = max(4, copy.reps - 1)
        }
        return copy
    }

    // MARK: manual mode

    private static func manualPlan(for user: UserProfile, partner: PartnerProfile, calendarDay: Int) -> SessionPlan {
        let userInputs = PlanInputs(user: user)
        // Resolve through the merged catalog so user-defined IDs are valid.
        let youExercises: [ExercisePlan] = user.manualExerciseIds.compactMap { id in
            guard let c = ExerciseCatalog.resolve(id, with: user.customExercises) else { return nil }
            return ExercisePlan(
                catalogId: c.id, name: c.name,
                sets: c.defaultSets, reps: c.defaultReps,
                weight: c.defaultWeight, kind: c.kind
            )
        }.map { adjust($0, inputs: userInputs) }

        // Derive the user's theme from what they hand-picked, so we can
        // describe their session in the title strip.
        let yourGroups = Set(youExercises.flatMap { ExerciseCatalog.resolve($0.catalogId, with: user.customExercises)?.muscleGroups ?? [] })
        let yourTheme = themeFromGroups(yourGroups)
        let (yTitle, ySub) = yourTheme.titleAndSubtitle()

        // Partner still gets an *independent* AI plan from their own goals —
        // they don't have to do whatever the user manually picked.
        let them = buildSide(inputs: PlanInputs(partner: partner),
                             calendarDay: calendarDay,
                             seedSalt: "partner")

        return SessionPlan(
            title: yTitle,
            subtitle: ySub,
            durationMinutes: max(30, youExercises.count * 5),
            youPlan: youExercises,
            muscleGroups: Array(yourGroups),
            partnerTitle: them.title,
            partnerSubtitle: them.subtitle,
            partnerDurationMinutes: them.durationMinutes,
            partnerPlan: them.exercises,
            partnerMuscleGroups: them.theme.muscleGroups
        )
    }

    private static func themeFromGroups(_ groups: Set<String>) -> BodyTheme {
        if groups.contains(where: { ["Quads","Glutes","Hamstrings"].contains($0) }) { return .lower }
        if groups.contains("Chest") || groups.contains("Shoulders") { return .upperPush }
        if groups.contains("Back") { return .upperPull }
        if groups.contains("Cardio") { return .conditioning }
        if groups.contains("Mobility") { return .mobility }
        return .fullBody
    }
}

// Deterministic shuffle so we get the same plan order in a given session.
private extension Array {
    func shuffled(seed: String) -> [Element] {
        var hasher = Hasher()
        hasher.combine(seed)
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(hasher.finalize())))
        return shuffled(using: &rng)
    }
}

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}

// MARK: - Persisted store

/// Single source of truth, persists to UserDefaults so onboarding state and
/// completed sessions survive relaunches. Strip this out and replace with a
/// real backend once the v1 server exists.
final class SessionStore: ObservableObject {

    // Onboarding
    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: K.hasOnboarded) }
    }

    @Published var profile: UserProfile {
        didSet {
            persist(profile, forKey: K.profile)
            onProfileMutated?()
        }
    }

    @Published var partner: PartnerProfile {
        didSet {
            persist(partner, forKey: K.partner)
            onPartnerMutated?()
        }
    }

    @Published var isPaired: Bool {
        didSet { defaults.set(isPaired, forKey: K.isPaired) }
    }

    /// User explicitly chose "I'll workout solo" on the invite screen.
    /// We surface different copy (no partner column on Today, History, etc.)
    /// but they can still send an invite later from Profile.
    @Published var isSolo: Bool {
        didSet { defaults.set(isSolo, forKey: K.isSolo) }
    }

    // MARK: - Sync hooks
    //
    // Models stay free of `Supabase` imports. A `RemoteSync` mediator is
    // owned by the App scene and installs these closures at launch. When
    // unset (e.g. in previews), all writes are local-only — exactly the v1
    // behavior, so previews don't accidentally hit a backend.

    /// Fired after `profile` mutates via the UI. The mediator debounces
    /// these into a single Supabase PATCH.
    var onProfileMutated: (() -> Void)?

    /// Fired after `partner` mutates via the UI.
    var onPartnerMutated: (() -> Void)?

    @Published var pendingCode: String? {
        didSet { defaults.set(pendingCode, forKey: K.pendingCode) }
    }

    /// The deep-link token attached to the most recent invite. We persist it
    /// so that re-opening the share sheet (e.g. user hit cancel in Messages)
    /// reuses the same token instead of rotating it.
    @Published var pendingInviteToken: String? {
        didSet { defaults.set(pendingInviteToken, forKey: K.pendingInviteToken) }
    }

    // Plans & history
    @Published var todayPlan: SessionPlan {
        didSet { persist(todayPlan, forKey: K.todayPlan) }
    }

    @Published var history: [CompletedSession] {
        didSet { persist(history, forKey: K.history) }
    }

    @Published var todayState: TodayState = .ready

    // Active session (transient; not persisted between launches)
    @Published var youProgressPct: Double = 0
    @Published var partnerProgressPct: Double = 22
    @Published var elapsed: String = "00:00"
    @Published var currentExerciseIndex: Int = 1
    @Published var sessionStartedAt: Date? = nil

    /// What the paired partner is doing *right now*, as observed via the
    /// realtime channel on `public.live_sessions`. `nil` whenever the
    /// partner isn't in an active session (or we're not paired). Populated
    /// by `RemoteSync.subscribeToPartnerLive`. Never persisted — purely a
    /// transient signal driving the "Alex is in the middle of leg day"
    /// banner on Today.
    @Published var partnerActivity: PartnerActivity? = nil

    /// Transient toast surfaced from any view. Auto-dismisses after a short delay.
    @Published var toast: Toast? = nil

    func showToast(_ message: String, icon: String = "checkmark.circle.fill") {
        let new = Toast(message: message, icon: icon)
        toast = new
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            // Only clear if this toast is still the current one.
            if toast?.id == new.id { toast = nil }
        }
    }

    // MARK: keys

    private let defaults = UserDefaults.standard
    private enum K {
        static let hasOnboarded = "hasOnboarded"
        static let profile = "profile"
        static let partner = "partner"
        static let isPaired = "isPaired"
        static let isSolo = "isSolo"
        static let pendingCode = "pendingCode"
        static let pendingInviteToken = "pendingInviteToken"
        static let todayPlan = "todayPlan"
        static let history = "history"
        static let partnershipId = "partnershipId"
        static let partnerUserId = "partnerUserId"
    }

    // MARK: init

    init() {
        let d = UserDefaults.standard
        self.hasOnboarded = d.bool(forKey: K.hasOnboarded)
        self.isPaired     = d.bool(forKey: K.isPaired)
        self.isSolo       = d.bool(forKey: K.isSolo)
        self.pendingCode  = d.string(forKey: K.pendingCode)
        self.pendingInviteToken = d.string(forKey: K.pendingInviteToken)
        self.partnershipId = d.string(forKey: K.partnershipId).flatMap(UUID.init(uuidString:))
        self.partnerUserId = d.string(forKey: K.partnerUserId).flatMap(UUID.init(uuidString:))

        self.profile = Self.read(UserProfile.self, key: K.profile) ?? UserProfile()
        self.partner = Self.read(PartnerProfile.self, key: K.partner) ?? PartnerProfile()
        self.history = Self.read([CompletedSession].self, key: K.history) ?? []

        // Generate or restore today's plan
        if let plan = Self.read(SessionPlan.self, key: K.todayPlan),
           Calendar.current.isDateInToday(plan.generatedAt) {
            self.todayPlan = plan
        } else {
            self.todayPlan = PlanGenerator.generateNextSession(
                for: Self.read(UserProfile.self, key: K.profile) ?? UserProfile(),
                partner: Self.read(PartnerProfile.self, key: K.partner) ?? PartnerProfile()
            )
        }
    }

    // MARK: actions

    func resetOnboarding() {
        for key in [K.hasOnboarded, K.profile, K.partner, K.isPaired, K.isSolo,
                    K.pendingCode, K.pendingInviteToken, K.todayPlan, K.history,
                    K.partnershipId, K.partnerUserId] {
            defaults.removeObject(forKey: key)
        }
        hasOnboarded = false
        profile = UserProfile()
        partner = PartnerProfile()
        isPaired = false
        isSolo = false
        pendingCode = nil
        pendingInviteToken = nil
        partnershipId = nil
        partnerUserId = nil
        history = []
        regenerateTodayPlan()
    }

    func regenerateTodayPlan() {
        todayPlan = PlanGenerator.generateNextSession(for: profile, partner: partner)
    }

    /// Append an exercise to today's plan. Used by the in-session add flow
    /// and by anywhere else that needs to splice in something the planner
    /// didn't know about (stretching, ad-hoc accessory work, custom lifts).
    func appendToTodayPlan(_ ex: ExercisePlan) {
        todayPlan.youPlan.append(ex)
    }

    /// Persist a brand-new custom exercise. Returns the inserted entry.
    @discardableResult
    func addCustomExercise(_ ex: CustomExercise) -> CustomExercise {
        profile.customExercises.append(ex)
        return ex
    }

    func updateCustomExercise(_ ex: CustomExercise) {
        guard let i = profile.customExercises.firstIndex(where: { $0.id == ex.id }) else { return }
        profile.customExercises[i] = ex
    }

    func deleteCustomExercise(id: String) {
        profile.customExercises.removeAll { $0.id == id }
        // Also pull from the manual list so we don't render dangling references.
        profile.manualExerciseIds.removeAll { $0 == id }
    }

    /// Add a stretch area to the user's saved list (de-duped, keeps insertion
    /// order so most-recently-added shows up first when surfaced as chips).
    func addStretchArea(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !profile.customStretchAreas.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }),
              !StretchArea.allCases.contains(where: { $0.label.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        profile.customStretchAreas.insert(trimmed, at: 0)
    }

    /// Hook installed by `RemoteSync.attach`. Calls
    /// `create_pair_invite` server-side and stamps `pendingCode` /
    /// `pendingInviteToken` with the result. The view layer only sees
    /// "pendingCode flipped from nil to something."
    var requestRemoteInvite: (() async -> Void)?

    /// Hook installed by `RemoteSync.attach`. Calls `accept_pair_invite`
    /// with whichever arg is non-nil and refreshes partner state on success.
    /// The view layer awaits this and then renders accordingly.
    var acceptRemoteInvite: ((_ code: String?, _ token: String?) async throws -> Void)?

    /// Hook installed by `RemoteSync.attach`. Pushes the partner relationship
    /// label up to the server using the `set_relationship_label` RPC.
    var pushRelationshipLabel: ((_ label: RelationshipLabel, _ custom: String?) async -> Void)?

    /// Generate (or rotate) the user's pending pair invite. Always goes
    /// through the server now — the previous local-random fallback was
    /// removed because partner pairing is meaningless without a backend.
    func generatePendingCode() {
        guard let request = requestRemoteInvite else {
            // No remote available (e.g. previews). Don't fabricate a code:
            // empty pendingCode keeps the UI in a "loading invite…" state
            // rather than showing a fake code that won't accept.
            return
        }
        Task { await request() }
    }

    /// Mark the user as a solo lifter (skipped the invite step). Idempotent;
    /// they can still send an invite later from Profile.
    func chooseSolo() {
        isSolo = true
        pendingCode = nil
        pendingInviteToken = nil
    }

    /// Set what *I* call my partner. Triggers a UI refresh because
    /// `partner` is `@Published`.
    /// Called by onboarding flow's final CTA. The actual remote write is
    /// scheduled by the `onProfileMutated` hook (which fires because we just
    /// flipped `hasOnboarded` and that triggers a profile-shaped change too).
    /// `RemoteSync` will see this through the regular debounce path; it also
    /// exposes a `flushProfile` for callers that need to commit immediately.
    func completeOnboarding() {
        hasOnboarded = true
        regenerateTodayPlan()
        onCompleteOnboarding?()
    }

    /// Called when the user's session has been bootstrapped and we need to
    /// ensure the freshest local copy is up at Supabase regardless of
    /// debouncing. Used at app launch for cached changes that didn't get a
    /// chance to flush.
    var onCompleteOnboarding: (() -> Void)?

    /// Resolves the signed-in user's id, signing in if necessary. Set by the
    /// app at launch. `nil` until then.
    var resolveCurrentUserId: (() async -> UUID?)?

    /// Replace the local profile with the canonical server copy. Called by
    /// `RemoteSync.refreshAll()`. The mediator wraps this in
    /// `isApplyingRemote = true/false` to suppress the round-trip echo.
    ///
    /// Server is authoritative for every field on `UserProfile`. The only
    /// reason this isn't a straight `profile = remote` assignment is so we
    /// emit a single `didSet` (assigning a struct fires once, even if many
    /// fields change underneath).
    func applyRemoteProfile(_ remote: UserProfile, hasOnboarded: Bool) {
        profile = remote
        if self.hasOnboarded != hasOnboarded {
            self.hasOnboarded = hasOnboarded
        }
    }

    /// The current user's partnership row id. Set after pairing or when
    /// `RemoteSync.refreshPartner` finds an existing one. Needed so the
    /// relationship-label RPC has its `p_partnership_id` argument.
    @Published var partnershipId: UUID? {
        didSet { defaults.set(partnershipId?.uuidString, forKey: K.partnershipId) }
    }

    /// The partner's auth.users row id. Used by sessions/exercises rows
    /// (foreign keys) and to disambiguate "which side of the partnership
    /// am I on" when reading per-user labels.
    ///
    /// Mutating it also fires `onPartnerLinkChanged` so `RemoteSync` can
    /// (re)subscribe to / unsubscribe from the partner's `live_sessions`
    /// realtime channel without the UI having to know it exists.
    @Published var partnerUserId: UUID? {
        didSet {
            defaults.set(partnerUserId?.uuidString, forKey: K.partnerUserId)
            if oldValue != partnerUserId {
                onPartnerLinkChanged?(partnerUserId)
                if partnerUserId == nil { partnerActivity = nil }
            }
        }
    }

    /// Hook installed by `RemoteSync.attach`. Fires whenever the bound
    /// partner changes (paired/unpaired/swapped) so the realtime channel
    /// can be torn down and re-subscribed against the new id.
    var onPartnerLinkChanged: ((UUID?) -> Void)?

    /// Hook installed by `RemoteSync.attach`. Pushes the current "I'm in a
    /// session" state to `public.live_sessions`. Called from
    /// `ActiveSessionView` on every meaningful progression.
    var publishLiveSession: ((_ exerciseName: String?, _ currentSet: Int?, _ totalSets: Int?, _ progressPct: Int) async -> Void)?

    /// Hook installed by `RemoteSync.attach`. Tears down our
    /// `live_sessions` row when the active session ends or is abandoned.
    var clearLiveSession: (() async -> Void)?

    /// Apply (or clear) a freshly-arrived partner activity snapshot from
    /// the realtime channel. Idempotent — same row written twice doesn't
    /// trigger `objectWillChange` because of `Equatable`.
    func applyPartnerActivity(_ activity: PartnerActivity?) {
        if partnerActivity != activity {
            partnerActivity = activity
        }
    }

    /// Apply a server-side partner snapshot. Synthesizes the local
    /// `PartnerProfile` from the partner's `UserProfile` (which the server
    /// thinks of as just another `profiles` row).
    func applyRemotePartner(
        profile partnerProfile: UserProfile,
        partnerUserId: UUID,
        partnershipId: UUID,
        pairedSince: Date,
        relationshipLabel: RelationshipLabel?,
        relationshipCustom: String?
    ) {
        var p = partner
        p.name               = partnerProfile.name.isEmpty ? "Partner" : partnerProfile.name
        p.fitnessLevel       = partnerProfile.fitnessLevel
        p.focuses            = partnerProfile.focuses
        p.intensity          = partnerProfile.intensity
        p.equipment          = partnerProfile.equipment
        p.avoidedStyles      = partnerProfile.avoidedStyles
        p.relationshipLabel  = relationshipLabel
        p.relationshipCustom = relationshipCustom
        p.pairedSinceISO     = Self.dayLabel(pairedSince)
        p.online             = true   // realtime presence is wired in a later phase
        partner              = p
        self.partnerUserId   = partnerUserId
        self.partnershipId   = partnershipId
        self.isPaired        = true
        self.isSolo          = false
    }

    /// Drop local pairing state (server says we're no longer paired, e.g.
    /// the partner unpaired us).
    func applyUnpaired() {
        partner          = PartnerProfile()
        partnerUserId    = nil
        partnershipId    = nil
        isPaired         = false
        pendingCode      = nil
        pendingInviteToken = nil
    }

    /// Accept a pairing invite — by typed code OR deep-link token. Calls
    /// `accept_pair_invite` server-side; on success `RemoteSync` refreshes
    /// partner state which flips `isPaired = true`.
    ///
    /// Returns the error string if it fails, `nil` on success. Callers
    /// surface the error in the UI (toast, alert, error label).
    @discardableResult
    func acceptPartner(code: String? = nil, token: String? = nil) async -> String? {
        guard let accept = acceptRemoteInvite else {
            return "Pairing requires a network connection."
        }
        do {
            try await accept(code, token)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Sets the relationship label locally and asynchronously pushes to the
    /// server. The local update is immediate so the UI flips snappily; the
    /// remote push is best-effort.
    func setRelationshipLabel(_ label: RelationshipLabel?, custom: String? = nil) {
        partner.relationshipLabel = label
        partner.relationshipCustom = label == .other ? custom : nil
        if let label, let push = pushRelationshipLabel {
            Task { await push(label, custom) }
        }
    }

    /// Universal-link-shaped invite URL the user shares via Messages, etc.
    /// In production this points at `tempo.app` (with associated-domain
    /// fallback through `tempo://`); for local dev we just use the scheme
    /// directly so the simulator can intercept it without a Web server.
    var inviteURL: URL {
        let token = pendingInviteToken ?? pendingCode ?? "INVITE"
        let name  = profile.name.isEmpty ? "your friend" : profile.name
        var c = URLComponents()
        c.scheme = "tempo"
        c.host   = "pair"
        c.queryItems = [
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "from", value: name),
        ]
        return c.url ?? URL(string: "tempo://pair")!
    }

    /// Pre-written body for the share sheet. First-person, casual.
    func inviteMessage() -> String {
        let url = inviteURL.absoluteString
        if profile.name.isEmpty {
            return "I just started using Tempo to make my workouts a two-player game. Be my partner? \(url)"
        } else {
            return "Hey — \(profile.name) here. I'm using Tempo to keep my workouts on track and want a partner. Want in? \(url)"
        }
    }

    /// What I call the other person. Resolves to "partner" when nothing's set.
    var partnerNoun: String { partner.noun }

    func recordCompletedExercise(_ ex: CompletedExercise) {
        // No-op — accumulated in the active-session view model and saved on finish.
    }

    /// Hook installed by `RemoteSync.attach`. Pushes a freshly completed
    /// session up to Supabase. Best-effort: the local history list still
    /// updates immediately so the UI doesn't block on the network.
    var pushCompletedSession: ((CompletedSession) async -> Void)?

    func saveCompletedSession(_ s: CompletedSession) {
        // Local cache first — the Schedule + History views are bound to
        // `history` and need to update synchronously.
        history.insert(s, at: 0)
        if let push = pushCompletedSession {
            Task { await push(s) }
        }
    }

    /// Replace the local history list with the canonical server copy.
    /// Called by `RemoteSync.refreshAll`.
    func applyRemoteHistory(_ remote: [CompletedSession]) {
        history = remote
    }

    /// Looks up the user's best lift for an exercise (used for PR detection).
    func bestLift(catalogId: String) -> Int {
        var best = 0
        for session in history {
            for ex in session.you where ex.catalogId == catalogId {
                for set in ex.sets where !set.skipped {
                    if set.weight > best { best = set.weight }
                }
            }
        }
        return best
    }

    // MARK: persistence helpers

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func dayLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}

// MARK: - Toast

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var icon: String = "checkmark.circle.fill"
}

// MARK: - Partner activity (realtime)

/// Snapshot of "what the partner is doing right now". Populated by
/// `RemoteSync` from the `live_sessions` realtime channel. `nil` whenever
/// the partner doesn't have an active session.
///
/// Kept deliberately small: just enough to render a one-line presence
/// banner ("Alex · Goblet squat · 3/8 · 38%"). The full plan / per-set
/// detail lives in `sessions` once it's saved.
struct PartnerActivity: Equatable {
    let partnerUserId: UUID
    let startedAt: Date
    let progressPct: Int
    let currentExerciseName: String?
    let currentSet: Int?
    let totalSets: Int?
    let updatedAt: Date

    /// Compact "X / Y · ExerciseName" string for the presence banner.
    /// Falls back gracefully when the partner only published a percent.
    var compactStatus: String {
        var parts: [String] = []
        if let cur = currentSet, let total = totalSets, total > 0 {
            parts.append("\(cur)/\(total)")
        }
        if let name = currentExerciseName, !name.isEmpty {
            parts.append(name)
        }
        if parts.isEmpty {
            parts.append("\(progressPct)%")
        }
        return parts.joined(separator: " · ")
    }
}
