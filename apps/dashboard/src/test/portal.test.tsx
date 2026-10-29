import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { createMockClient } from "../demo/mockClient";
vi.mock("../lib/supabase", () => ({ supabase: createMockClient(), isDemo: true, configError: null }));
const { SessionProvider } = await import("../session");
const { default: App } = await import("../App");
beforeEach(() => {
  globalThis.__LL_OFFLINE_MEM__ = new Map();
});
afterEach(async () => {
  cleanup();
  await new Promise((r) => setTimeout(r, 20));
});
describe("Portal", () => {
  it("shows family portal empty state in demo", async () => {
    render(
      <MemoryRouter initialEntries={["/portal"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    expect(await screen.findByRole("heading", { name: "Family portal" })).toBeTruthy();
    expect(await screen.findByText(/No linked students/i)).toBeTruthy();
  });
});
