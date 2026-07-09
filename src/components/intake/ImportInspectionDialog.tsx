import { useState, useCallback } from "react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Upload, FileText, Mail, Image, Link as LinkIcon, Loader2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "@/hooks/use-toast";
import { IntakeReviewScreen } from "./IntakeReviewScreen";
import { AUTH_BYPASS, getMockUser } from "@/lib/authBypass";
import { useAuth } from "@/hooks/useAuth";
import { useUserRoles } from "@/hooks/useUserRoles";

interface ParsedData {
  client_name: string | null;
  company_name: string | null;
  vin: string | null;
  vehicle_year: string | null;
  vehicle_make: string | null;
  vehicle_model: string | null;
  mileage: string | null;
  inspection_location: string | null;
  requested_date: string | null;
  inspection_type: string | null;
  template_name: string;
  priority: string;
  vin_valid: boolean;
  notes: string | null;
}

async function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const s = String(reader.result ?? "");
      resolve(s.includes(",") ? s.slice(s.indexOf(",") + 1) : s);
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

export function ImportInspectionDialog() {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [emailText, setEmailText] = useState("");
  const [url, setUrl] = useState("");
  const [parsedData, setParsedData] = useState<ParsedData | null>(null);
  const [originalText, setOriginalText] = useState("");
  const [dragOver, setDragOver] = useState(false);
  const { user } = useAuth();
  const { activeOrgId } = useUserRoles();

  const resetState = () => {
    setParsedData(null);
    setOriginalText("");
    setEmailText("");
    setUrl("");
    setLoading(false);
  };

  const runParse = async (text: string, type: "email" | "pdf" | "image" | "url") => {
    setLoading(true);
    setOriginalText(text);
    try {
      const { data, error } = await supabase.functions.invoke("parse-inspection", {
        body: { text, source_type: type },
      });
      if (error) throw error;
      if (data.error) throw new Error(data.error);
      setParsedData(data.parsed);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      toast({ title: "Parsing failed", description: msg, variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const handleEmail = () => {
    if (!emailText.trim()) {
      toast({ title: "No content", description: "Paste the email or text first.", variant: "destructive" });
      return;
    }
    runParse(emailText, "email");
  };

  const handleUrl = async () => {
    if (!url.trim()) {
      toast({ title: "No URL", description: "Paste a link first.", variant: "destructive" });
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase.functions.invoke("intake-public", {
        body: { op: "fetch_url", url: url.trim() },
      });
      if (error || data?.error) throw new Error(error?.message ?? data.error);
      await runParse(data.text, "url");
    } catch (e) {
      setLoading(false);
      toast({ title: "Fetch failed", description: e instanceof Error ? e.message : String(e), variant: "destructive" });
    }
  };

  const handleFileUpload = useCallback(async (file: File) => {
    setLoading(true);
    try {
      if (file.type === "text/plain" || file.name.endsWith(".txt") || file.name.endsWith(".eml")) {
        const text = await file.text();
        await runParse(text, "email");
        return;
      }
      if (file.type === "application/pdf") {
        const base64 = await fileToBase64(file);
        const { data, error } = await supabase.functions.invoke("intake-public", {
          body: { op: "parse_pdf", base64 },
        });
        if (error || data?.error) throw new Error(error?.message ?? data.error);
        await runParse(data.text, "pdf");
        return;
      }
      if (file.type.startsWith("image/")) {
        const base64 = await fileToBase64(file);
        const { data, error } = await supabase.functions.invoke("intake-public", {
          body: { op: "parse_image", base64, mime: file.type },
        });
        if (error || data?.error) throw new Error(error?.message ?? data.error);
        setOriginalText(`[Image: ${file.name}]`);
        setParsedData(data.parsed);
        setLoading(false);
        return;
      }
      toast({ title: "Unsupported file", description: "Upload a PDF, image, or text file.", variant: "destructive" });
      setLoading(false);
    } catch (e) {
      setLoading(false);
      toast({ title: "Parsing failed", description: e instanceof Error ? e.message : String(e), variant: "destructive" });
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFileUpload(file);
  }, [handleFileUpload]);

  const handleSaveInspection = async (data: ParsedData) => {
    try {
      const mock = AUTH_BYPASS ? getMockUser() : null;
      const orgId = activeOrgId ?? mock?.org_id ?? null;
      const payload = {
        client_name: data.client_name,
        company_name: data.company_name,
        vin: data.vin,
        vehicle_year: data.vehicle_year,
        vehicle_make: data.vehicle_make,
        vehicle_model: data.vehicle_model,
        mileage: data.mileage,
        inspection_location: data.inspection_location,
        requested_date: data.requested_date,
        inspection_type: data.inspection_type,
        template_name: data.template_name,
        priority: data.priority,
        notes: data.notes,
      };

      // Mock users go through the service-role edge function because they
      // have no Supabase JWT to satisfy RLS on inspection_requests / jobs.
      if (mock) {
        const { data: res, error } = await supabase.functions.invoke("intake-public", {
          body: { op: "create", mock_user_id: mock.id, organization_id: orgId, payload },
        });
        if (error || res?.error) throw new Error(error?.message ?? res.error);
      } else {
        const { error } = await supabase.from("inspection_requests").insert({
          ...payload,
          status: "request_received",
        });
        if (error) throw error;
      }

      toast({ title: "Inspection created", description: "Added to the pipeline." });
      resetState();
      setOpen(false);
    } catch (e) {
      toast({
        title: "Save failed",
        description: e instanceof Error ? e.message : String(e),
        variant: "destructive",
      });
    }
  };

  if (parsedData) {
    return (
      <Dialog open={open} onOpenChange={(v) => { if (!v) resetState(); setOpen(v); }}>
        <DialogTrigger asChild>
          <Button className="gap-2">
            <Upload className="h-4 w-4" />
            Import Inspection
          </Button>
        </DialogTrigger>
        <DialogContent className="max-w-5xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Review Parsed Inspection</DialogTitle>
            <DialogDescription>
              Edit any extracted fields before creating the inspection request.
            </DialogDescription>
          </DialogHeader>
          <IntakeReviewScreen
            originalText={originalText}
            parsedData={parsedData}
            onSave={handleSaveInspection}
            onBack={resetState}
          />
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open={open} onOpenChange={(v) => { if (!v) resetState(); setOpen(v); }}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <Upload className="h-4 w-4" />
          Import Inspection
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Import Inspection Request</DialogTitle>
          <DialogDescription>
            Paste an email, drop a PDF or photo of a request form, or give us a link — AI will extract the details.
          </DialogDescription>
        </DialogHeader>

        <Tabs defaultValue="email" className="mt-2">
          <TabsList className="grid w-full grid-cols-4">
            <TabsTrigger value="email" className="gap-2"><Mail className="h-4 w-4" /> Email</TabsTrigger>
            <TabsTrigger value="pdf" className="gap-2"><FileText className="h-4 w-4" /> PDF</TabsTrigger>
            <TabsTrigger value="image" className="gap-2"><Image className="h-4 w-4" /> Image</TabsTrigger>
            <TabsTrigger value="url" className="gap-2"><LinkIcon className="h-4 w-4" /> Link</TabsTrigger>
          </TabsList>

          <TabsContent value="email" className="space-y-4 mt-4">
            <Textarea
              placeholder="Paste the email, request form, or any text containing inspection details..."
              className="min-h-[200px] font-mono-tech text-sm"
              value={emailText}
              onChange={(e) => setEmailText(e.target.value)}
            />
            <Button onClick={handleEmail} disabled={loading || !emailText.trim()} className="w-full gap-2">
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
              {loading ? "Parsing with AI..." : "Parse Inspection Request"}
            </Button>
          </TabsContent>

          <TabsContent value="pdf" className="mt-4">
            <div
              className={`border-2 border-dashed rounded-lg p-12 text-center transition-colors ${dragOver ? "border-primary bg-primary/5" : "border-border"}`}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
            >
              <FileText className="h-10 w-10 mx-auto text-muted-foreground mb-3" />
              <p className="text-sm font-medium mb-1">Drag & drop a PDF file here</p>
              <p className="text-xs text-muted-foreground mb-4">or click to browse — text is extracted server-side</p>
              <input
                type="file"
                accept=".pdf,.txt,.eml"
                className="hidden"
                id="pdf-upload"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); }}
              />
              <Button variant="outline" onClick={() => document.getElementById("pdf-upload")?.click()} disabled={loading}>
                {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
                {loading ? "Processing..." : "Browse Files"}
              </Button>
            </div>
          </TabsContent>

          <TabsContent value="image" className="mt-4">
            <div
              className={`border-2 border-dashed rounded-lg p-12 text-center transition-colors ${dragOver ? "border-primary bg-primary/5" : "border-border"}`}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
            >
              <Image className="h-10 w-10 mx-auto text-muted-foreground mb-3" />
              <p className="text-sm font-medium mb-1">Upload an inspection form or auction sheet photo</p>
              <p className="text-xs text-muted-foreground mb-4">JPG, PNG, HEIC — OCR runs via AI</p>
              <input
                type="file"
                accept="image/*"
                className="hidden"
                id="image-upload"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); }}
              />
              <Button variant="outline" onClick={() => document.getElementById("image-upload")?.click()} disabled={loading}>
                {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
                {loading ? "Reading image..." : "Browse Images"}
              </Button>
            </div>
          </TabsContent>

          <TabsContent value="url" className="mt-4 space-y-3">
            <Input
              type="url"
              placeholder="https://example.com/inspection-request/1234"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              disabled={loading}
            />
            <p className="text-xs text-muted-foreground">
              We'll fetch the page, extract the text, and let AI pull out the request details.
            </p>
            <Button onClick={handleUrl} disabled={loading || !url.trim()} className="w-full gap-2">
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <LinkIcon className="h-4 w-4" />}
              {loading ? "Fetching..." : "Fetch & Parse"}
            </Button>
          </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
