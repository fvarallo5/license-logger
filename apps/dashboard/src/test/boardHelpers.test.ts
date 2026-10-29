import { describe, expect, it } from "vitest";
import { canMark, dayStart, filterLessons, isLive, rangeForView, sortBoardLessons, weekStart } from "../lib/boardHelpers";
import type { Lesson } from "../lib/types";

const base: Lesson = {
  id: "1",
  school_id: "s",
  student_id: "st",
  instructor_id: "u-2",
  car_id: "car-1",
  start_at: "2026-10-29T15:00:00.000Z",
  end_at: "2026-10-29T16:00:00.000Z",
  kind: "btw",
  status: "booked",
  name: "",
  meet: "lot",
  topic: "",
};

describe("boardHelpers", () => {
  it("weekStart lands on Monday", () => {
    // Wednesday Oct 29 2026
    const w = weekStart(new Date(2026, 9, 29, 12));
    expect(w.getDay()).toBe(1);
    expect(w.getDate()).toBe(26);
  });

  it("rangeForView today is one local day", () => {
    const anchor = new Date(2026, 9, 29, 15);
    const { from, to } = rangeForView("today", anchor);
    expect(from.getTime()).toBe(dayStart(anchor).getTime());
    expect(to.getTime() - from.getTime()).toBe(86400000);
  });

  it("filterLessons respects instructor and car", () => {
    const rows = [
      { ...base, id: "a", instructor_id: "u-2", car_id: "car-1" },
      { ...base, id: "b", instructor_id: "u-3", car_id: "car-2" },
    ];
    expect(filterLessons(rows, { instructorId: "u-2", carId: "all" }).map((r) => r.id)).toEqual(["a"]);
    expect(filterLessons(rows, { instructorId: "all", carId: "car-2" }).map((r) => r.id)).toEqual(["b"]);
    expect(filterLessons(rows, { instructorId: "all", carId: "all", forceInstructorId: "u-3" }).map((r) => r.id)).toEqual(["b"]);
  });

  it("sortBoardLessons puts booked before taught", () => {
    const rows = [
      { ...base, id: "t", status: "taught" },
      { ...base, id: "b", status: "booked", start_at: "2026-10-29T18:00:00.000Z" },
      { ...base, id: "i", status: "in_lesson", start_at: "2026-10-29T12:00:00.000Z" },
    ];
    expect(sortBoardLessons(rows).map((r) => r.id)).toEqual(["i", "b", "t"]);
  });

  it("canMark / isLive", () => {
    expect(canMark(base)).toBe(true);
    expect(canMark({ ...base, kind: "blocked" })).toBe(false);
    expect(canMark({ ...base, status: "taught" })).toBe(false);
    const now = new Date("2026-10-29T15:30:00.000Z");
    expect(isLive(base, now)).toBe(true);
    expect(isLive({ ...base, status: "taught" }, now)).toBe(false);
  });
});
