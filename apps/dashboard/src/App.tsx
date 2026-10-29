import { NavLink, Navigate, Route, Routes } from "react-router-dom";
import { configError, isDemo, supabase } from "./lib/supabase";
import { useSession } from "./session";
import { perms } from "./lib/perms";
import { roleLabel } from "./lib/format";
import { ErrorBox, Loading } from "./components/ui";
import AuthPage, { NewPasswordPage } from "./pages/Auth";
import Onboarding from "./pages/Onboarding";
import Board from "./pages/Board";
import Plan from "./pages/Plan";
import Students from "./pages/Students";
import StudentDetail from "./pages/StudentDetail";
import Drives from "./pages/Drives";
import People from "./pages/People";
import Schedule from "./pages/Schedule";
import Settings from "./pages/Settings";
import QuickBooks from "./pages/QuickBooks";
import Packages from "./pages/Packages";
import Pay from "./pages/Pay";
import Fleet from "./pages/Fleet";
import Payouts from "./pages/Payouts";
import PortalApp from "./pages/portal/PortalApp";
import { usePendingSignoffs } from "./lib/usePendingSignoffs";
import { PwaChrome } from "./components/PwaChrome";
import type { Membership } from "./lib/types";

function DeskShell({
  current,
  memberships,
  email,
  selectSchool,
}: {
  current: Membership;
  memberships: Membership[];
  email: string | undefined;
  selectSchool: (id: string) => void;
}) {
  const p = perms(current);
  const pending = usePendingSignoffs(supabase, current.school_id, p.reviewDrives);

  return (
    <>
      <PwaChrome />
      {isDemo && <div className="demo-banner">DEMO DATA · not connected to a real school</div>}
      <header className="top">
        <div className="logo">
          <i />
          LicenseLogger
        </div>
        {memberships.length > 1 ? (
          <select aria-label="School" value={current.school_id} onChange={(e) => selectSchool(e.target.value)}>
            {memberships.map((m) => (
              <option key={m.school_id} value={m.school_id}>
                {m.schools?.name ?? m.school_id}
              </option>
            ))}
          </select>
        ) : (
          <span className="pill">{current.schools?.name}</span>
        )}
        <div className="spacer" />
        <span className="pill">{roleLabel[current.role]}</span>
        <span className="who">{email}</span>
        <NavLink className="btn sm" to="/portal">
          Family
        </NavLink>
        <button className="btn sm" onClick={() => void supabase.auth.signOut()}>
          Sign out
        </button>
      </header>
      <nav className="tabs" aria-label="Main">
        <NavLink to="/board" end>
          Board
        </NavLink>
        <NavLink to="/plan">Plan</NavLink>
        <NavLink to="/students">Students</NavLink>
        {p.reviewDrives && (
          <NavLink to="/drives">
            Sign-offs
            {pending.count > 0 && (
              <span className="nav-badge" aria-label={`${pending.count} pending`}>
                {pending.count > 99 ? "99+" : pending.count}
              </span>
            )}
          </NavLink>
        )}
        <NavLink to="/schedule">Schedule</NavLink>
        <NavLink to="/people">People</NavLink>
        {p.manageSchool && <NavLink to="/fleet">Fleet</NavLink>}
        {p.manageSchool && <NavLink to="/settings">Settings</NavLink>}
        {p.viewBilling && <NavLink to="/pay">Pay</NavLink>}
        {p.viewBilling && <NavLink to="/payouts">Payouts</NavLink>}
        {p.viewBilling && <NavLink to="/packages">Packages</NavLink>}
        {p.viewBilling && <NavLink to="/quickbooks">QuickBooks</NavLink>}
      </nav>
      <main>
        <Routes>
          <Route path="/board" element={<Board />} />
          <Route path="/plan" element={<Plan />} />
          <Route path="/students" element={<Students />} />
          <Route path="/students/:id" element={<StudentDetail />} />
          <Route path="/drives" element={p.reviewDrives ? <Drives /> : <Navigate to="/board" />} />
          <Route path="/schedule" element={<Schedule />} />
          <Route path="/people" element={<People />} />
          <Route path="/fleet" element={p.manageSchool ? <Fleet /> : <Navigate to="/board" />} />
          <Route path="/settings" element={p.manageSchool ? <Settings /> : <Navigate to="/board" />} />
          <Route path="/pay" element={p.viewBilling ? <Pay /> : <Navigate to="/board" />} />
          <Route path="/payouts" element={p.viewBilling ? <Payouts /> : <Navigate to="/board" />} />
          <Route path="/packages" element={p.viewBilling ? <Packages /> : <Navigate to="/board" />} />
          <Route path="/quickbooks" element={p.viewBilling ? <QuickBooks /> : <Navigate to="/board" />} />
          <Route path="/portal" element={<PortalApp />} />
          <Route path="*" element={<Navigate to="/board" />} />
        </Routes>
      </main>
    </>
  );
}

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

  return <DeskShell current={s.current} memberships={s.memberships} email={s.session.user.email} selectSchool={s.selectSchool} />;
}
