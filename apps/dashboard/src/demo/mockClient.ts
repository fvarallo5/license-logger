// A tiny in-memory stand-in for supabase-js used by demo mode and tests. No network.
import type { SupabaseClient } from "@supabase/supabase-js";
import { demo } from "./data";

type Row = Record<string, unknown>;
type Res = { data: unknown; error: null | { message: string; code?: string } };

class Query implements PromiseLike<Res> {
  private filters: ((r: Row) => boolean)[] = [];
  private from = 0;
  private to = Infinity;
  private one: "single" | "maybe" | null = null;
  constructor(private rows: Row[]) {}
  select() {
    return this;
  }
  order() {
    return this;
  }
  or() {
    return this;
  }
  eq(c: string, v: unknown) {
    this.filters.push((r) => r[c] === v);
    return this;
  }
  neq(c: string, v: unknown) {
    this.filters.push((r) => r[c] !== v);
    return this;
  }
  in(c: string, v: unknown[]) {
    this.filters.push((r) => v.includes(r[c]));
    return this;
  }
  is(c: string, v: unknown) {
    this.filters.push((r) => (r[c] ?? null) === v);
    return this;
  }
  not(c: string, _op: string, v: unknown) {
    this.filters.push((r) => (r[c] ?? null) !== v);
    return this;
  }
  lt(c: string, v: string) {
    this.filters.push((r) => String(r[c]) < v);
    return this;
  }
  limit(n: number) {
    this.to = this.from + n - 1;
    return this;
  }
  range(a: number, b: number) {
    this.from = a;
    this.to = b;
    return this;
  }
  maybeSingle() {
    this.one = "maybe";
    return this;
  }
  single() {
    this.one = "single";
    return this;
  }
  then<A, B>(ok?: ((v: Res) => A | PromiseLike<A>) | null, bad?: ((e: unknown) => B | PromiseLike<B>) | null) {
    const hit = this.rows.filter((r) => this.filters.every((f) => f(r))).slice(this.from, this.to + 1);
    const data = this.one ? (hit[0] ?? null) : hit;
    return Promise.resolve<Res>({ data, error: null }).then(ok, bad);
  }
}

export function createMockClient(): SupabaseClient {
  const t = demo.tables;
  const withSchool = (m: Row) => ({ ...m, schools: t.schools.find((s) => s.id === m.school_id) ?? null });
  const rpcs: Record<string, (a: Row) => unknown> = {
    school_students_progress: (a) =>
      t.students
        .filter((s) => s.school_id === a.p_school_id)
        .sort((x, y) => String(x.last_name).localeCompare(String(y.last_name)))
        .filter((s) => !a.p_after_last || String(s.last_name) > String(a.p_after_last))
        .slice(0, Number(a.p_limit ?? 25))
        .map((s) => ({
          student_id: s.id,
          first_name: s.first_name,
          last_name: s.last_name,
          seat: s.seat,
          instructor_id: s.instructor_id,
          practice_hours: s.practice_hours,
          night_hours: s.night_hours,
          school_hours: s.school_hours,
          hour_goal: s.hour_goal,
          night_goal: s.night_goal,
          pending_drives: t.drives.filter((d) => d.student_id === s.id).length,
          last_drive_at: t.drives.find((d) => d.student_id === s.id)?.started_at ?? null,
        })),
    student_rule_progress: (a) => ({ ...demo.progress, student_id: a.p_student_id }),
    state_resources: () => demo.resources,
    list_drives: (a) =>
      t.drives
        .filter((d) => d.student_id === a.p_student_id)
        .map((d) => ({
          ...d,
          supervisor_name: "Parent",
          local_date: String(d.started_at).slice(0, 10),
          has_route: true,
          locked_at: null,
          weather_minutes: 0,
        })),
    school_schedule: (a) => demo.lessons.filter((l) => l.start_at >= String(a.p_from) && l.start_at < String(a.p_to)),
    qbo_sync_status: () => [],
    create_school: () => demo.school,
  };
  const ok = (data: unknown) => Promise.resolve({ data, error: null });
  const session = { access_token: "demo", user: { id: demo.me, email: "owner@example.com" } };
  const client = {
    from: (table: string) => new Query(table === "school_members" ? t.school_members.map(withSchool) : (t[table] ?? [])),
    rpc: (name: string, args: Row = {}) => ok(rpcs[name] ? rpcs[name](args) : { status: "ok" }),
    functions: {
      invoke: () => Promise.resolve({ data: null, error: { name: "FunctionsHttpError", message: "Not found", context: { status: 404 } } }),
    },
    auth: {
      // ?signedout in the URL shows the sign-in screen in demo mode
      getSession: () => ok({ session: typeof location !== "undefined" && location.search.includes("signedout") ? null : session }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      signInWithPassword: () => ok({ session }),
      signUp: () => ok({ session: null, user: null }),
      resetPasswordForEmail: () => ok({}),
      updateUser: () => ok({ user: session.user }),
      signOut: () => ok({}),
    },
  };
  return client as unknown as SupabaseClient;
}
