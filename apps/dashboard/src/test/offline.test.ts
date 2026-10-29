import { beforeEach, describe, expect, it } from "vitest";
import { enqueueMutation, flushMutationQueue, isNetworkError, pendingCount, QUEUE_KEY } from "../lib/offline";

beforeEach(() => {
  globalThis.__LL_OFFLINE_MEM__ = new Map();
});

describe("offline queue", () => {
  it("enqueues and counts", async () => {
    expect(await pendingCount()).toBe(0);
    await enqueueMutation({ type: "mark_lesson", payload: { lessonId: "l-1", status: "taught" } });
    expect(await pendingCount()).toBe(1);
    const stored = globalThis.__LL_OFFLINE_MEM__?.get(QUEUE_KEY) as unknown[];
    expect(stored).toHaveLength(1);
  });

  it("flushes in order and keeps failures", async () => {
    await enqueueMutation({ type: "mark_lesson", payload: { n: 1 } });
    await enqueueMutation({ type: "mark_lesson", payload: { n: 2 } });
    const seen: number[] = [];
    let failOnce = true;
    const r1 = await flushMutationQueue({
      mark_lesson: async (p) => {
        seen.push(Number(p.n));
        if (failOnce && Number(p.n) === 1) {
          failOnce = false;
          throw new Error("network");
        }
      },
    });
    expect(r1.flushed).toBe(0);
    expect(r1.remaining).toBe(2);
    const r2 = await flushMutationQueue({
      mark_lesson: async (p) => {
        seen.push(Number(p.n));
      },
    });
    expect(r2.flushed).toBe(2);
    expect(r2.remaining).toBe(0);
    expect(seen).toEqual([1, 1, 2]);
  });

  it("retains unknown types", async () => {
    await enqueueMutation({ type: "mystery", payload: {} });
    const r = await flushMutationQueue({ mark_lesson: async () => {} });
    expect(r.flushed).toBe(0);
    expect(r.remaining).toBe(1);
  });

  it("isNetworkError detects fetch failures", () => {
    expect(isNetworkError(new TypeError("Failed to fetch"))).toBe(true);
    expect(isNetworkError(new Error("permission denied"))).toBe(false);
  });
});
