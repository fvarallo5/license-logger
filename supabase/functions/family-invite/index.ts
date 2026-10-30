// POST /functions/v1/family-invite   (signed-in user's JWT required)
//   { "action": "create", "student_id": "...", "relationship": "parent", "email": "optional@x.com", "max_uses": 2 }
//   { "action": "redeem", "code": "LL-7Q4K-M2" }
//   { "action": "revoke_link", "link_id": "..." }   |  { "action": "revoke_invite", "invite_id": "..." }
// All permission checks happen in the database RPCs (RLS + SECURITY DEFINER), as the caller.
import { json, pgStatus, preflight } from "../_shared/http.ts";
import { userClient } from "../_shared/clients.ts";
import { escapeHtml, layout, sendEmail } from "../_shared/email.ts";
import { envOr } from "../_shared/env.ts";
import { rateLimit } from "../_shared/rate_limit.ts";
import { asEmail, asUuid, clampInt, readJsonLimited } from "../_shared/validate.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json(req, { error: "POST only" }, 405);

  const db = userClient(req);
  const { data: userData } = await db.auth.getUser();
  const uid = userData.user?.id ?? "anon";
  if (!rateLimit(`family-invite:${uid}`, { capacity: 20, refillPerSec: 0.2 })) {
    return json(req, { error: "rate limited" }, 429);
  }

  const parsed = await readJsonLimited(req, 16_000);
  if (!parsed.ok) return parsed.response;
  const body = (parsed.body ?? {}) as Record<string, unknown>;

  switch (body.action) {
    case "create": {
      const studentId = asUuid(body.student_id);
      if (!studentId) return json(req, { error: "student_id required" }, 400);
      const email = body.email == null || body.email === "" ? null : asEmail(body.email);
      if (body.email && !email) return json(req, { error: "invalid email" }, 400);
      const maxUses = clampInt(body.max_uses ?? 2, 1, 10, 2);
      const relationship = typeof body.relationship === "string" && body.relationship
        ? body.relationship.slice(0, 40)
        : "parent";

      const { data, error } = await db.rpc("create_family_invite", {
        p_student_id: studentId,
        p_relationship: relationship,
        p_max_uses: maxUses,
        p_email: email,
      });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      const invite = data as { invite_id: string; code: string; expires_at: string };

      let emailed = false;
      if (email) {
        const { data: kid } = await db.from("students").select("first_name, school_id, schools(name)")
          .eq("id", studentId).maybeSingle();
        const first = kid?.first_name ?? "Your student";
        // deno-lint-ignore no-explicit-any -- PostgREST embed
        const schoolName = (kid as any)?.schools?.name as string | undefined;
        const where = kid?.school_id && schoolName ? ` (${schoolName})` : " (practising with family)";
        const appUrl = envOr("LL_APP_LINK", "https://app.licenselogger.com");
        const r = await sendEmail({
          to: email,
          subject: `${first} invited you to LicenseLogger`,
          text:
            `${first}${where} wants you to follow their driving hours on LicenseLogger.\n\nYour code: ${invite.code}\n\n` +
            `Get the app: ${appUrl}\nOpen it, choose "I'm a parent or guardian", and enter the code. It expires ${
              invite.expires_at.slice(0, 10)
            }.`,
          html: layout(
            `${first} invited you to LicenseLogger`,
            `<p>${escapeHtml(first)}${escapeHtml(where)} wants you to follow their driving hours and sign off drives.</p>
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
      return json(req, { ...invite, emailed });
    }
    case "redeem": {
      const code = String(body.code ?? "").trim().slice(0, 32);
      if (!code) return json(req, { error: "code required" }, 400);
      const { data, error } = await db.rpc("redeem_family_invite", { p_code: code });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      const status = (data as { status: string }).status;
      return json(req, data, status === "ok" ? 200 : status === "rate_limited" ? 429 : 400);
    }
    case "revoke_link": {
      const linkId = asUuid(body.link_id);
      if (!linkId) return json(req, { error: "link_id required" }, 400);
      const { error } = await db.rpc("revoke_family_link", { p_link_id: linkId });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      return json(req, { status: "ok" });
    }
    case "revoke_invite": {
      const inviteId = asUuid(body.invite_id);
      if (!inviteId) return json(req, { error: "invite_id required" }, 400);
      const { error } = await db.rpc("revoke_family_invite", { p_invite_id: inviteId });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      return json(req, { status: "ok" });
    }
    default:
      return json(req, { error: "Unknown action" }, 400);
  }
});
