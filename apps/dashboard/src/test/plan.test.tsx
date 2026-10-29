import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
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

function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <SessionProvider>
        <App />
      </SessionProvider>
    </MemoryRouter>,
  );
}

describe("Plan page", () => {
  it("lists slot templates and booking requests", async () => {
    renderAt("/plan");
    expect(await screen.findByRole("heading", { name: "Plan" })).toBeTruthy();
    await waitFor(() => expect(screen.getByText("Marcus weekdays")).toBeTruthy());
    expect(screen.getByRole("button", { name: "Accept" })).toBeTruthy();
  });

  it("opens new template modal", async () => {
    renderAt("/plan");
    await screen.findByRole("heading", { name: "Plan" });
    fireEvent.click(screen.getByRole("button", { name: "+ Template" }));
    expect(await screen.findByRole("dialog", { name: "New slot template" })).toBeTruthy();
  });
});
