import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";

export interface ActiveTrip {
  id: string;
  title: string | null;
  trip_date: string;
  status: string;
  total_miles: number | null;
  started_at: string | null;
}
export interface ActiveStop {
  id: string;
  trip_id: string;
  job_id: string | null;
  sort_order: number;
  label: string | null;
  address: string | null;
  status: string;
  latitude: number | null;
  longitude: number | null;
}

interface Ctx {
  trip: ActiveTrip | null;
  stops: ActiveStop[];
  nextStop: ActiveStop | null;
  progress: { completed: number; total: number };
  loading: boolean;
  refresh: () => Promise<void>;
}

const ActiveTripContext = createContext<Ctx>({
  trip: null, stops: [], nextStop: null,
  progress: { completed: 0, total: 0 }, loading: true,
  refresh: async () => {},
});

const ACTIVE_STATUSES = ["active", "paused", "draft", "planned"];

export function ActiveTripProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [trip, setTrip] = useState<ActiveTrip | null>(null);
  const [stops, setStops] = useState<ActiveStop[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (!user) { setTrip(null); setStops([]); setLoading(false); return; }
    setLoading(true);
    const { data: t } = await supabase
      .from("trips")
      .select("id,title,trip_date,status,total_miles,started_at")
      .eq("user_id", user.id)
      .in("status", ACTIVE_STATUSES)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (!t) { setTrip(null); setStops([]); setLoading(false); return; }
    setTrip(t as ActiveTrip);
    const { data: s } = await supabase
      .from("trip_stops")
      .select("id,trip_id,job_id,sort_order,label,address,status,latitude,longitude")
      .eq("trip_id", t.id)
      .order("sort_order");
    setStops((s ?? []) as ActiveStop[]);
    setLoading(false);
  }, [user]);

  useEffect(() => { refresh(); }, [refresh]);

  // Realtime: keep banner/next-stop in sync across pages
  useEffect(() => {
    if (!user) return;
    const ch = supabase
      .channel("active-trip-watch")
      .on("postgres_changes", { event: "*", schema: "public", table: "trips", filter: `user_id=eq.${user.id}` }, () => refresh())
      .on("postgres_changes", { event: "*", schema: "public", table: "trip_stops" }, () => refresh())
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [user, refresh]);

  const value = useMemo<Ctx>(() => {
    const completed = stops.filter(s => s.status === "completed" || s.status === "skipped").length;
    const next = stops.find(s => s.status !== "completed" && s.status !== "skipped") ?? null;
    return { trip, stops, nextStop: next, progress: { completed, total: stops.length }, loading, refresh };
  }, [trip, stops, loading, refresh]);

  return <ActiveTripContext.Provider value={value}>{children}</ActiveTripContext.Provider>;
}

export const useActiveTrip = () => useContext(ActiveTripContext);
