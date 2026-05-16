# Tempo — SwiftUI iOS implementation

A working SwiftUI port of the Tempo couples-fitness designs from `source_designs/`.

## Open in Xcode

```bash
open ios/Tempo.xcodeproj
```

Build target: iOS 17+. Run on any iPhone simulator.

## What's implemented

All eight design sections, with the four-tab shell wired up and full-screen flows
for the modal experiences (Active Session, Post-session, PR moment, Onboarding).

| Section            | Status | Notes |
| ------------------ | :----: | ----- |
| Today (3 states)   | ✅     | Ready · In progress · Rest day. Demo state-picker at the top lets you flip between them. |
| Active Session     | ✅     | Strength composition. Tap **Log Set** to advance sets; final set triggers the PR moment. Tap the **Plan** dock action to surface the bottom-sheet plan view. |
| History            | ✅     | Quick stat card, filter pills, week-grouped session rows with PR pill + chevron. |
| Progress           | ✅     | KPI card, weekly volume bars, est. 1RM line chart with partner overlay, top lifts list, body-part coverage heatmap. |
| Profile            | ✅     | Header, partner card with unpair affordance, goals/preferences/advanced/account sections. Unpair sheet with destructive type-to-confirm. |
| Post-session       | ✅     | "Done · in tempo" hero, streak update, KPIs, per-exercise side-by-side comparison, reactions row. |
| PR moment          | ✅     | Full-takeover gold burst with spring-in animation. |
| Onboarding (7 scr) | ✅     | Welcome · Sign in · Photo · About you · Pair choice · Pending code · We're ready. Form state isn't persisted; flow is navigable. |
| Goals (4 scr)      | ⏳     | Not in this pass — the brief explicitly mentions "Adjust-set sheet, demo-video overlay, in-session chat" + "stubbed Goals" as scope-deferred items. Stubs are reachable from Profile → Goals rows. |

## Demo routes

To reach screens that aren't on the natural path (PR moment, post-session, full
onboarding from the running app), the Today screen has a small **Demo routes**
section at the bottom — buttons to open each one. Remove that section from
`TodayView.swift` before any production build.

## Architecture

```
Tempo/
├── TempoApp.swift          # @main entry, injects SessionStore
├── RootView.swift          # 4-tab shell + fullScreenCover routes
├── Theme/
│   └── Theme.swift         # Design tokens (colors, type scale, radii, card modifier)
├── Models/
│   └── Models.swift        # SessionPlan, ExercisePlan, HistoryEntry, SessionStore
├── Components/
│   ├── Avatar.swift        # Avatar (you/partner/neutral/accent) + PartnerPip
│   ├── Buttons.swift       # PrimaryCTA, SecondaryCTA, IconButton, LinkButton
│   ├── Progress.swift      # ProgressStrip + DualProgress
│   └── Chrome.swift        # TopBar, SectionHead, KPI
└── Features/
    ├── Today/              # 3-state Today screen
    ├── ActiveSession/      # Strength composition + bottom plan sheet
    ├── History/            # Filterable session list
    ├── Progress/           # Charts + heatmap (renders ProgressView)
    ├── Profile/            # Settings + unpair sheet
    ├── PostSession/        # Comparison + PR moment
    └── Onboarding/         # 7-screen flow
```

## Design system notes

- **Colors:** ported from `tokens.css` OKLCH values to sRGB approximations.
  See `Theme.Color` — every token from the brief has a Swift counterpart.
- **Type:** Geist + Geist Mono aren't bundled, so the implementation falls back
  to SF Pro / SF Mono. To match the design exactly, add Geist `.ttf` files
  to the app bundle and register them in `Info.plist` under
  `UIAppFonts`, then update `Theme.Font` to reference them.
- **Numerics:** every figure uses `monospacedDigit()` and tabular numerals,
  matching the brief's "Tabular numerals everywhere" rule.
- **Tab bar:** uses `.ultraThinMaterial` for the iOS blurred chrome.
- **Accent rule honored:** the green is only used on primary CTAs, the "done"
  state of set chips, the in-tempo dot, and the heatmap fill. Partner blue/amber
  are ambient context only. PR gold is reserved for celebration.

## Data layer (stubbed)

`SessionStore` is an `@StateObject` published into the environment. It carries
the partner record, the today plan, and a few live-session values used by the
Active Session view. There's no networking, persistence, or AI integration —
the brief's V1 realtime layer is the next thing to wire up.

## Testing the Supabase backend locally

The project includes a full Supabase stack you can run in Docker. This is the
fastest, safest way to verify schema changes before pushing to your cloud
project, and it's the same backend your local Xcode build talks to.

### One-time setup

```bash
# Make sure Docker Desktop is running, then:
cd /Users/luisalvarez/dev/src/tempo
export SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=dummy_local_unused  # any string
supabase start
```

That brings up Postgres + GoTrue + PostgREST + Realtime + Studio at
`http://127.0.0.1:54321` and applies every migration in `supabase/migrations/`.

You can browse the DB at `http://127.0.0.1:54323` (Supabase Studio).

### Verifying it actually works end-to-end

```bash
scripts/smoke-supabase.sh
```

This signs up a fake user, exercises the `handle_new_user` trigger, updates
the profile (mimicking onboarding), and asserts RLS hides other users' rows.
Run it after any schema change.

### Pointing the iOS app at it

`ios/Tempo/Supabase/SupabaseConfig.swift` is gitignored. The committed default
in this checkout already points at the local stack:

```swift
static let url     = URL(string: "http://127.0.0.1:54321")!
static let anonKey = "<the local anon JWT>"
```

The iOS Simulator can reach `127.0.0.1` directly. If you run on a physical
device on the same Wi-Fi, replace `127.0.0.1` with your Mac's LAN IP.

### Running against cloud Supabase instead

```bash
export SUPA_URL=https://YOUR_REF.supabase.co
export SUPA_ANON=eyJhbGciOi…   # anon public key, not service_role
scripts/smoke-supabase.sh
```

The same script verifies your cloud project before TestFlight.

### Stopping the local stack

```bash
supabase stop            # preserves DB volume
supabase stop --no-backup # nuke everything, fresh start next time
```

## CI

Two GitHub Actions workflows in `.github/workflows/`:

| Workflow              | Trigger paths                       | What it does |
| --------------------- | ----------------------------------- | ------------ |
| `supabase-smoke.yml`  | `supabase/**`, scripts, the workflow | Boots local Supabase in CI, runs `smoke-supabase.sh`. Fails on any schema/RLS regression. ~2 min. |
| `ios-build.yml`       | `ios/**`, the workflow              | Compiles the app for the iOS Simulator with Xcode 16. Catches missing files in `project.pbxproj`, Swift errors, broken SPM deps. ~10 min. |

Neither runs unit/UI tests yet — the Xcode project doesn't have a test target.
That's a sensible next step.

## Known TODOs / next steps

1. **Real fonts.** Bundle Geist + Geist Mono `.ttf` files and switch
   `Theme.Font.sans` / `.mono` to use the registered names.
2. **Goals questionnaire (4 screens).** Build out matching the `goals.jsx`
   designs — answer cards grid, frequency slider, intensity rows, styles chips.
3. **Adjust-set sheet, in-session chat, demo-video overlay** — referenced in
   the brief but not designed in v1; stub during the design pass.
4. **Realtime layer.** The brief is explicit that partner presence must be
   wired up early. Mock with a Combine publisher on `SessionStore`, then swap
   for the real subscription.
5. **Persistence + AI plan generation** — out of scope for the UI port.
