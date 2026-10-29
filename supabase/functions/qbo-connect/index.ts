// POST /functions/v1/qbo-connect  (owner/admin JWT)
//   { "school_id": "...", "action": "connect" }    -> { url }  open it in the browser
//   { "school_id": "...", "action": "disconnect" } -> revokes at Intuit, wipes tokens
import { json, pgStatus, preflight } from "../_shared/http.ts";
import { serviceClient, userClient } from "../_shared/clients.ts";
import { env } from "../_shared/env.ts";
import { AUTHORIZE_URL, revokeToken, SCOPE } from "../_shared/qbo.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json(req, { error: "POST only" }, 405);
  const { school_id, action = "connect" } = await req.json().catch(() => ({}));
  if (!school_id) return json(req, { error: "school_id required" }, 400);
  const db = userClient(req);

  if (action === "connect") {
    const { data: state, error } = await db.rpc("qbo_begin_connect", { p_school_id: school_id });
    if (error) return json(req, { error: error.message }, pgStatus(error.code));
    const url = new URL(AUTHORIZE_URL);
    url.searchParams.set("client_id", env("QBO_CLIENT_ID"));
    url.searchParams.set("response_type", "code");
    url.searchParams.set("scope", SCOPE);
    url.searchParams.set("redirect_uri", env("QBO_REDIRECT_URI"));
    url.searchParams.set("state", state as string);
    return json(req, { url: url.toString() });
  }

  if (action === "disconnect") {
    // Read the refresh token first (service), then let the DB check the caller is a manager.
    const svc = serviceClient();
    const { data: tok } = await svc.rpc("svc_qbo_get_tokens", { p_school_id: school_id }).maybeSingle();
    const { error } = await db.rpc("qbo_disconnect", { p_school_id: school_id });
    if (error) return json(req, { error: error.message }, pgStatus(error.code));
    const refresh = (tok as { refresh_token?: string } | null)?.refresh_token;
    if (refresh) {
      await revokeToken(refresh).catch(() => console.error("Intuit revoke failed (tokens already wiped locally)"));
    }
    return json(req, { status: "disconnected" });
  }
  return json(req, { error: "Unknown action" }, 400);
});
