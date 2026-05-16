// post.jsx — Post-session comparison + PR celebration moment

// ── A. Post-session comparison ──────────────────────────
function PostSessionCompare() {
  const session = [
    { ex: 'Back squat',         pr: true,
      you: ['Set 1 · 6 × 195', 'Set 2 · 6 × 195', 'Set 3 · 6 × 200', 'Set 4 · 5 × 200'],
      par: ['Set 1 · 8 × 35',  'Set 2 · 8 × 35',  'Set 3 · 8 × 35',  'Set 4 · 8 × 40'] },
    { ex: 'Romanian deadlift',
      you: ['Set 1 · 8 × 155', 'Set 2 · 8 × 155', 'Set 3 · 8 × 155'],
      par: ['Set 1 · 10 × 95', 'Set 2 · 10 × 95', 'Set 3 · 10 × 100'] },
    { ex: 'Walking lunge',
      you: ['3 × 20 · bodyweight'],
      par: ['3 × 16 · bodyweight'] },
    { ex: 'Hanging leg raise',  pr: true,
      you: ['3 × 12'],
      par: ['—'] },
    { ex: 'Plank',
      you: ['3 × 45s'],
      par: ['3 × 30s'] },
  ];
  return (
    <div className="app">
      {/* Hero */}
      <div className="scroll" style={{ paddingTop: 70, paddingBottom: 110, gap: 18 }}>

        <div className="complete-hero">
          <div className="overline" style={{ color: 'var(--accent)' }}>Done · in tempo</div>
          <div className="duration">45:08</div>
          <div className="label" style={{ marginTop: 8 }}>Lower body & core · together</div>
        </div>

        {/* Streak update */}
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 44, height: 44, borderRadius: 999, background: 'oklch(0.86 0.16 95 / 0.16)', display: 'grid', placeItems: 'center', color: 'var(--pr)' }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 3s4 4 4 8a4 4 0 1 1-8 0c0-1.5.7-2.5 1.5-3 0 1.5 1 2 1.5 2 0-2 1-5 1-7Z"/>
            </svg>
          </div>
          <div style={{ flex: 1 }}>
            <div className="display" style={{ fontSize: 17 }}>24-day streak</div>
            <div className="mono" style={{ fontSize: 12, color: 'var(--fg-soft)', marginTop: 2 }}>Longest yet — keep it rolling Wed</div>
          </div>
          <span className="mono" style={{ fontSize: 22, color: 'var(--fg)', fontWeight: 600 }}>+1</span>
        </div>

        {/* KPI row */}
        <div className="cardio-row" style={{ gridTemplateColumns: '1fr 1fr 1fr' }}>
          <div className="kpi"><span className="v numeric">8,650</span><span className="u">Volume lb · you</span></div>
          <div className="kpi"><span className="v numeric">2</span><span className="u">PRs hit</span></div>
          <div className="kpi"><span className="v numeric">38:21</span><span className="u">Active time</span></div>
        </div>

        {/* Header row for comparison */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '8px 4px 0' }}>
          <div className="overline">Side-by-side</div>
          <div className="label" style={{ display: 'flex', gap: 14 }}>
            <span style={{ color: 'var(--you)' }}>● You</span>
            <span style={{ color: 'var(--partner)' }}>● Andrea</span>
          </div>
        </div>

        {/* Per-exercise rows */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {session.map(s => (
            <div key={s.ex} className="cmp-row">
              <div className="name-bar">
                <span className="ex">{s.ex}</span>
                {s.pr && <span className="pr">★ Personal record</span>}
              </div>
              <div className="cmp-col you">
                <span className="meta">You</span>
                {s.you.map((v, i) => <div className="vals" key={i}>{v}</div>)}
              </div>
              <div className="cmp-divider" />
              <div className="cmp-col par">
                <span className="meta">Andrea</span>
                {s.par.map((v, i) => <div className="vals" key={i}>{v}</div>)}
              </div>
            </div>
          ))}
        </div>

        {/* React row */}
        <div>
          <div className="overline" style={{ marginBottom: 8 }}>Send Andrea a reaction</div>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <span className="react-bubble"><span className="em">💪</span></span>
            <span className="react-bubble"><span className="em">🔥</span></span>
            <span className="react-bubble"><span className="em">👏</span></span>
            <span className="react-bubble"><span className="em">😮‍💨</span></span>
            <span className="react-bubble">Type a note…</span>
          </div>
        </div>

      </div>

      <div className="action-dock" style={{ paddingBottom: 24 }}>
        <button className="cta-primary cta-tall">
          <span>Done</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M5 13l4 4L19 7"/></svg>
        </button>
      </div>
    </div>
  );
}

// ── B. PR celebration (mid-session) ─────────────────────
function PRMoment() {
  return (
    <div className="app" style={{ position: 'relative' }}>
      {/* dimmed session below */}
      <div className="active-topbar" style={{ top: 60, opacity: 0.3 }}>
        <div className="session-meta">
          <div className="exit-btn"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M6 6l12 12M18 6L6 18"/></svg></div>
          <span className="overline mono numeric" style={{ color: 'var(--fg)' }}>14:22</span>
        </div>
        <div className="partner-pip"><div className="avatar">A<div className="dot"/></div><span className="name">Andrea</span></div>
      </div>

      {/* Backdrop */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(80% 60% at 50% 40%, oklch(0.86 0.16 95 / 0.12) 0%, oklch(0.16 0.006 260 / 0.9) 60%)', zIndex: 1 }} />

      {/* Centerpiece */}
      <div style={{
        position: 'absolute', inset: 0, zIndex: 2,
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        padding: '0 24px', gap: 22
      }}>
        <div className="pr-burst">
          <span className="glyph">PR</span>
        </div>

        <div style={{ textAlign: 'center' }}>
          <div className="overline" style={{ color: 'var(--pr)' }}>Personal record</div>
          <div className="display" style={{ fontSize: 32, marginTop: 6 }}>
            Back squat
          </div>
          <div className="hero" style={{ marginTop: 14 }}>
            <span className="n" style={{ fontSize: 64 }}>6</span>
            <span className="x" style={{ fontSize: 22 }}>×</span>
            <span className="n" style={{ fontSize: 64 }}>200</span>
          </div>
          <div className="hero-units" style={{ marginTop: 6 }}>reps × lb</div>
          <div className="mono" style={{ fontSize: 12, color: 'var(--fg-soft)', marginTop: 14 }}>
            Previous best · 6 × 195 · Mar 18
          </div>
        </div>

        <div style={{ width: '100%', maxWidth: 320, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button className="cta-primary cta-tall">
            <span>Log it</span>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M5 13l4 4L19 7"/></svg>
          </button>
          <button className="adjust-link">Failed — adjust</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { PostSessionCompare, PRMoment });
