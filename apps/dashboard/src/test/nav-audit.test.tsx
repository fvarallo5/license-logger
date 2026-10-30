import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { createMockClient } from "../demo/mockClient";

vi.mock("../lib/supabase", () => ({ supabase: createMockClient(), isDemo: true, configError: null }));

const { SessionProvider } = await import("../session");
const { default: App } = await import("../App");

afterEach(() => cleanup());

function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <SessionProvider>
        <App />
      </SessionProvider>
    </MemoryRouter>,
  );
}

describe("Desk nav (audit)", () => {
  it("exposes skip link and main landmark", async () => {
    renderAt("/board");
    await screen.findByRole("heading", { name: "Board" });
    expect(screen.getByRole("link", { name: "Skip to content" })).toBeTruthy();
    expect(document.getElementById("main")).toBeTruthy();
  });

  it("redirects legacy /schedule to Board", async () => {
    renderAt("/schedule");
    expect(await screen.findByRole("heading", { name: "Board" })).toBeTruthy();
  });

  it("hides QuickBooks when VITE_ENABLE_QBO is off", async () => {
    renderAt("/board");
    await screen.findByRole("heading", { name: "Board" });
    const nav = screen.getByRole("navigation", { name: "Main" });
    expect(nav.textContent || "").not.toMatch(/QuickBooks/);
  });

  it("keeps a phone quick dock", async () => {
    renderAt("/board");
    await screen.findByRole("heading", { name: "Board" });
    expect(screen.getByRole("navigation", { name: "Quick" })).toBeTruthy();
  });
});
