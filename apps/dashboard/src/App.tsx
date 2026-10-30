import { Suspense, lazy } from "react";
import { NavLink, Navigate, Route, Routes } from "react-router-dom";
import { configError, isDemo, supabase } from "./lib/supabase";
import { useSession } from "./session";
import { perms } from "./lib/perms";
import { roleLabel } from "./lib/format";
import { ErrorBox, Loading } from "./components/ui";
import { usePendingSignoffs } from "./lib/usePendingSignoffs";
import { PwaChrome } from "./components/PwaChrome";
import type { Membership } from "./lib/types";

const AuthPage = lazy(() => import("./pages/Auth"));
const NewPasswordPage = lazy(() => import("./pages/Auth").then((m) => ({ default: m.NewPasswordPage })));
const Onboarding = lazy(() => import("./pages/Onboarding"));
const Board = lazy(() => import("./pages/Board"));
const Plan = lazy(() => import("./pages/Plan"));
const Students = lazy(() => import("./pages/Students"));
const StudentDetail = lazy(() => import("./pages/StudentDetail"));
const Drives = lazy(() => import("./pages/Drives"));
const People = lazy(() => import("./pages/People"));
const Settings = lazy(() => import("./pages/Settings"));
const QuickBooks = lazy(() => import("./pages/QuickBooks"));
const Packages = lazy(() => import("./pages/Packages"));
const Pay = lazy(() => import("./pages/Pay"));
const Fleet = lazy(() => import("./pages/Fleet"));
const Payouts = lazy(() => import("./pages/Payouts"));
const PortalApp = lazy(() => import("./pages/portal/PortalApp"));

const ENABLE_QBO = import.meta.env.VITE_ENABLE_QBO === "1";

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
  const showBilling = p.viewBilling;
  const showAdmin = p.manageSchool;

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
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
        <NavLink to="/people">People</NavLink>
        {showAdmin && <NavLink to="/fleet">Fleet</NavLink>}
        {showAdmin && <NavLink to="/settings">Settings</NavLink>}
        {showBilling && <NavLink to="/pay">Pay</NavLink>}
        {showBilling && <NavLink to="/payouts">Payouts</NavLink>}
        {showBilling && <NavLink to="/packages">Packages</NavLink>}
        {showBilling && ENABLE_QBO && <NavLink to="/quickbooks">QuickBooks</NavLink>}
        <NavLink to="/portal" className="nav-secondary">
          Family portal
        </NavLink>
      </nav>
      <main id="main">
        <Suspense fallback={<Loading label="Loading…" />}>
          <Routes>
            <Route path="/board" element={<Board />} />
            <Route path="/plan" element={<Plan />} />
            <Route path="/students" element={<Students />} />
            <Route path="/students/:id" element={<StudentDetail />} />
            <Route path="/drives" element={p.reviewDrives ? <Drives /> : <Navigate to="/board" replace />} />
            <Route path="/people" element={<People />} />
            <Route path="/fleet" element={showAdmin ? <Fleet /> : <Navigate to="/board" replace />} />
            <Route path="/settings" element={showAdmin ? <Settings /> : <Navigate to="/board" replace />} />
            <Route path="/pay" element={showBilling ? <Pay /> : <Navigate to="/board" replace />} />
            <Route path="/payouts" element={showBilling ? <Payouts /> : <Navigate to="/board" replace />} />
            <Route path="/packages" element={showBilling ? <Packages /> : <Navigate to="/board" replace />} />
            <Route path="/quickbooks" element={showBilling ? <QuickBooks /> : <Navigate to="/board" replace />} />
            <Route path="/portal" element={<PortalApp />} />
            {/* Schedule was a thin week list; Board Week covers it — keep redirect for old bookmarks */}
            <Route path="/schedule" element={<Navigate to="/board" replace />} />
            <Route path="*" element={<Navigate to="/board" replace />} />
          </Routes>
        </Suspense>
      </main>
      {/* Instructor/admin phone dock: fastest path to today's work */}
      <nav className="dock" aria-label="Quick">
        <NavLink to="/board" end>
          Board
        </NavLink>
        <NavLink to="/plan">Plan</NavLink>
        <NavLink to="/students">Students</NavLink>
        {p.reviewDrives && (
          <NavLink to="/drives">
            Sign-offs
            {pending.count > 0 && <span className="dock-dot" aria-hidden />}
          </NavLink>
        )}
      </nav>
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
  return (
    <Suspense fallback={<Loading label="Loading…" />}>
      {s.recovery ? (
        <NewPasswordPage />
      ) : !s.session ? (
        <AuthPage />
      ) : s.loadingSchools && !s.memberships.length ? (
        <Loading label="Loading your school…" />
      ) : s.schoolError ? (
        <main id="main">
          <ErrorBox error={s.schoolError} onRetry={() => void s.refreshSchools()} />
        </main>
      ) : !s.current ? (
        <Onboarding />
      ) : (
        <DeskShell current={s.current} memberships={s.memberships} email={s.session.user.email} selectSchool={s.selectSchool} />
      )}
    </Suspense>
  );
}
