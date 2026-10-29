import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
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
describe("Skills checklist", () => {
  it("shows skills on student detail", async () => {
    render(
      <MemoryRouter initialEntries={["/students/s-1"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText(/Skills \/ road-test readiness/i)).toBeTruthy(), { timeout: 3000 });
  });
});
