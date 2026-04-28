// Location platform layer.
// Web: navigator.geolocation.
// Native (Capacitor): @capacitor/geolocation foreground watchPosition.
//
// NOTE: This module intentionally exposes a foreground-tracking API only.
// True background / locked-screen continuous trip tracking will require
// a dedicated background geolocation plugin plus native permissions setup.

import { isNative, loadNativePlugin } from "./native";

export interface Position {
  latitude: number;
  longitude: number;
  accuracy?: number;
  timestamp: number;
}

export interface LocationSample extends Position {
  speed?: number;
  heading?: number;
}

export async function getCurrent(): Promise<LocationSample | null> {
  if (isNative()) {
    const mod = await loadNativePlugin<any>("@capacitor/geolocation");
    try {
      const p = await mod?.Geolocation?.getCurrentPosition({ enableHighAccuracy: true, timeout: 8000 });
      if (p?.coords) {
        return {
          latitude: p.coords.latitude,
          longitude: p.coords.longitude,
          accuracy: p.coords.accuracy,
          speed: p.coords.speed ?? undefined,
          heading: p.coords.heading ?? undefined,
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
          speed: p.coords.speed ?? undefined,
          heading: p.coords.heading ?? undefined,
          timestamp: p.timestamp,
        }),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 30_000 },
    );
  });
}

/**
 * Foreground watch suitable for trip mileage recording while app is open.
 * TODO(background): Provide a plugin adapter for true background geolocation.
 */
export function startTripLocationWatch(onUpdate: (p: LocationSample) => void): () => void {
  let watchId: string | number | null = null;
  let cancelled = false;

  if (isNative()) {
    loadNativePlugin<any>("@capacitor/geolocation").then(async (mod) => {
      if (cancelled || !mod?.Geolocation) return;
      try {
        watchId = await mod.Geolocation.watchPosition(
          { enableHighAccuracy: true, maximumAge: 1000, timeout: 10000 },
          (p: any) => {
            if (!p?.coords) return;
            onUpdate({
              latitude: p.coords.latitude,
              longitude: p.coords.longitude,
              accuracy: p.coords.accuracy,
              speed: p.coords.speed ?? undefined,
              heading: p.coords.heading ?? undefined,
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
        speed: p.coords.speed ?? undefined,
        heading: p.coords.heading ?? undefined,
        timestamp: p.timestamp,
      }),
    () => {},
    { enableHighAccuracy: true, maximumAge: 2_000, timeout: 10_000 },
  );
  return () => {
    if (typeof watchId === "number") navigator.geolocation.clearWatch(watchId);
  };
}

// Backwards-compatible alias for existing callers.
export function startTracking(onUpdate: (p: Position) => void): () => void {
  return startTripLocationWatch(onUpdate);
}
