import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { qboStatus } from "../lib/api";
import { useSchool } from "../session";
import { fmtDateTime } from "../lib/format";
import type { QboStatus } from "../lib/types";
import { Badge, Card, ErrorBox, Loading, PageHeader } from "../components/ui";

export default function QuickBooks() {
  const schoolId = useSchool().school_id;
  const [d, setD] = useState<QboStatus | null | undefined>(undefined);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    qboStatus(supabase, schoolId)
      .then(setD)
      .catch((e: Error) => setErr(e.message));
  }, [schoolId]);
  const conn = d && d.status && d.status !== "disconnected" ? d : null;
  return (
    <>
      <PageHeader title="QuickBooks" desc="Sync students, invoices and payments with QuickBooks Online." />
      <div className="alert warn">
        QuickBooks connect is not switched on yet. It needs the QuickBooks server functions deployed and Intuit’s app approval. Until then
        this page only shows status.
      </div>
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
          <ErrorBox error={err} />
        ) : d === undefined ? (
          <Loading />
        ) : conn ? (
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
        ) : (
          <>
            <p>This school isn’t connected to QuickBooks.</p>
            <button className="btn" disabled title="Available once QuickBooks functions are deployed">
              Connect to QuickBooks
            </button>
          </>
        )}
      </Card>
    </>
  );
}
