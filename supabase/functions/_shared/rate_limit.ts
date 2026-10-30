/** Simple in-isolate token bucket. Resets when the isolate recycles — defense in depth only.
 *  Prefer Postgres private.too_many_attempts / svc rate tables for durable limits.
 */
type Bucket = { tokens: number; updated: number };
const buckets = new Map<string, Bucket>();

export function rateLimit(
  key: string,
  { capacity = 30, refillPerSec = 0.5 }: { capacity?: number; refillPerSec?: number } = {},
): boolean {
  const now = Date.now() / 1000;
  let b = buckets.get(key);
  if (!b) {
    b = { tokens: capacity, updated: now };
    buckets.set(key, b);
  }
  const elapsed = Math.max(0, now - b.updated);
  b.tokens = Math.min(capacity, b.tokens + elapsed * refillPerSec);
  b.updated = now;
  if (b.tokens < 1) return false;
  b.tokens -= 1;
  return true;
}
