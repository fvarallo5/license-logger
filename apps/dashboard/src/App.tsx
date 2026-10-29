import { NavLink, Navigate, Route, Routes } from "react-router-dom";
import { configError, isDemo, supabase } from "./lib/supabase";
import { useSession } from "./session";
import { perms } from "./lib/perms";
import { roleLabel } from "./lib/format";
import { ErrorBox, Loading } from "./components/ui";
import AuthPage, { NewPasswordPage } from "./pages/Auth";
import Onboarding from "./pages/Onboarding";
import Students from "./pages/Students";
import StudentDetail from "./pages/StudentDetail";
import Drives from "./pages/Drives";
import People from "./pages/People";
import Schedule from "./pages/Schedule";
import Settings from "./pages/Settings";
import QuickBooks from "./pages/QuickBooks";

export default function App() {
  const s = useSession();
  if (configError)
    return (
      <main id="main">
        <ErrorBox error={configError} />
      </main>
    );
  if (!s.ready) return <Loading label="Starting…" />;
  if (s.recovery) return <NewPasswordPage />;
  if (!s.session) return <AuthPage />;
  if (s.loadingSchools && !s.memberships.length) return <Loading label="Loading your school…" />;
  if (s.schoolError)
    return (
      <main>
        <ErrorBox error={s.schoolError} onRetry={() => void s.refreshSchools()} />
      </main>
    );
  if (!s.current) return <Onboarding />;
  const p = perms(s.current);

  return (
    <>
      {isDemo && <div className="demo-banner">DEMO DATA · not connected to a real school</div>}
      <header className="top">
        <div className="logo">
          <i />
          LicenseLogger
        </div>
        {s.memberships.length > 1 ? (
          <select aria-label="School" value={s.current.school_id} onChange={(e) => s.selectSchool(e.target.value)}>
            {s.memberships.map((m) => (
              <option key={m.school_id} value={m.school_id}>
                {m.schools?.name ?? m.school_id}
              </option>
            ))}
          </select>
        ) : (
          <span className="pill">{s.current.schools?.name}</span>
        )}
        <div className="spacer" />
        <span className="pill">{roleLabel[s.current.role]}</span>
        <span className="who">{s.session.user.email}</span>
        <button className="btn sm" onClick={() => void supabase.auth.signOut()}>
          Sign out
        </button>
      </header>
      <nav className="tabs" aria-label="Main">
        <NavLink to="/students">Students</NavLink>
        {p.reviewDrives && <NavLink to="/drives">Sign-offs</NavLink>}
        <NavLink to="/schedule">Schedule</NavLink>
        <NavLink to="/people">People</NavLink>
        {p.manageSchool && <NavLink to="/settings">Settings</NavLink>}
        {p.viewBilling && <NavLink to="/quickbooks">QuickBooks</NavLink>}
      </nav>
      <main>
        <Routes>
          <Route path="/students" element={<Students />} />
          <Route path="/students/:id" element={<StudentDetail />} />
          <Route path="/drives" element={p.reviewDrives ? <Drives /> : <Navigate to="/students" />} />
          <Route path="/schedule" element={<Schedule />} />
          <Route path="/people" element={<People />} />
          <Route path="/settings" element={p.manageSchool ? <Settings /> : <Navigate to="/students" />} />
          <Route path="/quickbooks" element={p.viewBilling ? <QuickBooks /> : <Navigate to="/students" />} />
          <Route path="*" element={<Navigate to="/students" />} />
        </Routes>
      </main>
    </>
  );
}
