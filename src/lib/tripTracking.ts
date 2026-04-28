import { supabase } from "@/integrations/supabase/client";
import { startTripLocationWatch, type LocationSample } from "@/platform/location";

type TrackingStatus = "idle" | "live" | "paused";

interface TrackingSnapshot {
  tripId: string;
  status: TrackingStatus;
  totalMiles: number;
  lastPointAt?: number;
}

const STORAGE_KEY = "tripTracking:state:v1";
const MIN_ACCURACY_METERS = 75;
const MIN_MOVEMENT_METERS = 10;
const MAX_MPH = 110;
const MAX_GAP_MS = 1000 * 60 * 12;
const FLUSH_BATCH_SIZE = 8;
const FLUSH_INTERVAL_MS = 6000;

let stopWatch: (() => void) | null = null;
let flushTimer: number | null = null;
let snapshot: TrackingSnapshot | null = null;
let pointBuffer: any[] = [];
let lastWrittenPoint: LocationSample | null = null;
let listeners = new Set<(s: TrackingSnapshot | null) => void>();

function readState(): TrackingSnapshot | null {
  if (typeof localStorage === "undefined") return null;
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
  } catch {
    return null;
  }
}

function writeState(next: TrackingSnapshot | null) {
  if (typeof localStorage === "undefined") return;
  if (!next) {
    localStorage.removeItem(STORAGE_KEY);
    return;
  }
  localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
}

function emit() {
  writeState(snapshot);
  listeners.forEach((cb) => cb(snapshot));
}

export function subscribeTripTrackingState(cb: (s: TrackingSnapshot | null) => void): () => void {
  listeners.add(cb);
  cb(snapshot ?? readState());
  return () => listeners.delete(cb);
}

export function getTripTrackingState(): TrackingSnapshot | null {
  return snapshot ?? readState();
}

export function haversineMiles(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const toRad = (n: number) => (n * Math.PI) / 180;
  const R = 3958.7613;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function distanceMeters(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  return haversineMiles(a, b) * 1609.344;
}

function isDuplicatePoint(next: LocationSample) {
  if (!lastWrittenPoint) return false;
  const dt = Math.abs(next.timestamp - lastWrittenPoint.timestamp);
  return dt < 1500 && distanceMeters(next, lastWrittenPoint) < 3;
}

function isImpossibleJump(next: LocationSample) {
  if (!lastWrittenPoint) return false;
  const miles = haversineMiles(lastWrittenPoint, next);
  const dtHours = Math.max((next.timestamp - lastWrittenPoint.timestamp) / 3_600_000, 0.0001);
  const mph = miles / dtHours;
  if (next.timestamp - lastWrittenPoint.timestamp > MAX_GAP_MS) return false;
  return mph > MAX_MPH;
}

function shouldRecordPoint(next: LocationSample) {
  if (typeof next.accuracy === "number" && next.accuracy > MIN_ACCURACY_METERS) return false;
  if (isDuplicatePoint(next) || isImpossibleJump(next)) return false;
  if (!lastWrittenPoint) return true;
  return distanceMeters(lastWrittenPoint, next) >= MIN_MOVEMENT_METERS;
}

async function flushPoints() {
  if (!snapshot || pointBuffer.length === 0) return;
  const chunk = pointBuffer.splice(0, FLUSH_BATCH_SIZE);
  const { error } = await supabase.from("trip_location_points").insert(chunk);
  if (error) {
    pointBuffer = [...chunk, ...pointBuffer].slice(0, FLUSH_BATCH_SIZE * 4);
  }
}

function scheduleFlush() {
  if (flushTimer != null) return;
  flushTimer = window.setTimeout(async () => {
    flushTimer = null;
    await flushPoints();
    if (pointBuffer.length) scheduleFlush();
  }, FLUSH_INTERVAL_MS);
}

async function resolveTripMeta(tripId: string) {
  const { data, error } = await supabase
    .from("trips")
    .select("id,organization_id,user_id,total_miles,status")
    .eq("id", tripId)
    .maybeSingle();
  if (error || !data) return null;
  return data;
}

async function onLocation(next: LocationSample) {
  if (!snapshot || snapshot.status !== "live") return;
  if (!shouldRecordPoint(next)) return;

  const distance = lastWrittenPoint ? haversineMiles(lastWrittenPoint, next) : 0;
  snapshot.totalMiles = Number((snapshot.totalMiles + distance).toFixed(5));
  snapshot.lastPointAt = next.timestamp;

  const meta = await resolveTripMeta(snapshot.tripId);
  if (!meta) return;

  pointBuffer.push({
    trip_id: meta.id,
    organization_id: meta.organization_id,
    user_id: meta.user_id,
    latitude: next.latitude,
    longitude: next.longitude,
    accuracy: next.accuracy ?? null,
    speed: next.speed ?? null,
    heading: next.heading ?? null,
    distance_from_previous_miles: distance,
    recorded_at: new Date(next.timestamp).toISOString(),
  });

  lastWrittenPoint = next;
  emit();

  if (pointBuffer.length >= FLUSH_BATCH_SIZE) {
    await flushPoints();
  } else {
    scheduleFlush();
  }

  await supabase.from("trips").update({ total_miles: snapshot.totalMiles }).eq("id", snapshot.tripId);
}

function stopWatcher() {
  if (stopWatch) {
    stopWatch();
    stopWatch = null;
  }
}

async function bootstrapLastPoint(tripId: string) {
  const { data } = await supabase
    .from("trip_location_points")
    .select("latitude,longitude,recorded_at")
    .eq("trip_id", tripId)
    .order("recorded_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!data) {
    lastWrittenPoint = null;
    return;
  }
  lastWrittenPoint = {
    latitude: Number(data.latitude),
    longitude: Number(data.longitude),
    timestamp: new Date(data.recorded_at).getTime(),
  };
}

export async function startTripTracking(trip: { id: string }) {
  await stopTripTracking();
  const meta = await resolveTripMeta(trip.id);
  if (!meta) return;
  await bootstrapLastPoint(trip.id);
  snapshot = {
    tripId: trip.id,
    status: "live",
    totalMiles: Number(meta.total_miles ?? 0),
  };
  stopWatch = startTripLocationWatch((p) => {
    onLocation(p);
  });
  emit();
}

export async function resumeTripTracking(trip: { id: string }) {
  if (snapshot?.tripId === trip.id && snapshot.status === "live") return;
  await startTripTracking(trip);
}

export async function pauseTripTracking() {
  if (!snapshot) return;
  snapshot.status = "paused";
  stopWatcher();
  await flushPoints();
  emit();
}

export async function stopTripTracking() {
  stopWatcher();
  if (flushTimer != null) {
    window.clearTimeout(flushTimer);
    flushTimer = null;
  }
  await flushPoints();
  snapshot = null;
  pointBuffer = [];
  lastWrittenPoint = null;
  emit();
}

export async function restoreTripTrackingFromStorage() {
  const stored = readState();
  if (!stored) return;
  snapshot = stored;
  if (stored.status === "live") {
    await resumeTripTracking({ id: stored.tripId });
  } else {
    emit();
  }
}
