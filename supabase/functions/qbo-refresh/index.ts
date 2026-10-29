// Cron (every 30 min): refresh access tokens that expire within 15 minutes.
// Header x-cron-secret required. Refresh tokens rotate, so the newest pair is always stored.
import { json, requireCron } from "../_shared/http.ts";
import { serviceClient } from "../_shared/clients.ts";
import { accessTokenFor } from "../_shared/qbo.ts";

Deno.serve(async (req) => {
  const deny = requireCron(req);
  if (deny) return deny;
  const svc = serviceClient();
  const { data, error } = await svc.rpc("svc_qbo_due_for_refresh", { p_within_minutes: 15 });
  if (error) return json(req, { error: error.message }, 500);
  let ok = 0, failed = 0;
  for (const row of (data ?? []) as { school_id: string }[]) {
    try {
      await accessTokenFor(svc, row.school_id);
      ok++;
    } catch {
      failed++;
    }
  }
  return json(req, { refreshed: ok, failed });
});
