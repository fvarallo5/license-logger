// POST /functions/v1/family-invite   (signed-in user's JWT required)
//   { "action": "create", "student_id": "...", "relationship": "parent", "email": "optional@x.com", "max_uses": 2 }
//   { "action": "redeem", "code": "LL-7Q4K-M2" }
//   { "action": "revoke_link", "link_id": "..." }   |  { "action": "revoke_invite", "invite_id": "..." }
// All permission checks happen in the database RPCs (RLS + SECURITY DEFINER), as the caller.
import { json, pgStatus, preflight } from "../_shared/http.ts";
import { userClient } from "../_shared/clients.ts";
import { escapeHtml, layout, sendEmail } from "../_shared/email.ts";
import { envOr } from "../_shared/env.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json(req, { error: "POST only" }, 405);
  const db = userClient(req);
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return json(req, { error: "Invalid JSON" }, 400);
  }

  switch (body.action) {
    case "create": {
      const { data, error } = await db.rpc("create_family_invite", {
        p_student_id: body.student_id,
        p_relationship: body.relationship ?? "parent",
        p_max_uses: body.max_uses ?? 2,
        p_email: body.email ?? null,
      });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      const invite = data as { invite_id: string; code: string; expires_at: string };

      let emailed = false;
      if (body.email && typeof body.email === "string") {
        // Works the same for school students and independent students (school_id null).
        const { data: kid } = await db.from("students").select("first_name, school_id, schools(name)")
          .eq("id", body.student_id).maybeSingle();
        const first = kid?.first_name ?? "Your student";
        // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
        const schoolName = (kid as any)?.schools?.name as string | undefined;
        const where = kid?.school_id && schoolName ? ` (${schoolName})` : " (practising with family)";
        const appUrl = envOr("LL_APP_LINK", "https://licenselogger.example/app");
        const r = await sendEmail({
          to: body.email,
          subject: `${first} invited you to LicenseLogger`,
          text:
            `${first}${where} wants you to follow their driving hours on LicenseLogger.\n\nYour code: ${invite.code}\n\n` +
            `Get the app: ${appUrl}\nOpen it, choose "I'm a parent or guardian", and enter the code. It expires ${
              invite.expires_at.slice(0, 10)
            }.`,
          html: layout(
            `${first} invited you to LicenseLogger`,
            `<p>${escapeHtml(first)}${
              escapeHtml(where)
            } wants you to follow their driving hours and sign off drives.</p>
             <p style="font-size:28px;font-weight:700;letter-spacing:2px;font-family:ui-monospace,monospace">${
              escapeHtml(invite.code)
            }</p>
             <p>Open the app, choose <b>I'm a parent or guardian</b>, and enter the code. It expires ${
              escapeHtml(invite.expires_at.slice(0, 10))
            }.</p>
             <p><a href="${escapeHtml(appUrl)}">Get LicenseLogger</a></p>`,
          ),
        }, `family_invite:${invite.invite_id}`);
        emailed = r.ok;
        if (!r.ok) console.error("invite email failed", invite.invite_id, r.error);
      }
      // The code is returned to the caller (to show on screen) and never stored or logged.
      return json(req, { ...invite, emailed });
    }
    case "redeem": {
      const { data, error } = await db.rpc("redeem_family_invite", { p_code: String(body.code ?? "") });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      const status = (data as { status: string }).status;
      return json(req, data, status === "ok" ? 200 : status === "rate_limited" ? 429 : 400);
    }
    case "revoke_link": {
      const { error } = await db.rpc("revoke_family_link", { p_link_id: body.link_id });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      return json(req, { status: "ok" });
    }
    case "revoke_invite": {
      const { error } = await db.rpc("revoke_family_invite", { p_invite_id: body.invite_id });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      return json(req, { status: "ok" });
    }
    default:
      return json(req, { error: "Unknown action" }, 400);
  }
});
