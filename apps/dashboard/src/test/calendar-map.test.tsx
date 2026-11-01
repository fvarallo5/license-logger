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

  it("selecting a calendar lesson marks it selected", async () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <SessionProvider>
          <App />
        </SessionProvider>
      </MemoryRouter>,
    );
    await screen.findByTestId("calendar-map-split");
    await waitFor(() => expect(document.querySelectorAll(".ll-cal-item").length).toBeGreaterThan(0));
    fireEvent.click(document.querySelectorAll(".ll-cal-item")[0]);
    await waitFor(() => expect(document.querySelector(".ll-cal-item.is-on")).toBeTruthy());
    expect(screen.getByText(/Open on Board/i)).toBeTruthy();
  });
});
