import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import { friendly, getStudent, listInvoices, listMyFamilyLinks, requestSlot, ruleProgress } from "../../lib/api";
import { useSession } from "../../session";
import { Card, Empty, ErrorBox, Loading, PageHeader } from "../../components/ui";

type LinkRow = { student_id: string; school_id: string; relationship: string | null };

export default function PortalApp() {
  const { session } = useSession();
  const [links, setLinks] = useState<LinkRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [studentId, setStudentId] = useState<string>("");
  const [hours, setHours] = useState<string>("");
  const [invoices, setInvoices] = useState<{ doc_number: string | null; balance: number; status: string }[]>([]);
  const [note, setNote] = useState("");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const rows = await listMyFamilyLinks(supabase);
      setLinks(rows);
      if (rows[0] && !studentId) setStudentId(rows[0].student_id);
    } catch (e) {
      // Demo / staff may have no family_links — soft empty
      setLinks([]);
      setErr(friendly(e));
    }
  }, [studentId]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!studentId || !links?.length) return;
    const link = links.find((l) => l.student_id === studentId) ?? links[0];
    void (async () => {
      try {
        const prog = await ruleProgress(supabase, studentId);
        const practice =
          (prog as { practice_minutes?: number; practice_hours?: number })?.practice_hours ??
          ((prog as { practice_minutes?: number })?.practice_minutes ?? 0) / 60;
        setHours(String(practice));
        const inv = await listInvoices(supabase, link.school_id).catch(() => []);
        setInvoices(
          inv.filter((i) => i.student_id === studentId).map((i) => ({ doc_number: i.doc_number, balance: i.balance, status: i.status })),
        );
      } catch {
        setHours("—");
      }
    })();
  }, [studentId, links]);

  async function submitRequest() {
    if (!links?.length || !studentId || !start || !end) return;
    const link = links.find((l) => l.student_id === studentId);
    if (!link) return;
    setBusy(true);
    setMsg(null);
    try {
      // Instructor required — use school's first instructor from studentsPage instructor_id or placeholder RPC
      const stu = await getStudent(supabase, studentId).catch(() => null);
      const instructorId = (stu as { instructor_id?: string } | null)?.instructor_id;
      if (!instructorId) throw new Error("No instructor assigned yet — ask the school.");
      await requestSlot(supabase, {
        schoolId: link.school_id,
        studentId,
        instructorId,
        startAt: new Date(start).toISOString(),
        endAt: new Date(end).toISOString(),
        note,
      });
      setMsg("Request sent. The school will accept or suggest another time.");
      setNote("");
    } catch (e) {
      setMsg(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  // Demo mode: show sample portal when no links
  const demo = !links?.length;

  return (
    <div className="portal-shell">
      <header className="top">
        <div className="logo">
          <i />
          LicenseLogger · Family
        </div>
        <div className="spacer" />
        <span className="who">{session?.user.email}</span>
        <Link className="btn sm" to="/board">
          Desk
        </Link>
        <button className="btn sm" onClick={() => void supabase.auth.signOut()}>
          Sign out
        </button>
      </header>
      <main>
        <PageHeader title="Family portal" desc="Hours, request a lesson, and billing read-only." />
        {err && !demo && <ErrorBox error={err} onRetry={load} />}
        {links === null ? (
          <Loading />
        ) : demo ? (
          <Card title="No linked students">
            <Empty>
              Sign in with a family account that redeemed an invite, or ask the school to send a family invite. Desk staff can open{" "}
              <Link to="/board">Board</Link>.
            </Empty>
          </Card>
        ) : (
          <>
            <Card title="Your students">
              <select value={studentId} onChange={(e) => setStudentId(e.target.value)} aria-label="Student">
                {links.map((l) => (
                  <option key={l.student_id} value={l.student_id}>
                    {l.student_id.slice(0, 8)}…
                  </option>
                ))}
              </select>
              <p style={{ marginTop: "0.75rem" }}>
                Practice hours (approx): <strong>{hours}</strong>
              </p>
            </Card>
            <Card title="Request a time">
              {msg && (
                <div className="alert warn" role="status">
                  {msg}
                </div>
              )}
              <label>
                Start
                <input type="datetime-local" value={start} onChange={(e) => setStart(e.target.value)} />
              </label>
              <label>
                End
                <input type="datetime-local" value={end} onChange={(e) => setEnd(e.target.value)} />
              </label>
              <label>
                Note
                <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Pickup notes…" />
              </label>
              <button className="btn primary" disabled={busy || !start || !end} onClick={() => void submitRequest()}>
                Send request
              </button>
              <p className="muted">Sends a request to the school. They accept or decline on Plan.</p>
            </Card>
            <Card title="Billing" count={invoices.length}>
              {!invoices.length ? (
                <Empty>No invoices for this student.</Empty>
              ) : (
                <ul>
                  {invoices.map((i, idx) => (
                    <li key={idx}>
                      {i.doc_number || "Invoice"} · {i.status} · ${Number(i.balance).toFixed(2)} due
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </>
        )}
      </main>
    </div>
  );
}
