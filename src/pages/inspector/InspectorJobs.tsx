import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Pencil, Play, CheckCircle2, X } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";

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
  notes: string | null;
}

const STATUSES = ["scheduled", "in_progress", "completed", "canceled"] as const;

export default function InspectorJobs() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [filter, setFilter] = useState<string>("all");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Job | null>(null);
  const [form, setForm] = useState<Partial<Job>>({ title: "", status: "scheduled", estimated_duration_minutes: 60 });

  const load = async () => {
    if (!activeOrgId) return;
    const { data } = await supabase
      .from("jobs").select("*")
      .eq("organization_id", activeOrgId)
      .is("deleted_at", null)
      .order("scheduled_at", { ascending: true, nullsFirst: false });
    setJobs((data ?? []) as Job[]);
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [activeOrgId]);

  const openNew = () => {
    setEditing(null);
    setForm({ title: "", status: "scheduled", estimated_duration_minutes: 60, scheduled_at: new Date().toISOString().slice(0,16) });
    setOpen(true);
  };
  const openEdit = (j: Job) => {
    setEditing(j);
    setForm({ ...j, scheduled_at: j.scheduled_at ? j.scheduled_at.slice(0,16) : "" });
    setOpen(true);
  };

  const save = async () => {
    if (!user || !activeOrgId || !form.title) return;
    const payload: any = {
      title: form.title,
      customer_name: form.customer_name || null,
      location: form.location || null,
      scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null,
      estimated_duration_minutes: form.estimated_duration_minutes ?? 60,
      status: form.status ?? "scheduled",
      fee_override: form.fee_override ?? null,
      notes: form.notes || null,
    };
    if (editing) {
      const { error } = await supabase.from("jobs").update({ ...payload, updated_by: user.id }).eq("id", editing.id);
      if (error) return toast.error(error.message);
      toast.success("Job updated");
    } else {
      const { error } = await supabase.from("jobs").insert({
        ...payload,
        organization_id: activeOrgId,
        assigned_to: user.id,
        created_by: user.id,
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

  const filtered = filter === "all" ? jobs : jobs.filter(j => j.status === filter);

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Jobs</h1>
            <p className="text-sm text-muted-foreground mt-1">All inspection jobs assigned to you</p>
          </div>
          <div className="flex items-center gap-2">
            <Select value={filter} onValueChange={setFilter}>
              <SelectTrigger className="w-36"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                {STATUSES.map(s => <SelectItem key={s} value={s} className="capitalize">{s.replace("_"," ")}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button onClick={openNew}><Plus className="h-4 w-4 mr-1.5" />New Job</Button>
          </div>
        </div>

        <div className="grid gap-2">
          {filtered.length === 0 && (
            <Card><CardContent className="p-8 text-center text-sm text-muted-foreground">No jobs to show.</CardContent></Card>
          )}
          {filtered.map(j => (
            <Card key={j.id}>
              <CardContent className="p-4 flex items-center justify-between gap-4 flex-wrap">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-medium">{j.title}</p>
                    <Badge variant="outline" className="capitalize text-xs">{j.status.replace("_"," ")}</Badge>
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    {j.customer_name && <>{j.customer_name} · </>}
                    {j.location && <>{j.location} · </>}
                    {j.scheduled_at ? new Date(j.scheduled_at).toLocaleString([], {month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}) : "Unscheduled"}
                    {j.estimated_duration_minutes && <> · {j.estimated_duration_minutes}min</>}
                  </p>
                </div>
                <div className="flex items-center gap-1">
                  {j.status === "scheduled" && (
                    <Button size="sm" variant="outline" onClick={() => setStatus(j, "in_progress")}><Play className="h-3.5 w-3.5 mr-1" />Start</Button>
                  )}
                  {j.status === "in_progress" && (
                    <Button size="sm" variant="outline" onClick={() => setStatus(j, "completed")}><CheckCircle2 className="h-3.5 w-3.5 mr-1" />Complete</Button>
                  )}
                  {(j.status === "scheduled" || j.status === "in_progress") && (
                    <Button size="sm" variant="ghost" onClick={() => setStatus(j, "canceled")}><X className="h-3.5 w-3.5" /></Button>
                  )}
                  <Button size="sm" variant="ghost" onClick={() => openEdit(j)}><Pencil className="h-3.5 w-3.5" /></Button>
                </div>
              </CardContent>
            </Card>
          ))}
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
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1.5">
                <Label>Status</Label>
                <Select value={form.status ?? "scheduled"} onValueChange={v => setForm({ ...form, status: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{STATUSES.map(s => <SelectItem key={s} value={s} className="capitalize">{s.replace("_"," ")}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5"><Label>Fee override ($)</Label><Input type="number" value={form.fee_override ?? ""} onChange={e => setForm({ ...form, fee_override: e.target.value ? Number(e.target.value) : null })} /></div>
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
