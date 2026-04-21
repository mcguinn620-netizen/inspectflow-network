import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Send } from "lucide-react";

export default function DispatchDashboard() {
  return (
    <DashboardLayout>
      <div className="space-y-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Dispatch Workspace</h1>
          <p className="text-sm text-muted-foreground mt-1">Coordinate inspectors and assignments — coming soon</p>
        </div>
        <Card>
          <CardHeader><CardTitle className="text-base flex items-center gap-2"><Send className="h-4 w-4" />Phase placeholder</CardTitle></CardHeader>
          <CardContent className="text-sm text-muted-foreground space-y-2">
            <p>Future modules planned for this role:</p>
            <ul className="list-disc pl-5 space-y-1">
              <li>Live inspector availability map</li>
              <li>Auto/manual assignment queue</li>
              <li>Coverage and territory management</li>
              <li>SLA &amp; on-time tracking</li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}
