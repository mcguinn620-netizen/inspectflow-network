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
 */
const config: CapacitorConfig = {
  appId: "app.lovable.c4a81c228a3d4381bec7340e222a48cb",
  appName: "inspectflow-network",
  webDir: "dist",
  bundledWebRuntime: false,
  ios: {
    contentInset: "always",
    limitsNavigationsToAppBoundDomains: false,
    buildOptions: {
      // @ts-expect-error - flag consumed by Capacitor SPM tooling
      enableSPMSupport: true,
    },
  },
  android: {
    allowMixedContent: false,
  },
  plugins: {
    Geolocation: {
      // iOS Info.plist keys are checked into ios/App/App/Info.plist.
    },
    BackgroundGeolocation: {
      desiredAccuracy: 10,
      distanceFilter: 15,
      stopOnTerminate: false,
      startOnBoot: true,
      debug: false,
      locationAuthorizationRequest: "Always",
      notification: {
        title: "Drive Smooth mileage tracking active",
        text: "Tracking location during active trips to calculate business mileage.",
      },
    },
  },
};

export default config;
