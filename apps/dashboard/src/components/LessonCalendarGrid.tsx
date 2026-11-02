import { useEffect, useMemo, useRef } from "react";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import timeGridPlugin from "@fullcalendar/timegrid";
import interactionPlugin from "@fullcalendar/interaction";
import type { EventClickArg, EventContentArg } from "@fullcalendar/core";
import type { Lesson } from "../lib/types";
import { statusColor } from "../lib/lessonPins";
import type { CalView } from "./LessonCalendar";

function instructorHue(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0;
  return h % 360;
}

function viewToFc(view: CalView): string {
  if (view === "month") return "dayGridMonth";
  // Week uses WeekStripView (option D), not FullCalendar
  return "timeGridDay";
}

function studentLabel(l: Lesson, names: Record<string, string>): string {
  if (l.kind === "blocked") return l.name || "Blocked";
  if (l.student_id && names[l.student_id]) return names[l.student_id];
  return l.topic || l.kind || "Lesson";
}

export default function LessonCalendarGrid({
  lessons,
  names,
  view,
  anchor,
  selectedId,
  onSelect,
  onDatesSet,
}: {
  lessons: Lesson[];
  names: Record<string, string>;
  view: CalView;
  anchor: Date;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  onDatesSet?: (start: Date, end: Date) => void;
}) {
  const ref = useRef<FullCalendar>(null);

  const events = useMemo(
    () =>
      lessons.map((l) => {
        const color = statusColor(l.status);
        const hue = instructorHue(l.instructor_id || "x");
        const student = studentLabel(l, names);
        const instructor = names[l.instructor_id] || "Instructor";
        const title =
          view === "month" ? `${new Date(l.start_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })} ${student}` : student;
        return {
          id: l.id,
          title,
          start: l.start_at,
          end: l.end_at,
          backgroundColor: color,
          borderColor: `hsl(${hue} 45% 35%)`,
          textColor: "#fff",
          extendedProps: {
            status: l.status,
            instructor,
            student,
            meet: l.meet,
            topic: l.topic,
            kind: l.kind,
          },
          classNames: selectedId === l.id ? ["ll-fc-selected"] : [],
        };
      }),
    [lessons, names, selectedId, view],
  );

  useEffect(() => {
    const api = ref.current?.getApi();
    if (!api) return;
    const want = viewToFc(view);
    if (api.view.type !== want) api.changeView(want);
    api.gotoDate(anchor);
  }, [view, anchor]);

  useEffect(() => {
    const api = ref.current?.getApi();
    if (!api) return;
    api.refetchEvents();
  }, [events]);

  function onEventClick(arg: EventClickArg) {
    arg.jsEvent.preventDefault();
    onSelect(arg.event.id);
  }

  function renderEvent(arg: EventContentArg) {
    const time = arg.timeText;
    const { student, instructor, kind } = arg.event.extendedProps as {
      student?: string;
      instructor?: string;
      kind?: string;
    };
    const isWeek = arg.view.type === "timeGridWeek";
    const isMonth = arg.view.type === "dayGridMonth";
    if (isMonth) {
      return (
        <div className="ll-fc-chip">
          <span className="ll-fc-chip-dot" style={{ background: arg.event.backgroundColor }} />
          <span className="ll-fc-chip-text">{arg.event.title}</span>
        </div>
      );
    }
    return (
      <div className="ll-fc-block">
        {time ? <div className="ll-fc-block-time">{time}</div> : null}
        <div className="ll-fc-block-title">{student || arg.event.title}</div>
        {isWeek ? (
          <div className="ll-fc-block-sub">
            {kind || "btw"} · {instructor || ""}
          </div>
        ) : (
          <div className="ll-fc-block-sub">
            {kind || "btw"} · {instructor || ""}
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="ll-fc" data-testid="lesson-calendar-grid">
      <FullCalendar
        ref={ref}
        plugins={[dayGridPlugin, timeGridPlugin, interactionPlugin]}
        initialView={viewToFc(view)}
        initialDate={anchor}
        headerToolbar={false}
        height="100%"
        expandRows
        stickyHeaderDates
        nowIndicator
        allDaySlot={false}
        slotMinTime="07:00:00"
        slotMaxTime="21:00:00"
        slotDuration="00:30:00"
        slotLabelInterval="01:00:00"
        weekends
        firstDay={1}
        dayMaxEvents={3}
        moreLinkClick="popover"
        eventDisplay="block"
        events={events}
        eventClick={onEventClick}
        eventContent={renderEvent}
        datesSet={(info) => onDatesSet?.(info.start, info.end)}
        eventMinHeight={28}
        slotEventOverlap={false}
        eventOverlap
        editable={false}
        selectable={false}
      />
    </div>
  );
}
