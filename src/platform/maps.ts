// Maps platform layer.
// Web: opens Apple/Google/Waze in a new tab using deep links the user prefers.
// Capacitor (future): swap `open()` to `@capacitor/app` `App.openUrl()` so iOS
// hands off to the installed Apple Maps / Google Maps / Waze app, and Android
// uses the geo: intent. The interface here stays stable.
//
// User preference is read from localStorage key `mapProvider` and falls back
// to platform default (Apple on Apple devices, Google elsewhere).

export type MapProvider = "auto" | "apple" | "google" | "waze";

export interface MapTarget {
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  label?: string | null;
}

const STORAGE_KEY = "mapProvider";

export function getProvider(): MapProvider {
  if (typeof localStorage === "undefined") return "auto";
  const v = localStorage.getItem(STORAGE_KEY);
  if (v === "apple" || v === "google" || v === "waze") return v;
  return "auto";
}

export function setProvider(p: MapProvider) {
  if (typeof localStorage === "undefined") return;
  if (p === "auto") localStorage.removeItem(STORAGE_KEY);
  else localStorage.setItem(STORAGE_KEY, p);
}

function isApplePlatform() {
  if (typeof navigator === "undefined") return false;
  return /iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent || "");
}

import { isNative, loadNativePlugin } from "./native";

function isCapacitor() {
  return isNative();
}

function buildQuery(t: MapTarget) {
  if (t.latitude != null && t.longitude != null) return `${t.latitude},${t.longitude}`;
  return t.address ?? t.label ?? "";
}

function resolveProvider(): "apple" | "google" | "waze" {
  const p = getProvider();
  if (p !== "auto") return p;
  return isApplePlatform() ? "apple" : "google";
}

/**
 * Build a deep link URL for the chosen provider.
 * Returns null when the target has no address/coords.
 */
export function buildMapsUrl(t: MapTarget, override?: MapProvider): string | null {
  const q = buildQuery(t);
  if (!q) return null;
  const provider = override && override !== "auto" ? override : resolveProvider();
  const hasCoords = t.latitude != null && t.longitude != null;

  switch (provider) {
    case "apple":
      // Apple Maps universal link — works in browser + native iOS/macOS handoff
      return `https://maps.apple.com/?q=${encodeURIComponent(q)}${
        hasCoords ? `&ll=${t.latitude},${t.longitude}` : ""
      }${t.label ? `&t=${encodeURIComponent(t.label)}` : ""}`;
    case "waze":
      return hasCoords
        ? `https://waze.com/ul?ll=${t.latitude}%2C${t.longitude}&navigate=yes`
        : `https://waze.com/ul?q=${encodeURIComponent(q)}&navigate=yes`;
    case "google":
    default:
      return hasCoords
        ? `https://www.google.com/maps/dir/?api=1&destination=${t.latitude},${t.longitude}`
        : `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(q)}`;
  }
}

/**
 * Open the chosen map provider with a navigation intent.
 * Web: window.open. Capacitor: hand off to native via App.openUrl()
 * (the universal links above will route to installed apps automatically).
 */
export function open(t: MapTarget, override?: MapProvider): boolean {
  const url = buildMapsUrl(t, override);
  if (!url) return false;
  if (isCapacitor()) {
    // Native: hand off to system via Capacitor App plugin. Universal links
    // (Apple Maps / Google Maps / Waze) route to the installed app automatically.
    loadNativePlugin<any>("@capacitor/app")
      .then((m) => m?.App?.openUrl?.({ url }))
      .catch(() => window.open(url, "_blank", "noopener,noreferrer"));
    return true;
  }
  window.open(url, "_blank", "noopener,noreferrer");
  return true;
}

export const PROVIDER_LABELS: Record<MapProvider, string> = {
  auto: "Automatic (system default)",
  apple: "Apple Maps",
  google: "Google Maps",
  waze: "Waze",
};
