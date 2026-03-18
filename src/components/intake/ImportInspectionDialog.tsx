import { useState, useCallback } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Upload, FileText, Mail, Image, Loader2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "@/hooks/use-toast";
import { IntakeReviewScreen } from "./IntakeReviewScreen";

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

export function ImportInspectionDialog() {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [emailText, setEmailText] = useState("");
  const [parsedData, setParsedData] = useState<ParsedData | null>(null);
  const [originalText, setOriginalText] = useState("");
  const [sourceType, setSourceType] = useState<"email" | "pdf" | "image">("email");
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [dragOver, setDragOver] = useState(false);

  const resetState = () => {
    setParsedData(null);
    setOriginalText("");
    setEmailText("");
    setUploadedFile(null);
    setLoading(false);
  };

  const handleParse = async (text: string, type: "email" | "pdf" | "image") => {
    if (!text.trim()) {
      toast({ title: "No content", description: "Please provide text or upload a file.", variant: "destructive" });
      return;
    }
    setLoading(true);
    setOriginalText(text);
    setSourceType(type);

    try {
      const { data, error } = await supabase.functions.invoke("parse-inspection", {
        body: { text, source_type: type },
      });
      if (error) throw error;
      if (data.error) throw new Error(data.error);
      setParsedData(data.parsed);
    } catch (e: any) {
      toast({ title: "Parsing failed", description: e.message || "Could not parse the inspection request.", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = useCallback(async (file: File) => {
    setUploadedFile(file);
    const type = file.type.startsWith("image/") ? "image" as const : "pdf" as const;

    // For text-based files, read directly
    if (file.type === "text/plain" || file.name.endsWith(".txt") || file.name.endsWith(".eml")) {
      const text = await file.text();
      await handleParse(text, "email");
      return;
    }

    // For PDF/images, we extract text client-side (basic) and send to AI
    if (file.type === "application/pdf") {
      // Read as text (basic extraction)
      const text = await file.text();
      const cleanText = text.replace(/[^\x20-\x7E\n\r\t]/g, " ").replace(/\s+/g, " ").trim();
      if (cleanText.length > 50) {
        await handleParse(cleanText, type);
      } else {
        toast({ title: "Could not extract text", description: "The PDF may be image-based. Try pasting the text manually.", variant: "destructive" });
      }
      return;
    }

    // For images, inform user to paste text
    if (file.type.startsWith("image/")) {
      toast({ title: "Image uploaded", description: "Please paste the text content from the image in the Email/Text tab for AI parsing." });
      return;
    }

    toast({ title: "Unsupported file", description: "Please upload a PDF, image, or text file.", variant: "destructive" });
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFileUpload(file);
  }, [handleFileUpload]);

  const handleSaveInspection = async (data: ParsedData) => {
    try {
      // Upload source file if present
      let sourceFilePath: string | null = null;
      if (uploadedFile) {
        const fileName = `${Date.now()}-${uploadedFile.name}`;
        const { error: uploadError } = await supabase.storage
          .from("intake-files")
          .upload(fileName, uploadedFile);
        if (!uploadError) sourceFilePath = fileName;
      }

      // Create inspection request
      const { error: insertError } = await supabase
        .from("inspection_requests")
        .insert({
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
          status: "request_received",
          notes: data.notes,
        });
      if (insertError) throw insertError;

      toast({ title: "Inspection created", description: "The inspection request has been added to the pipeline." });
      resetState();
      setOpen(false);
    } catch (e: any) {
      toast({ title: "Save failed", description: e.message, variant: "destructive" });
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
        </DialogHeader>

        <Tabs defaultValue="email" className="mt-2">
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="email" className="gap-2"><Mail className="h-4 w-4" /> Email / Text</TabsTrigger>
            <TabsTrigger value="pdf" className="gap-2"><FileText className="h-4 w-4" /> PDF</TabsTrigger>
            <TabsTrigger value="image" className="gap-2"><Image className="h-4 w-4" /> Image</TabsTrigger>
          </TabsList>

          <TabsContent value="email" className="space-y-4 mt-4">
            <Textarea
              placeholder="Paste the email, request form, or any text containing inspection details..."
              className="min-h-[200px] font-mono-tech text-sm"
              value={emailText}
              onChange={(e) => setEmailText(e.target.value)}
            />
            <Button
              onClick={() => handleParse(emailText, "email")}
              disabled={loading || !emailText.trim()}
              className="w-full gap-2"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
              {loading ? "Parsing with AI..." : "Parse Inspection Request"}
            </Button>
          </TabsContent>

          <TabsContent value="pdf" className="mt-4">
            <div
              className={`border-2 border-dashed rounded-lg p-12 text-center transition-colors ${
                dragOver ? "border-primary bg-primary/5" : "border-border"
              }`}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
            >
              <FileText className="h-10 w-10 mx-auto text-muted-foreground mb-3" />
              <p className="text-sm font-medium mb-1">Drag & drop a PDF file here</p>
              <p className="text-xs text-muted-foreground mb-4">or click to browse</p>
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
              className={`border-2 border-dashed rounded-lg p-12 text-center transition-colors ${
                dragOver ? "border-primary bg-primary/5" : "border-border"
              }`}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
            >
              <Image className="h-10 w-10 mx-auto text-muted-foreground mb-3" />
              <p className="text-sm font-medium mb-1">Upload inspection form or auction sheet</p>
              <p className="text-xs text-muted-foreground mb-4">JPG, PNG supported</p>
              <input
                type="file"
                accept="image/*"
                className="hidden"
                id="image-upload"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); }}
              />
              <Button variant="outline" onClick={() => document.getElementById("image-upload")?.click()} disabled={loading}>
                Browse Images
              </Button>
            </div>
          </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
