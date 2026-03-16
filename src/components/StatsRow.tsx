import { ClipboardCheck, Users, TrendingUp, AlertTriangle } from "lucide-react";

const stats = [
  { label: "Active Inspections", value: "24", change: "+3 today", icon: ClipboardCheck, trend: "up" as const },
  { label: "Available Inspectors", value: "12", change: "of 18 total", icon: Users, trend: "neutral" as const },
  { label: "Completion Rate", value: "94.2%", change: "+2.1% this week", icon: TrendingUp, trend: "up" as const },
  { label: "Needs Attention", value: "3", change: "overdue items", icon: AlertTriangle, trend: "down" as const },
];

export function StatsRow() {
  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      {stats.map((stat) => (
        <div
          key={stat.label}
          className="rounded-lg border bg-card p-4 transition-colors duration-150"
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
              {stat.label}
            </span>
            <stat.icon className="h-4 w-4 text-muted-foreground" />
          </div>
          <p className="text-2xl font-semibold tracking-tight">{stat.value}</p>
          <p className={`text-xs mt-1 ${
            stat.trend === "up" ? "text-success" : stat.trend === "down" ? "text-destructive" : "text-muted-foreground"
          }`}>
            {stat.change}
          </p>
        </div>
      ))}
    </div>
  );
}
