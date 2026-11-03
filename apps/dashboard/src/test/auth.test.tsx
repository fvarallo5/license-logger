import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";

const signInWithPassword = vi.fn();
const signUp = vi.fn();
const resetPasswordForEmail = vi.fn();

vi.mock("../lib/supabase", () => ({
  supabase: {
    auth: {
      signInWithPassword: (...a: unknown[]) => signInWithPassword(...a),
      signUp: (...a: unknown[]) => signUp(...a),
      resetPasswordForEmail: (...a: unknown[]) => resetPasswordForEmail(...a),
      updateUser: vi.fn(),
    },
  },
  isDemo: false,
  configError: null,
}));

vi.mock("../session", () => ({
  useSession: () => ({
    session: null,
    ready: true,
    recovery: false,
    memberships: [],
    current: null,
    loadingSchools: false,
    schoolError: null,
    selectSchool: () => {},
    refreshSchools: async () => {},
    clearRecovery: () => {},
  }),
}));

const { default: AuthPage } = await import("../pages/Auth");

describe("Auth UI", () => {
  beforeEach(() => {
    signInWithPassword.mockReset();
    signUp.mockReset();
    resetPasswordForEmail.mockReset();
  });
  afterEach(() => cleanup());

  it("signs in with email and password", async () => {
    signInWithPassword.mockResolvedValue({ data: { session: {} }, error: null });
    render(
      <MemoryRouter>
        <AuthPage />
      </MemoryRouter>,
    );
    expect(screen.getByRole("heading", { name: /Sign In To Your School/i })).toBeTruthy();
    fireEvent.change(screen.getByLabelText(/Email/i), { target: { value: "owner@school.com" } });
    fireEvent.change(screen.getByLabelText(/Password/i), { target: { value: "secret123" } });
    fireEvent.click(screen.getByRole("button", { name: /^Sign in$/i }));
    await waitFor(() => expect(signInWithPassword).toHaveBeenCalled());
    expect(signInWithPassword).toHaveBeenCalledWith({ email: "owner@school.com", password: "secret123" });
  });

  it("shows an error when sign-in fails", async () => {
    signInWithPassword.mockResolvedValue({ data: { session: null }, error: { message: "Invalid login credentials" } });
    render(
      <MemoryRouter>
        <AuthPage />
      </MemoryRouter>,
    );
    fireEvent.change(screen.getByLabelText(/Email/i), { target: { value: "bad@x.com" } });
    fireEvent.change(screen.getByLabelText(/Password/i), { target: { value: "nope" } });
    fireEvent.click(screen.getByRole("button", { name: /^Sign in$/i }));
    expect((await screen.findByRole("alert")).textContent).toMatch(/Invalid login credentials/i);
  });

  it("signs up a school account and prompts to confirm email", async () => {
    signUp.mockResolvedValue({ data: { session: null, user: null }, error: null });
    render(
      <MemoryRouter>
        <AuthPage />
      </MemoryRouter>,
    );
    fireEvent.click(screen.getByRole("button", { name: /Create account/i }));
    expect(screen.getByRole("heading", { name: /Create A School Account/i })).toBeTruthy();
    fireEvent.change(screen.getByLabelText(/Your name/i), { target: { value: "Frank" } });
    fireEvent.change(screen.getByLabelText(/Email/i), { target: { value: "frank@school.com" } });
    fireEvent.change(screen.getByLabelText(/Password/i), { target: { value: "password1" } });
    fireEvent.click(screen.getByRole("button", { name: /^Create account$/i }));
    await waitFor(() => expect(signUp).toHaveBeenCalled());
    expect(signUp.mock.calls[0][0]).toMatchObject({
      email: "frank@school.com",
      password: "password1",
      options: { data: { full_name: "Frank", account_type: "school" } },
    });
    expect((await screen.findByRole("alert")).textContent).toMatch(/Check your email/i);
  });

  it("redirects back to sign in from signup confirmation", async () => {
    signUp.mockResolvedValue({ data: { session: null, user: null }, error: null });
    render(
      <MemoryRouter>
        <AuthPage />
      </MemoryRouter>,
    );
    fireEvent.click(screen.getByRole("button", { name: /Create account/i }));
    fireEvent.change(screen.getByLabelText(/Your name/i), { target: { value: "Frank" } });
    fireEvent.change(screen.getByLabelText(/Email/i), { target: { value: "frank@school.com" } });
    fireEvent.change(screen.getByLabelText(/Password/i), { target: { value: "password1" } });
    fireEvent.click(screen.getByRole("button", { name: /^Create account$/i }));
    const back = await screen.findByRole("button", { name: /Back to sign in/i });
    fireEvent.click(back);
    expect(screen.getByRole("heading", { name: /Sign In To Your School/i })).toBeTruthy();
  });
});
