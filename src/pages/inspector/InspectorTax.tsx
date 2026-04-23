import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { Info, Settings as SettingsIcon, TrendingUp, Receipt, Car, Calculator } from "lucide-react";

interface Settings {
  default_job_fee: number;
  default_mileage_fee: number;
  mileage_rate: number;
  estimated_tax_rate: number;
  federal_tax_rate: number;
  state_tax_rate: number;
  self_employment_tax_rate: number;
  state_code: string | null;
  filing_status: string;
}

interface PeriodStats {
  jobs: number;
  miles: number;
  jobEarnings: number;
  mileageFeeEarnings: number;
}

const DEFAULTS: Settings = {
  default_job_fee: 75,
  default_mileage_fee: 0,
  mileage_rate: 0.67,
  estimated_tax_rate: 0.25,
  federal_tax_rate: 0.15,
  state_tax_rate: 0.05,
  self_employment_tax_rate: 0.153,
  state_code: null,
  filing_status: "single",
};

export default function InspectorTax() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [settings, setSettings] = useState<Settings>(DEFAULTS);
  const [period, setPeriod] = useState<"week" | "month" | "ytd">("week");
  const [week, setWeek] = useState<PeriodStats>({ jobs: 0, miles: 0, jobEarnings: 0, mileageFeeEarnings: 0 });
  const [month, setMonth] = useState<PeriodStats>({ jobs: 0, miles: 0, jobEarnings: 0, mileageFeeEarnings: 0 });
  const [ytd, setYtd] = useState<PeriodStats>({ jobs: 0, miles: 0, jobEarnings: 0, mileageFeeEarnings: 0 });

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: s } = await supabase.from("earnings_settings").select("*").eq("user_id", user.id).maybeSingle();
    const cfg: Settings = s ? {
      default_job_fee: Number(s.default_job_fee),
      default_mileage_fee: Number((s as any).default_mileage_fee ?? 0),
      mileage_rate: Number(s.mileage_rate),
      estimated_tax_rate: Number(s.estimated_tax_rate),
      federal_tax_rate: Number((s as any).federal_tax_rate ?? 0.15),
      state_tax_rate: Number((s as any).state_tax_rate ?? 0.05),
      self_employment_tax_rate: Number((s as any).self_employment_tax_rate ?? 0.153),
      state_code: (s as any).state_code ?? null,
      filing_status: (s as any).filing_status ?? "single",
    } : DEFAULTS;
    setSettings(cfg);

    const now = new Date();
    const weekAgo = new Date(); weekAgo.setDate(now.getDate() - 7);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const yearStart = new Date(now.getFullYear(), 0, 1);

    const { data: jobs } = await supabase.from("jobs")
      .select("status,fee_override,mileage_fee,actual_end_time")
      .eq("organization_id", activeOrgId).eq("status", "completed")
      .gte("actual_end_time", yearStart.toISOString());

    const { data: trips } = await supabase.from("trips")
      .select("trip_date,total_miles").eq("user_id", user.id)
      .gte("trip_date", yearStart.toISOString().slice(0,10));

    const calc = (jobsList: any[], tripsList: any[]): PeriodStats => {
      const miles = tripsList.reduce((sum, t) => sum + Number(t.total_miles || 0), 0);
      const jobEarnings = jobsList.reduce((sum, j) => sum + Number(j.fee_override ?? cfg.default_job_fee), 0);
      const mileageFeeEarnings = jobsList.reduce((sum, j) => sum + Number(j.mileage_fee ?? cfg.default_mileage_fee), 0);
      return { jobs: jobsList.length, miles, jobEarnings, mileageFeeEarnings };
    };

    const inRange = (d: string | null | undefined, from: Date) => d ? new Date(d) >= from : false;

    setWeek(calc(
      (jobs ?? []).filter((j: any) => inRange(j.actual_end_time, weekAgo)),
      (trips ?? []).filter((t: any) => new Date(t.trip_date) >= weekAgo),
    ));
    setMonth(calc(
      (jobs ?? []).filter((j: any) => inRange(j.actual_end_time, monthStart)),
      (trips ?? []).filter((t: any) => new Date(t.trip_date) >= monthStart),
    ));
    setYtd(calc(jobs ?? [], trips ?? []));
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const current = period === "week" ? week : period === "month" ? month : ytd;
  const periodLabel = period === "week" ? "Past 7 days" : period === "month" ? "Month-to-date" : "Year-to-date";

  // Earnings breakdown
  const grossJobs = current.jobEarnings;
  const grossMileageFees = current.mileageFeeEarnings;
  const gross = grossJobs + grossMileageFees;

  // Mileage deduction (IRS standard mileage method) reduces taxable income
  const mileageDeduction = current.miles * settings.mileage_rate;
  const taxable = Math.max(gross - mileageDeduction, 0);

  // Tax breakdown — use detailed rates if present, else fallback to combined estimate
  const useDetailed = settings.federal_tax_rate > 0 || settings.state_tax_rate > 0 || settings.self_employment_tax_rate > 0;
  const seTax = useDetailed ? taxable * settings.self_employment_tax_rate : 0;
  const fedTax = useDetailed ? taxable * settings.federal_tax_rate : taxable * settings.estimated_tax_rate;
  const stateTax = useDetailed ? taxable * settings.state_tax_rate : 0;
  const totalTax = seTax + fedTax + stateTax;
  const net = gross - totalTax;

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Tax &amp; Earnings</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Estimates based on completed jobs and logged miles
              {settings.state_code && <> · State: <span className="font-medium text-foreground">{settings.state_code}</span></>}
            </p>
          </div>
          <div className="flex gap-2">
            <Tabs value={period} onValueChange={(v) => setPeriod(v as any)}>
              <TabsList>
                <TabsTrigger value="week">Week</TabsTrigger>
                <TabsTrigger value="month">Month</TabsTrigger>
                <TabsTrigger value="ytd">YTD</TabsTrigger>
              </TabsList>
            </Tabs>
            <Button asChild variant="outline" size="sm">
              <Link to="/settings"><SettingsIcon className="h-4 w-4 mr-1.5" />Tax settings</Link>
            </Button>
          </div>
        </div>

        {/* Hero summary */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <Card className="md:col-span-1">
            <CardContent className="p-5">
              <div className="flex items-center gap-2 mb-1 text-muted-foreground">
                <TrendingUp className="h-4 w-4" />
                <span className="text-xs uppercase tracking-wide">Gross earnings</span>
              </div>
              <p className="text-3xl font-semibold tabular-nums">${gross.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground mt-1">{periodLabel} · {current.jobs} job{current.jobs !== 1 ? "s" : ""}</p>
            </CardContent>
          </Card>
          <Card className="md:col-span-1">
            <CardContent className="p-5">
              <div className="flex items-center gap-2 mb-1 text-muted-foreground">
                <Receipt className="h-4 w-4" />
                <span className="text-xs uppercase tracking-wide">Estimated tax</span>
              </div>
              <p className="text-3xl font-semibold tabular-nums text-muted-foreground">−${totalTax.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground mt-1">SE + Federal + State</p>
            </CardContent>
          </Card>
          <Card className="md:col-span-1 border-primary/40 bg-primary/5">
            <CardContent className="p-5">
              <div className="flex items-center gap-2 mb-1 text-primary">
                <Calculator className="h-4 w-4" />
                <span className="text-xs uppercase tracking-wide">Estimated net</span>
              </div>
              <p className="text-3xl font-semibold tabular-nums">${net.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground mt-1">After estimated taxes</p>
            </CardContent>
          </Card>
        </div>

        {/* Breakdown */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">Earnings breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <BreakdownRow label="Job fees" sub={`${current.jobs} jobs · base $${settings.default_job_fee.toFixed(0)} unless overridden`} value={grossJobs} />
            <BreakdownRow label="Mileage fees billed" sub={`Flat mileage fee per job`} value={grossMileageFees} />
            <Divider />
            <BreakdownRow label="Gross earnings" value={gross} bold />
            <BreakdownRow
              label="Mileage deduction"
              sub={<>{current.miles.toFixed(0)} mi × ${settings.mileage_rate.toFixed(2)}/mi <Badge variant="outline" className="ml-1 text-[10px]"><Car className="h-2.5 w-2.5 mr-1" />IRS standard</Badge></>}
              value={-mileageDeduction}
            />
            <Divider />
            <BreakdownRow label="Taxable estimate" value={taxable} bold muted />
            {useDetailed && (
              <>
                <BreakdownRow label="Self-employment tax" sub={`${(settings.self_employment_tax_rate*100).toFixed(1)}%`} value={-seTax} />
                <BreakdownRow label="Federal tax" sub={`${(settings.federal_tax_rate*100).toFixed(0)}% · ${settings.filing_status.replace("_"," ")}`} value={-fedTax} />
                <BreakdownRow label={`State tax${settings.state_code ? ` (${settings.state_code})` : ""}`} sub={`${(settings.state_tax_rate*100).toFixed(0)}%`} value={-stateTax} />
              </>
            )}
            {!useDetailed && (
              <BreakdownRow label="Combined tax estimate" sub={`${(settings.estimated_tax_rate*100).toFixed(0)}%`} value={-totalTax} />
            )}
            <Divider />
            <BreakdownRow label="Estimated tax owed" value={-totalTax} bold muted />
            <BreakdownRow label="Estimated net" value={net} bold highlight />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2"><Info className="h-4 w-4" />How this is calculated</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground space-y-1">
            <p><span className="text-foreground font-medium">Gross</span> = Job fees + mileage fees billed.</p>
            <p><span className="text-foreground font-medium">Taxable</span> = Gross − mileage deduction (miles × IRS rate).</p>
            <p><span className="text-foreground font-medium">Tax</span> = SE + federal + state, applied to taxable income.</p>
            <p className="text-xs pt-2">Configure rates in <Link to="/settings" className="text-primary underline">Settings</Link>. First-pass estimator only — confirm with a tax professional.</p>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}

function BreakdownRow({
  label, sub, value, bold, highlight, muted,
}: { label: React.ReactNode; sub?: React.ReactNode; value: number; bold?: boolean; highlight?: boolean; muted?: boolean }) {
  return (
    <div className={`flex items-start justify-between py-2 gap-3 ${highlight ? "bg-primary/5 -mx-3 px-3 rounded" : ""}`}>
      <div className="min-w-0">
        <p className={`text-sm ${bold ? "font-semibold" : ""} ${highlight ? "text-primary" : ""}`}>{label}</p>
        {sub && <p className="text-xs text-muted-foreground mt-0.5">{sub}</p>}
      </div>
      <p className={`text-sm tabular-nums ${bold ? "font-semibold" : ""} ${muted ? "text-muted-foreground" : ""} ${highlight ? "text-primary text-base" : ""}`}>
        {value < 0 ? "−" : ""}${Math.abs(value).toFixed(2)}
      </p>
    </div>
  );
}

function Divider() {
  return <div className="border-t my-1" />;
}
