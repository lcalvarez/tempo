# Tempo — TestFlight release plan

State of the app, what's wired, what's blocking a TestFlight push, and the
exact steps to get a build into reviewers' hands. Written so a future-you
or a co-founder can run it without re-reading every chat thread.

> **Last verified:** local Supabase + simulator app, all 9 smoke scripts green
> against `iPhone 17 Pro` simulator on Xcode 16, May 2026.
>
> Manual walkthrough checklist: see `WALKTHROUGH.md`. Run before every
> cloud config flip and every TestFlight upload.

---

## 1. What's actually built

The app is a working SwiftUI client backed by a live Supabase project. Not
a prototype — every screen reads/writes real rows.

### Backend (Supabase, `supabase/migrations/`)

| Concern              | Where                                | Status |
| -------------------- | ------------------------------------ | :----: |
| Auth (anon + email)  | `auth.users` + `handle_new_user` trigger | ✅ |
| Profile              | `public.profiles` (incl. `appearance`, `custom_stretch_areas`, `custom_exercises` jsonb) | ✅ |
| Pairing              | `public.partnerships` + `pair_invites` + RPCs (`create_pair_invite`, `accept_pair_invite`, `set_relationship_label`) | ✅ |
| Partner view         | `public.my_partner` (RLS-gated) | ✅ |
| Sessions / exercises / sets | `public.sessions` + `exercises` + `sets` (3-table batch insert) | ✅ |
| Realtime             | `public.live_sessions` (added to `supabase_realtime` publication) + `public.partnerships` | ✅ |
| RLS                  | Every table — own + partner read where applicable, own write only | ✅ |
| Edge Functions       | `generate-plan` (Anthropic Sonnet 4.5, JWT-auth, per-user/day rate limit via `plan_generation_log`); `delete-user` (privileged self-delete) | ✅ |

### iOS client (`ios/Tempo/`)

| Concern                | Where                          | Status |
| ---------------------- | ------------------------------ | :----: |
| 4-tab shell (Today/Schedule/Progress/Profile) | `RootView.swift`              | ✅ |
| Today (3 states)       | `Features/Today/TodayView.swift` | ✅ — partner-live banner now driven by realtime |
| Active session         | `Features/ActiveSession/ActiveSessionView.swift` | ✅ — strength + bodyweight + stretching |
| Onboarding (7 screens) | `Features/Onboarding/OnboardingFlow.swift` | ✅ |
| Goals questionnaire    | `Features/Goals/GoalsFlow.swift` | ✅ |
| Schedule (timeline)    | `Features/History/HistoryView.swift` | ✅ |
| Progress (charts)      | `Features/Progress/ProgressView.swift` | ✅ |
| Profile                | `Features/Profile/ProfileView.swift` | ✅ |
| Pair partner (SMS / deep link) | `Features/Pairing/InvitePartnerScreen.swift` | ✅ |
| Email/password sign-in | `Features/Auth/SignInScreen.swift` (`SignInSheet`) | ✅ — 3 explicit modes (save / sign in / switch) |
| Sync + realtime        | `Supabase/RemoteSync.swift` | ✅ |
| AI planner (tiered)    | `AI/PlannerService.swift` (Foundation Models → Anthropic → heuristic), once-per-day cache via `PlannedDayCache` | ✅ |

### Test coverage (`scripts/smoke-*.sh`)

All run against a booted simulator + local Supabase, exit non-zero on regression.
Nine total — each covers one round-trip:

```
scripts/smoke-supabase.sh                  Auth + profile RLS via curl (no simulator)
scripts/smoke-pairing.sh                   create_pair_invite + accept_pair_invite via curl
scripts/smoke-pairing-with-app.sh          End-to-end pairing through the running app
scripts/smoke-sessions-with-app.sh         saveCompletedSession round-trip
scripts/smoke-custom-exercise-with-app.sh  Custom exercises persist to profiles.custom_exercises
scripts/smoke-signin-with-app.sh           Anonymous → email/password upgrade preserves auth.uid()
scripts/smoke-live-with-app.sh             Realtime partner activity (insert + delete) lands in app
scripts/smoke-unpair-with-app.sh           Unpair flow deletes partnership row + tears down realtime
scripts/smoke-unpair-cross-device.sh       Partner-side DELETE flips running app to solo (no relaunch)
```

CI: `.github/workflows/supabase-smoke.yml` runs the curl-only smokes on every
push. The simulator-driven ones are local because GitHub's Linux runners
can't boot iOS sims; you can move them to a macOS runner later if you want.

---

## 2. Hard blockers before TestFlight

Three things will fail a real install. Fix all three before archiving.

### 2.1 `SupabaseConfig.swift` must point at cloud, not localhost

This file is gitignored. The committed placeholder
`ios/Tempo/Supabase/SupabaseConfig.swift` is a 2-field stub pointing at
`http://127.0.0.1:54321`. **A TestFlight build with that file would 100% fail
on a tester's phone** — their device can't reach your Mac's localhost, and
ATS will reject the unencrypted HTTP anyway.

The fix is to re-run the bootstrap with cloud enabled, which writes a
`#if DEBUG / #else` switch:

```bash
./scripts/bootstrap-supabase.sh
# choose option 2 (cloud only) or 3 (both)
# follow the prompt to link to your `tempo` cloud project
```

Result: `SupabaseConfig.swift` ends up shaped like

```swift
enum SupabaseConfig {
    static var url: URL {
        #if DEBUG
        return useLocal ? localURL : cloudURL
        #else
        return cloudURL
        #endif
    }
    // … same for anonKey
    private static let useLocal: Bool = true   // dev default — flip if you want
    private static let localURL  = URL(string: "http://127.0.0.1:54321")!
    private static let cloudURL  = URL(string: "https://<ref>.supabase.co")!
    private static let cloudAnonKey = "<your cloud anon JWT>"
}
```

Release builds always pick `cloudURL` regardless of `useLocal`.

> **Verify before archiving:** `git status` should show `SupabaseConfig.swift`
> as untracked (gitignored). Open it and confirm the `cloudURL` is your real
> project, not `https://example.supabase.co`.

### 2.2 Demo-only UI gated to DEBUG

Already done in this pass — the "Demo routes" row on Today (PR moment /
Post-session / Replay onboarding) and the `Ready / In progress / Rest day`
state picker are now both `#if DEBUG`. A Release archive won't show them.
Confirm with:

```bash
xcodebuild -project ios/Tempo.xcodeproj -scheme Tempo -configuration Release \
  -destination 'generic/platform=iOS Simulator' clean build | grep -E 'error|warning'
```

You should not see any `Demo routes` strings in the resulting `Tempo.app`.

### 2.3 Sign in with Apple is stubbed

The onboarding `SignInScreen` (the private one in `OnboardingFlow.swift`)
shows the Apple button but doesn't yet call `auth.signInWithApple(...)` —
the wire-up exists in `AuthStore.swift` but nothing in the onboarding flow
invokes it. For TestFlight v1 we ship with the **anonymous + email/password**
path only:

- **Reviewers don't need an account.** Anon sign-in works on first launch.
- **The `SignInSheet` in Profile** lets them upgrade to email/password to
  preserve their data across reinstalls.

This is fine for the first internal TestFlight. Sign in with Apple can ship
in v1.1 once you've configured the Apple Developer console for it (entitlement
+ Services ID + redirect URL). It is **not** an App Store requirement until
you offer other 3rd-party login providers (you don't, yet).

---

## 3. Nice-to-haves before TestFlight (not blockers)

Pre-flight polish that's worth a few hours but won't reject your build.

- **Tagline / display copy.** Bundle display name is `Tempo`. Subtitle on
  TestFlight + App Store Connect: something like *"Couples fitness — train
  in tempo with your partner."* Length: 30 chars.
- **Privacy nutrition labels.** App Store Connect will ask. Truthful answers
  for v1: collects email (auth), workout data linked to user (sessions),
  partner info (pairing). No tracking, no analytics SDK, no third-party
  data sharing. Takes ~15 minutes the first time.
- **Crash reporting.** Not wired. Add Sentry or even just MetricKit before
  external testing. One file, ~30 lines.
- **App icon all sizes.** You only have `AppIcon-1024.png` (the new dotless
  rings). Xcode auto-derives smaller sizes from it for Asset Catalog
  compilation, so this works, but if you want pixel-perfect smaller icons
  you'll need to export 80px / 120px / 180px from the source.
- **Launch screen.** `Info.plist`'s `UILaunchScreen` now references the
  `LaunchBackground` named color (matches `Theme.Color.bg` in light/dark)
  so users see a single bg-colored frame instead of a white flash. Adding
  a centered logo image is a v1.1 polish item.

---

## 4. The actual TestFlight steps

Sequenced in the order you'd do them on a clean machine.

### 4.1 Apple Developer + App Store Connect

1. **Apple Developer account.** $99/year. You probably already have this; if
   not, [enroll](https://developer.apple.com/programs/enroll/) — it can take
   24-48h on first creation.
2. **Bundle ID.** Currently `com.tempo.app`. Register it once at
   [identifiers](https://developer.apple.com/account/resources/identifiers/list):
   - Type: App ID
   - Description: Tempo
   - Bundle ID (Explicit): `com.tempo.app`
   - Capabilities: **Sign in with Apple** (even if not wired yet — easier
     to enable now than later).
3. **App in App Store Connect.** [Create one](https://appstoreconnect.apple.com/apps):
   - Platform: iOS
   - Name: Tempo
   - Primary language: English (U.S.)
   - Bundle ID: `com.tempo.app` (the one you just registered)
   - SKU: `tempo-ios-001` (any string; internal)
   - User Access: Full Access

### 4.2 Project signing

1. Open `ios/Tempo.xcodeproj` in Xcode.
2. Click the **Tempo** target → **Signing & Capabilities** tab.
3. Set **Team** to your Apple Developer team. Leave **Automatically manage
   signing** on. Bundle ID should already read `com.tempo.app`.
4. **Add the "Sign in with Apple" capability** (`+ Capability` → Sign in
   with Apple). Even though we're not calling it yet, it's required to
   match the App ID config.

### 4.3 Cloud Supabase project

1. Make sure your cloud project's schema is current with the local one:
   ```bash
   ./scripts/db-push.sh        # supabase db push --linked
   ```
2. Verify against the cloud project (this script reads `SUPA_URL` /
   `SUPA_ANON` from env if set):
   ```bash
   export SUPA_URL=https://<ref>.supabase.co
   export SUPA_ANON=<cloud anon JWT>
   scripts/smoke-supabase.sh
   ```
   Should pass clean.
3. **Auth → URL Configuration** in the Supabase dashboard:
   - **Site URL:** `tempo://` (so password-recovery / email-confirm links open
     the app, even though we don't trigger those flows in v1).
   - **Redirect URLs:** add `tempo://*` if you ever wire Apple OAuth.
4. **Auth → Providers → Email**: turn on email/password (default), keep
   "Confirm email" off for v1 (or leave it on and accept that signups
   need the email confirmation step — GoTrue will send via your project's
   default email; for TestFlight, off is friendlier).

### 4.4 Archive + upload

1. In Xcode: **Product → Destination → Any iOS Device (arm64)**. Not the
   simulator — TestFlight needs a device-targeted archive.
2. **Product → Archive**. Coffee break — first archive is ~5 minutes.
3. The Organizer window pops open with your archive. **Distribute App** →
   **App Store Connect** → **Upload**. Defaults are fine (auto-manage
   signing, include symbols, manage version & build number).
4. Wait for the green check. Apple will then run automated checks for ~5-15
   minutes (you'll get an email when it's "ready to test").
5. In App Store Connect → **TestFlight** tab on your app:
   - The new build appears with status "Missing Compliance" — click it,
     answer the encryption questions (uses HTTPS only = "Yes, but exempt
     under Category 5 Part 2").
   - Add yourself + your wife as **Internal Testers** (no Apple review
     needed, instant).
   - Optional: create an **External Testers** group for friends. This goes
     through a one-time Beta App Review (24-48h), then they install via
     a public link.

### 4.5 First-run smoke test on device

Before you tell anyone the build is live:

1. Install on your own iPhone via TestFlight.
2. Onboard from scratch (you'll be a fresh anon user).
3. Profile → "Save your account" → enter a real email + password. Confirm
   the toast.
4. From a different device (or sim), sign in to that account → confirm
   profile + history sync down.
5. Pair with your wife via the SMS share sheet. Both phones confirm
   "Andrea is your partner" / similar.
6. Have one of you start a session. The other's Today screen should show
   the live banner ("Andrea training now · Goblet squat · 3/8 · 38%")
   updating in near-real-time.

If any of those break, **don't promote the build to external testers yet.**
Re-run the matching local smoke (`scripts/smoke-*.sh`) to triage.

---

## 5. After it's live

### Telemetry

You're flying blind right now — no analytics, no crash reports. Two cheap
adds:

1. **Sentry** — drop-in for crashes + Swift errors. ~10 lines in `TempoApp`.
2. **`OSLog` + Console.app on your dev Mac** when a tester reports an issue
   — they can stream logs from their iPhone over USB.

### Updating the schema after launch

```bash
supabase migration new short_name
# edit the generated file
./scripts/db-push.sh
# bump the iOS Info.plist if you also shipped client changes
```

The migrations are forward-only by design. RLS policies live in the same
files and get re-applied via `drop policy if exists` so you can update
them safely.

### Versioning

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj`
(currently `1.0` / `1`). Convention used here:

- **Build number** (`CURRENT_PROJECT_VERSION`) bumps on every TestFlight
  upload, even for the same `1.0`.
- **Marketing version** bumps when something user-visible changes.

Apple will reject a build with a duplicate `(version, build)` pair within
the same release train.

---

## 6. Tracked TODOs that are *not* blockers

Captured from the various `// TODO:` comments + smoke-test gaps that exist
today. None are TestFlight-blocking — the build runs without them — but
they're the next pieces of work after v1 is out.

- Wire Sign in with Apple in `OnboardingFlow.SignInScreen` (the credentials
  flow already exists in `AuthStore.signInWithApple`). The button was
  removed from onboarding for v1; "Continue with email" + "Continue as
  guest" are the two functional paths.
- AI planner is now tiered (Apple Foundation Models → Anthropic Sonnet 4.5
  via `generate-plan` Edge Function → heuristic fallback). Set
  `ANTHROPIC_API_KEY` (and optionally `ANTHROPIC_MODEL`) on the cloud
  project before TestFlight, otherwise tier 2 returns 502 and every
  device falls through to the heuristic. See `supabase/README.md`.
- Profile-photo storage. Onboarding now writes the JPEG to
  `UserProfile.avatarData` locally. v1.1 should add a Supabase Storage
  bucket + `profiles.avatar_url` column and upload on edit.
- Bundle Geist / Geist Mono fonts; `Theme.Font` falls back to SF.
- Move simulator-driven smoke scripts to a macOS GitHub Actions runner
  job alongside `ios-build.yml`.

---

## 7. One-line summary

> The app, the schema, and the test scripts are real and green. The only
> hard blocker for TestFlight is `SupabaseConfig.swift` pointing at your
> cloud project instead of `localhost` — re-run `./scripts/bootstrap-supabase.sh`
> with the cloud option, then archive and upload.
