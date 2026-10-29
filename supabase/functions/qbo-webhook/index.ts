// POST /functions/v1/qbo-webhook  (Intuit -> us; verify_jwt = false)
// 1. Verify intuit-signature = base64(HMAC-SHA256(raw body, QBO_WEBHOOK_VERIFIER_TOKEN)).
// 2. Store event ids (duplicates ignored) and queue "pull" jobs. 3. Answer 200 fast (< 3 s).
// The qbo-sync worker does the actual reads. Payload is the CloudEvents array format
// (Intuit's default since 2026); the legacy {eventNotifications:[...]} shape is converted.
import { serviceClient } from "../_shared/clients.ts";
import { env } from "../_shared/env.ts";
import { verifyIntuitSignature } from "../_shared/qbo.ts";

async function sha256(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
async function toCloudEvents(body: any): Promise<any[]> {
  if (Array.isArray(body)) return body;
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
  const out: any[] = [];
  for (const n of body?.eventNotifications ?? []) {
    for (const e of n?.dataChangeEvent?.entities ?? []) {
      const op = String(e.operation ?? "update").toLowerCase();
      out.push({
        id: await sha256(`${n.realmId}|${e.name}|${e.id}|${e.operation}|${e.lastUpdated}`),
        type: `qbo.${String(e.name).toLowerCase()}.${
          op === "update" ? "updated" : op === "create" ? "created" : op
        }.v1`,
        intuitaccountid: String(n.realmId),
        intuitentityid: String(e.id),
        time: e.lastUpdated,
      });
    }
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const raw = await req.text();
  if (raw.length > 2_000_000) return new Response("too large", { status: 413 });
  const ok = await verifyIntuitSignature(raw, req.headers.get("intuit-signature"), env("QBO_WEBHOOK_VERIFIER_TOKEN"));
  if (!ok) return new Response("bad signature", { status: 401 });

  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return new Response("bad json", { status: 400 });
  }
  const events = await toCloudEvents(body);
  const { data, error } = await serviceClient().rpc("svc_qbo_record_events", { p_events: events });
  if (error) {
    console.error("record events failed", error.code);
    return new Response("retry", { status: 500 }); // Intuit retries later; ids make that safe
  }
  return new Response(JSON.stringify({ received: events.length, new: data }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
