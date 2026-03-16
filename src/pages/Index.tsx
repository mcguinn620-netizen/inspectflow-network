import { DashboardLayout } from "@/components/DashboardLayout";
import { KanbanBoard } from "@/components/KanbanBoard";
import { StatsRow } from "@/components/StatsRow";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";

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
          <Button className="gap-2">
            <Plus className="h-4 w-4" />
            New Inspection
          </Button>
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
