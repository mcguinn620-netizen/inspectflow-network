import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ArrowLeft, Check, AlertTriangle, Car } from "lucide-react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { LocationAutocomplete } from "@/components/maps/LocationAutocomplete";

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

interface IntakeReviewScreenProps {
  originalText: string;
  parsedData: ParsedData;
  onSave: (data: ParsedData) => void;
  onBack: () => void;
}

const templates = [
  "Verity Checklist",
  "APC Checklist",
  "Pre-Purchase Inspection",
  "Lease Return",
  "Fleet Audit",
  "Lender Inspection",
  "Standard Inspection",
];

export function IntakeReviewScreen({ originalText, parsedData, onSave, onBack }: IntakeReviewScreenProps) {
  const [editData, setEditData] = useState<ParsedData>({ ...parsedData });

  const update = (field: keyof ParsedData, value: string | null) => {
    setEditData((prev) => ({ ...prev, [field]: value }));
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* LEFT: Original text */}
      <div className="space-y-3">
        <div className="flex items-center gap-2">
          <Badge variant="outline" className="text-xs">Source Document</Badge>
        </div>
        <ScrollArea className="h-[500px] rounded-lg border bg-muted/30 p-4">
          <pre className="text-sm whitespace-pre-wrap font-mono-tech text-muted-foreground leading-relaxed">
            {originalText}
          </pre>
        </ScrollArea>
      </div>

      {/* RIGHT: Parsed fields */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <Badge variant="outline" className="text-xs">Extracted Data</Badge>
          {!editData.vin_valid && editData.vin && (
            <Badge variant="destructive" className="gap-1 text-xs">
              <AlertTriangle className="h-3 w-3" /> Invalid VIN
            </Badge>
          )}
          {editData.vin_valid && editData.vin && (
            <Badge className="gap-1 text-xs bg-success text-success-foreground">
              <Check className="h-3 w-3" /> Valid VIN
            </Badge>
          )}
        </div>

        <ScrollArea className="h-[440px] pr-4">
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Client Name</Label>
                <Input value={editData.client_name || ""} onChange={(e) => update("client_name", e.target.value)} />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Company</Label>
                <Input value={editData.company_name || ""} onChange={(e) => update("company_name", e.target.value)} />
              </div>
            </div>

            <div className="space-y-1">
              <Label className="text-xs text-muted-foreground flex items-center gap-1">
                <Car className="h-3 w-3" /> VIN
              </Label>
              <Input
                value={editData.vin || ""}
                onChange={(e) => update("vin", e.target.value.toUpperCase())}
                className="font-mono-tech"
                maxLength={17}
              />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Year</Label>
                <Input value={editData.vehicle_year || ""} onChange={(e) => update("vehicle_year", e.target.value)} />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Make</Label>
                <Input value={editData.vehicle_make || ""} onChange={(e) => update("vehicle_make", e.target.value)} />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Model</Label>
                <Input value={editData.vehicle_model || ""} onChange={(e) => update("vehicle_model", e.target.value)} />
              </div>
            </div>

            <div className="space-y-1">
              <Label className="text-xs text-muted-foreground">Mileage</Label>
              <Input value={editData.mileage || ""} onChange={(e) => update("mileage", e.target.value)} />
            </div>
            <div className="space-y-1">
              <Label className="text-xs text-muted-foreground">Location</Label>
              <LocationAutocomplete
                value={editData.inspection_location || ""}
                onChange={(loc) => update("inspection_location", loc.address)}
                placeholder="Search address…"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Requested Date</Label>
                <Input type="date" value={editData.requested_date || ""} onChange={(e) => update("requested_date", e.target.value)} />
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Inspection Type</Label>
                <Input value={editData.inspection_type || ""} onChange={(e) => update("inspection_type", e.target.value)} />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Template</Label>
                <Select value={editData.template_name} onValueChange={(v) => update("template_name", v)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {templates.map((t) => (
                      <SelectItem key={t} value={t}>{t}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-muted-foreground">Priority</Label>
                <Select value={editData.priority} onValueChange={(v) => update("priority", v)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="low">Low</SelectItem>
                    <SelectItem value="medium">Medium</SelectItem>
                    <SelectItem value="high">High</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-1">
              <Label className="text-xs text-muted-foreground">Notes</Label>
              <Input value={editData.notes || ""} onChange={(e) => update("notes", e.target.value)} />
            </div>
          </div>
        </ScrollArea>

        <div className="flex items-center gap-3 pt-2 border-t">
          <Button variant="outline" onClick={onBack} className="gap-2">
            <ArrowLeft className="h-4 w-4" /> Re-parse
          </Button>
          <Button onClick={() => onSave(editData)} className="flex-1 gap-2">
            <Check className="h-4 w-4" /> Create Inspection Request
          </Button>
        </div>
      </div>
    </div>
  );
}
