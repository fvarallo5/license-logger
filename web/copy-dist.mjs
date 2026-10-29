import { cpSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const src = join(root, "../apps/dashboard/dist");
const dest = join(root, "dist");
rmSync(dest, { recursive: true, force: true });
cpSync(src, dest, { recursive: true });
