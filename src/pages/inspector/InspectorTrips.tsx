import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Plus, MapPin, Trash2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";

interface Trip {
  id: string;
  trip_date: string;
  total_miles: number;
  drive_minutes: number;
  work_minutes: number;
  status: string;
  notes: string | null;
}
interface Stop {
  id: string;
  trip_id: string;
  sort_order: number;
  label: string | null;
  address: string | null;
  miles_from_previous: number;
}

export default function InspectorTrips() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [stops, setStops] = useState<Record<string, Stop[]>>({});
  const [open, setOpen] = useState(false);
  const [stopOpen, setStopOpen] = useState<string | null>(null);
  const [stopForm, setStopForm] = useState<Partial<Stop>>({});
  const [form, setForm] = useState<Partial<Trip>>({
    trip_date: new Date().toISOString().slice(0,10),
    total_miles: 0, drive_minutes: 0, work_minutes: 0, status: "planned",
  });

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: t } = await supabase
      .from("trips").select("*")
      .eq("user_id", user.id)
      .order("trip_date", { ascending: false }).limit(60);
    const trips = (t ?? []) as Trip[];
    setTrips(trips);
    if (trips.length) {
      const { data: s } = await supabase
        .from("trip_stops").select("*")
        .in("trip_id", trips.map(x => x.id))
        .order("sort_order");
      const map: Record<string, Stop[]> = {};
      for (const stop of (s ?? []) as Stop[]) {
        (map[stop.trip_id] ??= []).push(stop);
      }
      setStops(map);
    }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const today = new Date().toISOString().slice(0,10);
  const todayTrip = trips.find(t => t.trip_date === today);
  const todayMiles = trips.filter(t => t.trip_date === today).reduce((s,t) => s + Number(t.total_miles||0), 0);

  const createTrip = async () => {
    if (!user || !activeOrgId) return;
    const { error } = await supabase.from("trips").insert({
      organization_id: activeOrgId,
      user_id: user.id,
      trip_date: form.trip_date,
      total_miles: form.total_miles ?? 0,
      drive_minutes: form.drive_minutes ?? 0,
      work_minutes: form.work_minutes ?? 0,
      status: form.status ?? "planned",
      notes: form.notes ?? null,
    });
    if (error) return toast.error(error.message);
    toast.success("Trip logged");
    setOpen(false);
    load();
  };

  const addStop = async () => {
    if (!stopOpen) return;
    const list = stops[stopOpen] ?? [];
    const { error } = await supabase.from("trip_stops").insert({
      trip_id: stopOpen,
      sort_order: list.length,
      label: stopForm.label ?? null,
      address: stopForm.address ?? null,
      miles_from_previous: stopForm.miles_from_previous ?? 0,
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

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Trips</h1>
            <p className="text-sm text-muted-foreground mt-1">Mileage and travel log</p>
          </div>
          <Button onClick={() => setOpen(true)}><Plus className="h-4 w-4 mr-1.5" />Log trip</Button>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          <Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Today miles</p><p className="text-2xl font-semibold">{todayMiles.toFixed(1)}</p></CardContent></Card>
          <Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Today drive</p><p className="text-2xl font-semibold">{todayTrip?.drive_minutes ?? 0}m</p></CardContent></Card>
          <Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Today work</p><p className="text-2xl font-semibold">{todayTrip?.work_minutes ?? 0}m</p></CardContent></Card>
        </div>

        <Card className="border-dashed">
          <CardContent className="p-6 text-center">
            <MapPin className="h-6 w-6 text-muted-foreground mx-auto mb-2" />
            <p className="text-sm text-muted-foreground">Map view coming soon. GPS auto-tracking will appear here.</p>
          </CardContent>
        </Card>

        <div className="space-y-3">
          <h2 className="text-sm font-semibold">History</h2>
          {trips.length === 0 && <p className="text-sm text-muted-foreground">No trips yet.</p>}
          {trips.map(t => (
            <Card key={t.id}>
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <CardTitle className="text-base">{new Date(t.trip_date).toLocaleDateString([], { weekday:"short", month:"short", day:"numeric" })}</CardTitle>
                  <div className="flex items-center gap-2">
                    <Badge variant="outline" className="capitalize">{t.status}</Badge>
                    <span className="text-sm text-muted-foreground">{Number(t.total_miles).toFixed(1)} mi · {t.drive_minutes}m drive</span>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-2">
                {(stops[t.id] ?? []).map((s, i) => (
                  <div key={s.id} className="flex items-center justify-between rounded-md border px-3 py-2 text-sm">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-xs text-muted-foreground">#{i+1}</span>
                      <span className="font-medium truncate">{s.label || s.address || "Stop"}</span>
                      {s.address && s.label && <span className="text-xs text-muted-foreground truncate">{s.address}</span>}
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-muted-foreground">{Number(s.miles_from_previous).toFixed(1)} mi</span>
                      <Button size="sm" variant="ghost" onClick={() => delStop(s.id)}><Trash2 className="h-3.5 w-3.5" /></Button>
                    </div>
                  </div>
                ))}
                <Button size="sm" variant="outline" onClick={() => { setStopOpen(t.id); setStopForm({}); }}>
                  <Plus className="h-3.5 w-3.5 mr-1" />Add stop
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

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
            <div className="space-y-1.5"><Label>Address</Label><Input value={stopForm.address ?? ""} onChange={e => setStopForm({ ...stopForm, address: e.target.value })} /></div>
            <div className="space-y-1.5"><Label>Miles from previous</Label><Input type="number" step="0.1" value={stopForm.miles_from_previous ?? 0} onChange={e => setStopForm({ ...stopForm, miles_from_previous: Number(e.target.value) })} /></div>
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
