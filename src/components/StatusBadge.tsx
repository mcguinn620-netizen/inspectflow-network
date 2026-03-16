import { cn } from "@/lib/utils";

export type InspectionStatus =
  | "request_received"
  | "assigned"
  | "scheduled"
  | "in_progress"
  | "awaiting_review"
  | "completed"
  | "report_delivered";

interface StatusBadgeProps {
  status: InspectionStatus;
  className?: string;
}

const statusConfig: Record<InspectionStatus, { label: string; className: string }> = {
  request_received: { label: "Request Received", className: "bg-muted text-muted-foreground" },
  assigned: { label: "Assigned", className: "bg-primary/10 text-primary" },
  scheduled: { label: "Scheduled", className: "bg-warning/10 text-warning" },
  in_progress: { label: "In Progress", className: "bg-primary/20 text-primary" },
  awaiting_review: { label: "Awaiting Review", className: "bg-warning/10 text-warning" },
  completed: { label: "Completed", className: "bg-success/10 text-success" },
  report_delivered: { label: "Report Delivered", className: "bg-success/20 text-success" },
};

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const config = statusConfig[status];
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium transition-all duration-150",
        config.className,
        className
      )}
    >
      {config.label}
    </span>
  );
}
