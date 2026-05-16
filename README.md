# Handoff: Tempo — couples fitness iOS app (v1)

## Overview

**Tempo** is an iOS app for couples who want to work out together. Both partners sign up, connect, complete a goals questionnaire, and an AI generates personalized but time-synchronized workouts — different exercises tailored to each person, on a shared timeline so they finish together. During a live session, each partner sees the other's real-time progress. After, a side-by-side comparison shows what each did, with PRs flagged and a permanent progress history.

V1 is **synchronous-only** — both partners live in the same session at the same time.

The first user is the founder and his wife (Luis + Andrea in the mocks).

## About the design files

The files in `source_designs/` are **design references created in HTML** — high-fidelity prototypes showing intended look and behavior, not production code to copy directly. The task is to **recreate these HTML designs in the target codebase's environment** (SwiftUI for native iOS, or React Native if cross-platform is desired) using its established patterns and libraries.

`source_designs/Today screen.html` is the entry point — open it in a browser to see all 22 artboards on a pan/zoom canvas, grouped into 8 sections. Click any artboard to focus it fullscreen.

The non-design support files (`ios-frame.jsx`, `design-canvas.jsx`, `tweaks-panel.jsx`) are scaffolding for presenting the designs and can be ignored during implementation.

## Fidelity

**High-fidelity.** Pixel-perfect mockups with final colors, typography, spacing, and interactions. The developer should recreate the UI pixel-perfectly using the target platform's primitives.

The visual system is locked. Two things are not:
- **Brand mark** — current logo is two interlocking circles (muted blue + muted amber). Functional placeholder; replace with final mark when designed.
- **Tweakable accent + partner palette** — the Tweaks panel in the prototype shows the design works under multiple accent colors (green / lime / electric / coral / magenta) and partner palettes (blue-amber / teal-rose / indigo-peach / mono). **Default is green accent + blue-amber partners** — ship that.

## App structure

**Four tabs** at the root:
1. **Today** (default) — front door
2. **History** — every completed session
3. **Progress** — power-user tab (charts, PRs, body-part coverage)
4. **Profile** — settings, partner connection, goals

No social feed, no discover, no challenges. Tab bar visible everywhere except inside an active session (full-screen immersion) and inside flows like onboarding / goals.

## Screens

### 1. Onboarding (7 screens)
Sequential flow with progress dots (16×3px hairlines, top-left). Each screen has its own scroll, footer holds the primary CTA + skip link.

1. **Welcome** — brand mark, "Train together. / In tempo." headline (44px, weight 600), dual-progress bars as decorative motif, value-prop copy, "Get started" CTA, "I already have an account" link.
2. **Sign in** — Apple Sign In primary (filled white, 56px), "or" divider, "Continue with email" ghost. Terms / Privacy links below.
3. **Photo (optional)** — 168px dashed circular target, "Take selfie" + "Choose from library" buttons, 6 colored-monogram alternatives, **prominent "Skip — I'll add a photo later"** below the Continue CTA.
4. **About you** — single scrollable screen: Name input · Age + Units segmented · Fitness level segmented (New/Some/Strong/Advanced) · Equipment chips · Usual workout times chips · Injuries textarea.
5. **Pair up** — two large tappable cards: "Send your partner an invite" (marked Recommended in accent green border) and "Enter their code". "Pair later" footer link.
6. **Pending invite** — 6-char code in monospace digit cells (e.g. `AX7 — K9P`), pulsing accent ring on partner avatar placeholder, Copy + Share buttons, "Expires in 24 hours" caption.
7. **We're ready** — paired avatars (You blue + Partner amber) connected by an accent-green link with dot endpoints, "You and Andrea are ready" headline, mini stat row (2 profiles · 0 sessions · ∞ together), "Set your goals" CTA.

### 2. Goals questionnaire (4 screens)
Edits to goals re-trigger AI planning. Same scaffold as onboarding but with a back arrow + "Skip" link in topbar.

1. **Primary focus** — 6 answer cards in a 2-col grid (Strength · Hypertrophy · Endurance · Weight loss · Mobility · General). Multi-select, up to 2.
2. **Frequency** — slider with big numeric display ("4 days per week", 56px), 7-cell week visualization showing predicted training days highlighted in accent green.
3. **Intensity** — 4 full-width answer rows (Easy / Moderate / Hard / Brutal) with title + subtitle.
4. **Styles** — three chip groups: ❤️ You like (green) · 🚫 Skip (red) · Everything else (default). Tap once for like, again for skip. CTA: "Generate first plan".

### 3. Today (3 states)
Front door. Routes to one of three states based on session state.

- **A · Session ready** — hero card with "Today's session" overline, big headline "Lower body & core", duration + ex count, "Both ready" indicator (two small avatars in partner colors), big "Start Session" primary CTA. Below: Today's plan preview (2-column side-by-side, You + Andrea), streak card (23 days, flame icon in PR gold), last-together card.
- **B · Session in progress** — auto-routed when partner started first. Live card with pulsing accent dot, "Andrea set the tempo." headline (with "the tempo." in accent green), dual progress bars (You 0% · Andrea 22%), "Join Session" CTA, your-first-up card with demo placeholder, "Skip warm-up · jump in cold" secondary.
- **C · Rest day** — "Rest day. Recover well." headline, streak meta line, "This week, together" KPI card (3 sessions · 2h 18m · 3 PRs), Recent activity list with You/Andrea color-coded left-borders, "Plan an extra session" secondary CTA.

Top bar (all states): "Today · Tue · May 14" left, partner pip with status dot right. Status dot in accent green when online, faint when off.

### 4. Active session (3 compositions)
The heart of the app. No tab bar — full immersion. Bottom is reserved for the LOG action.

- **A · Strength · between sets** — topbar with X-exit · elapsed time · ex count · partner pip. Dual progress strip (You / Andrea, both colored). Rest timer card (label · progress bar · time, large). Current exercise label. **Hero numbers** ("6 × 195" at 96px, mono tabular). Set chips strip (done = accent-dim with checkmark, current = ringed, upcoming = muted). Bottom dock: partner-strip (Andrea · current exercise · chat pip with unread amber dot) → tall green "Log Set 3 · 6 × 195" CTA → small dock-actions row: `Adjust · Skip set · End session` (End in muted red).
- **B · Cardio · live distance** — same chrome. Hero replaced by 104px distance counter (1.84 mi). 3 sub-KPIs (elapsed / pace per mi / bpm). Pace track strip. Dock actions: `Pause · Skip exercise · End session`.
- **C · Plan sheet** — bottom sheet (78% height) over the strength view dimmed/blurred at 35%. Three-column rows: # · You · Andrea, each cell showing status dot (done filled in partner color, current ringed, upcoming hairline circle) + exercise name + meta. Top row shows palette legend.

### 5. Post-session (2 screens)
Unlocked when both partners hit Complete.

- **A · Comparison** — "Done · in tempo" overline in accent green, 64px duration ("45:08"), session name. Streak update card with PR-gold flame, "24-day streak", "+1" callout. KPI row. Per-exercise comparison rows: header bar with exercise name + ★ PR badge (gold), then You / Andrea columns side-by-side with sets-by-set breakdown. React row with emoji bubbles + "Type a note…" pill. "Done" green CTA at the bottom.
- **B · PR moment** — full-takeover celebration mid-session. Warm gold radial glow background. 120px circular gold burst with "PR" glyph at center. "Personal record" overline. Exercise name large. Hero numbers (6 × 200) in standard treatment. "Previous best · 6 × 195 · Mar 18" subline. "Log it" green CTA. "Failed — adjust" link.

### 6. History (1 screen)
- Quick stat card (Sessions all time · Together time)
- Horizontal filter pill row (All / ★ PR only / Strength / Cardio / This month)
- Week-grouped session rows: 48px square date (day large, month mono small) · session name + meta · PR pill + chevron right
- Tab bar with History active

### 7. Progress (2 screens)
- **A · Overview** — top range selector (1W / 1M / 3M / 1Y) inline with title. This-month KPI card. **Volume bars chart** (weekly, last bar in accent). **Est. 1RM line chart** with Andrea's line overlaid in muted amber. Top lifts list with delta indicators (+5 lb in accent green if up). 6-week body-part coverage **heatmap** (7×6 grid, 5 levels of accent opacity per cell).
- **B · Per-exercise detail (Back squat)** — back-arrow topbar. Hero "238 lb" (80px) with "▲ 14 lb in 6 weeks" delta. Range row (1M / 3M / 6M / 1Y / All). Two charts (1RM with partner overlay, volume bars). Frequency card. Recent sets table with PR pills.

### 8. Profile + settings (2 screens)
- **A · Profile (main)** — profile header (56px avatar in You-blue), Partner card section (large) with Andrea avatar + name + "In tempo since Mar 28 · online", stat row (sessions / together time / joint PRs), prominent muted-red **"Unpair from Andrea"** button. Goals section · Preferences (units, rest default, reminder toggles, partner activity toggle, chat toggle) · Advanced (RPE toggle, plate calc, CSV export) · Account (Sign out, Delete account in red).
- **B · Unpair confirmation** — sheet over dimmed profile. Sheet handle, broken pair-link visualization (avatars connected by red line with ✕), "Unpair from Andrea?" headline, calm bulleted list (✓ history kept · ✗ Andrea notified · ✗ next session cancelled), "Type ANDREA to confirm" field, solid red "Unpair" button (disabled until confirmed), "Cancel" link below.

## Design tokens

### Type
- **UI font:** `Geist` (Google Fonts, weights 400/500/600/700)
- **Mono font:** `Geist Mono` (Google Fonts, weights 400/500/600) — used for ALL labels, metrics, numbers, timestamps. Tabular numerals (`font-variant-numeric: tabular-nums`) everywhere.
- Type scale used: 10–11px mono labels (uppercase, 0.08–0.18em letter-spacing) · 12–14px body · 17–22px subhead · 28–44px display · 64–104px hero numerics. Letter-spacing tightens with size (-0.015 to -0.04em).

### Colors (OKLCH-based)

| Token | Value | Use |
|---|---|---|
| `--bg` | `oklch(0.16 0.006 260)` | Canvas |
| `--bg-elev-1` | `oklch(0.20 0.008 260)` | Card |
| `--bg-elev-2` | `oklch(0.25 0.010 260)` | Nested card / chip |
| `--bg-elev-3` | `oklch(0.30 0.012 260)` | Divider strong |
| `--border` | `oklch(0.32 0.012 260 / 0.6)` | Card border |
| `--hairline` | `oklch(1 0 0 / 0.06)` | Subtle separator |
| `--fg` | `oklch(0.97 0.003 260)` | Primary text |
| `--fg-mute` | `oklch(0.74 0.008 260)` | Secondary text |
| `--fg-soft` | `oklch(0.55 0.010 260)` | Labels |
| `--fg-faint` | `oklch(0.40 0.012 260)` | Captions, ticks |
| `--accent` | `oklch(0.84 0.19 142)` | Primary action only (Start / Log / Complete / Join / Finish). Never decorative. |
| `--accent-ink` | `oklch(0.18 0.06 145)` | Text on accent |
| `--accent-dim` | `oklch(0.84 0.19 142 / 0.14)` | Accent fill subtle |
| `--you` | `oklch(0.78 0.09 230)` | "You" partner color (muted blue) |
| `--you-dim` | `oklch(0.78 0.09 230 / 0.16)` | You fill subtle |
| `--partner` | `oklch(0.82 0.09 78)` | Partner color (muted amber) |
| `--partner-dim` | `oklch(0.82 0.09 78 / 0.16)` | Partner fill subtle |
| `--pr` | `oklch(0.86 0.16 95)` | PR / celebration (warm gold). Reserved for PR moments only. |
| Destructive | `oklch(0.55 0.20 25)` / `oklch(0.74 0.12 25)` | End session / Unpair / Delete |

**Color rules:**
- Accent green appears ONLY on primary actions and the "done" state of set chips. Never as decoration.
- Partner tones are always lower contrast than accent — they read as ambient context.
- PR gold has its own register so accent green can keep "primary action" semantic.

### Radii
- `--r-xs: 6px` · `--r-sm: 10px` · `--r-md: 14px` · `--r-lg: 20px` · `--r-xl: 28px`
- Pills: `999px`
- Device frame corner: 48px (iOS)

### Spacing
8px-based, deviates where typographically required. Card padding 16–24px. Section gap 16–22px.

### Shadows
Minimal. Primary CTA has a subtle inner highlight + outer accent shadow:
```css
0 1px 0 oklch(1 0 0 / 0.25) inset,
0 -1px 0 oklch(0 0 0 / 0.15) inset,
0 8px 20px oklch(0.84 0.19 142 / 0.25)
```

## Interactions & behavior

### Navigation
- **Onboarding & Goals:** linear, swipeable, with back + skip in topbar. Each screen has a single CTA in the footer.
- **Tabs:** standard iOS tabbar at bottom of Today / History / Progress / Profile. Hidden inside Active Session and inside flows.
- **Active session:** topbar X = "End session" with confirmation. Swipe up reveals the Plan sheet. Tap exercise name = demo + form notes overlay (not designed in v1). Tap partner area = chat overlay (not designed in v1).

### Logging interaction
- Primary "Log Set" CTA defaults to **"same as last set"** — one tap if nothing changed
- Tapping "Adjust" opens a sheet with steppers/wheels (not designed in v1 — defer)
- "Skip set" appends a skipped marker and advances rest timer
- "End session" prompts confirmation

### Animations
- **PR unlock** — small celebration burst (~600ms). Gold radial glow fades in, "PR" medallion scales up from 0.8 with a slight bounce.
- **Set log** — satisfying tick (haptic + scale pulse on the set chip turning accent-dim).
- **Live progress bars** — animate width continuously as data updates.
- **Pulse on partner avatar** (pending invite) — 1.8s ease-in-out infinite.
- Otherwise calm: 200ms ease on hovers, 320ms ease-out on sheet transitions.

### State management
- **Session state:** `idle | planned | live | paused | complete | comparing`
- **Partner state:** subscribed via realtime — `name | avatarUrl | online | currentExerciseId | currentSetIndex | progressPct`
- **Exercise state per partner per session:** `[{exerciseId, sets: [{reps, weight, completed, skipped, rpe?, notes?}]}]`
- **Goals re-edit** triggers AI planning request → regenerates upcoming sessions

### Data model essentials
Every exercise in the catalog has a **type** that determines logging UI:
- `strength` — sets × reps × weight
- `bodyweight` — sets × reps, weight optional
- `timed_hold` — duration per set
- `distance` — distance + duration + optional pace
- `time_based` — duration + optional reps
- `mobility` — completion + optional duration

Exercise catalog is **static and seeded** — ~50–80 named exercises with consistent IDs. AI references this catalog when generating plans.

## Out of scope for v1
- Social features beyond your one partner
- Solo and async sessions
- Challenges / leaderboards
- Pre-built workout programs (AI generates everything)
- Video calls during sessions (chat is enough)
- HealthKit / wearables integration
- Nutrition tracking
- Group workouts

## Assets
- **Fonts:** Geist + Geist Mono via Google Fonts (free, open-source)
- **Icons:** custom inline SVG line-icons drawn in the prototype — see `source_designs/*.jsx` for each glyph. 1.6–1.8 stroke weight, rounded caps/joins. Consistent line weight across the set.
- **Brand mark:** placeholder — two interlocking circles in `--you` and `--partner` colors. Replace with final mark.
- **Exercise demos:** brief specifies short looping videos or clean line illustrations, NOT stock photos. Prototype shows a striped placeholder where the video would sit.

## Files in this handoff

```
source_designs/
├── Today screen.html        — entry point, open in browser to see all 22 artboards
├── tokens.css               — all design tokens (colors, type, primitives)
├── today.jsx                — Today screen 3 states
├── active.jsx               — Active session 3 compositions
├── onboarding.jsx           — Onboarding 7 screens (incl. optional photo)
├── goals.jsx                — Goals questionnaire 4 screens
├── post.jsx                 — Post-session comparison + PR moment
├── history.jsx              — History tab
├── progress.jsx             — Progress tab (overview + detail)
├── profile.jsx              — Profile/settings + unpair flow
├── ios-frame.jsx            — iPhone bezel scaffold (ignore)
├── design-canvas.jsx        — pan/zoom presentation scaffold (ignore)
└── tweaks-panel.jsx         — accent/palette tweak demo (ignore)
```

## Recommended next steps for the implementer

1. **Pick a platform.** Native iOS (SwiftUI) is the natural fit — the brief says iOS, the design uses iOS conventions (tab bar, sheet presentations, status bar treatment). React Native is acceptable if cross-platform is a priority.
2. **Lift the tokens** from `tokens.css` into the platform's preferred form (Color extensions + a typography modifier set in SwiftUI, a tokens module in RN).
3. **Build the four-tab shell first.** Stub each tab with placeholder content. Get navigation right before any single screen is polished.
4. **Build Today's "Session ready" state next.** It establishes the visual vocabulary everything inherits.
5. **Build Active Session third.** It's the most complex and most-used screen — it'll uncover any missing tokens or interaction patterns.
6. **Stub the realtime layer early.** Partner presence + live progress is critical to the product feel; mocking it last invites surprises.
7. **The Adjust-set sheet, demo-video overlay, and in-session chat** are referenced in the brief but not designed in v1. Stub them as TODOs and come back for design before building.
