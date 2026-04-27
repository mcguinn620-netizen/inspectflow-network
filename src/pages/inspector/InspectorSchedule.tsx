import { useEffect, useMemo, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Clock, MapPin, Route as RouteIcon, Play, CheckCircle2, X, CalendarClock,
  CalendarPlus, ChevronLeft, ChevronRight, Download, AlertTriangle,
} from "lucide-react";
import { Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";
import { OpenInMapsButton } from "@/components/maps/OpenInMapsButton";
import { setJobStatus } from "@/lib/tripLifecycle";
import { platformCalendar } from "@/platform";
import { ScheduleWeekGrid, type ScheduleJob } from "@/components/inspector/ScheduleWeekGrid";
import { detectConflicts, summarizeConflicts } from "@/lib/scheduleConflicts";

interface Job extends ScheduleJob {
  estimated_duration_minutes?: number | null;
  notes?: string | null;
}

type FilterKey = "today" | "upcoming" | "completed" | "all";
type ViewKey = "list" | "week";

const ymd = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

const startOfWeek = (d: Date) => {
  const r = new Date(d);
  r.setHours(0, 0, 0, 0);
  r.setDate(r.getDate() - r.getDay());
  return r;
};

export default function InspectorSchedule() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [editing, setEditing] = useState<Job | null>(null);
  const [newTime, setNewTime] = useState("");
  const [filter, setFilter] = useState<FilterKey>("today");
  const [view, setView] = useState<ViewKey>("list");
  const [weekStart, setWeekStart] = useState<Date>(() => startOfWeek(new Date()));
  const [tripJobIds, setTripJobIds] = useState<Set<string>>(new Set());
  const [activeTripId, setActiveTripId] = useState<string | null>(null);
  const [blockedDates, setBlockedDates] = useState<Set<string>>(new Set());
  const [availability, setAvailability] = useState<
    Record<number, { start_time: string; end_time: string; is_available: boolean }[]>
  >({});

  const load = async () => {
    if (!activeOrgId || !user) return;
    const { data } = await supabase
      .from("jobs")
      .select("id,title,customer_name,location,scheduled_at,status,estimated_duration_minutes,notes")
      .eq("organization_id", activeOrgId)
      .is("deleted_at", null)
      .order("scheduled_at", { ascending: true, nullsFirst: false });
    setJobs((data ?? []) as Job[]);

    const { data: liveTrip } = await supabase
      .from("trips").select("id").eq("user_id", user.id)
      .in("status", ["active", "paused", "draft", "planned"])
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (liveTrip) {
      setActiveTripId(liveTrip.id);
      const { data: stops } = await supabase.from("trip_stops").select("job_id").eq("trip_id", liveTrip.id);
      setTripJobIds(new Set((stops ?? []).map((s: { job_id: string | null }) => s.job_id).filter(Boolean) as string[]));
    } else {
      setActiveTripId(null);
      setTripJobIds(new Set());
    }

    // Linked inspector profile (if any) → blocked dates + availability.
    const { data: insp } = await supabase
      .from("inspectors").select("id").eq("user_id", user.id).limit(1).maybeSingle();
    if (insp?.id) {
      const { data: blocked } = await supabase
        .from("inspector_blocked_dates").select("blocked_date").eq("inspector_id", insp.id);
      setBlockedDates(new Set((blocked ?? []).map((b: { blocked_date: string }) => b.blocked_date)));
      const { data: avail } = await supabase
        .from("availability_schedules")
        .select("day_of_week,start_time,end_time,is_available")
        .eq("inspector_id", insp.id);
      const byDay: Record<number, { start_time: string; end_time: string; is_available: boolean }[]> = {};
      for (const a of avail ?? []) {
        (byDay[a.day_of_week] ??= []).push({
          start_time: a.start_time, end_time: a.end_time, is_available: a.is_available ?? true,
        });
      }
      setAvailability(byDay);
    } else {
      setBlockedDates(new Set());
      setAvailability({});
    }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [activeOrgId, user]);

  const today = new Date(); today.setHours(0,0,0,0);
  const tomorrow = new Date(today.getTime() + 86400000);

  const filtered = useMemo(() => {
    return jobs.filter(j => {
      if (j.status === "canceled") return filter === "all";
      const date = j.scheduled_at ? new Date(j.scheduled_at) : null;
      if (filter === "today") return date && date >= today && date < tomorrow && j.status !== "completed";
      if (filter === "upcoming") return date && date >= tomorrow && j.status !== "completed";
      if (filter === "completed") return j.status === "completed";
      return true;
    });
  }, [jobs, filter, today, tomorrow]);

  const grouped = useMemo(() => {
    const groups: Record<string, Job[]> = {};
    for (const j of filtered) {
      const key = j.scheduled_at ? new Date(j.scheduled_at).toDateString() : "Unscheduled";
      (groups[key] ??= []).push(j);
    }
    return groups;
  }, [filtered]);

  const todayCount = jobs.filter(j => j.scheduled_at && new Date(j.scheduled_at) >= today && new Date(j.scheduled_at) < tomorrow && j.status !== "completed" && j.status !== "canceled").length;

  const conflictMap = useMemo(
    () => detectConflicts({ jobs, blockedDates, availability }),
    [jobs, blockedDates, availability],
  );

  const saveTime = async () => {
    if (!editing) return;
    if (newTime) {
      const target = new Date(newTime);
      if (blockedDates.has(ymd(target))) {
        if (!confirm("That date is marked as blocked/off. Schedule anyway?")) return;
      }
    }
    const { error } = await supabase.from("jobs").update({
      scheduled_at: newTime ? new Date(newTime).toISOString() : null,
    }).eq("id", editing.id);
    if (error) return toast.error(error.message);
    toast.success("Schedule updated");
    setEditing(null);
    load();
  };

  const setStatus = async (j: Job, status: "in_progress" | "completed" | "canceled") => {
    const ok = await setJobStatus({ id: j.id, status: j.status }, status);
    if (ok) load();
  };

  const buildTripFromToday = async () => {
    if (!user || !activeOrgId) return;
    const todayJobs = jobs.filter(j => j.scheduled_at && new Date(j.scheduled_at) >= today && new Date(j.scheduled_at) < tomorrow && j.status !== "canceled");
    if (todayJobs.length === 0) return toast.info("No jobs scheduled today");
    const { data: trip, error } = await supabase.from("trips").insert({
      organization_id: activeOrgId, user_id: user.id,
      trip_date: today.toISOString().slice(0,10),
      status: "draft",
    }).select().single();
    if (error || !trip) return toast.error(error?.message ?? "Could not create trip");
    const stops = todayJobs.map((j, i) => ({
      trip_id: trip.id, job_id: j.id, sort_order: i,
      label: j.title, address: j.location ?? null,
    }));
    await supabase.from("trip_stops").insert(stops);
    toast.success("Trip built from today's schedule");
    load();
  };

  const downloadJobIcs = (j: Job) => {
    if (!j.scheduled_at) return toast.info("Job has no scheduled time");
    platformCalendar.downloadIcs(
      `job-${j.id.slice(0, 8)}`,
      [{
        uid: `job-${j.id}@inspector.lovable.app`,
        title: j.title,
        start: new Date(j.scheduled_at),
        durationMinutes: j.estimated_duration_minutes ?? 60,
        location: j.location,
        description: [j.customer_name ? `Customer: ${j.customer_name}` : null, j.notes].filter(Boolean).join("\n"),
      }],
      j.title,
    );
    toast.success("Calendar event downloaded");
  };

  const downloadDayIcs = () => {
    const todayJobs = jobs.filter(j => j.scheduled_at && new Date(j.scheduled_at) >= today && new Date(j.scheduled_at) < tomorrow);
    if (todayJobs.length === 0) return toast.info("No jobs today");
    platformCalendar.downloadIcs(
      `inspector-day-${ymd(today)}`,
      todayJobs.map(j => ({
        uid: `job-${j.id}@inspector.lovable.app`,
        title: j.title,
        start: new Date(j.scheduled_at!),
        durationMinutes: j.estimated_duration_minutes ?? 60,
        location: j.location,
        description: j.customer_name ? `Customer: ${j.customer_name}` : null,
      })),
      `Inspector — ${today.toLocaleDateString()}`,
    );
    toast.success("Day exported to calendar");
  };

  const shiftWeek = (delta: number) => {
    const d = new Date(weekStart);
    d.setDate(d.getDate() + delta * 7);
    setWeekStart(d);
  };

  const weekEnd = useMemo(() => {
    const d = new Date(weekStart);
    d.setDate(d.getDate() + 6);
    return d;
  }, [weekStart]);

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Schedule</h1>
            <p className="text-sm text-muted-foreground mt-1">
              {todayCount > 0 ? `${todayCount} job${todayCount !== 1 ? "s" : ""} today` : "No jobs scheduled today"}
            </p>
          </div>
          <div className="flex gap-2 flex-wrap">
            <Button variant="outline" size="sm" onClick={downloadDayIcs}>
              <Download className="h-4 w-4 mr-1.5" />Export day (.ics)
            </Button>
            <Button variant="outline" size="sm" onClick={buildTripFromToday}>
              <RouteIcon className="h-4 w-4 mr-1.5" />Build trip from today
            </Button>
            <Button asChild size="sm">
              <Link to="/app/inspector/trips"><RouteIcon className="h-4 w-4 mr-1.5" />Open trips</Link>
            </Button>
          </div>
        </div>

        <div className="flex items-center justify-between gap-2 flex-wrap">
          <Tabs value={view} onValueChange={v => setView(v as ViewKey)}>
            <TabsList>
              <TabsTrigger value="list">List</TabsTrigger>
              <TabsTrigger value="week">Week</TabsTrigger>
            </TabsList>
          </Tabs>

          {view === "list" ? (
            <Tabs value={filter} onValueChange={v => setFilter(v as FilterKey)}>
              <TabsList>
                <TabsTrigger value="today">Today</TabsTrigger>
                <TabsTrigger value="upcoming">Upcoming</TabsTrigger>
                <TabsTrigger value="completed">Completed</TabsTrigger>
                <TabsTrigger value="all">All</TabsTrigger>
              </TabsList>
            </Tabs>
          ) : (
            <div className="flex items-center gap-1">
              <Button size="icon" variant="ghost" onClick={() => shiftWeek(-1)}>
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <span className="text-sm font-medium px-2">
                {weekStart.toLocaleDateString(undefined, { month: "short", day: "numeric" })} –{" "}
                {weekEnd.toLocaleDateString(undefined, { month: "short", day: "numeric" })}
              </span>
              <Button size="icon" variant="ghost" onClick={() => shiftWeek(1)}>
                <ChevronRight className="h-4 w-4" />
              </Button>
              <Button size="sm" variant="outline" onClick={() => setWeekStart(startOfWeek(new Date()))}>
                Today
              </Button>
            </div>
          )}
        </div>

        {view === "week" && (
          <ScheduleWeekGrid
            weekStart={weekStart}
            jobs={jobs}
            blockedDates={blockedDates}
            availability={availability}
            onJobClick={(j) => {
              setEditing(j as Job);
              setNewTime(j.scheduled_at ? j.scheduled_at.slice(0, 16) : "");
            }}
          />
        )}

        {view === "list" && Object.keys(grouped).length === 0 && (
          <Card><CardContent className="p-8 text-center text-sm text-muted-foreground">Nothing scheduled in this view.</CardContent></Card>
        )}

        {view === "list" && Object.entries(grouped).map(([day, list]) => {
          const isToday = new Date(day).toDateString() === today.toDateString();
          const dayDate = new Date(day);
          const isBlocked = !isNaN(dayDate.getTime()) && blockedDates.has(ymd(dayDate));
          return (
            <div key={day} className="space-y-2">
              <div className="flex items-baseline gap-2 flex-wrap">
                <h2 className={`text-sm font-semibold ${isToday ? "text-primary" : ""}`}>
                  {isToday ? "Today" : day}
                </h2>
                <span className="text-xs text-muted-foreground">{list.length} job{list.length !== 1 && "s"}</span>
                {isBlocked && <Badge variant="outline" className="text-xs">Marked off</Badge>}
              </div>
              <div className="grid gap-2">
                {list.map(j => {
                  const inTrip = tripJobIds.has(j.id);
                  return (
                    <Card key={j.id} className={isToday ? "border-primary/30" : ""}>
                      <CardContent className="p-3 flex items-center justify-between gap-3 flex-wrap">
                        <div className="min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <p className="font-medium text-sm">{j.title}</p>
                            <Badge
                              variant={j.status === "completed" ? "secondary" : j.status === "in_progress" ? "default" : "outline"}
                              className="capitalize text-xs"
                            >
                              {j.status.replace("_"," ")}
                            </Badge>
                            {inTrip && <Badge variant="outline" className="text-xs border-primary/40 text-primary">In trip</Badge>}
                          </div>
                          <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1.5 flex-wrap">
                            <Clock className="h-3 w-3" />
                            {j.scheduled_at ? new Date(j.scheduled_at).toLocaleTimeString([], { hour:"numeric", minute:"2-digit"}) : "Unscheduled"}
                            {j.customer_name && <>· {j.customer_name}</>}
                            {j.location && <><span>·</span><MapPin className="h-3 w-3" />{j.location}</>}
                          </p>
                        </div>
                        <div className="flex items-center gap-1 flex-wrap">
                          <Button size="sm" variant="ghost" title="Add to calendar"
                            onClick={() => downloadJobIcs(j)}
                            disabled={!j.scheduled_at}>
                            <CalendarPlus className="h-3.5 w-3.5" />
                          </Button>
                          <OpenInMapsButton target={{ address: j.location, label: j.title }} iconOnly />
                          {j.status === "scheduled" && (
                            <Button size="sm" variant="outline" onClick={() => setStatus(j, "in_progress")}>
                              <Play className="h-3.5 w-3.5 mr-1" />Start
                            </Button>
                          )}
                          {j.status === "in_progress" && (
                            <Button size="sm" variant="default" onClick={() => setStatus(j, "completed")}>
                              <CheckCircle2 className="h-3.5 w-3.5 mr-1" />Complete
                            </Button>
                          )}
                          {(j.status === "scheduled" || j.status === "in_progress") && (
                            <>
                              <Button size="sm" variant="ghost" onClick={() => { setEditing(j); setNewTime(j.scheduled_at ? j.scheduled_at.slice(0,16) : ""); }}>
                                <CalendarClock className="h-3.5 w-3.5" />
                              </Button>
                              <Button size="sm" variant="ghost" onClick={() => setStatus(j, "canceled")}>
                                <X className="h-3.5 w-3.5" />
                              </Button>
                            </>
                          )}
                        </div>
                      </CardContent>
                    </Card>
                  );
                })}
              </div>
            </div>
          );
        })}

        {activeTripId && (
          <p className="text-xs text-muted-foreground text-center pt-2">
            Active trip detected — jobs marked "In trip" are part of it.{" "}
            <Link to="/app/inspector/trips" className="text-primary underline">Open trip</Link>
          </p>
        )}
      </div>

      <Dialog open={!!editing} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader><DialogTitle>Reschedule</DialogTitle></DialogHeader>
          <Input type="datetime-local" value={newTime} onChange={e => setNewTime(e.target.value)} />
          <DialogFooter>
            <Button variant="ghost" onClick={() => setEditing(null)}>Cancel</Button>
            <Button onClick={saveTime}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
