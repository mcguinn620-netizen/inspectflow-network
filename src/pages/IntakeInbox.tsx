import { useEffect, useState } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Input } from "@/components/ui/input";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "@/hooks/use-toast";
import { IntakeReviewScreen } from "@/components/intake/IntakeReviewScreen";
import { Loader2, Mail, MessageSquare, Link2, Upload, Inbox as InboxIcon, RefreshCw } from "lucide-react";
import { formatDistanceToNow } from "date-fns";

type Channel = "gmail" | "outlook" | "telegram" | "web_link" | "manual";
type Status = "new" | "parsing" | "needs_review" | "auto_created" | "converted" | "dismissed" | "error";

interface IntakeItem {
  id: string;
  channel: Channel;
  source_address: string | null;
  subject: string | null;
  raw_text: string | null;
  parsed_data: any | null;
  confidence: number | null;
  status: Status;
  inspection_request_id: string | null;
  error: string | null;
  created_at: string;
}

const channelIcon = (c: Channel) => {
  if (c === "gmail" || c === "outlook") return <Mail className="h-4 w-4" />;
  if (c === "telegram") return <MessageSquare className="h-4 w-4" />;
  if (c === "web_link") return <Link2 className="h-4 w-4" />;
  return <Upload className="h-4 w-4" />;
};

const statusVariant = (s: Status): "default" | "secondary" | "destructive" | "outline" => {
  if (s === "auto_created" || s === "converted") return "default";
  if (s === "needs_review") return "secondary";
  if (s === "error") return "destructive";
  return "outline";
};

export default function IntakeInbox() {
  const [items, setItems] = useState<IntakeItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | Status>("needs_review");
  const [selected, setSelected] = useState<IntakeItem | null>(null);
  const [url, setUrl] = useState("");
  const [fetching, setFetching] = useState(false);

  const load = async () => {
    setLoading(true);
    const q = supabase
      .from("intake_items" as any)
      .select("*")
      .order("created_at", { ascending: false })
      .limit(100);
    const { data, error } = filter === "all" ? await q : await q.eq("status", filter);
    if (error) toast({ title: "Failed to load inbox", description: error.message, variant: "destructive" });
    setItems((data as any) ?? []);
    setLoading(false);
  };

  useEffect(() => { load(); /* eslint-disable-next-line */ }, [filter]);

  useEffect(() => {
    const ch = supabase
      .channel("intake_items_changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "intake_items" }, () => load())
      .subscribe();
    return () => { supabase.removeChannel(ch); };
    // eslint-disable-next-line
  }, [filter]);

  const handleFetchUrl = async () => {
    if (!url.trim()) return;
    setFetching(true);
    try {
      const { data, error } = await supabase.functions.invoke("intake-fetch-url", { body: { url: url.trim() } });
      if (error) throw error;
      if (data?.error) throw new Error(data.error);
      toast({ title: data?.duplicate ? "Already ingested" : "URL queued", description: "Parsing in background." });
      setUrl("");
      load();
    } catch (e: any) {
      toast({ title: "Fetch failed", description: e.message, variant: "destructive" });
    } finally { setFetching(false); }
  };

  const handleConvert = async (data: any) => {
    if (!selected) return;
    try {
      const { data: ins, error } = await supabase
        .from("inspection_requests")
        .insert({
          client_name: data.client_name, company_name: data.company_name,
          vin: data.vin, vehicle_year: data.vehicle_year, vehicle_make: data.vehicle_make,
          vehicle_model: data.vehicle_model, mileage: data.mileage,
          inspection_location: data.inspection_location, requested_date: data.requested_date,
          inspection_type: data.inspection_type, template_name: data.template_name,
          priority: data.priority, status: "request_received", notes: data.notes,
        })
        .select("id").single();
      if (error) throw error;
      await supabase
        .from("intake_items" as any)
        .update({ status: "converted", inspection_request_id: ins.id, parsed_data: data })
        .eq("id", selected.id);
      toast({ title: "Inspection created" });
      setSelected(null);
      load();
    } catch (e: any) {
      toast({ title: "Convert failed", description: e.message, variant: "destructive" });
    }
  };

  const handleDismiss = async (item: IntakeItem) => {
    await supabase.from("intake_items" as any).update({ status: "dismissed" }).eq("id", item.id);
    load();
  };

  return (
    <DashboardLayout>
      <div className="container max-w-5xl py-6 space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <InboxIcon className="h-6 w-6" />
            <h1 className="text-2xl font-semibold">Intake Inbox</h1>
          </div>
          <Button variant="outline" size="sm" onClick={load} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>

        <Card>
          <CardContent className="pt-4 space-y-2">
            <p className="text-sm font-medium">Add by URL</p>
            <div className="flex gap-2">
              <Input
                placeholder="https://auction-site.com/listing/123"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") handleFetchUrl(); }}
              />
              <Button onClick={handleFetchUrl} disabled={fetching || !url.trim()}>
                {fetching ? <Loader2 className="h-4 w-4 animate-spin" /> : "Fetch"}
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Pasted URLs are fetched server-side, parsed by AI, and added to the inbox below.
            </p>
          </CardContent>
        </Card>

        <Tabs value={filter} onValueChange={(v) => setFilter(v as any)}>
          <TabsList>
            <TabsTrigger value="needs_review">Needs review</TabsTrigger>
            <TabsTrigger value="auto_created">Auto-created</TabsTrigger>
            <TabsTrigger value="converted">Converted</TabsTrigger>
            <TabsTrigger value="error">Errors</TabsTrigger>
            <TabsTrigger value="all">All</TabsTrigger>
          </TabsList>
        </Tabs>

        <div className="space-y-2">
          {loading && <div className="flex justify-center py-8"><Loader2 className="h-6 w-6 animate-spin text-muted-foreground" /></div>}
          {!loading && items.length === 0 && (
            <Card><CardContent className="py-10 text-center text-sm text-muted-foreground">
              No items in this view.
            </CardContent></Card>
          )}
          {items.map((item) => (
            <Card key={item.id} className="hover:bg-accent/40 transition-colors">
              <CardContent className="py-3 flex items-center gap-3">
                <div className="text-muted-foreground">{channelIcon(item.channel)}</div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="font-medium truncate">{item.subject ?? item.parsed_data?.vin ?? "(no subject)"}</p>
                    <Badge variant={statusVariant(item.status)} className="text-[10px] uppercase">{item.status.replace("_", " ")}</Badge>
                    {item.confidence != null && (
                      <span className={`text-xs ${item.confidence >= 0.85 ? "text-emerald-600" : "text-amber-600"}`}>
                        {(item.confidence * 100).toFixed(0)}%
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground truncate">
                    {item.channel} · {item.source_address ?? "—"} · {formatDistanceToNow(new Date(item.created_at), { addSuffix: true })}
                  </p>
                </div>
                <div className="flex gap-1">
                  <Button size="sm" variant="outline" onClick={() => setSelected(item)}>Review</Button>
                  {item.status !== "dismissed" && item.status !== "converted" && (
                    <Button size="sm" variant="ghost" onClick={() => handleDismiss(item)}>Dismiss</Button>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <Dialog open={!!selected} onOpenChange={(v) => !v && setSelected(null)}>
          <DialogContent className="max-w-5xl max-h-[90vh] overflow-y-auto">
            <DialogHeader><DialogTitle>Review intake item</DialogTitle></DialogHeader>
            {selected && (
              <IntakeReviewScreen
                originalText={selected.raw_text ?? ""}
                parsedData={selected.parsed_data ?? {
                  client_name: null, company_name: null, vin: null,
                  vehicle_year: null, vehicle_make: null, vehicle_model: null,
                  mileage: null, inspection_location: null, requested_date: null,
                  inspection_type: null, template_name: "Standard Inspection",
                  priority: "medium", vin_valid: false, notes: null,
                }}
                onSave={handleConvert}
                onBack={() => setSelected(null)}
              />
            )}
          </DialogContent>
        </Dialog>
      </div>
    </DashboardLayout>
  );
}
