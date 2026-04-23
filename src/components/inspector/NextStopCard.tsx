import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Navigation, Flag, Play, CheckCircle2, MapPin } from "lucide-react";
import { useActiveTrip, type ActiveStop } from "@/hooks/useActiveTrip";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { platformMaps } from "@/platform";

/**
 * Next-stop card for Dashboard / Trips top.
 * Drives the field workflow with three primary actions:
 *   Navigate → Arrived → Start job → Complete job
 */
export function NextStopCard() {
  const { trip, nextStop, progress, refresh } = useActiveTrip();
  if (!trip || !nextStop) return null;

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
    refresh();
  };

  const navigate = () => platformMaps.open({
    address: nextStop.address, latitude: nextStop.latitude, longitude: nextStop.longitude, label: nextStop.label,
  });

  return (
    <Card className="border-primary/40">
      <CardContent className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-2 flex-wrap">
          <div className="min-w-0">
            <p className="text-[10px] uppercase tracking-wider text-muted-foreground">Next stop · {progress.completed + 1} of {progress.total}</p>
            <p className="text-base font-semibold truncate mt-0.5">{nextStop.label || "Stop"}</p>
            {nextStop.address && (
              <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
                <MapPin className="h-3 w-3 shrink-0" />
                <span className="truncate">{nextStop.address}</span>
              </p>
            )}
          </div>
          <Badge variant="outline" className="capitalize text-[10px]">{nextStop.status}</Badge>
        </div>

        <div className="grid grid-cols-2 gap-2">
          <Button size="sm" variant="outline" onClick={navigate} disabled={!nextStop.address && nextStop.latitude == null}>
            <Navigation className="h-3.5 w-3.5 mr-1.5" />Navigate
          </Button>
          {nextStop.status === "pending" && (
            <Button size="sm" variant="outline" onClick={() => setStop(nextStop, "arrived", { startJob: !!nextStop.job_id })}>
              <Flag className="h-3.5 w-3.5 mr-1.5" />
              {nextStop.job_id ? "Arrive + Start" : "Mark arrived"}
            </Button>
          )}
          {nextStop.status === "arrived" && nextStop.job_id && (
            <Button size="sm" variant="outline" onClick={() => setStop(nextStop, "arrived", { startJob: true })}>
              <Play className="h-3.5 w-3.5 mr-1.5" />Start job
            </Button>
          )}
          <Button size="sm" variant="default" className="col-span-2"
            onClick={() => setStop(nextStop, "completed", { completeJob: !!nextStop.job_id })}>
            <CheckCircle2 className="h-3.5 w-3.5 mr-1.5" />
            {nextStop.job_id ? "Complete stop + job" : "Complete stop"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
