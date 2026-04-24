import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Navigation, Flag, Play, CheckCircle2, MapPin, ArrowRight } from "lucide-react";
import { useActiveTrip, type ActiveStop } from "@/hooks/useActiveTrip";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { platformMaps } from "@/platform";

/**
 * Next-stop card for Dashboard / Trips top — Phase 5.
 *
 * One-tap field workflow: Navigate → Arrive (+ start job) → Complete.
 * After complete, realtime updates auto-advance to the next stop in the
 * same card (the user never leaves trip context).
 */
export function NextStopCard() {
  const { trip, nextStop, stops, progress, refresh } = useActiveTrip();
  if (!trip || !nextStop) return null;

  const upcomingAfter = stops
    .filter(s => s.id !== nextStop.id && s.status !== "completed" && s.status !== "skipped")
    .slice(0, 1)[0];
  const pct = progress.total ? Math.round((progress.completed / progress.total) * 100) : 0;
  const stopNumber = progress.completed + 1;

  const setStop = async (s: ActiveStop, status: string, opts: { startJob?: boolean; completeJob?: boolean } = {}) => {
    const updates: any = { status };
    const now = new Date().toISOString();
    if (status === "arrived") updates.arrived_at = now;
    if (status === "completed") { updates.completed_at = now; updates.departed_at = now; }
    if (status === "skipped") updates.departed_at = now;
    const { error } = await supabase.from("trip_stops").update(updates).eq("id", s.id);
    if (error) return toast.error(error.message);

    if (s.job_id) {
      if (opts.startJob)
        await supabase.from("jobs").update({ status: "in_progress", actual_start_time: now }).eq("id", s.job_id);
      if (opts.completeJob)
        await supabase.from("jobs").update({ status: "completed", actual_end_time: now }).eq("id", s.job_id);
    }
    if (status === "completed") toast.success("Stop completed — moving to next");
    refresh();
  };

  const navigate = () => platformMaps.open({
    address: nextStop.address, latitude: nextStop.latitude, longitude: nextStop.longitude, label: nextStop.label,
  });

  return (
    <Card className="border-2 border-primary shadow-md">
      <CardContent className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-2 flex-wrap">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2 flex-wrap">
              <p className="text-[10px] uppercase tracking-wider font-semibold text-primary">
                Next stop · {stopNumber} of {progress.total}
              </p>
              <Badge variant="outline" className="capitalize text-[10px] h-4">{nextStop.status}</Badge>
            </div>
            <p className="text-lg font-semibold truncate mt-0.5">{nextStop.label || "Stop"}</p>
            {nextStop.address && (
              <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
                <MapPin className="h-3 w-3 shrink-0" />
                <span className="truncate">{nextStop.address}</span>
              </p>
            )}
          </div>
        </div>

        {progress.total > 1 && <Progress value={pct} className="h-1.5" />}

        {/* One-tap action ladder */}
        <div className="grid grid-cols-2 gap-2">
          <Button
            size="default"
            variant="outline"
            onClick={navigate}
            disabled={!nextStop.address && nextStop.latitude == null}
            className="h-11"
          >
            <Navigation className="h-4 w-4 mr-1.5" />Navigate
          </Button>
          {nextStop.status === "pending" ? (
            <Button
              size="default"
              variant="outline"
              onClick={() => setStop(nextStop, "arrived", { startJob: !!nextStop.job_id })}
              className="h-11"
            >
              <Flag className="h-4 w-4 mr-1.5" />
              {nextStop.job_id ? "Arrive + Start" : "Arrived"}
            </Button>
          ) : nextStop.status === "arrived" && nextStop.job_id ? (
            <Button
              size="default"
              variant="outline"
              onClick={() => setStop(nextStop, "arrived", { startJob: true })}
              className="h-11"
            >
              <Play className="h-4 w-4 mr-1.5" />Start job
            </Button>
          ) : (
            <Button
              size="default"
              variant="outline"
              disabled
              className="h-11"
            >
              <Flag className="h-4 w-4 mr-1.5" />On site
            </Button>
          )}
          <Button
            size="default"
            variant="default"
            className="col-span-2 h-12 text-base font-semibold"
            onClick={() => setStop(nextStop, "completed", { completeJob: !!nextStop.job_id })}
          >
            <CheckCircle2 className="h-5 w-5 mr-2" />
            {nextStop.job_id ? "Complete stop + job" : "Complete stop"}
          </Button>
        </div>

        {/* "Up next" preview keeps user in trip context after completion */}
        {upcomingAfter && (
          <div className="flex items-center gap-2 pt-1 text-[11px] text-muted-foreground border-t">
            <ArrowRight className="h-3 w-3 shrink-0" />
            <span className="truncate">After this: <span className="text-foreground font-medium">{upcomingAfter.label || upcomingAfter.address || "next stop"}</span></span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
