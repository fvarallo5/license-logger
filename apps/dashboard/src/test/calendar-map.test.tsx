import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { createMockClient } from "../demo/mockClient";

vi.mock("../lib/supabase", () => ({ supabase: createMockClient(), isDemo: true, configError: null }));

const { SessionProvider } = await import("../session");
const { default: App } = await import("../App");

beforeEach(() => {
  globalThis.__LL_OFFLINE_MEM__ = new Map();
  Object.defineProperty(window, "matchMedia", {
    writable: true,
    value: (query: string) => ({
      matches: String(query).includes("min-width: 900"),
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    }),
  });
});
afterEach(async () => {
  cleanup();
  await new Promise((r) => setTimeout(r, 20));
});

describe("Calendar + map split", () => {
  it("renders on Home with calendar and map panes", async () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    expect(await screen.findByTestId("calendar-map-split")).toBeTruthy();
    expect(screen.getByLabelText("Calendar pane")).toBeTruthy();
    expect(screen.getByLabelText("Map pane")).toBeTruthy();
    expect(screen.getAllByLabelText("Lessons map").length).toBeGreaterThan(0);
  });

  it("loads day FullCalendar and selects a lesson block", async () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    await screen.findByTestId("calendar-map-split");
    expect(await screen.findByTestId("lesson-calendar-grid", {}, { timeout: 8000 })).toBeTruthy();
    expect(screen.getByRole("button", { name: "Day" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "Week" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "Month" })).toBeTruthy();

    await waitFor(() => expect(document.querySelectorAll(".fc-event").length).toBeGreaterThan(0), { timeout: 8000 });
    fireEvent.click(document.querySelectorAll(".fc-event")[0]);
    await waitFor(() => expect(screen.getByText(/Open on Board/i)).toBeTruthy());
  });

  it("Board week view uses day strip (option D) and selects a card", async () => {
    render(
      <MemoryRouter initialEntries={["/board"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    await screen.findByTestId("calendar-map-split");
    // Board defaults to week → strip
    const strip = await screen.findByTestId("week-strip-view", {}, { timeout: 8000 });
    expect(strip).toBeTruthy();
    const dayTabs = strip.querySelectorAll('[role="tab"]');
    expect(dayTabs.length).toBe(7);
    // Today should be selected by default when in current week
    expect(strip.querySelector('[role="tab"][aria-selected="true"]')).toBeTruthy();
    await waitFor(() => expect(strip.querySelectorAll(".ll-week-d-card").length).toBeGreaterThan(0), { timeout: 5000 });
    fireEvent.click(strip.querySelectorAll(".ll-week-d-card")[0]);
    await waitFor(() => expect(strip.querySelector(".ll-week-d-card.is-on")).toBeTruthy());
    expect(screen.getByText(/Open on Board/i)).toBeTruthy();
  });
});
