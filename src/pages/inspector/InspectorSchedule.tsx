import { useEffect, useMemo, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Clock, MapPin, Route as RouteIcon, Play, CheckCircle2, X, CalendarClock } from "lucide-react";
import { Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";
import { OpenInMapsButton } from "@/components/maps/OpenInMapsButton";
import { setJobStatus } from "@/lib/tripLifecycle";

interface Job {
  id: string;
  title: string;
  customer_name: string | null;
  location: string | null;
  scheduled_at: string | null;
  status: string;
}

type FilterKey = "today" | "upcoming" | "completed" | "all";

export default function InspectorSchedule() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [editing, setEditing] = useState<Job | null>(null);
  const [newTime, setNewTime] = useState("");
  const [filter, setFilter] = useState<FilterKey>("today");
  const [tripJobIds, setTripJobIds] = useState<Set<string>>(new Set());
  const [activeTripId, setActiveTripId] = useState<string | null>(null);

  const load = async () => {
    if (!activeOrgId || !user) return;
    const { data } = await supabase
      .from("jobs").select("id,title,customer_name,location,scheduled_at,status")
      .eq("organization_id", activeOrgId).is("deleted_at", null)
      .order("scheduled_at", { ascending: true, nullsFirst: false });
    setJobs((data ?? []) as Job[]);

    const { data: liveTrip } = await supabase
      .from("trips").select("id").eq("user_id", user.id)
      .in("status", ["active", "paused", "draft", "planned"])
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (liveTrip) {
      setActiveTripId(liveTrip.id);
      const { data: stops } = await supabase.from("trip_stops").select("job_id").eq("trip_id", liveTrip.id);
      setTripJobIds(new Set((stops ?? []).map((s: any) => s.job_id).filter(Boolean)));
    } else {
      setActiveTripId(null);
      setTripJobIds(new Set());
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

  const saveTime = async () => {
    if (!editing) return;
    const { error } = await supabase.from("jobs").update({
      scheduled_at: newTime ? new Date(newTime).toISOString() : null,
    }).eq("id", editing.id);
    if (error) return toast.error(error.message);
    toast.success("Schedule updated");
    setEditing(null);
    load();
  };

  const setStatus = async (j: Job, status: "in_progress" | "completed" | "canceled") => {
    // Route through centralized lifecycle helper for idempotency.
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
            <Button variant="outline" size="sm" onClick={buildTripFromToday}>
              <RouteIcon className="h-4 w-4 mr-1.5" />Build trip from today
            </Button>
            <Button asChild size="sm">
              <Link to="/app/inspector/trips"><RouteIcon className="h-4 w-4 mr-1.5" />Open trips</Link>
            </Button>
          </div>
        </div>

        <Tabs value={filter} onValueChange={v => setFilter(v as FilterKey)}>
          <TabsList>
            <TabsTrigger value="today">Today</TabsTrigger>
            <TabsTrigger value="upcoming">Upcoming</TabsTrigger>
            <TabsTrigger value="completed">Completed</TabsTrigger>
            <TabsTrigger value="all">All</TabsTrigger>
          </TabsList>
        </Tabs>

        {Object.keys(grouped).length === 0 && (
          <Card><CardContent className="p-8 text-center text-sm text-muted-foreground">Nothing scheduled in this view.</CardContent></Card>
        )}

        {Object.entries(grouped).map(([day, list]) => {
          const isToday = new Date(day).toDateString() === today.toDateString();
          return (
            <div key={day} className="space-y-2">
              <div className="flex items-baseline gap-2">
                <h2 className={`text-sm font-semibold ${isToday ? "text-primary" : ""}`}>
                  {isToday ? "Today" : day}
                </h2>
                <span className="text-xs text-muted-foreground">{list.length} job{list.length !== 1 && "s"}</span>
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
            Active trip detected — jobs marked “In trip” are part of it.{" "}
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
