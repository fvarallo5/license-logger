import { useState, type FormEvent } from "react";
import { supabase } from "../lib/supabase";
import { useSession } from "../session";

type Mode = "signin" | "signup" | "reset";
const siteUrl = () => (import.meta.env.VITE_SITE_URL as string | undefined) || window.location.origin;

export default function AuthPage() {
  const [mode, setMode] = useState<Mode>("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: "ok" | "bad"; text: string } | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      if (mode === "signin") {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
      } else if (mode === "signup") {
        if (password.length < 8) throw new Error("Use at least 8 characters for your password.");
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: { emailRedirectTo: siteUrl(), data: { full_name: name, account_type: "school" } },
        });
        if (error) throw error;
        if (!data.session) setMsg({ tone: "ok", text: "Check your email to confirm your account, then sign in." });
      } else {
        const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: siteUrl() });
        if (error) throw error;
        setMsg({ tone: "ok", text: "If that email has an account, a reset link is on its way." });
      }
    } catch (err) {
      setMsg({ tone: "bad", text: (err as Error).message });
    } finally {
      setBusy(false);
    }
  }

  const title = { signin: "Sign in to your school", signup: "Create a school account", reset: "Reset your password" }[mode];
  return (
    <div className="auth-wrap">
      <form className="card auth-card" onSubmit={submit}>
        <div className="logo" style={{ marginBottom: 8 }}>
          <i />
          LicenseLogger <span className="muted">for schools</span>
        </div>
        <h2 style={{ marginTop: 0 }}>{title}</h2>
        {msg && (
          <div className={`alert ${msg.tone}`} role="alert">
            {msg.text}
          </div>
        )}
        {mode === "signup" && (
          <div className="field">
            <label htmlFor="name">Your name</label>
            <input id="name" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
        )}
        <div className="field">
          <label htmlFor="email">Email</label>
          <input id="email" type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </div>
        {mode !== "reset" && (
          <div className="field">
            <label htmlFor="pw">Password</label>
            <input
              id="pw"
              type="password"
              autoComplete={mode === "signup" ? "new-password" : "current-password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
        )}
        <button className="btn primary" style={{ width: "100%" }} disabled={busy}>
          {busy ? "Please wait…" : mode === "signin" ? "Sign in" : mode === "signup" ? "Create account" : "Send reset link"}
        </button>
        <div className="row" style={{ justifyContent: "space-between", marginTop: 12 }}>
          {mode !== "signin" ? (
            <button type="button" className="btn link" onClick={() => setMode("signin")}>
              Back to sign in
            </button>
          ) : (
            <button type="button" className="btn link" onClick={() => setMode("signup")}>
              New school? Create account
            </button>
          )}
          {mode === "signin" && (
            <button type="button" className="btn link" onClick={() => setMode("reset")}>
              Forgot password?
            </button>
          )}
        </div>
      </form>
    </div>
  );
}

export function NewPasswordPage() {
  const { clearRecovery } = useSession();
  const [pw, setPw] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    const { error } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (error) setErr(error.message);
    else clearRecovery();
  }
  return (
    <div className="auth-wrap">
      <form className="card auth-card" onSubmit={submit}>
        <h2>Choose a new password</h2>
        {err && <div className="alert bad">{err}</div>}
        <div className="field">
          <label htmlFor="npw">New password</label>
          <input id="npw" type="password" minLength={8} value={pw} onChange={(e) => setPw(e.target.value)} required />
        </div>
        <button className="btn primary" disabled={busy}>
          Save password
        </button>
      </form>
    </div>
  );
}
