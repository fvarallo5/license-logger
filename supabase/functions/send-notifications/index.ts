// Cron (every minute): send queued emails through Resend. Header x-cron-secret required.
// Each email carries its outbox idempotency_key as Resend's Idempotency-Key: retries never double-send.
// Also runs daily housekeeping when called with ?housekeeping=1.
import { json, requireCron } from "../_shared/http.ts";
import { rateLimit } from "../_shared/rate_limit.ts";
import { serviceClient } from "../_shared/clients.ts";
import { envOr } from "../_shared/env.ts";
import { type Email, escapeHtml, layout, sendEmail } from "../_shared/email.ts";

type Note = {
  id: string;
  kind: string;
  to_email: string | null;
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
  payload: any;
  attempts: number;
  idempotency_key: string;
};

function render(n: Note): Email | null {
  if (!n.to_email) return null;
  const app = envOr("LL_APP_LINK", "https://app.licenselogger.com");
  if (n.kind === "drive_pending") {
    const first = n.payload.student_first_name ?? "Your student";
    const mins = Number(n.payload.minutes ?? 0);
    const hm = mins >= 60 ? `${Math.floor(mins / 60)}h ${String(mins % 60).padStart(2, "0")}m` : `${mins}m`;
    return {
      to: n.to_email,
      subject: `${first} logged a ${hm} drive — sign off?`,
      text:
        `${first} finished a ${hm} drive on ${n.payload.local_date}. Open LicenseLogger to review and sign it: ${app}`,
      html: layout(
        `${first} logged a ${hm} drive`,
        `<p>${escapeHtml(first)} finished a drive on ${escapeHtml(String(n.payload.local_date))}` +
          (n.payload.night_minutes > 0 ? ` (${Number(n.payload.night_minutes)} min at night)` : "") + `.</p>
         <p>Review and sign it in the app so it counts toward the log.</p>
         <p><a href="${escapeHtml(app)}">Open LicenseLogger</a></p>`,
      ),
    };
  }
  return null;
}

Deno.serve(async (req) => {
  const deny = requireCron(req);
  if (deny) return deny;
  if (!rateLimit("send-notifications", { capacity: 120, refillPerSec: 2 })) {
    return json(req, { error: "rate limited" }, 429);
  }
  const svc = serviceClient();

  if (new URL(req.url).searchParams.get("housekeeping") === "1") {
    const { data: hk } = await svc.rpc("svc_housekeeping");
    const { data: expired } = await svc.rpc("svc_expire_exports");
    const paths = ((expired ?? []) as { storage_path: string | null }[]).map((r) => r.storage_path).filter(
      Boolean,
    ) as string[];
    for (let i = 0; i < paths.length; i += 100) await svc.storage.from("exports").remove(paths.slice(i, i + 100));
    return json(req, { housekeeping: hk, exports_removed: paths.length });
  }

  const { data, error } = await svc.rpc("svc_claim_notifications", { p_limit: 50 });
  if (error) return json(req, { error: error.message }, 500);
  let sent = 0, failed = 0;
  for (const n of (data ?? []) as Note[]) {
    const mail = render(n);
    if (!mail) {
      await svc.rpc("svc_finish_notification", { p_id: n.id, p_ok: false, p_error: "no address or template" });
      failed++;
      continue;
    }
    const r = await sendEmail(mail, n.idempotency_key);
    await svc.rpc("svc_finish_notification", { p_id: n.id, p_ok: r.ok, p_error: r.error ?? null });
    r.ok ? sent++ : failed++;
  }
  return json(req, { sent, failed });
});
