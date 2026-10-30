/** Lightweight request validation for Edge Functions. */

export function requireMethod(req: Request, allowed: string[]): Response | null {
  if (!allowed.includes(req.method)) {
    return new Response("method not allowed", { status: 405, headers: { Allow: allowed.join(", ") } });
  }
  return null;
}

export function clampInt(v: unknown, min: number, max: number, fallback: number): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

export function asUuid(v: unknown): string | null {
  if (typeof v !== "string") return null;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)
    ? v
    : null;
}

export function asEmail(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const s = v.trim().toLowerCase();
  if (s.length < 3 || s.length > 254 || !s.includes("@")) return null;
  return s;
}

/** Reject oversized JSON bodies early (DoS). */
export async function readJsonLimited(req: Request, maxBytes = 64_000): Promise<
  { ok: true; body: unknown } | { ok: false; response: Response }
> {
  const len = Number(req.headers.get("content-length") ?? 0);
  if (len > maxBytes) return { ok: false, response: new Response("payload too large", { status: 413 }) };
  const text = await req.text();
  if (text.length > maxBytes) return { ok: false, response: new Response("payload too large", { status: 413 }) };
  if (!text) return { ok: true, body: {} };
  try {
    return { ok: true, body: JSON.parse(text) };
  } catch {
    return { ok: false, response: new Response("invalid json", { status: 400 }) };
  }
}
