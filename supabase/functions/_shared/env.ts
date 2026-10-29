// Secrets come ONLY from environment variables (supabase secrets set ...).
// Never log these values.
export function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing required environment variable ${name}`);
  return v;
}
export function envOr(name: string, fallback: string): string {
  return Deno.env.get(name) || fallback;
}
