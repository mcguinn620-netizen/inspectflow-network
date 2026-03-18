import { DashboardLayout } from "@/components/DashboardLayout";
import { KanbanBoard } from "@/components/KanbanBoard";
import { StatsRow } from "@/components/StatsRow";
import { ImportInspectionDialog } from "@/components/intake/ImportInspectionDialog";

const Index = () => {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Command Center</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Inspection lifecycle overview · March 16, 2026
            </p>
          </div>
          <ImportInspectionDialog />
        </div>
        <StatsRow />
        <div>
          <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground mb-4">
            Inspection Pipeline
          </h2>
          <KanbanBoard />
        </div>
      </div>
    </DashboardLayout>
  );
};

export default Index;
