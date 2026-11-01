import { useEffect, useState } from "react";

const KEY = "ll-theme";

export type ThemeMode = "light" | "dark" | "system";

export function readTheme(): ThemeMode {
  try {
    const v = localStorage.getItem(KEY);
    return v === "dark" || v === "light" || v === "system" ? v : "system";
  } catch {
    return "system";
  }
}

export function resolveTheme(mode: ThemeMode): "light" | "dark" {
  if (mode === "light" || mode === "dark") return mode;
  try {
    return window.matchMedia?.("(prefers-color-scheme: dark)")?.matches ? "dark" : "light";
  } catch {
    return "light";
  }
}

export function applyTheme(mode: ThemeMode) {
  const resolved = resolveTheme(mode);
  document.documentElement.dataset.theme = resolved;
  try {
    localStorage.setItem(KEY, mode);
  } catch {
    /* ignore */
  }
}

export function cycleTheme(mode: ThemeMode): ThemeMode {
  return mode === "system" ? "light" : mode === "light" ? "dark" : "system";
}

/** true when viewport is desktop redesign (≥900px). Defaults true in SSR/jsdom. */
export function useDesktopMedia(minWidth = 900): boolean {
  const [desktop, setDesktop] = useState(() => {
    if (typeof window === "undefined" || !window.matchMedia) return true;
    return window.matchMedia(`(min-width: ${minWidth}px)`).matches;
  });
  useEffect(() => {
    const mq = window.matchMedia?.(`(min-width: ${minWidth}px)`);
    if (!mq) return;
    const apply = () => setDesktop(mq.matches);
    apply();
    mq.addEventListener?.("change", apply);
    return () => mq.removeEventListener?.("change", apply);
  }, [minWidth]);
  return desktop;
}
