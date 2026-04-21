// Map handoff utilities — opens external Maps apps for navigation.
// CarPlay/Android Auto integration hook point: when wrapped in a native shell
// (Capacitor/RN), replace these openers with platform-specific intents that
// the in-car UI surfaces automatically. Web stays as planning/logging hub.

export interface MapTarget {
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  label?: string | null;
}

function isApplePlatform() {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent || "";
  return /iPhone|iPad|iPod|Macintosh/.test(ua);
}

function buildQuery(target: MapTarget) {
  if (target.latitude != null && target.longitude != null) {
    return `${target.latitude},${target.longitude}`;
  }
  return target.address ?? target.label ?? "";
}

export function buildMapsUrl(target: MapTarget): string | null {
  const q = buildQuery(target);
  if (!q) return null;
  if (isApplePlatform()) {
    return `https://maps.apple.com/?q=${encodeURIComponent(q)}`;
  }
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`;
}

export function openInMaps(target: MapTarget) {
  const url = buildMapsUrl(target);
  if (!url) return false;
  window.open(url, "_blank", "noopener,noreferrer");
  return true;
}
