import { useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { type DriveCursor, pendingDrivesPage, rejectDrive, signLesson, voidDrive } from "../lib/api";
import { usePaged } from "../lib/usePaged";
import { useSchool } from "../session";
import { fmtDateTime, fullName, hrs } from "../lib/format";
import type { Drive } from "../lib/types";
import { Badge, Card, Empty, ErrorBox, Loading, Modal, PageHeader, Pager } from "../components/ui";

type Action = { drive: Drive; kind: "reject" | "void" };

export default function Drives() {
  const schoolId = useSchool().school_id;
  const pg = usePaged((c: DriveCursor | null) => pendingDrivesPage(supabase, schoolId, c), schoolId);
  const [action, setAction] = useState<Action | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ tone: "ok" | "bad"; text: string } | null>(null);

  async function sign(d: Drive) {
    setBusy(d.id);
    setMsg(null);
    try {
      await signLesson(supabase, d.id);
      setMsg({ tone: "ok", text: "Lesson signed." });
      pg.reload();
    } catch (e) {
      setMsg({ tone: "bad", text: (e as Error).message });
    } finally {
      setBusy(null);
    }
  }

  return (
    <>
      <PageHeader
        title="Sign-offs"
        desc="Drives waiting for review. You sign instructor lessons here; parents sign practice drives in their app."
      />
      {msg && (
        <div className={`alert ${msg.tone}`} role="status">
          {msg.text}
        </div>
      )}
      <Card title="Pending drives">
        {pg.error ? (
          <ErrorBox error={pg.error} onRetry={pg.reload} />
        ) : pg.loading ? (
          <Loading />
        ) : !pg.rows.length ? (
          <Empty>All caught up. No drives are waiting.</Empty>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="t">
              <thead>
                <tr>
                  <th>Student</th>
                  <th>When</th>
                  <th>Type</th>
                  <th>Route</th>
                  <th>Time</th>
                  <th>Night</th>
                  <th>Miles</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {pg.rows.map((d) => (
                  <tr key={d.id}>
                    <td>
                      <Link to={`/students/${d.student_id}`}>{fullName(d.students)}</Link>
                    </td>
                    <td>{fmtDateTime(d.started_at)}</td>
                    <td>
                      <Badge tone={d.kind === "lesson" ? "info" : ""}>{d.kind}</Badge>
                    </td>
                    <td>
                      {d.start_label} → {d.end_label}
                    </td>
                    <td className="num">{hrs(d.duration_minutes)}</td>
                    <td className="num">{hrs(d.night_minutes)}</td>
                    <td className="num">{Number(d.distance_miles).toFixed(1)}</td>
                    <td className="row nowrap">
                      {d.kind === "lesson" ? (
                        <button className="btn sm primary" disabled={busy === d.id} onClick={() => void sign(d)}>
                          Sign
                        </button>
                      ) : (
                        <span className="muted" title="Practice drives are signed by a parent/supervisor in the app">
                          Family signs
                        </span>
                      )}
                      <button className="btn sm" onClick={() => setAction({ drive: d, kind: "reject" })}>
                        Reject
                      </button>
                      <button className="btn sm danger" onClick={() => setAction({ drive: d, kind: "void" })}>
                        Void
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pager {...pg} />
      </Card>
      {action && (
        <ReasonModal
          action={action}
          onClose={() => setAction(null)}
          onDone={(t) => {
            setAction(null);
            setMsg({ tone: "ok", text: t });
            pg.reload();
          }}
        />
      )}
    </>
  );
}

function ReasonModal({ action, onClose, onDone }: { action: Action; onClose: () => void; onDone: (t: string) => void }) {
  const [reason, setReason] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const isVoid = action.kind === "void";
  async function submit() {
    setBusy(true);
    setErr(null);
    try {
      if (isVoid) await voidDrive(supabase, action.drive.id, reason);
      else await rejectDrive(supabase, action.drive.id, reason);
      onDone(isVoid ? "Drive voided. It no longer counts toward hours." : "Drive rejected. The student can see your reason.");
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title={isVoid ? "Void this drive" : "Reject this drive"} onClose={onClose}>
      <p className="muted">
        {fullName(action.drive.students)} · {fmtDateTime(action.drive.started_at)} · {hrs(action.drive.duration_minutes)}
      </p>
      {err && <ErrorBox error={err} />}
      <div className="field">
        <label htmlFor="reason">Reason {isVoid && "(required)"}</label>
        <input id="reason" value={reason} onChange={(e) => setReason(e.target.value)} />
      </div>
      <div className="row">
        <button
          className={`btn ${isVoid ? "danger" : "primary"}`}
          disabled={busy || (isVoid && reason.trim().length < 3)}
          onClick={() => void submit()}
        >
          {isVoid ? "Void drive" : "Reject drive"}
        </button>
        <button className="btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </Modal>
  );
}
