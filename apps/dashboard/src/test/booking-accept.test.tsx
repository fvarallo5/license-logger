import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { createMockClient } from "../demo/mockClient";
import { demo } from "../demo/data";

vi.mock("../lib/supabase", () => {
  const client = createMockClient();
  return { supabase: client, isDemo: true, configError: null };
});

const { SessionProvider } = await import("../session");
const { default: App } = await import("../App");

describe("Booking accept flow", () => {
  beforeEach(() => {
    globalThis.__LL_OFFLINE_MEM__ = new Map();
    // ensure an open reservation exists in demo data
    const rows = demo.tables.reservations as { id: string; status: string }[];
    if (rows[0]) rows[0].status = "requested";
  });
  afterEach(async () => {
    cleanup();
    await new Promise((r) => setTimeout(r, 20));
  });

  it("accepts a booking request on Plan and removes it from the open queue", async () => {
    render(
      <MemoryRouter initialEntries={["/plan"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    expect(await screen.findByRole("heading", { name: /^Plan$/i }, { timeout: 8000 })).toBeTruthy();
    // Open booking requests card — Accept buttons for requested rows
    const accept = await screen.findAllByRole("button", { name: /^Accept$/i }, { timeout: 8000 });
    expect(accept.length).toBeGreaterThan(0);
    fireEvent.click(accept[0]);
    await waitFor(
      () => {
        // after accept, status becomes accepted — button should go away or count drop
        const left = screen.queryAllByRole("button", { name: /^Accept$/i });
        expect(left.length).toBeLessThan(accept.length);
      },
      { timeout: 5000 },
    );
  });
});
