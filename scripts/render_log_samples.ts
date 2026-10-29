// Render sample state-matched logs for a made-up student.
//   deno run -A scripts/render_log_samples.ts OUT_DIR [ST ...]      (default: every state with a layout + a few generic)
import { buildLogDocument, renderStateLogPdf, type Layouts, type LogDriveInput } from "../supabase/functions/export-report/log_layout.ts";

const root = new URL("../", import.meta.url).pathname;
const layouts = JSON.parse(await Deno.readTextFile(`${root}docs/log_layouts/layouts.json`)) as Layouts;
const [out = "./samples", ...only] = Deno.args;
await Deno.mkdir(out, { recursive: true });

// Deterministic sample: 44 signed drives Apr-Oct 2026, ~55 h with ~12 h at night and some rain.
const skills = [["Stops", "Left turns"], ["Parking lot", "Backing"], ["Lane changes", "Following distance"], ["Highway merge", "Lane changes"],
  ["Night driving", "Headlights"], ["Roundabout", "Stop signs"], ["Parallel parking"], ["Unprotected lefts", "Mirrors"]];
const places = ["Home - Mueller", "Mueller to Round Rock", "Mueller to Pflugerville", "Downtown loop", "MoPac to Cedar Park"];
const drives: LogDriveInput[] = [];
let seed = 7;
const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
for (let i = 0; i < 44; i++) {
  const day = new Date(Date.UTC(2026, 3, 20) + i * 4 * 86400000 + Math.floor(rnd() * 2) * 86400000);
  const evening = i % 4 === 3, morning = i % 9 === 4;
  const startMin = evening ? 18 * 60 + 30 + Math.floor(rnd() * 6) * 10 : morning ? 6 * 60 + 10 : 15 * 60 + Math.floor(rnd() * 8) * 15;
  const minutes = [45, 60, 75, 90, 105, 120][Math.floor(rnd() * 6)];
  const night = evening ? Math.min(minutes, 30 + Math.floor(rnd() * 4) * 15) : morning ? 20 : 0;
  const rain = i % 7 === 2;
  const hh = (m: number) => `${String(Math.floor(m / 60) % 24).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
  const sup = i % 3 === 2 ? ["Carlos Lopez", "CL"] : ["Ana Lopez", "AL"];
  drives.push({ date: day.toISOString().slice(0, 10), start: hh(startMin), end: hh(startMin + minutes), minutes, night_minutes: night,
    weather_minutes: rain ? minutes : 0, weather: rain ? "Rain" : i % 2 ? "Clear" : "Sunny", roadway: rain ? "Wet" : "Dry",
    supervisor: sup[0], initials: sup[1], skills: evening ? ["Night driving", ...skills[i % skills.length].slice(0, 1)] : skills[i % skills.length],
    conditions: rain ? ["Rain", "Wet"] : ["Dry"], location: places[i % places.length], notes: i % 5 === 0 ? "Smooth, check mirrors more" : "" });
}
const total = drives.reduce((a, d) => a + d.minutes, 0), night = drives.reduce((a, d) => a + d.night_minutes, 0);
const weather = drives.reduce((a, d) => a + d.weather_minutes, 0);
const states = only.length ? only : [...Object.keys(layouts.states), "AZ", "NM", "GA"].sort();
for (const st of states) {
  const doc = buildLogDocument(layouts, { state_code: st, main_supervisor: "Ana Lopez",
    student: { first: "Maya", last: "Lopez", permit_number: "A1234567", birthday: "2010-03-09", permit_issued: "2026-04-14", school: "" },
    drives, totals: { total, day: total - night, night, weather }, excluded: { unsigned_drives: 1, unsigned_minutes: 40, lessons: 0 } });
  const bytes = await renderStateLogPdf(doc, { generatedAt: "2026-10-22 18:00 UTC", exportId: "sample" });
  const kind = layouts.states[st]?.kind ?? "generic";
  await Deno.writeFile(`${out}/${st}_${kind}.pdf`, bytes);
}
console.log(`rendered ${states.length} samples to ${out} (${drives.length} drives, ${(total / 60).toFixed(1)} h, night ${(night / 60).toFixed(1)} h)`);
