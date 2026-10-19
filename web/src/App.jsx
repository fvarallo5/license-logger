import { useMemo, useState } from 'react';
import { buildSample } from './sample.js';
import Board from './Board.jsx';
import Plan from './Plan.jsx';
import Portal from './Portal.jsx';
import Students from './Students.jsx';

const TABS = ['Board', 'Plan', 'Students', 'Pay', 'People', 'Settings'];

export default function App() {
  const portal = window.location.pathname.startsWith('/portal');
  const [school, setSchool] = useState(() => buildSample());
  const [tab, setTab] = useState(() => new URLSearchParams(window.location.search).get('tab') || 'Board');
  const [selectedDay, setSelectedDay] = useState(school.today);

  const api = useMemo(() => ({
    accept(id) {
      setSchool((s) => {
        const req = s.requests.find((r) => r.id === id);
        if (!req) return s;
        return {
          ...s,
          requests: s.requests.filter((r) => r.id !== id),
          lessons: [
            ...s.lessons,
            { ...req, id: `l-${id}`, status: 'booked' },
          ],
        };
      });
    },
    decline(id) {
      setSchool((s) => ({
        ...s,
        requests: s.requests.filter((r) => r.id !== id),
      }));
    },
    requestSlot(payload) {
      setSchool((s) => ({
        ...s,
        requests: [
          {
            id: `r-${Date.now()}`,
            status: 'requested',
            ...payload,
          },
          ...s.requests,
        ],
      }));
    },
    addTemplate(template) {
      setSchool((s) => ({
        ...s,
        templates: [...s.templates, { ...template, id: `t-${Date.now()}`, active: true }],
      }));
    },
    addStudent(form) {
      setSchool((s) => ({
        ...s,
        students: [
          ...s.students,
          {
            id: `s-${Date.now()}`,
            name: form.name.trim(),
            age: form.age,
            state: 'TX',
            hours: 0,
            night: 0,
            nightGoal: 10,
            goal: 50,
            schoolHours: 0,
            packageHours: form.packageHours,
            packageLeft: form.packageHours,
            balance: 0,
            seat: 'active',
            instructorId: form.instructorId || null,
            permitOn: '',
            holdDays: 0,
            parent: form.parent.trim(),
            phone: '',
            pickup: '',
            notes: '',
            lastNote: '',
            lastDrive: null,
            lat: s.lot.lat,
            lng: s.lot.lng,
            checklist: [
              { id: 'age', label: 'Age 16', done: form.age >= 16 },
              { id: 'hold', label: 'Permit hold', done: false },
              { id: 'practice', label: 'Practice hours', done: false },
              { id: 'night', label: 'Night hours', done: false },
              { id: 'ed', label: 'Driver ed', done: false },
              { id: 'written', label: 'Written test', done: false },
              { id: 'docs', label: 'Documents', done: false },
            ],
          },
        ],
      }));
    },
  }), []);

  if (portal) {
    return <Portal school={school} onRequest={api.requestSlot} />;
  }

  return (
    <div className="desk">
      <div className="banner">Sample week · Green Light Driving · nothing here is live yet</div>
      <header className="topbar">
        <div className="brand"><span className="ll">LL</span> LicenseLogger</div>
        <div className="school-chip">{school.school} · {school.city}</div>
        <div className="school-chip quiet">{new Date(`${school.today}T12:00:00`).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</div>
        <div className="grow" />
        <input className="search" placeholder="Search students, jump to today  ⌘K" readOnly />
        <a className="school-chip" href="/portal">Portal</a>
        <div className="you">JH</div>
      </header>
      <nav className="tabs">
        {TABS.map((t) => (
          <button key={t} className={`tab${tab === t ? ' on' : ''}`} onClick={() => setTab(t)}>
            {t}
          </button>
        ))}
      </nav>
      <main className="page">
        {tab === 'Board' && <Board school={school} api={api} />}
        {tab === 'Plan' && (
          <Plan
            school={school}
            selectedDay={selectedDay}
            onSelectDay={setSelectedDay}
            onAddTemplate={api.addTemplate}
          />
        )}
        {tab === 'Students' && <Students school={school} onAdd={api.addStudent} />}
        {tab === 'Pay' && <Stub title="Pay" copy="Packages, invoices, and instructor bills land here after the shell." />}
        {tab === 'People' && <Stub title="People" copy="Instructors, cars, customers, and invites." />}
        {tab === 'Settings' && <Stub title="Settings" copy="Lots, default duration, travel buffers, cancel window, who starts a lesson." />}
      </main>
    </div>
  );
}

function Stub({ title, copy }) {
  return (
    <div className="stub plate">
      <div>
        <h2>{title}</h2>
        <p>{copy}</p>
      </div>
    </div>
  );
}
