import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { ArrowLeft, CheckCircle2, Flag, Loader2, MapPin, SkipForward, Volume2, VolumeX } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { TripMapOverlay, type MapStop } from "@/components/maps/TripMapOverlay";
import { OpenInMapsButton } from "@/components/maps/OpenInMapsButton";
import { useActiveTrip, type ActiveStop } from "@/hooks/useActiveTrip";
import { useWakeLock } from "@/hooks/useWakeLock";
import { isVoiceEnabled, setVoiceEnabled, speak } from "@/lib/voiceCue";
import { startTracking, type Position } from "@/platform/location";
import { setStopStatus, canArriveStop, canCompleteStop } from "@/lib/tripLifecycle";
import { toast } from "sonner";

// Haversine distance in meters
function distanceMeters(a: { lat: number; lon: number }, b: { lat: number; lon: number }) {
  const R = 6371000;
  const toRad = (n: number) => (n * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

const ARRIVE_RADIUS_METERS = 75;
const REQUIRED_HITS = 2;

export default function InspectorDrive() {
  const navigate = useNavigate();
  const { trip, stops, nextStop, routePoints, progress, refresh, loading } = useActiveTrip();
  const [voice, setVoice] = useState(isVoiceEnabled());
  const [pending, setPending] = useState(false);
  const [userPos, setUserPos] = useState<Position | null>(null);
  const lastAnnouncedRef = useRef<string | null>(null);
  const arriveHitsRef = useRef<{ id: string; count: number } | null>(null);
  const promptedRef = useRef<Set<string>>(new Set());

  useWakeLock(true);

  // Voice cue when next stop changes
  useEffect(() => {
    if (!nextStop) return;
    if (lastAnnouncedRef.current === nextStop.id) return;
    lastAnnouncedRef.current = nextStop.id;
    speak(`Next stop, ${nextStop.label || "destination"}`);
  }, [nextStop?.id]);

  // Track user position
  useEffect(() => {
    const stop = startTracking((p) => setUserPos(p));
    return stop;
  }, []);

  // Auto-arrive geofence
  useEffect(() => {
    if (!userPos || !nextStop) return;
    if (nextStop.latitude == null || nextStop.longitude == null) return;
    if (promptedRef.current.has(nextStop.id)) return;

    const d = distanceMeters(
      { lat: userPos.latitude, lon: userPos.longitude },
      { lat: Number(nextStop.latitude), lon: Number(nextStop.longitude) },
    );

    if (d < ARRIVE_RADIUS_METERS) {
      const prev = arriveHitsRef.current;
      const count = prev?.id === nextStop.id ? prev.count + 1 : 1;
      arriveHitsRef.current = { id: nextStop.id, count };
      if (count >= REQUIRED_HITS) {
        promptedRef.current.add(nextStop.id);
        speak(`Arriving at ${nextStop.label || "destination"}`);
        toast.success(`Arrived at ${nextStop.label || "stop"}`, {
          description: "Mark this stop arrived?",
          action: {
            label: "Arrived",
            onClick: () => arrive(nextStop),
          },
          duration: 10000,
        });
      }
    } else {
      if (arriveHitsRef.current?.id === nextStop.id) arriveHitsRef.current = null;
    }
  }, [userPos, nextStop]);

  const guard = async (fn: () => Promise<unknown>) => {
    if (pending) return;
    setPending(true);
    try { await fn(); } finally { setPending(false); }
    refresh();
  };

  const arrive = (s: ActiveStop) =>
    guard(() => setStopStatus(s, "arrived", { startJob: !!s.job_id }));
  const complete = (s: ActiveStop) =>
    guard(() => setStopStatus(s, "completed", { completeJob: !!s.job_id }));
  const skip = (s: ActiveStop) =>
    guard(() => setStopStatus(s, "skipped"));

  const toggleVoice = () => {
    const next = !voice;
    setVoice(next);
    setVoiceEnabled(next);
  };

  const mapStops: MapStop[] = stops.map((s) => ({
    id: s.id,
    label: s.label,
    address: s.address,
    latitude: s.latitude,
    longitude: s.longitude,
  }));

  // Distance + naive ETA to next stop
  let distanceLabel: string | null = null;
  let etaLabel: string | null = null;
  if (userPos && nextStop?.latitude != null && nextStop?.longitude != null) {
    const m = distanceMeters(
      { lat: userPos.latitude, lon: userPos.longitude },
      { lat: Number(nextStop.latitude), lon: Number(nextStop.longitude) },
    );
    const km = m / 1000;
    distanceLabel = km < 1 ? `${Math.round(m)} m` : `${km.toFixed(1)} km`;
    const minutes = Math.max(1, Math.round((km / 50) * 60)); // 50 km/h avg
    etaLabel = `~${minutes} min`;
  }

  if (loading) {
    return (
      <div className="h-[100dvh] flex items-center justify-center bg-background">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!trip) {
    return (
      <div className="h-[100dvh] flex flex-col items-center justify-center gap-3 bg-background p-6 text-center">
        <p className="text-sm text-muted-foreground">No active trip.</p>
        <Button asChild variant="outline">
          <Link to="/app/inspector/trips">Open trips</Link>
        </Button>
      </div>
    );
  }

  const pct = progress.total ? Math.round((progress.completed / progress.total) * 100) : 0;

  return (
    <div className="h-[100dvh] w-full flex flex-col bg-background overflow-hidden">
      {/* Top bar */}
      <header className="shrink-0 border-b bg-background/95 backdrop-blur">
        <div className="flex items-center gap-2 px-3 py-2">
          <Button size="icon" variant="ghost" onClick={() => navigate("/app/inspector/trips")} aria-label="Exit drive mode">
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold truncate">{trip.title || "Active trip"}</p>
            <div className="flex items-center gap-2 text-[11px] text-muted-foreground">
              <Badge variant="outline" className="capitalize text-[10px] h-4">{trip.status}</Badge>
              <span className="tabular-nums">{progress.completed} / {progress.total} stops</span>
            </div>
          </div>
          <Button size="icon" variant="ghost" onClick={toggleVoice} aria-label={voice ? "Mute voice" : "Enable voice"}>
            {voice ? <Volume2 className="h-5 w-5" /> : <VolumeX className="h-5 w-5 text-muted-foreground" />}
          </Button>
        </div>
        {progress.total > 0 && <Progress value={pct} className="h-1 rounded-none" />}
      </header>

      {/* Map fills remaining space */}
      <div className="flex-1 min-h-0 relative">
        <TripMapOverlay
          stops={mapStops}
          selectedId={nextStop?.id ?? null}
          fullscreen
          className="absolute inset-0"
          actualRoutePoints={routePoints.map((p) => ({ latitude: Number(p.latitude), longitude: Number(p.longitude) }))}
        />
      </div>

      {/* Bottom action sheet */}
      <div className="shrink-0 border-t bg-background">
        {nextStop ? (
          <div className="p-3 space-y-3">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0 flex-1">
                <p className="text-[10px] uppercase tracking-wider font-semibold text-primary">Next stop</p>
                <p className="text-base font-semibold truncate">{nextStop.label || "Stop"}</p>
                {nextStop.address && (
                  <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
                    <MapPin className="h-3 w-3 shrink-0" />
                    <span className="truncate">{nextStop.address}</span>
                  </p>
                )}
              </div>
              {(distanceLabel || etaLabel) && (
                <div className="text-right shrink-0">
                  {distanceLabel && <p className="text-base font-semibold tabular-nums">{distanceLabel}</p>}
                  {etaLabel && <p className="text-[11px] text-muted-foreground tabular-nums">{etaLabel}</p>}
                </div>
              )}
            </div>

            <div className="grid grid-cols-3 gap-2">
              <OpenInMapsButton
                target={{
                  address: nextStop.address,
                  latitude: nextStop.latitude,
                  longitude: nextStop.longitude,
                  label: nextStop.label,
                }}
              />
              <Button variant="outline" onClick={() => skip(nextStop)} disabled={pending}>
                <SkipForward className="h-4 w-4 mr-1.5" />Skip
              </Button>
              {canArriveStop(nextStop.status) ? (
                <Button onClick={() => arrive(nextStop)} disabled={pending}>
                  {pending ? <Loader2 className="h-4 w-4 mr-1.5 animate-spin" /> : <Flag className="h-4 w-4 mr-1.5" />}
                  Arrive
                </Button>
              ) : (
                <Button onClick={() => complete(nextStop)} disabled={pending || !canCompleteStop(nextStop.status)}>
                  {pending ? <Loader2 className="h-4 w-4 mr-1.5 animate-spin" /> : <CheckCircle2 className="h-4 w-4 mr-1.5" />}
                  Done
                </Button>
              )}
            </div>
          </div>
        ) : (
          <div className="p-4 text-center text-sm text-muted-foreground">
            All stops handled.{" "}
            <Link to="/app/inspector/trips" className="text-primary underline">Wrap up trip</Link>
          </div>
        )}
      </div>
    </div>
  );
}
