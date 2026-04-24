import { useEffect, useMemo, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Plus, Trash2, Play, Pause, CheckCircle2, ArrowUp, ArrowDown, Flag, SkipForward, Briefcase, Loader2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";
import { OpenInMapsButton } from "@/components/maps/OpenInMapsButton";
import { TripMapOverlay, type MapStop } from "@/components/maps/TripMapOverlay";
import { LocationAutocomplete } from "@/components/maps/LocationAutocomplete";
import { TripDetailSheet } from "@/components/trips/TripDetailSheet";
import { NextStopCard } from "@/components/inspector/NextStopCard";
import { Progress } from "@/components/ui/progress";
import { Link } from "react-router-dom";
import { Pencil, Download } from "lucide-react";
import {
  setTripStatus as setTripStatusSafe,
  setStopStatus as setStopStatusSafe,
  canStartTrip, canPauseTrip, canCompleteTrip,
  canArriveStop, canCompleteStop, canSkipStop,
  isStopTerminal,
} from "@/lib/tripLifecycle";

interface Trip {
  id: string;
  title: string | null;
  trip_date: string;
  total_miles: number;
  drive_minutes: number;
  work_minutes: number;
  status: string;
  notes: string | null;
  start_time: string | null;
  end_time: string | null;
  started_at: string | null;
  paused_at: string | null;
  completed_at: string | null;
  inspector_vehicle_id: string | null;
}
interface Stop {
  id: string;
  trip_id: string;
  job_id: string | null;
  sort_order: number;
  label: string | null;
  address: string | null;
  miles_from_previous: number;
  status: string;
  arrived_at: string | null;
  departed_at: string | null;
  completed_at: string | null;
  latitude: number | null;
  longitude: number | null;
}

export default function InspectorTrips() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [stops, setStops] = useState<Record<string, Stop[]>>({});
  const [open, setOpen] = useState(false);
  const [stopOpen, setStopOpen] = useState<string | null>(null);
  const [stopForm, setStopForm] = useState<Partial<Stop>>({});
  const [selectedStopId, setSelectedStopId] = useState<string | null>(null);
  const [vehicles, setVehicles] = useState<any[]>([]);
  const [editingTrip, setEditingTrip] = useState<Trip | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [form, setForm] = useState<Partial<Trip>>({
    trip_date: new Date().toISOString().slice(0,10),
    total_miles: 0, drive_minutes: 0, work_minutes: 0, status: "draft",
  });

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: t } = await supabase
      .from("trips").select("*").eq("user_id", user.id)
      .order("trip_date", { ascending: false }).limit(60);
    const trips = (t ?? []) as Trip[];
    setTrips(trips);
    if (trips.length) {
      const { data: s } = await supabase
        .from("trip_stops").select("*").in("trip_id", trips.map(x => x.id)).order("sort_order");
      const map: Record<string, Stop[]> = {};
      for (const stop of (s ?? []) as Stop[]) (map[stop.trip_id] ??= []).push(stop);
      setStops(map);
    }
    const { data: v } = await supabase.from("inspector_vehicles" as any)
      .select("*").eq("user_id", user.id).eq("is_archived", false);
    setVehicles((v ?? []) as any[]);
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const today = new Date().toISOString().slice(0,10);
  const todayTrip = trips.find(t => t.trip_date === today);
  const todayMiles = trips.filter(t => t.trip_date === today).reduce((s,t) => s + Number(t.total_miles||0), 0);
  const activeTrip = useMemo(() => trips.find(t => ["active","paused","draft","planned"].includes(t.status)) ?? null, [trips]);
  const activeStops = activeTrip ? (stops[activeTrip.id] ?? []) : [];

  const mapStops: MapStop[] = activeStops.map(s => ({
    id: s.id, label: s.label, address: s.address, latitude: s.latitude, longitude: s.longitude,
  }));

  const createTrip = async () => {
    if (!user || !activeOrgId) return;
    const { error } = await supabase.from("trips").insert({
      organization_id: activeOrgId, user_id: user.id,
      trip_date: form.trip_date,
      total_miles: form.total_miles ?? 0,
      drive_minutes: form.drive_minutes ?? 0,
      work_minutes: form.work_minutes ?? 0,
      status: form.status ?? "draft",
      notes: form.notes ?? null,
    });
    if (error) return toast.error(error.message);
    toast.success("Trip logged");
    setOpen(false);
    load();
  };

  const guard = async <T,>(id: string, fn: () => Promise<T>): Promise<T | undefined> => {
    if (pendingId) return undefined;
    setPendingId(id);
    try { return await fn(); } finally { setPendingId(null); }
  };

  const setTripStatus = (trip: Trip, status: "active" | "paused" | "completed") =>
    guard(`trip:${trip.id}:${status}`, async () => {
      const ok = await setTripStatusSafe(trip, status);
      if (ok) load();
    });

  const addStop = async () => {
    if (!stopOpen) return;
    const list = stops[stopOpen] ?? [];
    const { error } = await supabase.from("trip_stops").insert({
      trip_id: stopOpen, sort_order: list.length,
      label: stopForm.label ?? null,
      address: stopForm.address ?? null,
      miles_from_previous: stopForm.miles_from_previous ?? 0,
      latitude: stopForm.latitude ?? null,
      longitude: stopForm.longitude ?? null,
      status: "pending",
    });
    if (error) return toast.error(error.message);
    setStopForm({});
    setStopOpen(null);
    load();
  };

  const delStop = async (id: string) => {
    await supabase.from("trip_stops").delete().eq("id", id);
    load();
  };

  const moveStop = async (s: Stop, dir: -1 | 1) => {
    const list = stops[s.trip_id] ?? [];
    const idx = list.findIndex(x => x.id === s.id);
    const swap = list[idx + dir];
    if (!swap) return;
    await supabase.from("trip_stops").update({ sort_order: swap.sort_order }).eq("id", s.id);
    await supabase.from("trip_stops").update({ sort_order: s.sort_order }).eq("id", swap.id);
    load();
  };

  const setStopStatus = (s: Stop, status: "arrived" | "completed" | "skipped") =>
    guard(`stop:${s.id}:${status}`, async () => {
      const ok = await setStopStatusSafe(s, status, {
        completeJob: status === "completed" && !!s.job_id,
      });
      if (ok) load();
    });

  const startJobFromStop = (s: Stop) =>
    guard(`stop:${s.id}:start`, async () => {
      if (!s.job_id) { toast.info("This stop has no linked job"); return; }
      const ok = await setStopStatusSafe(s, "arrived", { startJob: true });
      if (ok) load();
    });

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Trips</h1>
            <p className="text-sm text-muted-foreground mt-1">Plan, run, and log your day</p>
          </div>
          <div className="flex gap-2">
            <Button asChild variant="outline" size="sm"><Link to="/app/inspector/schedule">Build from schedule</Link></Button>
            <Button onClick={() => setOpen(true)}><Plus className="h-4 w-4 mr-1.5" />Log trip</Button>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          <Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Today miles</p><p className="text-2xl font-semibold">{todayMiles.toFixed(1)}</p></CardContent></Card>
          <Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Today drive</p><p className="text-2xl font-semibold">{todayTrip?.drive_minutes ?? 0}m</p></CardContent></Card>
          <Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Today work</p><p className="text-2xl font-semibold">{todayTrip?.work_minutes ?? 0}m</p></CardContent></Card>
        </div>

        {/* Next-stop quick-action card (mobile-friendly primary action) */}
        <NextStopCard />

        {/* Active trip planner with map overlay */}
        {activeTrip && (() => {
          const completedCount = activeStops.filter(s => s.status === "completed" || s.status === "skipped").length;
          const pct = activeStops.length ? Math.round((completedCount / activeStops.length) * 100) : 0;
          return (
          <div className="space-y-2">
            <div className="flex items-center justify-between flex-wrap gap-2">
              <div className="min-w-0">
                <h2 className="text-sm font-semibold flex items-center gap-2 flex-wrap">
                  Active trip
                  <Badge variant="outline" className="capitalize text-xs">{activeTrip.status}</Badge>
                  {activeStops.length > 0 && (
                    <span className="text-xs text-muted-foreground tabular-nums">
                      {completedCount}/{activeStops.length} stops
                    </span>
                  )}
                </h2>
                {activeStops.length > 0 && <Progress value={pct} className="h-1.5 mt-1.5 w-40" />}
              </div>
              <div className="flex gap-2 flex-wrap">
                {canStartTrip(activeTrip.status) && (
                  <Button size="sm" variant="outline" disabled={!!pendingId}
                    onClick={() => setTripStatus(activeTrip, "active")}>
                    {pendingId === `trip:${activeTrip.id}:active` ? <Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> : <Play className="h-3.5 w-3.5 mr-1" />}Start
                  </Button>
                )}
                {canPauseTrip(activeTrip.status) && (
                  <Button size="sm" variant="outline" disabled={!!pendingId}
                    onClick={() => setTripStatus(activeTrip, "paused")}>
                    {pendingId === `trip:${activeTrip.id}:paused` ? <Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> : <Pause className="h-3.5 w-3.5 mr-1" />}Pause
                  </Button>
                )}
                <Button size="sm" variant="outline" onClick={() => setEditingTrip(activeTrip)}><Pencil className="h-3.5 w-3.5 mr-1" />Edit</Button>
                {canCompleteTrip(activeTrip.status) && (
                  <Button size="sm" variant="default" disabled={!!pendingId}
                    onClick={() => setTripStatus(activeTrip, "completed")}>
                    {pendingId === `trip:${activeTrip.id}:completed` ? <Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> : <CheckCircle2 className="h-3.5 w-3.5 mr-1" />}Complete
                  </Button>
                )}
              </div>
            </div>

            <div className="grid lg:grid-cols-2 gap-3">
              <TripMapOverlay
                stops={mapStops}
                selectedId={selectedStopId}
                onSelect={setSelectedStopId}
              />
              <Card>
                <CardContent className="p-3 space-y-2">
                  {activeStops.length === 0 && <p className="text-sm text-muted-foreground p-3">No stops yet. Add stops or build from schedule.</p>}
                  {(() => {
                    // Determine current/next stop for visual emphasis
                    const nextIdx = activeStops.findIndex(s => s.status !== "completed" && s.status !== "skipped");
                    return activeStops.map((s, i) => {
                      const isDone = s.status === "completed" || s.status === "skipped";
                      const isNext = i === nextIdx;
                      return (
                    <div
                      key={s.id}
                      onClick={() => setSelectedStopId(s.id)}
                      className={`rounded-md border p-2 cursor-pointer transition-colors ${
                        selectedStopId === s.id
                          ? "border-primary bg-primary/5"
                          : isNext
                            ? "border-primary/60 bg-primary/5 ring-1 ring-primary/30"
                            : isDone
                              ? "opacity-60 hover:opacity-100"
                              : "hover:bg-muted/40"
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2 flex-wrap">
                        <div className="flex items-center gap-2 min-w-0">
                          <span className={`text-xs tabular-nums ${isNext ? "text-primary font-semibold" : "text-muted-foreground"}`}>#{i+1}</span>
                          <span className={`font-medium text-sm truncate ${isDone ? "line-through" : ""}`}>{s.label || s.address || "Stop"}</span>
                          {isNext && <Badge variant="default" className="capitalize text-[10px] h-4">Next</Badge>}
                          {!isNext && <Badge variant="outline" className="capitalize text-xs">{s.status}</Badge>}
                          {s.job_id && <Badge variant="outline" className="text-xs"><Briefcase className="h-3 w-3 mr-1" />Job</Badge>}
                        </div>
                        <div className="flex items-center gap-1">
                          <Button size="icon" variant="ghost" className="h-7 w-7" onClick={(e) => { e.stopPropagation(); moveStop(s, -1); }}><ArrowUp className="h-3.5 w-3.5" /></Button>
                          <Button size="icon" variant="ghost" className="h-7 w-7" onClick={(e) => { e.stopPropagation(); moveStop(s, 1); }}><ArrowDown className="h-3.5 w-3.5" /></Button>
                          <OpenInMapsButton target={{ address: s.address, latitude: s.latitude, longitude: s.longitude, label: s.label }} iconOnly />
                          <Button size="icon" variant="ghost" className="h-7 w-7" onClick={(e) => { e.stopPropagation(); delStop(s.id); }}><Trash2 className="h-3.5 w-3.5" /></Button>
                        </div>
                      </div>
                      {s.address && <p className="text-xs text-muted-foreground mt-1 ml-6 truncate">{s.address}</p>}
                      <div className="flex flex-wrap gap-1 mt-2 ml-6">
                        {canArriveStop(s.status) && (
                          <Button size="sm" variant="outline" disabled={!!pendingId}
                            onClick={(e) => { e.stopPropagation(); setStopStatus(s, "arrived"); }}>
                            {pendingId === `stop:${s.id}:arrived` ? <Loader2 className="h-3 w-3 mr-1 animate-spin" /> : <Flag className="h-3 w-3 mr-1" />}Arrived
                          </Button>
                        )}
                        {s.job_id && !isStopTerminal(s.status) && (
                          <Button size="sm" variant="outline" disabled={!!pendingId}
                            onClick={(e) => { e.stopPropagation(); startJobFromStop(s); }}>
                            {pendingId === `stop:${s.id}:start` ? <Loader2 className="h-3 w-3 mr-1 animate-spin" /> : <Play className="h-3 w-3 mr-1" />}Start job
                          </Button>
                        )}
                        {canCompleteStop(s.status) && (
                          <Button size="sm" variant="default" disabled={!!pendingId}
                            onClick={(e) => { e.stopPropagation(); setStopStatus(s, "completed"); }}>
                            {pendingId === `stop:${s.id}:completed` ? <Loader2 className="h-3 w-3 mr-1 animate-spin" /> : <CheckCircle2 className="h-3 w-3 mr-1" />}Complete
                          </Button>
                        )}
                        {canSkipStop(s.status) && (
                          <Button size="sm" variant="ghost" disabled={!!pendingId}
                            onClick={(e) => { e.stopPropagation(); setStopStatus(s, "skipped"); }}>
                            <SkipForward className="h-3 w-3 mr-1" />Skip
                          </Button>
                        )}
                      </div>
                    </div>
                      );
                    });
                  })()}
                  <Button size="sm" variant="outline" className="w-full" onClick={() => { setStopOpen(activeTrip.id); setStopForm({}); }}>
                    <Plus className="h-3.5 w-3.5 mr-1" />Add stop
                  </Button>
                </CardContent>
              </Card>
            </div>
          </div>
          );
        })()}

        <div className="space-y-3">
          <h2 className="text-sm font-semibold">History</h2>
          {trips.length === 0 && <p className="text-sm text-muted-foreground">No trips yet.</p>}
          {trips.filter(t => !activeTrip || t.id !== activeTrip.id).map(t => (
            <Card key={t.id}>
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <CardTitle className="text-base">
                    {t.title ? t.title : new Date(t.trip_date).toLocaleDateString([], { weekday:"short", month:"short", day:"numeric" })}
                  </CardTitle>
                  <div className="flex items-center gap-2">
                    <Badge variant="outline" className="capitalize">{t.status}</Badge>
                    <span className="text-sm text-muted-foreground">{Number(t.total_miles).toFixed(1)} mi · {t.drive_minutes}m drive</span>
                    <Button size="sm" variant="ghost" onClick={() => setEditingTrip(t)}><Pencil className="h-3.5 w-3.5 mr-1" />Edit</Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-2">
                {(stops[t.id] ?? []).map((s, i) => (
                  <div key={s.id} className="flex items-center justify-between rounded-md border bg-background/40 px-3 py-2 text-sm">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-xs text-muted-foreground">#{i+1}</span>
                      <span className="font-medium truncate">{s.label || s.address || "Stop"}</span>
                      <Badge variant="outline" className="capitalize text-xs">{s.status}</Badge>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-muted-foreground">{Number(s.miles_from_previous).toFixed(1)} mi</span>
                      <OpenInMapsButton target={{ address: s.address, latitude: s.latitude, longitude: s.longitude, label: s.label }} iconOnly />
                    </div>
                  </div>
                ))}
                {(stops[t.id] ?? []).length === 0 && <p className="text-xs text-muted-foreground">No stops</p>}
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      <TripDetailSheet
        trip={editingTrip as any}
        stops={(editingTrip ? stops[editingTrip.id] : []) as any}
        vehicles={vehicles as any}
        open={!!editingTrip}
        onOpenChange={(o) => !o && setEditingTrip(null)}
        onSaved={load}
      />

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-sm">
          <DialogHeader><DialogTitle>Log trip</DialogTitle></DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1.5"><Label>Date</Label><Input type="date" value={form.trip_date as any} onChange={e => setForm({ ...form, trip_date: e.target.value })} /></div>
            <div className="grid grid-cols-3 gap-2">
              <div className="space-y-1.5"><Label className="text-xs">Miles</Label><Input type="number" step="0.1" value={form.total_miles ?? 0} onChange={e => setForm({ ...form, total_miles: Number(e.target.value) })} /></div>
              <div className="space-y-1.5"><Label className="text-xs">Drive (m)</Label><Input type="number" value={form.drive_minutes ?? 0} onChange={e => setForm({ ...form, drive_minutes: Number(e.target.value) })} /></div>
              <div className="space-y-1.5"><Label className="text-xs">Work (m)</Label><Input type="number" value={form.work_minutes ?? 0} onChange={e => setForm({ ...form, work_minutes: Number(e.target.value) })} /></div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={createTrip}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!stopOpen} onOpenChange={(o) => !o && setStopOpen(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader><DialogTitle>Add stop</DialogTitle></DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1.5"><Label>Label</Label><Input value={stopForm.label ?? ""} onChange={e => setStopForm({ ...stopForm, label: e.target.value })} placeholder="Customer pickup" /></div>
            <div className="space-y-1.5">
              <Label>Address</Label>
              <LocationAutocomplete
                value={stopForm.address ?? ""}
                onChange={(loc) => setStopForm({
                  ...stopForm,
                  address: loc.address,
                  latitude: loc.latitude ?? stopForm.latitude ?? null,
                  longitude: loc.longitude ?? stopForm.longitude ?? null,
                })}
                placeholder="Search address or use my location"
              />
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1.5"><Label className="text-xs">Latitude</Label><Input type="number" step="0.000001" value={stopForm.latitude ?? ""} onChange={e => setStopForm({ ...stopForm, latitude: e.target.value ? Number(e.target.value) : null })} /></div>
              <div className="space-y-1.5"><Label className="text-xs">Longitude</Label><Input type="number" step="0.000001" value={stopForm.longitude ?? ""} onChange={e => setStopForm({ ...stopForm, longitude: e.target.value ? Number(e.target.value) : null })} /></div>
            </div>
            <div className="space-y-1.5"><Label>Miles from previous</Label><Input type="number" step="0.1" value={stopForm.miles_from_previous ?? 0} onChange={e => setStopForm({ ...stopForm, miles_from_previous: Number(e.target.value) })} /></div>
            <p className="text-xs text-muted-foreground">Address lookup auto-fills coordinates so the map and "Open in Maps" work.</p>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setStopOpen(null)}>Cancel</Button>
            <Button onClick={addStop}>Add</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
