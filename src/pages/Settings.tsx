import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Badge } from "@/components/ui/badge";
import { useTheme } from "next-themes";
import { Monitor, Moon, Sun, Plus, Trash2, Star, LogOut, Calendar, Copy, RefreshCw, Navigation, ChevronDown } from "lucide-react";
import { getProvider as getMapProvider, setProvider as setMapProvider, PROVIDER_LABELS, type MapProvider } from "@/platform/maps";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";
import { toast } from "sonner";
import { useNavigate } from "react-router-dom";

const US_STATES = [
  "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA",
  "ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK",
  "OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY",
];

interface EarningsSettings {
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

interface InspectorVehicle {
  id: string;
  nickname: string;
  year: string | null;
  make: string | null;
  model: string | null;
  license_plate: string | null;
  is_default: boolean;
}

const DEFAULT_SETTINGS: EarningsSettings = {
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

export default function SettingsPage() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const { user, signOut } = useAuth();
  const { activeOrgId } = useUserRoles();
  const navigate = useNavigate();

  const [settings, setSettings] = useState<EarningsSettings>(DEFAULT_SETTINGS);
  const [savingSettings, setSavingSettings] = useState(false);
  const [vehicles, setVehicles] = useState<InspectorVehicle[]>([]);
  const [vForm, setVForm] = useState<Partial<InspectorVehicle>>({ nickname: "" });
  const [feedToken, setFeedToken] = useState<string | null>(null);
  const [feedBusy, setFeedBusy] = useState(false);
  const [mapProvider, setMapProviderState] = useState<MapProvider>("auto");
  useEffect(() => { setMapProviderState(getMapProvider()); }, []);

  const feedUrl = feedToken
    ? `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/calendar-feed?token=${feedToken}`
    : null;
  const webcalUrl = feedUrl ? feedUrl.replace(/^https?:\/\//, "webcal://") : null;

  const load = async () => {
    if (!user || !activeOrgId) return;
    const { data: s } = await supabase.from("earnings_settings")
      .select("*").eq("user_id", user.id).maybeSingle();
    if (s) {
      setSettings({
        default_job_fee: Number(s.default_job_fee),
        default_mileage_fee: Number((s as any).default_mileage_fee ?? 0),
        mileage_rate: Number(s.mileage_rate),
        estimated_tax_rate: Number(s.estimated_tax_rate),
        federal_tax_rate: Number((s as any).federal_tax_rate ?? 0.15),
        state_tax_rate: Number((s as any).state_tax_rate ?? 0.05),
        self_employment_tax_rate: Number((s as any).self_employment_tax_rate ?? 0.153),
        state_code: (s as any).state_code ?? null,
        filing_status: (s as any).filing_status ?? "single",
      });
    }
    const { data: v } = await supabase.from("inspector_vehicles" as any)
      .select("*").eq("user_id", user.id).eq("is_archived", false)
      .order("is_default", { ascending: false }).order("created_at");
    setVehicles((v ?? []) as any);

    const { data: prof } = await supabase.from("profiles")
      .select("calendar_feed_token").eq("id", user.id).maybeSingle();
    setFeedToken((prof as { calendar_feed_token?: string | null } | null)?.calendar_feed_token ?? null);
  };

  const generateFeedToken = async () => {
    if (!user) return;
    setFeedBusy(true);
    // 32 random bytes → URL-safe hex
    const buf = new Uint8Array(24);
    crypto.getRandomValues(buf);
    const token = Array.from(buf, b => b.toString(16).padStart(2, "0")).join("");
    const { error } = await supabase.from("profiles")
      .update({ calendar_feed_token: token }).eq("id", user.id);
    setFeedBusy(false);
    if (error) return toast.error(error.message);
    setFeedToken(token);
    toast.success("Calendar feed enabled");
  };

  const revokeFeedToken = async () => {
    if (!user) return;
    setFeedBusy(true);
    const { error } = await supabase.from("profiles")
      .update({ calendar_feed_token: null }).eq("id", user.id);
    setFeedBusy(false);
    if (error) return toast.error(error.message);
    setFeedToken(null);
    toast.success("Calendar feed disabled");
  };

  const copyFeedUrl = async () => {
    if (!feedUrl) return;
    try {
      await navigator.clipboard.writeText(feedUrl);
      toast.success("Calendar URL copied");
    } catch {
      toast.error("Could not copy — long-press to select");
    }
  };

  useEffect(() => { load(); /* eslint-disable-next-line */ }, [user, activeOrgId]);

  const saveSettings = async () => {
    if (!user || !activeOrgId) return;
    setSavingSettings(true);
    const { error } = await supabase.from("earnings_settings").upsert({
      organization_id: activeOrgId, user_id: user.id,
      ...settings,
    } as any, { onConflict: "organization_id,user_id" });
    setSavingSettings(false);
    if (error) return toast.error(error.message);
    toast.success("Settings saved");
  };

  const addVehicle = async () => {
    if (!user || !activeOrgId || !vForm.nickname) return toast.error("Nickname required");
    const { error } = await supabase.from("inspector_vehicles" as any).insert({
      user_id: user.id, organization_id: activeOrgId,
      nickname: vForm.nickname,
      year: vForm.year || null, make: vForm.make || null, model: vForm.model || null,
      license_plate: vForm.license_plate || null,
      is_default: vehicles.length === 0,
    });
    if (error) return toast.error(error.message);
    setVForm({ nickname: "" });
    load();
  };

  const setDefaultVehicle = async (id: string) => {
    if (!user) return;
    await supabase.from("inspector_vehicles" as any).update({ is_default: false }).eq("user_id", user.id);
    await supabase.from("inspector_vehicles" as any).update({ is_default: true }).eq("id", id);
    load();
  };

  const removeVehicle = async (id: string) => {
    await supabase.from("inspector_vehicles" as any).update({ is_archived: true }).eq("id", id);
    load();
  };

  const handleLogout = async () => {
    await signOut();
    toast.success("Signed out");
    navigate("/auth", { replace: true });
  };

  return (
    <DashboardLayout>
      <div className="space-y-6 max-w-4xl">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Settings</h1>
          <p className="text-sm text-muted-foreground mt-1">Platform configuration and preferences</p>
        </div>

        {/* Appearance */}
        <Card>
          <CardHeader>
            <CardTitle>Appearance</CardTitle>
            <CardDescription>Choose how the interface looks. Sync with your system or pick a fixed theme.</CardDescription>
          </CardHeader>
          <CardContent>
            {mounted && (
              <RadioGroup value={theme ?? "system"} onValueChange={setTheme}
                className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <ThemeOption value="light" icon={<Sun className="h-5 w-5" />} label="Light" />
                <ThemeOption value="dark" icon={<Moon className="h-5 w-5" />} label="Dark" />
                <ThemeOption value="system" icon={<Monitor className="h-5 w-5" />} label="System" />
              </RadioGroup>
            )}
          </CardContent>
        </Card>

        {/* Earnings & Fees */}
        <Card>
          <CardHeader>
            <CardTitle>Earnings &amp; Fees</CardTitle>
            <CardDescription>
              Default fees used when creating new jobs. Each job can override these.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid md:grid-cols-3 gap-3">
              <div className="space-y-1.5">
                <Label>Base inspection fee ($)</Label>
                <Input type="number" step="0.01" value={settings.default_job_fee}
                  onChange={(e) => setSettings({ ...settings, default_job_fee: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">Default per-job fee.</p>
              </div>
              <div className="space-y-1.5">
                <Label>Default mileage fee ($)</Label>
                <Input type="number" step="0.01" value={settings.default_mileage_fee}
                  onChange={(e) => setSettings({ ...settings, default_mileage_fee: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">Flat mileage fee added to a job.</p>
              </div>
              <div className="space-y-1.5">
                <Label>Mileage reimbursement ($/mi)</Label>
                <Input type="number" step="0.01" value={settings.mileage_rate}
                  onChange={(e) => setSettings({ ...settings, mileage_rate: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">Per-mile rate for tax estimates (IRS standard ≈ $0.67).</p>
              </div>
            </div>
            <Button onClick={saveSettings} disabled={savingSettings}>
              {savingSettings ? "Saving..." : "Save earnings settings"}
            </Button>
          </CardContent>
        </Card>

        {/* Tax Settings */}
        <Card>
          <CardHeader>
            <CardTitle>Tax Settings</CardTitle>
            <CardDescription>Used by the Tax / Earnings estimator. First-pass estimate only — confirm with a tax professional.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid md:grid-cols-3 gap-3">
              <div className="space-y-1.5">
                <Label>State</Label>
                <Select value={settings.state_code ?? "none"} onValueChange={(v) => setSettings({ ...settings, state_code: v === "none" ? null : v })}>
                  <SelectTrigger><SelectValue placeholder="Select state" /></SelectTrigger>
                  <SelectContent className="max-h-72">
                    <SelectItem value="none">— Not set —</SelectItem>
                    {US_STATES.map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>Filing status</Label>
                <Select value={settings.filing_status} onValueChange={(v) => setSettings({ ...settings, filing_status: v })}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="single">Single</SelectItem>
                    <SelectItem value="married_joint">Married, joint</SelectItem>
                    <SelectItem value="married_separate">Married, separate</SelectItem>
                    <SelectItem value="head_of_household">Head of household</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>Self-employment tax (0–1)</Label>
                <Input type="number" step="0.001" value={settings.self_employment_tax_rate}
                  onChange={(e) => setSettings({ ...settings, self_employment_tax_rate: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">e.g. 0.153 for 15.3%</p>
              </div>
            </div>
            <div className="grid md:grid-cols-3 gap-3">
              <div className="space-y-1.5">
                <Label>Federal tax rate (0–1)</Label>
                <Input type="number" step="0.01" value={settings.federal_tax_rate}
                  onChange={(e) => setSettings({ ...settings, federal_tax_rate: Number(e.target.value) })} />
              </div>
              <div className="space-y-1.5">
                <Label>State tax rate (0–1)</Label>
                <Input type="number" step="0.01" value={settings.state_tax_rate}
                  onChange={(e) => setSettings({ ...settings, state_tax_rate: Number(e.target.value) })} />
              </div>
              <div className="space-y-1.5">
                <Label>Combined estimate fallback (0–1)</Label>
                <Input type="number" step="0.01" value={settings.estimated_tax_rate}
                  onChange={(e) => setSettings({ ...settings, estimated_tax_rate: Number(e.target.value) })} />
                <p className="text-xs text-muted-foreground">Used if detailed rates aren't set.</p>
              </div>
            </div>
            <Button onClick={saveSettings} disabled={savingSettings}>
              {savingSettings ? "Saving..." : "Save tax settings"}
            </Button>
          </CardContent>
        </Card>

        {/* Calendar Sync */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Calendar className="h-5 w-5" />Calendar Sync
            </CardTitle>
            <CardDescription>
              Subscribe to a live, read-only feed of your upcoming jobs in Apple Calendar, Google Calendar, or Outlook.
              Updates automatically — no manual export needed.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {!feedToken ? (
              <Button onClick={generateFeedToken} disabled={feedBusy}>
                <Calendar className="h-4 w-4 mr-2" />
                {feedBusy ? "Enabling..." : "Enable calendar sync"}
              </Button>
            ) : (
              <>
                <div className="rounded-md border bg-muted/30 p-3 space-y-2">
                  <Label className="text-xs uppercase tracking-wide text-muted-foreground">Subscription URL</Label>
                  <Input readOnly value={webcalUrl ?? ""} className="font-mono text-xs" onFocus={(e) => e.currentTarget.select()} />
                  <p className="text-xs text-muted-foreground">
                    On iPhone: tap the link to subscribe. On Google Calendar: <em>Settings → Add calendar → From URL</em>.
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button size="sm" variant="outline" onClick={copyFeedUrl}>
                    <Copy className="h-3.5 w-3.5 mr-1.5" />Copy URL
                  </Button>
                  <Button size="sm" variant="outline" onClick={generateFeedToken} disabled={feedBusy}>
                    <RefreshCw className="h-3.5 w-3.5 mr-1.5" />Rotate token
                  </Button>
                  <Button size="sm" variant="ghost" onClick={revokeFeedToken} disabled={feedBusy}>
                    <Trash2 className="h-3.5 w-3.5 mr-1.5" />Disable
                  </Button>
                </div>
              </>
            )}
          </CardContent>
        </Card>

        {/* Maps & Navigation provider preference (Phase 7C) */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Navigation className="h-5 w-5" />Maps & Navigation
            </CardTitle>
            <CardDescription>
              Choose which maps app the "Navigate" button hands off to. On mobile, the device will open the installed app automatically.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <Label>Preferred maps app</Label>
            <Select
              value={mapProvider}
              onValueChange={(v) => { setMapProvider(v as MapProvider); setMapProviderState(v as MapProvider); toast.success("Map preference saved"); }}
            >
              <SelectTrigger className="max-w-sm"><SelectValue /></SelectTrigger>
              <SelectContent>
                {(["auto","apple","google","waze"] as MapProvider[]).map(p => (
                  <SelectItem key={p} value={p}>{PROVIDER_LABELS[p]}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              Automatic uses Apple Maps on Apple devices and Google Maps elsewhere. You can also choose per-stop from the dropdown next to each "Navigate" button.
            </p>
          </CardContent>
        </Card>

        {/* Inspector Vehicles */}
        <Card>
          <CardHeader>
            <CardTitle>My Vehicles</CardTitle>
            <CardDescription>
              Personal/business vehicles you use for inspector work. Trips can be linked to a vehicle for filing records.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-2">
              {vehicles.length === 0 && (
                <p className="text-sm text-muted-foreground">No vehicles yet. Add one below.</p>
              )}
              {vehicles.map((v) => (
                <div key={v.id} className="flex items-center justify-between rounded-md border p-3 gap-3 flex-wrap">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="font-medium text-sm">{v.nickname}</p>
                      {v.is_default && <Badge variant="outline" className="text-xs"><Star className="h-3 w-3 mr-1" />Default</Badge>}
                    </div>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {[v.year, v.make, v.model].filter(Boolean).join(" ") || "—"}
                      {v.license_plate && <> · Plate {v.license_plate}</>}
                    </p>
                  </div>
                  <div className="flex items-center gap-1">
                    {!v.is_default && (
                      <Button size="sm" variant="outline" onClick={() => setDefaultVehicle(v.id)}>
                        <Star className="h-3.5 w-3.5 mr-1" />Make default
                      </Button>
                    )}
                    <Button size="icon" variant="ghost" onClick={() => removeVehicle(v.id)}>
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>

            <div className="rounded-md border p-3 space-y-2 bg-muted/30">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Add vehicle</p>
              <div className="grid grid-cols-2 md:grid-cols-5 gap-2">
                <Input placeholder="Nickname *" value={vForm.nickname ?? ""} onChange={(e) => setVForm({ ...vForm, nickname: e.target.value })} />
                <Input placeholder="Year" value={vForm.year ?? ""} onChange={(e) => setVForm({ ...vForm, year: e.target.value })} />
                <Input placeholder="Make" value={vForm.make ?? ""} onChange={(e) => setVForm({ ...vForm, make: e.target.value })} />
                <Input placeholder="Model" value={vForm.model ?? ""} onChange={(e) => setVForm({ ...vForm, model: e.target.value })} />
                <Input placeholder="Plate (optional)" value={vForm.license_plate ?? ""} onChange={(e) => setVForm({ ...vForm, license_plate: e.target.value })} />
              </div>
              <Button size="sm" onClick={addVehicle}><Plus className="h-4 w-4 mr-1" />Add vehicle</Button>
            </div>
          </CardContent>
        </Card>

        {/* Account */}
        <Card>
          <CardHeader>
            <CardTitle>Account</CardTitle>
            <CardDescription>Signed in as {user?.email}</CardDescription>
          </CardHeader>
          <CardContent>
            <Button variant="outline" onClick={handleLogout}>
              <LogOut className="h-4 w-4 mr-2" />Sign out
            </Button>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}

function ThemeOption({ value, icon, label }: { value: string; icon: React.ReactNode; label: string }) {
  return (
    <Label htmlFor={`theme-${value}`}
      className="flex items-center gap-3 rounded-lg border bg-card p-4 cursor-pointer hover:border-primary transition-colors [&:has([data-state=checked])]:border-primary [&:has([data-state=checked])]:bg-accent">
      <RadioGroupItem id={`theme-${value}`} value={value} />
      <span className="text-muted-foreground">{icon}</span>
      <span className="font-medium">{label}</span>
    </Label>
  );
}

// Suppress unused warning for Switch (kept for future toggles)
const _keepSwitch = Switch;
void _keepSwitch;
