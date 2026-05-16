import Foundation
import Supabase

/// "Raw SQL with a nice client library." Five-ish helpers that round-trip the
/// app's `Codable` models through Supabase. Each one corresponds to one or two
/// Postgres tables — no ORM, no codegen.
///
/// All functions are `async throws` and intentionally do nothing about
/// optimistic UI / caching. The caller (`SessionStore`) is responsible for
/// updating local state and then awaiting the network call in a `Task`.
enum SyncStore {

    // MARK: - Profile

    /// Save the current user's profile row.
    ///
    /// The `handle_new_user` trigger guarantees a profile row already exists
    /// for any authenticated user, so we UPDATE rather than INSERT/UPSERT.
    /// `userId` must match `auth.uid()` (otherwise RLS blocks the write).
    ///
    /// We send a `[String: AnyJSON]`-shaped patch so we can omit `updated_at`
    /// (the server-side trigger sets it; including a null would violate the
    /// not-null check). Wrapping in a typed encoder + manual exclusion would
    /// be more verbose for the same effect.
    static func saveProfile(_ profile: UserProfile, userId: UUID, hasOnboarded: Bool) async throws {
        let row = ProfileRow(id: userId, profile: profile, hasOnboarded: hasOnboarded)
        try await TempoSupabase.client
            .from("profiles")
            .update(row, returning: .minimal)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Fetch the current user's profile row. Returns `nil` if the row doesn't
    /// exist yet (e.g. brand-new auth user before the trigger fires).
    static func fetchProfile(userId: UUID) async throws -> (UserProfile, hasOnboarded: Bool)? {
        let rows: [ProfileRow] = try await TempoSupabase.client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return (row.toProfile(), row.hasOnboarded)
    }

    /// Fetch the paired partner's profile, if any. Backed by the `my_partner`
    /// view (read-only, gated by partnerships + RLS).
    static func fetchPartner() async throws -> (UserProfile, id: UUID)? {
        let rows: [ProfileRow] = try await TempoSupabase.client
            .from("my_partner")
            .select()
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return (row.toProfile(), row.id)
    }

    /// Fetch the current user's partnership row, if any. Used to derive the
    /// `partnership_id` we pass to `set_relationship_label`, and to read what
    /// each side has chosen as the relationship label.
    static func fetchPartnership() async throws -> PartnershipRow? {
        let rows: [PartnershipRow] = try await TempoSupabase.client
            .from("partnerships")
            .select()
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Sessions

    /// Save a completed session + its exercises + sets. Three inserts; if
    /// any fails the partial state is left for the next sync to reconcile.
    /// (For v1, that's fine — we re-fetch history on launch.)
    static func saveCompletedSession(_ session: CompletedSession, userId: UUID, partnerId: UUID?) async throws {
        let sessionRow = SessionRow(
            id: session.id,
            userId: userId,
            partnerId: partnerId,
            title: session.title,
            startedAt: session.date,
            durationSeconds: session.durationSeconds
        )
        try await TempoSupabase.client.from("sessions").insert(sessionRow).execute()

        // Build flat exercise + set arrays so we can do two batch inserts.
        var exerciseRows: [ExerciseRow] = []
        var setRows: [SetRow] = []
        for (idx, ex) in session.you.enumerated() {
            let exRow = ExerciseRow(
                id: ex.id,
                sessionId: session.id,
                catalogId: ex.catalogId,
                name: ex.name,
                isPr: ex.isPR,
                orderIndex: idx
            )
            exerciseRows.append(exRow)
            for (setIdx, set) in ex.sets.enumerated() {
                setRows.append(SetRow(
                    id: set.id,
                    exerciseId: ex.id,
                    setIndex: setIdx,
                    reps: set.reps,
                    weight: set.weight,
                    skipped: set.skipped
                ))
            }
        }
        if !exerciseRows.isEmpty {
            try await TempoSupabase.client.from("exercises").insert(exerciseRows).execute()
        }
        if !setRows.isEmpty {
            try await TempoSupabase.client.from("sets").insert(setRows).execute()
        }
    }

    /// Fetch the user's history (own + partner's, via RLS). Returns most-recent
    /// first. Joins exercises + sets in two follow-up queries (PostgREST
    /// embedded selects keep this to one round-trip if you prefer; this is
    /// the simpler version for debugging).
    static func fetchHistory(userId: UUID, limit: Int = 50) async throws -> [CompletedSession] {
        let sessionRows: [SessionRow] = try await TempoSupabase.client
            .from("sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        guard !sessionRows.isEmpty else { return [] }

        let sessionIds = sessionRows.map { $0.id.uuidString }
        let exerciseRows: [ExerciseRow] = try await TempoSupabase.client
            .from("exercises")
            .select()
            .in("session_id", values: sessionIds)
            .order("order_index", ascending: true)
            .execute()
            .value
        let exerciseIds = exerciseRows.map { $0.id.uuidString }
        let setRows: [SetRow] = exerciseIds.isEmpty ? [] : try await TempoSupabase.client
            .from("sets")
            .select()
            .in("exercise_id", values: exerciseIds)
            .order("set_index", ascending: true)
            .execute()
            .value

        let setsByExercise = Dictionary(grouping: setRows, by: \.exerciseId)
        let exercisesBySession = Dictionary(grouping: exerciseRows, by: \.sessionId)

        return sessionRows.map { s in
            let exercises: [CompletedExercise] = (exercisesBySession[s.id] ?? []).map { e in
                CompletedExercise(
                    id: e.id,
                    catalogId: e.catalogId,
                    name: e.name,
                    sets: (setsByExercise[e.id] ?? []).map {
                        CompletedSet(id: $0.id, reps: $0.reps, weight: $0.weight, skipped: $0.skipped)
                    },
                    isPR: e.isPr
                )
            }
            return CompletedSession(
                id: s.id,
                title: s.title,
                date: s.startedAt,
                durationSeconds: s.durationSeconds,
                you: exercises,
                partner: []
            )
        }
    }

    // MARK: - Pairing

    /// Server-side: rotates expired invites, generates a fresh 6-char code +
    /// 24-byte token, returns the row. RPC defined in the initial migration.
    static func createPairInvite() async throws -> PairInviteRow {
        try await TempoSupabase.client
            .rpc("create_pair_invite")
            .single()
            .execute()
            .value
    }

    /// Set what *I* call the other side of the partnership. Server-side
    /// enforces that I can only edit my own column.
    static func setRelationshipLabel(
        partnershipId: UUID,
        label: RelationshipLabel,
        custom: String? = nil
    ) async throws -> PartnershipRow {
        struct Params: Encodable {
            let p_partnership_id: UUID
            let p_label: String
            let p_label_custom: String?
        }
        return try await TempoSupabase.client
            .rpc("set_relationship_label",
                 params: Params(
                    p_partnership_id: partnershipId,
                    p_label: label.rawValue,
                    p_label_custom: label == .other ? custom : nil
                 ))
            .single()
            .execute()
            .value
    }

    /// Accept an invite by either user-typed `code` or deep-link `token`.
    /// The RPC enforces canonical ordering and idempotency on `partnerships`.
    static func acceptPairInvite(code: String? = nil, token: String? = nil) async throws -> PartnershipRow {
        struct Params: Encodable {
            let p_code: String?
            let p_token: String?
        }
        return try await TempoSupabase.client
            .rpc("accept_pair_invite", params: Params(p_code: code, p_token: token))
            .single()
            .execute()
            .value
    }

    // MARK: - Live session (realtime writer)

    /// Upsert one row representing "I'm working out right now". The
    /// `live_sessions` table has a primary key on `user_id` so this is safe to
    /// call on every set tick.
    static func writeLiveSession(_ row: LiveSessionRow) async throws {
        try await TempoSupabase.client
            .from("live_sessions")
            .upsert(row, returning: .minimal)
            .execute()
    }

    /// Tear down the realtime row when the session ends or is abandoned.
    static func clearLiveSession(userId: UUID) async throws {
        try await TempoSupabase.client
            .from("live_sessions")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}
