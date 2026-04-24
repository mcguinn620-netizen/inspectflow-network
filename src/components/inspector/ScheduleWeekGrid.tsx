import { useMemo } from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

export interface ScheduleJob {
  id: string;
  title: string;
  customer_name: string | null;
  location: string | null;
  scheduled_at: string | null;
  status: string;
}

interface ScheduleWeekGridProps {
  weekStart: Date;
  jobs: ScheduleJob[];
  blockedDates: Set<string>; // YYYY-MM-DD
  availability: Record<number, { start_time: string; end_time: string; is_available: boolean }[]>;
  onJobClick?: (job: ScheduleJob) => void;
  onSlotClick?: (date: Date) => void;
}

const dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export function ScheduleWeekGrid({
  weekStart,
  jobs,
  blockedDates,
  availability,
  onJobClick,
  onSlotClick,
}: ScheduleWeekGridProps) {
  const days = useMemo(() => {
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(weekStart);
      d.setDate(d.getDate() + i);
      d.setHours(0, 0, 0, 0);
      return d;
    });
  }, [weekStart]);

  const today = useMemo(() => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  }, []);

  const jobsByDay = useMemo(() => {
    const map: Record<string, ScheduleJob[]> = {};
    for (const j of jobs) {
      if (!j.scheduled_at) continue;
      const key = new Date(j.scheduled_at).toDateString();
      (map[key] ??= []).push(j);
    }
    return map;
  }, [jobs]);

  const ymd = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

  return (
    <div className="grid grid-cols-7 gap-1.5">
      {days.map((d) => {
        const isToday = d.getTime() === today.getTime();
        const isBlocked = blockedDates.has(ymd(d));
        const dayJobs = jobsByDay[d.toDateString()] ?? [];
        const dow = d.getDay();
        const hasAvailability = (availability[dow]?.length ?? 0) > 0;
        return (
          <Card
            key={d.toISOString()}
            className={cn(
              "p-2 min-h-[140px] cursor-pointer hover:border-primary/40 transition-colors",
              isToday && "border-primary/60 bg-primary/5",
              isBlocked && "opacity-60 bg-muted/40",
            )}
            onClick={() => onSlotClick?.(d)}
          >
            <div className="flex items-center justify-between mb-1.5">
              <div>
                <div className="text-[10px] uppercase tracking-wide text-muted-foreground">
                  {dayLabels[dow]}
                </div>
                <div className={cn("text-sm font-semibold", isToday && "text-primary")}>
                  {d.getDate()}
                </div>
              </div>
              {isBlocked && (
                <Badge variant="outline" className="text-[9px] px-1 py-0">
                  Off
                </Badge>
              )}
            </div>
            <div className="space-y-1">
              {dayJobs.slice(0, 4).map((j) => (
                <button
                  key={j.id}
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onJobClick?.(j);
                  }}
                  className={cn(
                    "w-full text-left text-[11px] leading-tight px-1.5 py-1 rounded border bg-card hover:bg-accent truncate block",
                    j.status === "completed" && "opacity-60 line-through",
                    j.status === "in_progress" && "border-primary/50 text-primary",
                  )}
                  title={j.title}
                >
                  <span className="font-medium">
                    {j.scheduled_at
                      ? new Date(j.scheduled_at).toLocaleTimeString([], {
                          hour: "numeric",
                          minute: "2-digit",
                        })
                      : ""}
                  </span>{" "}
                  {j.title}
                </button>
              ))}
              {dayJobs.length > 4 && (
                <div className="text-[10px] text-muted-foreground px-1">
                  +{dayJobs.length - 4} more
                </div>
              )}
              {dayJobs.length === 0 && !isBlocked && hasAvailability && (
                <div className="text-[10px] text-muted-foreground px-1 italic">Available</div>
              )}
            </div>
          </Card>
        );
      })}
    </div>
  );
}
