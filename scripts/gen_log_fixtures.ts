// Regenerate docs/log_layouts/fixtures/expected/<ST>.json from the TypeScript builder.
//   deno run -A scripts/gen_log_fixtures.ts
// The Dart builder (app: test/log_layouts_test.dart) must produce the same documents.
import { buildLogDocument, type Layouts, type LogInput } from "../supabase/functions/export-report/log_layout.ts";

const root = new URL("../", import.meta.url).pathname;
const layouts = JSON.parse(await Deno.readTextFile(`${root}docs/log_layouts/layouts.json`)) as Layouts;
const input = JSON.parse(await Deno.readTextFile(`${root}docs/log_layouts/fixtures/input.json`)) as LogInput & { _doc?: string };
delete input._doc;
const states = [...Object.keys(layouts.states), ...Object.keys(layouts.generic_states), "ZZ"].sort();
for (const st of states) {
  const doc = buildLogDocument(layouts, { ...input, state_code: st, state_name: st === "ZZ" ? "Nowhere" : undefined });
  await Deno.writeTextFile(`${root}docs/log_layouts/fixtures/expected/${st}.json`, JSON.stringify(doc, null, 1) + "\n");
}
console.log(`wrote ${states.length} expected documents (layouts sha256 ${layouts.sha256.slice(0, 12)})`);
