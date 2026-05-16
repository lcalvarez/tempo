// goals.jsx — Goals questionnaire (4 screens of swipe-through flow)
// Editing goals re-triggers AI planning per the brief.

function GoalsDots({ step, total = 4 }) {
  return (
    <div className="ob-dots">
      {Array.from({ length: total }).map((_, i) => (
        <span key={i} className={i < step ? 'on' : ''} />
      ))}
    </div>
  );
}

function GoalsBackTopBar({ step, total }) {
  return (
    <div className="active-topbar" style={{ top: 60 }}>
      <button className="exit-btn" aria-label="Back">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M15 6l-6 6 6 6"/>
        </svg>
      </button>
      <span className="overline mono">{step} of {total}</span>
      <button className="adjust-link" style={{ padding: 0 }}>Skip</button>
    </div>
  );
}

// ── 1. Primary focus ────────────────────────────────────────
function GoalsFocus() {
  const focuses = [
    { ttl: 'Strength',    sub: 'Heavier · fewer reps',      key: 's', on: true },
    { ttl: 'Hypertrophy', sub: 'Build muscle · 8–12 reps',  key: 'h', on: true },
    { ttl: 'Endurance',   sub: 'Conditioning · capacity',   key: 'e' },
    { ttl: 'Weight loss', sub: 'Calorie deficit, retain',   key: 'w' },
    { ttl: 'Mobility',    sub: 'Range · injury-proofing',   key: 'm' },
    { ttl: 'General',     sub: 'Just stay healthy',         key: 'g' },
  ];
  return (
    <div className="ob-screen">
      <GoalsDots step={1} />
      <GoalsBackTopBar step={1} total={4} />

      <div className="ob-head" style={{ paddingTop: 116 }}>
        <div className="step">Goals · 1 of 4</div>
        <div className="ob-title">What are you<br/>training for?</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>Pick up to 2 — the AI will balance them.</div>
      </div>

      <div className="ob-body">
        <div className="answer-grid">
          {focuses.map(f => (
            <button key={f.key} className={`answer-card ${f.on ? 'on' : ''}`}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div className="sub">{f.sub}</div>
                {f.on && (
                  <svg className="icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M5 13l4 4L19 7"/>
                  </svg>
                )}
              </div>
              <div className="ttl">{f.ttl}</div>
            </button>
          ))}
        </div>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Continue</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
      </div>
    </div>
  );
}

// ── 2. Frequency (slider) ──────────────────────────────────
function GoalsFrequency() {
  return (
    <div className="ob-screen">
      <GoalsDots step={2} />
      <GoalsBackTopBar step={2} total={4} />

      <div className="ob-head" style={{ paddingTop: 116 }}>
        <div className="step">Goals · 2 of 4</div>
        <div className="ob-title">How many days<br/>per week?</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>Be honest. The AI plans around what you'll actually do.</div>
      </div>

      <div className="ob-body">
        <div className="slider-block">
          <div className="v">4</div>
          <div className="unit">days per week</div>
          <div className="slider-track">
            <div className="rail" />
            <div className="fill" style={{ left: 0, width: '50%' }} />
            <div className="thumb" style={{ left: '50%' }} />
          </div>
          <div className="slider-ticks">
            <span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6</span><span>7</span>
          </div>
        </div>

        {/* Mini week visualization */}
        <div>
          <div className="label" style={{ marginBottom: 10 }}>Likely week</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 6 }}>
            {['M','T','W','T','F','S','S'].map((d, i) => (
              <div key={i} style={{
                aspectRatio: '1', borderRadius: 8,
                background: [0,2,4,5].includes(i) ? 'var(--accent-dim)' : 'var(--bg-elev-2)',
                border: '1px solid ' + ([0,2,4,5].includes(i) ? 'oklch(0.84 0.19 142 / 0.45)' : 'var(--hairline)'),
                display: 'grid', placeItems: 'center',
                fontFamily: 'var(--ff-mono)', fontSize: 11,
                color: [0,2,4,5].includes(i) ? 'var(--accent)' : 'var(--fg-faint)',
              }}>{d}</div>
            ))}
          </div>
          <div className="label" style={{ marginTop: 10, color: 'var(--fg-faint)' }}>AI will pick the exact days based on your typical schedule</div>
        </div>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Continue</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
      </div>
    </div>
  );
}

// ── 3. Intensity ─────────────────────────────────────────
function GoalsIntensity() {
  const ints = [
    { ttl: 'Easy',     sub: 'Light · sustainable' },
    { ttl: 'Moderate', sub: 'Solid effort',  on: true },
    { ttl: 'Hard',     sub: 'Pushing limits' },
    { ttl: 'Brutal',   sub: 'No survivors' },
  ];
  return (
    <div className="ob-screen">
      <GoalsDots step={3} />
      <GoalsBackTopBar step={3} total={4} />

      <div className="ob-head" style={{ paddingTop: 116 }}>
        <div className="step">Goals · 3 of 4</div>
        <div className="ob-title">How hard<br/>do you want it?</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>This sets the difficulty curve — you can change it anytime.</div>
      </div>

      <div className="ob-body">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {ints.map(i => (
            <button key={i.ttl} className={`answer-card ${i.on ? 'on' : ''}`} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 64, gap: 14, padding: '14px 16px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, textAlign: 'left' }}>
                <div className="ttl">{i.ttl}</div>
                <div className="sub">{i.sub}</div>
              </div>
              {i.on && (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10" stroke="var(--accent)" strokeWidth="2"/>
                  <path d="M8 12l3 3 5-6"/>
                </svg>
              )}
            </button>
          ))}
        </div>

        <div className="label" style={{ color: 'var(--fg-faint)', textAlign: 'center', marginTop: 6 }}>
          The AI dials this up or down based on how you log RPE
        </div>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Continue</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
      </div>
    </div>
  );
}

// ── 4. Styles (enjoy / avoid) ───────────────────────────
function GoalsStyles() {
  const enjoy = ['Free weights', 'Conditioning', 'HIIT', 'Bodyweight'];
  const avoid = ['Long cardio', 'Burpees'];
  const all = ['Free weights', 'Machines', 'Conditioning', 'HIIT', 'Bodyweight', 'Long cardio', 'Cycling', 'Rowing', 'Yoga', 'Mobility', 'Burpees', 'Box jumps'];
  return (
    <div className="ob-screen">
      <GoalsDots step={4} />
      <GoalsBackTopBar step={4} total={4} />

      <div className="ob-head" style={{ paddingTop: 116 }}>
        <div className="step">Goals · 4 of 4</div>
        <div className="ob-title">What do you<br/>love and hate?</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>Tap once for ❤️, again for 🚫.</div>
      </div>

      <div className="ob-body">
        <div className="label" style={{ marginBottom: 6 }}>You like</div>
        <div className="chips">
          {enjoy.map(s => (
            <span key={s} className="chip-pill on" style={{ background: 'var(--accent-dim)', borderColor: 'oklch(0.84 0.19 142 / 0.45)', color: 'var(--accent)' }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 21s-7-4.5-9.5-9C0.5 8 3 4 7 4c2 0 3.5 1 5 3 1.5-2 3-3 5-3 4 0 6.5 4 4.5 8C19 16.5 12 21 12 21z"/></svg>
              {s}
            </span>
          ))}
        </div>

        <div className="label" style={{ marginTop: 12, marginBottom: 6 }}>You'd rather skip</div>
        <div className="chips">
          {avoid.map(s => (
            <span key={s} className="chip-pill" style={{ background: 'oklch(0.55 0.20 25 / 0.16)', borderColor: 'oklch(0.55 0.20 25 / 0.35)', color: 'oklch(0.78 0.14 25)' }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
                <circle cx="12" cy="12" r="9.5"/><path d="M6 6l12 12"/>
              </svg>
              {s}
            </span>
          ))}
        </div>

        <div className="label" style={{ marginTop: 16, marginBottom: 6 }}>Everything else</div>
        <div className="chips">
          {all.filter(a => !enjoy.includes(a) && !avoid.includes(a)).map(s => (
            <span key={s} className="chip-pill">{s}</span>
          ))}
        </div>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Generate first plan</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/></svg>
        </button>
      </div>
    </div>
  );
}

Object.assign(window, { GoalsFocus, GoalsFrequency, GoalsIntensity, GoalsStyles });
