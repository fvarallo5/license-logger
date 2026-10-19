import { useMemo, useState } from 'react';

const SEATS = ['active', 'waitlist', 'graduated', 'inactive'];

function readyOf(student) {
  const done = (student.checklist || []).filter((c) => c.done).length;
  const total = (student.checklist || []).length || 7;
  return { done, total, label: `${done}/${total}` };
}

function qty(n) {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}

function when(iso) {
  return new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
}

function nextFor(school, studentId) {
  const now = school.clock ? new Date(school.clock) : new Date();
  return [...school.lessons, ...school.requests]
    .filter((x) => x.studentId === studentId && x.status !== 'taught' && x.kind !== 'blocked')
    .filter((x) => new Date(x.end) > now)
    .sort((a, b) => a.start.localeCompare(b.start))[0];
}

function rowModel(school, student) {
  const next = nextFor(school, student.id);
  const ins = school.instructors.find((i) => i.id === student.instructorId);
  const ready = readyOf(student);
  const needsLesson = student.seat === 'active' && !next;
  const hasRequest = school.requests.some((r) => r.studentId === student.id);
  const packageLow = student.packageLeft <= 1;
  const testReady = ready.done >= 6;
  const hold = student.holdDays > 0;
  const due = student.balance > 0;
  const stale = student.seat === 'inactive' || (student.lastDrive != null && student.lastDrive >= 14);
  let flag = 'green';
  if (due || (!student.permitOn && student.seat === 'active')) flag = 'red';
  else if (hold || packageLow || needsLesson || stale) flag = 'yellow';
  let status = 'On track';
  if (due) status = 'Balance due';
  else if (hold) status = 'Permit hold';
  else if (testReady) status = 'Ready';
  else if (hasRequest) status = 'Requested';
  else if (next && new Date(next.start) <= (school.clock ? new Date(school.clock) : new Date()) && new Date(next.end) > (school.clock ? new Date(school.clock) : new Date())) status = 'In lesson';
  else if (next) status = 'Booked';
  else if (needsLesson) status = 'Needs lesson';
  else if (student.seat === 'waitlist') status = 'Waitlist';
  return {
    student,
    next,
    ins,
    ready,
    needsLesson,
    hasRequest,
    packageLow,
    testReady,
    hold,
    due,
    stale,
    flag,
    status,
  };
}

const FILTERS = [
  { id: 'needs', label: 'Needs a lesson', pick: (r) => r.needsLesson },
  { id: 'requests', label: 'Requests', pick: (r) => r.hasRequest },
  { id: 'package', label: 'Package low', pick: (r) => r.packageLow },
  { id: 'ready', label: 'Test-ready', pick: (r) => r.testReady },
  { id: 'hold', label: 'Permit hold', pick: (r) => r.hold },
  { id: 'due', label: 'Balance due', pick: (r) => r.due },
];

export default function Students({ school, onAdd }) {
  const [q, setQ] = useState('');
  const [seat, setSeat] = useState('active');
  const [filter, setFilter] = useState('');
  const [open, setOpen] = useState(() => new URLSearchParams(window.location.search).get('student'));
  const [adding, setAdding] = useState(false);

  const rows = useMemo(
    () => school.students.map((s) => rowModel(school, s)),
    [school],
  );

  const visible = rows.filter((r) => {
    if (seat && r.student.seat !== seat) return false;
    if (filter && !FILTERS.find((f) => f.id === filter)?.pick(r)) return false;
    if (q.trim()) {
      const blob = `${r.student.name} ${r.student.parent} ${r.ins?.name || ''}`.toLowerCase();
      if (!blob.includes(q.trim().toLowerCase())) return false;
    }
    return true;
  });

  const opened = rows.find((r) => r.student.id === open);

  return (
    <div className="students-page">
      <div className="stu-toolbar">
        <input
          className="stu-search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search students, parents, instructors"
        />
        <div className="seat-chips">
          {SEATS.map((s) => (
            <button
              key={s}
              className={`seat-chip${seat === s ? ' on' : ''}`}
              onClick={() => setSeat(s)}
            >
              {s}
              <em>{rows.filter((r) => r.student.seat === s).length}</em>
            </button>
          ))}
        </div>
        <button className="btn btn-lime" onClick={() => setAdding(true)}>Add student</button>
      </div>

      <div className="stu-pulse">
        {FILTERS.map((f) => {
          const n = rows.filter((r) => r.student.seat === 'active' && f.pick(r)).length;
          return (
            <button
              key={f.id}
              className={`stu-pulse-card${filter === f.id ? ' on' : ''}${n && (f.id === 'due' || f.id === 'hold') ? ' hot' : ''}${n && f.id === 'ready' ? ' go' : ''}`}
              onClick={() => setFilter((cur) => (cur === f.id ? '' : f.id))}
            >
              <div className="kicker">{f.label}</div>
              <b>{n}</b>
            </button>
          );
        })}
      </div>

      <div className="stu-list plate">
        <div className="stu-head">
          <span>Student</span>
          <span>Instructor</span>
          <span>Next lesson</span>
          <span>Practice / night</span>
          <span>Package</span>
          <span>Ready</span>
          <span>Balance</span>
          <span>Status</span>
        </div>
        {visible.length === 0 && (
          <div className="inbox-empty">
            <b>No students in this view</b>
            <p>Clear the filter or add a student to the roster.</p>
          </div>
        )}
        {visible.map((r) => (
          <button type="button" className={`stu-row flag-${r.flag}`} key={r.student.id} onClick={() => setOpen(r.student.id)}>
            <div className="stu-name">
              <b>{r.student.name}</b>
              <small>{r.student.age} · {r.student.state} · {r.student.parent}</small>
            </div>
            <div className="stu-ins">
              {r.ins ? (
                <>
                  <span className="avatar sm" style={{ background: r.ins.color }}>{r.ins.name.split(' ').map((p) => p[0]).join('')}</span>
                  {r.ins.name.split(' ')[0]}
                </>
              ) : <span className="muted">Unassigned</span>}
            </div>
            <div className="stu-next">
              {r.next ? (
                <>
                  <b>{when(r.next.start)}</b>
                  <small>{r.next.meet === 'pickup' ? 'pickup' : 'lot'}</small>
                </>
              ) : <span className="muted">None</span>}
            </div>
            <div className="stu-bars">
              <Bar value={r.student.hours} max={r.student.goal} label={`${qty(r.student.hours)}/${r.student.goal} h`} tone="green" />
              <Bar value={r.student.night} max={r.student.nightGoal} label={`${qty(r.student.night)} night`} tone="yellow" />
            </div>
            <div className="stu-pkg">
              <b>{r.student.packageLeft}h left</b>
              <small>{r.student.schoolHours}/{r.student.packageHours} school</small>
            </div>
            <div className="stu-ready"><span className={`frac${r.ready.done >= 6 ? ' go' : ''}`}>{r.ready.label}</span></div>
            <div className="stu-bal">
              {r.student.balance > 0
                ? <span className="bal due">${r.student.balance}</span>
                : <span className="bal ok">Paid</span>}
            </div>
            <div className="stu-status"><span className={`tag ${statusClass(r.status)}`}>{r.status}</span></div>
          </button>
        ))}
      </div>

      {opened && (
        <Dossier row={opened} school={school} onClose={() => setOpen(null)} />
      )}
      {adding && (
        <AddSheet
          instructors={school.instructors}
          onClose={() => setAdding(false)}
          onSave={(payload) => {
            onAdd(payload);
            setAdding(false);
            setSeat('active');
          }}
        />
      )}
    </div>
  );
}

function statusClass(status) {
  if (status === 'Balance due' || status === 'Permit hold') return 'block';
  if (status === 'Ready' || status === 'In lesson') return 'taught';
  if (status === 'Requested') return 'requested';
  if (status === 'Booked') return 'booked';
  if (status === 'On track') return 'taught';
  return 'block';
}

function Bar({ value, max, label, tone }) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  return (
    <div className="hbar">
      <i className={tone} style={{ width: `${pct}%` }} />
      <span>{label}</span>
    </div>
  );
}

function Dossier({ row, school, onClose }) {
  const s = row.student;
  const history = [...school.lessons, ...school.requests]
    .filter((x) => x.studentId === s.id)
    .sort((a, b) => b.start.localeCompare(a.start));

  return (
    <div className="sheet" onClick={onClose}>
      <div className="sheet-card dossier" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-head">
          <div>
            <h3>{s.name}</h3>
            <p className="dossier-sub">{s.age} · {s.state} · {s.parent} · {s.phone}</p>
          </div>
          <button className="sheet-x" onClick={onClose} type="button">×</button>
        </div>
        <div className="dossier-flags">
          <span className={`tag ${statusClass(row.status)}`}>{row.status}</span>
          <span className={`frac${row.ready.done >= 6 ? ' go' : ''}`}>{row.ready.label} ready</span>
          {s.holdDays > 0 && <span className="tag block">{s.holdDays}d hold</span>}
          {s.balance > 0 && <span className="bal due">${s.balance} due</span>}
        </div>
        <div className="dossier-grid">
          <div>
            <div className="kicker">Hours</div>
            <p><b>{qty(s.hours)}</b> / {s.goal} practice · <b>{qty(s.night)}</b> / {s.nightGoal} night</p>
            <p><b>{s.schoolHours}</b> school h · <b>{s.packageLeft}</b> left on a {s.packageHours}h package</p>
          </div>
          <div>
            <div className="kicker">Next</div>
            <p>{row.next ? `${when(row.next.start)} · ${row.ins?.name.split(' ')[0] || '—'} · ${row.next.meet === 'pickup' ? 'pickup' : 'lot'}` : 'No lesson on the board'}</p>
            <p>{s.pickup || 'School lot'}</p>
          </div>
        </div>
        <div className="kicker">Test-ready</div>
        <ul className="check-list">
          {s.checklist.map((c) => (
            <li key={c.id} className={c.done ? 'done' : ''}>
              <i /> {c.label}
            </li>
          ))}
        </ul>
        {s.lastNote && (
          <>
            <div className="kicker">Last instructor note</div>
            <p className="quote">“{s.lastNote}”</p>
          </>
        )}
        {s.notes && <p className="dossier-note">{s.notes}</p>}
        <div className="kicker">Lessons</div>
        <ul className="dossier-hist">
          {history.length === 0 && <li className="muted">No school lessons yet.</li>}
          {history.map((h) => (
            <li key={h.id}>
              <time>{when(h.start)}</time>
              <span>{school.instructors.find((i) => i.id === h.instructorId)?.name.split(' ')[0]}</span>
              <i className={`tag ${h.status || 'block'}`}>{h.status || h.kind}</i>
            </li>
          ))}
        </ul>
        <div className="actions" style={{ marginTop: 14 }}>
          <button className="btn btn-yes" type="button">Book lesson</button>
          <button className="btn btn-ghost" type="button">Share hours</button>
        </div>
      </div>
    </div>
  );
}

function AddSheet({ instructors, onClose, onSave }) {
  const [form, setForm] = useState({
    name: '',
    age: 16,
    parent: '',
    instructorId: instructors[0]?.id || '',
    packageHours: 10,
  });
  return (
    <div className="sheet" onClick={onClose}>
      <div className="sheet-card" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-head">
          <h3>Add student</h3>
          <button className="sheet-x" onClick={onClose} type="button">×</button>
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (!form.name.trim()) return;
            onSave(form);
          }}
        >
          <div className="field">
            <label>Name</label>
            <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
          </div>
          <div className="pair">
            <div className="field">
              <label>Age</label>
              <input type="number" value={form.age} onChange={(e) => setForm({ ...form, age: Number(e.target.value) })} />
            </div>
            <div className="field">
              <label>Package hours</label>
              <input type="number" value={form.packageHours} onChange={(e) => setForm({ ...form, packageHours: Number(e.target.value) })} />
            </div>
          </div>
          <div className="field">
            <label>Parent / customer</label>
            <input value={form.parent} onChange={(e) => setForm({ ...form, parent: e.target.value })} />
          </div>
          <div className="field">
            <label>Instructor</label>
            <select value={form.instructorId} onChange={(e) => setForm({ ...form, instructorId: e.target.value })}>
              {instructors.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
            </select>
          </div>
          <div className="actions">
            <button className="btn btn-yes" type="submit">Save student</button>
            <button className="btn btn-ghost" type="button" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
