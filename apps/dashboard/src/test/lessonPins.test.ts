import { describe, expect, it } from "vitest";
import { pinForLesson, rangeForCalView, statusColor, weekStart } from "../lib/lessonPins";
import type { Lesson, Lot } from "../lib/types";

const lot: Lot = {
  id: "lot-1",
  school_id: "sch",
  name: "Main",
  lat: 40.7,
  lng: -74.0,
  is_default: true,
} as Lot;

function lesson(partial: Partial<Lesson>): Lesson {
  return {
    id: "l1",
    school_id: "sch",
    student_id: "s1",
    instructor_id: "u1",
    car_id: null,
    start_at: new Date().toISOString(),
    end_at: new Date().toISOString(),
    kind: "btw",
    status: "booked",
    name: "",
    meet: "lot",
    topic: "",
    ...partial,
  } as Lesson;
}

describe("lessonPins", () => {
  it("pins lot meets at lot coords", () => {
    const p = pinForLesson(lesson({ meet: "lot" }), [lot]);
    expect(p?.kind).toBe("lot");
    expect(p?.lat).toBe(40.7);
  });

  it("offsets pickup pins stably", () => {
    const a = pinForLesson(lesson({ id: "a", meet: "pickup" }), [lot]);
    const b = pinForLesson(lesson({ id: "a", meet: "pickup" }), [lot]);
    const c = pinForLesson(lesson({ id: "b", meet: "pickup" }), [lot]);
    expect(a?.lat).toBe(b?.lat);
    expect(a?.lat).not.toBe(c?.lat);
  });

  it("maps status colors", () => {
    expect(statusColor("taught")).toMatch(/^#/);
    expect(statusColor("booked")).toMatch(/^#/);
  });
});

describe("rangeForCalView", () => {
  it("returns day/week/month windows", () => {
    const anchor = new Date("2026-11-01T12:00:00");
    const day = rangeForCalView("day", anchor);
    expect(day.to.getTime()).toBeGreaterThan(day.from.getTime());
    expect(day.to.getDate()).not.toBe(day.from.getDate());
    const week = rangeForCalView("week", anchor);
    expect(week.to.getTime() - week.from.getTime()).toBeGreaterThan(6 * 86400000);
    expect(weekStart(week.from).getTime()).toBe(week.from.getTime());
    const month = rangeForCalView("month", anchor);
    expect(month.from.getTime()).toBeLessThan(new Date(2026, 10, 1).getTime() + 1);
    expect(month.to.getTime()).toBeGreaterThan(new Date(2026, 10, 30).getTime());
  });
});
