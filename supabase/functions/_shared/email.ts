import { env } from "./env.ts";

export type Email = { to: string; subject: string; html: string; text: string };

/**
 * Sends through Resend's HTTP API. The Idempotency-Key makes retries safe:
 * Resend returns the original result instead of sending a second email.
 */
export async function sendEmail(mail: Email, idempotencyKey: string): Promise<{ ok: boolean; error?: string }> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
      "Idempotency-Key": idempotencyKey.slice(0, 256),
    },
    body: JSON.stringify({
      from: env("EMAIL_FROM"),
      to: [mail.to],
      subject: mail.subject,
      html: mail.html,
      text: mail.text,
    }),
  });
  if (res.ok) return { ok: true };
  const body = await res.text();
  return { ok: false, error: `Resend ${res.status}: ${body.slice(0, 300)}` };
}

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
}

export function layout(title: string, bodyHtml: string): string {
  return `<!doctype html><html><body style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:#f6f7f9;padding:24px">
<div style="max-width:520px;margin:auto;background:#fff;border-radius:12px;padding:24px;color:#0f1b2d">
<h1 style="font-size:20px;margin:0 0 12px">${escapeHtml(title)}</h1>${bodyHtml}
<p style="color:#6b7280;font-size:12px;margin-top:24px">LicenseLogger · You can turn these emails off in the app under Profile.</p>
</div></body></html>`;
}
