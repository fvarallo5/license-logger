import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { pendingDrivesCount } from "./api";

/** Poll pending drive count for the Sign-offs rail badge. Soft-fails to 0. */
export function usePendingSignoffs(sb: SupabaseClient, schoolId: string | undefined, enabled: boolean) {
  const [count, setCount] = useState(0);
  const refresh = useCallback(async () => {
    if (!schoolId || !enabled) {
      setCount(0);
      return;
    }
    try {
      setCount(await pendingDrivesCount(sb, schoolId));
    } catch {
      setCount(0);
    }
  }, [sb, schoolId, enabled]);

  useEffect(() => {
    void refresh();
    const id = window.setInterval(() => void refresh(), 60_000);
    const onFocus = () => void refresh();
    window.addEventListener("focus", onFocus);
    return () => {
      window.clearInterval(id);
      window.removeEventListener("focus", onFocus);
    };
  }, [refresh]);

  return { count, refresh };
}
