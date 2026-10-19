function when(iso) {
  return new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
}

export default function Portal({ school, onRequest }) {
  const kid = school.students[0];
  const open = [
    {
      instructorId: 'jordan',
      start: `${school.today}T14:00:00`,
      end: `${school.today}T15:00:00`,
      meet: 'lot',
    },
    {
      instructorId: 'priya',
      start: `${school.today}T16:30:00`,
      end: `${school.today}T18:30:00`,
      meet: 'pickup',
    },
  ];

  return (
    <div className="portal">
      <div className="banner">Customer portal · /portal · sample</div>
      <header className="topbar">
        <div className="brand"><span className="ll">LL</span> LicenseLogger</div>
        <div className="school-chip">{school.school}</div>
        <div className="grow" />
        <a className="school-chip" href="/">Desk</a>
        <div className="you">ML</div>
      </header>
      <nav className="tabs">
        {['Home', 'Lessons', 'Hours', 'Billing', 'Messages'].map((t, i) => (
          <button key={t} className={`tab${i === 0 ? ' on' : ''}`}>{t}</button>
        ))}
      </nav>
      <main className="page">
        <div className="portal-grid">
          <section className="portal-hero">
            <div className="kicker" style={{ color: '#d4ff4a' }}>Your student</div>
            <h1>{kid.name}</h1>
            <p style={{ opacity: 0.85, fontWeight: 700, marginTop: 6 }}>
              {kid.hours} / {kid.goal} practice hours · test-ready {(kid.checklist || []).filter((c) => c.done).length}/{(kid.checklist || []).length || 7}
            </p>
          </section>
          <h3 style={{ fontWeight: 900 }}>Request a time</h3>
          {open.map((slot) => {
            const ins = school.instructors.find((i) => i.id === slot.instructorId);
            return (
              <button
                key={slot.start}
                className="slot-pick"
                onClick={() => onRequest({
                  studentId: kid.id,
                  instructorId: slot.instructorId,
                  start: slot.start,
                  end: slot.end,
                  meet: slot.meet,
                  note: 'Requested from portal',
                  travelAfter: 15,
                })}
              >
                <b>{when(slot.start)}–{when(slot.end)}</b>
                <div style={{ color: '#3d5346', marginTop: 4, fontWeight: 600 }}>
                  {ins?.name} · {slot.meet === 'lot' ? 'Green Light lot' : 'Pickup at home'}
                </div>
              </button>
            );
          })}
          {school.requests.filter((r) => r.studentId === kid.id).map((r) => (
            <div key={r.id} className="slot-pick" style={{ outline: '2px solid #ffd21f' }}>
              <b>Requested · {when(r.start)}</b>
              <div style={{ color: '#3d5346', marginTop: 4, fontWeight: 600 }}>Waiting on the school</div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
