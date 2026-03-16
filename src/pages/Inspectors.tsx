import { DashboardLayout } from "@/components/DashboardLayout";
import { mockInspectors } from "@/data/mockData";
import { Star, MapPin } from "lucide-react";

const statusStyles = {
  available: "bg-success/10 text-success",
  busy: "bg-warning/10 text-warning",
  offline: "bg-muted text-muted-foreground",
};

const InspectorsPage = () => {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Inspectors</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage your inspection network</p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {mockInspectors.map((inspector) => (
            <div
              key={inspector.id}
              className="rounded-lg border bg-card p-4 hover:border-primary/30 transition-colors duration-150 cursor-pointer"
            >
              <div className="flex items-start gap-3">
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                  <span className="text-sm font-semibold text-primary">{inspector.avatar}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-semibold truncate">{inspector.name}</p>
                    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium capitalize ${statusStyles[inspector.status]}`}>
                      {inspector.status}
                    </span>
                  </div>
                  <p className="text-xs font-mono-tech text-muted-foreground">{inspector.id}</p>
                </div>
              </div>
              <div className="mt-3 pt-3 border-t grid grid-cols-3 gap-2 text-center">
                <div>
                  <div className="flex items-center justify-center gap-1">
                    <Star className="h-3 w-3 text-warning" />
                    <span className="text-sm font-semibold">{inspector.rating}</span>
                  </div>
                  <p className="text-[10px] text-muted-foreground">Rating</p>
                </div>
                <div>
                  <p className="text-sm font-semibold">{inspector.completedJobs}</p>
                  <p className="text-[10px] text-muted-foreground">Jobs</p>
                </div>
                <div>
                  <div className="flex items-center justify-center gap-1">
                    <MapPin className="h-3 w-3 text-muted-foreground" />
                  </div>
                  <p className="text-[10px] text-muted-foreground truncate">{inspector.territory}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </DashboardLayout>
  );
};

export default InspectorsPage;
