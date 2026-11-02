import { describe, expect, it } from "vitest";
import { pinForLesson, statusColor } from "../lib/lessonPins";
import type { Lesson, Lot } from "../lib/types";

const lot: Lot = {
  id: "lot-1",
  school_id: "s",
  name: "Main lot",
  lat: 40.7128,
  lng: -74.006,
  is_default: true,
};

function lesson(partial: Partial<Lesson>): Lesson {
  return {
    id: "l1",
    school_id: "s",
    student_id: "st",
    instructor_id: "u1",
    start_at: new Date().toISOString(),
    end_at: new Date().toISOString(),
    kind: "btw",
    status: "booked",
    name: "",
    meet: "lot",
    topic: "",
    ...partial,
  };
}

describe("lessonPins", () => {
  it("pins lot meets on the default lot", () => {
    const p = pinForLesson(lesson({ meet: "lot" }), [lot]);
    expect(p?.kind).toBe("lot");
    expect(p?.lat).toBe(40.7128);
  });

  it("offsets pickup meets stably", () => {
    const a = pinForLesson(lesson({ id: "a", meet: "pickup" }), [lot]);
    const b = pinForLesson(lesson({ id: "a", meet: "pickup" }), [lot]);
    const c = pinForLesson(lesson({ id: "b", meet: "pickup" }), [lot]);
    expect(a?.kind).toBe("pickup");
    expect(a?.lat).toBe(b?.lat);
    expect(a?.lat).not.toBe(c?.lat);
  });

  it("colors taught green-ish", () => {
    expect(statusColor("taught")).toMatch(/^#/);
  });
});
