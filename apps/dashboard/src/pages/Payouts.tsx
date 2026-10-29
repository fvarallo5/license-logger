import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase";
import { computeInstructorPay, friendly, profileNames, type InstructorPayRow } from "../lib/api";
import { useSchool } from "../session";
import { Card, Empty, ErrorBox, Loading, PageHeader } from "../components/ui";

function monthBounds(d = new Date()) {
  const start = new Date(d.getFullYear(), d.getMonth(), 1);
  const end = new Date(d.getFullYear(), d.getMonth() + 1, 0);
  const iso = (x: Date) => x.toISOString().slice(0, 10);
  return { start: iso(start), end: iso(end) };
}

export default function PayoutsPage() {
  const schoolId = useSchool().school_id;
  const initial = useMemo(() => monthBounds(), []);
  const [from, setFrom] = useState(initial.start);
  const [to, setTo] = useState(initial.end);
  const [rows, setRows] = useState<InstructorPayRow[] | null>(null);
  const [names, setNames] = useState<Record<string, string>>({});
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const data = await computeInstructorPay(supabase, schoolId, from, to);
      setRows(data);
      setNames(
        await profileNames(
          supabase,
          data.map((r) => r.instructor_id),
        ),
      );
    } catch (e) {
      setErr(friendly(e));
      setRows([]);
    }
  }, [schoolId, from, to]);

  useEffect(() => {
    void load();
  }, [load]);

  const total = (rows ?? []).reduce((s, r) => s + Number(r.amount), 0);

  return (
    <>
      <PageHeader title="Payouts" desc="Taught lesson hours × hourly rate. Rates hidden without Pay access (RLS + Phase 4 lockdown).">
        <label className="row">
          From
          <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </label>
        <label className="row">
          To
          <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </label>
        <button className="btn" onClick={() => void load()}>
          Refresh
        </button>
      </PageHeader>
      {err && <ErrorBox error={err} onRetry={load} />}
      <Card title="Period totals" count={rows ? `$${total.toFixed(2)}` : undefined}>
        {rows === null ? (
          <Loading />
        ) : !rows.length ? (
          <Empty>No taught lessons in this period (or rates not set on People).</Empty>
        ) : (
          <table className="t">
            <thead>
              <tr>
                <th>Instructor</th>
                <th className="num">Hours</th>
                <th className="num">Rate</th>
                <th className="num">Amount</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.instructor_id}>
                  <td>{names[r.instructor_id] ?? r.instructor_id.slice(0, 8)}</td>
                  <td className="num">{Number(r.hours).toFixed(2)}</td>
                  <td className="num">${Number(r.rate).toFixed(2)}</td>
                  <td className="num">${Number(r.amount).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <p className="muted">
        Saving pay runs to <code>instructor_pay_runs</code> requires the Phase 7 migration. Until then this is a live compute view.
      </p>
    </>
  );
}
