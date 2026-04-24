import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import {
  Info, Settings as SettingsIcon, TrendingUp, Receipt, Car, Calculator,
  Calendar, Download, ChevronDown, AlertCircle,
} from "lucide-react";
import { calculateTax, buildQuarterlyEstimates, type PeriodIncome } from "@/lib/taxCalculator";
import type { FilingStatus } from "@/data/federalTaxTables";
import { quarterOf } from "@/data/federalTaxTables";
import { STATE_TAX_2025 } from "@/data/stateTaxTables";
import { toCsv, downloadCsv } from "@/platform/export";
import { toast } from "sonner";

interface Settings {
  default_job_fee: number;
  default_mileage_fee: number;
  mileage_rate: number;
  state_code: string | null;
  filing_status: FilingStatus;
}

const DEFAULTS: Settings = {
  default_job_fee: 75,
  default_mileage_fee: 0,
  mileage_rate: 0.67,
  state_code: null,
  filing_status: "single",
};

interface JobRow {
  fee_override: number | null;
  mileage_fee: number | null;
  actual_end_time: string | null;
  customer_name: string | null;
}
interface TripRow {
  trip_date: string;
  total_miles: number | null;
}

export default function InspectorTax() {
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();
  const [settings, setSettings] = useState<Settings>(DEFAULTS);
  const [period, setPeriod] = useState<"week" | "month" | "ytd">("week");
  const [jobs, setJobs] = useState<JobRow[]>([]);
  const [trips, setTrips] = useState<TripRow[]>([]);
  const [breakdownOpen, setBreakdownOpen] = useState(false);

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: s } = await supabase.from("earnings_settings").select("*").eq("user_id", user.id).maybeSingle();
    setSettings(s ? {
      default_job_fee: Number(s.default_job_fee),
      default_mileage_fee: Number((s as any).default_mileage_fee ?? 0),
      mileage_rate: Number(s.mileage_rate),
      state_code: (s as any).state_code ?? null,
      filing_status: ((s as any).filing_status ?? "single") as FilingStatus,
    } : DEFAULTS);

    const yearStart = new Date(new Date().getFullYear(), 0, 1);
    const [{ data: jobsData }, { data: tripsData }] = await Promise.all([
      supabase.from("jobs")
        .select("fee_override,mileage_fee,actual_end_time,customer_name")
        .eq("organization_id", activeOrgId).eq("status", "completed")
        .gte("actual_end_time", yearStart.toISOString()),
      supabase.from("trips").select("trip_date,total_miles")
        .eq("user_id", user.id).gte("trip_date", yearStart.toISOString().slice(0, 10)),
    ]);
    setJobs((jobsData ?? []) as JobRow[]);
    setTrips((tripsData ?? []) as TripRow[]);
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const cfg = settings;
  const incomeForJobs = (rows: JobRow[]): PeriodIncome => {
    const gross = rows.reduce((sum, j) => sum + Number(j.fee_override ?? cfg.default_job_fee) + Number(j.mileage_fee ?? cfg.default_mileage_fee), 0);
    return { gross, deductions: 0 };
  };

  const milesIn = (rows: TripRow[]) => rows.reduce((s, t) => s + Number(t.total_miles || 0), 0);

  // Build period income (gross + mileage deduction)
  const { current, currentLabel, currentMiles, currentJobCount } = useMemo(() => {
    const now = new Date();
    const weekAgo = new Date(); weekAgo.setDate(now.getDate() - 7);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const yearStart = new Date(now.getFullYear(), 0, 1);

    const range = period === "week" ? weekAgo : period === "month" ? monthStart : yearStart;
    const label = period === "week" ? "Past 7 days" : period === "month" ? "Month-to-date" : "Year-to-date";

    const jr = jobs.filter((j) => j.actual_end_time && new Date(j.actual_end_time) >= range);
    const tr = trips.filter((t) => new Date(t.trip_date) >= range);
    const income = incomeForJobs(jr);
    const miles = milesIn(tr);
    income.deductions = miles * cfg.mileage_rate;
    return { current: income, currentLabel: label, currentMiles: miles, currentJobCount: jr.length };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [jobs, trips, period, cfg.mileage_rate, cfg.default_job_fee, cfg.default_mileage_fee]);

  // Year fraction for the active period (used to annualize for bracket lookup)
  const yearFraction = useMemo(() => {
    const now = new Date();
    const yearStart = new Date(now.getFullYear(), 0, 1);
    const yearEnd = new Date(now.getFullYear() + 1, 0, 1);
    const yearMs = yearEnd.getTime() - yearStart.getTime();
    if (period === "week") return 7 * 86400000 / yearMs;
    if (period === "month") return (now.getTime() - new Date(now.getFullYear(), now.getMonth(), 1).getTime()) / yearMs;
    // ytd
    return (now.getTime() - yearStart.getTime()) / yearMs;
  }, [period]);

  const breakdown = useMemo(
    () => calculateTax(current, cfg.filing_status, cfg.state_code, Math.max(yearFraction, 0.001)),
    [current, cfg.filing_status, cfg.state_code, yearFraction],
  );

  // Quarterly breakdown — bucket YTD jobs/trips by IRS quarter
  const year = new Date().getFullYear();
  const quarterly = useMemo(() => {
    const perQ: Record<1 | 2 | 3 | 4, PeriodIncome> = {
      1: { gross: 0, deductions: 0 },
      2: { gross: 0, deductions: 0 },
      3: { gross: 0, deductions: 0 },
      4: { gross: 0, deductions: 0 },
    };
    jobs.forEach((j) => {
      if (!j.actual_end_time) return;
      const d = new Date(j.actual_end_time);
      if (d.getFullYear() !== year) return;
      const q = quarterOf(d);
      perQ[q].gross += Number(j.fee_override ?? cfg.default_job_fee) + Number(j.mileage_fee ?? cfg.default_mileage_fee);
    });
    trips.forEach((t) => {
      const d = new Date(t.trip_date);
      if (d.getFullYear() !== year) return;
      const q = quarterOf(d);
      perQ[q].deductions += Number(t.total_miles || 0) * cfg.mileage_rate;
    });
    return buildQuarterlyEstimates(year, perQ, cfg.filing_status, cfg.state_code);
  }, [jobs, trips, year, cfg]);

  const stateName = cfg.state_code ? STATE_TAX_2025[cfg.state_code]?.name : null;
  const stateHasTax = cfg.state_code ? STATE_TAX_2025[cfg.state_code]?.type !== "none" : false;

  // 1099-style export: per customer YTD totals
  const handleExport1099 = () => {
    const byCustomer = new Map<string, { jobs: number; gross: number }>();
    jobs.forEach((j) => {
      const name = (j.customer_name || "Unknown").trim();
      const cur = byCustomer.get(name) ?? { jobs: 0, gross: 0 };
      cur.jobs += 1;
      cur.gross += Number(j.fee_override ?? cfg.default_job_fee) + Number(j.mileage_fee ?? cfg.default_mileage_fee);
      byCustomer.set(name, cur);
    });
    const rows = Array.from(byCustomer.entries())
      .sort((a, b) => b[1].gross - a[1].gross)
      .map(([name, v]) => ({ customer: name, jobs: v.jobs, gross: v.gross.toFixed(2) }));
    if (!rows.length) {
      toast.info("No completed jobs to export this year.");
      return;
    }
    downloadCsv(`1099-summary-${year}.csv`, toCsv(rows, ["customer", "jobs", "gross"]));
    toast.success(`Exported ${rows.length} customer rows`);
  };

  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div className="flex items-start justify-between flex-wrap gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Tax &amp; Earnings</h1>
            <p className="text-sm text-muted-foreground mt-1">
              {year} estimates using federal brackets &amp; SE tax
              {stateName && <> · State: <span className="font-medium text-foreground">{stateName}</span>{!stateHasTax && " (no income tax)"}</>}
            </p>
          </div>
          <div className="flex gap-2 flex-wrap">
            <Tabs value={period} onValueChange={(v) => setPeriod(v as any)}>
              <TabsList>
                <TabsTrigger value="week">Week</TabsTrigger>
                <TabsTrigger value="month">Month</TabsTrigger>
                <TabsTrigger value="ytd">YTD</TabsTrigger>
              </TabsList>
            </Tabs>
            <Button variant="outline" size="sm" onClick={handleExport1099}>
              <Download className="h-4 w-4 mr-1.5" />1099 export
            </Button>
            <Button asChild variant="outline" size="sm">
              <Link to="/settings"><SettingsIcon className="h-4 w-4 mr-1.5" />Tax settings</Link>
            </Button>
          </div>
        </div>

        {/* Hero summary */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <Card>
            <CardContent className="p-5">
              <div className="flex items-center gap-2 mb-1 text-muted-foreground">
                <TrendingUp className="h-4 w-4" />
                <span className="text-xs uppercase tracking-wide">Gross earnings</span>
              </div>
              <p className="text-3xl font-semibold tabular-nums">${breakdown.gross.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground mt-1">{currentLabel} · {currentJobCount} job{currentJobCount !== 1 ? "s" : ""}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-5">
              <div className="flex items-center gap-2 mb-1 text-muted-foreground">
                <Receipt className="h-4 w-4" />
                <span className="text-xs uppercase tracking-wide">Estimated tax</span>
              </div>
              <p className="text-3xl font-semibold tabular-nums text-muted-foreground">−${breakdown.totalTax.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground mt-1">SE + Federal{stateHasTax ? " + State" : ""} · {(breakdown.effectiveRate * 100).toFixed(1)}% effective</p>
            </CardContent>
          </Card>
          <Card className="border-primary/40 bg-primary/5">
            <CardContent className="p-5">
              <div className="flex items-center gap-2 mb-1 text-primary">
                <Calculator className="h-4 w-4" />
                <span className="text-xs uppercase tracking-wide">Estimated net</span>
              </div>
              <p className="text-3xl font-semibold tabular-nums">${breakdown.net.toFixed(0)}</p>
              <p className="text-xs text-muted-foreground mt-1">After estimated taxes</p>
            </CardContent>
          </Card>
        </div>

        {/* Quarterly breakdown */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <Calendar className="h-4 w-4" />
              Quarterly estimated tax · {year}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {quarterly.map((q) => (
                <QuarterCard key={q.q} quarter={q} />
              ))}
            </div>
            <p className="text-xs text-muted-foreground mt-3 flex items-start gap-1.5">
              <AlertCircle className="h-3.5 w-3.5 mt-0.5 shrink-0" />
              Each quarter shows income earned, mileage deductions, and estimated tax to set aside. Federal due dates: Apr 15, Jun 15, Sep 15, Jan 15.
            </p>
          </CardContent>
        </Card>

        {/* Expandable detailed breakdown */}
        <Card>
          <Collapsible open={breakdownOpen} onOpenChange={setBreakdownOpen}>
            <CollapsibleTrigger asChild>
              <button className="w-full text-left">
                <CardHeader className="pb-3 flex-row items-center justify-between space-y-0">
                  <CardTitle className="text-base">Tax breakdown · {currentLabel}</CardTitle>
                  <ChevronDown className={`h-4 w-4 text-muted-foreground transition-transform ${breakdownOpen ? "rotate-180" : ""}`} />
                </CardHeader>
              </button>
            </CollapsibleTrigger>
            <CollapsibleContent>
              <CardContent>
                <BreakdownRow label="Gross earnings" sub={`${currentJobCount} jobs`} value={breakdown.gross} bold />
                <BreakdownRow
                  label="Mileage deduction"
                  sub={<>{currentMiles.toFixed(0)} mi × ${cfg.mileage_rate.toFixed(2)}/mi <Badge variant="outline" className="ml-1 text-[10px]"><Car className="h-2.5 w-2.5 mr-1" />IRS standard</Badge></>}
                  value={-breakdown.deductions}
                />
                <Divider />
                <BreakdownRow label="Net self-employment income" value={breakdown.netSelfEmployment} bold muted />
                <BreakdownRow label="Self-employment tax" sub="15.3% (SS + Medicare) on 92.35% of net SE" value={-breakdown.seTax} />
                <BreakdownRow label="½ SE tax deduction" sub="Above-the-line adjustment" value={-breakdown.seDeduction} muted />
                <BreakdownRow label="Standard deduction" sub={cfg.filing_status.replace("_", " ")} value={-breakdown.standardDeduction} muted />
                <Divider />
                <BreakdownRow label="Federal taxable income" value={breakdown.taxableFederal} muted />
                <BreakdownRow label="Federal income tax" sub="2025 progressive brackets" value={-breakdown.federalTax} />
                {stateHasTax && (
                  <>
                    <BreakdownRow label={`${stateName} taxable income`} value={breakdown.taxableState} muted />
                    <BreakdownRow label={`${stateName} state tax`} sub="2025 state brackets" value={-breakdown.stateTax} />
                  </>
                )}
                <Divider />
                <BreakdownRow label="Total estimated tax" value={-breakdown.totalTax} bold muted />
                <BreakdownRow label="Estimated net" value={breakdown.net} bold highlight />
              </CardContent>
            </CollapsibleContent>
          </Collapsible>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2"><Info className="h-4 w-4" />How this is calculated</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground space-y-1">
            <p><span className="text-foreground font-medium">Gross</span> = job fees + mileage fees billed.</p>
            <p><span className="text-foreground font-medium">Net SE</span> = Gross − mileage deduction (miles × IRS rate).</p>
            <p><span className="text-foreground font-medium">SE tax</span> = 15.3% on 92.35% of net SE (capped SS portion at $176,100).</p>
            <p><span className="text-foreground font-medium">Federal</span> = 2025 progressive brackets applied to (Net SE − ½ SE − standard deduction), annualized.</p>
            {stateHasTax && <p><span className="text-foreground font-medium">State</span> = {stateName} 2025 brackets applied to (Net SE − ½ SE − state std deduction).</p>}
            <p className="text-xs pt-2">Estimates only — confirm with a tax professional before filing or paying quarterly estimates.</p>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}

function QuarterCard({ quarter }: { quarter: ReturnType<typeof buildQuarterlyEstimates>[number] }) {
  const dueLabel = quarter.dueDate.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  const net = quarter.income - quarter.deductions;
  return (
    <div
      className={`rounded-md border p-3 ${
        quarter.isNext
          ? "border-primary/50 bg-primary/5"
          : quarter.isPast
          ? "bg-muted/30"
          : ""
      }`}
    >
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-semibold">{quarter.label}</span>
        {quarter.isNext && <Badge className="text-[10px] h-5 px-1.5">Next</Badge>}
        {quarter.isPast && !quarter.isNext && <Badge variant="outline" className="text-[10px] h-5 px-1.5">Past</Badge>}
      </div>
      <div className="space-y-1 text-xs">
        <div className="flex justify-between">
          <span className="text-muted-foreground">Income</span>
          <span className="tabular-nums font-medium">${quarter.income.toFixed(0)}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-muted-foreground">Deductions</span>
          <span className="tabular-nums text-muted-foreground">−${quarter.deductions.toFixed(0)}</span>
        </div>
        <div className="flex justify-between border-t pt-1 mt-1">
          <span className="text-muted-foreground">Net</span>
          <span className="tabular-nums">${net.toFixed(0)}</span>
        </div>
        <div className="flex justify-between pt-1 mt-1 border-t border-primary/20">
          <span className="font-medium">Set aside</span>
          <span className="tabular-nums font-semibold text-primary">${quarter.estimatedTax.toFixed(0)}</span>
        </div>
      </div>
      <p className="text-[10px] text-muted-foreground mt-2">Due {dueLabel}</p>
    </div>
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
