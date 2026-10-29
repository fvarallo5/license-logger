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

function go(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <SessionProvider>
        <App />
      </SessionProvider>
    </MemoryRouter>,
  );
}

describe("Pay & Packages", () => {
  it("lists packages", async () => {
    go("/packages");
    expect(await screen.findByRole("heading", { name: "Packages" })).toBeTruthy();
    await waitFor(() => expect(screen.getByText("6-hour BTW")).toBeTruthy());
  });

  it("lists invoices on Pay", async () => {
    go("/pay");
    expect(await screen.findByRole("heading", { name: "Pay" })).toBeTruthy();
    await waitFor(() => expect(screen.getByText("INV-1001")).toBeTruthy());
  });
});
