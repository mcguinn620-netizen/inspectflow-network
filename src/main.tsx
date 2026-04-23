import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

// PWA service worker registration.
// Hard-guarded so the SW NEVER registers inside the Lovable preview iframe
// (which would cache stale builds and break navigation). Production / installed
// PWA only.
const isInIframe = (() => { try { return window.self !== window.top; } catch { return true; } })();
const host = window.location.hostname;
const isPreviewHost =
  host.includes("lovableproject.com") ||
  host.includes("lovable.app") ||
  host.includes("id-preview--") ||
  host === "localhost" ||
  host === "127.0.0.1";

if ("serviceWorker" in navigator) {
  if (isInIframe || isPreviewHost) {
    // Defensive: clean up any SW that might already be registered in preview.
    navigator.serviceWorker.getRegistrations().then((rs) => rs.forEach((r) => r.unregister())).catch(() => {});
  } else {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("/sw.js").catch(() => {});
    });
  }
}

createRoot(document.getElementById("root")!).render(<App />);
