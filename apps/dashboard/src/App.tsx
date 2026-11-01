import { Suspense, lazy } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { configError } from "./lib/supabase";
import { useSession } from "./session";
import { perms } from "./lib/perms";
import { ErrorBox, Loading } from "./components/ui";
import { DeskShell } from "./components/Shell";
import type { Membership } from "./lib/types";

const AuthPage = lazy(() => import("./pages/Auth"));
const NewPasswordPage = lazy(() => import("./pages/Auth").then((m) => ({ default: m.NewPasswordPage })));
const Onboarding = lazy(() => import("./pages/Onboarding"));
const Home = lazy(() => import("./pages/Home"));
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

function Desk({
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
  const showBilling = p.viewBilling;
  const showAdmin = p.manageSchool;

  return (
    <DeskShell current={current} memberships={memberships} email={email} selectSchool={selectSchool}>
      <Suspense fallback={<Loading label="Loading…" />}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/board" element={<Board />} />
          <Route path="/plan" element={<Plan />} />
          <Route path="/students" element={<Students />} />
          <Route path="/students/:id" element={<StudentDetail />} />
          <Route path="/drives" element={p.reviewDrives ? <Drives /> : <Navigate to="/" replace />} />
          <Route path="/people" element={<People />} />
          <Route path="/fleet" element={showAdmin ? <Fleet /> : <Navigate to="/" replace />} />
          <Route path="/settings" element={showAdmin ? <Settings /> : <Navigate to="/" replace />} />
          <Route path="/pay" element={showBilling ? <Pay /> : <Navigate to="/" replace />} />
          <Route path="/payouts" element={showBilling ? <Payouts /> : <Navigate to="/" replace />} />
          <Route path="/packages" element={showBilling ? <Packages /> : <Navigate to="/" replace />} />
          <Route path="/quickbooks" element={showBilling ? <QuickBooks /> : <Navigate to="/" replace />} />
          <Route path="/portal" element={<PortalApp />} />
          <Route path="/schedule" element={<Navigate to="/board" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </DeskShell>
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
        <Desk current={s.current} memberships={s.memberships} email={s.session.user.email} selectSchool={s.selectSchool} />
      )}
    </Suspense>
  );
}
