import { useState, useEffect } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { ConfirmDeleteDialog } from "@/components/ConfirmDeleteDialog";
import { toast } from "sonner";
import { logAudit } from "@/hooks/useAuditLog";
import { Star, MapPin, Plus, Pencil, Trash2 } from "lucide-react";

interface InspectorRow {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  rating: number | null;
  completed_jobs: number | null;
  status: string | null;
  certifications: string[] | null;
  hourly_rate: number | null;
  deleted_at: string | null;
}

interface Territory {
  id: string;
  inspector_id: string;
  name: string;
  city: string | null;
  state: string | null;
  radius_miles: number | null;
}

const statusStyles: Record<string, string> = {
  available: "bg-success/10 text-success",
  busy: "bg-warning/10 text-warning",
  offline: "bg-muted text-muted-foreground",
};

export default function InspectorsPage() {
  const [inspectors, setInspectors] = useState<InspectorRow[]>([]);
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [loading, setLoading] = useState(true);
  const [addOpen, setAddOpen] = useState(false);
  const [editInspector, setEditInspector] = useState<InspectorRow | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<InspectorRow | null>(null);

  // Form
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [rate, setRate] = useState("");
  const [city, setCity] = useState("");
  const [state, setState] = useState("");
  const [radius, setRadius] = useState("25");

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    const [insRes, terRes] = await Promise.all([
      supabase.from("inspectors").select("*").is("deleted_at", null).order("name"),
      supabase.from("territories").select("*"),
    ]);
    setInspectors((insRes.data as InspectorRow[]) || []);
    setTerritories((terRes.data as Territory[]) || []);
    setLoading(false);
  };

  const resetForm = () => {
    setName(""); setEmail(""); setPhone(""); setRate(""); setCity(""); setState(""); setRadius("25");
  };

  const openEdit = (ins: InspectorRow) => {
    setEditInspector(ins);
    setName(ins.name); setEmail(ins.email || ""); setPhone(ins.phone || "");
    setRate(ins.hourly_rate?.toString() || "");
    const ter = territories.find((t) => t.inspector_id === ins.id);
    setCity(ter?.city || ""); setState(ter?.state || ""); setRadius(ter?.radius_miles?.toString() || "25");
  };

  const saveInspector = async () => {
    if (!name.trim()) { toast.error("Name is required"); return; }

    if (editInspector) {
      const updates = {
        name, email: email || null, phone: phone || null,
        hourly_rate: rate ? parseFloat(rate) : null,
        updated_at: new Date().toISOString(),
      };
      const { error } = await supabase.from("inspectors").update(updates).eq("id", editInspector.id);
      if (error) { toast.error(error.message); return; }

      // Update territory
      const ter = territories.find((t) => t.inspector_id === editInspector.id);
      if (ter && city) {
        await supabase.from("territories").update({
          city: city || null, state: state || null,
          radius_miles: parseFloat(radius) || 25,
          name: `${city} Area`,
        }).eq("id", ter.id);
      } else if (!ter && city) {
        await supabase.from("territories").insert({
          inspector_id: editInspector.id, name: `${city} Area`,
          city, state: state || null, radius_miles: parseFloat(radius) || 25,
        });
      }

      await logAudit("inspector", editInspector.id, "update", {
        name: { before: editInspector.name, after: name },
      });
      toast.success("Inspector updated");
      setEditInspector(null);
    } else {
      const { data: ins, error } = await supabase.from("inspectors").insert({
        name, email: email || null, phone: phone || null,
        hourly_rate: rate ? parseFloat(rate) : null, status: "available",
      }).select().single();
      if (error) { toast.error(error.message); return; }

      if (city && ins) {
        await supabase.from("territories").insert({
          inspector_id: ins.id, name: `${city} Area`,
          city, state: state || null, radius_miles: parseFloat(radius) || 25,
        });
      }
      if (ins) {
        const schedules = [1, 2, 3, 4, 5].map((day) => ({
          inspector_id: ins.id, day_of_week: day,
          start_time: "08:00", end_time: "17:00", is_available: true,
        }));
        await supabase.from("availability_schedules").insert(schedules);
        await logAudit("inspector", ins.id, "create");
      }
      toast.success("Inspector added");
      setAddOpen(false);
    }
    resetForm();
    loadData();
  };

  const softDelete = async () => {
    if (!deleteTarget) return;
    await supabase.from("inspectors").update({ deleted_at: new Date().toISOString() }).eq("id", deleteTarget.id);
    await logAudit("inspector", deleteTarget.id, "delete");
    toast.success("Inspector removed");
    setDeleteTarget(null);
    loadData();
  };

  const getTerritory = (id: string) => territories.find((t) => t.inspector_id === id);

  const formContent = (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2"><Label>Full Name *</Label><Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Marcus Rivera" /></div>
        <div className="space-y-2"><Label>Email</Label><Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="marcus@email.com" /></div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2"><Label>Phone</Label><Input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="(555) 123-4567" /></div>
        <div className="space-y-2"><Label>Hourly Rate ($)</Label><Input type="number" value={rate} onChange={(e) => setRate(e.target.value)} placeholder="75" /></div>
      </div>
      <div className="border-t pt-4">
        <h4 className="text-sm font-medium mb-3 flex items-center gap-2"><MapPin className="h-4 w-4 text-primary" /> Service Territory</h4>
        <div className="grid grid-cols-3 gap-4">
          <div className="space-y-2"><Label>City</Label><Input value={city} onChange={(e) => setCity(e.target.value)} placeholder="Dallas" /></div>
          <div className="space-y-2"><Label>State</Label><Input value={state} onChange={(e) => setState(e.target.value)} placeholder="TX" maxLength={2} /></div>
          <div className="space-y-2"><Label>Radius (mi)</Label><Input type="number" value={radius} onChange={(e) => setRadius(e.target.value)} /></div>
        </div>
      </div>
      <Button onClick={saveInspector} className="w-full">{editInspector ? "Save Changes" : "Add Inspector"}</Button>
    </div>
  );

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Inspectors</h1>
            <p className="text-sm text-muted-foreground mt-1">Manage your inspection network · {inspectors.length} inspectors</p>
          </div>
          <Dialog open={addOpen} onOpenChange={(o) => { setAddOpen(o); if (!o) resetForm(); }}>
            <DialogTrigger asChild>
              <Button size="sm"><Plus className="h-4 w-4 mr-2" />Add Inspector</Button>
            </DialogTrigger>
            <DialogContent><DialogHeader><DialogTitle>Add Inspector</DialogTitle></DialogHeader>{formContent}</DialogContent>
          </Dialog>
        </div>

        <Dialog open={!!editInspector} onOpenChange={(o) => { if (!o) { setEditInspector(null); resetForm(); } }}>
          <DialogContent><DialogHeader><DialogTitle>Edit Inspector</DialogTitle></DialogHeader>{formContent}</DialogContent>
        </Dialog>

        <ConfirmDeleteDialog
          open={!!deleteTarget}
          onOpenChange={(o) => !o && setDeleteTarget(null)}
          onConfirm={softDelete}
          title="Remove Inspector?"
          description="This will soft-delete the inspector. Their inspection history will be preserved."
        />

        {loading ? (
          <div className="flex justify-center p-12">
            <div className="animate-spin h-6 w-6 border-2 border-primary border-t-transparent rounded-full" />
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {inspectors.map((inspector) => {
              const territory = getTerritory(inspector.id);
              return (
                <div key={inspector.id} className="rounded-lg border bg-card p-4 hover:border-primary/30 transition-colors duration-150 group">
                  <div className="flex items-start gap-3">
                    <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                      <span className="text-sm font-semibold text-primary">
                        {inspector.name.split(" ").map((n) => n[0]).join("")}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <p className="text-sm font-semibold truncate">{inspector.name}</p>
                        <Badge variant="outline" className={statusStyles[inspector.status || "offline"]}>{inspector.status}</Badge>
                      </div>
                      {inspector.email && <p className="text-xs text-muted-foreground truncate">{inspector.email}</p>}
                    </div>
                  </div>
                  <div className="mt-3 pt-3 border-t grid grid-cols-3 gap-2 text-center">
                    <div>
                      <div className="flex items-center justify-center gap-1">
                        <Star className="h-3 w-3 text-warning" />
                        <span className="text-sm font-semibold">{inspector.rating || "—"}</span>
                      </div>
                      <p className="text-[10px] text-muted-foreground">Rating</p>
                    </div>
                    <div>
                      <p className="text-sm font-semibold">{inspector.completed_jobs || 0}</p>
                      <p className="text-[10px] text-muted-foreground">Jobs</p>
                    </div>
                    <div>
                      {territory ? (
                        <>
                          <div className="flex items-center justify-center gap-1"><MapPin className="h-3 w-3 text-muted-foreground" /></div>
                          <p className="text-[10px] text-muted-foreground truncate">
                            {territory.city}{territory.state ? `, ${territory.state}` : ""} ({territory.radius_miles}mi)
                          </p>
                        </>
                      ) : (
                        <p className="text-[10px] text-muted-foreground">No territory</p>
                      )}
                    </div>
                  </div>
                  <div className="mt-2 pt-2 border-t flex items-center justify-between">
                    <span className="text-xs text-muted-foreground">{inspector.hourly_rate ? `$${inspector.hourly_rate}/hr` : ""}</span>
                    <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                      <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => openEdit(inspector)}>
                        <Pencil className="h-3 w-3" />
                      </Button>
                      <Button variant="ghost" size="icon" className="h-7 w-7 text-destructive" onClick={() => setDeleteTarget(inspector)}>
                        <Trash2 className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
