import { useEffect, useMemo, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Plus, Pencil, Play, CheckCircle2, X, Route as RouteIcon, Copy } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";
import { Link } from "react-router-dom";
import { OpenInMapsButton } from "@/components/maps/OpenInMapsButton";

interface Job {
  id: string;
  title: string;
  customer_name: string | null;
  location: string | null;
  scheduled_at: string | null;
  estimated_duration_minutes: number | null;
  actual_start_time: string | null;
  actual_end_time: string | null;
  status: string;
  fee_override: number | null;
  mileage_fee: number | null;
  notes: string | null;
}

const STATUSES = ["scheduled", "in_progress", "completed", "canceled"] as const;
type FilterKey = "today" | "upcoming" | "completed" | "canceled" | "all";

export default function InspectorJobs() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [filter, setFilter] = useState<FilterKey>("today");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Job | null>(null);
  const [form, setForm] = useState<Partial<Job>>({ title: "", status: "scheduled", estimated_duration_minutes: 60 });
  const [tripJobMap, setTripJobMap] = useState<Record<string, string>>({});
  const [defaults, setDefaults] = useState<{ fee: number; mileageFee: number; taxRate: number }>({ fee: 75, mileageFee: 0, taxRate: 0.25 });

  const load = async () => {
    if (!activeOrgId || !user) return;
    const { data } = await supabase
      .from("jobs").select("*").eq("organization_id", activeOrgId)
      .is("deleted_at", null).order("scheduled_at", { ascending: true, nullsFirst: false });
    setJobs((data ?? []) as Job[]);

    const { data: settings } = await supabase
      .from("earnings_settings").select("default_job_fee, default_mileage_fee, estimated_tax_rate, federal_tax_rate, state_tax_rate, self_employment_tax_rate")
      .eq("user_id", user.id).maybeSingle();
    const s: any = settings ?? {};
    const computedTax = Number(s.estimated_tax_rate ?? 0)
      || (Number(s.federal_tax_rate ?? 0) + Number(s.state_tax_rate ?? 0) + Number(s.self_employment_tax_rate ?? 0))
      || 0.25;
    setDefaults({
      fee: Number(s.default_job_fee ?? 75),
      mileageFee: Number(s.default_mileage_fee ?? 0),
      taxRate: computedTax,
    });

    const { data: liveTrip } = await supabase
      .from("trips").select("id").eq("user_id", user.id)
      .in("status", ["active","paused","draft","planned"])
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (liveTrip) {
      const { data: stops } = await supabase.from("trip_stops").select("job_id").eq("trip_id", liveTrip.id);
      const map: Record<string, string> = {};
      for (const s of (stops ?? []) as any[]) if (s.job_id) map[s.job_id] = liveTrip.id;
      setTripJobMap(map);
    } else setTripJobMap({});
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [activeOrgId, user]);

  const openNew = () => {
    setEditing(null);
    setForm({
      title: "", status: "scheduled", estimated_duration_minutes: 60,
      scheduled_at: new Date().toISOString().slice(0,16),
      fee_override: defaults.fee,        // prefill base fee, editable
      mileage_fee: defaults.mileageFee,  // prefill default mileage fee
    });
    setOpen(true);
  };
  const openEdit = (j: Job) => {
    setEditing(j);
    setForm({
      ...j,
      scheduled_at: j.scheduled_at ? j.scheduled_at.slice(0,16) : "",
      fee_override: j.fee_override ?? defaults.fee,
      mileage_fee: j.mileage_fee ?? defaults.mileageFee,
    });
    setOpen(true);
  };

  const save = async () => {
    if (!user || !activeOrgId || !form.title) return;
    // Treat override as "custom fee" only if it differs from default base fee.
    const overrideValue = form.fee_override === undefined || form.fee_override === null
      ? null
      : Number(form.fee_override) === Number(defaults.fee)
        ? null
        : Number(form.fee_override);
    const payload: any = {
      title: form.title,
      customer_name: form.customer_name || null,
      location: form.location || null,
      scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null,
      estimated_duration_minutes: form.estimated_duration_minutes ?? 60,
      status: form.status ?? "scheduled",
      fee_override: overrideValue,
      mileage_fee: form.mileage_fee !== undefined && form.mileage_fee !== null ? Number(form.mileage_fee) : null,
      notes: form.notes || null,
    };
    if (editing) {
      const { error } = await supabase.from("jobs").update({ ...payload, updated_by: user.id }).eq("id", editing.id);
      if (error) return toast.error(error.message);
      toast.success("Job updated");
    } else {
      const { error } = await supabase.from("jobs").insert({
        ...payload, organization_id: activeOrgId, assigned_to: user.id, created_by: user.id,
      });
      if (error) return toast.error(error.message);
      toast.success("Job created");
    }
    setOpen(false);
    load();
  };

  const setStatus = async (j: Job, status: string) => {
    const updates: any = { status };
    if (status === "in_progress" && !j.actual_start_time) updates.actual_start_time = new Date().toISOString();
    if (status === "completed") updates.actual_end_time = new Date().toISOString();
    const { error } = await supabase.from("jobs").update(updates).eq("id", j.id);
    if (error) return toast.error(error.message);
    load();
  };

  const duplicate = async (j: Job) => {
    if (!user || !activeOrgId) return;
    const { error } = await supabase.from("jobs").insert({
      organization_id: activeOrgId, assigned_to: user.id, created_by: user.id,
      title: `${j.title} (copy)`, customer_name: j.customer_name, location: j.location,
      estimated_duration_minutes: j.estimated_duration_minutes ?? 60,
      status: "scheduled", fee_override: j.fee_override, mileage_fee: j.mileage_fee, notes: j.notes,
    });
    if (error) return toast.error(error.message);
    toast.success("Job duplicated");
    load();
  };

  const today = new Date(); today.setHours(0,0,0,0);
  const tomorrow = new Date(today.getTime() + 86400000);

  const filtered = useMemo(() => jobs.filter(j => {
    const date = j.scheduled_at ? new Date(j.scheduled_at) : null;
    if (filter === "today") return date && date >= today && date < tomorrow && j.status !== "completed" && j.status !== "canceled";
    if (filter === "upcoming") return date && date >= tomorrow && j.status !== "completed" && j.status !== "canceled";
    if (filter === "completed") return j.status === "completed";
    if (filter === "canceled") return j.status === "canceled";
    return true;
  }), [jobs, filter, today, tomorrow]);

  const earningsFor = (j: Job) => {
    const base = j.fee_override != null ? Number(j.fee_override) : defaults.fee;
    const mileage = j.mileage_fee != null ? Number(j.mileage_fee) : 0;
    const gross = base + mileage;
    return { base, mileage, gross, taxable: gross * defaults.taxRate, net: gross * (1 - defaults.taxRate) };
  };

  const totals = useMemo(() => {
    return filtered.reduce((acc, j) => {
      const e = earningsFor(j);
      acc.base += e.base; acc.mileage += e.mileage; acc.gross += e.gross; acc.taxable += e.taxable;
      return acc;
    }, { base: 0, mileage: 0, gross: 0, taxable: 0 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filtered, defaults]);

  const fmt = (n: number) => `$${n.toFixed(2)}`;

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Jobs</h1>
            <p className="text-sm text-muted-foreground mt-1">All inspection jobs assigned to you</p>
          </div>
          <Button onClick={openNew}><Plus className="h-4 w-4 mr-1.5" />New Job</Button>
        </div>

        <Tabs value={filter} onValueChange={v => setFilter(v as FilterKey)}>
          <TabsList>
            <TabsTrigger value="today">Today</TabsTrigger>
            <TabsTrigger value="upcoming">Upcoming</TabsTrigger>
            <TabsTrigger value="completed">Completed</TabsTrigger>
            <TabsTrigger value="canceled">Canceled</TabsTrigger>
            <TabsTrigger value="all">All</TabsTrigger>
          </TabsList>
        </Tabs>

        <div className="grid gap-2">
          {filtered.length === 0 && (
            <Card><CardContent className="p-8 text-center text-sm text-muted-foreground">No jobs to show.</CardContent></Card>
          )}
          {filtered.map(j => {
            const inTrip = tripJobMap[j.id];
            return (
              <Card key={j.id}>
                <CardContent className="p-4 flex items-center justify-between gap-4 flex-wrap">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="font-medium">{j.title}</p>
                      <Badge variant="outline" className="capitalize text-xs">{j.status.replace("_"," ")}</Badge>
                      {inTrip ? (
                        <Link to="/app/inspector/trips" className="inline-flex">
                          <Badge variant="outline" className="text-xs border-primary/40 text-primary">
                            <RouteIcon className="h-3 w-3 mr-1" />In trip
                          </Badge>
                        </Link>
                      ) : (
                        <Badge variant="outline" className="text-xs text-muted-foreground">Not in trip</Badge>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {j.customer_name && <>{j.customer_name} · </>}
                      {j.location && <>{j.location} · </>}
                      {j.scheduled_at ? new Date(j.scheduled_at).toLocaleString([], {month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}) : "Unscheduled"}
                      {j.estimated_duration_minutes && <> · {j.estimated_duration_minutes}min</>}
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
                      <Button size="sm" variant="ghost" onClick={() => setStatus(j, "canceled")}><X className="h-3.5 w-3.5" /></Button>
                    )}
                    <Button size="sm" variant="ghost" onClick={() => duplicate(j)} title="Duplicate"><Copy className="h-3.5 w-3.5" /></Button>
                    <Button size="sm" variant="ghost" onClick={() => openEdit(j)}><Pencil className="h-3.5 w-3.5" /></Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader><DialogTitle>{editing ? "Edit Job" : "New Job"}</DialogTitle></DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1.5"><Label>Title</Label><Input value={form.title ?? ""} onChange={e => setForm({ ...form, title: e.target.value })} /></div>
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1.5"><Label>Customer</Label><Input value={form.customer_name ?? ""} onChange={e => setForm({ ...form, customer_name: e.target.value })} /></div>
              <div className="space-y-1.5"><Label>Location</Label><Input value={form.location ?? ""} onChange={e => setForm({ ...form, location: e.target.value })} /></div>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1.5"><Label>Scheduled</Label><Input type="datetime-local" value={(form.scheduled_at as any) ?? ""} onChange={e => setForm({ ...form, scheduled_at: e.target.value as any })} /></div>
              <div className="space-y-1.5"><Label>Duration (min)</Label><Input type="number" value={form.estimated_duration_minutes ?? 60} onChange={e => setForm({ ...form, estimated_duration_minutes: Number(e.target.value) })} /></div>
            </div>
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select value={form.status ?? "scheduled"} onValueChange={v => setForm({ ...form, status: v })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{STATUSES.map(s => <SelectItem key={s} value={s} className="capitalize">{s.replace("_"," ")}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="rounded-md border bg-muted/30 p-3 space-y-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Fees</p>
              <div className="grid grid-cols-2 gap-2">
                <div className="space-y-1.5">
                  <Label className="text-xs flex items-center gap-1.5">
                    Base inspection fee ($)
                    {Number(form.fee_override) !== Number(defaults.fee) && (
                      <Badge variant="outline" className="text-[10px]">Custom</Badge>
                    )}
                  </Label>
                  <Input type="number" step="0.01"
                    value={form.fee_override ?? defaults.fee}
                    onChange={e => setForm({ ...form, fee_override: e.target.value === "" ? null : Number(e.target.value) })} />
                  <p className="text-[10px] text-muted-foreground">Default ${defaults.fee.toFixed(2)} from Settings. Edit to override for this job.</p>
                </div>
                <div className="space-y-1.5">
                  <Label className="text-xs">Mileage fee ($)</Label>
                  <Input type="number" step="0.01"
                    value={form.mileage_fee ?? defaults.mileageFee}
                    onChange={e => setForm({ ...form, mileage_fee: e.target.value === "" ? null : Number(e.target.value) })} />
                  <p className="text-[10px] text-muted-foreground">Flat mileage fee added to this job.</p>
                </div>
              </div>
            </div>
            <div className="space-y-1.5"><Label>Notes</Label><Textarea rows={3} value={form.notes ?? ""} onChange={e => setForm({ ...form, notes: e.target.value })} /></div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={save}>{editing ? "Save" : "Create"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
