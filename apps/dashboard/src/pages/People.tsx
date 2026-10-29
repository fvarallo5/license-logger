import { useEffect, useState, type FormEvent } from "react";
import { supabase } from "../lib/supabase";
import { inviteToSchool, invitesPage, membersPage, profileNames, revokeInvite } from "../lib/api";
import { usePaged } from "../lib/usePaged";
import { useSchool } from "../session";
import { perms } from "../lib/perms";
import { fmtDate, roleLabel } from "../lib/format";
import type { Role } from "../lib/types";
import { Badge, Card, Empty, ErrorBox, Loading, Modal, PageHeader, Pager } from "../components/ui";

export default function People() {
  const current = useSchool();
  const schoolId = current.school_id;
  const p = perms(current);
  const [filter, setFilter] = useState<Role | "">("");
  const [inviting, setInviting] = useState(false);
  const [k, setK] = useState(0);
  const pg = usePaged((c: number | null) => membersPage(supabase, schoolId, c ?? 0, filter || undefined), `${schoolId}:${filter}`);
  const [names, setNames] = useState<Record<string, string>>({});
  useEffect(() => {
    void profileNames(
      supabase,
      pg.rows.map((r) => r.user_id),
    ).then(setNames);
  }, [pg.rows]);
  const soon = (d: string | null) => d && new Date(d).getTime() - Date.now() < 30 * 864e5;

  return (
    <>
      <PageHeader title="People" desc="Instructors and staff at your school.">
        <div className="seg">
          {(["", "instructor", "front_desk", "admin"] as const).map((r) => (
            <button key={r} className={filter === r ? "on" : ""} onClick={() => setFilter(r)}>
              {r ? roleLabel[r] : "All"}
            </button>
          ))}
        </div>
        {p.manageSchool && (
          <button className="btn primary" onClick={() => setInviting(true)}>
            + Invite
          </button>
        )}
      </PageHeader>
      <div className="grid2">
        <Card title="Staff">
          {pg.error ? (
            <ErrorBox error={pg.error} onRetry={pg.reload} />
          ) : pg.loading ? (
            <Loading />
          ) : !pg.rows.length ? (
            <Empty>No one here yet.</Empty>
          ) : (
            <table className="t">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Role</th>
                  <th>Instructor license</th>
                  <th>Rate</th>
                </tr>
              </thead>
              <tbody>
                {pg.rows.map((m) => (
                  <tr key={m.user_id}>
                    <td>
                      <span
                        style={{
                          display: "inline-block",
                          width: 10,
                          height: 10,
                          borderRadius: 3,
                          background: m.color ?? "#CBD5E1",
                          marginRight: 6,
                        }}
                      />
                      {names[m.user_id] || <span className="mono">{m.user_id.slice(0, 8)}</span>}
                    </td>
                    <td>{roleLabel[m.role]}</td>
                    <td>
                      {m.license_expires ? (
                        <>
                          {fmtDate(m.license_expires)}{" "}
                          {soon(m.license_expires) && (
                            <Badge tone={new Date(m.license_expires) < new Date() ? "bad" : "warn"}>
                              {new Date(m.license_expires) < new Date() ? "expired" : "expiring"}
                            </Badge>
                          )}
                        </>
                      ) : (
                        "—"
                      )}
                    </td>
                    <td className="num">{m.hourly_rate != null ? `$${Number(m.hourly_rate).toFixed(2)}/h` : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <Pager {...pg} />
        </Card>
        {p.manageSchool && <Invites key={k} schoolId={schoolId} />}
      </div>
      {inviting && (
        <InviteModal
          schoolId={schoolId}
          onClose={() => setInviting(false)}
          onDone={() => {
            setInviting(false);
            setK((x) => x + 1);
          }}
        />
      )}
    </>
  );
}

function Invites({ schoolId }: { schoolId: string }) {
  const pg = usePaged((c: number | null) => invitesPage(supabase, schoolId, c ?? 0), schoolId);
  const [err, setErr] = useState<string | null>(null);
  return (
    <Card title="Pending invites">
      {err && <ErrorBox error={err} />}
      {pg.error ? (
        <ErrorBox error={pg.error} onRetry={pg.reload} />
      ) : pg.loading ? (
        <Loading />
      ) : !pg.rows.length ? (
        <Empty>No pending invites.</Empty>
      ) : (
        <table className="t">
          <tbody>
            {pg.rows.map((i) => (
              <tr key={i.id}>
                <td>
                  {i.email}
                  <div className="muted">
                    {roleLabel[i.role] ?? i.role} · expires {fmtDate(i.expires_at)}
                  </div>
                </td>
                <td>
                  <button
                    className="btn sm danger"
                    onClick={() => {
                      revokeInvite(supabase, i.id)
                        .then(pg.reload)
                        .catch((e: Error) => setErr(e.message));
                    }}
                  >
                    Revoke
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <Pager {...pg} />
      <p className="muted" style={{ fontSize: 12 }}>
        Invitees sign up with the same email; they join automatically on first sign-in.
      </p>
    </Card>
  );
}

function InviteModal({ schoolId, onClose, onDone }: { schoolId: string; onClose: () => void; onDone: () => void }) {
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<Exclude<Role, "owner">>("instructor");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      await inviteToSchool(supabase, schoolId, email, role);
      onDone();
    } catch (x) {
      setErr((x as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title="Invite staff" onClose={onClose}>
      <form onSubmit={submit}>
        {err && <ErrorBox error={err} />}
        <div className="field">
          <label htmlFor="ie">Email</label>
          <input id="ie" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="ir">Role</label>
          <select id="ir" value={role} onChange={(e) => setRole(e.target.value as Exclude<Role, "owner">)}>
            <option value="instructor">Instructor</option>
            <option value="front_desk">Front desk</option>
            <option value="admin">Admin</option>
          </select>
        </div>
        <p className="muted" style={{ fontSize: 12 }}>
          Invite emails aren’t sent automatically yet. Ask them to sign up on this site with this email.
        </p>
        <div className="row">
          <button className="btn primary" disabled={busy}>
            Create invite
          </button>
          <button type="button" className="btn" onClick={onClose}>
            Cancel
          </button>
        </div>
      </form>
    </Modal>
  );
}
