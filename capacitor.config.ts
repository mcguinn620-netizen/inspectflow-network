import type { CapacitorConfig } from "@capacitor/cli";

/**
 * Capacitor configuration for the InspectFlow Network mobile shell.
 *
 * IMPORTANT — running this on a real device:
 *   1. Push this repo to your own GitHub (Lovable's "Export to GitHub" button).
 *   2. `git pull` locally and run `bun install` (or `npm install`).
 *   3. Build the web bundle: `bun run build`.
 *   4. Add platforms: `npx cap add ios` and/or `npx cap add android`.
 *   5. Sync: `npx cap sync`.
 *   6. Open in Xcode/Android Studio: `npx cap open ios` / `npx cap open android`.
 *
 * The bundled web build (`webDir: "dist"`) is shipped inside the native app —
 * no live-reload from the Lovable sandbox. Change to `server.url` if you want
 * device-side hot reload during native development.
 *
 * CarPlay / Android Auto:
 *   The native projects under `ios/App/App/CarPlay/` and
 *   `android/app/src/main/java/.../car/` contain stub Swift / Kotlin scenes that
 *   read trip + stop data from the same Supabase backend the web app uses.
 *   See `docs/native/CARPLAY_CONTRACT.md` for the JSON contract.
 */
const config: CapacitorConfig = {
  appId: "app.lovable.c4a81c228a3d4381bec7340e222a48cb",
  appName: "inspectflow-network",
  webDir: "dist",
  bundledWebRuntime: false,
  ios: {
    contentInset: "always",
    limitsNavigationsToAppBoundDomains: false,
  },
  android: {
    allowMixedContent: false,
  },
  plugins: {
    Geolocation: {
      // iOS Info.plist requires NSLocationWhenInUseUsageDescription — set in Xcode.
    },
  },
};

export default config;
