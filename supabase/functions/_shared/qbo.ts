// QuickBooks Online helpers. Docs:
//  OAuth 2.0: https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/oauth-2.0
//  Webhooks (CloudEvents): https://developer.intuit.com/app/developer/qbo/docs/develop/webhooks/cloudevents-webhooks
// Access tokens last 60 minutes. Refresh tokens roll (~100 days) and now have a 5-year hard limit;
// always store the newest refresh token Intuit returns.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { env, envOr } from "./env.ts";

export const AUTHORIZE_URL = "https://appcenter.intuit.com/connect/oauth2";
const TOKEN_URL = "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer";
const REVOKE_URL = "https://developer.api.intuit.com/v2/oauth2/tokens/revoke";
export const SCOPE = "com.intuit.quickbooks.accounting";

export type TokenResponse = {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  x_refresh_token_expires_in: number;
};

export class QboAuthError extends Error {}

function basicAuth(): string {
  return "Basic " + btoa(`${env("QBO_CLIENT_ID")}:${env("QBO_CLIENT_SECRET")}`);
}

async function tokenRequest(body: Record<string, string>): Promise<TokenResponse> {
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: {
      Authorization: basicAuth(),
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams(body),
  });
  const text = await res.text();
  if (!res.ok) {
    // invalid_grant = refresh token expired/revoked -> the school must reconnect.
    if (text.includes("invalid_grant")) throw new QboAuthError("invalid_grant");
    throw new Error(`Intuit token endpoint ${res.status}`);
  }
  return JSON.parse(text) as TokenResponse;
}

export function exchangeCode(code: string): Promise<TokenResponse> {
  return tokenRequest({ grant_type: "authorization_code", code, redirect_uri: env("QBO_REDIRECT_URI") });
}

export function refreshTokens(refreshToken: string): Promise<TokenResponse> {
  return tokenRequest({ grant_type: "refresh_token", refresh_token: refreshToken });
}

export async function revokeToken(token: string): Promise<void> {
  await fetch(REVOKE_URL, {
    method: "POST",
    headers: { Authorization: basicAuth(), Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ token }),
  });
}

export function apiBase(environment: string): string {
  return environment === "sandbox" ? "https://sandbox-quickbooks.api.intuit.com" : "https://quickbooks.api.intuit.com";
}

export const MINOR_VERSION = envOr("QBO_MINOR_VERSION", "75");

/** Returns a valid access token for the school, refreshing (and storing the new pair) when close to expiry. */
export async function accessTokenFor(
  svc: SupabaseClient,
  schoolId: string,
): Promise<{ token: string; realm: string; environment: string }> {
  const { data, error } = await svc.rpc("svc_qbo_get_tokens", { p_school_id: schoolId }).maybeSingle();
  if (error) throw new Error(`token lookup failed: ${error.message}`);
  const row = data as {
    realm_id: string;
    environment: string;
    access_token: string;
    refresh_token: string;
    access_expires_at: string;
  } | null;
  if (!row) throw new QboAuthError("not_connected");
  const expiresAt = row.access_expires_at ? Date.parse(row.access_expires_at) : 0;
  if (expiresAt - Date.now() > 5 * 60_000) {
    return { token: row.access_token, realm: row.realm_id, environment: row.environment };
  }

  try {
    const t = await refreshTokens(row.refresh_token);
    const { error: e2 } = await svc.rpc("svc_qbo_store_tokens", {
      p_school_id: schoolId,
      p_realm_id: row.realm_id,
      p_access_token: t.access_token,
      p_refresh_token: t.refresh_token,
      p_access_expires_in: t.expires_in,
      p_refresh_expires_in: t.x_refresh_token_expires_in,
      p_environment: row.environment,
    });
    if (e2) throw new Error(`token store failed: ${e2.message}`);
    return { token: t.access_token, realm: row.realm_id, environment: row.environment };
  } catch (e) {
    if (e instanceof QboAuthError) {
      await svc.rpc("svc_qbo_mark_error", {
        p_school_id: schoolId,
        p_error: "QuickBooks needs to be reconnected",
        p_needs_reauth: true,
      });
    }
    throw e;
  }
}

/** Calls the Accounting API. requestId makes POSTs idempotent on Intuit's side. */
export async function qboFetch(
  auth: { token: string; realm: string; environment: string },
  path: string,
  init: { method?: string; body?: unknown; requestId?: string } = {},
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
): Promise<{ status: number; json: any }> {
  const url = new URL(`${apiBase(auth.environment)}/v3/company/${auth.realm}/${path}`);
  url.searchParams.set("minorversion", MINOR_VERSION);
  if (init.requestId) url.searchParams.set("requestid", init.requestId);
  const res = await fetch(url, {
    method: init.method ?? "GET",
    headers: {
      Authorization: `Bearer ${auth.token}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
  });
  const text = await res.text();
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
  let parsed: any = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = { raw: text.slice(0, 300) };
  }
  return { status: res.status, json: parsed };
}

/** base64(HMAC-SHA256(rawBody, verifierToken)) must equal the intuit-signature header. */
export async function verifyIntuitSignature(
  rawBody: string,
  signature: string | null,
  verifierToken: string,
): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(verifierToken),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody)));
  const expected = btoa(String.fromCharCode(...mac));
  const a = new TextEncoder().encode(expected), b = new TextEncoder().encode(signature);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}
