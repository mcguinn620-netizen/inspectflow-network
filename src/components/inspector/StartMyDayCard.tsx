import { Link } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Play, Plus, Route as RouteIcon, CalendarDays, Sun } from "lucide-react";
import { useActiveTrip } from "@/hooks/useActiveTrip";

interface Props {
  hasJobsToday: boolean;
  todayJobCount: number;
  onStartTodayTrip: () => void;
}

/**
 * Phase 5 — "Start My Day" entry point.
 *
 * Answers the field question "what do I do first?" depending on state:
 *   - active trip → handled elsewhere (NextStopCard / banner). Hidden.
 *   - paused/draft trip exists → Resume
 *   - jobs today, no trip → Start Today's Trip + Build Route from Schedule
 *   - no jobs at all → Add First Job
 */
export function StartMyDayCard({ hasJobsToday, todayJobCount, onStartTodayTrip }: Props) {
  const { trip } = useActiveTrip();

  // If a trip is active, NextStopCard owns the screen.
  if (trip && trip.status === "active") return null;

  // Paused / draft / planned trip → resume call to action.
  if (trip) {
    return (
      <Card className="border-2 border-primary/60 bg-primary/5">
        <CardContent className="p-4 flex items-center justify-between gap-3 flex-wrap">
          <div className="min-w-0">
            <p className="text-[10px] uppercase tracking-wider font-semibold text-primary">Pick up where you left off</p>
            <p className="text-base font-semibold mt-0.5 capitalize">Trip {trip.status}</p>
            <p className="text-xs text-muted-foreground">Resume to continue your route.</p>
          </div>
          <Button size="lg" onClick={onStartTodayTrip} className="h-11">
            <Play className="h-4 w-4 mr-1.5" />Resume trip
          </Button>
        </CardContent>
      </Card>
    );
  }

  // No trip but has jobs today → Start the day.
  if (hasJobsToday) {
    return (
      <Card className="border-2 border-primary/60 bg-gradient-to-br from-primary/10 to-transparent">
        <CardContent className="p-4 space-y-3">
          <div className="flex items-start gap-3">
            <div className="h-10 w-10 rounded-full bg-primary/15 flex items-center justify-center shrink-0">
              <Sun className="h-5 w-5 text-primary" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] uppercase tracking-wider font-semibold text-primary">Start my day</p>
              <p className="text-base font-semibold mt-0.5">
                {todayJobCount} job{todayJobCount === 1 ? "" : "s"} on today's schedule
              </p>
              <p className="text-xs text-muted-foreground">Start a trip to track miles, time, and progress.</p>
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <Button size="lg" onClick={onStartTodayTrip} className="h-11">
              <Play className="h-4 w-4 mr-1.5" />Start today's trip
            </Button>
            <Button size="lg" variant="outline" asChild className="h-11">
              <Link to="/app/inspector/schedule">
                <RouteIcon className="h-4 w-4 mr-1.5" />Build route from schedule
              </Link>
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  // No trip, no jobs → onboard the inspector.
  return (
    <Card className="border-dashed border-2">
      <CardContent className="p-6 text-center space-y-3">
        <div className="h-12 w-12 rounded-full bg-muted mx-auto flex items-center justify-center">
          <CalendarDays className="h-6 w-6 text-muted-foreground" />
        </div>
        <div>
          <p className="text-base font-semibold">Nothing scheduled</p>
          <p className="text-xs text-muted-foreground mt-1">Add a job to get your day started.</p>
        </div>
        <div className="flex gap-2 justify-center flex-wrap">
          <Button size="lg" asChild className="h-11">
            <Link to="/app/inspector/jobs"><Plus className="h-4 w-4 mr-1.5" />Add first job</Link>
          </Button>
          <Button size="lg" variant="outline" asChild className="h-11">
            <Link to="/app/inspector/schedule"><CalendarDays className="h-4 w-4 mr-1.5" />Open schedule</Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
