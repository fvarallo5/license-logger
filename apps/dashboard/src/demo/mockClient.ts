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
  private wantCount = false;
  private headOnly = false;
  constructor(private rows: Row[]) {}
  select(_cols?: string, opts?: { count?: string; head?: boolean }) {
    if (opts?.count) this.wantCount = true;
    if (opts?.head) this.headOnly = true;
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
  gte(c: string, v: string) {
    this.filters.push((r) => String(r[c]) >= v);
    return this;
  }
  lt(c: string, v: string) {
    this.filters.push((r) => String(r[c]) < v);
    return this;
  }
  lte(c: string, v: string) {
    this.filters.push((r) => String(r[c]) <= v);
    return this;
  }
  gt(c: string, v: string) {
    this.filters.push((r) => String(r[c]) > v);
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
  insert(row: Row | Row[]) {
    const rows = Array.isArray(row) ? row : [row];
    for (const r of rows) this.rows.push({ id: r.id ?? `row-${Date.now()}`, ...r });
    return this;
  }
  update(patch: Row) {
    const hit = this.rows.filter((r) => this.filters.every((f) => f(r)));
    for (const r of hit) Object.assign(r, patch);
    return this;
  }
  delete() {
    const keep = this.rows.filter((r) => !this.filters.every((f) => f(r)));
    this.rows.length = 0;
    this.rows.push(...keep);
    return this;
  }
  then<A, B>(ok?: ((v: Res) => A | PromiseLike<A>) | null, bad?: ((e: unknown) => B | PromiseLike<B>) | null) {
    const all = this.rows.filter((r) => this.filters.every((f) => f(r)));
    const hit = all.slice(this.from, this.to + 1);
    const data = this.headOnly ? null : this.one ? (hit[0] ?? null) : hit;
    const res: Res & { count?: number | null } = { data, error: null };
    if (this.wantCount) res.count = all.length;
    return Promise.resolve(res).then(ok, bad);
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
    mark_lesson: (a) => {
      const row = demo.lessons.find((l) => l.id === a.p_lesson_id);
      if (row) row.status = String(a.p_status);
      return null;
    },
    reassign_lesson: (a) => {
      const row = demo.lessons.find((l) => l.id === a.p_lesson_id);
      if (row) {
        row.instructor_id = String(a.p_instructor_id);
        row.car_id = (a.p_car_id as string | null | undefined) ?? null;
      }
      return null;
    },
    qbo_sync_status: () => [],
    compute_instructor_pay: (a) => {
      const taught = demo.lessons.filter(
        (l) =>
          l.status === "taught" &&
          String(l.start_at).slice(0, 10) >= String(a.p_period_start) &&
          String(l.start_at).slice(0, 10) <= String(a.p_period_end),
      );
      const by: Record<string, number> = {};
      for (const l of taught) {
        const hrs = (new Date(String(l.end_at)).getTime() - new Date(String(l.start_at)).getTime()) / 3600000;
        by[String(l.instructor_id)] = (by[String(l.instructor_id)] ?? 0) + hrs;
      }
      return Object.entries(by).map(([instructor_id, hours]) => ({
        instructor_id,
        hours: Math.round(hours * 100) / 100,
        rate: 35,
        amount: Math.round(hours * 35 * 100) / 100,
      }));
    },
    member_hourly_rate: () => 35,
    request_slot: () => `res-${Date.now()}`,
    create_school: () => demo.school,
    add_car: (a) => {
      const id = `car-${Date.now()}`;
      (t.cars as Row[]).push({
        id,
        school_id: a.p_school_id,
        name: a.p_name,
        plate: a.p_plate,
        color: a.p_color,
        model: a.p_model,
        dual_control: true,
        assigned_user_id: a.p_assigned_user_id,
        active: true,
      });
      return id;
    },
    add_lot: (a) => {
      const id = `lot-${Date.now()}`;
      (t.lots as Row[]).push({ id, school_id: a.p_school_id, name: a.p_name, lat: null, lng: null, is_default: !!a.p_is_default });
      return id;
    },
    add_slot_template: (a) => {
      const id = `tpl-${Date.now()}`;
      (t.slot_templates as Row[]).push({
        id,
        school_id: a.p_school_id,
        instructor_id: a.p_instructor_id,
        car_id: a.p_car_id,
        name: a.p_name,
        kind: a.p_kind,
        duration_minutes: a.p_duration_minutes,
        travel_before_minutes: a.p_travel_before_minutes,
        travel_after_minutes: a.p_travel_after_minutes,
        days: a.p_days,
        window_start: a.p_window_start,
        window_end: a.p_window_end,
        meet: a.p_meet,
        min_notice_hours: a.p_min_notice_hours,
        max_advance_days: a.p_max_advance_days,
        note: a.p_note,
        active: true,
      });
      return id;
    },
    book_lesson: () => `l-${Date.now()}`,
    add_block: () => `l-block-${Date.now()}`,
    accept_reservation: (a) => {
      const r = (t.reservations as Row[]).find((x) => x.id === a.p_reservation_id);
      if (r) r.status = "accepted";
      return `l-${Date.now()}`;
    },
    decline_reservation: (a) => {
      const r = (t.reservations as Row[]).find((x) => x.id === a.p_reservation_id);
      if (r) {
        r.status = "declined";
        r.decline_reason = a.p_reason;
      }
      return null;
    },
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
