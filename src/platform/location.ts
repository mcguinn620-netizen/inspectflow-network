// Location platform layer (placeholder).
// Web: navigator.geolocation one-shot read.
// Future Capacitor: @capacitor/geolocation with background tracking for trips.

export interface Position {
  latitude: number;
  longitude: number;
  accuracy?: number;
  timestamp: number;
}

export async function getCurrent(): Promise<Position | null> {
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

// Stubs for the trip GPS feature later — kept here so call sites can already
// reference the API even though we don't ship background tracking yet.
export function startTracking(_onUpdate: (p: Position) => void): () => void {
  // TODO: wire to Capacitor watchPosition with background mode
  return () => {};
}
