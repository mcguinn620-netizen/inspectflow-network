import { useState, useEffect } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { MapPin, Clock, Star, Zap, UserCheck, AlertTriangle, Send, RefreshCw } from "lucide-react";

interface InspectionRequest {
  id: string;
  vin: string | null;
  vehicle_make: string | null;
  vehicle_model: string | null;
  vehicle_year: string | null;
  client_name: string | null;
  inspection_location: string | null;
  status: string | null;
  priority: string | null;
  requested_date: string | null;
}

interface Inspector {
  id: string;
  name: string;
  rating: number | null;
  completed_jobs: number | null;
  status: string | null;
}

interface DispatchAssignment {
  id: string;
  inspection_request_id: string;
  inspector_id: string | null;
  assignment_type: string | null;
  status: string | null;
  scheduled_date: string | null;
  dispatch_score: number | null;
  created_at: string | null;
}

export default function DispatchPage() {
  const [requests, setRequests] = useState<InspectionRequest[]>([]);
  const [inspectors, setInspectors] = useState<Inspector[]>([]);
  const [assignments, setAssignments] = useState<DispatchAssignment[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedInspector, setSelectedInspector] = useState<Record<string, string>>({});

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    const [reqRes, insRes, assRes] = await Promise.all([
      supabase.from("inspection_requests").select("*").in("status", ["request_received", "assigned", "scheduled"]).order("created_at", { ascending: false }),
      supabase.from("inspectors").select("*").eq("status", "available"),
      supabase.from("dispatch_assignments").select("*").order("created_at", { ascending: false }),
    ]);
    setRequests((reqRes.data as InspectionRequest[]) || []);
    setInspectors((insRes.data as Inspector[]) || []);
    setAssignments((assRes.data as DispatchAssignment[]) || []);
    setLoading(false);
  };

  const autoAssign = async (requestId: string) => {
    if (inspectors.length === 0) {
      toast.error("No available inspectors");
      return;
    }
    // Simple scoring: highest rating + most jobs = best match
    const best = inspectors.reduce((a, b) =>
      ((a.rating || 0) + (a.completed_jobs || 0) / 100) > ((b.rating || 0) + (b.completed_jobs || 0) / 100) ? a : b
    );
    await assignInspector(requestId, best.id, "auto");
  };

  const manualAssign = async (requestId: string) => {
    const inspectorId = selectedInspector[requestId];
    if (!inspectorId) {
      toast.error("Select an inspector first");
      return;
    }
    await assignInspector(requestId, inspectorId, "manual");
  };

  const assignInspector = async (requestId: string, inspectorId: string, type: string) => {
    const { error } = await supabase.from("dispatch_assignments").insert({
      inspection_request_id: requestId,
      inspector_id: inspectorId,
      assignment_type: type,
      status: "pending",
      dispatch_score: type === "auto" ? 95 : null,
    });
    if (error) {
      toast.error("Assignment failed: " + error.message);
      return;
    }
    await supabase.from("inspection_requests").update({ status: "assigned", inspector_id: inspectorId }).eq("id", requestId);
    toast.success(`Inspector ${type === "auto" ? "auto-" : ""}assigned successfully`);
    loadData();
  };

  const getAssignment = (reqId: string) => assignments.find((a) => a.inspection_request_id === reqId);

  const priorityConfig: Record<string, { icon: React.ReactNode; class: string }> = {
    high: { icon: <AlertTriangle className="h-3.5 w-3.5" />, class: "bg-destructive/10 text-destructive" },
    medium: { icon: <Clock className="h-3.5 w-3.5" />, class: "bg-warning/10 text-warning" },
    low: { icon: null, class: "bg-muted text-muted-foreground" },
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Dispatch Center</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Intelligent inspector assignment · {requests.length} pending requests
            </p>
          </div>
          <Button variant="outline" size="sm" onClick={loadData}>
            <RefreshCw className="h-4 w-4 mr-2" />
            Refresh
          </Button>
        </div>

        {/* Available Inspectors Summary */}
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {inspectors.slice(0, 4).map((ins) => (
            <div key={ins.id} className="rounded-lg border bg-card p-3">
              <div className="flex items-center gap-2">
                <div className="h-8 w-8 rounded-full bg-success/10 flex items-center justify-center">
                  <UserCheck className="h-4 w-4 text-success" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{ins.name}</p>
                  <div className="flex items-center gap-2">
                    <Star className="h-3 w-3 text-warning" />
                    <span className="text-xs text-muted-foreground">{ins.rating || 0} · {ins.completed_jobs || 0} jobs</span>
                  </div>
                </div>
              </div>
            </div>
          ))}
          {inspectors.length === 0 && !loading && (
            <div className="col-span-full rounded-lg border border-dashed bg-muted/30 p-6 text-center">
              <p className="text-sm text-muted-foreground">No inspectors available. Add inspectors in the Inspectors page.</p>
            </div>
          )}
        </div>

        {/* Dispatch Queue */}
        <div>
          <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground mb-4">
            Dispatch Queue
          </h2>
          <div className="space-y-3">
            {loading ? (
              <div className="rounded-lg border bg-card p-8 text-center">
                <div className="animate-spin h-6 w-6 border-2 border-primary border-t-transparent rounded-full mx-auto" />
              </div>
            ) : requests.length === 0 ? (
              <div className="rounded-lg border border-dashed bg-muted/30 p-8 text-center">
                <Send className="h-8 w-8 text-muted-foreground mx-auto mb-2" />
                <p className="text-sm text-muted-foreground">No pending inspection requests</p>
                <p className="text-xs text-muted-foreground mt-1">Import inspections from the Command Center</p>
              </div>
            ) : (
              requests.map((req) => {
                const assignment = getAssignment(req.id);
                const prio = priorityConfig[req.priority || "medium"];
                return (
                  <div key={req.id} className="rounded-lg border bg-card p-4 hover:border-primary/30 transition-colors duration-150">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="text-xs font-mono-tech text-muted-foreground">{req.id.slice(0, 8)}</span>
                          <Badge variant="outline" className={prio.class}>
                            {prio.icon}
                            <span className="ml-1 capitalize">{req.priority || "medium"}</span>
                          </Badge>
                          <Badge variant="outline" className="text-xs capitalize">
                            {req.status?.replace("_", " ")}
                          </Badge>
                        </div>
                        <p className="text-sm font-medium">
                          {req.vehicle_year} {req.vehicle_make} {req.vehicle_model}
                        </p>
                        <div className="flex items-center gap-4 mt-1 text-xs text-muted-foreground">
                          {req.client_name && <span>{req.client_name}</span>}
                          {req.vin && <span className="font-mono-tech">{req.vin}</span>}
                          {req.inspection_location && (
                            <span className="flex items-center gap-1">
                              <MapPin className="h-3 w-3" />
                              {req.inspection_location}
                            </span>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        {!assignment ? (
                          <>
                            <Select onValueChange={(v) => setSelectedInspector((s) => ({ ...s, [req.id]: v }))}>
                              <SelectTrigger className="w-44 h-8 text-xs">
                                <SelectValue placeholder="Select inspector" />
                              </SelectTrigger>
                              <SelectContent>
                                {inspectors.map((ins) => (
                                  <SelectItem key={ins.id} value={ins.id}>
                                    {ins.name} ({ins.rating || 0}★)
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                            <Button size="sm" variant="outline" onClick={() => manualAssign(req.id)}>
                              Assign
                            </Button>
                            <Button size="sm" onClick={() => autoAssign(req.id)}>
                              <Zap className="h-3.5 w-3.5 mr-1" />
                              Auto
                            </Button>
                          </>
                        ) : (
                          <Badge className="bg-success/10 text-success">
                            <UserCheck className="h-3 w-3 mr-1" />
                            Assigned ({assignment.assignment_type})
                          </Badge>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
