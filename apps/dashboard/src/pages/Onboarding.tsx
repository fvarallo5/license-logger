import { useState, type FormEvent } from "react";
import { supabase } from "../lib/supabase";
import { createSchool } from "../lib/api";
import { useSession } from "../session";

export default function Onboarding() {
  const s = useSession();
  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      const id = await createSchool(supabase, name.trim(), city.trim());
      s.selectSchool(id);
      await s.refreshSchools();
    } catch (x) {
      setErr((x as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="auth-wrap">
      <form className="card auth-card" onSubmit={submit}>
        <h2>Set up your driving school</h2>
        <p className="muted">
          You'll be the owner. You can invite instructors and front-desk staff after this. If someone already invited you, ask them to
          resend the invite to {s.session?.user.email}.
        </p>
        {err && <div className="alert bad">{err}</div>}
        <div className="field">
          <label htmlFor="sn">School name</label>
          <input id="sn" value={name} onChange={(e) => setName(e.target.value)} required minLength={2} />
        </div>
        <div className="field">
          <label htmlFor="sc">City, state</label>
          <input id="sc" value={city} onChange={(e) => setCity(e.target.value)} placeholder="Austin, TX" />
        </div>
        <div className="row">
          <button className="btn primary" disabled={busy}>
            {busy ? "Creating…" : "Create school"}
          </button>
          <button type="button" className="btn" onClick={() => void supabase.auth.signOut()}>
            Sign out
          </button>
        </div>
      </form>
    </div>
  );
}
