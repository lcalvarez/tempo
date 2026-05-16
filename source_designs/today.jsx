// today.jsx — Today screen, three states
// State A: Session Ready  (today's session is planned, waiting to start)
// State B: Session In Progress (Andrea is mid-session — auto-route)
// State C: Rest Day / No Plan

// ── tiny icon set (line-based, consistent 1.6 stroke) ────────
const Ic = {
  today: (s = 22, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3.2" />
      <circle cx="12" cy="12" r="8.5" />
    </svg>
  ),
  history: (s = 22, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 7h16M4 12h16M4 17h10" />
    </svg>
  ),
  progress: (s = 22, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 19V8M10 19V4M16 19v-8M22 19H2" />
    </svg>
  ),
  profile: (s = 22, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8.5" r="3.5" />
      <path d="M5 20c1.5-3.4 4-5 7-5s5.5 1.6 7 5" />
    </svg>
  ),
  play: (s = 18, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
      <path d="M7 4.5v15a.7.7 0 0 0 1.07.6L20 12 8.07 3.9A.7.7 0 0 0 7 4.5Z" />
    </svg>
  ),
  arrow: (s = 16, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  ),
  chev: (s = 14, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 6l6 6-6 6" />
    </svg>
  ),
  bolt: (s = 14, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
      <path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z" />
    </svg>
  ),
  flame: (s = 14, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3s4 4 4 8a4 4 0 1 1-8 0c0-1.5.7-2.5 1.5-3 0 1.5 1 2 1.5 2 0-2 1-5 1-7Z" />
    </svg>
  ),
  plus: (s = 16, c = 'currentColor') => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinecap="round">
      <path d="M12 5v14M5 12h14" />
    </svg>
  ),
};

// ── shared chrome ──────────────────────────────────────────
function TopBar({ partnerOnline = true, partnerName = 'Andrea', partnerInit = 'A' }) {
  return (
    <div className="topbar">
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span className="overline" style={{ color: 'var(--fg)' }}>Today</span>
        <span className="overline">·</span>
        <span className="overline mono">Tue · May 14</span>
      </div>
      <div className="partner-pip">
        <div className="avatar">{partnerInit}<div className={`dot ${partnerOnline ? '' : 'off'}`} /></div>
        <span className="name">{partnerName}</span>
      </div>
    </div>
  );
}

function TabBar({ active = 'today' }) {
  const items = [
    { id: 'today', label: 'Today', icon: Ic.today },
    { id: 'history', label: 'History', icon: Ic.history },
    { id: 'progress', label: 'Progress', icon: Ic.progress },
    { id: 'profile', label: 'Profile', icon: Ic.profile },
  ];
  return (
    <div className="tabbar">
      {items.map(it => (
        <div key={it.id} className={`tabbar-item ${active === it.id ? 'active' : ''}`}>
          {it.icon(22)}
          <span>{it.label}</span>
        </div>
      ))}
    </div>
  );
}

// ── State A: Session Ready ───────────────────────────────────
function TodaySessionReady() {
  const youPlan = [
    { name: 'Back squat', meta: '4 × 6 · 195 lb' },
    { name: 'Romanian deadlift', meta: '3 × 8 · 155 lb' },
    { name: 'Walking lunge', meta: '3 × 20' },
    { name: 'Hanging leg raise', meta: '3 × 12' },
  ];
  const partnerPlan = [
    { name: 'Goblet squat', meta: '4 × 8 · 35 lb' },
    { name: 'Hip thrust', meta: '3 × 10 · 95 lb' },
    { name: 'Reverse lunge', meta: '3 × 16' },
    { name: 'Dead bug', meta: '3 × 12' },
  ];
  return (
    <div className="app">
      <TopBar />
      <div className="scroll">

        {/* Hero session card */}
        <div className="card" style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 22 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <div className="overline">Today's session</div>
            <div className="label mono" style={{ display: 'flex', gap: 10 }}>
              <span>45 MIN</span><span style={{ color: 'var(--fg-faint)' }}>·</span><span>8 EX</span>
            </div>
          </div>
          <div className="display" style={{ fontSize: 36 }}>
            Lower body<br/>
            <span style={{ color: 'var(--fg-mute)' }}>&amp; core</span>
          </div>

          {/* Both ready row */}
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <div className="avatar you" style={{ width: 22, height: 22, fontSize: 10 }}>A</div>
            <div className="avatar" style={{ width: 22, height: 22, fontSize: 10 }}>A</div>
            <span className="label" style={{ marginLeft: 4 }}>In tempo · both ready</span>
          </div>

          <button className="cta-primary">
            <span>Start Session</span>
            {Ic.play(16, 'currentColor')}
          </button>
        </div>

        {/* Plan preview — side by side */}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 18px 12px' }}>
            <div className="overline">Today's plan</div>
            <div className="label mono" style={{ display: 'flex', alignItems: 'center', gap: 4, color: 'var(--fg-mute)' }}>
              View all {Ic.chev(12)}
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', borderTop: '1px solid var(--hairline)' }}>
            <div style={{ padding: '14px 16px 16px', borderRight: '1px solid var(--hairline)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
                <div style={{ width: 6, height: 6, borderRadius: 999, background: 'var(--you)' }} />
                <span className="label" style={{ color: 'var(--you)' }}>You</span>
              </div>
              <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
                {youPlan.map(e => (
                  <li key={e.name}>
                    <div style={{ fontSize: 13, color: 'var(--fg)', lineHeight: 1.2 }}>{e.name}</div>
                    <div className="mono" style={{ fontSize: 11, color: 'var(--fg-soft)', marginTop: 2 }}>{e.meta}</div>
                  </li>
                ))}
              </ul>
            </div>
            <div style={{ padding: '14px 16px 16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
                <div style={{ width: 6, height: 6, borderRadius: 999, background: 'var(--partner)' }} />
                <span className="label" style={{ color: 'var(--partner)' }}>Andrea</span>
              </div>
              <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
                {partnerPlan.map(e => (
                  <li key={e.name}>
                    <div style={{ fontSize: 13, color: 'var(--fg)', lineHeight: 1.2 }}>{e.name}</div>
                    <div className="mono" style={{ fontSize: 11, color: 'var(--fg-soft)', marginTop: 2 }}>{e.meta}</div>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>

        {/* Streak + last session */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="card card-tight">
            <div className="label" style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
              {Ic.flame(11, 'var(--pr)')} Streak
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span className="display numeric" style={{ fontSize: 32 }}>23</span>
              <span className="label">days</span>
            </div>
          </div>
          <div className="card card-tight">
            <div className="label" style={{ marginBottom: 10 }}>Last together</div>
            <div style={{ fontSize: 14, color: 'var(--fg)' }}>Push day</div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--fg-soft)', marginTop: 2 }}>Sun · 2 PRs</div>
          </div>
        </div>

      </div>
      <TabBar active="today" />
    </div>
  );
}

// ── State B: Session In Progress (route-in) ─────────────────
function TodaySessionInProgress() {
  return (
    <div className="app">
      <TopBar />
      <div className="scroll" style={{ justifyContent: 'flex-start' }}>

        {/* Live banner */}
        <div className="card" style={{ background: 'var(--bg-elev-1)', padding: 22, borderColor: 'var(--accent-dim)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
            <span style={{ width: 8, height: 8, borderRadius: 999, background: 'var(--accent)', boxShadow: '0 0 0 4px var(--accent-dim)' }} />
            <span className="overline" style={{ color: 'var(--accent)' }}>Session live</span>
            <span className="label mono" style={{ marginLeft: 'auto' }}>12:04 elapsed</span>
          </div>

          <div className="display" style={{ fontSize: 28, marginBottom: 18 }}>
            Andrea set <br/>
            <span style={{ color: 'var(--accent)' }}>the tempo.</span>
          </div>

          {/* Dual progress */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 22 }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
                <span className="label" style={{ color: 'var(--you)' }}>You</span>
                <span className="mono" style={{ fontSize: 12, color: 'var(--fg-faint)' }}>not started</span>
              </div>
              <div className="progress"><div className="progress-fill you" style={{ width: '0%' }} /></div>
            </div>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
                <span className="label" style={{ color: 'var(--partner)' }}>Andrea</span>
                <span className="mono" style={{ fontSize: 12, color: 'var(--fg-mute)' }}>2 / 8 · Goblet squat</span>
              </div>
              <div className="progress"><div className="progress-fill partner" style={{ width: '22%' }} /></div>
            </div>
          </div>

          <button className="cta-primary">
            <span>Join Session</span>
            {Ic.arrow(16, 'currentColor')}
          </button>
        </div>

        {/* Context: your first exercise */}
        <div className="card card-tight">
          <div className="overline" style={{ marginBottom: 12 }}>Your first up</div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <div className="display" style={{ fontSize: 20 }}>Back squat</div>
              <div className="mono" style={{ fontSize: 12, color: 'var(--fg-soft)', marginTop: 4 }}>4 sets · 6 reps · 195 lb</div>
            </div>
            <div style={{
              width: 64, height: 64, borderRadius: 12,
              background: 'repeating-linear-gradient(135deg, oklch(0.30 0.012 260) 0 6px, oklch(0.26 0.010 260) 6px 12px)',
              display: 'grid', placeItems: 'center', color: 'var(--fg-faint)', fontSize: 9, letterSpacing: 0.1,
              fontFamily: 'var(--ff-mono)', textAlign: 'center',
            }}>DEMO</div>
          </div>
        </div>

        <button className="cta-secondary">Skip warm-up · jump in cold</button>

      </div>
      <TabBar active="today" />
    </div>
  );
}

// ── State C: Rest Day / No Plan ─────────────────────────────
function TodayRestDay() {
  const yourRecent = [
    { name: 'Squat',          meta: '3 × 8 · 185 lb', pr: true,  when: 'Sun' },
    { name: 'Bench press',    meta: '4 × 5 · 165 lb', pr: false, when: 'Fri' },
    { name: 'Deadlift',       meta: '3 × 5 · 245 lb', pr: false, when: 'Wed' },
  ];
  const partnerRecent = [
    { name: 'Goblet squat',   meta: '4 × 8 · 35 lb',  pr: false, when: 'Sun' },
    { name: 'Hip thrust',     meta: '3 × 10 · 95 lb', pr: true,  when: 'Fri' },
  ];
  return (
    <div className="app">
      <TopBar />
      <div className="scroll">

        {/* Big rest message — owns the screen */}
        <div className="card" style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="overline">Today</div>
          <div className="display" style={{ fontSize: 32 }}>
            Rest day.<br/>
            <span style={{ color: 'var(--fg-mute)' }}>Recover well.</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
            {Ic.flame(13, 'var(--pr)')}
            <span className="mono" style={{ fontSize: 12, color: 'var(--fg-mute)' }}>23-day streak — next session Wed</span>
          </div>
        </div>

        {/* Quick KPIs */}
        <div className="card" style={{ padding: 18 }}>
          <div className="overline" style={{ marginBottom: 14 }}>This week, together</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14 }}>
            <div className="kpi"><span className="v">3</span><span className="u">Sessions</span></div>
            <div className="kpi"><span className="v">2h 18m</span><span className="u">Active</span></div>
            <div className="kpi"><span className="v">3</span><span className="u">PRs</span></div>
          </div>
        </div>

        {/* Recent activity — your + partner */}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ padding: '16px 18px 6px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="overline">Recent activity</div>
            <div className="label mono" style={{ display: 'flex', alignItems: 'center', gap: 4, color: 'var(--fg-mute)' }}>
              History {Ic.chev(12)}
            </div>
          </div>
          <ul style={{ listStyle: 'none', margin: 0, padding: '8px 0 8px' }}>
            {yourRecent.map(r => (
              <li key={r.name + r.when} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 18px' }}>
                <div style={{ width: 4, height: 28, borderRadius: 4, background: 'var(--you)' }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, color: 'var(--fg)' }}>{r.name}</div>
                  <div className="mono" style={{ fontSize: 11, color: 'var(--fg-soft)', marginTop: 2 }}>{r.meta} · {r.when}</div>
                </div>
                {r.pr && <span className="mono" style={{ fontSize: 10, padding: '3px 7px', borderRadius: 999, background: 'oklch(0.86 0.16 95 / 0.16)', color: 'var(--pr)', letterSpacing: 0.08, textTransform: 'uppercase' }}>PR</span>}
              </li>
            ))}
            {partnerRecent.map(r => (
              <li key={r.name + r.when} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 18px' }}>
                <div style={{ width: 4, height: 28, borderRadius: 4, background: 'var(--partner)' }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, color: 'var(--fg)' }}>Andrea · {r.name}</div>
                  <div className="mono" style={{ fontSize: 11, color: 'var(--fg-soft)', marginTop: 2 }}>{r.meta} · {r.when}</div>
                </div>
                {r.pr && <span className="mono" style={{ fontSize: 10, padding: '3px 7px', borderRadius: 999, background: 'oklch(0.86 0.16 95 / 0.16)', color: 'var(--pr)', letterSpacing: 0.08, textTransform: 'uppercase' }}>PR</span>}
              </li>
            ))}
          </ul>
        </div>

        <button className="cta-secondary">
          {Ic.plus(16, 'currentColor')}
          <span>Plan an extra session</span>
        </button>

      </div>
      <TabBar active="today" />
    </div>
  );
}

Object.assign(window, { TodaySessionReady, TodaySessionInProgress, TodayRestDay });
