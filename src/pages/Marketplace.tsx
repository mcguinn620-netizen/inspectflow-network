import { useState, useEffect } from "react";
import { DashboardLayout } from "@/components/DashboardLayout";
import { supabase } from "@/integrations/supabase/client";
import { Store, Star, FileCheck, ChevronRight, Camera, ListChecks, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";

interface Template {
  id: string;
  name: string;
  description: string | null;
  source_provider: string | null;
  inspection_type: string | null;
  is_published: boolean | null;
  is_marketplace: boolean | null;
  version: number | null;
}

interface TemplateSection {
  id: string;
  name: string;
  sort_order: number | null;
  items: TemplateItem[];
}

interface TemplateItem {
  id: string;
  label: string;
  input_type: string | null;
  options: any;
  is_required: boolean | null;
  requires_photo: boolean | null;
  requires_video: boolean | null;
  weight: number | null;
  sort_order: number | null;
}

interface RequiredPhoto {
  id: string;
  label: string;
  sort_order: number | null;
}

interface SpecialInstruction {
  id: string;
  instruction: string;
  sort_order: number | null;
}

const typeColors: Record<string, string> = {
  warranty: "bg-primary/10 text-primary",
  pre_warranty: "bg-warning/10 text-warning",
  warranty_claim: "bg-success/10 text-success",
  arbitration: "bg-destructive/10 text-destructive",
};

export default function MarketplacePage() {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTemplate, setSelectedTemplate] = useState<string | null>(null);
  const [sections, setSections] = useState<TemplateSection[]>([]);
  const [photos, setPhotos] = useState<RequiredPhoto[]>([]);
  const [instructions, setInstructions] = useState<SpecialInstruction[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);

  useEffect(() => {
    loadTemplates();
  }, []);

  const loadTemplates = async () => {
    const { data } = await supabase.from("inspection_templates").select("*").eq("is_marketplace", true).order("name");
    setTemplates((data as Template[]) || []);
    setLoading(false);
  };

  const loadTemplateDetails = async (templateId: string) => {
    setDetailLoading(true);
    setSelectedTemplate(templateId);

    const [sectionsRes, photosRes, instructionsRes] = await Promise.all([
      supabase.from("template_sections").select("*").eq("template_id", templateId).order("sort_order"),
      supabase.from("template_required_photos").select("*").eq("template_id", templateId).order("sort_order"),
      supabase.from("template_special_instructions").select("*").eq("template_id", templateId).order("sort_order"),
    ]);

    const secs = (sectionsRes.data || []) as any[];
    const secIds = secs.map((s) => s.id);

    let items: any[] = [];
    if (secIds.length > 0) {
      const { data } = await supabase.from("template_checklist_items").select("*").in("section_id", secIds).order("sort_order");
      items = data || [];
    }

    const sectionsWithItems: TemplateSection[] = secs.map((s) => ({
      ...s,
      items: items.filter((i) => i.section_id === s.id),
    }));

    setSections(sectionsWithItems);
    setPhotos((photosRes.data as RequiredPhoto[]) || []);
    setInstructions((instructionsRes.data as SpecialInstruction[]) || []);
    setDetailLoading(false);
  };

  const template = templates.find((t) => t.id === selectedTemplate);
  const totalItems = sections.reduce((sum, s) => sum + s.items.length, 0);

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Inspection Marketplace</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Browse, preview, and deploy inspection templates from industry providers
          </p>
        </div>

        {loading ? (
          <div className="flex justify-center p-12">
            <div className="animate-spin h-6 w-6 border-2 border-primary border-t-transparent rounded-full" />
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {templates.map((t) => (
              <Dialog key={t.id} onOpenChange={(open) => open && loadTemplateDetails(t.id)}>
                <DialogTrigger asChild>
                  <div className="rounded-lg border bg-card p-4 hover:border-primary/30 transition-colors duration-150 cursor-pointer group">
                    <div className="flex items-start justify-between mb-3">
                      <div className="h-9 w-9 rounded-md bg-primary/10 flex items-center justify-center">
                        <Store className="h-4 w-4 text-primary" />
                      </div>
                      <Badge variant="outline" className={typeColors[t.inspection_type || "warranty"] || "bg-muted text-muted-foreground"}>
                        {t.inspection_type?.replace("_", " ")}
                      </Badge>
                    </div>
                    <h3 className="text-sm font-semibold mb-1 group-hover:text-primary transition-colors duration-150">
                      {t.name}
                    </h3>
                    <p className="text-xs text-muted-foreground mb-3 line-clamp-2">{t.description}</p>
                    <div className="flex items-center justify-between pt-3 border-t">
                      <span className="text-xs text-muted-foreground">by {t.source_provider}</span>
                      <span className="text-xs text-primary flex items-center gap-1 group-hover:translate-x-0.5 transition-transform">
                        View <ChevronRight className="h-3 w-3" />
                      </span>
                    </div>
                  </div>
                </DialogTrigger>
                <DialogContent className="max-w-2xl max-h-[85vh]">
                  <DialogHeader>
                    <DialogTitle className="flex items-center gap-2">
                      <Store className="h-5 w-5 text-primary" />
                      {template?.name}
                    </DialogTitle>
                  </DialogHeader>
                  {detailLoading ? (
                    <div className="flex justify-center p-8">
                      <div className="animate-spin h-6 w-6 border-2 border-primary border-t-transparent rounded-full" />
                    </div>
                  ) : (
                    <ScrollArea className="max-h-[65vh]">
                      <div className="space-y-6 pr-4">
                        <div className="flex items-center gap-4 text-sm text-muted-foreground">
                          <span className="flex items-center gap-1"><ListChecks className="h-4 w-4" />{totalItems} items</span>
                          <span className="flex items-center gap-1"><Camera className="h-4 w-4" />{photos.length} photos</span>
                          <span>v{template?.version}</span>
                        </div>

                        {template?.description && (
                          <p className="text-sm text-muted-foreground">{template.description}</p>
                        )}

                        {instructions.length > 0 && (
                          <div>
                            <h3 className="text-sm font-semibold mb-2 flex items-center gap-2">
                              <AlertCircle className="h-4 w-4 text-warning" />
                              Special Instructions
                            </h3>
                            <ul className="space-y-1.5">
                              {instructions.map((i) => (
                                <li key={i.id} className="text-xs text-muted-foreground bg-warning/5 rounded px-3 py-2 border border-warning/10">
                                  {i.instruction}
                                </li>
                              ))}
                            </ul>
                          </div>
                        )}

                        {sections.map((sec) => (
                          <div key={sec.id}>
                            <h3 className="text-sm font-semibold mb-2">{sec.name}</h3>
                            <div className="rounded-lg border divide-y">
                              {sec.items.map((item) => (
                                <div key={item.id} className="flex items-center justify-between px-3 py-2">
                                  <div className="flex items-center gap-2">
                                    <span className="text-xs">{item.label}</span>
                                    {item.requires_photo && <Camera className="h-3 w-3 text-muted-foreground" />}
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <Badge variant="outline" className="text-[10px]">{item.input_type?.replace("_", " ")}</Badge>
                                    {item.weight && item.weight > 1 && (
                                      <span className="text-[10px] text-warning font-medium">×{item.weight}</span>
                                    )}
                                  </div>
                                </div>
                              ))}
                            </div>
                          </div>
                        ))}

                        {photos.length > 0 && (
                          <div>
                            <h3 className="text-sm font-semibold mb-2 flex items-center gap-2">
                              <Camera className="h-4 w-4 text-primary" />
                              Required Photos
                            </h3>
                            <div className="grid grid-cols-2 gap-2">
                              {photos.map((p) => (
                                <div key={p.id} className="text-xs bg-muted/50 rounded px-3 py-2">
                                  {p.label}
                                </div>
                              ))}
                            </div>
                          </div>
                        )}

                        <Button className="w-full">Deploy Template</Button>
                      </div>
                    </ScrollArea>
                  )}
                </DialogContent>
              </Dialog>
            ))}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
