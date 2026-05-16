// onboarding.jsx — first-run flow + partner pairing
// Screens:
//   1. Welcome / value prop
//   2. Sign in (Apple primary + email)
//   3. Selfie / photo (OPTIONAL — can skip)
//   4. About you (single-screen profile)
//   5. Partner pairing · choice
//   6. Partner pairing · pending (invite code)
//   7. We're ready

function Dots({ step, total = 7 }) {
  return (
    <div className="ob-dots">
      {Array.from({ length: total }).map((_, i) => (
        <span key={i} className={i < step ? 'on' : ''} />
      ))}
    </div>
  );
}

function BrandMark() {
  return (
    <div className="brand-mark">
      <div className="glyph">
        <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
          <circle cx="10" cy="14" r="7" stroke="var(--you)" strokeWidth="2.4" />
          <circle cx="18" cy="14" r="7" stroke="var(--partner)" strokeWidth="2.4" />
        </svg>
      </div>
      <span className="name">Tempo</span>
    </div>
  );
}

// ── 1. Welcome ──────────────────────────────────────────────
function OBWelcome() {
  return (
    <div className="ob-screen">
      <div style={{ padding: '60px 24px 0' }}>
        <BrandMark />
      </div>

      <div className="welcome-mark">
        <div className="overline">Couples fitness · in rhythm</div>
        <div style={{ fontFamily: 'var(--ff-sans)', fontWeight: 600, fontSize: 44, lineHeight: 1.0, letterSpacing: '-0.03em', marginTop: 6, marginBottom: 14 }}>
          Train together.<br/>
          <span style={{ color: 'var(--fg-mute)' }}>In tempo.</span>
        </div>

        <div className="welcome-bars">
          <div className="bar you" />
          <div className="bar par" />
        </div>

        <p className="ob-sub" style={{ margin: 0 }}>
          Two people, one timeline.
          Different workouts paced to the same rhythm —
          so you start, sweat, and finish in sync.
        </p>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Get started</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
        <button className="adjust-link" style={{ color: 'var(--fg-mute)' }}>I already have an account</button>
      </div>
    </div>
  );
}

// ── 2. Sign in ──────────────────────────────────────────────
function OBSignIn() {
  return (
    <div className="ob-screen">
      <Dots step={1} />
      <div className="ob-head" style={{ paddingTop: 100 }}>
        <div className="step">Step 1 of 5</div>
        <div className="ob-title">Sign in to<br/>get started</div>
      </div>
      <div className="ob-body" style={{ justifyContent: 'flex-end' }}>
        <div style={{ flex: 1 }} />
        <button className="btn-apple">
          <svg width="17" height="20" viewBox="0 0 24 28" fill="currentColor">
            <path d="M19.7 21.4c-1 1.4-2 2.8-3.6 2.8-1.6 0-2-1-3.9-1s-2.4 1-3.8 1c-1.6 0-2.7-1.6-3.7-3-2-3-3.5-8.4-1.5-12.1.9-1.8 2.7-3 4.5-3 1.5 0 2.9 1 3.9 1 .9 0 2.6-1.2 4.4-1 .7 0 2.9.3 4.3 2.4-.1.1-2.5 1.5-2.5 4.4 0 3.5 3 4.7 3 4.7-.1.2-.5 1.6-1.6 3.8zM14 4.6c.8-1 1.4-2.4 1.3-3.8-1.2.1-2.6.9-3.5 1.9-.8.9-1.5 2.3-1.3 3.6 1.3.1 2.7-.7 3.5-1.7z"/>
          </svg>
          <span>Continue with Apple</span>
        </button>
        <div className="divider-or">or</div>
        <button className="btn-ghost">Continue with email</button>
        <p style={{ textAlign: 'center', color: 'var(--fg-faint)', fontSize: 12, lineHeight: 1.5, margin: '14px 24px 0' }}>
          By continuing, you agree to our <span style={{ color: 'var(--fg-mute)', textDecoration: 'underline' }}>Terms</span> and <span style={{ color: 'var(--fg-mute)', textDecoration: 'underline' }}>Privacy Policy</span>.
        </p>
      </div>
    </div>
  );
}

// ── 3. Selfie · optional ────────────────────────────────────
function OBSelfie() {
  const alts = [
    { letter: 'A', bg: 'oklch(0.78 0.09 230 / 0.22)', fg: 'var(--you)',     on: true },
    { letter: 'A', bg: 'oklch(0.82 0.09 78 / 0.22)',  fg: 'var(--partner)' },
    { letter: 'A', bg: 'oklch(0.84 0.19 142 / 0.18)', fg: 'var(--accent)' },
    { letter: 'A', bg: 'oklch(0.74 0.10 320 / 0.22)', fg: 'oklch(0.82 0.10 320)' },
    { letter: 'A', bg: 'oklch(0.78 0.10 12 / 0.22)',  fg: 'oklch(0.82 0.10 12)' },
    { letter: 'A', bg: 'oklch(0.30 0.012 260)',       fg: 'var(--fg)' },
  ];
  return (
    <div className="ob-screen">
      <Dots step={2} />
      <div className="ob-head" style={{ paddingTop: 100 }}>
        <div className="step" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span>Step 2 of 5 · Photo</span>
          <span style={{
            fontFamily: 'var(--ff-mono)', fontSize: 9.5, padding: '2px 6px',
            background: 'var(--bg-elev-2)', color: 'var(--fg-mute)',
            borderRadius: 999, letterSpacing: 0.12
          }}>OPTIONAL</span>
        </div>
        <div className="ob-title">Pick a photo<br/>(or skip).</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>
          So Andrea can see who she's pairing with. You can change it anytime.
        </div>
      </div>

      <div className="ob-body" style={{ alignItems: 'center', gap: 22 }}>
        {/* Big photo target */}
        <div style={{
          width: 168, height: 168, borderRadius: 999,
          background: 'var(--bg-elev-1)',
          border: '1.5px dashed var(--border)',
          display: 'grid', placeItems: 'center',
          color: 'var(--fg-soft)', position: 'relative'
        }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 8h3l1.5-2h5L16 8h3a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2Z"/>
              <circle cx="12" cy="13" r="3.5"/>
            </svg>
            <span className="label" style={{ color: 'var(--fg-mute)' }}>Tap to add</span>
          </div>
        </div>

        {/* Two action buttons */}
        <div style={{ width: '100%', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <button className="cta-secondary" style={{ height: 48 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 8h3l1.5-2h5L16 8h3a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2Z"/>
              <circle cx="12" cy="13" r="3.5"/>
            </svg>
            Take selfie
          </button>
          <button className="cta-secondary" style={{ height: 48 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="5" width="18" height="14" rx="2"/>
              <circle cx="9" cy="11" r="2"/>
              <path d="M3 17l5-4 4 3 3-2 6 5"/>
            </svg>
            Choose from library
          </button>
        </div>

        {/* Or pick a colored monogram */}
        <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 12, marginTop: 6 }}>
          <div className="label" style={{ textAlign: 'center', color: 'var(--fg-soft)' }}>Or pick a monogram</div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'center' }}>
            {alts.map((a, i) => (
              <div key={i} style={{
                width: 44, height: 44, borderRadius: 999,
                background: a.bg, color: a.fg,
                display: 'grid', placeItems: 'center',
                fontFamily: 'var(--ff-sans)', fontWeight: 600, fontSize: 17,
                border: a.on ? '2px solid var(--accent)' : '1px solid var(--hairline)',
                boxShadow: a.on ? '0 0 0 3px var(--accent-dim)' : 'none'
              }}>{a.letter}</div>
            ))}
          </div>
        </div>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Continue</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
        <button className="adjust-link" style={{ color: 'var(--fg-mute)' }}>Skip — I'll add a photo later</button>
      </div>
    </div>
  );
}

// ── 4. About you ────────────────────────────────────────────
function OBProfile() {
  return (
    <div className="ob-screen">
      <Dots step={3} />
      <div className="ob-head" style={{ paddingTop: 100 }}>
        <div className="step">Step 3 of 5 · About you</div>
        <div className="ob-title">A few things<br/>about you.</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>So the AI can plan workouts that fit.</div>
      </div>

      <div className="ob-body">
        <div className="field">
          <div className="field-label">Name</div>
          <div className="field-input filled">Alex<div className="caret" /></div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="field">
            <div className="field-label">Age</div>
            <div className="field-input filled">32</div>
          </div>
          <div className="field">
            <div className="field-label">Units</div>
            <div className="segmented">
              <button className="on">lbs · mi</button>
              <button>kg · km</button>
            </div>
          </div>
        </div>

        <div className="field">
          <div className="field-label">Fitness level</div>
          <div className="segmented">
            <button>New</button>
            <button className="on">Some</button>
            <button>Strong</button>
            <button>Advanced</button>
          </div>
        </div>

        <div className="field">
          <div className="field-label">Equipment</div>
          <div className="chips">
            <span className="chip-pill on">Full gym</span>
            <span className="chip-pill">Home rack</span>
            <span className="chip-pill">Dumbbells</span>
            <span className="chip-pill">Bands</span>
            <span className="chip-pill">Bodyweight only</span>
          </div>
        </div>

        <div className="field">
          <div className="field-label">Usual workout times</div>
          <div className="chips">
            <span className="chip-pill">Early morning</span>
            <span className="chip-pill on">Morning</span>
            <span className="chip-pill">Midday</span>
            <span className="chip-pill on">Evening</span>
            <span className="chip-pill">Late</span>
          </div>
        </div>

        <div className="field">
          <div className="field-label">Injuries / limitations (optional)</div>
          <div className="field-input" style={{ height: 64, alignItems: 'flex-start', paddingTop: 14 }}>
            <span className="placeholder">e.g. lower back, right knee</span>
          </div>
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

// ── 4. Partner pairing · choice ─────────────────────────────
function OBPairChoice() {
  return (
    <div className="ob-screen">
      <Dots step={4} />
      <div className="ob-head" style={{ paddingTop: 100 }}>
        <div className="step">Step 4 of 5 · Pair up</div>
        <div className="ob-title">Connect with<br/>your partner.</div>
        <div className="ob-sub" style={{ marginTop: 4 }}>You'll train in sync. They get a personalized plan too.</div>
      </div>

      <div className="ob-body" style={{ gap: 14 }}>
        {/* Option A: send an invite */}
        <button style={{
          display: 'flex', flexDirection: 'column', gap: 12,
          padding: 22, borderRadius: 'var(--r-lg)',
          background: 'var(--bg-elev-1)', border: '1px solid var(--accent-dim)',
          textAlign: 'left', cursor: 'pointer', color: 'var(--fg)', fontFamily: 'inherit'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span className="label" style={{ color: 'var(--accent)' }}>Recommended</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
          </div>
          <div className="display" style={{ fontSize: 22 }}>Send your partner an invite</div>
          <div className="ob-sub" style={{ fontSize: 13 }}>We'll generate a code you can text them. They sign up and you're connected.</div>
        </button>

        {/* Option B: enter a code */}
        <button style={{
          display: 'flex', flexDirection: 'column', gap: 12,
          padding: 22, borderRadius: 'var(--r-lg)',
          background: 'var(--bg-elev-1)', border: '1px solid var(--hairline)',
          textAlign: 'left', cursor: 'pointer', color: 'var(--fg)', fontFamily: 'inherit'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span className="label">If they invited you</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fg-mute)" strokeWidth="2" strokeLinecap="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
          </div>
          <div className="display" style={{ fontSize: 22 }}>Enter their code</div>
          <div className="ob-sub" style={{ fontSize: 13 }}>Got a 6-letter code from your partner? Enter it to connect.</div>
        </button>

        <div style={{ flex: 1 }} />

        <button className="adjust-link" style={{ color: 'var(--fg-soft)' }}>Pair later — let me look around first</button>
      </div>
    </div>
  );
}

// ── 5. Pending ──────────────────────────────────────────────
function OBPending() {
  return (
    <div className="ob-screen">
      <Dots step={5} />
      <div className="ob-head" style={{ paddingTop: 100 }}>
        <div className="step">Step 5 of 5 · Almost there</div>
        <div className="ob-title">Send this code<br/>to your partner.</div>
      </div>

      <div className="ob-body" style={{ alignItems: 'stretch' }}>
        {/* Big code display */}
        <div style={{ background: 'var(--bg-elev-1)', border: '1px solid var(--hairline)', borderRadius: 'var(--r-lg)', padding: '4px 8px 14px' }}>
          <div className="code-display">
            <div className="digit">A</div>
            <div className="digit">X</div>
            <div className="digit">7</div>
            <span className="sep">—</span>
            <div className="digit">K</div>
            <div className="digit">9</div>
            <div className="digit">P</div>
          </div>
          <div style={{ textAlign: 'center' }}>
            <span className="label">Expires in 24 hours</span>
          </div>
        </div>

        {/* Status row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 0' }}>
          <div className="pulse-avatar">?</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <div className="overline" style={{ color: 'var(--fg)' }}>Waiting for your partner</div>
            <div className="ob-sub" style={{ fontSize: 13 }}>You'll get a notification when they accept.</div>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <button className="cta-secondary" style={{ height: 50 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/></svg>
            Copy
          </button>
          <button className="cta-secondary" style={{ height: 50 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/></svg>
            Share
          </button>
        </div>

        <div style={{ flex: 1 }} />
      </div>

      <div className="ob-foot">
        <button className="adjust-link" style={{ color: 'var(--fg-soft)' }}>I'll do this later</button>
      </div>
    </div>
  );
}

// ── 6. We're ready ──────────────────────────────────────────
function OBReady() {
  return (
    <div className="ob-screen">
      <Dots step={7} />

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 24px', gap: 24 }}>
        <div className="pair-row">
          <div className="pair-avatar you">A</div>
          <div className="pair-link" />
          <div className="pair-avatar par">A</div>
        </div>

        <div style={{ textAlign: 'center' }}>
          <div className="overline" style={{ color: 'var(--accent)' }}>Paired</div>
          <div style={{ fontFamily: 'var(--ff-sans)', fontWeight: 600, fontSize: 32, lineHeight: 1.05, letterSpacing: '-0.025em', marginTop: 8 }}>
            You and Andrea<br/>
            <span style={{ color: 'var(--fg-mute)' }}>are ready.</span>
          </div>
          <p className="ob-sub" style={{ marginTop: 14 }}>
            Next: a quick goals questionnaire so we can plan your first session together.
          </p>
        </div>

        {/* Tiny stat row */}
        <div style={{
          display: 'flex', justifyContent: 'center', gap: 24,
          padding: '14px 0', borderTop: '1px solid var(--hairline)', borderBottom: '1px solid var(--hairline)'
        }}>
          <div style={{ textAlign: 'center' }}>
            <div className="display numeric" style={{ fontSize: 22 }}>2</div>
            <div className="label" style={{ marginTop: 2 }}>Profiles</div>
          </div>
          <div style={{ width: 1, background: 'var(--hairline)' }} />
          <div style={{ textAlign: 'center' }}>
            <div className="display numeric" style={{ fontSize: 22 }}>0</div>
            <div className="label" style={{ marginTop: 2 }}>Sessions</div>
          </div>
          <div style={{ width: 1, background: 'var(--hairline)' }} />
          <div style={{ textAlign: 'center' }}>
            <div className="display" style={{ fontSize: 22 }}>∞</div>
            <div className="label" style={{ marginTop: 2 }}>Together</div>
          </div>
        </div>
      </div>

      <div className="ob-foot">
        <button className="cta-primary cta-tall">
          <span>Set your goals</span>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </button>
      </div>
    </div>
  );
}

Object.assign(window, {
  OBWelcome, OBSignIn, OBSelfie, OBProfile, OBPairChoice, OBPending, OBReady
});
