// history.jsx — Reverse-chronological session list

function HistoryList() {
  const sessions = [
    { d: '14', m: 'May', ttl: 'Lower body & core',  duration: '45:08', ex: 5,  prs: 2, type: 'strength' },
    { d: '12', m: 'May', ttl: 'Push day',           duration: '42:11', ex: 6,  prs: 0, type: 'strength' },
    { d: '10', m: 'May', ttl: 'Easy run · together', duration: '32:00', ex: 1,  prs: 0, type: 'cardio' },
    { d: '08', m: 'May', ttl: 'Pull + accessories', duration: '48:33', ex: 7,  prs: 1, type: 'strength' },
    { d: '06', m: 'May', ttl: 'Lower body',         duration: '50:02', ex: 6,  prs: 0, type: 'strength' },
    { d: '03', m: 'May', ttl: 'Conditioning',       duration: '28:14', ex: 4,  prs: 0, type: 'cardio' },
    { d: '02', m: 'May', ttl: 'Upper body · light', duration: '36:40', ex: 5,  prs: 0, type: 'strength' },
    { d: '28', m: 'Apr', ttl: 'Full body',          duration: '52:17', ex: 8,  prs: 3, type: 'strength' },
  ];
  // Group by week
  return (
    <div className="app">
      {/* Top header */}
      <div className="topbar" style={{ top: 66 }}>
        <span className="overline" style={{ color: 'var(--fg)' }}>History</span>
        <div className="iconbtn" style={{ width: 34, height: 34 }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 6h16M7 12h10M10 18h4"/>
          </svg>
        </div>
      </div>

      <div className="scroll" style={{ paddingTop: 110, paddingBottom: 110, gap: 16 }}>

        {/* Quick stat */}
        <div className="card" style={{ display: 'flex', alignItems: 'baseline', gap: 18 }}>
          <div className="kpi">
            <span className="v">23</span>
            <span className="u">Sessions · all time</span>
          </div>
          <div style={{ width: 1, height: 30, background: 'var(--hairline)' }}/>
          <div className="kpi">
            <span className="v">18h 22m</span>
            <span className="u">Together</span>
          </div>
        </div>

        {/* Filters */}
        <div className="filter-row">
          <span className="filter-pill on">All</span>
          <span className="filter-pill">★ PR only</span>
          <span className="filter-pill">Strength</span>
          <span className="filter-pill">Cardio</span>
          <span className="filter-pill">This month</span>
        </div>

        {/* Week header — this week */}
        <div className="set-section-head" style={{ paddingTop: 4 }}>
          <span className="ttl">This week</span>
          <span className="meta">3 sessions · 1 PR</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {sessions.slice(0, 3).map((s, i) => (
            <div key={i} className="hist-row">
              <div className="date">
                <span className="d">{s.d}</span>
                <span className="m">{s.m}</span>
              </div>
              <div className="body">
                <span className="ttl">{s.ttl}</span>
                <div className="meta">
                  <span>{s.duration}</span>
                  <span style={{ color: 'var(--fg-faint)' }}>·</span>
                  <span>{s.ex} ex</span>
                  <span style={{ color: 'var(--fg-faint)' }}>·</span>
                  <span style={{ color: 'var(--you)' }}>You + Andrea</span>
                </div>
              </div>
              <div className="right">
                {s.prs > 0 && <span className="pr-pill">★ {s.prs}</span>}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fg-faint)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>
              </div>
            </div>
          ))}
        </div>

        {/* Week header — last week */}
        <div className="set-section-head" style={{ paddingTop: 4 }}>
          <span className="ttl">Last week</span>
          <span className="meta">3 sessions · 1 PR</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {sessions.slice(3, 6).map((s, i) => (
            <div key={i} className="hist-row">
              <div className="date">
                <span className="d">{s.d}</span>
                <span className="m">{s.m}</span>
              </div>
              <div className="body">
                <span className="ttl">{s.ttl}</span>
                <div className="meta">
                  <span>{s.duration}</span>
                  <span style={{ color: 'var(--fg-faint)' }}>·</span>
                  <span>{s.ex} ex</span>
                </div>
              </div>
              <div className="right">
                {s.prs > 0 && <span className="pr-pill">★ {s.prs}</span>}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fg-faint)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>
              </div>
            </div>
          ))}
        </div>

        {/* April */}
        <div className="set-section-head" style={{ paddingTop: 4 }}>
          <span className="ttl">April</span>
          <span className="meta">12 sessions · 4 PRs</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {sessions.slice(6).map((s, i) => (
            <div key={i} className="hist-row">
              <div className="date">
                <span className="d">{s.d}</span>
                <span className="m">{s.m}</span>
              </div>
              <div className="body">
                <span className="ttl">{s.ttl}</span>
                <div className="meta">
                  <span>{s.duration}</span>
                  <span style={{ color: 'var(--fg-faint)' }}>·</span>
                  <span>{s.ex} ex</span>
                </div>
              </div>
              <div className="right">
                {s.prs > 0 && <span className="pr-pill">★ {s.prs}</span>}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fg-faint)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>
              </div>
            </div>
          ))}
        </div>

      </div>

      {/* Tab bar — History active */}
      <div className="tabbar">
        <div className="tabbar-item">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3.2"/><circle cx="12" cy="12" r="8.5"/></svg>
          <span>Today</span>
        </div>
        <div className="tabbar-item active">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M4 7h16M4 12h16M4 17h10"/></svg>
          <span>History</span>
        </div>
        <div className="tabbar-item">
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

Object.assign(window, { HistoryList });
