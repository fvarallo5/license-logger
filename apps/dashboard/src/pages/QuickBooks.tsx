import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { friendly, qboConnect, qboStatus, qboSyncNow } from "../lib/api";
import { useSchool } from "../session";
import { fmtDateTime } from "../lib/format";
import type { QboStatus } from "../lib/types";
import { Badge, Card, ErrorBox, Loading, PageHeader } from "../components/ui";

const ENABLE = import.meta.env.VITE_ENABLE_QBO === "1";

export default function QuickBooks() {
  const schoolId = useSchool().school_id;
  const [d, setD] = useState<QboStatus | null | undefined>(undefined);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  const load = useCallback(() => {
    setErr(null);
    qboStatus(supabase, schoolId)
      .then(setD)
      .catch((e: Error) => setErr(e.message));
  }, [schoolId]);

  useEffect(() => {
    load();
  }, [load]);

  const conn = d && d.status && d.status !== "disconnected" ? d : null;

  async function connect() {
    setBusy(true);
    setNote(null);
    try {
      const r = await qboConnect(supabase, schoolId);
      if ("notDeployed" in r) {
        setNote(r.message);
        return;
      }
      window.location.href = r.url;
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  async function syncNow() {
    setBusy(true);
    setNote(null);
    try {
      await qboSyncNow(supabase, schoolId);
      setNote("Sync queued.");
      load();
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader title="QuickBooks" desc="Sync students, invoices and payments with QuickBooks Online." />
      {!ENABLE && (
        <div className="alert warn">
          Connect is behind <code>VITE_ENABLE_QBO=1</code>. Deploy <code>qbo-*</code> edge functions and set Intuit secrets first (see
          docs/PHASE5_EXPORT_QBO.md). Status still loads.
        </div>
      )}
      {note && (
        <div className="alert warn" role="status">
          {note}
        </div>
      )}
      <Card
        title="Connection"
        actions={
          d === undefined ? null : conn ? (
            <Badge tone={conn.status === "active" ? "ok" : "warn"}>{conn.status}</Badge>
          ) : (
            <Badge>not connected</Badge>
          )
        }
      >
        {err ? (
          <ErrorBox error={err} onRetry={load} />
        ) : d === undefined ? (
          <Loading />
        ) : conn ? (
          <>
            <dl className="kv">
              <dt>Company</dt>
              <dd>{conn.company_name ?? "—"}</dd>
              <dt>Last sync</dt>
              <dd>{fmtDateTime(conn.last_sync_at)}</dd>
              <dt>Queue</dt>
              <dd>
                {conn.queued} waiting · {conn.failed} retrying ·{" "}
                {conn.dead > 0 ? <Badge tone="bad">{conn.dead} need attention</Badge> : "0 stuck"}
              </dd>
              {conn.last_error && (
                <>
                  <dt>Last error</dt>
                  <dd className="muted">{conn.last_error}</dd>
                </>
              )}
            </dl>
            <div className="row" style={{ marginTop: "0.75rem" }}>
              <button className="btn primary" disabled={!ENABLE || busy} onClick={() => void syncNow()}>
                Sync now
              </button>
            </div>
          </>
        ) : (
          <>
            <p>This school isn’t connected to QuickBooks.</p>
            <button
              className="btn primary"
              disabled={!ENABLE || busy}
              title={ENABLE ? "Start Intuit OAuth" : "Set VITE_ENABLE_QBO=1 after deploying qbo-* functions"}
              onClick={() => void connect()}
            >
              Connect to QuickBooks
            </button>
          </>
        )}
      </Card>
    </>
  );
}
