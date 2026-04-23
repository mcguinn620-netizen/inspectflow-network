import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Briefcase, Route, Receipt, CalendarDays, Clock, MapPin, Play, Plus, Pause } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { OpenInMapsButton } from "@/components/maps/OpenInMapsButton";
import { NextStopCard } from "@/components/inspector/NextStopCard";
import { toast } from "sonner";

interface Job {
  id: string;
  title: string;
  customer_name: string | null;
  location: string | null;
  scheduled_at: string | null;
  status: string;
  fee_override: number | null;
  actual_end_time: string | null;
}

export default function InspectorDashboard() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [stats, setStats] = useState({ jobsToday: 0, milesToday: 0, weeklyMiles: 0, estimatedEarnings: 0 });
  const [activeTrip, setActiveTrip] = useState<any>(null);
  const [nextStop, setNextStop] = useState<any>(null);

  const load = async () => {
    if (!user || !activeOrgId) return;
    const today = new Date(); today.setHours(0,0,0,0);
    const weekAgo = new Date(); weekAgo.setDate(weekAgo.getDate()-7);

    const { data: jobData } = await supabase
      .from("jobs").select("*").eq("organization_id", activeOrgId)
      .is("deleted_at", null).order("scheduled_at", { ascending: true }).limit(20);
    setJobs((jobData ?? []) as Job[]);

    const todayStr = today.toISOString().slice(0,10);
    const { data: tripsToday } = await supabase
      .from("trips").select("total_miles").eq("user_id", user.id).eq("trip_date", todayStr);
    const { data: tripsWeek } = await supabase
      .from("trips").select("total_miles, trip_date").eq("user_id", user.id)
      .gte("trip_date", weekAgo.toISOString().slice(0,10));
    const { data: settings } = await supabase
      .from("earnings_settings").select("*").eq("user_id", user.id).maybeSingle();
    const { data: live } = await supabase
      .from("trips").select("*").eq("user_id", user.id)
      .in("status", ["active","paused","draft","planned"])
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    setActiveTrip(live);

    if (live) {
      const { data: stop } = await supabase
        .from("trip_stops").select("*").eq("trip_id", live.id)
        .in("status", ["pending","arrived"])
        .order("sort_order").limit(1).maybeSingle();
      setNextStop(stop);
    } else {
      setNextStop(null);
    }

    const milesToday = (tripsToday ?? []).reduce((s, t: any) => s + Number(t.total_miles || 0), 0);
    const weeklyMiles = (tripsWeek ?? []).reduce((s, t: any) => s + Number(t.total_miles || 0), 0);
    const completedThisWeek = (jobData ?? []).filter((j: any) =>
      j.status === "completed" && j.actual_end_time && new Date(j.actual_end_time) >= weekAgo
    );
    const fee = settings?.default_job_fee ?? 75;
    const mRate = settings?.mileage_rate ?? 0.67;
    const earningsJobs = completedThisWeek.reduce((s: number, j: any) => s + Number(j.fee_override ?? fee), 0);
    const earningsMiles = weeklyMiles * Number(mRate);
    const jobsTodayCount = (jobData ?? []).filter((j: any) =>
      j.scheduled_at && new Date(j.scheduled_at) >= today &&
      new Date(j.scheduled_at) < new Date(today.getTime() + 86400000)
    ).length;

    setStats({ jobsToday: jobsTodayCount, milesToday, weeklyMiles, estimatedEarnings: earningsJobs + earningsMiles });
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const startTodayTrip = async () => {
    if (!user || !activeOrgId) return;
    const today = new Date(); today.setHours(0,0,0,0);
    const todayStr = today.toISOString().slice(0,10);
    const { data: existing } = await supabase
      .from("trips").select("*").eq("user_id", user.id).eq("trip_date", todayStr)
      .order("created_at", { ascending: false }).limit(1).maybeSingle();

    if (existing) {
      const { error } = await supabase.from("trips").update({
        status: "active",
        started_at: existing.started_at ?? new Date().toISOString(),
        paused_at: null,
      }).eq("id", existing.id);
      if (error) return toast.error(error.message);
      toast.success("Trip resumed");
    } else {
      const { error } = await supabase.from("trips").insert({
        organization_id: activeOrgId, user_id: user.id, trip_date: todayStr,
        status: "active", started_at: new Date().toISOString(),
      });
      if (error) return toast.error(error.message);
      toast.success("Trip started");
    }
    load();
  };

  const pauseTrip = async () => {
    if (!activeTrip) return;
    await supabase.from("trips").update({ status: "paused", paused_at: new Date().toISOString() }).eq("id", activeTrip.id);
    load();
  };

  const today = new Date(); today.setHours(0,0,0,0);
  const tomorrow = new Date(today.getTime() + 86400000);
  const todayJobs = jobs.filter(j => j.scheduled_at && new Date(j.scheduled_at) >= today && new Date(j.scheduled_at) < tomorrow);
  const upcoming = jobs.filter(j => j.scheduled_at && new Date(j.scheduled_at) >= tomorrow).slice(0, 5);
  const nextJob = todayJobs.find(j => j.status !== "completed" && j.status !== "canceled");

  const statCards = [
    { label: "Jobs Today", value: stats.jobsToday, icon: Briefcase },
    { label: "Miles Today", value: stats.milesToday.toFixed(1), icon: Route },
    { label: "Weekly Miles", value: stats.weeklyMiles.toFixed(1), icon: MapPin },
    { label: "Est. Earnings (7d)", value: `$${stats.estimatedEarnings.toFixed(0)}`, icon: Receipt },
  ];

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Inspector Dashboard</h1>
            <p className="text-sm text-muted-foreground mt-1">Your day at a glance</p>
          </div>
          <div className="flex gap-2 flex-wrap">
            <Button variant="outline" size="sm" asChild>
              <Link to="/app/inspector/jobs"><Plus className="h-4 w-4 mr-1.5" />Quick job</Link>
            </Button>
            <Button variant="outline" size="sm" asChild>
              <Link to="/app/inspector/schedule"><CalendarDays className="h-4 w-4 mr-1.5" />Schedule</Link>
            </Button>
            {activeTrip && activeTrip.status === "active" ? (
              <Button size="sm" variant="secondary" onClick={pauseTrip}>
                <Pause className="h-4 w-4 mr-1.5" />Pause trip
              </Button>
            ) : (
              <Button size="sm" onClick={startTodayTrip}>
                <Play className="h-4 w-4 mr-1.5" />{activeTrip ? "Resume trip" : "Start today's trip"}
              </Button>
            )}
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {statCards.map((s) => (
            <Card key={s.label} className="shadow-sm">
              <CardContent className="p-4">
                <div className="flex items-center justify-between mb-2">
                  <s.icon className="h-4 w-4 text-muted-foreground" />
                </div>
                <p className="text-2xl font-semibold">{s.value}</p>
                <p className="text-xs text-muted-foreground mt-1">{s.label}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        <NextStopCard />

        {activeTrip && !nextStop && (
          <Card className="border-primary/40 bg-primary/5">
            <CardContent className="p-4 flex items-center justify-between flex-wrap gap-2">
              <div className="flex items-center gap-3 min-w-0">
                <div className={`h-2 w-2 rounded-full bg-primary ${activeTrip.status === "active" ? "animate-pulse" : ""}`} />
                <div className="min-w-0">
                  <p className="text-sm font-medium capitalize">Trip {activeTrip.status}</p>
                  <p className="text-xs text-muted-foreground truncate">
                    {Number(activeTrip.total_miles || 0).toFixed(1)} mi tracked · all stops handled
                  </p>
                </div>
              </div>
              <Button asChild size="sm" variant="outline"><Link to="/app/inspector/trips">Open trip</Link></Button>
            </CardContent>
          </Card>
        )}

        {nextJob && !activeTrip && (
          <Card className="bg-muted/40">
            <CardContent className="p-4 flex items-center justify-between flex-wrap gap-2">
              <div className="min-w-0">
                <p className="text-xs text-muted-foreground">Next up</p>
                <p className="text-sm font-medium">{nextJob.title}</p>
                <p className="text-xs text-muted-foreground flex items-center gap-1.5 mt-0.5">
                  <Clock className="h-3 w-3" />
                  {nextJob.scheduled_at && new Date(nextJob.scheduled_at).toLocaleTimeString([], { hour:"numeric", minute:"2-digit"})}
                  {nextJob.location && <><span>·</span><MapPin className="h-3 w-3" />{nextJob.location}</>}
                </p>
              </div>
              <OpenInMapsButton target={{ address: nextJob.location, label: nextJob.title }} variant="outline" />
            </CardContent>
          </Card>
        )}

        <div className="grid md:grid-cols-2 gap-4">
          <Card>
            <CardHeader><CardTitle className="text-base">Today</CardTitle></CardHeader>
            <CardContent className="space-y-2">
              {todayJobs.length === 0 && <p className="text-sm text-muted-foreground">No jobs scheduled today.</p>}
              {todayJobs.map(j => <JobRow key={j.id} job={j} />)}
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Upcoming</CardTitle></CardHeader>
            <CardContent className="space-y-2">
              {upcoming.length === 0 && <p className="text-sm text-muted-foreground">Nothing upcoming.</p>}
              {upcoming.map(j => <JobRow key={j.id} job={j} />)}
            </CardContent>
          </Card>
        </div>

        <div className="flex flex-wrap gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link to="/app/inspector/tax"><Receipt className="h-4 w-4 mr-1.5" />Tax snapshot</Link>
          </Button>
        </div>
      </div>
    </DashboardLayout>
  );
}

function JobRow({ job }: { job: Job }) {
  const time = job.scheduled_at ? new Date(job.scheduled_at).toLocaleString([], { month:"short", day:"numeric", hour:"numeric", minute:"2-digit"}) : "Unscheduled";
  return (
    <div className="flex items-center justify-between rounded-md border bg-background/40 p-3 hover:bg-muted/50 transition-colors">
      <Link to="/app/inspector/jobs" className="min-w-0 flex-1">
        <p className="text-sm font-medium truncate">{job.title}</p>
        <p className="text-xs text-muted-foreground flex items-center gap-1.5 mt-0.5">
          <Clock className="h-3 w-3" />{time}
          {job.location && <><span>·</span><MapPin className="h-3 w-3" />{job.location}</>}
        </p>
      </Link>
      <div className="flex items-center gap-1 ml-2">
        <OpenInMapsButton target={{ address: job.location, label: job.title }} iconOnly />
        <Badge variant={job.status === "completed" ? "secondary" : "outline"} className="capitalize text-xs">{job.status.replace("_"," ")}</Badge>
      </div>
    </div>
  );
}
