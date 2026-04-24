import { useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Navigation, Flag, Play, CheckCircle2, MapPin, ArrowRight, Loader2 } from "lucide-react";
import { useActiveTrip, type ActiveStop } from "@/hooks/useActiveTrip";
import { platformMaps } from "@/platform";
import { setStopStatus, canArriveStop, canCompleteStop } from "@/lib/tripLifecycle";

/**
 * Next-stop card — Phase 5 one-tap workflow + Phase 6 idempotency.
 *
 * Each lifecycle button is disabled mid-mutation and routes through the
 * centralized lifecycle helper. Buttons disappear when their transition
 * is no longer valid (canArriveStop / canCompleteStop).
 */
export function NextStopCard() {
  const { trip, nextStop, stops, progress, refresh } = useActiveTrip();
  const [pending, setPending] = useState(false);
  if (!trip || !nextStop) return null;

  const upcomingAfter = stops
    .filter(s => s.id !== nextStop.id && s.status !== "completed" && s.status !== "skipped")
    .slice(0, 1)[0];
  const pct = progress.total ? Math.round((progress.completed / progress.total) * 100) : 0;
  const stopNumber = progress.completed + 1;

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

        <div className="grid grid-cols-2 gap-2">
          <Button size="default" variant="outline" onClick={navigate}
            disabled={!nextStop.address && nextStop.latitude == null}
            className="h-11">
            <Navigation className="h-4 w-4 mr-1.5" />Navigate
          </Button>

          {canArriveStop(nextStop.status) ? (
            <Button size="default" variant="outline" disabled={pending}
              onClick={() => arrive(nextStop)} className="h-11">
              {pending ? <Loader2 className="h-4 w-4 mr-1.5 animate-spin" /> : <Flag className="h-4 w-4 mr-1.5" />}
              {nextStop.job_id ? "Arrive + Start" : "Arrived"}
            </Button>
          ) : (
            <Button size="default" variant="outline" disabled className="h-11">
              <Flag className="h-4 w-4 mr-1.5" />On site
            </Button>
          )}

          <Button size="default" variant="default"
            className="col-span-2 h-12 text-base font-semibold"
            disabled={pending || !canCompleteStop(nextStop.status)}
            onClick={() => complete(nextStop)}>
            {pending ? <Loader2 className="h-5 w-5 mr-2 animate-spin" /> : <CheckCircle2 className="h-5 w-5 mr-2" />}
            {nextStop.job_id ? "Complete stop + job" : "Complete stop"}
          </Button>
        </div>

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
