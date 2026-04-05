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
import { Car, Plus, Pencil, Trash2, Archive } from "lucide-react";

interface Vehicle {
  id: string;
  vin: string;
  year: string | null;
  make: string | null;
  model: string | null;
  trim: string | null;
  mileage: string | null;
  is_archived: boolean | null;
  deleted_at: string | null;
  created_at: string | null;
}

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [loading, setLoading] = useState(true);
  const [addOpen, setAddOpen] = useState(false);
  const [editVehicle, setEditVehicle] = useState<Vehicle | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Vehicle | null>(null);

  // Form state
  const [vin, setVin] = useState("");
  const [year, setYear] = useState("");
  const [make, setMake] = useState("");
  const [model, setModel] = useState("");
  const [trim, setTrim] = useState("");
  const [mileage, setMileage] = useState("");

  useEffect(() => { loadVehicles(); }, []);

  const loadVehicles = async () => {
    const { data } = await supabase
      .from("vehicles")
      .select("*")
      .is("deleted_at", null)
      .order("created_at", { ascending: false });
    setVehicles((data as Vehicle[]) || []);
    setLoading(false);
  };

  const resetForm = () => {
    setVin(""); setYear(""); setMake(""); setModel(""); setTrim(""); setMileage("");
  };

  const openEdit = (v: Vehicle) => {
    setEditVehicle(v);
    setVin(v.vin); setYear(v.year || ""); setMake(v.make || "");
    setModel(v.model || ""); setTrim(v.trim || ""); setMileage(v.mileage || "");
  };

  const saveVehicle = async () => {
    if (!vin.trim()) { toast.error("VIN is required"); return; }

    if (editVehicle) {
      const before = { vin: editVehicle.vin, year: editVehicle.year, make: editVehicle.make, model: editVehicle.model };
      const updates = { vin, year: year || null, make: make || null, model: model || null, trim: trim || null, mileage: mileage || null, updated_at: new Date().toISOString() };
      const { error } = await supabase.from("vehicles").update(updates).eq("id", editVehicle.id);
      if (error) { toast.error(error.message); return; }
      await logAudit("vehicle", editVehicle.id, "update", {
        vin: { before: before.vin, after: vin },
        make: { before: before.make, after: make },
      });
      toast.success("Vehicle updated");
      setEditVehicle(null);
    } else {
      const { data, error } = await supabase.from("vehicles").insert({
        vin, year: year || null, make: make || null, model: model || null, trim: trim || null, mileage: mileage || null,
      }).select().single();
      if (error) { toast.error(error.message); return; }
      if (data) await logAudit("vehicle", data.id, "create");
      toast.success("Vehicle added");
      setAddOpen(false);
    }
    resetForm();
    loadVehicles();
  };

  const softDelete = async () => {
    if (!deleteTarget) return;
    // Check for active inspections
    const { count } = await supabase
      .from("inspection_requests")
      .select("id", { count: "exact", head: true })
      .eq("vehicle_id", deleteTarget.id)
      .in("status", ["assigned", "scheduled", "in_progress"]);

    if (count && count > 0) {
      // Archive instead
      await supabase.from("vehicles").update({ is_archived: true, updated_at: new Date().toISOString() }).eq("id", deleteTarget.id);
      await logAudit("vehicle", deleteTarget.id, "update", { is_archived: { before: false, after: true } });
      toast.info("Vehicle archived (has active inspections)");
    } else {
      await supabase.from("vehicles").update({ deleted_at: new Date().toISOString() }).eq("id", deleteTarget.id);
      await logAudit("vehicle", deleteTarget.id, "delete");
      toast.success("Vehicle deleted");
    }
    setDeleteTarget(null);
    loadVehicles();
  };

  const toggleArchive = async (v: Vehicle) => {
    const newVal = !v.is_archived;
    await supabase.from("vehicles").update({ is_archived: newVal, updated_at: new Date().toISOString() }).eq("id", v.id);
    await logAudit("vehicle", v.id, "update", { is_archived: { before: v.is_archived, after: newVal } });
    toast.success(newVal ? "Vehicle archived" : "Vehicle restored");
    loadVehicles();
  };

  const vehicleLabel = (v: Vehicle) => [v.year, v.make, v.model, v.trim].filter(Boolean).join(" ") || "Unknown Vehicle";

  const formContent = (
    <div className="space-y-4">
      <div className="space-y-2">
        <Label>VIN *</Label>
        <Input value={vin} onChange={(e) => setVin(e.target.value.toUpperCase())} placeholder="1HGCM82633A004352" maxLength={17} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2"><Label>Year</Label><Input value={year} onChange={(e) => setYear(e.target.value)} placeholder="2024" /></div>
        <div className="space-y-2"><Label>Make</Label><Input value={make} onChange={(e) => setMake(e.target.value)} placeholder="Honda" /></div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2"><Label>Model</Label><Input value={model} onChange={(e) => setModel(e.target.value)} placeholder="Accord" /></div>
        <div className="space-y-2"><Label>Trim</Label><Input value={trim} onChange={(e) => setTrim(e.target.value)} placeholder="EX-L" /></div>
      </div>
      <div className="space-y-2"><Label>Mileage</Label><Input value={mileage} onChange={(e) => setMileage(e.target.value)} placeholder="45,000" /></div>
      <Button onClick={saveVehicle} className="w-full">{editVehicle ? "Save Changes" : "Add Vehicle"}</Button>
    </div>
  );

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Vehicles</h1>
            <p className="text-sm text-muted-foreground mt-1">Vehicle database · {vehicles.length} vehicles</p>
          </div>
          <Dialog open={addOpen} onOpenChange={(o) => { setAddOpen(o); if (!o) resetForm(); }}>
            <DialogTrigger asChild>
              <Button size="sm"><Plus className="h-4 w-4 mr-2" />Add Vehicle</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Add Vehicle</DialogTitle></DialogHeader>
              {formContent}
            </DialogContent>
          </Dialog>
        </div>

        {/* Edit dialog */}
        <Dialog open={!!editVehicle} onOpenChange={(o) => { if (!o) { setEditVehicle(null); resetForm(); } }}>
          <DialogContent>
            <DialogHeader><DialogTitle>Edit Vehicle</DialogTitle></DialogHeader>
            {formContent}
          </DialogContent>
        </Dialog>

        <ConfirmDeleteDialog
          open={!!deleteTarget}
          onOpenChange={(o) => !o && setDeleteTarget(null)}
          onConfirm={softDelete}
          title="Delete Vehicle?"
          description="This will soft-delete the vehicle. If it has active inspections, it will be archived instead."
        />

        {loading ? (
          <div className="flex justify-center p-12">
            <div className="animate-spin h-6 w-6 border-2 border-primary border-t-transparent rounded-full" />
          </div>
        ) : vehicles.length === 0 ? (
          <div className="text-center py-12 text-muted-foreground">
            <Car className="h-10 w-10 mx-auto mb-3 opacity-40" />
            <p className="text-sm">No vehicles yet. Add your first vehicle above.</p>
          </div>
        ) : (
          <div className="rounded-lg border bg-card overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b bg-muted/50">
                    <th className="text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider px-4 py-3">Vehicle</th>
                    <th className="text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider px-4 py-3">VIN</th>
                    <th className="text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider px-4 py-3 hidden md:table-cell">Mileage</th>
                    <th className="text-left text-xs font-semibold text-muted-foreground uppercase tracking-wider px-4 py-3 hidden lg:table-cell">Status</th>
                    <th className="text-right text-xs font-semibold text-muted-foreground uppercase tracking-wider px-4 py-3">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {vehicles.map((v) => (
                    <tr key={v.id} className="border-b last:border-0 hover:bg-muted/30 transition-colors duration-150">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <Car className="h-4 w-4 text-muted-foreground shrink-0" />
                          <span className="text-sm font-medium">{vehicleLabel(v)}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className="text-sm font-mono text-muted-foreground">{v.vin}</span>
                      </td>
                      <td className="px-4 py-3 hidden md:table-cell">
                        <span className="text-sm text-muted-foreground">{v.mileage || "—"}</span>
                      </td>
                      <td className="px-4 py-3 hidden lg:table-cell">
                        {v.is_archived ? (
                          <Badge variant="outline" className="bg-warning/10 text-warning">Archived</Badge>
                        ) : (
                          <Badge variant="outline" className="bg-success/10 text-success">Active</Badge>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-end gap-1">
                          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openEdit(v)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => toggleArchive(v)}>
                            <Archive className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8 text-destructive" onClick={() => setDeleteTarget(v)}>
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
