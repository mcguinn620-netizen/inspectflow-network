import { useState, useEffect } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { supabase } from "@/integrations/supabase/client";
import { StatusBadge, type InspectionStatus } from "@/components/StatusBadge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { logAudit } from "@/hooks/useAuditLog";
import { Search, Pencil, Eye, Filter } from "lucide-react";

type Inspection = {
  id: string;
  client_name: string | null;
  vin: string | null;
  vehicle_year: string | null;
  vehicle_make: string | null;
  vehicle_model: string | null;
  inspection_location: string | null;
  requested_date: string | null;
  status: string | null;
  priority: string | null;
  notes: string | null;
  inspector_id: string | null;
  template_name: string | null;
  overall_score: number | null;
  created_at: string | null;
};

type Inspector = { id: string; name: string };

const ALL_STATUSES: InspectionStatus[] = [
  "request_received", "assigned", "scheduled", "in_progress",
  "awaiting_review", "completed", "report_delivered",
];

const EDITABLE_STATUSES = ["request_received", "assigned", "scheduled", "in_progress", "awaiting_review"];

function isEditable(status: string | null) {
  return EDITABLE_STATUSES.includes(status || "");
}

export default function InspectionsPage() {
  const [inspections, setInspections] = useState<Inspection[]>([]);
  const [inspectors, setInspectors] = useState<Inspector[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [selected, setSelected] = useState<Inspection | null>(null);
  const [dialogMode, setDialogMode] = useState<"view" | "edit">("view");
  const [editForm, setEditForm] = useState({ notes: "", status: "", inspector_id: "", requested_date: "" });

  const fetchData = async () => {
    setLoading(true);
    const [{ data: ins }, { data: insp }] = await Promise.all([
      supabase.from("inspection_requests").select("*").is("deleted_at", null).order("created_at", { ascending: false }),
      supabase.from("inspectors").select("id, name").is("deleted_at", null),
    ]);
    setInspections(ins || []);
    setInspectors(insp || []);
    setLoading(false);
  };

  useEffect(() => { fetchData(); }, []);

  const openDialog = (insp: Inspection, mode: "view" | "edit") => {
    setSelected(insp);
    setDialogMode(mode);
    setEditForm({
      notes: insp.notes || "",
      status: insp.status || "request_received",
      inspector_id: insp.inspector_id || "",
      requested_date: insp.requested_date || "",
    });
  };

  const handleSave = async () => {
    if (!selected) return;
    const updates = {
      notes: editForm.notes,
      status: editForm.status,
      inspector_id: editForm.inspector_id || null,
      requested_date: editForm.requested_date,
      updated_at: new Date().toISOString(),
    };
    const { error } = await (supabase.from("inspection_requests") as any).update(updates).eq("id", selected.id);
    if (error) { toast.error("Failed to update"); return; }
    await logAudit("inspection_request", selected.id, "update", {
      status: { before: selected.status, after: editForm.status },
      notes: { before: selected.notes, after: editForm.notes },
    });
    toast.success("Inspection updated");
    setSelected(null);
    fetchData();
  };

  const filtered = inspections.filter((i) => {
    const matchesSearch = !search || [i.client_name, i.vin, i.vehicle_make, i.vehicle_model, i.inspection_location]
      .some((f) => f?.toLowerCase().includes(search.toLowerCase()));
    const matchesStatus = statusFilter === "all" || i.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const priorityColor = (p: string | null) => {
    if (p === "high" || p === "urgent") return "destructive";
    if (p === "medium") return "secondary";
    return "outline";
  };

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Inspections</h1>
            <p className="text-sm text-muted-foreground mt-1">{filtered.length} inspection records</p>
          </div>
        </div>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-3">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input placeholder="Search by client, VIN, vehicle..." className="pl-9" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-[200px]">
              <Filter className="h-4 w-4 mr-2" />
              <SelectValue placeholder="Filter by status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Statuses</SelectItem>
              {ALL_STATUSES.map((s) => (
                <SelectItem key={s} value={s}>{s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {/* Table */}
        <div className="rounded-lg border bg-card">
          {loading ? (
            <div className="p-12 text-center text-muted-foreground">Loading inspections...</div>
          ) : filtered.length === 0 ? (
            <div className="p-12 text-center text-muted-foreground">No inspections found</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Client</TableHead>
                  <TableHead className="hidden md:table-cell">Vehicle</TableHead>
                  <TableHead className="hidden lg:table-cell">Location</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="hidden sm:table-cell">Priority</TableHead>
                  <TableHead className="hidden lg:table-cell">Score</TableHead>
                  <TableHead className="hidden md:table-cell">Date</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((insp) => (
                  <TableRow key={insp.id}>
                    <TableCell className="font-medium">{insp.client_name || "—"}</TableCell>
                    <TableCell className="hidden md:table-cell text-muted-foreground">
                      {[insp.vehicle_year, insp.vehicle_make, insp.vehicle_model].filter(Boolean).join(" ") || "—"}
                    </TableCell>
                    <TableCell className="hidden lg:table-cell text-muted-foreground">{insp.inspection_location || "—"}</TableCell>
                    <TableCell><StatusBadge status={(insp.status as InspectionStatus) || "request_received"} /></TableCell>
                    <TableCell className="hidden sm:table-cell">
                      <Badge variant={priorityColor(insp.priority)}>{insp.priority || "normal"}</Badge>
                    </TableCell>
                    <TableCell className="hidden lg:table-cell">
                      {insp.overall_score != null ? <span className="font-semibold">{insp.overall_score}/100</span> : "—"}
                    </TableCell>
                    <TableCell className="hidden md:table-cell text-muted-foreground">
                      {insp.requested_date || (insp.created_at ? new Date(insp.created_at).toLocaleDateString() : "—")}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1">
                        {isEditable(insp.status) ? (
                          <Button variant="ghost" size="icon" onClick={() => openDialog(insp, "edit")} title="Edit">
                            <Pencil className="h-4 w-4" />
                          </Button>
                        ) : null}
                        <Button variant="ghost" size="icon" onClick={() => openDialog(insp, "view")} title="View">
                          <Eye className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </div>
      </div>

      {/* View / Edit Dialog */}
      <Dialog open={!!selected} onOpenChange={(o) => !o && setSelected(null)}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{dialogMode === "edit" ? "Edit Inspection" : "Inspection Details"}</DialogTitle>
          </DialogHeader>
          {selected && (
            <div className="space-y-4">
              {/* Read-only info */}
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div><span className="text-muted-foreground">Client:</span> <span className="font-medium">{selected.client_name || "—"}</span></div>
                <div><span className="text-muted-foreground">VIN:</span> <span className="font-mono text-xs">{selected.vin || "—"}</span></div>
                <div><span className="text-muted-foreground">Vehicle:</span> <span>{[selected.vehicle_year, selected.vehicle_make, selected.vehicle_model].filter(Boolean).join(" ") || "—"}</span></div>
                <div><span className="text-muted-foreground">Location:</span> <span>{selected.inspection_location || "—"}</span></div>
                <div><span className="text-muted-foreground">Template:</span> <span>{selected.template_name || "—"}</span></div>
                {selected.overall_score != null && (
                  <div><span className="text-muted-foreground">Score:</span> <span className="font-semibold">{selected.overall_score}/100</span></div>
                )}
              </div>

              {dialogMode === "edit" ? (
                <div className="space-y-3 border-t pt-3">
                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1">
                      <Label>Status</Label>
                      <Select value={editForm.status} onValueChange={(v) => setEditForm((f) => ({ ...f, status: v }))}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {ALL_STATUSES.map((s) => (
                            <SelectItem key={s} value={s}>{s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-1">
                      <Label>Assigned Inspector</Label>
                      <Select value={editForm.inspector_id} onValueChange={(v) => setEditForm((f) => ({ ...f, inspector_id: v }))}>
                        <SelectTrigger><SelectValue placeholder="Unassigned" /></SelectTrigger>
                        <SelectContent>
                          {inspectors.map((i) => (
                            <SelectItem key={i.id} value={i.id}>{i.name}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                  <div className="space-y-1">
                    <Label>Requested Date</Label>
                    <Input type="date" value={editForm.requested_date} onChange={(e) => setEditForm((f) => ({ ...f, requested_date: e.target.value }))} />
                  </div>
                  <div className="space-y-1">
                    <Label>Notes</Label>
                    <Textarea rows={3} value={editForm.notes} onChange={(e) => setEditForm((f) => ({ ...f, notes: e.target.value }))} />
                  </div>
                  <div className="flex justify-end gap-2 pt-2">
                    <Button variant="outline" onClick={() => setSelected(null)}>Cancel</Button>
                    <Button onClick={handleSave}>Save Changes</Button>
                  </div>
                </div>
              ) : (
                <div className="space-y-2 border-t pt-3 text-sm">
                  <div><span className="text-muted-foreground">Status:</span> <StatusBadge status={(selected.status as InspectionStatus) || "request_received"} /></div>
                  <div><span className="text-muted-foreground">Priority:</span> <Badge variant={priorityColor(selected.priority)}>{selected.priority || "normal"}</Badge></div>
                  <div><span className="text-muted-foreground">Date:</span> {selected.requested_date || "—"}</div>
                  {selected.notes && <div><span className="text-muted-foreground">Notes:</span> {selected.notes}</div>}
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
