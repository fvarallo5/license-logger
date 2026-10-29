// GET /functions/v1/qbo-callback?code=...&state=...&realmId=...
// Intuit redirects the browser here after the owner approves. No Supabase JWT (verify_jwt = false);
// the one-time `state` from qbo_begin_connect() proves who started it.
import { serviceClient } from "../_shared/clients.ts";
import { env, envOr } from "../_shared/env.ts";
import { exchangeCode, qboFetch } from "../_shared/qbo.ts";

function back(path: string): Response {
  return Response.redirect(`${env("LL_DASHBOARD_URL")}${path}`, 302);
}

Deno.serve(async (req) => {
  const u = new URL(req.url);
  if (u.searchParams.get("error")) return back("/settings?qbo=cancelled");
  const code = u.searchParams.get("code");
  const state = u.searchParams.get("state");
  const realmId = u.searchParams.get("realmId");
  if (!code || !state || !realmId) return back("/settings?qbo=error");

  const svc = serviceClient();
  const { data: st, error } = await svc.rpc("svc_qbo_consume_state", { p_state: state }).maybeSingle();
  const s = st as { school_id: string; user_id: string } | null;
  if (error || !s) return back("/settings?qbo=expired");

  try {
    const t = await exchangeCode(code);
    const environment = envOr("QBO_ENVIRONMENT", "production");
    let companyName = "";
    const info = await qboFetch({ token: t.access_token, realm: realmId, environment }, `companyinfo/${realmId}`);
    if (info.status === 200) companyName = info.json?.CompanyInfo?.CompanyName ?? "";

    const { error: e2 } = await svc.rpc("svc_qbo_store_tokens", {
      p_school_id: s.school_id,
      p_realm_id: realmId,
      p_access_token: t.access_token,
      p_refresh_token: t.refresh_token,
      p_access_expires_in: t.expires_in,
      p_refresh_expires_in: t.x_refresh_token_expires_in,
      p_user_id: s.user_id,
      p_environment: environment,
      p_company_name: companyName,
    });
    if (e2) {
      console.error("store tokens failed", e2.code);
      return back(e2.code === "23505" ? "/settings?qbo=already_linked" : "/settings?qbo=error");
    }
    return back("/settings?qbo=connected");
  } catch (_e) {
    console.error("QuickBooks connect failed"); // never log codes or tokens
    return back("/settings?qbo=error");
  }
});
