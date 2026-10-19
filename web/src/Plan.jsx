import { useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

const DOW = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const DAY_NAMES = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

function fmtDay(iso) {
  return new Date(`${iso}T12:00:00`).toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
}

function hm(iso) {
  return iso.slice(11, 16);
}

function meetLabel(e) {
  if (e.kind === 'blocked') return 'off';
  return e.meet === 'pickup' ? 'pickup' : 'lot';
}

function statusOf(e) {
  if (e.kind === 'blocked') return 'block';
  return e.status || 'slot';
}

function monthCells(year, month) {
  const first = new Date(year, month, 1);
  const lead = first.getDay();
  const days = new Date(year, month + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < 42; i += 1) {
    const d = new Date(year, month, i - lead + 1);
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    cells.push({ iso, day: d.getDate(), inMonth: d.getMonth() === month });
  }
  return cells;
}

function eventsOn(school, iso) {
  const day = (row) => row.start.slice(0, 10) === iso;
  return [
    ...school.lessons.filter(day),
    ...school.requests.filter(day),
    ...school.blocks.filter(day),
  ];
}

export default function Plan({ school, selectedDay, onSelectDay, onAddTemplate }) {
  const now = new Date();
  const [cursor, setCursor] = useState({ y: now.getFullYear(), m: now.getMonth() });
  const [sheet, setSheet] = useState(() => new URLSearchParams(window.location.search).has('new'));
  const cells = useMemo(() => monthCells(cursor.y, cursor.m), [cursor]);
  const title = new Date(cursor.y, cursor.m, 1).toLocaleString('en', { month: 'long', year: 'numeric' });
  const dayEvents = eventsOn(school, selectedDay)
    .slice()
    .sort((a, b) => a.start.localeCompare(b.start));

  return (
    <div className="plan-grid">
      <section className="plate day-pane">
        <div className="plate-h">
          <div>
            <h3>{fmtDay(selectedDay)}</h3>
            <span>{dayEvents.length === 0 ? 'Open day' : `${dayEvents.length} on the board`}</span>
          </div>
        </div>
        <button className="btn btn-lime day-new" onClick={() => setSheet(true)}>New slot</button>
        <div className="day-list">
          {dayEvents.length === 0 && <p className="day-empty">No slots this day yet.</p>}
          {dayEvents.map((e) => {
            const stu = school.students.find((s) => s.id === e.studentId);
            const ins = school.instructors.find((i) => i.id === e.instructorId);
            const st = statusOf(e);
            return (
              <article className="day-item" key={e.id}>
                <time>{hm(e.start)}–{hm(e.end)}</time>
                <b>{stu?.name || e.name || e.kind}</b>
                <span>{ins?.name.split(' ')[0]} · {meetLabel(e)}</span>
                <i className={`tag ${st}`}>{st}</i>
              </article>
            );
          })}
        </div>
      </section>
      <section className="plate cal">
        <div className="cal-nav">
          <button className="btn btn-ghost" onClick={() => setCursor((c) => {
            const d = new Date(c.y, c.m - 1, 1);
            return { y: d.getFullYear(), m: d.getMonth() };
          })}>‹</button>
          <h2>{title}</h2>
          <button className="btn btn-ghost" onClick={() => setCursor((c) => {
            const d = new Date(c.y, c.m + 1, 1);
            return { y: d.getFullYear(), m: d.getMonth() };
          })}>›</button>
        </div>
        <div className="dow">{DOW.map((d, i) => <span key={`${d}${i}`}>{d}</span>)}</div>
        <div className="grid">
          {cells.map((c) => {
            const ev = eventsOn(school, c.iso);
            return (
              <button
                key={c.iso}
                className={`cell${c.inMonth ? '' : ' out'}${c.iso === school.today ? ' today' : ''}${c.iso === selectedDay ? ' sel' : ''}`}
                onClick={() => onSelectDay(c.iso)}
              >
                <b>{c.day}</b>
                <div className="chips">
                  {ev.map((e) => (
                    <i
                      key={e.id}
                      className="chip"
                      style={{
                        background: e.status === 'requested' ? '#f9ad26'
                          : e.status === 'taught' ? '#027e47'
                            : e.kind === 'blocked' ? '#9eacbe'
                              : '#1156c1',
                      }}
                    />
                  ))}
                </div>
              </button>
            );
          })}
        </div>
      </section>
      <section className="plate map-wrap">
        <div className="plate-h">
          <h3>Day map</h3>
          <div className="map-legend" aria-hidden="true">
            <span><i className="lg lg-lot" />Lot</span>
            <span><i className="lg lg-booked" />Booked</span>
            <span><i className="lg lg-pickup" />Pickup</span>
            <span><i className="lg lg-req" />Request</span>
          </div>
        </div>
        <div className="map-box">
          <DayMap school={school} selectedDay={selectedDay} />
          <div className="map-hud" aria-hidden="true">
            <i className="map-hud-corner nw" />
            <i className="map-hud-corner ne" />
            <i className="map-hud-corner sw" />
            <i className="map-hud-corner se" />
          </div>
        </div>
      </section>
      {sheet && (
        <SlotSheet
          school={school}
          onClose={() => setSheet(false)}
          onSave={(t) => { onAddTemplate(t); setSheet(false); }}
        />
      )}
    </div>
  );
}

function pinIcon(kind, label) {
  const size = kind === 'lot' ? 36 : 28;
  return L.divIcon({
    className: `ll-pin ll-pin--${kind}`,
    html: `<i class="ll-ping"></i><span>${label}</span>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    tooltipAnchor: [0, -size / 2 - 4],
  });
}

function pinKind(event) {
  if (event.status === 'requested') return 'req';
  if (event.status === 'taught') return 'taught';
  if (event.meet === 'pickup') return 'pickup';
  return 'booked';
}

function DayMap({ school, selectedDay }) {
  const ref = useRef(null);
  const mapRef = useRef(null);
  const groupRef = useRef(null);

  useEffect(() => {
    if (!ref.current || mapRef.current) return undefined;
    const map = L.map(ref.current, {
      zoomControl: false,
      attributionControl: true,
    });
    L.control.zoom({ position: 'bottomright' }).addTo(map);
    L.tileLayer(
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      {
        maxZoom: 19,
        maxNativeZoom: 19,
        attribution: 'Tiles &copy; <a href="https://www.esri.com/">Esri</a>',
      },
    ).addTo(map);
    map.setView([school.lot.lat, school.lot.lng], 13);
    groupRef.current = L.layerGroup().addTo(map);
    mapRef.current = map;
    setTimeout(() => map.invalidateSize(), 80);
    return () => {
      map.remove();
      mapRef.current = null;
      groupRef.current = null;
    };
  }, [school.lot.lat, school.lot.lng]);

  useEffect(() => {
    const map = mapRef.current;
    const group = groupRef.current;
    if (!map || !group) return;
    group.clearLayers();
    const lot = [school.lot.lat, school.lot.lng];
    const points = [lot];

    L.circle(lot, {
      radius: 520,
      color: '#1156C1',
      weight: 1.25,
      opacity: 0.45,
      dashArray: '3 7',
      fillColor: '#1156C1',
      fillOpacity: 0.05,
      className: 'll-lot-ring',
      interactive: false,
    }).addTo(group);

    L.marker(lot, { icon: pinIcon('lot', 'LL'), zIndexOffset: 40 })
      .bindTooltip(school.lot.name, { className: 'll-tip', direction: 'top' })
      .addTo(group);

    eventsOn(school, selectedDay).forEach((e) => {
      const stu = school.students.find((s) => s.id === e.studentId);
      if (!stu) return;
      const here = [stu.lat, stu.lng];
      points.push(here);
      const kind = pinKind(e);
      const initials = stu.name.split(' ').map((p) => p[0]).join('').slice(0, 2);
      if (e.meet === 'pickup') {
        L.polyline([lot, here], {
          color: '#1156C1',
          weight: 7,
          opacity: 0.12,
          lineCap: 'round',
          className: 'll-route-glow',
          interactive: false,
        }).addTo(group);
        L.polyline([lot, here], {
          color: '#1156C1',
          weight: 2,
          opacity: 0.8,
          dashArray: '1 8',
          lineCap: 'round',
          className: 'll-route',
        }).addTo(group);
      }
      L.marker(here, { icon: pinIcon(kind, initials), zIndexOffset: kind === 'req' ? 20 : 10 })
        .bindTooltip(
          `${stu.name} · ${e.meet === 'pickup' ? 'pickup' : 'lot'} · ${e.status || e.kind}`,
          { className: 'll-tip', direction: 'top' },
        )
        .addTo(group);
    });

    if (points.length > 1) {
      map.fitBounds(points, { padding: [36, 36], maxZoom: 15 });
    } else {
      map.setView(lot, 13);
    }
    setTimeout(() => map.invalidateSize(), 80);
  }, [school, selectedDay]);

  return <div ref={ref} className="day-map" />;
}

function SlotSheet({ school, onClose, onSave }) {
  const [form, setForm] = useState({
    instructorId: school.instructors[0].id,
    name: 'New BTW block',
    kind: 'Behind-the-wheel',
    durationHours: 1,
    travelBefore: 0,
    travelAfter: 15,
    days: [1, 2, 3, 4, 5],
    windowStart: '09:00',
    windowEnd: '17:00',
    meet: 'lot',
    car: school.instructors[0].car,
    minNotice: 24,
    maxAdvance: 14,
    note: 'Bring permit and glasses.',
  });

  function toggleDay(d) {
    setForm((f) => ({
      ...f,
      days: f.days.includes(d) ? f.days.filter((x) => x !== d) : [...f.days, d].sort(),
    }));
  }

  return (
    <div className="sheet" onClick={onClose}>
      <form
        className="sheet-card"
        onClick={(e) => e.stopPropagation()}
        onSubmit={(e) => {
          e.preventDefault();
          onSave(form);
        }}
      >
        <div className="sheet-head">
          <h3>New time slot</h3>
          <button type="button" className="sheet-x" onClick={onClose} aria-label="Close">×</button>
        </div>
        <div className="field">
          <label>Instructor</label>
          <select value={form.instructorId} onChange={(e) => setForm({ ...form, instructorId: e.target.value })}>
            {school.instructors.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
          </select>
        </div>
        <div className="pair">
          <div className="field">
            <label>Duration (hours)</label>
            <input type="number" min="0.5" max="3" step="0.25" value={form.durationHours} onChange={(e) => setForm({ ...form, durationHours: Number(e.target.value) })} />
          </div>
          <div className="field">
            <label>Kind</label>
            <select value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
              <option>Behind-the-wheel</option>
              <option>Observation</option>
              <option>Classroom</option>
              <option>Road-test ride</option>
            </select>
          </div>
        </div>
        <div className="pair">
          <div className="field">
            <label>Travel before (min)</label>
            <input type="number" min="0" max="60" value={form.travelBefore} onChange={(e) => setForm({ ...form, travelBefore: Number(e.target.value) })} />
          </div>
          <div className="field">
            <label>Travel after (min)</label>
            <input type="number" min="0" max="60" value={form.travelAfter} onChange={(e) => setForm({ ...form, travelAfter: Number(e.target.value) })} />
          </div>
        </div>
        <div className="field">
          <label>Days</label>
          <div className="days">
            {DAY_NAMES.map((n, i) => (
              <button type="button" key={n + i} className={form.days.includes(i) ? 'on' : ''} onClick={() => toggleDay(i)}>{n}</button>
            ))}
          </div>
        </div>
        <div className="pair">
          <div className="field">
            <label>Window start</label>
            <input type="time" value={form.windowStart} onChange={(e) => setForm({ ...form, windowStart: e.target.value })} />
          </div>
          <div className="field">
            <label>Window end</label>
            <input type="time" value={form.windowEnd} onChange={(e) => setForm({ ...form, windowEnd: e.target.value })} />
          </div>
        </div>
        <div className="pair">
          <div className="field">
            <label>Meet</label>
            <select value={form.meet} onChange={(e) => setForm({ ...form, meet: e.target.value })}>
              <option value="lot">School lot</option>
              <option value="pickup">House pickup</option>
            </select>
          </div>
          <div className="field">
            <label>Car</label>
            <input value={form.car} onChange={(e) => setForm({ ...form, car: e.target.value })} />
          </div>
        </div>
        <div className="pair">
          <div className="field">
            <label>Min notice (h)</label>
            <input type="number" value={form.minNotice} onChange={(e) => setForm({ ...form, minNotice: Number(e.target.value) })} />
          </div>
          <div className="field">
            <label>Max advance (days)</label>
            <input type="number" value={form.maxAdvance} onChange={(e) => setForm({ ...form, maxAdvance: Number(e.target.value) })} />
          </div>
        </div>
        <div className="field">
          <label>Customer note</label>
          <input value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} />
        </div>
        <div className="actions">
          <button type="submit" className="btn btn-yes">Save slot</button>
          <button type="button" className="btn btn-ghost" onClick={onClose}>Cancel</button>
        </div>
      </form>
    </div>
  );
}
