// active.jsx — Active session (the heart of the app)
// Compositions:
//   A. Strength · between sets (rest timer + log-set CTA defaulted)
//   B. Cardio · live distance run
//   C. Plan sheet (swipe-up) over the active screen

// ── shared chrome ───────────────────────────────────────────
function ActiveTopBar({ elapsed = '12:04', exNum = 2, exTotal = 8 }) {
  return (
    <div className="active-topbar">
      <div className="session-meta">
        <button className="exit-btn" aria-label="Exit session">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
        <div className="overline mono numeric" style={{ color: 'var(--fg)' }}>{elapsed}</div>
        <span className="overline" style={{ color: 'var(--fg-faint)' }}>·</span>
        <span className="overline mono">{exNum} / {exTotal}</span>
      </div>
      <div className="partner-pip">
        <div className="avatar">A<div className="dot" /></div>
        <span className="name">Andrea</span>
      </div>
    </div>
  );
}

function DualProgress({ you, partner, partnerEx, partnerSet, partnerTotal }) {
  return (
    <div className="dual-progress">
      <div className="dual-progress-row">
        <span className="who" style={{ color: 'var(--you)' }}>You</span>
        <div className="progress"><div className="progress-fill you" style={{ width: `${you}%` }} /></div>
        <span className="meta">{you}%</span>
      </div>
      <div className="dual-progress-row">
        <span className="who" style={{ color: 'var(--partner)' }}>Andrea</span>
        <div className="progress"><div className="progress-fill partner" style={{ width: `${partner}%` }} /></div>
        <span className="meta">{partner}%</span>
      </div>
    </div>
  );
}

// ── A. Strength · between sets ──────────────────────────────
function ActiveStrengthBetweenSets() {
  return (
    <div className="app">
      <ActiveTopBar elapsed="12:04" exNum={2} exTotal={8} />
      <div className="scroll" style={{ paddingTop: 110, paddingBottom: 200, gap: 18 }}>

        <DualProgress
          you={28}
          partner={42}
          partnerEx="Goblet squat"
          partnerSet={3}
          partnerTotal={4}
        />

        {/* Rest timer block */}
        <div className="rest-block">
          <div className="rest-label">
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M9 2h6"/></svg>
            Rest
          </div>
          <div className="rest-bar"><div className="rest-bar-fill" style={{ width: '47%' }} /></div>
          <div className="rest-time">0:42</div>
        </div>

        {/* Current exercise */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, marginTop: 4 }}>
          <div className="label" style={{ color: 'var(--fg-soft)' }}>Set 3 of 4 · Back squat</div>
        </div>

        {/* Hero numbers */}
        <div>
          <div className="hero">
            <span className="n">6</span>
            <span className="x">×</span>
            <span className="n">195</span>
          </div>
          <div className="hero-units">reps × lb</div>
        </div>

        {/* Set chips */}
        <div className="set-chips">
          <div className="set-chip done">
            <span className="num">Set 1</span>
            <span className="val">6 × 195</span>
          </div>
          <div className="set-chip done">
            <span className="num">Set 2</span>
            <span className="val">6 × 195</span>
          </div>
          <div className="set-chip current">
            <span className="num">Set 3</span>
            <span className="val">6 × 195</span>
          </div>
          <div className="set-chip">
            <span className="num">Set 4</span>
            <span className="val">6 × 195</span>
          </div>
        </div>

      </div>

      {/* Bottom-pinned action dock */}
      <div className="action-dock">
        <div className="partner-strip">
          <div className="avatar" style={{ width: 22, height: 22, fontSize: 10 }}>A</div>
          <span className="ex"><b>Andrea</b> · Goblet squat · set 3 of 4</span>
          <button className="chat-pip unread" aria-label="Chat">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a8 8 0 0 1-11.5 7.2L4 21l1.8-5.5A8 8 0 1 1 21 12Z"/></svg>
          </button>
        </div>
        <button className="cta-primary cta-tall">
          <span>Log Set 3 · 6 × 195</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
        <div className="dock-actions">
          <button>Adjust</button>
          <span className="sep">·</span>
          <button>Skip set</button>
          <span className="sep">·</span>
          <button className="danger">End session</button>
        </div>
      </div>
    </div>
  );
}

// ── B. Cardio · live distance ──────────────────────────────
function ActiveCardio() {
  return (
    <div className="app">
      <ActiveTopBar elapsed="18:22" exNum={5} exTotal={8} />
      <div className="scroll" style={{ paddingTop: 110, paddingBottom: 200, gap: 18 }}>

        <DualProgress you={62} partner={58} partnerEx="Stationary bike" partnerSet={1} partnerTotal={1} />

        <div className="label" style={{ textAlign: 'center', marginTop: 8, color: 'var(--fg-soft)' }}>
          Exercise 5 of 8 · Easy run
        </div>

        {/* Hero — distance counting up */}
        <div className="cardio-hero">
          <div className="big">1.84</div>
          <div className="unit">miles</div>
        </div>

        {/* Sub KPIs */}
        <div className="cardio-row">
          <div className="kpi"><span className="v numeric">06:11</span><span className="u">elapsed</span></div>
          <div className="kpi"><span className="v numeric">8:42</span><span className="u">pace · /mi</span></div>
          <div className="kpi"><span className="v numeric">152</span><span className="u">bpm</span></div>
        </div>

        {/* Pace visualization */}
        <div>
          <div className="label" style={{ marginBottom: 8 }}>Pace · last 6 min</div>
          <div className="pace-bar" />
        </div>

      </div>

      <div className="action-dock">
        <div className="partner-strip">
          <div className="avatar" style={{ width: 22, height: 22, fontSize: 10 }}>A</div>
          <span className="ex"><b>Andrea</b> · Stationary bike · 6:08 in</span>
          <button className="chat-pip" aria-label="Chat">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a8 8 0 0 1-11.5 7.2L4 21l1.8-5.5A8 8 0 1 1 21 12Z"/></svg>
          </button>
        </div>
        <button className="cta-primary cta-tall">
          <span>Finish run</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="6" y="6" width="12" height="12" rx="1.5"/></svg>
        </button>
        <div className="dock-actions">
          <button>Pause</button>
          <span className="sep">·</span>
          <button>Skip exercise</button>
          <span className="sep">·</span>
          <button className="danger">End session</button>
        </div>
      </div>
    </div>
  );
}

// ── C. Plan sheet (swipe-up) ───────────────────────────────
function PlanSheetOverlay() {
  // Underlying screen = strength view, sheet on top
  const yourPlan = [
    { name: 'Goblet squat',         meta: '4 × 8 · 25 lb',   status: 'done' },
    { name: 'Back squat',           meta: '4 × 6 · 195 lb',  status: 'curr' },
    { name: 'Romanian deadlift',    meta: '3 × 8 · 155 lb',  status: '' },
    { name: 'Walking lunge',        meta: '3 × 20',          status: '' },
    { name: 'Bulgarian split squat',meta: '3 × 10',          status: '' },
    { name: 'Calf raise',           meta: '4 × 12',          status: '' },
    { name: 'Hanging leg raise',    meta: '3 × 12',          status: '' },
    { name: 'Plank',                meta: '3 × 45s',         status: '' },
  ];
  const partnerPlan = [
    { name: 'Air squat',            meta: '3 × 12',          status: 'done' },
    { name: 'Goblet squat',         meta: '4 × 8 · 35 lb',   status: 'curr' },
    { name: 'Hip thrust',           meta: '3 × 10 · 95 lb',  status: '' },
    { name: 'Reverse lunge',        meta: '3 × 16',          status: '' },
    { name: 'Step-up',              meta: '3 × 12 · 20 lb',  status: '' },
    { name: 'Bridge',               meta: '3 × 15',          status: '' },
    { name: 'Dead bug',             meta: '3 × 12',          status: '' },
    { name: 'Side plank',           meta: '3 × 30s',         status: '' },
  ];
  return (
    <div className="app" style={{ position: 'relative' }}>
      {/* Faded backdrop simulating the active session below */}
      <div style={{
        position: 'absolute', inset: 0,
        background:
          'radial-gradient(120% 60% at 50% 30%, oklch(0.22 0.012 260) 0%, oklch(0.16 0.006 260) 70%)',
        pointerEvents: 'none'
      }}/>
      <ActiveTopBar elapsed="12:04" exNum={2} exTotal={8} />
      <div className="scroll" style={{ paddingTop: 110, paddingBottom: 30, opacity: 0.35, filter: 'blur(0.5px)' }}>
        <DualProgress you={28} partner={42} partnerEx="Goblet squat" partnerSet={3} partnerTotal={4} />
        <div className="rest-block">
          <div className="rest-label">Rest</div>
          <div className="rest-bar"><div className="rest-bar-fill" style={{ width: '47%' }}/></div>
          <div className="rest-time">0:42</div>
        </div>
      </div>

      <div className="sheet-backdrop" />
      <div className="sheet">
        <div className="sheet-handle" />
        <div style={{ padding: '0 18px 14px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div className="display" style={{ fontSize: 22 }}>Today's plan</div>
          <div className="label mono">45 min · 8 ex</div>
        </div>

        <div style={{ padding: '0 18px 8px', display: 'grid', gridTemplateColumns: '28px 1fr 1fr', gap: 12, alignItems: 'center' }}>
          <span className="label" style={{ textAlign: 'center' }}>#</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: 'var(--you)' }} />
            <span className="label" style={{ color: 'var(--you)' }}>You</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: 'var(--partner)' }} />
            <span className="label" style={{ color: 'var(--partner)' }}>Andrea</span>
          </div>
        </div>

        <div className="plan-list">
          {yourPlan.map((y, i) => {
            const s = partnerPlan[i];
            const yDim = y.status === '';
            const sDim = s.status === '';
            return (
              <div className="plan-row" key={i}>
                <span className="idx">{String(i + 1).padStart(2, '0')}</span>
                <div className={`cell you ${yDim ? 'dim' : ''}`}>
                  <span className={`status ${y.status}`} />
                  <div>
                    <div className="name">{y.name}</div>
                    <div className="meta">{y.meta}</div>
                  </div>
                </div>
                <div className={`cell par ${sDim ? 'dim' : ''}`}>
                  <span className={`status ${s.status}`} />
                  <div>
                    <div className="name">{s.name}</div>
                    <div className="meta">{s.meta}</div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ActiveStrengthBetweenSets, ActiveCardio, PlanSheetOverlay });
