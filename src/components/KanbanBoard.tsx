import { StatusBadge, type InspectionStatus } from "@/components/StatusBadge";
import { mockJobs } from "@/data/mockData";
import { Clock, AlertTriangle, Car } from "lucide-react";

const columns: { status: InspectionStatus; label: string }[] = [
  { status: "request_received", label: "Request Received" },
  { status: "assigned", label: "Assigned" },
  { status: "scheduled", label: "Scheduled" },
  { status: "in_progress", label: "In Progress" },
  { status: "awaiting_review", label: "Awaiting Review" },
  { status: "completed", label: "Completed" },
  { status: "report_delivered", label: "Delivered" },
];

function PriorityIndicator({ priority }: { priority: string }) {
  if (priority === "high") {
    return <AlertTriangle className="h-3.5 w-3.5 text-destructive" />;
  }
  if (priority === "medium") {
    return <Clock className="h-3.5 w-3.5 text-warning" />;
  }
  return null;
}

export function KanbanBoard() {
  return (
    <div className="flex gap-3 overflow-x-auto pb-4 -mx-4 md:-mx-6 px-4 md:px-6">
      {columns.map((col) => {
        const jobs = mockJobs.filter((j) => j.status === col.status);
        return (
          <div
            key={col.status}
            className="flex-shrink-0 w-72 flex flex-col"
          >
            <div className="flex items-center justify-between mb-3 px-1">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {col.label}
              </h3>
              <span className="text-xs font-medium text-muted-foreground bg-muted rounded-full px-2 py-0.5">
                {jobs.length}
              </span>
            </div>
            <div className="space-y-2 flex-1">
              {jobs.map((job) => (
                <div
                  key={job.id}
                  className="rounded-lg border bg-card p-3 hover:border-primary/30 transition-colors duration-150 cursor-pointer group"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-medium text-muted-foreground font-mono-tech">
                      {job.id}
                    </span>
                    <PriorityIndicator priority={job.priority} />
                  </div>
                  <div className="flex items-center gap-1.5 mb-1.5">
                    <Car className="h-3.5 w-3.5 text-muted-foreground" />
                    <p className="text-sm font-medium truncate">{job.vehicle}</p>
                  </div>
                  <p className="text-xs font-mono-tech text-muted-foreground mb-2 truncate">
                    {job.vin}
                  </p>
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-muted-foreground truncate">
                      {job.customer}
                    </span>
                    <StatusBadge status={job.status} />
                  </div>
                  {job.inspector && (
                    <div className="mt-2 pt-2 border-t flex items-center gap-2">
                      <div className="h-5 w-5 rounded-full bg-primary/10 flex items-center justify-center">
                        <span className="text-[9px] font-semibold text-primary">
                          {job.inspector.split(" ").map(n => n[0]).join("")}
                        </span>
                      </div>
                      <span className="text-xs text-muted-foreground">{job.inspector}</span>
                    </div>
                  )}
                </div>
              ))}
              {jobs.length === 0 && (
                <div className="rounded-lg border border-dashed bg-muted/30 p-6 text-center">
                  <p className="text-xs text-muted-foreground">No inspections</p>
                </div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
