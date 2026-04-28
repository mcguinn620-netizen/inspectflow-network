import { getPlatform, isNative, loadNativePlugin } from "./native";

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

export type TripTrackingMode = "background" | "foreground" | "unavailable";

export interface TrackingCapability {
  mode: TripTrackingMode;
  label:
    | "Live tracking on"
    | "Background tracking on"
    | "Foreground tracking only"
    | "Tracking paused"
    | "Location permission needed"
    | "Background permission needed";
  warning?: string;
  foregroundPermissionGranted: boolean;
  backgroundPermissionGranted: boolean;
  isNative: boolean;
}

interface NativeGeolocationPlugin {
  getCurrentPosition: (options?: Record<string, unknown>) => Promise<unknown>;
  watchPosition: (options: Record<string, unknown>, callback: (position: unknown) => void) => Promise<string>;
  clearWatch?: (options: { id: string | number }) => Promise<void>;
  checkPermissions: () => Promise<Record<string, string>>;
  requestPermissions: () => Promise<Record<string, string>>;
}

interface BackgroundSubscription {
  remove?: () => void;
}

interface BackgroundGeolocationPlugin {
  DESIRED_ACCURACY_HIGH: number;
  requestPermission?: () => Promise<unknown>;
  onLocation: (
    success: (location: unknown) => void,
    failure?: (error: unknown) => void,
  ) => Promise<BackgroundSubscription>;
  ready: (config: Record<string, unknown>) => Promise<unknown>;
  start: () => Promise<void>;
  stop: () => Promise<void>;
}

export interface TripLocationWatchOptions {
  onUpdate: (p: LocationSample) => void;
  onError?: (error: unknown) => void;
  distanceFilterMeters?: number;
  intervalMs?: number;
}

const BG_WARNING =
  "Tracking may pause when the app is closed or the screen locks. Enable background location for accurate mileage.";

let currentStopFn: (() => void) | null = null;
let lastCapability: TrackingCapability = {
  mode: "unavailable",
  label: "Location permission needed",
  warning: BG_WARNING,
  foregroundPermissionGranted: false,
  backgroundPermissionGranted: false,
  isNative: false,
};

function normalizeCoords(p: unknown): LocationSample | null {
  const raw = p as Record<string, unknown> | null;
  const coords = ((raw?.coords as Record<string, unknown> | undefined) ?? raw) as Record<string, unknown> | null;
  if (typeof coords?.latitude !== "number" || typeof coords?.longitude !== "number") return null;
  return {
    latitude: coords.latitude,
    longitude: coords.longitude,
    accuracy: typeof coords.accuracy === "number" ? coords.accuracy : undefined,
    speed: typeof coords.speed === "number" ? coords.speed : undefined,
    heading: typeof coords.heading === "number" ? coords.heading : undefined,
    timestamp: typeof raw?.timestamp === "number" ? (raw.timestamp as number) : Date.now(),
  };
}

async function getNativeGeolocation(): Promise<NativeGeolocationPlugin | null> {
  const mod = await loadNativePlugin<Record<string, unknown>>("@capacitor/geolocation");
  return (mod?.Geolocation as NativeGeolocationPlugin | undefined) ?? null;
}

async function getBackgroundGeolocation(): Promise<BackgroundGeolocationPlugin | null> {
  const mod = await loadNativePlugin<Record<string, unknown>>("@transistorsoft/capacitor-background-geolocation");
  const plugin = (mod?.BackgroundGeolocation ?? mod?.default ?? null) as BackgroundGeolocationPlugin | null;
  return plugin;
}

async function ensureForegroundPermission(): Promise<boolean> {
  if (!isNative()) return typeof navigator !== "undefined" && !!navigator.geolocation;

  const geo = await getNativeGeolocation();
  if (!geo) return false;

  try {
    const current = await geo.checkPermissions();
    const coarse = current?.coarseLocation;
    const location = current?.location;
    if (location === "granted" || coarse === "granted") return true;
  } catch {
    // continue to request
  }

  try {
    const requested = await geo.requestPermissions();
    return requested?.location === "granted" || requested?.coarseLocation === "granted";
  } catch {
    return false;
  }
}

async function ensureBackgroundPermission(): Promise<boolean> {
  if (!isNative()) return false;

  const plugin = await getBackgroundGeolocation();
  if (!plugin) return false;

  try {
    if (typeof plugin.requestPermission === "function") {
      const status = await plugin.requestPermission();
      const state = typeof status === "string" ? status.toLowerCase() : String((status as Record<string, unknown> | null)?.status ?? "").toLowerCase();
      return state.includes("always") || state.includes("authorized") || state.includes("granted");
    }
  } catch {
    return false;
  }

  return false;
}

async function computeCapability(): Promise<TrackingCapability> {
  const native = isNative();
  const foregroundGranted = await ensureForegroundPermission();

  if (!foregroundGranted) {
    return {
      mode: "unavailable",
      label: "Location permission needed",
      warning: BG_WARNING,
      foregroundPermissionGranted: false,
      backgroundPermissionGranted: false,
      isNative: native,
    };
  }

  if (!native) {
    return {
      mode: "foreground",
      label: "Foreground tracking only",
      warning: BG_WARNING,
      foregroundPermissionGranted: true,
      backgroundPermissionGranted: false,
      isNative: false,
    };
  }

  const hasBgPlugin = !!(await getBackgroundGeolocation());
  const backgroundGranted = hasBgPlugin ? await ensureBackgroundPermission() : false;

  if (hasBgPlugin && backgroundGranted) {
    return {
      mode: "background",
      label: "Background tracking on",
      foregroundPermissionGranted: true,
      backgroundPermissionGranted: true,
      isNative: true,
    };
  }

  return {
    mode: "foreground",
    label: hasBgPlugin ? "Background permission needed" : "Foreground tracking only",
    warning: BG_WARNING,
    foregroundPermissionGranted: true,
    backgroundPermissionGranted: false,
    isNative: true,
  };
}

async function startForegroundLocationWatch(options: TripLocationWatchOptions): Promise<() => void> {
  let watchId: string | number | null = null;

  if (isNative()) {
    const geo = await getNativeGeolocation();
    if (!geo) return () => {};

    watchId = await geo.watchPosition(
      {
        enableHighAccuracy: true,
        maximumAge: 1000,
        timeout: options.intervalMs ?? 10_000,
      },
      (p: unknown) => {
        const sample = normalizeCoords(p);
        if (sample) options.onUpdate(sample);
      },
    );

    return () => {
      if (watchId != null) {
        void geo.clearWatch?.({ id: watchId });
      }
    };
  }

  if (typeof navigator === "undefined" || !navigator.geolocation) return () => {};
  watchId = navigator.geolocation.watchPosition(
    (p) => {
      const sample = normalizeCoords(p);
      if (sample) options.onUpdate(sample);
    },
    (err) => options.onError?.(err),
    {
      enableHighAccuracy: true,
      maximumAge: 2_000,
      timeout: options.intervalMs ?? 10_000,
    },
  );

  return () => {
    if (typeof watchId === "number") navigator.geolocation.clearWatch(watchId);
  };
}

async function startBackgroundLocationWatch(options: TripLocationWatchOptions): Promise<(() => void) | null> {
  const bg = await getBackgroundGeolocation();
  if (!bg) return null;

  try {
    const locationSub = await bg.onLocation(
      (location: unknown) => {
        const sample = normalizeCoords(location);
        if (sample) options.onUpdate(sample);
      },
      (error: unknown) => options.onError?.(error),
    );

    await bg.ready({
      desiredAccuracy: bg.DESIRED_ACCURACY_HIGH,
      distanceFilter: options.distanceFilterMeters ?? 15,
      stopOnTerminate: false,
      startOnBoot: true,
      preventSuspend: true,
      debug: false,
      heartbeatInterval: 60,
      locationUpdateInterval: options.intervalMs ?? 10_000,
      fastestLocationUpdateInterval: Math.max((options.intervalMs ?? 10_000) / 2, 5_000),
      notification: {
        title: "Drive Smooth mileage tracking active",
        text: "Tracking location during active trips to calculate business mileage.",
        channelName: "Mileage Tracking",
      },
    });

    await bg.start();

    return () => {
      if (typeof locationSub?.remove === "function") {
        locationSub.remove();
      }
      void bg.stop();
    };
  } catch (error) {
    options.onError?.(error);
    return null;
  }
}

export async function getCurrent(): Promise<LocationSample | null> {
  if (isNative()) {
    const geo = await getNativeGeolocation();
    try {
      const p = await geo?.getCurrentPosition({ enableHighAccuracy: true, timeout: 8000 });
      const sample = normalizeCoords(p);
      if (sample) return sample;
    } catch {
      /* fall through to web */
    }
  }

  if (typeof navigator === "undefined" || !navigator.geolocation) return null;
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (p) => resolve(normalizeCoords(p)),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 30_000 },
    );
  });
}

export async function startTripLocationWatch(options: TripLocationWatchOptions): Promise<TrackingCapability> {
  await stopTripLocationWatch();

  const capability = await computeCapability();
  let stop: (() => void) | null = null;

  if (capability.mode === "background") {
    stop = await startBackgroundLocationWatch(options);
  }

  if (!stop && capability.mode !== "unavailable") {
    stop = await startForegroundLocationWatch(options);
  }

  currentStopFn = stop;
  lastCapability = capability;
  return capability;
}

export async function stopTripLocationWatch() {
  if (!currentStopFn) return;
  const stop = currentStopFn;
  currentStopFn = null;
  stop();
}

export async function isBackgroundTrackingAvailable(): Promise<boolean> {
  if (!isNative()) return false;
  const capability = await computeCapability();
  lastCapability = capability;
  return capability.mode === "background";
}

export async function getTrackingCapability(): Promise<TrackingCapability> {
  lastCapability = await computeCapability();
  return lastCapability;
}

export function getTrackingCapabilitySnapshot(): TrackingCapability {
  return lastCapability;
}

export function getTrackingModeLabel(capability: TrackingCapability | null, status: "idle" | "live" | "paused") {
  if (status === "paused") return "Tracking paused" as const;
  if (!capability) return "Location permission needed" as const;
  if (status !== "live") return "Tracking paused" as const;
  return capability.label;
}

// Backwards-compatible alias for existing callers.
export function startTracking(onUpdate: (p: Position) => void): () => void {
  void startTripLocationWatch({ onUpdate });
  return () => {
    void stopTripLocationWatch();
  };
}

export function getTrackingPlatform() {
  return getPlatform();
}
