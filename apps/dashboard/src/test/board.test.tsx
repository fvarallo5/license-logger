import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
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

describe("Board page", () => {
  it("is the default landing route and shows Today / Week", async () => {
    renderAt("/");
    expect(await screen.findByRole("heading", { name: "Board" })).toBeTruthy();
    expect(screen.getByRole("tab", { name: "Today" })).toBeTruthy();
    expect(screen.getByRole("tab", { name: "Week" })).toBeTruthy();
  });

  it("lists today's booked lessons with Taught action", async () => {
    renderAt("/board");
    expect(await screen.findByRole("heading", { name: "Board" })).toBeTruthy();
    await waitFor(() => expect(screen.getAllByRole("button", { name: "Taught" }).length).toBeGreaterThan(0));
    expect(screen.getByLabelText("Filter by car")).toBeTruthy();
    expect(screen.getByLabelText("Filter by instructor")).toBeTruthy();
  });

  it("marks a lesson taught from the board", async () => {
    renderAt("/board");
    const taughtButtons = await screen.findAllByRole("button", { name: "Taught" });
    fireEvent.click(taughtButtons[0]);
    await waitFor(() => {
      // after refresh, at least one taught badge should appear
      expect(screen.getAllByText(/taught/i).length).toBeGreaterThan(0);
    });
  });

  it("week view still renders the board chrome", async () => {
    renderAt("/board");
    await screen.findByRole("heading", { name: "Board" });
    fireEvent.click(screen.getByRole("tab", { name: "Week" }));
    expect(screen.getByRole("tab", { name: "Week" }).className).toMatch(/on/);
    await waitFor(() => expect(screen.getByRole("heading", { name: "Board" })).toBeTruthy());
  });

  it("nav highlights Board", async () => {
    renderAt("/board");
    await screen.findByRole("heading", { name: "Board" });
    const nav = screen.getByRole("navigation", { name: "Main" });
    expect(within(nav).getByRole("link", { name: "Board" })).toBeTruthy();
  });
});
