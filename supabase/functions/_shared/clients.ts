import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { env } from "./env.ts";

/** Acts as the signed-in caller: RLS applies. Use for every read/write on a user's behalf. */
export function userClient(req: Request): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Service role: bypasses RLS. Only for svc_* RPCs, Storage uploads and signed URLs. Never sent to a client. */
export function serviceClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireUser(req: Request): Promise<{ id: string; email?: string } | null> {
  const { data, error } = await userClient(req).auth.getUser();
  if (error || !data.user) return null;
  return { id: data.user.id, email: data.user.email ?? undefined };
}
