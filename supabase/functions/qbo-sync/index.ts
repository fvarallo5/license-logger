// Cron (every minute): drain private.qbo_sync_jobs.
//   push: app change -> QuickBooks (requestid = job id, so a retry never creates a duplicate)
//   pull: webhook said something changed -> read it -> svc_qbo_apply_entity (stale data ignored)
// Header x-cron-secret required. Runs at most ~45 s per call.
import { json, requireCron } from "../_shared/http.ts";
import { serviceClient } from "../_shared/clients.ts";
import { envOr } from "../_shared/env.ts";
import { accessTokenFor, QboAuthError, qboFetch } from "../_shared/qbo.ts";

type Job = {
  id: string;
  school_id: string;
  direction: "push" | "pull";
  entity: "customer" | "invoice" | "payment";
  local_id: string | null;
  qbo_id: string | null;
  attempts: number;
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
  payload: any;
};

const ENTITY = { customer: "Customer", invoice: "Invoice", payment: "Payment" } as const;

// deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
function customerBody(p: any) {
  return {
    ...(p.qbo_customer_id ? { Id: p.qbo_customer_id, SyncToken: p.qbo_sync_token, sparse: true } : {}),
    DisplayName: p.display_name,
    ...(p.email ? { PrimaryEmailAddr: { Address: p.email } } : {}),
    ...(p.phone ? { PrimaryPhone: { FreeFormNumber: p.phone } } : {}),
    Active: p.active,
  };
}

// deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
function invoiceBody(p: any) {
  if (!p.customer_qbo_id) throw new Error("Customer is not in QuickBooks yet (will retry)");
  const defaultItem = envOr("QBO_DEFAULT_ITEM_ID", "1");
  return {
    ...(p.qbo_invoice_id ? { Id: p.qbo_invoice_id, SyncToken: p.qbo_sync_token, sparse: true } : {}),
    CustomerRef: { value: p.customer_qbo_id },
    TxnDate: p.txn_date,
    ...(p.due_date ? { DueDate: p.due_date } : {}),
    ...(p.doc_number ? { DocNumber: p.doc_number } : {}),
    ...(p.memo ? { CustomerMemo: { value: String(p.memo).slice(0, 1000) } } : {}),
    // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
    Line: (p.lines ?? []).map((l: any) => ({
      DetailType: "SalesItemLineDetail",
      Amount: Number(l.amount),
      Description: l.description,
      SalesItemLineDetail: {
        ItemRef: { value: l.qbo_item_id ?? defaultItem },
        Qty: Number(l.quantity),
        UnitPrice: Number(l.unit_price),
      },
    })),
  };
}

// deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
function paymentBody(p: any) {
  if (!p.customer_qbo_id) throw new Error("Customer is not in QuickBooks yet (will retry)");
  return {
    ...(p.qbo_payment_id ? { Id: p.qbo_payment_id, SyncToken: p.qbo_sync_token, sparse: true } : {}),
    CustomerRef: { value: p.customer_qbo_id },
    TotalAmt: Number(p.amount),
    TxnDate: p.received_on,
    ...(p.reference ? { PaymentRefNum: String(p.reference).slice(0, 21) } : {}),
    ...(p.invoice_qbo_id
      ? { Line: [{ Amount: Number(p.amount), LinkedTxn: [{ TxnId: p.invoice_qbo_id, TxnType: "Invoice" }] }] }
      : {}),
  };
}

/** Outcome of one sync job, recorded via svc_qbo_finish_job. */
type JobResult = {
  ok: boolean;
  error?: string | null;
  qboId?: string | null;
  syncToken?: string | null;
  updatedAt?: string | null;
};

async function runJob(
  svc: ReturnType<typeof serviceClient>,
  job: Job,
  auth: Awaited<ReturnType<typeof accessTokenFor>>,
): Promise<JobResult> {
  const name = ENTITY[job.entity];
  if (job.direction === "push") {
    if (!job.payload) return { ok: true }; // row was deleted locally; nothing to send
    const body = job.entity === "customer"
      ? customerBody(job.payload)
      : job.entity === "invoice"
      ? invoiceBody(job.payload)
      : paymentBody(job.payload);
    const r = await qboFetch(auth, job.entity, { method: "POST", body, requestId: job.id });
    if (r.status >= 300) {
      return { ok: false, error: `QuickBooks ${r.status}: ${JSON.stringify(r.json?.Fault ?? r.json).slice(0, 400)}` };
    }
    const obj = r.json?.[name];
    return { ok: true, qboId: obj?.Id, syncToken: obj?.SyncToken, updatedAt: obj?.MetaData?.LastUpdatedTime };
  }
  // pull
  const r = await qboFetch(auth, `${job.entity}/${encodeURIComponent(job.qbo_id!)}`);
  if (r.status === 400 || r.status === 404) {
    const fault = JSON.stringify(r.json ?? {});
    if (/not found|deleted/i.test(fault)) {
      await svc.rpc("svc_qbo_mark_deleted", { p_school_id: job.school_id, p_entity: job.entity, p_qbo_id: job.qbo_id });
      return { ok: true };
    }
  }
  if (r.status >= 300) return { ok: false, error: `QuickBooks ${r.status}` };
  const { error } = await svc.rpc("svc_qbo_apply_entity", {
    p_school_id: job.school_id,
    p_entity: job.entity,
    p_obj: r.json?.[name],
  });
  if (error) return { ok: false, error: `apply failed: ${error.message}` };
  return { ok: true };
}

Deno.serve(async (req) => {
  const deny = requireCron(req);
  if (deny) return deny;
  const svc = serviceClient();
  const started = Date.now();
  const { data, error } = await svc.rpc("svc_qbo_claim_jobs", { p_limit: 25 });
  if (error) return json(req, { error: error.message }, 500);

  const tokens = new Map<string, Awaited<ReturnType<typeof accessTokenFor>> | null>();
  let done = 0, failed = 0;
  for (const job of (data ?? []) as Job[]) {
    if (Date.now() - started > 45_000) {
      // Out of time: give it back immediately (no backoff penalty beyond this attempt).
      await svc.rpc("svc_qbo_finish_job", { p_job_id: job.id, p_ok: false, p_error: "deferred (time budget)" });
      continue;
    }
    try {
      if (!tokens.has(job.school_id)) {
        tokens.set(
          job.school_id,
          await accessTokenFor(svc, job.school_id).catch((e) => {
            if (e instanceof QboAuthError) return null;
            throw e;
          }),
        );
      }
      const auth = tokens.get(job.school_id);
      if (!auth) {
        await svc.rpc("svc_qbo_finish_job", {
          p_job_id: job.id,
          p_ok: false,
          p_error: "QuickBooks not connected / needs reconnect",
        });
        failed++;
        continue;
      }
      const res = await runJob(svc, job, auth);
      await svc.rpc("svc_qbo_finish_job", {
        p_job_id: job.id,
        p_ok: res.ok,
        p_error: res.error ?? null,
        p_qbo_id: res.qboId ?? null,
        p_sync_token: res.syncToken ?? null,
        p_qbo_updated_at: res.updatedAt ?? null,
      });
      res.ok ? done++ : failed++;
    } catch (e) {
      await svc.rpc("svc_qbo_finish_job", {
        p_job_id: job.id,
        p_ok: false,
        p_error: String((e as Error).message ?? e).slice(0, 500),
      });
      failed++;
    }
  }
  return json(req, { claimed: (data ?? []).length, done, failed });
});
