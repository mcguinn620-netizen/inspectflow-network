import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Wrench } from "lucide-react";

export default function MechanicDashboard() {
  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Mechanic Workspace</h1>
          <p className="text-sm text-muted-foreground mt-1">Repair queue and work orders — coming soon</p>
        </div>
        <Card>
          <CardHeader><CardTitle className="text-base flex items-center gap-2"><Wrench className="h-4 w-4" />Phase placeholder</CardTitle></CardHeader>
          <CardContent className="text-sm text-muted-foreground space-y-2">
            <p>Future modules planned for this role:</p>
            <ul className="list-disc pl-5 space-y-1">
              <li>Incoming repair estimates from completed inspections</li>
              <li>Work order management</li>
              <li>Parts ordering &amp; technician assignment</li>
              <li>Customer approvals via client portal</li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
