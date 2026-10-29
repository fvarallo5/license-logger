import { useCallback, useEffect, useRef, useState } from "react";
import type { Page } from "./api";

/** Cursor-stack pagination: works for keyset cursors and page numbers alike. */
/**
 * @param resetKey change this (e.g. school id + filter) to jump back to page 1.
 */
export function usePaged<T, C>(fetchPage: (cursor: C | null) => Promise<Page<T, C>>, resetKey: string) {
  const [stack, setStack] = useState<(C | null)[]>([null]);
  const [rows, setRows] = useState<T[]>([]);
  const [next, setNext] = useState<C | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  const fetchRef = useRef(fetchPage);
  fetchRef.current = fetchPage;
  const cursor = stack[stack.length - 1];

  // Reset to first page when inputs change.
  useEffect(() => {
    setStack([null]);
  }, [resetKey]);

  useEffect(() => {
    let live = true;
    setLoading(true);
    setError(null);
    fetchRef
      .current(cursor)
      .then((p) => {
        if (live) {
          setRows(p.rows);
          setNext(p.next);
        }
      })
      .catch((e: Error) => {
        if (live) setError(e.message);
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [cursor, tick]);

  return {
    rows,
    loading,
    error,
    page: stack.length - 1,
    hasPrev: stack.length > 1,
    hasNext: next !== null,
    onNext: useCallback(() => {
      if (next !== null) setStack((s) => [...s, next]);
    }, [next]),
    onPrev: useCallback(() => setStack((s) => (s.length > 1 ? s.slice(0, -1) : s)), []),
    reload: useCallback(() => setTick((t) => t + 1), []),
  };
}
