// Tiny helper that lets the platform/* modules detect Capacitor without a
// static import. Keeping the import dynamic avoids breaking the web build when
// the native plugins aren't bundled and lets Vite tree-shake them away.

export function isNative(): boolean {
  const cap = (globalThis as any).Capacitor;
  return !!(cap && typeof cap.isNativePlatform === "function" && cap.isNativePlatform());
}

export function getPlatform(): "ios" | "android" | "web" {
  const cap = (globalThis as any).Capacitor;
  const p = cap?.getPlatform?.();
  if (p === "ios" || p === "android") return p;
  return "web";
}

/**
 * Dynamically import a native plugin. Returns null on web or if the plugin is
 * unavailable. We hide the import behind `new Function` so Vite/Rolldown does
 * not try to resolve the package at build time when only the web bundle is
 * being produced.
 */
export async function loadNativePlugin<T = unknown>(moduleName: string): Promise<T | null> {
  if (!isNative()) return null;
  try {
    const dynamicImport = new Function("m", "return import(m)") as (m: string) => Promise<T>;
    return await dynamicImport(moduleName);
  } catch {
    return null;
  }
}
