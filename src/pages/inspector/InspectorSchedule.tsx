import { useEffect, useMemo, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Clock, MapPin, Route as RouteIcon } from "lucide-react";
import { Link } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";

interface Job {
  id: string;
  title: string;
  customer_name: string | null;
  location: string | null;
  scheduled_at: string | null;
  status: string;
}

export default function InspectorSchedule() {
  const { activeOrgId } = useUserRoles();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [editing, setEditing] = useState<Job | null>(null);
  const [newTime, setNewTime] = useState("");

  const load = async () => {
    if (!activeOrgId) return;
    const { data } = await supabase
      .from("jobs").select("id,title,customer_name,location,scheduled_at,status")
      .eq("organization_id", activeOrgId).is("deleted_at", null)
      .neq("status", "canceled")
      .order("scheduled_at", { ascending: true, nullsFirst: false });
    setJobs((data ?? []) as Job[]);
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [activeOrgId]);

  const grouped = useMemo(() => {
    const groups: Record<string, Job[]> = {};
    for (const j of jobs) {
      const key = j.scheduled_at ? new Date(j.scheduled_at).toDateString() : "Unscheduled";
      (groups[key] ??= []).push(j);
    }
    return groups;
  }, [jobs]);

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

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Schedule</h1>
            <p className="text-sm text-muted-foreground mt-1">Your operational calendar — grouped by day</p>
          </div>
          <Button asChild variant="outline" size="sm"><Link to="/app/inspector/trips"><RouteIcon className="h-4 w-4 mr-1.5" />Plan trip</Link></Button>
        </div>

        {Object.keys(grouped).length === 0 && (
          <Card><CardContent className="p-8 text-center text-sm text-muted-foreground">Nothing scheduled. Create jobs from the Jobs page.</CardContent></Card>
        )}

        {Object.entries(grouped).map(([day, list]) => (
          <div key={day} className="space-y-2">
            <div className="flex items-baseline gap-2">
              <h2 className="text-sm font-semibold">{day}</h2>
              <span className="text-xs text-muted-foreground">{list.length} job{list.length !== 1 && "s"}</span>
            </div>
            <div className="grid gap-2">
              {list.map(j => (
                <Card key={j.id}>
                  <CardContent className="p-3 flex items-center justify-between gap-3 flex-wrap">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="font-medium text-sm">{j.title}</p>
                        <Badge variant="outline" className="capitalize text-xs">{j.status.replace("_"," ")}</Badge>
                      </div>
                      <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1.5 flex-wrap">
                        <Clock className="h-3 w-3" />
                        {j.scheduled_at ? new Date(j.scheduled_at).toLocaleTimeString([], { hour:"numeric", minute:"2-digit"}) : "Unscheduled"}
                        {j.customer_name && <>· {j.customer_name}</>}
                        {j.location && <><span>·</span><MapPin className="h-3 w-3" />{j.location}</>}
                      </p>
                    </div>
                    <Button size="sm" variant="ghost" onClick={() => { setEditing(j); setNewTime(j.scheduled_at ? j.scheduled_at.slice(0,16) : ""); }}>Reschedule</Button>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        ))}
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
