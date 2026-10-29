import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./lib/supabase";
import { acceptMyInvites, myMemberships } from "./lib/api";
import type { Membership } from "./lib/types";

interface Ctx {
  session: Session | null;
  ready: boolean;
  recovery: boolean;
  memberships: Membership[];
  current: Membership | null;
  loadingSchools: boolean;
  schoolError: string | null;
  selectSchool: (id: string) => void;
  refreshSchools: () => Promise<void>;
  clearRecovery: () => void;
}
const SessionCtx = createContext<Ctx | null>(null);
export const useSession = () => {
  const c = useContext(SessionCtx);
  if (!c) throw new Error("useSession outside provider");
  return c;
};

export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [recovery, setRecovery] = useState(false);
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [loadingSchools, setLoadingSchools] = useState(false);
  const [schoolError, setSchoolError] = useState<string | null>(null);
  const [currentId, setCurrentId] = useState<string | null>(() => localStorage.getItem("ll.school"));

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data } = supabase.auth.onAuthStateChange((event, s) => {
      setSession(s);
      if (event === "PASSWORD_RECOVERY") setRecovery(true);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  const userId = session?.user.id;
  const refreshSchools = useCallback(async () => {
    if (!userId) {
      setMemberships([]);
      return;
    }
    setLoadingSchools(true);
    setSchoolError(null);
    try {
      await acceptMyInvites(supabase);
      setMemberships(await myMemberships(supabase, userId));
    } catch (e) {
      setSchoolError((e as Error).message);
    } finally {
      setLoadingSchools(false);
    }
  }, [userId]);
  useEffect(() => {
    void refreshSchools();
  }, [refreshSchools]);

  const current = memberships.find((m) => m.school_id === currentId) ?? memberships[0] ?? null;
  const selectSchool = (id: string) => {
    localStorage.setItem("ll.school", id);
    setCurrentId(id);
  };

  return (
    <SessionCtx.Provider
      value={{
        session,
        ready,
        recovery,
        memberships,
        current,
        loadingSchools,
        schoolError,
        selectSchool,
        refreshSchools,
        clearRecovery: () => setRecovery(false),
      }}
    >
      {children}
    </SessionCtx.Provider>
  );
}

/** The selected school membership. Only call inside pages that App renders after a school is chosen. */
export function useSchool(): Membership {
  const { current } = useSession();
  if (!current) throw new Error("useSchool called before a school was selected");
  return current;
}
