import { useEffect, useMemo, useState } from 'react';

const START = 7 * 60;
const SPAN = 12 * 60;
const HOURS = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

function minsOf(value) {
  const d = value instanceof Date ? value : new Date(value);
  return d.getHours() * 60 + d.getMinutes();
}

function pct(value) {
  return ((minsOf(value) - START) / SPAN) * 100;
}

function width(start, end) {
  return ((minsOf(end) - minsOf(start)) / SPAN) * 100;
}

function when(iso) {
  return new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
}

function initials(name) {
  return name.split(' ').map((p) => p[0]).join('').slice(0, 2);
}

function addMin(iso, minutes) {
  const d = new Date(iso);
  d.setMinutes(d.getMinutes() + minutes);
  return d;
}

function isLive(item, now) {
  if (!item || item.status === 'taught' || item.kind === 'blocked') return false;
  return new Date(item.start) <= now && now < new Date(item.end);
}

function until(iso, now) {
  const ms = new Date(iso) - now;
  if (ms <= 0) return 'now';
  const m = Math.round(ms / 60000);
  if (m < 60) return `in ${m} min`;
  const h = Math.floor(m / 60);
  const r = m % 60;
  return r ? `in ${h}h ${r}m` : `in ${h}h`;
}

function dayLabel(iso) {
  return new Date(`${iso}T12:00:00`).toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
}

export default function Board({ school, api }) {
  const frozen = Boolean(school.clock);
  const [now, setNow] = useState(() => (school.clock ? new Date(school.clock) : new Date()));
  const [focus, setFocus] = useState(school.requests[0]?.id || school.lessons[0]?.id || null);

  useEffect(() => {
    if (frozen) return undefined;
    const t = setInterval(() => setNow(new Date()), 15000);
    return () => clearInterval(t);
  }, [frozen]);

  const roster = useMemo(() => {
    const lessons = school.lessons;
    const requests = school.requests;
    const live = lessons.find((l) => isLive(l, now));
    const upcoming = [...lessons, ...requests]
      .filter((x) => x.status !== 'taught' && x.kind !== 'blocked')
      .filter((x) => new Date(x.end) > now)
      .sort((a, b) => a.start.localeCompare(b.start));
    const booked = lessons.filter((l) => l.status === 'booked');
    const cars = [...new Set(
      booked
        .map((l) => school.instructors.find((i) => i.id === l.instructorId)?.car)
        .filter(Boolean),
    )];
    return { live, next: upcoming[0], booked, cars };
  }, [school, now]);

  const heroStudent = school.students.find((s) => s.id === (roster.live || roster.next)?.studentId);
  const heroIns = school.instructors.find((i) => i.id === (roster.live || roster.next)?.instructorId);
  const nowPct = Math.min(100, Math.max(0, pct(now)));
  const showNow = minsOf(now) >= START && minsOf(now) <= START + SPAN;

  return (
    <div className="board">
      <section className="pulse">
        <div className="pulse-card hero">
          <div className="pulse-hero-top">
            <div className="kicker">{roster.live ? 'Teaching now' : 'Next up'}</div>
            <time>{now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</time>
          </div>
          <h2>{heroStudent ? heroStudent.name.split(' ')[0] : 'Open day'}</h2>
          <p>
            {roster.live && `${when(roster.live.start)}–${when(roster.live.end)} · ${heroIns?.name.split(' ')[0]} · ${roster.live.meet === 'pickup' ? 'pickup' : 'lot'}`}
            {!roster.live && roster.next && `${when(roster.next.start)} · ${heroIns?.name.split(' ')[0]} · ${until(roster.next.start, now)}`}
            {!roster.live && !roster.next && 'No lessons left today'}
          </p>
        </div>
        <div className={`pulse-card${school.requests.length ? ' warn' : ''}`}>
          <div className="kicker">Requests</div>
          <h2>{school.requests.length}</h2>
          <p>{school.requests.length ? 'Waiting on Accept' : 'Inbox clear'}</p>
        </div>
        <div className="pulse-card">
          <div className="kicker">On the road</div>
          <h2>{roster.booked.length}</h2>
          <p>{roster.live ? `Live · ${heroStudent?.name.split(' ')[0]}` : 'Booked today'}</p>
        </div>
        <div className="pulse-card">
          <div className="kicker">Cars out</div>
          <h2>{roster.cars.length}</h2>
          <p>{roster.cars.length ? roster.cars.join(' · ') : 'All on the lot'}</p>
        </div>
      </section>

      <div className="board-grid">
        <section className="plate timeline">
          <div className="plate-h">
            <h3>Today · {dayLabel(school.today)}</h3>
            <span>Bars are lessons · hatch is travel</span>
          </div>
          <div className="hours">
            <div />
            <div className="hours-scale">
              {HOURS.filter((h) => h % 2 !== 0).map((h) => (
                <span key={h} style={{ left: `${((h * 60 - START) / SPAN) * 100}%` }}>
                  {h <= 12 ? h : h - 12}{h < 12 ? 'a' : 'p'}
                </span>
              ))}
            </div>
          </div>
          {school.instructors.map((ins) => (
            <div className="lane" key={ins.id}>
              <div className="who">
                <span className="avatar" style={{ background: ins.color }}>{initials(ins.name)}</span>
                <div>
                  <b>{ins.name.split(' ')[0]}</b>
                  <small>{ins.car}</small>
                </div>
              </div>
              <div className="track">
                {HOURS.map((h) => (
                  <i key={h} className="tick" style={{ left: `${((h * 60 - START) / SPAN) * 100}%` }} />
                ))}
                {showNow && <i className="now" style={{ left: `${nowPct}%` }} />}
                {school.blocks.filter((b) => b.instructorId === ins.id).map((b) => (
                  <div
                    key={b.id}
                    className={`bar blocked${focus === b.id ? ' on' : ''}`}
                    style={{ left: `${pct(b.start)}%`, width: `${width(b.start, b.end)}%` }}
                    onClick={() => setFocus(b.id)}
                  >
                    {b.name}
                  </div>
                ))}
                {school.lessons.filter((l) => l.instructorId === ins.id).map((l) => (
                  <Bar key={l.id} item={l} students={school.students} now={now} focus={focus} onFocus={setFocus} />
                ))}
                {school.requests.filter((l) => l.instructorId === ins.id).map((l) => (
                  <Bar key={l.id} item={l} students={school.students} now={now} focus={focus} onFocus={setFocus} />
                ))}
              </div>
            </div>
          ))}
          <ol className="up-next">
            {[...school.lessons, ...school.requests, ...school.blocks]
              .slice()
              .sort((a, b) => a.start.localeCompare(b.start))
              .map((e) => {
                const stu = school.students.find((s) => s.id === e.studentId);
                const ins = school.instructors.find((i) => i.id === e.instructorId);
                const st = e.kind === 'blocked' ? 'block' : (isLive(e, now) ? 'teaching' : e.status);
                return (
                  <li
                    key={e.id}
                    className={`up-row${focus === e.id ? ' on' : ''}`}
                    onClick={() => setFocus(e.id)}
                  >
                    <time>{when(e.start)}</time>
                    <b>{stu?.name || e.name}</b>
                    <span>{ins?.name.split(' ')[0]} · {e.meet === 'pickup' ? 'pickup' : e.kind === 'blocked' ? 'off' : 'lot'}</span>
                    <i className={`tag ${st}`}>{st}</i>
                  </li>
                );
              })}
          </ol>
        </section>

        <aside className="plate inbox">
          <div className="plate-h">
            <h3>Reservations</h3>
            <span>{school.requests.length ? `${school.requests.length} waiting` : 'Clear'}</span>
          </div>
          {school.requests.length === 0 && (
            <div className="inbox-empty">
              <b>Inbox clear</b>
              <p>Portal requests land here. Accept holds the car and the slot.</p>
            </div>
          )}
          {school.requests.map((r) => {
            const stu = school.students.find((s) => s.id === r.studentId);
            const ins = school.instructors.find((i) => i.id === r.instructorId);
            return (
              <article
                key={r.id}
                className={`req${focus === r.id ? ' on' : ''}`}
                onClick={() => setFocus(r.id)}
              >
                <div className="req-top">
                  <h4>{stu?.name}</h4>
                  <em className="tag requested">requested</em>
                </div>
                <p className="req-line">
                  {when(r.start)}–{when(r.end)} · {ins?.name.split(' ')[0]} · {r.meet === 'pickup' ? 'pickup' : 'lot'}
                </p>
                {r.note && <p className="quote">“{r.note}”</p>}
                <div className="req-chips">
                  <span>{stu ? `${stu.hours.toFixed(0)}/${stu.goal} h` : ''}</span>
                  <span>{stu?.ready} ready</span>
                  <span>{until(r.start, now)}</span>
                </div>
                <div className="actions">
                  <button className="btn btn-yes" onClick={(e) => { e.stopPropagation(); api.accept(r.id); }}>Accept</button>
                  <button className="btn btn-no" onClick={(e) => { e.stopPropagation(); api.decline(r.id); }}>Decline</button>
                </div>
              </article>
            );
          })}
        </aside>
      </div>
    </div>
  );
}

function Bar({ item, students, now, focus, onFocus }) {
  const stu = students.find((s) => s.id === item.studentId);
  const live = isLive(item, now);
  const status = live ? 'teaching' : (item.status || item.kind);
  const travelAfter = item.travelAfter || 0;
  const travelBefore = item.travelBefore || 0;
  const end = new Date(item.end);
  const beforeStart = addMin(item.start, -travelBefore);

  return (
    <>
      {travelBefore > 0 && (
        <div
          className="travel"
          style={{ left: `${pct(beforeStart)}%`, width: `${(travelBefore / SPAN) * 100}%` }}
        />
      )}
      <button
        type="button"
        className={`bar ${status}${focus === item.id ? ' on' : ''}`}
        style={{ left: `${pct(item.start)}%`, width: `${width(item.start, item.end)}%` }}
        title={stu?.name || item.name}
        onClick={() => onFocus(item.id)}
      >
        {stu?.name.split(' ')[0] || item.name}
      </button>
      {travelAfter > 0 && (
        <div
          className="travel"
          style={{ left: `${pct(end)}%`, width: `${Math.max((travelAfter / SPAN) * 100, 1.2)}%` }}
        />
      )}
    </>
  );
}
