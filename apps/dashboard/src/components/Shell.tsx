import { useEffect, useState, type ReactNode } from "react";
import { NavLink } from "react-router-dom";
import {
  LayoutDashboard,
  CalendarDays,
  Users,
  ClipboardCheck,
  UserCog,
  Car,
  Settings,
  Wallet,
  Package,
  HandCoins,
  BookOpen,
  LogOut,
  Moon,
  Sun,
  Monitor,
  Menu,
  X,
} from "lucide-react";
import { supabase, isDemo } from "../lib/supabase";
import { perms } from "../lib/perms";
import { roleLabel } from "../lib/format";
import { usePendingSignoffs } from "../lib/usePendingSignoffs";
import { PwaChrome } from "./PwaChrome";
import { applyTheme, cycleTheme, readTheme, type ThemeMode } from "../lib/theme";
import type { Membership } from "../lib/types";

type Item = { to: string; label: string; icon: ReactNode; end?: boolean; badge?: number; show?: boolean };

export function DeskShell({
  current,
  memberships,
  email,
  selectSchool,
  children,
}: {
  current: Membership;
  memberships: Membership[];
  email: string | undefined;
  selectSchool: (id: string) => void;
  children: ReactNode;
}) {
  const p = perms(current);
  const pending = usePendingSignoffs(supabase, current.school_id, p.reviewDrives);
  const showBilling = p.viewBilling;
  const showAdmin = p.manageSchool;
  const [theme, setTheme] = useState<ThemeMode>(() => readTheme());
  const [open, setOpen] = useState(false);

  useEffect(() => {
    applyTheme(theme);
    const mq = window.matchMedia?.("(prefers-color-scheme: dark)");
    if (!mq?.addEventListener) return;
    const onChange = () => theme === "system" && applyTheme("system");
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [theme]);

  const mainNav: Item[] = [
    { to: "/", label: "Home", icon: <LayoutDashboard size={18} />, end: true },
    { to: "/board", label: "Board", icon: <CalendarDays size={18} /> },
    { to: "/plan", label: "Plan", icon: <BookOpen size={18} /> },
    { to: "/students", label: "Students", icon: <Users size={18} /> },
    {
      to: "/drives",
      label: "Sign-offs",
      icon: <ClipboardCheck size={18} />,
      badge: pending.count,
      show: p.reviewDrives,
    },
    { to: "/people", label: "People", icon: <UserCog size={18} /> },
    { to: "/fleet", label: "Fleet", icon: <Car size={18} />, show: showAdmin },
    { to: "/settings", label: "Settings", icon: <Settings size={18} />, show: showAdmin },
  ];
  const billingNav: Item[] = [
    { to: "/pay", label: "Pay", icon: <Wallet size={18} />, show: showBilling },
    { to: "/payouts", label: "Payouts", icon: <HandCoins size={18} />, show: showBilling },
    { to: "/packages", label: "Packages", icon: <Package size={18} />, show: showBilling },
  ];

  const ThemeIcon = theme === "dark" ? Moon : theme === "light" ? Sun : Monitor;

  function link(item: Item, onNavigate?: () => void) {
    if (item.show === false) return null;
    return (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end}
        className={({ isActive }) => `side-link${isActive ? " active" : ""}`}
        onClick={onNavigate}
      >
        <span className="side-ico" aria-hidden>
          {item.icon}
        </span>
        <span>{item.label}</span>
        {item.badge != null && item.badge > 0 && (
          <span className="nav-badge" aria-label={`${item.badge} pending`}>
            {item.badge > 99 ? "99+" : item.badge}
          </span>
        )}
      </NavLink>
    );
  }

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <PwaChrome />

      <div className={`desk${open ? " side-open" : ""}`}>
        <aside className="sidebar" aria-label="School">
          <div className="side-brand">
            <span className="logo-mark" aria-hidden />
            <div>
              <strong>LicenseLogger</strong>
              <small>School Desk</small>
            </div>
            <button type="button" className="btn icon ghost side-close" aria-label="Close menu" onClick={() => setOpen(false)}>
              <X size={18} />
            </button>
          </div>

          <div className="side-school">
            {memberships.length > 1 ? (
              <select aria-label="School" value={current.school_id} onChange={(e) => selectSchool(e.target.value)}>
                {memberships.map((m) => (
                  <option key={m.school_id} value={m.school_id}>
                    {m.schools?.name ?? m.school_id}
                  </option>
                ))}
              </select>
            ) : (
              <span className="side-school-name">{current.schools?.name}</span>
            )}
            <span className="pill soft">{roleLabel[current.role]}</span>
          </div>

          <nav className="side-nav" aria-label="Main">
            {mainNav.map((i) => link(i, () => setOpen(false)))}
            {billingNav.some((i) => i.show !== false) && <div className="side-label">Billing</div>}
            {billingNav.map((i) => link(i, () => setOpen(false)))}
            <NavLink
              to="/portal"
              className={({ isActive }) => `side-link nav-secondary${isActive ? " active" : ""}`}
              onClick={() => setOpen(false)}
            >
              <span className="side-ico" aria-hidden>
                <Users size={18} />
              </span>
              <span>Family portal</span>
            </NavLink>
          </nav>

          <div className="side-foot">
            <button type="button" className="btn sm ghost" onClick={() => setTheme((t) => cycleTheme(t))} title={`Theme: ${theme}`}>
              <ThemeIcon size={16} /> {theme === "system" ? "Auto" : theme === "dark" ? "Dark" : "Light"}
            </button>
            <div className="side-who" title={email}>
              {email}
            </div>
            <button type="button" className="btn sm" onClick={() => void supabase.auth.signOut()}>
              <LogOut size={14} /> Sign out
            </button>
          </div>
        </aside>

        <div className="desk-main">
          {isDemo && <div className="demo-banner">DEMO DATA · not connected to a real school</div>}
          <header className="topbar">
            <button type="button" className="btn icon ghost menu-btn" aria-label="Open menu" onClick={() => setOpen(true)}>
              <Menu size={18} />
            </button>
            <div className="topbar-title">{current.schools?.name ?? "LicenseLogger"}</div>
            <div className="spacer" />
            <span className="who hide-sm">{email}</span>
          </header>
          <main id="main" className="page">
            {children}
          </main>
        </div>
      </div>

      {open && <button type="button" className="side-backdrop" aria-label="Close menu" onClick={() => setOpen(false)} />}
    </>
  );
}
