import { Link, useLocation } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Play, Pause, CheckCircle2, Route as RouteIcon, Navigation, MapPin } from "lucide-react";
import { useActiveTrip } from "@/hooks/useActiveTrip";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { platformMaps } from "@/platform";

/**
 * Global active-trip banner — Phase 5 trip dominance.
 *
 * Visual priority above page content. On mobile the banner sticks to the
 * top of the scroll container so the next action is always visible while
 * the inspector is in trip mode.
 */
export function ActiveTripBanner() {
  const { trip, nextStop, progress, refresh } = useActiveTrip();
  const { pathname } = useLocation();

  if (!trip) return null;
  // /trips already shows the full trip surface — keep the banner there
  // hidden to avoid duplication, but show on every other inspector page.
  if (pathname.startsWith("/app/inspector/trips")) return null;
  if (!pathname.startsWith("/app/inspector")) return null;

  const setStatus = async (status: string) => {
    const updates: any = { status };
    if (status === "active" && !trip.started_at) updates.started_at = new Date().toISOString();
    if (status === "paused") updates.paused_at = new Date().toISOString();
    if (status === "completed") updates.completed_at = new Date().toISOString();
    const { error } = await supabase.from("trips").update(updates).eq("id", trip.id);
    if (error) return toast.error(error.message);
    toast.success(`Trip ${status}`);
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
        {/* Top row: trip identity + progress */}
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

        {/* Progress bar */}
        {progress.total > 0 && (
          <Progress value={pct} className="h-1 rounded-none" />
        )}

        {/* Next stop strip */}
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
              <Button size="sm" variant="default" onClick={navigateNext} className="h-8">
                <Navigation className="h-3.5 w-3.5 mr-1" />Go
              </Button>
            )}
            {trip.status === "active" ? (
              <Button size="sm" variant="ghost" onClick={() => setStatus("paused")} className="h-8 px-2">
                <Pause className="h-3.5 w-3.5" />
              </Button>
            ) : (
              <Button size="sm" variant="ghost" onClick={() => setStatus("active")} className="h-8 px-2">
                <Play className="h-3.5 w-3.5" />
              </Button>
            )}
            <Button size="sm" variant="outline" asChild className="h-8">
              <Link to="/app/inspector/trips"><RouteIcon className="h-3.5 w-3.5 mr-1" />Open</Link>
            </Button>
            {!nextStop && (
              <Button size="sm" variant="default" onClick={() => setStatus("completed")} className="h-8">
                <CheckCircle2 className="h-3.5 w-3.5 mr-1" />End
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
