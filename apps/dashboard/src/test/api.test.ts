import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import * as api from "../lib/api";
import { perms } from "../lib/perms";
import type { Membership } from "../lib/types";

function fakeRpc(data: unknown, error: unknown = null) {
  const rpc = vi.fn().mockResolvedValue({ data, error });
  return { sb: { rpc } as unknown as SupabaseClient, rpc };
}

describe("RPC wiring uses exact live names and argument keys", () => {
  it("school_students_progress keyset pagination", async () => {
    const rows = Array.from({ length: 2 }, (_, i) => ({ student_id: `s${i}`, first_name: "A", last_name: `L${i}` }));
    const { sb, rpc } = fakeRpc(rows);
    const p = await api.studentsPage(sb, "sch", null, 2);
    expect(rpc).toHaveBeenCalledWith("school_students_progress", {
      p_school_id: "sch",
      p_after_last: null,
      p_after_first: null,
      p_after_id: null,
      p_limit: 2,
    });
    expect(p.next).toEqual({ last: "L1", first: "A", id: "s1" });
    const p2 = await api.studentsPage(sb, "sch", p.next, 5);
    expect(rpc).toHaveBeenLastCalledWith(
      "school_students_progress",
      expect.objectContaining({ p_after_last: "L1", p_after_id: "s1", p_limit: 5 }),
    );
    expect(p2.next).toBeNull();
  });
  it("update_school sends every column", async () => {
    const { sb, rpc } = fakeRpc(null);
    await api.updateSchool(sb, {
      id: "x",
      name: "N",
      city: "C",
      phone: "P",
      timezone: "America/Chicago",
      default_lesson_minutes: 60,
      cancel_window_hours: 24,
      who_starts: "instructor",
      package_draw: "",
    });
    expect(rpc).toHaveBeenCalledWith("update_school", {
      p_school_id: "x",
      p_name: "N",
      p_city: "C",
      p_phone: "P",
      p_timezone: "America/Chicago",
      p_default_lesson_minutes: 60,
      p_cancel_window_hours: 24,
      p_who_starts: "instructor",
    });
  });
  it("sign_drive uses the instructor method", async () => {
    const { sb, rpc } = fakeRpc({});
    await api.signLesson(sb, "d1");
    expect(rpc.mock.calls[0][0]).toBe("sign_drive");
    expect(rpc.mock.calls[0][1]).toMatchObject({ p_drive_id: "d1", p_method: "instructor", p_supervisor_id: null });
  });
  it("void_drive requires a reason before calling the server", async () => {
    const { sb, rpc } = fakeRpc(null);
    await expect(api.voidDrive(sb, "d1", " a")).rejects.toThrow(/reason/);
    expect(rpc).not.toHaveBeenCalled();
  });
  it("request_student_link trims the code", async () => {
    const { sb, rpc } = fakeRpc({});
    await api.requestStudentLink(sb, "sch", "  LL-ABC ");
    expect(rpc).toHaveBeenCalledWith("request_student_link", { p_school_id: "sch", p_student_code: "LL-ABC" });
  });
  it("surfaces server errors in plain language", async () => {
    const { sb } = fakeRpc(null, { code: "42501", message: "permission denied for table students" });
    await expect(api.releaseStudent(sb, "s")).rejects.toThrow("You don't have permission to do that.");
  });
});

describe("export-report", () => {
  const sbWith = (res: unknown) => ({ functions: { invoke: vi.fn().mockResolvedValue(res) } }) as unknown as SupabaseClient;
  it("returns the signed URL", async () => {
    const r = await api.exportReport(sbWith({ data: { url: "https://x/y" }, error: null }), {
      student_id: "s",
      format: "pdf",
      layout: "state",
    });
    expect(r).toEqual({ ok: true, url: "https://x/y" });
  });
  it("reports 'not deployed' gracefully on 404", async () => {
    const r = await api.exportReport(
      sbWith({ data: null, error: { name: "FunctionsHttpError", message: "x", context: { status: 404 } } }),
      { student_id: "s", format: "pdf" },
    );
    expect(r).toMatchObject({ ok: false, notDeployed: true });
  });
  it("passes through server error text", async () => {
    const r = await api.exportReport(
      sbWith({
        data: null,
        error: { name: "FunctionsHttpError", message: "x", context: { status: 429, json: async () => ({ error: "Too many exports" }) } },
      }),
      { student_id: "s", format: "csv" },
    );
    expect(r).toEqual({ ok: false, notDeployed: false, message: "Too many exports" });
  });
});

describe("role-aware permissions", () => {
  const m = (role: string, access = {}) => ({ role, access }) as unknown as Membership;
  it("instructors cannot manage the school or students", () => {
    expect(perms(m("instructor"))).toMatchObject({ manageSchool: false, manageStudents: false, reviewDrives: true, viewBilling: false });
  });
  it("front desk manages students, billing only with pay access", () => {
    expect(perms(m("front_desk"))).toMatchObject({ manageStudents: true, manageSchool: false, viewBilling: false });
    expect(perms(m("front_desk", { pay: true })).viewBilling).toBe(true);
  });
  it("owners can do everything", () => {
    const p = perms(m("owner"));
    expect(p.manageSchool && p.manageStudents && p.reviewDrives && p.viewBilling && p.seeBoard && p.manageBoard).toBe(true);
    expect(p.instructorOnly).toBe(false);
  });
});
