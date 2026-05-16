// progress.jsx — Progress tab (overview + per-exercise detail)

// Inline SVG line chart placeholder
function LineChart({ stroke = 'var(--accent)', dots = true, height = 110, showPartner = false }) {
  // Hand-tuned path that feels like a real trend curve
  const points = [
    [0, 70], [12, 64], [24, 58], [36, 62], [48, 50],
    [60, 54], [72, 42], [84, 46], [96, 36], [108, 28], [120, 24]
  ];
  const partnerPoints = [
    [0, 80], [12, 78], [24, 70], [36, 72], [48, 66],
    [60, 60], [72, 62], [84, 54], [96, 50], [108, 48], [120, 42]
  ];
  const toPath = (pts) => pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${(p[0] / 120) * 280},${p[1]}`).join(' ');
  return (
    <svg width="100%" height={height} viewBox={`0 0 280 ${height}`} preserveAspectRatio="none" style={{ overflow: 'visible' }}>
      {/* gridlines */}
      {[0, 0.33, 0.66, 1].map((r, i) => (
        <line key={i} x1="0" x2="280" y1={r * (height - 20) + 10} y2={r * (height - 20) + 10}
              stroke="var(--hairline)" strokeDasharray="2 4" />
      ))}
      {/* area fill */}
      <path d={`${toPath(points)} L 280,${height} L 0,${height} Z`} fill={stroke} opacity="0.08" />
      {/* partner line */}
      {showPartner && (
        <path d={toPath(partnerPoints)} fill="none" stroke="var(--partner)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" opacity="0.6" />
      )}
      {/* main line */}
      <path d={toPath(points)} fill="none" stroke={stroke} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      {/* end dot */}
      {dots && (
        <circle cx="280" cy="24" r="4" fill={stroke} />
      )}
    </svg>
  );
}

// Bar chart placeholder (volume per week)
function BarChart({ vals = [60, 78, 55, 90, 72, 85, 100], height = 90 }) {
  const max = Math.max(...vals);
  return (
    <svg width="100%" height={height} viewBox={`0 0 280 ${height}`} preserveAspectRatio="none">
      {vals.map((v, i) => {
        const w = 28;
        const gap = 12;
        const total = vals.length * w + (vals.length - 1) * gap;
        const start = (280 - total) / 2;
        const x = start + i * (w + gap);
        const h = (v / max) * (height - 10);
        const isLast = i === vals.length - 1;
        return (
          <rect key={i}
            x={x} y={height - h} width={w} height={h} rx="4"
            fill={isLast ? 'var(--accent)' : 'var(--bg-elev-3)'}/>
        );
      })}
    </svg>
  );
}

// ── A. Progress · Overview ─────────────────────────────
function ProgressOverview() {
  const exerciseTops = [
    { ex: 'Back squat',         best: '200 lb × 6',  delta: '+5 lb', up: true },
    { ex: 'Bench press',        best: '170 lb × 5',  delta: '+5 lb', up: true },
    { ex: 'Romanian deadlift',  best: '155 lb × 8',  delta: '—',     up: null },
    { ex: 'Pull-up',            best: '12 reps',     delta: '+2',    up: true },
  ];
  return (
    <div className="app">
      <div className="topbar" style={{ top: 66 }}>
        <span className="overline" style={{ color: 'var(--fg)' }}>Progress</span>
        <div className="range-row" style={{ width: 168 }}>
          <button>1W</button>
          <button className="on">1M</button>
          <button>3M</button>
          <button>1Y</button>
        </div>
      </div>

      <div className="scroll" style={{ paddingTop: 110, paddingBottom: 110, gap: 18 }}>

        {/* Top KPI row */}
        <div className="card" style={{ padding: 16 }}>
          <div className="overline" style={{ marginBottom: 14 }}>This month</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
            <div className="kpi"><span className="v">17</span><span className="u">Sessions</span></div>
            <div className="kpi"><span className="v">12h 32m</span><span className="u">Active</span></div>
            <div className="kpi"><span className="v">5</span><span className="u">PRs</span></div>
          </div>
        </div>

        {/* Volume chart */}
        <div className="chart-card">
          <div className="chart-head">
            <span className="ttl">Volume · weekly</span>
            <span><span className="val">42,800</span><span className="delta up">▲ 14%</span></span>
          </div>
          <BarChart vals={[60, 78, 55, 90, 72, 85, 100]} />
          <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--ff-mono)', fontSize: 10, color: 'var(--fg-faint)', padding: '0 6px' }}>
            <span>W1</span><span>W2</span><span>W3</span><span>W4</span><span>W5</span><span>W6</span><span>W7</span>
          </div>
        </div>

        {/* Estimated 1RM trend */}
        <div className="chart-card">
          <div className="chart-head">
            <span className="ttl">Squat · est. 1RM</span>
            <span><span className="val">238 lb</span><span className="delta up">▲ 8 lb</span></span>
          </div>
          <LineChart showPartner />
          <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--ff-mono)', fontSize: 10, color: 'var(--fg-faint)' }}>
            <span>Apr 14</span><span>May 14</span>
          </div>
          <div className="label" style={{ display: 'flex', gap: 14, marginTop: 2 }}>
            <span style={{ color: 'var(--you)' }}>● You</span>
            <span style={{ color: 'var(--partner)' }}>● Andrea</span>
          </div>
        </div>

        {/* Top lifts list */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Top lifts</span>
            <span className="meta">Tap for chart</span>
          </div>
          <div className="set-list">
            {exerciseTops.map(t => (
              <div key={t.ex} className="set-row" style={{ alignItems: 'center' }}>
                <span className="label" style={{ flex: 1 }}>{t.ex}</span>
                <span className="val">{t.best}</span>
                <span className="mono" style={{ fontSize: 11, color: t.up === true ? 'var(--accent)' : t.up === false ? 'oklch(0.74 0.12 25)' : 'var(--fg-faint)', minWidth: 44, textAlign: 'right' }}>
                  {t.delta}
                </span>
                <svg className="chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M9 6l6 6-6 6"/></svg>
              </div>
            ))}
          </div>
        </div>

        {/* Body-part heatmap */}
        <div className="chart-card">
          <div className="chart-head">
            <span className="ttl">Coverage · last 6 weeks</span>
            <span className="meta">By muscle group</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[
              { name: 'Quads',     cells: [3,2,4,1,3,4,2], val: '19 sessions' },
              { name: 'Hamstrings',cells: [2,3,2,2,3,2,4], val: '18 sessions' },
              { name: 'Glutes',    cells: [3,4,2,3,3,4,3], val: '22 sessions' },
              { name: 'Chest',     cells: [1,2,0,2,1,2,1], val: '9 sessions' },
              { name: 'Back',      cells: [2,1,2,3,2,1,3], val: '14 sessions' },
              { name: 'Core',      cells: [2,2,3,2,3,2,3], val: '17 sessions' },
            ].map(row => (
              <div key={row.name} style={{ display: 'grid', gridTemplateColumns: '90px 1fr 80px', gap: 10, alignItems: 'center' }}>
                <span style={{ fontFamily: 'var(--ff-mono)', fontSize: 11, color: 'var(--fg-mute)', letterSpacing: '0.04em' }}>{row.name}</span>
                <div className="heatmap" style={{ gridTemplateColumns: 'repeat(7, 1fr)' }}>
                  {row.cells.map((c, i) => <div key={i} className={`cell ${['','l1','l2','l3','l4'][c]}`} />)}
                </div>
                <span className="mono" style={{ fontSize: 10.5, color: 'var(--fg-soft)', textAlign: 'right' }}>{row.val}</span>
              </div>
            ))}
          </div>
        </div>

      </div>

      {/* Tab bar */}
      <div className="tabbar">
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3.2"/><circle cx="12" cy="12" r="8.5"/></svg>
          <span>Today</span>
        </div>
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M4 7h16M4 12h16M4 17h10"/></svg>
          <span>History</span>
        </div>
        <div className="tabbar-item active">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M4 19V8M10 19V4M16 19v-8M22 19H2"/></svg>
          <span>Progress</span>
        </div>
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="8.5" r="3.5"/><path d="M5 20c1.5-3.4 4-5 7-5s5.5 1.6 7 5"/></svg>
          <span>Profile</span>
        </div>
      </div>
    </div>
  );
}

// ── B. Per-exercise detail (Back squat) ───────────────────
function ProgressExerciseDetail() {
  return (
    <div className="app">
      {/* Header with back */}
      <div className="active-topbar" style={{ top: 60 }}>
        <button className="exit-btn">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6l-6 6 6 6"/></svg>
        </button>
        <span className="overline" style={{ color: 'var(--fg)' }}>Back squat</span>
        <div className="iconbtn" style={{ width: 34, height: 34 }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="2"/><circle cx="12" cy="5" r="2"/><circle cx="12" cy="19" r="2"/></svg>
        </div>
      </div>

      <div className="scroll" style={{ paddingTop: 108, paddingBottom: 40, gap: 18 }}>
        {/* Hero — current best */}
        <div style={{ textAlign: 'center', padding: '8px 0 0' }}>
          <div className="overline">Current best · est. 1RM</div>
          <div className="hero" style={{ marginTop: 10 }}>
            <span className="n" style={{ fontSize: 80 }}>238</span>
          </div>
          <div className="hero-units" style={{ marginTop: 4 }}>lb</div>
          <div className="mono" style={{ fontSize: 12, color: 'var(--accent)', marginTop: 8 }}>▲ 14 lb in 6 weeks</div>
        </div>

        {/* Range */}
        <div className="range-row">
          <button>1M</button>
          <button className="on">3M</button>
          <button>6M</button>
          <button>1Y</button>
          <button>All</button>
        </div>

        {/* 1RM chart */}
        <div className="chart-card">
          <div className="chart-head">
            <span className="ttl">Estimated 1RM</span>
            <span><span className="val">238 lb</span></span>
          </div>
          <LineChart showPartner height={140} />
          <div className="label" style={{ display: 'flex', gap: 14 }}>
            <span style={{ color: 'var(--you)' }}>● You · 238 lb</span>
            <span style={{ color: 'var(--partner)' }}>● Andrea · 165 lb</span>
          </div>
        </div>

        {/* Volume chart */}
        <div className="chart-card">
          <div className="chart-head">
            <span className="ttl">Volume per session</span>
            <span><span className="val">4,800 lb</span><span className="delta up">▲ 9%</span></span>
          </div>
          <BarChart vals={[55, 60, 70, 72, 80, 76, 90]} height={80} />
        </div>

        {/* Set frequency strip */}
        <div className="card" style={{ padding: 16 }}>
          <div className="overline" style={{ marginBottom: 10 }}>Frequency · last 30 days</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span className="display numeric" style={{ fontSize: 32 }}>9</span>
            <span className="label">sessions</span>
            <span style={{ flex: 1 }} />
            <span className="mono" style={{ fontSize: 12, color: 'var(--fg-soft)' }}>~2.1 / week</span>
          </div>
        </div>

        {/* Set history table */}
        <div>
          <div className="set-section-head">
            <span className="ttl">Recent sets</span>
            <span className="meta">Tap to see context</span>
          </div>
          <div className="set-list">
            {[
              { d: 'May 14', sets: '4×6 · 195, 195, 200, 200', pr: true },
              { d: 'May 6',  sets: '4×6 · 190, 195, 195, 195' },
              { d: 'Apr 28', sets: '4×6 · 185, 190, 190, 195' },
              { d: 'Apr 24', sets: '4×6 · 185, 185, 190, 190' },
              { d: 'Apr 17', sets: '4×6 · 180, 185, 185, 185' },
            ].map((s, i) => (
              <div key={i} className="set-row" style={{ alignItems: 'flex-start' }}>
                <div style={{ flex: 1 }}>
                  <div className="label" style={{ color: 'var(--fg)', fontFamily: 'var(--ff-sans)', fontSize: 14, fontWeight: 500, textTransform: 'none', letterSpacing: 0 }}>{s.d}</div>
                  <div className="mono" style={{ fontSize: 11.5, color: 'var(--fg-soft)', marginTop: 3 }}>{s.sets}</div>
                </div>
                {s.pr && <span className="pr-pill">★ PR</span>}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ProgressOverview, ProgressExerciseDetail });
