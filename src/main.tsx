import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

// PWA service worker registration.
// Hard-guarded so the SW NEVER registers inside the Lovable preview iframe,
// editor sandbox, or dev host (which would cache stale builds and trip the
// mobile-preview render heuristic). Production / installed PWA only.
//
// The decision is computed once in index.html (see __LOVABLE_IS_PREVIEW__) so
// the manifest link and the service worker use the exact same gating.
function isPreviewEnv(): boolean {
  const cached = (window as unknown as { __LOVABLE_IS_PREVIEW__?: boolean }).__LOVABLE_IS_PREVIEW__;
  if (typeof cached === "boolean") return cached;
  try {
    if (window.self !== window.top) return true;
  } catch {
    return true;
  }
  const h = (window.location.hostname || "").toLowerCase();
  if (!h) return true;
  if (h === "localhost" || h === "127.0.0.1" || h === "0.0.0.0") return true;
  if (h.endsWith(".local")) return true;
  const needles = [
    "lovableproject.com",
    "lovableproject-dev.com",
    "lovable.app",
    "lovable.dev",
    "id-preview--",
    "preview--",
    "sandbox.lovable",
  ];
  if (needles.some((n) => h.includes(n))) return true;
  try {
    if (/[?&](sw=off|preview=1)\b/.test(window.location.search || "")) return true;
  } catch {
    /* noop */
  }
  return false;
}

if ("serviceWorker" in navigator) {
  if (isPreviewEnv()) {
    // Defensive: evict any SW that may have registered from an earlier build.
    navigator.serviceWorker
      .getRegistrations()
      .then((rs) => Promise.all(rs.map((r) => r.unregister())))
      .catch(() => {});
  } else {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("/sw.js").catch(() => {});
    });
  }
}

createRoot(document.getElementById("root")!).render(<App />);
