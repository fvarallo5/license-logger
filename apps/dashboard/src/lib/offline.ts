/** IndexedDB offline mutation queue — port of TrekTrack frontend/src/lib/offline.js for LicenseLogger desk. */
import { get, set } from "idb-keyval";

const QUEUE_KEY = "ll-desk-mutation-queue-v1";
const SYNC_TAG = "ll-desk-sync";
const EVENT = "ll-offline";

type Mem = Map<string, unknown>;
declare global {
  var __LL_OFFLINE_MEM__: Mem | undefined;
}

const fallbackMem: Mem = new Map();

function memStore(): Mem | null {
  if (globalThis.__LL_OFFLINE_MEM__) return globalThis.__LL_OFFLINE_MEM__;
  if (typeof indexedDB === "undefined") return fallbackMem;
  return null;
}

async function storeGet<T>(key: string): Promise<T | undefined> {
  const mem = memStore();
  if (mem) return (mem.has(key) ? mem.get(key) : undefined) as T | undefined;
  return get(key) as Promise<T | undefined>;
}

async function storeSet(key: string, value: unknown): Promise<void> {
  const mem = memStore();
  if (mem) {
    mem.set(key, value);
    return;
  }
  await set(key, value);
}

export function isOnline(): boolean {
  return typeof navigator === "undefined" ? true : navigator.onLine;
}

export function isNetworkError(err: unknown): boolean {
  if (!err) return false;
  const e = err as { name?: string; message?: string };
  const msg = String(e.message || err);
  return e.name === "TypeError" || /failed to fetch|networkerror|load failed|network request failed/i.test(msg);
}

function emit(detail: { pending: number }): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(EVENT, { detail }));
}

export function subscribeOffline(fn: (d: { pending: number }) => void): () => void {
  if (typeof window === "undefined") return () => {};
  const handler = (e: Event) => fn((e as CustomEvent<{ pending: number }>).detail || { pending: 0 });
  window.addEventListener(EVENT, handler);
  return () => window.removeEventListener(EVENT, handler);
}

export interface QueuedMutation {
  id: string;
  createdAt: number;
  type: string;
  payload: Record<string, unknown>;
}

async function readQueue(): Promise<QueuedMutation[]> {
  const list = await storeGet<QueuedMutation[]>(QUEUE_KEY);
  return Array.isArray(list) ? list : [];
}

async function writeQueue(list: QueuedMutation[]): Promise<QueuedMutation[]> {
  await storeSet(QUEUE_KEY, list);
  emit({ pending: list.length });
  return list;
}

export async function pendingCount(): Promise<number> {
  return (await readQueue()).length;
}

export async function enqueueMutation(entry: { type: string; payload: Record<string, unknown> }): Promise<QueuedMutation> {
  const list = await readQueue();
  const item: QueuedMutation = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    createdAt: Date.now(),
    ...entry,
  };
  list.push(item);
  await writeQueue(list);
  await requestBackgroundSync();
  return item;
}

export async function requestBackgroundSync(): Promise<boolean> {
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return false;
  try {
    const reg = await navigator.serviceWorker.ready;
    const syncManager = (reg as ServiceWorkerRegistration & { sync?: { register: (t: string) => Promise<void> } }).sync;
    if (syncManager && "SyncManager" in window) {
      await syncManager.register(SYNC_TAG);
      return true;
    }
  } catch {
    /* unsupported */
  }
  return false;
}

type Handlers = Record<string, (payload: Record<string, unknown>) => Promise<void>>;

/** Replay queued mutations in order. Keeps failed / unknown items at the head — never silent drops. */
export async function flushMutationQueue(handlers: Handlers): Promise<{ flushed: number; remaining: number }> {
  if (!isOnline()) return { flushed: 0, remaining: await pendingCount() };
  let list = await readQueue();
  let flushed = 0;
  while (list.length) {
    const [next, ...rest] = list;
    const handler = handlers[next.type];
    if (!handler) break;
    try {
      await handler(next.payload);
      flushed += 1;
      list = rest;
      await writeQueue(list);
    } catch {
      break;
    }
  }
  return { flushed, remaining: list.length };
}

export { QUEUE_KEY, SYNC_TAG, EVENT };
