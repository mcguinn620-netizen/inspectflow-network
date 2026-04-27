import { useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Play, Pause, CheckCircle2, Route as RouteIcon, Navigation, MapPin, Loader2 } from "lucide-react";
import { useActiveTrip } from "@/hooks/useActiveTrip";
import { platformMaps } from "@/platform";
import {
  setTripStatus, canPauseTrip, canResumeTrip, canCompleteTrip, isTripTerminal,
} from "@/lib/tripLifecycle";

/**
 * Global active-trip banner — Phase 5 trip dominance + Phase 6 idempotency.
 *
 * All lifecycle calls flow through tripLifecycle helpers so a stale view or
 * double-tap cannot re-complete a trip. Buttons are disabled while a
 * mutation is in flight to harden against rapid taps on mobile.
 */
export function ActiveTripBanner() {
  const { trip, nextStop, progress, refresh } = useActiveTrip();
  const { pathname } = useLocation();
  const [pending, setPending] = useState(false);

  if (!trip) return null;
  if (pathname.startsWith("/app/inspector/trips")) return null;
  if (!pathname.startsWith("/app/inspector")) return null;
  // Once a trip is finalized, the realtime hook will drop it shortly — but
  // be defensive: never render banner controls for a terminal trip.
  if (isTripTerminal(trip.status)) return null;

  const guard = async (fn: () => Promise<unknown>) => {
    if (pending) return;
    setPending(true);
    try { await fn(); } finally { setPending(false); }
    refresh();
  };

  const navigateNext = () => {
    if (!nextStop) return;
    platformMaps.open({
      address: nextStop.address,
      latitude: nextStop.latitude,
      longitude: nextStop.longitude,
      label: nextStop.label,
    });
  };

  const pct = progress.total ? Math.round((progress.completed / progress.total) * 100) : 0;
  const dateLabel = new Date(trip.trip_date).toLocaleDateString([], { month: "short", day: "numeric" });

  return (
    <div className="sticky top-0 z-30 -mx-4 md:mx-0 px-4 md:px-0 pt-1 pb-2 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80">
      <div className="rounded-lg border-2 border-primary bg-primary/10 shadow-sm overflow-hidden">
        <div className="px-3 pt-2.5 pb-1.5 flex items-center gap-2 flex-wrap">
          <div className={`h-2.5 w-2.5 rounded-full bg-primary ${trip.status === "active" ? "animate-pulse" : ""}`} />
          <p className="text-sm font-semibold truncate min-w-0 flex-1">
            {trip.title || `Trip · ${dateLabel}`}
          </p>
          <Badge variant="default" className="capitalize text-[10px] h-5">{trip.status}</Badge>
          {progress.total > 0 && (
            <span className="text-[11px] font-medium text-muted-foreground tabular-nums">
              Stop {Math.min(progress.completed + (nextStop ? 1 : 0), progress.total)} of {progress.total}
            </span>
          )}
        </div>

        {progress.total > 0 && <Progress value={pct} className="h-1 rounded-none" />}

        <div className="px-3 py-2 flex items-center justify-between gap-2 flex-wrap">
          <div className="min-w-0 flex-1">
            {nextStop ? (
              <>
                <p className="text-[10px] uppercase tracking-wider text-muted-foreground">Next stop</p>
                <p className="text-sm font-medium truncate">{nextStop.label || nextStop.address || "Stop"}</p>
                {nextStop.address && nextStop.label && (
                  <p className="text-[11px] text-muted-foreground flex items-center gap-1 truncate">
                    <MapPin className="h-3 w-3 shrink-0" />
                    <span className="truncate">{nextStop.address}</span>
                  </p>
                )}
              </>
            ) : (
              <p className="text-xs text-muted-foreground">All stops handled — ready to wrap up</p>
            )}
          </div>
          <div className="flex items-center gap-1.5 flex-wrap shrink-0">
            {nextStop && (nextStop.address || (nextStop.latitude != null && nextStop.longitude != null)) && (
              <Button size="sm" variant="default" onClick={navigateNext} disabled={pending} className="h-8">
                <Navigation className="h-3.5 w-3.5 mr-1" />Go
              </Button>
            )}
            {canPauseTrip(trip.status) && (
              <Button size="sm" variant="ghost" disabled={pending}
                onClick={() => guard(() => setTripStatus(trip, "paused"))} className="h-8 px-2">
                {pending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Pause className="h-3.5 w-3.5" />}
              </Button>
            )}
            {canResumeTrip(trip.status) && (
              <Button size="sm" variant="ghost" disabled={pending}
                onClick={() => guard(() => setTripStatus(trip, "active"))} className="h-8 px-2">
                {pending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Play className="h-3.5 w-3.5" />}
              </Button>
            )}
            {nextStop && (
              <Button size="sm" variant="default" asChild className="h-8">
                <Link to="/app/inspector/drive"><Navigation className="h-3.5 w-3.5 mr-1" />Drive</Link>
              </Button>
            )}
            <Button size="sm" variant="outline" asChild className="h-8">
              <Link to="/app/inspector/trips"><RouteIcon className="h-3.5 w-3.5 mr-1" />Open</Link>
            </Button>
            {!nextStop && canCompleteTrip(trip.status) && (
              <Button size="sm" variant="default" disabled={pending}
                onClick={() => guard(() => setTripStatus(trip, "completed"))} className="h-8">
                {pending ? <Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> : <CheckCircle2 className="h-3.5 w-3.5 mr-1" />}End
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
