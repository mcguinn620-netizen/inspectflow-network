// Maps platform layer.
// Web: opens Apple/Google/Waze in a new tab using deep links.
// Native (Capacitor): uses App.openUrl so iOS/Android can hand off to device map apps.

import { isNative, loadNativePlugin } from "./native";

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

function isAndroidPlatform() {
  if (typeof navigator === "undefined") return false;
  return /Android/i.test(navigator.userAgent || "");
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

function buildNativeMapsUrl(t: MapTarget, provider: "apple" | "google" | "waze") {
  const q = buildQuery(t);
  const hasCoords = t.latitude != null && t.longitude != null;

  if (provider === "waze") {
    return hasCoords
      ? `waze://?ll=${t.latitude},${t.longitude}&navigate=yes`
      : `https://waze.com/ul?q=${encodeURIComponent(q)}&navigate=yes`;
  }

  if (provider === "apple") {
    return `maps://?q=${encodeURIComponent(q)}${hasCoords ? `&ll=${t.latitude},${t.longitude}` : ""}`;
  }

  if (isAndroidPlatform()) {
    return hasCoords
      ? `geo:${t.latitude},${t.longitude}?q=${t.latitude},${t.longitude}`
      : `geo:0,0?q=${encodeURIComponent(q)}`;
  }

  return hasCoords
    ? `comgooglemaps://?daddr=${t.latitude},${t.longitude}&directionsmode=driving`
    : `comgooglemaps://?daddr=${encodeURIComponent(q)}&directionsmode=driving`;
}

export function buildMapsUrl(t: MapTarget, override?: MapProvider): string | null {
  const q = buildQuery(t);
  if (!q) return null;
  const provider = override && override !== "auto" ? override : resolveProvider();
  const hasCoords = t.latitude != null && t.longitude != null;

  if (isNative()) return buildNativeMapsUrl(t, provider);

  switch (provider) {
    case "apple":
      return `https://maps.apple.com/?q=${encodeURIComponent(q)}${
        hasCoords ? `&ll=${t.latitude},${t.longitude}` : ""
      }`;
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

export function open(t: MapTarget, override?: MapProvider): boolean {
  const url = buildMapsUrl(t, override);
  if (!url) return false;
  if (isNative()) {
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
