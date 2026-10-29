import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createMockClient } from "../demo/mockClient";

export const isDemo = import.meta.env.VITE_DEMO === "1";
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;

export const configError =
  !isDemo && (!url || !key)
    ? "Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY. Copy .env.example to .env.local and fill them in."
    : !isDemo && key && /service_role|^sb_secret_/.test(key)
      ? "That looks like a SECRET key. Use the publishable/anon key only."
      : null;

export const supabase: SupabaseClient = isDemo
  ? createMockClient()
  : createClient(url ?? "http://invalid.local", key ?? "missing", {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    });
