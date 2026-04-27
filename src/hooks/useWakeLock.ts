import { useEffect, useRef } from "react";

/**
 * Keep the screen awake on supported browsers (Chrome, Edge, Safari 16.4+).
 * Auto-reacquires after the page is hidden then re-shown (browsers drop the
 * lock on visibility change). Silent no-op when the API is unavailable.
 */
export function useWakeLock(active: boolean = true) {
  const sentinelRef = useRef<any>(null);

  useEffect(() => {
    if (!active) return;
    const nav: any = typeof navigator !== "undefined" ? navigator : null;
    if (!nav?.wakeLock?.request) return;

    let cancelled = false;

    const acquire = async () => {
      try {
        const s = await nav.wakeLock.request("screen");
        if (cancelled) {
          s.release?.();
          return;
        }
        sentinelRef.current = s;
        s.addEventListener?.("release", () => {
          sentinelRef.current = null;
        });
      } catch {
        /* user denied or unsupported — silent */
      }
    };

    const onVisibility = () => {
      if (document.visibilityState === "visible" && !sentinelRef.current) {
        acquire();
      }
    };

    acquire();
    document.addEventListener("visibilitychange", onVisibility);

    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", onVisibility);
      sentinelRef.current?.release?.();
      sentinelRef.current = null;
    };
  }, [active]);
}
