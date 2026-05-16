import Foundation
import SwiftUI
import Combine
import OSLog
import Supabase
import Realtime

/// Bridges `SessionStore` (the SwiftUI model) and `SyncStore` (the typed
/// Supabase calls). Owns the policies the model layer should not have to
/// know about: when to debounce writes, how to refresh on launch, what to
/// do when the network is offline.
///
/// Architecture: backend (Postgres via Supabase) is the source of truth.
/// `UserDefaults` inside `SessionStore` is a local write-through cache so
/// the UI paints instantly on cold launch with last-known values; on every
/// launch we asynchronously pull from the cloud and replace the cached
/// copy. Last-write-wins on conflict (server `updated_at` is the tiebreaker
/// in v1; CRDT-style merges are out of scope).
///
/// Lives as a `@MainActor` class so it can directly mutate the `@Published`
/// properties on `SessionStore` after a fetch.
@MainActor
final class RemoteSync: ObservableObject {

    // MARK: - Wiring

    private weak var session: SessionStore?
    private let auth: AuthStore

    /// Debounce window for profile writes. Onboarding edits bursts of
    /// `@Published` mutations (one per field); we coalesce them into a
    /// single PATCH instead of hammering Supabase.
    private let profileDebounce: TimeInterval = 0.6
    private var profileDebounceTask: Task<Void, Never>?

    // MARK: - Live session (realtime) state

    /// Coalesces bursts of `publishLive` calls. We don't need set-by-set
    /// fidelity over the wire; once-per-second is plenty for a partner
    /// banner that the human eye reads.
    private let liveDebounce: TimeInterval = 0.8
    private var liveDebounceTask: Task<Void, Never>?

    /// Snapshot of the most recent `publishLive` call. Held so the
    /// debounce task and the explicit `flushLive()` call can both write
    /// the freshest values without re-plumbing them through arguments.
    private struct LivePublishSnapshot {
        var exerciseName: String?
        var currentSet: Int?
        var totalSets: Int?
        var progressPct: Int
    }
    private var liveLastSnapshot: LivePublishSnapshot?
    private var liveStartedAt: Date?

    /// Realtime channel + reader task for the *partner's* live row. Bound
    /// in `rebindPartnerSubscription` whenever `partnerUserId` changes;
    /// torn down on sign-out / unpair.
    private var liveChannel: RealtimeChannelV2?
    private var liveStreamTask: Task<Void, Never>?
    private var liveSubscriptionUserId: UUID?

    // MARK: - Partnership-watch (realtime) state
    //
    // Separate channel from `live_sessions` because `partnerships`
    // changes on a different cadence and we want them gated by RLS,
    // not by a per-partner-id filter (the row's primary key is
    // `id`, not the user's id, so a static filter wouldn't match).
    // RLS already restricts the rows each subscriber sees, so we let
    // the database do the filtering and just react to whatever lands.

    /// Realtime channel + reader task for `public.partnerships`. Bound
    /// in `rebindPartnershipWatch` once we know the user is signed in;
    /// torn down on sign-out.
    private var partnershipChannel: RealtimeChannelV2?
    private var partnershipStreamTask: Task<Void, Never>?
    /// `auth.uid()` the channel is bound to. Used to detect re-binds
    /// (sign-out → sign-in as somebody else) so we don't keep an old
    /// user's subscription open.
    private var partnershipSubscriptionUserId: UUID?

    /// `true` while `refreshAll()` is overwriting `session.profile` from
    /// the server, so the caller can suspend `markProfileDirty()` calls
    /// that would otherwise echo the same row back.
    @Published private(set) var isApplyingRemote = false

    /// Last successful profile push (UTC). Surfaced in Profile/debug.
    @Published private(set) var lastProfilePushAt: Date?

    /// Last error string from any sync operation. Cleared when the next
    /// op succeeds.
    @Published var lastError: String?

    init(auth: AuthStore) {
        self.auth = auth
    }

    /// Called once at app launch from `TempoApp`. Captures a weak reference
    /// to the session store and installs the auth/sync hooks on it.
    func attach(session: SessionStore) {
        self.session = session
        session.resolveCurrentUserId = { [auth] in
            await auth.ensureSignedIn()
            return auth.currentUserId
        }
        session.onProfileMutated = { [weak self] in
            self?.markProfileDirty(reason: "edit")
        }
        session.onCompleteOnboarding = { [weak self] in
            Task { await self?.flushProfile(reason: "onboarding-complete") }
        }
        session.requestRemoteInvite = { [weak self] in
            await self?.requestPairInvite()
        }
        session.acceptRemoteInvite = { [weak self] code, token in
            try await self?.acceptPairInvite(code: code, token: token)
        }
        session.pushRelationshipLabel = { [weak self] label, custom in
            guard let self, let pid = session.partnershipId else { return }
            await self.pushRelationshipLabel(partnershipId: pid, label: label, custom: custom)
        }
        session.requestUnpair = { [weak self] in
            await self?.unpair()
        }
        session.pushCompletedSession = { [weak self] completed in
            await self?.pushCompletedSession(completed)
        }
        // Live (realtime) session hooks: outbound publish/clear, plus an
        // observer that flips the partner-side subscription whenever
        // pairing changes.
        session.publishLiveSession = { [weak self] exerciseName, currentSet, totalSets, progressPct in
            await self?.publishLive(
                exerciseName: exerciseName,
                currentSet: currentSet,
                totalSets: totalSets,
                progressPct: progressPct
            )
        }
        session.clearLiveSession = { [weak self] in
            await self?.clearLive()
        }
        session.onPartnerLinkChanged = { [weak self] partnerId in
            Task { await self?.rebindPartnerSubscription(to: partnerId) }
        }
        // First-bind: if launch already restored a partner, kick off the
        // realtime subscription right away. Subsequent changes go via
        // `onPartnerLinkChanged` above.
        if let pid = session.partnerUserId {
            Task { [weak self] in await self?.rebindPartnerSubscription(to: pid) }
        }
    }

    /// Push a freshly completed session up to Supabase. Captures the
    /// session and any partner id, and writes through `SyncStore`.
    /// Errors are surfaced via `lastError` and a toast — the local history
    /// list is the source of truth for the UI until the refresh-on-launch
    /// pulls down the server copy.
    private func pushCompletedSession(_ s: CompletedSession) async {
        guard let session else { return }
        if auth.currentUserId == nil {
            await auth.ensureSignedIn()
        }
        guard let userId = auth.currentUserId else {
            log("pushCompletedSession skipped — no auth.uid()")
            return
        }
        let partnerId = session.partnerUserId
        let snapshot = s
        do {
            try await SyncStore.saveCompletedSession(snapshot, userId: userId, partnerId: partnerId)
            log("✓ saved session \(snapshot.id) to Supabase")
        } catch {
            log("✗ pushCompletedSession failed: \(error)")
            lastError = "Couldn't sync session: \(error.localizedDescription)"
            session.showToast("Session saved locally — couldn't sync", icon: "exclamationmark.icloud")
        }
    }

    /// Generates a pair invite via the server and stamps it on `SessionStore`
    /// so the UI can display it. Errors are logged + surfaced via `lastError`
    /// so the view layer can show a toast.
    private func requestPairInvite() async {
        do {
            let invite = try await createPairInvite()
            // Stamp the session synchronously: hooks run on the main actor.
            session?.pendingCode = invite.code
            session?.pendingInviteToken = invite.token
        } catch {
            log("✗ requestPairInvite failed: \(error)")
            lastError = "Couldn't create invite: \(error.localizedDescription)"
        }
    }

    // MARK: - Bootstrap

    /// Run on launch (and when the user signs in/out). Ensures we have an
    /// auth session, then pulls everything we treat as canonical: profile,
    /// partner (if any), partnership label, and history.
    func refreshAll() async {
        await auth.ensureSignedIn()
        guard let userId = auth.currentUserId else {
            log("refreshAll skipped — no auth.uid()")
            return
        }
        await refreshProfile(userId: userId)
        await refreshPartner(userId: userId)
        await refreshHistory(userId: userId)
        // Subscribe to partnership-watch as soon as we're sure the
        // session is valid. Idempotent: re-running `refreshAll` (e.g.
        // after a sign-out → sign-in) re-binds against the new uid.
        await rebindPartnershipWatch(to: userId)
    }

    private func refreshHistory(userId: UUID) async {
        do {
            let sessions = try await SyncStore.fetchHistory(userId: userId)
            isApplyingRemote = true
            session?.applyRemoteHistory(sessions)
            isApplyingRemote = false
            log("✓ refreshed \(sessions.count) sessions from server")
        } catch {
            isApplyingRemote = false
            log("✗ refreshHistory failed: \(error)")
            lastError = "Couldn't load history: \(error.localizedDescription)"
        }
    }

    private func refreshProfile(userId: UUID) async {
        do {
            guard let (remote, hasOnboarded) = try await SyncStore.fetchProfile(userId: userId) else {
                log("refreshProfile: no row for \(userId) yet")
                return
            }
            isApplyingRemote = true
            session?.applyRemoteProfile(remote, hasOnboarded: hasOnboarded)
            isApplyingRemote = false
            log("✓ refreshed profile from server for \(userId)")
            lastError = nil
        } catch {
            isApplyingRemote = false
            log("✗ refreshProfile failed: \(error)")
            lastError = "Couldn't load profile: \(error.localizedDescription)"
        }
    }

    private func refreshPartner(userId: UUID) async {
        do {
            // First check if there's a partnership at all.
            guard let partnership = try await SyncStore.fetchPartnership() else {
                // No partnership: clear local pairing state so the user lands
                // on the unpaired view if a partner removed them.
                if let session, session.isPaired {
                    isApplyingRemote = true
                    session.applyUnpaired()
                    isApplyingRemote = false
                    log("✓ no partnership server-side; cleared local paired state")
                } else {
                    log("· refreshPartner: no partnership for \(userId)")
                }
                return
            }
            // Then load the partner profile and resolve "what do I call them?"
            guard let (partnerProfile, partnerId) = try await SyncStore.fetchPartner() else {
                log("refreshPartner: partnership exists but my_partner view returned nothing")
                return
            }
            let myUserId = userId
            let (label, custom) = partnership.myLabel(for: myUserId)
            isApplyingRemote = true
            session?.applyRemotePartner(
                profile: partnerProfile,
                partnerUserId: partnerId,
                partnershipId: partnership.id,
                pairedSince: partnership.pairedSince,
                relationshipLabel: label,
                relationshipCustom: custom
            )
            isApplyingRemote = false
            log("✓ refreshed partner (\(partnerId)) and partnership (\(partnership.id))")
        } catch {
            isApplyingRemote = false
            log("✗ refreshPartner failed: \(error)")
            lastError = "Couldn't load partner: \(error.localizedDescription)"
        }
    }

    // MARK: - Pairing

    /// Ask the server for a fresh invite. Returns the code (for typing) and
    /// token (for deep-link sharing). Throws on auth/network failure so the
    /// UI can fall back / show an error toast.
    func createPairInvite() async throws -> (code: String, token: String) {
        if auth.currentUserId == nil {
            await auth.ensureSignedIn()
        }
        guard auth.currentUserId != nil else {
            throw NSError(domain: "RemoteSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let row = try await SyncStore.createPairInvite()
        log("✓ created pair invite \(row.code)")
        return (row.code, row.token)
    }

    /// Accept either a typed code or a deep-link token. Refreshes partner
    /// state on success so the UI flips to paired.
    func acceptPairInvite(code: String?, token: String?) async throws {
        if auth.currentUserId == nil {
            await auth.ensureSignedIn()
        }
        guard let userId = auth.currentUserId else {
            throw NSError(domain: "RemoteSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        _ = try await SyncStore.acceptPairInvite(code: code, token: token)
        log("✓ accepted pair invite — refreshing partner state")
        await refreshPartner(userId: userId)
    }

    /// Tear down the current user's partnership end-to-end:
    ///
    ///   1. Stop publishing our own `live_sessions` row (the partner
    ///      shouldn't see "still training" after we cut the link).
    ///   2. DELETE the `partnerships` row via `SyncStore`. Either user
    ///      can do this — RLS allows both `user_a` and `user_b`.
    ///   3. Apply the unpaired state locally so the UI flips
    ///      synchronously (don't wait for the next `refreshPartner`).
    ///      Setting `partnerUserId = nil` triggers
    ///      `onPartnerLinkChanged`, which tears down the realtime
    ///      live-session subscription via
    ///      `rebindPartnerSubscription(to: nil)`.
    ///
    /// The *other* side picks up the change instantly via the
    /// `partnership-watch` realtime channel (see
    /// `rebindPartnershipWatch`). The DELETE event lands on their
    /// device, `handlePartnershipDelete` sees the deleted row id matches
    /// their cached `partnershipId`, and `applyUnpaired()` runs — same
    /// path the local side runs synchronously. No relaunch required on
    /// either device.
    @discardableResult
    func unpair() async -> String? {
        guard let session, let partnershipId = session.partnershipId else {
            return "Not paired."
        }
        if auth.currentUserId == nil {
            await auth.ensureSignedIn()
        }
        guard auth.currentUserId != nil else {
            return "Not signed in."
        }
        // Best-effort: clear our live row first so the partner stops
        // seeing us "training" the moment we hit confirm. If this
        // fails we still proceed with the delete — better to be
        // unpaired-with-stale-live-row than paired-but-silent.
        await clearLive()
        do {
            try await SyncStore.deletePartnership(id: partnershipId)
            log("✓ deleted partnership \(partnershipId)")
        } catch {
            log("✗ deletePartnership failed: \(error)")
            lastError = "Couldn't unpair: \(error.localizedDescription)"
            return error.localizedDescription
        }
        // Local apply *after* the server delete succeeded. This flips
        // `isPaired` and clears the partner banner; the
        // `onPartnerLinkChanged` hook closes the realtime channel.
        isApplyingRemote = true
        session.applyUnpaired()
        isApplyingRemote = false
        lastError = nil
        return nil
    }

    /// Push a new relationship label to the server. Called from `RootView`
    /// and `ProfileView` after the picker sheet returns.
    func pushRelationshipLabel(
        partnershipId: UUID,
        label: RelationshipLabel,
        custom: String?
    ) async {
        do {
            _ = try await SyncStore.setRelationshipLabel(
                partnershipId: partnershipId, label: label, custom: custom
            )
            log("✓ relationship label set to \(label.rawValue)")
        } catch {
            log("✗ relationship label push failed: \(error)")
            lastError = "Couldn't save relationship label: \(error.localizedDescription)"
        }
    }

    // MARK: - Profile write-through

    /// Schedule a debounced profile push. Safe to call from any `didSet`.
    /// The model layer doesn't need to know how often the user is typing —
    /// we collapse a burst of mutations into one PATCH.
    func markProfileDirty(reason: String = "edit") {
        // Don't push back what we just pulled from the server.
        if isApplyingRemote { return }
        profileDebounceTask?.cancel()
        profileDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.profileDebounce ?? 0.6) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            // Run the actual push *outside* the debounce Task so that future
            // calls to `markProfileDirty` (which cancel `profileDebounceTask`)
            // don't cancel the in-flight network call. Detached avoids
            // inheriting the parent task's cancellation.
            await self.performProfilePush(reason: reason)
        }
    }

    /// Skip the debounce and push immediately. Used at moments where we
    /// must commit before the next thing happens (e.g. completing
    /// onboarding before showing Today).
    func flushProfile(reason: String) async {
        profileDebounceTask?.cancel()
        await performProfilePush(reason: reason)
    }

    /// Actually performs the PATCH. Resilient to caller-task cancellation:
    /// the caller may be the debounce task that just got cancelled, and we
    /// don't want to inherit that.
    private func performProfilePush(reason: String) async {
        guard let session else { return }
        if auth.currentUserId == nil {
            await auth.ensureSignedIn()
        }
        guard let userId = auth.currentUserId else {
            log("push skipped (\(reason)) — no auth.uid()")
            return
        }
        let profileSnapshot = session.profile
        let onboardedSnapshot = session.hasOnboarded
        // Detach so cancellation of the debounce task doesn't kill the
        // in-flight URLSession request. The Task's @Sendable closure means
        // we capture value snapshots rather than the @Published references.
        let result: Result<Void, Error> = await Task.detached {
            do {
                try await SyncStore.saveProfile(profileSnapshot, userId: userId, hasOnboarded: onboardedSnapshot)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
        switch result {
        case .success:
            lastProfilePushAt = Date()
            lastError = nil
            log("✓ pushed profile (\(reason)) for \(userId)")
        case .failure(let error):
            log("✗ push (\(reason)) failed: \(error)")
            lastError = "Couldn't save profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Live session (realtime) — outbound

    /// Upsert a `live_sessions` row representing the current workout.
    /// Safe to call on every set; we coalesce bursts via a debounce task
    /// so the channel doesn't get hammered.
    func publishLive(
        exerciseName: String?,
        currentSet: Int?,
        totalSets: Int?,
        progressPct: Int
    ) async {
        liveLastSnapshot = LivePublishSnapshot(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            progressPct: max(0, min(100, progressPct))
        )
        liveDebounceTask?.cancel()
        liveDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.liveDebounce ?? 0.8) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            await self.flushLive()
        }
    }

    /// Push the most recent snapshot up to Supabase right now, bypassing
    /// the debounce. Used at session-end so the final visible state
    /// reflects the completion before we tear it down.
    func flushLive() async {
        guard let snap = liveLastSnapshot else { return }
        if auth.currentUserId == nil { await auth.ensureSignedIn() }
        guard let userId = auth.currentUserId else {
            log("publishLive skipped — no auth.uid()")
            return
        }
        if liveStartedAt == nil { liveStartedAt = Date() }
        let row = LiveSessionRow(
            userId: userId,
            partnerId: session?.partnerUserId,
            startedAt: liveStartedAt ?? Date(),
            progressPct: snap.progressPct,
            currentExerciseName: snap.exerciseName,
            currentSet: snap.currentSet,
            totalSets: snap.totalSets,
            updatedAt: nil
        )
        let result: Result<Void, Error> = await Task.detached {
            do {
                try await SyncStore.writeLiveSession(row)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
        switch result {
        case .success:
            log("✓ live published (\(snap.progressPct)% · \(snap.exerciseName ?? "—"))")
        case .failure(let err):
            log("✗ live publish failed: \(err)")
        }
    }

    /// Delete our `live_sessions` row. Called from
    /// `ActiveSessionView.onDisappear` and `finishSession`.
    func clearLive() async {
        liveDebounceTask?.cancel()
        liveDebounceTask = nil
        liveLastSnapshot = nil
        liveStartedAt = nil
        if auth.currentUserId == nil { await auth.ensureSignedIn() }
        guard let userId = auth.currentUserId else { return }
        do {
            try await SyncStore.clearLiveSession(userId: userId)
            log("✓ live cleared")
        } catch {
            log("✗ live clear failed: \(error)")
        }
    }

    // MARK: - Live session (realtime) — inbound

    /// (Re)bind the realtime subscription to the given partner id. Passing
    /// `nil` tears down any active subscription and clears the local
    /// activity. Safe to call repeatedly — idempotent on identical ids.
    func rebindPartnerSubscription(to partnerId: UUID?) async {
        if liveSubscriptionUserId == partnerId { return }
        await tearDownLiveSubscription()
        guard let partnerId else {
            session?.applyPartnerActivity(nil)
            return
        }
        liveSubscriptionUserId = partnerId
        let channel = TempoSupabase.client.realtimeV2.channel("live:\(partnerId.uuidString)")
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "live_sessions",
            filter: "user_id=eq.\(partnerId.uuidString.lowercased())"
        )
        do {
            try await channel.subscribeWithError()
            log("✓ live subscribe(\(partnerId))")
        } catch {
            log("✗ live subscribe(\(partnerId)) failed: \(error)")
            liveSubscriptionUserId = nil
            return
        }
        liveChannel = channel

        // Pull the current snapshot right after subscribing so the UI
        // reflects an already-active partner session immediately, without
        // waiting for the next change to fire.
        await fetchPartnerLiveOnce(partnerId: partnerId)

        liveStreamTask = Task { [weak self] in
            for await action in stream {
                await self?.handleLiveAction(action, partnerId: partnerId)
            }
        }
    }

    private func fetchPartnerLiveOnce(partnerId: UUID) async {
        do {
            let rows: [LiveSessionRow] = try await TempoSupabase.client
                .from("live_sessions")
                .select()
                .eq("user_id", value: partnerId.uuidString)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                applyLiveRow(row, partnerId: partnerId)
            } else {
                session?.applyPartnerActivity(nil)
            }
        } catch {
            log("· live fetch-on-bind failed: \(error)")
        }
    }

    private func handleLiveAction(_ action: AnyAction, partnerId: UUID) async {
        switch action {
        case .insert(let a):
            if let row = decodeLiveRow(a.record) { applyLiveRow(row, partnerId: partnerId) }
        case .update(let a):
            if let row = decodeLiveRow(a.record) { applyLiveRow(row, partnerId: partnerId) }
        case .delete:
            session?.applyPartnerActivity(nil)
            log("· live delete from \(partnerId) — partner finished")
        }
    }

    private func applyLiveRow(_ row: LiveSessionRow, partnerId: UUID) {
        // Defensive: the channel filter already guarantees this, but a
        // mis-routed envelope would otherwise leak somebody else's
        // activity onto the banner.
        guard row.userId == partnerId else { return }
        let activity = PartnerActivity(
            partnerUserId: partnerId,
            startedAt: row.startedAt,
            progressPct: row.progressPct,
            currentExerciseName: row.currentExerciseName,
            currentSet: row.currentSet,
            totalSets: row.totalSets,
            updatedAt: row.updatedAt ?? Date()
        )
        session?.applyPartnerActivity(activity)
        log("· live partner update: \(activity.compactStatus) (\(activity.progressPct)%)")
    }

    private func tearDownLiveSubscription() async {
        liveStreamTask?.cancel()
        liveStreamTask = nil
        if let ch = liveChannel { await ch.unsubscribe() }
        liveChannel = nil
        liveSubscriptionUserId = nil
    }

    // MARK: - Partnership-watch (realtime)

    /// (Re)bind the realtime subscription that watches the user's own
    /// partnership row(s). Called from `refreshAll` once `auth.uid()` is
    /// known; the channel relies on RLS to scope what we receive (each
    /// user only sees rows where they're `user_a` or `user_b`). Passing
    /// `nil` tears the channel down — used on sign-out.
    ///
    /// We use a single un-filtered channel rather than a `user_a=eq.<me>`
    /// filter because the realtime API only supports one filter per
    /// channel, and a partnership row could put us in either column.
    /// Letting RLS do the work is both simpler and more secure.
    func rebindPartnershipWatch(to userId: UUID?) async {
        if partnershipSubscriptionUserId == userId { return }
        await tearDownPartnershipSubscription()
        guard let userId else { return }
        partnershipSubscriptionUserId = userId

        let channel = TempoSupabase.client.realtimeV2.channel("partnerships:\(userId.uuidString)")
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "partnerships"
        )
        do {
            try await channel.subscribeWithError()
            log("✓ partnership-watch subscribe(\(userId))")
        } catch {
            log("✗ partnership-watch subscribe(\(userId)) failed: \(error)")
            partnershipSubscriptionUserId = nil
            return
        }
        partnershipChannel = channel

        partnershipStreamTask = Task { [weak self] in
            for await action in stream {
                await self?.handlePartnershipAction(action, ownerUserId: userId)
            }
        }
    }

    /// React to inserts/updates/deletes on the `partnerships` table that
    /// landed on our channel (RLS-pre-filtered). The events we care
    /// about most:
    ///
    ///   • **DELETE** of our current partnership → flip to solo state
    ///     immediately. This is the cross-device unpair signal.
    ///   • **INSERT** referencing us → schedule a partner refresh so the
    ///     UI fills in the freshly-paired partner without a relaunch.
    ///     Useful when the *other* side accepts our invite.
    ///   • **UPDATE** (e.g. relationship label change) → refresh partner.
    ///
    /// We tolerate "DELETE without payload" gracefully: when REPLICA
    /// IDENTITY isn't FULL the old record only carries the primary key,
    /// so we match on `id` against the locally cached `partnershipId`.
    private func handlePartnershipAction(_ action: AnyAction, ownerUserId: UUID) async {
        switch action {
        case .delete(let a):
            handlePartnershipDelete(record: a.oldRecord, ownerUserId: ownerUserId)
        case .insert(let a):
            handlePartnershipInsertOrUpdate(record: a.record, ownerUserId: ownerUserId, kind: "insert")
        case .update(let a):
            handlePartnershipInsertOrUpdate(record: a.record, ownerUserId: ownerUserId, kind: "update")
        }
    }

    private func handlePartnershipDelete(record: [String: AnyJSON], ownerUserId: UUID) {
        // Pull the deleted row's id. With REPLICA IDENTITY FULL we also
        // get user_a / user_b, but `id` alone is enough: if it matches
        // the partnership we know about locally, it was ours.
        let deletedId: UUID? = (record["id"]?.stringValue).flatMap(UUID.init(uuidString:))
        guard let deletedId else {
            log("· partnership-watch delete: no id in payload, ignoring")
            return
        }
        let mine = session?.partnershipId
        guard deletedId == mine else {
            // Not our partnership row (shouldn't happen post-RLS but
            // belt-and-suspenders).
            log("· partnership-watch delete: \(deletedId) isn't ours (\(mine?.uuidString ?? "nil"))")
            return
        }
        log("· partnership-watch delete: \(deletedId) — flipping to solo")
        // Tearing down our own live row would be polite to a partner who
        // unpaired us — they shouldn't see ghost activity afterwards.
        Task { await self.clearLive() }
        isApplyingRemote = true
        session?.applyUnpaired()
        isApplyingRemote = false
        session?.showToast("Unpaired", icon: "link.badge.plus")
    }

    private func handlePartnershipInsertOrUpdate(record: [String: AnyJSON], ownerUserId: UUID, kind: String) {
        // Only refresh if the row references us. Realtime + RLS should
        // already guarantee that, but be defensive.
        let userA = (record["user_a"]?.stringValue).flatMap(UUID.init(uuidString:))
        let userB = (record["user_b"]?.stringValue).flatMap(UUID.init(uuidString:))
        guard userA == ownerUserId || userB == ownerUserId else { return }
        log("· partnership-watch \(kind): refreshing partner")
        Task { await self.refreshPartner(userId: ownerUserId) }
    }

    private func tearDownPartnershipSubscription() async {
        partnershipStreamTask?.cancel()
        partnershipStreamTask = nil
        if let ch = partnershipChannel { await ch.unsubscribe() }
        partnershipChannel = nil
        partnershipSubscriptionUserId = nil
    }

    /// Realtime payloads arrive as `[String: AnyJSON]`. We re-encode
    /// through `TempoSupabase.jsonEncoder` (the same snake_case-aware one
    /// PostgREST uses) and decode through a forgiving decoder that
    /// accepts realtime's "no-timezone with microseconds" timestamp form.
    private func decodeLiveRow(_ record: [String: AnyJSON]) -> LiveSessionRow? {
        do {
            let data = try TempoSupabase.jsonEncoder.encode(record)
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            dec.dateDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                let s = try c.decode(String.self)
                if let d = Self.flexibleDate(from: s) { return d }
                throw DecodingError.dataCorruptedError(in: c,
                    debugDescription: "Unrecognized realtime date: \(s)")
            }
            return try dec.decode(LiveSessionRow.self, from: data)
        } catch {
            log("· live decode failed: \(error)")
            return nil
        }
    }

    private static func flexibleDate(from s: String) -> Date? {
        let f1 = ISO8601DateFormatter(); f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: s) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.tempo.app", category: "RemoteSync")

    private func log(_ msg: String) {
        Self.logger.info("\(msg, privacy: .public)")
        #if DEBUG
        print("[RemoteSync] \(msg)")
        Self.appendDebugLog(msg)
        #endif
    }

    #if DEBUG
    /// Mirrors every `log()` call into `~/Documents/remote-sync.log` inside
    /// the app sandbox. The simulator's stdout/console is unreliable
    /// (Xcode console captures it but command-line `log show` doesn't), so
    /// having a flat file in the sandbox makes ground-truth easy to inspect:
    ///
    ///     UDID=$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)
    ///     cat "$(xcrun simctl get_app_container "$UDID" com.tempo.app data)/Documents/remote-sync.log"
    private static func appendDebugLog(_ msg: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("remote-sync.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    #endif
}
