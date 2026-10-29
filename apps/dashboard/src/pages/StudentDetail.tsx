import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { type DriveCursor, exportReport, getStudent, releaseStudent, ruleProgress, stateResources, studentDrivesPage } from "../lib/api";
import { usePaged } from "../lib/usePaged";
import { useSession } from "../session";
import { perms } from "../lib/perms";
import { fmtDate, fmtDateTime, hrs, statusTone } from "../lib/format";
import type { Requirement, RuleProgress, Student } from "../lib/types";
import { Badge, Card, Empty, ErrorBox, Loading, PageHeader, Pager, Progress } from "../components/ui";

export default function StudentDetail() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const p = perms(useSession().current);
  const [student, setStudent] = useState<Student | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "missing" | "error">("loading");
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(() => {
    setState("loading");
    getStudent(supabase, id)
      .then((s) => {
        setStudent(s);
        setState(s ? "ready" : "missing");
      })
      .catch((e: Error) => {
        setErr(e.message);
        setState("error");
      });
  }, [id]);
  useEffect(load, [load]);

  async function release() {
    if (
      !student ||
      !confirm(`Release ${student.first_name} from your school? They keep their app account and hours; you keep your records.`)
    )
      return;
    try {
      await releaseStudent(supabase, student.id);
      nav("/students");
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  if (state === "loading") return <Loading />;
  if (state === "error") return <ErrorBox error={err ?? "Error"} onRetry={load} />;
  if (state === "missing" || !student)
    return (
      <Empty>
        This student isn’t at your school (they may have left). <Link to="/students">Back to students</Link>
      </Empty>
    );

  return (
    <>
      <PageHeader
        title={`${student.first_name} ${student.last_name}`}
        desc={`${student.state_code} · permit ${fmtDate(student.permit_on)} · ${student.user_id ? "app connected" : "no app yet"}`}
      >
        <Link className="btn" to="/students">
          ← Students
        </Link>
        {p.manageStudents && student.user_id && (
          <button className="btn danger" onClick={() => void release()}>
            Release student
          </button>
        )}
      </PageHeader>
      {err && <ErrorBox error={err} />}
      <div className="grid2">
        <div>
          <ProgressCard studentId={student.id} />
          <DrivesCard studentId={student.id} />
        </div>
        <div>
          <Card title="Join code">
            <div className="kpi mono">{student.join_code}</div>
            <p className="muted">The student enters this in the LicenseLogger app to connect to this profile.</p>
          </Card>
          <ExportCard studentId={student.id} />
          <ResourcesCard state={student.state_code} permitOn={student.permit_on} />
        </div>
      </div>
    </>
  );
}

function ReqRow({ r }: { r: Requirement }) {
  return (
    <div style={{ marginBottom: 10 }}>
      <div className="row" style={{ justifyContent: "space-between" }}>
        <strong>{r.label ?? r.key}</strong>
        <span>
          {hrs(r.credited_minutes)} / {hrs(r.required_minutes)} {r.met ? <Badge tone="ok">met</Badge> : null}
          {r.pending_minutes ? <span className="muted"> (+{hrs(r.pending_minutes)} pending)</span> : null}
        </span>
      </div>
      <Progress have={r.credited_minutes ?? 0} need={r.required_minutes ?? 0} label={r.label} />
    </div>
  );
}

function ProgressCard({ studentId }: { studentId: string }) {
  const [d, setD] = useState<RuleProgress | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    ruleProgress(supabase, studentId)
      .then(setD)
      .catch((e: Error) => setErr(e.message));
  }, [studentId]);
  return (
    <Card
      title="Progress vs state rules"
      count={d?.rule ? d.rule.label : undefined}
      actions={d && (d.all_met ? <Badge tone="ok">ready</Badge> : <Badge tone="warn">in progress</Badge>)}
    >
      {err ? (
        <ErrorBox error={err} />
      ) : !d ? (
        <Loading />
      ) : !d.rule ? (
        <Empty>No state rule set found for this student yet. Check their state and permit date.</Empty>
      ) : (
        <>
          {d.rule.status !== "active" && (
            <div className="alert warn">This state’s rules are marked “{d.rule.status}”. Double-check with the official source.</div>
          )}
          {d.requirements.map((r, i) => (
            <ReqRow key={r.key ?? i} r={r} />
          ))}
          {d.stages.map((s) => (
            <div key={s.key} style={{ borderTop: "1px solid var(--line)", paddingTop: 8 }}>
              <div className="row">
                <strong>{s.label}</strong>
                {s.met && <Badge tone="ok">met</Badge>}
              </div>
              {s.requirements.map((r, i) => (
                <ReqRow key={r.key ?? i} r={r} />
              ))}
            </div>
          ))}
          {d.still_needed.length > 0 && (
            <div className="alert">
              <strong>Still needed:</strong> {d.still_needed.join(" · ")}
            </div>
          )}
          {d.paperwork?.form_name && (
            <p className="muted">
              Official form: {d.paperwork.form_name} {d.paperwork.form_number}
            </p>
          )}
        </>
      )}
    </Card>
  );
}

function DrivesCard({ studentId }: { studentId: string }) {
  const pg = usePaged((c: DriveCursor | null) => studentDrivesPage(supabase, studentId, c), studentId);
  return (
    <Card title="Drives">
      {pg.error ? (
        <ErrorBox error={pg.error} onRetry={pg.reload} />
      ) : pg.loading ? (
        <Loading />
      ) : !pg.rows.length ? (
        <Empty>No drives logged yet.</Empty>
      ) : (
        <div style={{ overflowX: "auto" }}>
          <table className="t">
            <thead>
              <tr>
                <th>When</th>
                <th>Type</th>
                <th>Route</th>
                <th>Time</th>
                <th>Night</th>
                <th>Miles</th>
                <th>Supervisor</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {pg.rows.map((r) => (
                <tr key={r.id}>
                  <td>{fmtDateTime(r.started_at)}</td>
                  <td>{r.kind}</td>
                  <td>
                    {r.start_label} → {r.end_label}
                  </td>
                  <td className="num">{hrs(r.duration_minutes)}</td>
                  <td className="num">{hrs(r.night_minutes)}</td>
                  <td className="num">{Number(r.distance_miles).toFixed(1)}</td>
                  <td>{r.supervisor_name ?? "—"}</td>
                  <td>
                    <Badge tone={statusTone(r.status)}>{r.status}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager {...pg} />
    </Card>
  );
}

function ExportCard({ studentId }: { studentId: string }) {
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ tone: "warn" | "bad" | "ok"; text: string } | null>(null);
  async function go(format: "pdf" | "csv", layout: "report" | "state") {
    setBusy(format + layout);
    setMsg(null);
    const r = await exportReport(supabase, { student_id: studentId, format, layout });
    setBusy(null);
    if (r.ok) {
      window.open(r.url, "_blank", "noopener");
      setMsg({ tone: "ok", text: "Download started. The link works for 10 minutes." });
    } else setMsg({ tone: r.notDeployed ? "warn" : "bad", text: r.message });
  }
  return (
    <Card title="Reports">
      {msg && (
        <div className={`alert ${msg.tone}`} role="alert">
          {msg.text}
        </div>
      )}
      <p className="muted" style={{ marginBottom: "0.5rem" }}>
        One-tap state-matched log for the DMV, plus a school hours report and CSV. Links expire in 10 minutes.
      </p>
      <div className="row">
        <button className="btn primary" disabled={!!busy} onClick={() => void go("pdf", "state")}>
          {busy === "pdfstate" ? "Building…" : "State log (PDF)"}
        </button>
        <button className="btn" disabled={!!busy} onClick={() => void go("pdf", "report")}>
          Hours report
        </button>
        <button className="btn" disabled={!!busy} onClick={() => void go("csv", "report")}>
          CSV
        </button>
      </div>
    </Card>
  );
}

function ResourcesCard({ state, permitOn }: { state: string; permitOn: string | null }) {
  const [d, setD] = useState<Record<string, unknown> | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    stateResources(supabase, state, permitOn)
      .then(setD)
      .catch((e: Error) => setErr(e.message));
  }, [state, permitOn]);
  const links = (d?.links as { kind: string; url: string; label?: string; status?: string }[] | undefined) ?? [];
  const checklist = (d?.checklist as { step: number; text: string }[] | undefined) ?? [];
  return (
    <Card title={`${state} resources`}>
      {err ? (
        <ErrorBox error={err} />
      ) : !d ? (
        <Loading />
      ) : (
        <>
          {checklist.length > 0 && (
            <ol style={{ paddingLeft: 18, marginTop: 0 }}>
              {checklist.map((c) => (
                <li key={c.step}>{c.text}</li>
              ))}
            </ol>
          )}
          {links.length ? (
            <ul style={{ paddingLeft: 18 }}>
              {links.map((l) => (
                <li key={l.kind}>
                  <a href={l.url} target="_blank" rel="noreferrer">
                    {l.label ?? l.kind.replace(/_url$/, "").replace(/_/g, " ")}
                  </a>
                  {l.status && l.status !== "ok" && (
                    <>
                      {" "}
                      <Badge tone="warn">{l.status}</Badge>
                    </>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <Empty>No official links on file for this state.</Empty>
          )}
        </>
      )}
    </Card>
  );
}
