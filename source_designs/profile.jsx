// profile.jsx — Profile & Settings screen + unpair flow
// Compositions:
//   A. Profile (main)         — settings landing, partner card with "Unpair" affordance
//   B. Unpair confirmation    — destructive confirmation sheet over the Profile screen

function ChevRow({ label, val, danger = false, sub }) {
  return (
    <div className={`set-row ${danger ? 'destructive' : ''}`}>
      <span className="label">{label}</span>
      {val != null && <span className="val">{val}</span>}
      <svg className="chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M9 6l6 6-6 6" />
      </svg>
    </div>
  );
}

function ToggleRow({ label, on = true, hint }) {
  return (
    <div className="set-row">
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span className="label">{label}</span>
        {hint && <span className="val" style={{ fontFamily: 'var(--ff-sans)', fontSize: 12, color: 'var(--fg-soft)' }}>{hint}</span>}
      </div>
      <div style={{
        width: 40, height: 24, borderRadius: 999,
        background: on ? 'var(--accent)' : 'var(--bg-elev-3)',
        position: 'relative', flexShrink: 0
      }}>
        <div style={{
          position: 'absolute', top: 2, left: on ? 18 : 2,
          width: 20, height: 20, borderRadius: 999,
          background: '#fff', boxShadow: '0 1px 2px oklch(0 0 0 / 0.4)'
        }} />
      </div>
    </div>
  );
}

// Section A — Profile (main screen)
function ProfileMain() {
  return (
    <div className="app">

      {/* Top header bar — just the page title */}
      <div className="topbar" style={{ top: 66 }}>
        <span className="overline" style={{ color: 'var(--fg)' }}>Profile</span>
        <div className="iconbtn" style={{ width: 34, height: 34 }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="2"/><circle cx="12" cy="5" r="2"/><circle cx="12" cy="19" r="2"/>
          </svg>
        </div>
      </div>

      <div className="prof-scroll" style={{ paddingTop: 110 }}>

        {/* Profile header */}
        <div className="prof-head">
          <div className="av">A</div>
          <div className="meta">
            <span className="name">Alex Chen</span>
            <span className="email">alex@gmail.com · 32 · Strong</span>
          </div>
        </div>

        {/* Partner section — features the unpair affordance */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Partner</span>
            <span className="meta">Connected · 47 days</span>
          </div>
          <div className="partner-card">
            <div className="top">
              <div className="av">A<div className="dot" style={{ bottom: -1, right: -1, position: 'absolute' }}/></div>
              <div style={{ flex: 1, position: 'relative' }}>
                <div className="name">Andrea Chen</div>
                <div className="since">In tempo since Mar 28 · online</div>
              </div>
            </div>
            <div className="stat-row">
              <div>
                <div className="v">23</div>
                <div className="u">Sessions</div>
              </div>
              <div>
                <div className="v">19h 04m</div>
                <div className="u">Together</div>
              </div>
              <div>
                <div className="v">7</div>
                <div className="u">PRs · joint</div>
              </div>
            </div>
            <button className="btn-destructive">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M10 7H4M14 17h6"/><circle cx="8" cy="7" r="3"/><circle cx="16" cy="17" r="3"/>
              </svg>
              Unpair from Andrea
            </button>
          </div>
        </div>

        {/* Goals */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Goals</span>
            <span className="meta">Last edited Apr 18</span>
          </div>
          <div className="set-list">
            <ChevRow label="Primary focus"     val="Strength · Hypertrophy" />
            <ChevRow label="Sessions per week" val="4"/>
            <ChevRow label="Time per session"  val="45 min"/>
            <ChevRow label="Intensity"         val="Moderate"/>
            <ChevRow label="Styles I enjoy"    val="Free weights · Conditioning" />
          </div>
        </div>

        {/* Preferences */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Preferences</span>
          </div>
          <div className="set-list">
            <ChevRow label="Units"              val="lbs · mi" />
            <ChevRow label="Rest timer default" val="90 s" />
            <ToggleRow label="Session reminders" on={true} hint="20 min before scheduled start" />
            <ToggleRow label="Partner activity"  on={true} hint="When Andrea logs a PR or finishes" />
            <ToggleRow label="Chat notifications" on={false} />
          </div>
        </div>

        {/* Power-user */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Advanced</span>
            <span className="meta">Optional</span>
          </div>
          <div className="set-list">
            <ToggleRow label="Show RPE field" on={false} hint="Rate of perceived exertion per set"/>
            <ToggleRow label="Plate calculator" on={true} />
            <ChevRow label="Export data" val="CSV"/>
          </div>
        </div>

        {/* Account */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Account</span>
          </div>
          <div className="set-list">
            <ChevRow label="Sign out" />
            <ChevRow label="Delete account" danger />
          </div>
        </div>

        <div style={{ textAlign: 'center', padding: '12px 0 0' }}>
          <span className="label" style={{ color: 'var(--fg-faint)' }}>Tempo · v1.0.0</span>
        </div>

      </div>

      {/* Reuse the tab bar from today — duplicated here so this works standalone */}
      <div className="tabbar">
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="3.2"/><circle cx="12" cy="12" r="8.5"/>
          </svg>
          <span>Today</span>
        </div>
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 7h16M4 12h16M4 17h10"/>
          </svg>
          <span>History</span>
        </div>
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 19V8M10 19V4M16 19v-8M22 19H2"/>
          </svg>
          <span>Progress</span>
        </div>
        <div className="tabbar-item active">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="8.5" r="3.5"/>
            <path d="M5 20c1.5-3.4 4-5 7-5s5.5 1.6 7 5"/>
          </svg>
          <span>Profile</span>
        </div>
      </div>
    </div>
  );
}

// Section B — Unpair confirmation
function ProfileUnpairConfirm() {
  return (
    <div className="app" style={{ position: 'relative' }}>
      {/* Dimmed underlying profile */}
      <div className="topbar" style={{ top: 66 }}>
        <span className="overline" style={{ color: 'var(--fg)' }}>Profile</span>
      </div>
      <div className="prof-scroll" style={{ paddingTop: 110, opacity: 0.25, filter: 'blur(0.5px)' }}>
        <div className="prof-head">
          <div className="av">A</div>
          <div className="meta"><span className="name">Alex Chen</span></div>
        </div>
        <div>
          <div className="set-section-head"><span className="ttl">Partner</span></div>
          <div className="partner-card">
            <div className="top">
              <div className="av">A</div>
              <div><div className="name">Andrea Chen</div></div>
            </div>
          </div>
        </div>
      </div>

      {/* Backdrop */}
      <div className="sheet-backdrop" />

      {/* Centered confirmation sheet */}
      <div className="sheet-confirm">
        <div className="sheet-handle" />

        {/* Visual: the pairing link being broken */}
        <div className="pair-row" style={{ marginTop: 10, marginBottom: 6 }}>
          <div className="pair-avatar you">A</div>
          <div style={{
            width: 28, height: 2, background: 'oklch(0.55 0.20 25)',
            margin: '0 -6px', position: 'relative', zIndex: 1, opacity: 0.7
          }}>
            <span style={{
              position: 'absolute', top: '50%', left: '50%',
              transform: 'translate(-50%, -50%)',
              fontFamily: 'var(--ff-mono)', fontSize: 18,
              background: 'var(--bg-elev-1)', color: 'oklch(0.78 0.14 25)',
              padding: '0 4px', lineHeight: 1
            }}>✕</span>
          </div>
          <div className="pair-avatar par">A</div>
        </div>

        <div style={{ textAlign: 'center', padding: '4px 8px 8px' }}>
          <div className="display" style={{ fontSize: 24 }}>
            Unpair from Andrea?
          </div>
          <p className="ob-sub" style={{ marginTop: 8, fontSize: 13.5 }}>
            You'll no longer share sessions. Your individual workout history stays — joint sessions remain visible in both accounts but won't update.
          </p>
        </div>

        {/* What will happen — clear, calm bullets */}
        <div className="set-list">
          <div className="set-row" style={{ alignItems: 'flex-start' }}>
            <div style={{
              width: 22, height: 22, borderRadius: 999, background: 'var(--accent-dim)',
              display: 'grid', placeItems: 'center', flexShrink: 0, marginTop: 1
            }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 13l4 4L19 7"/>
              </svg>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, color: 'var(--fg)' }}>Your individual history is kept</div>
              <div className="val" style={{ fontFamily: 'var(--ff-sans)', fontSize: 12, color: 'var(--fg-soft)' }}>23 sessions, PRs, charts</div>
            </div>
          </div>
          <div className="set-row" style={{ alignItems: 'flex-start' }}>
            <div style={{
              width: 22, height: 22, borderRadius: 999, background: 'oklch(0.55 0.20 25 / 0.18)',
              display: 'grid', placeItems: 'center', flexShrink: 0, marginTop: 1
            }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="oklch(0.78 0.14 25)" strokeWidth="2.5" strokeLinecap="round">
                <path d="M6 6l12 12M18 6L6 18"/>
              </svg>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, color: 'var(--fg)' }}>Andrea will be notified</div>
              <div className="val" style={{ fontFamily: 'var(--ff-sans)', fontSize: 12, color: 'var(--fg-soft)' }}>They can re-invite you any time</div>
            </div>
          </div>
          <div className="set-row" style={{ alignItems: 'flex-start' }}>
            <div style={{
              width: 22, height: 22, borderRadius: 999, background: 'oklch(0.55 0.20 25 / 0.18)',
              display: 'grid', placeItems: 'center', flexShrink: 0, marginTop: 1
            }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="oklch(0.78 0.14 25)" strokeWidth="2.5" strokeLinecap="round">
                <path d="M6 6l12 12M18 6L6 18"/>
              </svg>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, color: 'var(--fg)' }}>Your next session is cancelled</div>
              <div className="val" style={{ fontFamily: 'var(--ff-sans)', fontSize: 12, color: 'var(--fg-soft)' }}>Lower body · Wed 6:30 PM</div>
            </div>
          </div>
        </div>

        {/* Type-to-confirm — small friction for a destructive action */}
        <div className="field" style={{ marginTop: 4 }}>
          <div className="field-label">Type ANDREA to confirm</div>
          <div className="field-input filled" style={{ height: 48 }}>
            <span className="placeholder">ANDREA</span>
          </div>
        </div>

        <button className="btn-destructive-solid" disabled style={{ opacity: 0.5 }}>
          Unpair
        </button>
        <button className="adjust-link" style={{ color: 'var(--fg-mute)' }}>Cancel</button>
      </div>
    </div>
  );
}

Object.assign(window, { ProfileMain, ProfileUnpairConfirm });
