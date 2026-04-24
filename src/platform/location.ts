// Location platform layer.
// Web: navigator.geolocation.
// Native (Capacitor): @capacitor/geolocation — same shape, real GPS access.

import { isNative, loadNativePlugin } from "./native";

export interface Position {
  latitude: number;
  longitude: number;
  accuracy?: number;
  timestamp: number;
}

export async function getCurrent(): Promise<Position | null> {
  if (isNative()) {
    const mod = await loadNativePlugin<any>("@capacitor/geolocation");
    try {
      const p = await mod?.Geolocation?.getCurrentPosition({ enableHighAccuracy: true, timeout: 8000 });
      if (p?.coords) {
        return {
          latitude: p.coords.latitude,
          longitude: p.coords.longitude,
          accuracy: p.coords.accuracy,
          timestamp: p.timestamp ?? Date.now(),
        };
      }
    } catch {
      /* fall through to web */
    }
  }
  if (typeof navigator === "undefined" || !navigator.geolocation) return null;
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (p) =>
        resolve({
          latitude: p.coords.latitude,
          longitude: p.coords.longitude,
          accuracy: p.coords.accuracy,
          timestamp: p.timestamp,
        }),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 30_000 },
    );
  });
}

/**
 * Watch position. Returns an unsubscribe function.
 * On native, uses @capacitor/geolocation watchPosition (works in foreground).
 * On web, uses navigator.geolocation.watchPosition.
 */
export function startTracking(onUpdate: (p: Position) => void): () => void {
  let watchId: string | number | null = null;
  let cancelled = false;

  if (isNative()) {
    loadNativePlugin<any>("@capacitor/geolocation").then(async (mod) => {
      if (cancelled || !mod?.Geolocation) return;
      try {
        watchId = await mod.Geolocation.watchPosition(
          { enableHighAccuracy: true },
          (p: any) => {
            if (!p?.coords) return;
            onUpdate({
              latitude: p.coords.latitude,
              longitude: p.coords.longitude,
              accuracy: p.coords.accuracy,
              timestamp: p.timestamp ?? Date.now(),
            });
          },
        );
      } catch {
        /* ignore */
      }
    });
    return () => {
      cancelled = true;
      if (watchId != null) {
        loadNativePlugin<any>("@capacitor/geolocation").then((mod) => {
          mod?.Geolocation?.clearWatch?.({ id: watchId });
        });
      }
    };
  }

  if (typeof navigator === "undefined" || !navigator.geolocation) return () => {};
  watchId = navigator.geolocation.watchPosition(
    (p) =>
      onUpdate({
        latitude: p.coords.latitude,
        longitude: p.coords.longitude,
        accuracy: p.coords.accuracy,
        timestamp: p.timestamp,
      }),
    () => {},
    { enableHighAccuracy: true, maximumAge: 5_000 },
  );
  return () => {
    if (typeof watchId === "number") navigator.geolocation.clearWatch(watchId);
  };
}
