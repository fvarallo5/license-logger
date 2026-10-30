import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, waitFor, within } from "@testing-library/react";
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

describe("Sign-offs badge", () => {
  it("shows pending count on Sign-offs nav", async () => {
    render(
      <MemoryRouter initialEntries={["/board"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    const nav = await screen.findByRole("navigation", { name: "Main" });
    await waitFor(() => {
      const link = within(nav).getByRole("link", { name: /Sign-offs/i });
      expect(link.textContent).toMatch(/\d/);
    });
  });
});
