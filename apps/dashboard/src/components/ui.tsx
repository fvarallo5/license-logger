import { useEffect, useRef, type ReactNode } from "react";

export function Loading({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="state" role="status">
      {label}
    </div>
  );
}
export function Empty({ children }: { children: ReactNode }) {
  return <div className="state">{children}</div>;
}
export function ErrorBox({ error, onRetry }: { error: string; onRetry?: () => void }) {
  return (
    <div className="alert bad" role="alert">
      {error}{" "}
      {onRetry && (
        <button className="btn sm" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  );
}
export function Badge({ tone = "", children }: { tone?: "ok" | "warn" | "bad" | "info" | ""; children: ReactNode }) {
  return <span className={`badge ${tone ? "b-" + tone : ""}`}>{children}</span>;
}
export function PageHeader({ title, desc, children }: { title: string; desc?: string; children?: ReactNode }) {
  useEffect(() => {
    document.title = `${title} · LicenseLogger`;
  }, [title]);
  return (
    <div className="ph">
      <div>
        <h1>{title}</h1>
        {desc && <p>{desc}</p>}
      </div>
      <div className="spacer" />
      {children}
    </div>
  );
}
export function Card({ title, count, actions, children }: { title?: string; count?: ReactNode; actions?: ReactNode; children: ReactNode }) {
  return (
    <section className="card">
      {title && (
        <div className="ch">
          <h2>{title}</h2>
          {count != null && <small>{count}</small>}
          <div className="spacer" />
          {actions}
        </div>
      )}
      {children}
    </section>
  );
}
export function Pager({
  page,
  hasPrev,
  hasNext,
  onPrev,
  onNext,
  loading,
}: {
  page: number;
  hasPrev: boolean;
  hasNext: boolean;
  onPrev: () => void;
  onNext: () => void;
  loading?: boolean;
}) {
  if (!hasPrev && !hasNext) return null;
  return (
    <nav className="pager" aria-label="Pagination">
      <span>Page {page + 1}</span>
      <button className="btn sm" disabled={!hasPrev || loading} onClick={onPrev}>
        ← Prev
      </button>
      <button className="btn sm" disabled={!hasNext || loading} onClick={onNext}>
        Next →
      </button>
    </nav>
  );
}
/** Accessible dialog: closes on Escape or backdrop click and focuses its first field. */
export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    ref.current?.querySelector<HTMLElement>("input, select, textarea, button")?.focus();
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="modal-bg" onClick={onClose}>
      <div ref={ref} className="modal" role="dialog" aria-modal="true" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        {children}
      </div>
    </div>
  );
}
export function Progress({ have, need, label }: { have: number; need: number; label?: string }) {
  const p = need > 0 ? Math.min(100, Math.round((have / need) * 100)) : 100;
  return (
    <div title={label}>
      <div
        className={`bar ${p >= 100 ? "done" : ""}`}
        aria-label={label}
        role="progressbar"
        aria-valuenow={p}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <i style={{ width: `${p}%` }} />
      </div>
    </div>
  );
}
