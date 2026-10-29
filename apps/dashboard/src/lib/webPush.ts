/**
 * Web Push registration for desk staff.
 * Behind VITE_ENABLE_WEB_PUSH=1. Requires Phase 3 migration + VAPID public key.
 * Does nothing when flag off or PushManager missing (Safari older / insecure ctx).
 */
const ENABLED = import.meta.env.VITE_ENABLE_WEB_PUSH === "1";
const VAPID = import.meta.env.VITE_VAPID_PUBLIC_KEY as string | undefined;

function urlBase64ToUint8Array(base64String: string) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

export async function maybeRegisterWebPush(
  register: (args: { endpoint: string; p256dh: string; auth: string; userAgent: string }) => Promise<unknown>,
): Promise<"skipped" | "subscribed" | "denied"> {
  if (!ENABLED || !VAPID) return "skipped";
  if (typeof window === "undefined" || !("serviceWorker" in navigator) || !("PushManager" in window)) return "skipped";
  const perm = await Notification.requestPermission();
  if (perm !== "granted") return "denied";
  const reg = await navigator.serviceWorker.ready;
  let sub = await reg.pushManager.getSubscription();
  if (!sub) {
    sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID),
    });
  }
  const json = sub.toJSON();
  const endpoint = json.endpoint;
  const p256dh = json.keys?.p256dh;
  const auth = json.keys?.auth;
  if (!endpoint || !p256dh || !auth) return "skipped";
  await register({
    endpoint,
    p256dh,
    auth,
    userAgent: navigator.userAgent,
  });
  return "subscribed";
}
