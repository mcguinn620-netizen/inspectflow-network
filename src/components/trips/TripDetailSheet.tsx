import { useEffect, useState } from "react";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Download, Save } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { toCsv, downloadCsv } from "@/lib/exportCsv";

interface Vehicle { id: string; nickname: string; year: string|null; make: string|null; model: string|null; license_plate: string|null; }
interface Stop {
  id: string; sort_order: number; label: string|null; address: string|null; status: string;
  miles_from_previous: number; arrived_at: string|null; departed_at: string|null; completed_at: string|null;
}
interface Trip {
  id: string; title: string|null; trip_date: string; status: string;
  start_time: string|null; end_time: string|null;
  total_miles: number; drive_minutes: number; work_minutes: number;
  notes: string|null; inspector_vehicle_id: string|null;
  started_at: string|null; completed_at: string|null;
}

const TRIP_STATUSES = ["draft","planned","active","paused","completed","canceled"];

export function TripDetailSheet({
  trip, stops, vehicles, open, onOpenChange, onSaved,
}: {
  trip: Trip | null; stops: Stop[]; vehicles: Vehicle[];
  open: boolean; onOpenChange: (v: boolean) => void; onSaved: () => void;
}) {
  const [form, setForm] = useState<Partial<Trip>>({});
  const [saving, setSaving] = useState(false);

  // Re-hydrate form whenever a different trip is opened (or sheet re-opens
  // with the same trip after server changes). Keying on trip.id + open ensures
  // edits don't get stuck in stale state.
  useEffect(() => {
    if (trip && open) {
      setForm({
        ...trip,
        start_time: trip.start_time ? trip.start_time.slice(0, 16) : "",
        end_time: trip.end_time ? trip.end_time.slice(0, 16) : "",
      });
    }
  }, [trip?.id, open]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!trip) return null;

  const save = async () => {
    if (saving) return;
    setSaving(true);
    try {
      const { error } = await supabase.from("trips").update({
        title: form.title || null,
        trip_date: form.trip_date as string,
        status: form.status as string,
        start_time: form.start_time ? new Date(form.start_time as string).toISOString() : null,
        end_time: form.end_time ? new Date(form.end_time as string).toISOString() : null,
        total_miles: Number(form.total_miles ?? 0),
        drive_minutes: Number(form.drive_minutes ?? 0),
        work_minutes: Number(form.work_minutes ?? 0),
        notes: form.notes || null,
        inspector_vehicle_id: form.inspector_vehicle_id || null,
      }).eq("id", trip.id);
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success("Trip saved");
      onSaved();
      onOpenChange(false);
    } catch (e: any) {
      toast.error(e?.message || "Failed to save trip");
    } finally {
      setSaving(false);
    }
  };

  const exportCsv = () => {
    const v = vehicles.find(x => x.id === trip.inspector_vehicle_id);
    const vLabel = v ? `${v.nickname} (${[v.year,v.make,v.model].filter(Boolean).join(" ")})` : "";
    const meta = {
      trip_date: trip.trip_date,
      title: form.title ?? trip.title ?? "",
      status: form.status ?? trip.status,
      start_time: form.start_time ?? "",
      end_time: form.end_time ?? "",
      total_miles: form.total_miles ?? trip.total_miles,
      drive_minutes: form.drive_minutes ?? trip.drive_minutes,
      work_minutes: form.work_minutes ?? trip.work_minutes,
      vehicle: vLabel,
      license_plate: v?.license_plate ?? "",
      notes: form.notes ?? trip.notes ?? "",
    };
    const stopRows = stops.map((s, i) => ({
      type: "stop", stop_number: i + 1, ...meta,
      stop_label: s.label ?? "", stop_address: s.address ?? "",
      stop_status: s.status, miles_from_previous: s.miles_from_previous,
      arrived_at: s.arrived_at ?? "", departed_at: s.departed_at ?? "", completed_at: s.completed_at ?? "",
    }));
    const summary = { type: "summary", stop_number: "", ...meta,
      stop_label: "", stop_address: "", stop_status: "", miles_from_previous: "",
      arrived_at: "", departed_at: "", completed_at: "" };
    const csv = toCsv([summary, ...stopRows]);
    downloadCsv(`trip-${trip.trip_date}-${trip.id.slice(0,8)}.csv`, csv);
    toast.success("Trip exported");
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-lg overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Trip · {new Date(trip.trip_date).toLocaleDateString()}</SheetTitle>
          <SheetDescription>Edit trip details, route, times and export for filings.</SheetDescription>
        </SheetHeader>

        <div className="space-y-4 mt-4">
          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1.5 col-span-2">
              <Label>Title</Label>
              <Input value={form.title ?? ""} onChange={e => setForm({ ...form, title: e.target.value })} placeholder="e.g. North-side morning route" />
            </div>
            <div className="space-y-1.5">
              <Label>Date</Label>
              <Input type="date" value={form.trip_date as any ?? ""} onChange={e => setForm({ ...form, trip_date: e.target.value as any })} />
            </div>
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select value={form.status ?? trip.status} onValueChange={v => setForm({ ...form, status: v })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{TRIP_STATUSES.map(s => <SelectItem key={s} value={s} className="capitalize">{s}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Start time</Label>
              <Input type="datetime-local" value={(form.start_time as any) ?? ""} onChange={e => setForm({ ...form, start_time: e.target.value as any })} />
            </div>
            <div className="space-y-1.5">
              <Label>End time</Label>
              <Input type="datetime-local" value={(form.end_time as any) ?? ""} onChange={e => setForm({ ...form, end_time: e.target.value as any })} />
            </div>
            <div className="space-y-1.5">
              <Label>Total miles</Label>
              <Input type="number" step="0.1" value={form.total_miles ?? 0} onChange={e => setForm({ ...form, total_miles: Number(e.target.value) })} />
            </div>
            <div className="space-y-1.5">
              <Label>Drive (m)</Label>
              <Input type="number" value={form.drive_minutes ?? 0} onChange={e => setForm({ ...form, drive_minutes: Number(e.target.value) })} />
            </div>
            <div className="space-y-1.5 col-span-2">
              <Label>Work (m)</Label>
              <Input type="number" value={form.work_minutes ?? 0} onChange={e => setForm({ ...form, work_minutes: Number(e.target.value) })} />
            </div>
            <div className="space-y-1.5 col-span-2">
              <Label>Inspector vehicle</Label>
              <Select value={form.inspector_vehicle_id ?? "none"} onValueChange={v => setForm({ ...form, inspector_vehicle_id: v === "none" ? null : v })}>
                <SelectTrigger><SelectValue placeholder="Select vehicle" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">— None —</SelectItem>
                  {vehicles.map(v => (
                    <SelectItem key={v.id} value={v.id}>
                      {v.nickname}{[v.year,v.make,v.model].filter(Boolean).length ? ` · ${[v.year,v.make,v.model].filter(Boolean).join(" ")}` : ""}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {vehicles.length === 0 && (
                <p className="text-[11px] text-muted-foreground">Add vehicles in Settings → My Vehicles.</p>
              )}
            </div>
            <div className="space-y-1.5 col-span-2">
              <Label>Notes</Label>
              <Textarea rows={3} value={form.notes ?? ""} onChange={e => setForm({ ...form, notes: e.target.value })} />
            </div>
          </div>

          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground mb-2">Route ({stops.length} stops)</p>
            <div className="space-y-1">
              {stops.length === 0 && <p className="text-xs text-muted-foreground">No stops yet. Add stops from the Trips page.</p>}
              {stops.map((s, i) => (
                <div key={s.id} className="flex items-center justify-between rounded-md border bg-muted/30 px-2 py-1.5 text-xs">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-muted-foreground">#{i+1}</span>
                    <span className="font-medium truncate">{s.label || s.address || "Stop"}</span>
                    <Badge variant="outline" className="capitalize text-[10px]">{s.status}</Badge>
                  </div>
                  <span className="text-muted-foreground tabular-nums">{Number(s.miles_from_previous).toFixed(1)} mi</span>
                </div>
              ))}
            </div>
          </div>

          <div className="flex flex-wrap gap-2 pt-2">
            <Button onClick={save}><Save className="h-4 w-4 mr-1.5" />Save trip</Button>
            <Button variant="outline" onClick={exportCsv}><Download className="h-4 w-4 mr-1.5" />Export CSV</Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
