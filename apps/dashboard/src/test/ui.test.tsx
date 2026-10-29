import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup } from "@testing-library/react";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { createMockClient } from "../demo/mockClient";

vi.mock("../lib/supabase", () => ({ supabase: createMockClient(), isDemo: true, configError: null }));

const { SessionProvider } = await import("../session");
const { default: App } = await import("../App");

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

describe("dashboard with mocked Supabase", () => {
  it("shows the roster after sign-in", async () => {
    renderAt("/students");
    expect(await screen.findByText("Avery Brooks")).toBeTruthy();
    expect(screen.getByText("Lone Star Driving Academy")).toBeTruthy();
  });
  it("lists pending drives and explains practice sign-off", async () => {
    renderAt("/drives");
    await waitFor(() => expect(screen.getAllByText("Family signs").length).toBeGreaterThan(0));
    expect(screen.getAllByRole("button", { name: "Sign" }).length).toBeGreaterThan(0);
  });
  it("export shows a friendly message when the function isn't deployed", async () => {
    renderAt("/students/s-1");
    fireEvent.click(await screen.findByRole("button", { name: "State log (PDF)" }));
    expect(await screen.findByText(/hasn't been deployed/)).toBeTruthy();
  });
  it("shows state-rule progress", async () => {
    renderAt("/students/s-1");
    expect(await screen.findByText("Total supervised driving")).toBeTruthy();
    expect(screen.getByText(/Still needed/)).toBeTruthy();
  });
});
