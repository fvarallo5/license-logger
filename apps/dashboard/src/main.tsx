import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import "./styles.css";
import App from "./App";
import { SessionProvider } from "./session";

/** Harder zoom lock on iOS standalone / installed PWA (Safari a11y may still allow pinch in browser tabs). */
function lockIosStandaloneZoom() {
  try {
    const nav = window.navigator as Navigator & { standalone?: boolean };
    const isIos = /iPad|iPhone|iPod/.test(nav.userAgent) || (nav.platform === "MacIntel" && nav.maxTouchPoints > 1);
    const standalone = Boolean(nav.standalone) || window.matchMedia("(display-mode: standalone)").matches;
    if (!isIos || !standalone) return;
    document.addEventListener(
      "gesturestart",
      (e) => {
        e.preventDefault();
      },
      { passive: false },
    );
  } catch {
    /* ignore */
  }
}
lockIosStandaloneZoom();

const root = document.getElementById("root");
if (!root) throw new Error("index.html is missing #root");
createRoot(root).render(
  <StrictMode>
    <BrowserRouter>
      <SessionProvider>
        <App />
      </SessionProvider>
    </BrowserRouter>
  </StrictMode>,
);
