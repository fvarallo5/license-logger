#!/usr/bin/env node
/** Fail the build if dist looks like raw Vite source (the live Worker bug). */
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const dist = join(process.cwd(), "dist");
const htmlPath = join(dist, "index.html");
if (!existsSync(htmlPath)) {
  console.error("verify-dist: dist/index.html missing — did vite build?");
  process.exit(1);
}
const html = readFileSync(htmlPath, "utf8");
if (/src\/main\.(jsx|tsx|js|ts)/.test(html)) {
  console.error("verify-dist: dist/index.html still points at /src/main.* — refusing to ship raw source.");
  process.exit(1);
}
if (!existsSync(join(dist, "manifest.webmanifest"))) {
  console.error("verify-dist: manifest.webmanifest missing");
  process.exit(1);
}
if (!existsSync(join(dist, "sw.js"))) {
  console.error("verify-dist: sw.js missing");
  process.exit(1);
}
if (!/\/assets\//.test(html)) {
  console.error("verify-dist: expected hashed /assets/ script in index.html");
  process.exit(1);
}
console.log("verify-dist: ok (built SPA + PWA assets)");
