// Storage platform layer.
// Web: localStorage. Native (Capacitor): @capacitor/preferences (encrypted on iOS,
// SharedPreferences on Android — survives app reinstall when iCloud Keychain is on).
//
// Use this instead of touching localStorage directly for any value that needs to
// survive across native app launches (map provider preference, calendar feed
// token cache, drive-mode opt-in, etc.).

import { isNative, loadNativePlugin } from "./native";

export async function getItem(key: string): Promise<string | null> {
  if (isNative()) {
    const mod = await loadNativePlugin<any>("@capacitor/preferences");
    if (mod?.Preferences) {
      const { value } = await mod.Preferences.get({ key });
      return value ?? null;
    }
  }
  if (typeof localStorage === "undefined") return null;
  return localStorage.getItem(key);
}

export async function setItem(key: string, value: string): Promise<void> {
  if (isNative()) {
    const mod = await loadNativePlugin<any>("@capacitor/preferences");
    if (mod?.Preferences) {
      await mod.Preferences.set({ key, value });
      return;
    }
  }
  if (typeof localStorage !== "undefined") localStorage.setItem(key, value);
}

export async function removeItem(key: string): Promise<void> {
  if (isNative()) {
    const mod = await loadNativePlugin<any>("@capacitor/preferences");
    if (mod?.Preferences) {
      await mod.Preferences.remove({ key });
      return;
    }
  }
  if (typeof localStorage !== "undefined") localStorage.removeItem(key);
}
