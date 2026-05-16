# Manual walkthrough — Tier 2 verification

The smoke scripts cover protocol round-trips: auth, pairing, sessions,
realtime, unpair. They don't catch UX bugs that only show up when a
human navigates the app cold. This document is the short list of
things to click before pointing the build at cloud / a real phone.

Total time: ~15 minutes if nothing breaks.

> **Do this on the simulator first.** Same steps repeat against your
> iPhone after `useLocal = false`, but the simulator iteration loop is
> ~30 seconds vs ~3 minutes per round trip on a phone.

---

## Setup

```bash
./scripts/wipe-and-onboard.sh
```

That uninstalls Tempo, resets the local DB (all migrations + seed
re-applied), and relaunches. The simulator should now be on the
welcome screen with no cached profile / token.

---

## 1. Cold onboarding (5 min)

The single most likely place a real first-time tester gets stuck.
Walk through the entire flow, not just clicking through:

- [ ] **Welcome** → "Get started" advances.
- [ ] **Sign in** screen offers two real paths now: **Continue with
      email** (opens the SignInSheet — close without typing to test
      "back out" path) and **Continue as guest**. Pick guest for now.
- [ ] **Photo** → tap each of the 4 avatar tones, confirm the preview
      updates. Tap "Skip" too.
- [ ] **About you** → name, fitness level, intensity. The "Strong"
      level should highlight with the gold accent.
- [ ] **Goals** → pick 2-3 focuses; check the "Next" button enables
      only after at least 1 selection.
- [ ] **Schedule** → days per week + session length sliders.
- [ ] **Invite partner** → "Skip — train solo" should be a working
      escape hatch. Tap it.
- [ ] You should land on the **Today** tab.

What to watch for:

- Tap targets that look tappable but aren't (regression risk).
- Any toast that says "Couldn't sync" — means a profile field isn't
  reaching `profiles`. Check `remote-sync.log`.
- The streak card on Today should now show **"0 days"** (no history
  yet), not the old hardcoded `23`. ✅ verifies the Tier 3 streak fix.
- The "Last together" card should read **"Just you · invite a
  partner from Profile"** because you're solo. ✅ verifies the
  Tier 3 last-together fix.

---

## 2. Light mode (2 min)

You've been testing in dark. Force light:

- Simulator menu → **Features → Toggle Appearance** (`⌘⇧A`).

- [ ] **Today**: streak + last-together cards readable, accent gold
      still visible against light bg.
- [ ] **Active session** (start a session, log one set): tile
      backgrounds and chip outlines should still have contrast.
- [ ] **Profile** card edges shouldn't disappear into white bg.

Toggle back to dark when done; the app defaults to system.

---

## 3. Stretching session with stopwatch (3 min)

Distinct code path from strength sessions — timer-driven, no sets/reps,
saves with `kind = "stretch"`.

- [ ] Today → **Start session** → tap the **Stretching** tab in the
      active session.
- [ ] Pick a stretch area (or "Custom area").
- [ ] Hit **Start timer**, let it run 5–10 seconds, hit **Stop**.
- [ ] **Finish session** → confirm the post-session view shows the
      streak headline ("1-day streak — Day one — every streak starts
      here") rather than the old hardcoded "24-day streak".
- [ ] Tab to **Schedule** → verify the session row appears with the
      correct duration.

---

## 4. Schedule timeline scroll (1 min)

The `scrollTo("today")` anchor was buggy historically.

- [ ] Tap the **Schedule** tab → today's row should center in the
      viewport. (Past rows scroll up, future rows scroll down.)
- [ ] Scroll way down → tap the floating "today" chip if present →
      should snap back to today.

---

## 5. Profile relationship label (2 min)

Not in any smoke script. The `set_relationship_label` RPC should
push the change and the partner side should pick it up.

- [ ] You need to be paired for this. Either pair with a second sim
      user (see `scripts/smoke-pairing-with-app.sh`) or use the
      partner-side checks in §6.
- [ ] Profile → tap the partner's name/relationship → set to
      "Spouse" (or any custom label).
- [ ] Confirm a green toast.
- [ ] Check `psql`:
      ```sql
      select label_a, label_b, custom_label_a, custom_label_b
        from public.partnerships
       where user_a = '<your-uid>' or user_b = '<your-uid>';
      ```
      The right column should hold your new label.

---

## 6. Different goals · same window (1 min)

Real edge case: the UI is supposed to surface divergent partner goals
gracefully.

- [ ] Pair with a partner who has different focuses than you (use the
      smoke pairing flow + manually patch the partner's profile via
      Supabase Studio: change `focuses` to a different array).
- [ ] Today screen should still render both plans side-by-side. The
      partner column shows their session theme, not yours.
- [ ] **No crash, no empty state.**

---

## 7. Custom stretch area (1 min)

Distinct JSONB column from `custom_exercises`. Has its own UI path.

- [ ] In an active stretching session, tap **Custom area**.
- [ ] Enter a name ("Hip flexor mobility"), save.
- [ ] Confirm the new area appears in the stretch-area picker on the
      next visit.
- [ ] Verify in DB:
      ```sql
      select custom_stretch_areas from public.profiles
       where id = '<your-uid>';
      ```
      Your new entry should be in the JSONB array.

---

## Failure triage

| Symptom | Likely cause | Where to look |
|---|---|---|
| Onboarding silently doesn't advance | Anon sign-in failed on launch | `remote-sync.log` for `ensureSignedIn skipped` |
| Profile fields don't sync | Debounce flush errored | `remote-sync.log` for `flushProfile` lines |
| Light mode hides text | A `Theme.Color` variant collapsed to same value | `ios/Tempo/Theme/Theme.swift` `dyn(...)` calls |
| Today shows `0 days` even after a session | `currentStreak` calendar-day comparison off | `Models.swift` extension at the bottom |
| "Last together" stays "Just you" while paired | `partnerTitle` not stamped at save time | `ActiveSessionView.finishSession()` |
| Schedule doesn't scroll to today | `ScrollViewReader` ID mismatch (it was `"today"` last fix) | `ScheduleView.swift` `scrollTo` calls |

---

## When to run this

- **Before every cloud config flip** (`useLocal = false`). Catches
  bugs that the simulator-on-local masks.
- **Before every TestFlight upload.** Apple's reviewers won't run
  smoke scripts; they'll run cold onboarding. So should you.
- **After any `Theme`, `OnboardingFlow`, or `Models.swift` change.**
  Those three files have the highest blast radius for visual /
  flow regressions.

---

## What this *doesn't* cover

These are real-phone-only — see RELEASE.md §4.5 for the on-device
checks. Light summary:

- Realtime over actual WSS (latency, reconnect on backgrounding).
- Battery drain from long-lived realtime channel.
- Real iOS share-sheet → Messages flow for partner invite (the
  smoke uses a file-based test driver, not the real share sheet).
- Push notifications — don't exist yet.
- App backgrounding mid-session (sim approximates, doesn't match).
