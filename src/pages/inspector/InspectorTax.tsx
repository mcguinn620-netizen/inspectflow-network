import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";
import { Info } from "lucide-react";

interface Settings {
  default_job_fee: number;
  mileage_rate: number;
  estimated_tax_rate: number;
}

interface PeriodStats {
  jobs: number;
  miles: number;
  jobEarnings: number;
  mileageEarnings: number;
}

export default function InspectorTax() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [settings, setSettings] = useState<Settings>({ default_job_fee: 75, mileage_rate: 0.67, estimated_tax_rate: 0.25 });
  const [period, setPeriod] = useState<"week" | "month">("week");
  const [week, setWeek] = useState<PeriodStats>({ jobs: 0, miles: 0, jobEarnings: 0, mileageEarnings: 0 });
  const [month, setMonth] = useState<PeriodStats>({ jobs: 0, miles: 0, jobEarnings: 0, mileageEarnings: 0 });
  const [saving, setSaving] = useState(false);

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: s } = await supabase.from("earnings_settings")
      .select("*").eq("user_id", user.id).maybeSingle();
    const cfg: Settings = s ? {
      default_job_fee: Number(s.default_job_fee),
      mileage_rate: Number(s.mileage_rate),
      estimated_tax_rate: Number(s.estimated_tax_rate),
    } : settings;
    if (s) setSettings(cfg);

    const now = new Date();
    const weekAgo = new Date(); weekAgo.setDate(now.getDate() - 7);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const { data: jobs } = await supabase.from("jobs")
      .select("status,fee_override,actual_end_time")
      .eq("organization_id", activeOrgId).eq("status", "completed")
      .gte("actual_end_time", monthStart.toISOString());

    const { data: trips } = await supabase.from("trips")
      .select("trip_date,total_miles").eq("user_id", user.id)
      .gte("trip_date", monthStart.toISOString().slice(0,10));

    const fee = cfg.default_job_fee;
    const mRate = cfg.mileage_rate;

    const calc = (jobsList: any[], tripsList: any[]): PeriodStats => {
      const miles = tripsList.reduce((sum, t) => sum + Number(t.total_miles || 0), 0);
      const jobEarnings = jobsList.reduce((sum, j) => sum + Number(j.fee_override ?? fee), 0);
      return { jobs: jobsList.length, miles, jobEarnings, mileageEarnings: miles * mRate };
    };

    const weekJobsList = (jobs ?? []).filter((j: any) => j.actual_end_time && new Date(j.actual_end_time) >= weekAgo);
    const weekTripsList = (trips ?? []).filter((t: any) => new Date(t.trip_date) >= weekAgo);
    setWeek(calc(weekJobsList, weekTripsList));
    setMonth(calc(jobs ?? [], trips ?? []));
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const save = async () => {
    if (!user || !activeOrgId) return;
    setSaving(true);
    const { error } = await supabase.from("earnings_settings").upsert({
      organization_id: activeOrgId, user_id: user.id,
      default_job_fee: settings.default_job_fee,
      mileage_rate: settings.mileage_rate,
      estimated_tax_rate: settings.estimated_tax_rate,
    }, { onConflict: "organization_id,user_id" });
    setSaving(false);
    if (error) return toast.error(error.message);
    toast.success("Settings saved");
    load();
  };

  const current = period === "week" ? week : month;
  const gross = current.jobEarnings + current.mileageEarnings;
  const taxOwed = gross * settings.estimated_tax_rate;
  const net = gross - taxOwed;

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Tax &amp; Earnings</h1>
            <p className="text-sm text-muted-foreground mt-1">Estimates based on completed jobs and logged miles</p>
          </div>
          <Tabs value={period} onValueChange={v => setPeriod(v as "week" | "month")}>
            <TabsList>
              <TabsTrigger value="week">This week</TabsTrigger>
              <TabsTrigger value="month">This month</TabsTrigger>
            </TabsList>
          </Tabs>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Stat label="Job earnings" value={`$${current.jobEarnings.toFixed(0)}`} sub={`${current.jobs} job${current.jobs !== 1 ? "s" : ""} × $${settings.default_job_fee.toFixed(0)} default`} />
          <Stat label="Mileage earnings" value={`$${current.mileageEarnings.toFixed(0)}`} sub={`${current.miles.toFixed(0)} mi × $${settings.mileage_rate.toFixed(2)}/mi`} />
          <Stat label="Estimated tax" value={`-$${taxOwed.toFixed(0)}`} sub={`${(settings.estimated_tax_rate * 100).toFixed(0)}% of gross`} muted />
          <Stat label="Estimated net" value={`$${net.toFixed(0)}`} sub={`${period === "week" ? "Past 7 days" : "Month-to-date"}`} highlight />
        </div>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2"><Info className="h-4 w-4" />How this is calculated</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground space-y-1">
            <p><span className="text-foreground font-medium">Gross</span> = Job earnings ({current.jobs} × ${settings.default_job_fee.toFixed(0)} unless overridden) + Mileage ({current.miles.toFixed(0)} mi × ${settings.mileage_rate.toFixed(2)})</p>
            <p><span className="text-foreground font-medium">Tax estimate</span> = Gross × {(settings.estimated_tax_rate * 100).toFixed(0)}%</p>
            <p><span className="text-foreground font-medium">Net</span> = Gross − Tax estimate</p>
            <p className="text-xs pt-2">First-pass estimator — confirm with a tax professional.</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle className="text-base">Earnings settings</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <div className="grid md:grid-cols-3 gap-3">
              <div className="space-y-1.5">
                <Label>Default job fee ($)</Label>
                <Input type="number" step="0.01" value={settings.default_job_fee} onChange={e => setSettings({ ...settings, default_job_fee: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">Used when a job has no override.</p>
              </div>
              <div className="space-y-1.5">
                <Label>Mileage rate ($/mi)</Label>
                <Input type="number" step="0.01" value={settings.mileage_rate} onChange={e => setSettings({ ...settings, mileage_rate: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">Separate mileage line on earnings.</p>
              </div>
              <div className="space-y-1.5">
                <Label>Tax rate (0–1)</Label>
                <Input type="number" step="0.01" value={settings.estimated_tax_rate} onChange={e => setSettings({ ...settings, estimated_tax_rate: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">e.g. 0.25 for 25%.</p>
              </div>
            </div>
            <Button onClick={save} disabled={saving}>{saving ? "Saving..." : "Save settings"}</Button>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}

function Stat({ label, value, sub, highlight, muted }: { label: string; value: string; sub: string; highlight?: boolean; muted?: boolean }) {
  return (
    <Card className={highlight ? "border-primary/40 bg-primary/5" : ""}>
      <CardContent className="p-4">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className={`text-2xl font-semibold mt-1 ${muted ? "text-muted-foreground" : ""}`}>{value}</p>
        <p className="text-xs text-muted-foreground mt-1">{sub}</p>
      </CardContent>
    </Card>
  );
}
