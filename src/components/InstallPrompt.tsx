import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Download, X } from "lucide-react";

/**
 * iOS-aware install prompt.
 * - Chrome/Edge/Android: listens for `beforeinstallprompt` and shows a native trigger.
 * - iOS Safari: shows a one-line hint with "Share → Add to Home Screen".
 * - Hides itself when already installed (display-mode: standalone).
 * - Dismissal persisted for 14 days.
 */
const KEY = "pwa-install-dismissed-at";

export function InstallPrompt() {
  const [event, setEvent] = useState<any>(null);
  const [iosHint, setIosHint] = useState(false);
  const [hidden, setHidden] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") return;

    const standalone =
      (window.matchMedia?.("(display-mode: standalone)").matches) ||
      (window.navigator as any).standalone === true;
    if (standalone) return;

    const dismissed = Number(localStorage.getItem(KEY) || 0);
    if (dismissed && Date.now() - dismissed < 14 * 24 * 60 * 60 * 1000) return;

    // Don't pester users on the auth screen.
    if (window.location.pathname === "/auth") return;

    const isIos = /iPhone|iPad|iPod/.test(navigator.userAgent);
    if (isIos) {
      setIosHint(true);
      setHidden(false);
      return;
    }

    const handler = (e: any) => {
      e.preventDefault();
      setEvent(e);
      setHidden(false);
    };
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  if (hidden) return null;

  const install = async () => {
    if (event) {
      event.prompt();
      await event.userChoice;
      setEvent(null);
      setHidden(true);
    }
  };

  const dismiss = () => {
    localStorage.setItem(KEY, String(Date.now()));
    setHidden(true);
  };

  return (
    <div className="md:hidden fixed left-3 right-3 bottom-20 z-50 rounded-lg border bg-card shadow-lg p-3 flex items-center gap-2"
      style={{ marginBottom: "env(safe-area-inset-bottom)" }}>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium">Install Inspector app</p>
        <p className="text-[11px] text-muted-foreground truncate">
          {iosHint ? "Tap Share → Add to Home Screen" : "Get faster access from your home screen"}
        </p>
      </div>
      {!iosHint && (
        <Button size="sm" onClick={install}>
          <Download className="h-3.5 w-3.5 mr-1" />Install
        </Button>
      )}
      <Button size="icon" variant="ghost" onClick={dismiss} aria-label="Dismiss"><X className="h-4 w-4" /></Button>
    </div>
  );
}
