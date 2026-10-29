import { useState, type FormEvent } from "react";
import { supabase } from "../lib/supabase";
import { updateSchool } from "../lib/api";
import { useSchool, useSession } from "../session";
import type { School } from "../lib/types";
import { Card, ErrorBox, PageHeader } from "../components/ui";

const ZONES = [
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Phoenix",
  "America/Los_Angeles",
  "America/Anchorage",
  "Pacific/Honolulu",
];

export default function Settings() {
  const s = useSession();
  const school = useSchool().schools;
  if (!school) return <ErrorBox error="School details could not be loaded." />;
  return <SettingsForm initial={school} refresh={s.refreshSchools} />;
}

function SettingsForm({ initial, refresh }: { initial: School; refresh: () => Promise<void> }) {
  const [f, setF] = useState<School>(initial);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const set = <K extends keyof School>(k: K, v: School[K]) => setF({ ...f, [k]: v });
  async function save(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    setMsg(null);
    try {
      await updateSchool(supabase, f);
      await refresh();
      setMsg("Saved.");
    } catch (x) {
      setErr((x as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <PageHeader title="Settings" desc="Your school’s profile and booking rules." />
      <form className="card" style={{ maxWidth: 640 }} onSubmit={save}>
        {msg && <div className="alert ok">{msg}</div>}
        {err && <ErrorBox error={err} />}
        <div className="field">
          <label htmlFor="n">School name</label>
          <input id="n" required value={f.name} onChange={(e) => set("name", e.target.value)} />
        </div>
        <div className="row">
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="c">City</label>
            <input id="c" value={f.city} onChange={(e) => set("city", e.target.value)} />
          </div>
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="p">Phone</label>
            <input id="p" value={f.phone} onChange={(e) => set("phone", e.target.value)} />
          </div>
        </div>
        <div className="field">
          <label htmlFor="tz">Time zone</label>
          <select id="tz" value={f.timezone} onChange={(e) => set("timezone", e.target.value)}>
            {[...new Set([f.timezone, ...ZONES])].map((z) => (
              <option key={z}>{z}</option>
            ))}
          </select>
        </div>
        <div className="row">
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="dl">Default lesson (minutes)</label>
            <input
              id="dl"
              type="number"
              min={15}
              max={480}
              value={f.default_lesson_minutes}
              onChange={(e) => set("default_lesson_minutes", Number(e.target.value))}
            />
          </div>
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="cw">Cancel window (hours)</label>
            <input
              id="cw"
              type="number"
              min={0}
              max={168}
              value={f.cancel_window_hours}
              onChange={(e) => set("cancel_window_hours", Number(e.target.value))}
            />
          </div>
        </div>
        <div className="field">
          <label htmlFor="ws">Who starts a lesson drive</label>
          <select id="ws" value={f.who_starts} onChange={(e) => set("who_starts", e.target.value)}>
            {[...new Set([f.who_starts, "instructor", "student"])].map((v) => (
              <option key={v} value={v}>
                {v}
              </option>
            ))}
          </select>
        </div>
        <button className="btn primary" disabled={busy}>
          {busy ? "Saving…" : "Save changes"}
        </button>
      </form>
      <Card title="Coming next">
        <p className="muted">
          Lesson packages and pricing, cars and lots, and slot templates are in the database already; their editors arrive in the next
          dashboard update.
        </p>
      </Card>
    </>
  );
}
