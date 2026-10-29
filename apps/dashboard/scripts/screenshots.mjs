// Captures the main screens from the DEMO build (fake data, no network).
// Usage: npm run build:demo && npm run screenshots   (CHROME=/path/to/chrome to override)
import { chromium } from "playwright-core";
import { spawn } from "node:child_process";

const port = 4319;
const server = spawn("npx", ["vite", "preview", "--outDir", "dist-demo", "--port", String(port), "--strictPort"], { stdio: "ignore" });
await new Promise((r) => setTimeout(r, 2500));
const browser = await chromium.launch({ executablePath: process.env.CHROME || "/usr/bin/google-chrome", args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 1360, height: 860 }, deviceScaleFactor: 1 });
const shots = [
  ["01_sign_in", "/?signedout#/"],
  ["02_students", "/#/students"],
  ["03_student_detail", "/#/students/s-1"],
  ["04_signoffs", "/#/drives"],
  ["05_schedule", "/#/schedule"],
  ["06_people", "/#/people"],
  ["07_settings", "/#/settings"],
  ["08_quickbooks", "/#/quickbooks"],
];
try {
  for (const [name, path] of shots) {
    await page.goto(`http://localhost:${port}${path}`, { waitUntil: "networkidle" });
    await page.waitForTimeout(600);
    await page.screenshot({ path: `screenshots/${name}.png`, fullPage: true });
    console.log("saved", name);
  }
  // Extra states: export "not deployed" message and the add-student modal
  await page.goto(`http://localhost:${port}/#/students/s-1`, { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "State log (PDF)" }).click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: "screenshots/09_export_not_deployed.png", fullPage: true });
  await page.goto(`http://localhost:${port}/#/students`, { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "+ Add student" }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: "screenshots/10_add_student.png" });
  await page.goto(`http://localhost:${port}/#/students`, { waitUntil: "networkidle" });
  await page.reload({ waitUntil: "networkidle" });
  await page.getByRole("tab", { name: "Former" }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: "screenshots/11_former_students.png" });
} finally {
  await browser.close();
  server.kill();
}
