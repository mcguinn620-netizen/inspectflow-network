import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";

interface Settings {
  default_job_fee: number;
  mileage_rate: number;
  estimated_tax_rate: number;
}

export default function InspectorTax() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [settings, setSettings] = useState<Settings>({ default_job_fee: 75, mileage_rate: 0.67, estimated_tax_rate: 0.25 });
  const [stats, setStats] = useState({
    weekJobs: 0, weekMiles: 0, weekEarnings: 0,
    monthJobs: 0, monthMiles: 0, monthEarnings: 0, monthMileageDeduction: 0,
  });
  const [saving, setSaving] = useState(false);

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: s } = await supabase.from("earnings_settings")
      .select("*").eq("user_id", user.id).maybeSingle();
    if (s) setSettings({
      default_job_fee: Number(s.default_job_fee),
      mileage_rate: Number(s.mileage_rate),
      estimated_tax_rate: Number(s.estimated_tax_rate),
    });

    const now = new Date();
    const weekAgo = new Date(); weekAgo.setDate(now.getDate() - 7);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const { data: jobs } = await supabase.from("jobs")
      .select("status,fee_override,actual_end_time")
      .eq("organization_id", activeOrgId)
      .eq("status", "completed")
      .gte("actual_end_time", monthStart.toISOString());

    const { data: trips } = await supabase.from("trips")
      .select("trip_date,total_miles")
      .eq("user_id", user.id)
      .gte("trip_date", monthStart.toISOString().slice(0,10));

    const fee = s ? Number(s.default_job_fee) : 75;
    const mRate = s ? Number(s.mileage_rate) : 0.67;

    const weekJobsList = (jobs ?? []).filter((j: any) => j.actual_end_time && new Date(j.actual_end_time) >= weekAgo);
    const weekMiles = (trips ?? []).filter((t: any) => new Date(t.trip_date) >= weekAgo).reduce((sum, t: any) => sum + Number(t.total_miles || 0), 0);
    const monthMiles = (trips ?? []).reduce((sum, t: any) => sum + Number(t.total_miles || 0), 0);
    const weekEarn = weekJobsList.reduce((sum, j: any) => sum + Number(j.fee_override ?? fee), 0) + weekMiles * mRate;
    const monthEarn = (jobs ?? []).reduce((sum, j: any) => sum + Number(j.fee_override ?? fee), 0) + monthMiles * mRate;

    setStats({
      weekJobs: weekJobsList.length,
      weekMiles,
      weekEarnings: weekEarn,
      monthJobs: (jobs ?? []).length,
      monthMiles,
      monthEarnings: monthEarn,
      monthMileageDeduction: monthMiles * mRate,
    });
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const save = async () => {
    if (!user || !activeOrgId) return;
    setSaving(true);
    const { error } = await supabase.from("earnings_settings").upsert({
      organization_id: activeOrgId,
      user_id: user.id,
      default_job_fee: settings.default_job_fee,
      mileage_rate: settings.mileage_rate,
      estimated_tax_rate: settings.estimated_tax_rate,
    }, { onConflict: "organization_id,user_id" });
    setSaving(false);
    if (error) return toast.error(error.message);
    toast.success("Settings saved");
    load();
  };

  const taxOwed = stats.monthEarnings * settings.estimated_tax_rate;

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Tax & Earnings</h1>
          <p className="text-sm text-muted-foreground mt-1">Estimates based on completed jobs and logged miles</p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Stat label="This week" value={`$${stats.weekEarnings.toFixed(0)}`} sub={`${stats.weekJobs} jobs · ${stats.weekMiles.toFixed(0)} mi`} />
          <Stat label="This month" value={`$${stats.monthEarnings.toFixed(0)}`} sub={`${stats.monthJobs} jobs · ${stats.monthMiles.toFixed(0)} mi`} />
          <Stat label="Mileage deduction (mo)" value={`$${stats.monthMileageDeduction.toFixed(0)}`} sub={`${stats.monthMiles.toFixed(0)} mi × $${settings.mileage_rate}`} />
          <Stat label="Est. tax owed (mo)" value={`$${taxOwed.toFixed(0)}`} sub={`${(settings.estimated_tax_rate*100).toFixed(0)}% of earnings`} />
        </div>

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

        <p className="text-xs text-muted-foreground">
          This is a first-pass estimator. Always confirm with a tax professional.
        </p>
      </div>
    </DashboardLayout>
  );
}

function Stat({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <Card><CardContent className="p-4">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="text-2xl font-semibold mt-1">{value}</p>
      <p className="text-xs text-muted-foreground mt-1">{sub}</p>
    </CardContent></Card>
  );
}
