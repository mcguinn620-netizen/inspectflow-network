import { Link, useLocation } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Play, Pause, CheckCircle2, Route as RouteIcon, Navigation } from "lucide-react";
import { useActiveTrip } from "@/hooks/useActiveTrip";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { platformMaps } from "@/platform";

/**
 * Global active-trip banner.
 * Shown on inspector pages above the page content. Hidden on /trips itself
 * (page already shows full trip UI) and on auth screens.
 */
export function ActiveTripBanner() {
  const { trip, nextStop, progress, refresh } = useActiveTrip();
  const { pathname } = useLocation();

  if (!trip) return null;
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

  return (
    <div className="rounded-lg border border-primary/40 bg-primary/5 p-3 flex items-center justify-between flex-wrap gap-2">
      <div className="flex items-center gap-3 min-w-0 flex-1">
        <div className={`h-2.5 w-2.5 rounded-full bg-primary ${trip.status === "active" ? "animate-pulse" : ""}`} />
        <div className="min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <p className="text-sm font-medium truncate">
              {trip.title || `Trip · ${new Date(trip.trip_date).toLocaleDateString([], { month: "short", day: "numeric" })}`}
            </p>
            <Badge variant="outline" className="capitalize text-[10px]">{trip.status}</Badge>
            {progress.total > 0 && (
              <span className="text-[11px] text-muted-foreground tabular-nums">
                {progress.completed}/{progress.total} stops
              </span>
            )}
          </div>
          {nextStop ? (
            <p className="text-xs text-muted-foreground truncate mt-0.5">
              Next: {nextStop.label || nextStop.address || "Stop"}
            </p>
          ) : (
            <p className="text-xs text-muted-foreground mt-0.5">All stops handled</p>
          )}
        </div>
      </div>
      <div className="flex items-center gap-1.5 flex-wrap">
        {nextStop && (nextStop.address || (nextStop.latitude != null && nextStop.longitude != null)) && (
          <Button size="sm" variant="outline"
            onClick={() => platformMaps.open({
              address: nextStop.address, latitude: nextStop.latitude, longitude: nextStop.longitude, label: nextStop.label,
            })}
          >
            <Navigation className="h-3.5 w-3.5 mr-1" />Go
          </Button>
        )}
        {trip.status === "active" ? (
          <Button size="sm" variant="ghost" onClick={() => setStatus("paused")}>
            <Pause className="h-3.5 w-3.5 mr-1" />Pause
          </Button>
        ) : (
          <Button size="sm" variant="ghost" onClick={() => setStatus("active")}>
            <Play className="h-3.5 w-3.5 mr-1" />Resume
          </Button>
        )}
        <Button size="sm" variant="outline" asChild>
          <Link to="/app/inspector/trips"><RouteIcon className="h-3.5 w-3.5 mr-1" />Open</Link>
        </Button>
        <Button size="sm" variant="default" onClick={() => setStatus("completed")}>
          <CheckCircle2 className="h-3.5 w-3.5 mr-1" />End
        </Button>
      </div>
    </div>
  );
}
