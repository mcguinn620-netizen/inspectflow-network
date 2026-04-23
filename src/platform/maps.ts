// Maps platform layer.
// Web: opens Apple/Google Maps in a new tab.
// Future Capacitor: forward to native intent (Apple Maps app, Google Maps app,
// Waze) via @capacitor/app or a custom plugin.

export interface MapTarget {
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  label?: string | null;
}

function isApplePlatform() {
  if (typeof navigator === "undefined") return false;
  return /iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent || "");
}

function buildQuery(t: MapTarget) {
  if (t.latitude != null && t.longitude != null) return `${t.latitude},${t.longitude}`;
  return t.address ?? t.label ?? "";
}

export function buildMapsUrl(t: MapTarget): string | null {
  const q = buildQuery(t);
  if (!q) return null;
  if (isApplePlatform()) return `https://maps.apple.com/?q=${encodeURIComponent(q)}`;
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`;
}

export function open(t: MapTarget): boolean {
  const url = buildMapsUrl(t);
  if (!url) return false;
  // TODO: when running under Capacitor, use @capacitor/browser or native intent
  window.open(url, "_blank", "noopener,noreferrer");
  return true;
}
