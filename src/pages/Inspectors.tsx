import { useState, useEffect } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Star, MapPin, Plus, Clock, Calendar, UserCheck } from "lucide-react";

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
}

interface Territory {
  id: string;
  inspector_id: string;
  name: string;
  city: string | null;
  state: string | null;
  radius_miles: number | null;
  zip_codes: string[] | null;
}

const statusStyles: Record<string, string> = {
  available: "bg-success/10 text-success",
  busy: "bg-warning/10 text-warning",
  offline: "bg-muted text-muted-foreground",
};

const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export default function InspectorsPage() {
  const [inspectors, setInspectors] = useState<InspectorRow[]>([]);
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [loading, setLoading] = useState(true);
  const [addOpen, setAddOpen] = useState(false);
  const [newName, setNewName] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [newPhone, setNewPhone] = useState("");
  const [newRate, setNewRate] = useState("");
  const [newCity, setNewCity] = useState("");
  const [newState, setNewState] = useState("");
  const [newRadius, setNewRadius] = useState("25");

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    const [insRes, terRes] = await Promise.all([
      supabase.from("inspectors").select("*").order("name"),
      supabase.from("territories").select("*"),
    ]);
    setInspectors((insRes.data as InspectorRow[]) || []);
    setTerritories((terRes.data as Territory[]) || []);
    setLoading(false);
  };

  const addInspector = async () => {
    if (!newName.trim()) { toast.error("Name is required"); return; }

    const { data: ins, error } = await supabase.from("inspectors").insert({
      name: newName,
      email: newEmail || null,
      phone: newPhone || null,
      hourly_rate: newRate ? parseFloat(newRate) : null,
      status: "available",
    }).select().single();

    if (error) { toast.error(error.message); return; }

    // Create territory if city provided
    if (newCity && ins) {
      await supabase.from("territories").insert({
        inspector_id: ins.id,
        name: `${newCity} Area`,
        city: newCity,
        state: newState || null,
        radius_miles: parseFloat(newRadius) || 25,
      });
    }

    // Create default availability (Mon-Fri 8-5)
    if (ins) {
      const schedules = [1, 2, 3, 4, 5].map((day) => ({
        inspector_id: ins.id,
        day_of_week: day,
        start_time: "08:00",
        end_time: "17:00",
        is_available: true,
      }));
      await supabase.from("availability_schedules").insert(schedules);
    }

    toast.success("Inspector added with default schedule");
    setAddOpen(false);
    setNewName(""); setNewEmail(""); setNewPhone(""); setNewRate(""); setNewCity(""); setNewState("");
    loadData();
  };

  const getTerritory = (inspectorId: string) => territories.find((t) => t.inspector_id === inspectorId);

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Inspectors</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Manage your inspection network · {inspectors.length} inspectors
            </p>
          </div>
          <Dialog open={addOpen} onOpenChange={setAddOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="h-4 w-4 mr-2" />
                Add Inspector
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Add Inspector</DialogTitle>
              </DialogHeader>
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Full Name *</Label>
                    <Input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="Marcus Rivera" />
                  </div>
                  <div className="space-y-2">
                    <Label>Email</Label>
                    <Input type="email" value={newEmail} onChange={(e) => setNewEmail(e.target.value)} placeholder="marcus@email.com" />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Phone</Label>
                    <Input value={newPhone} onChange={(e) => setNewPhone(e.target.value)} placeholder="(555) 123-4567" />
                  </div>
                  <div className="space-y-2">
                    <Label>Hourly Rate ($)</Label>
                    <Input type="number" value={newRate} onChange={(e) => setNewRate(e.target.value)} placeholder="75" />
                  </div>
                </div>
                <div className="border-t pt-4">
                  <h4 className="text-sm font-medium mb-3 flex items-center gap-2"><MapPin className="h-4 w-4 text-primary" /> Service Territory</h4>
                  <div className="grid grid-cols-3 gap-4">
                    <div className="space-y-2">
                      <Label>City</Label>
                      <Input value={newCity} onChange={(e) => setNewCity(e.target.value)} placeholder="Dallas" />
                    </div>
                    <div className="space-y-2">
                      <Label>State</Label>
                      <Input value={newState} onChange={(e) => setNewState(e.target.value)} placeholder="TX" maxLength={2} />
                    </div>
                    <div className="space-y-2">
                      <Label>Radius (mi)</Label>
                      <Input type="number" value={newRadius} onChange={(e) => setNewRadius(e.target.value)} />
                    </div>
                  </div>
                </div>
                <Button onClick={addInspector} className="w-full">Add Inspector</Button>
              </div>
            </DialogContent>
          </Dialog>
        </div>

        {loading ? (
          <div className="flex justify-center p-12">
            <div className="animate-spin h-6 w-6 border-2 border-primary border-t-transparent rounded-full" />
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {inspectors.map((inspector) => {
              const territory = getTerritory(inspector.id);
              return (
                <div key={inspector.id} className="rounded-lg border bg-card p-4 hover:border-primary/30 transition-colors duration-150 cursor-pointer">
                  <div className="flex items-start gap-3">
                    <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                      <span className="text-sm font-semibold text-primary">
                        {inspector.name.split(" ").map((n) => n[0]).join("")}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <p className="text-sm font-semibold truncate">{inspector.name}</p>
                        <Badge variant="outline" className={statusStyles[inspector.status || "offline"]}>
                          {inspector.status}
                        </Badge>
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
                          <div className="flex items-center justify-center gap-1">
                            <MapPin className="h-3 w-3 text-muted-foreground" />
                          </div>
                          <p className="text-[10px] text-muted-foreground truncate">
                            {territory.city}{territory.state ? `, ${territory.state}` : ""} ({territory.radius_miles}mi)
                          </p>
                        </>
                      ) : (
                        <p className="text-[10px] text-muted-foreground">No territory</p>
                      )}
                    </div>
                  </div>
                  {inspector.hourly_rate && (
                    <div className="mt-2 pt-2 border-t">
                      <p className="text-xs text-muted-foreground">${inspector.hourly_rate}/hr</p>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
