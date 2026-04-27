// Shared conflict detection for the inspector schedule.
// Surfaces blocked-day, outside-availability, and overlap conflicts.

import type { ScheduleJob } from "@/components/inspector/ScheduleWeekGrid";

export type ConflictReason =
  | { kind: "blocked"; message: string }
  | { kind: "outside_hours"; message: string }
  | { kind: "overlap"; message: string; otherJobId: string };

export interface DetectInput {
  jobs: ScheduleJob[];
  blockedDates: Set<string>; // YYYY-MM-DD
  availability: Record<
    number,
    { start_time: string; end_time: string; is_available: boolean }[]
  >;
  /** Default duration when a job has no estimated_duration_minutes. */
  defaultDurationMinutes?: number;
}

const ymd = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

const minutesOfDay = (hhmm: string) => {
  const [h, m] = hhmm.split(":").map(Number);
  return (h || 0) * 60 + (m || 0);
};

export function detectConflicts({
  jobs,
  blockedDates,
  availability,
  defaultDurationMinutes = 60,
}: DetectInput): Map<string, ConflictReason[]> {
  const out = new Map<string, ConflictReason[]>();
  const push = (id: string, r: ConflictReason) => {
    const list = out.get(id) ?? [];
    list.push(r);
    out.set(id, list);
  };

  // Group by day for overlap detection
  const byDay = new Map<string, (ScheduleJob & { _start: number; _end: number })[]>();
  for (const j of jobs) {
    if (!j.scheduled_at) continue;
    if (j.status === "canceled" || j.status === "completed") continue;
    const start = new Date(j.scheduled_at);
    const dur = (j as any).estimated_duration_minutes ?? defaultDurationMinutes;
    const end = new Date(start.getTime() + dur * 60_000);
    const dayKey = ymd(start);
    const arr = byDay.get(dayKey) ?? [];
    arr.push({ ...j, _start: start.getTime(), _end: end.getTime() });
    byDay.set(dayKey, arr);

    // Blocked-date
    if (blockedDates.has(dayKey)) {
      push(j.id, { kind: "blocked", message: "Day marked off" });
    }

    // Outside availability
    const dow = start.getDay();
    const slots = availability[dow] ?? [];
    if (slots.length > 0) {
      const startMin = start.getHours() * 60 + start.getMinutes();
      const endMin = startMin + dur;
      const fitsAny = slots.some(
        (s) =>
          s.is_available !== false &&
          startMin >= minutesOfDay(s.start_time) &&
          endMin <= minutesOfDay(s.end_time),
      );
      if (!fitsAny) {
        push(j.id, { kind: "outside_hours", message: "Outside working hours" });
      }
    }
  }

  // Overlaps within each day
  for (const list of byDay.values()) {
    list.sort((a, b) => a._start - b._start);
    for (let i = 0; i < list.length; i++) {
      for (let k = i + 1; k < list.length; k++) {
        if (list[k]._start >= list[i]._end) break;
        push(list[i].id, {
          kind: "overlap",
          message: `Overlaps with ${list[k].title}`,
          otherJobId: list[k].id,
        });
        push(list[k].id, {
          kind: "overlap",
          message: `Overlaps with ${list[i].title}`,
          otherJobId: list[i].id,
        });
      }
    }
  }

  return out;
}

export function summarizeConflicts(reasons: ConflictReason[]): string {
  if (!reasons.length) return "";
  return reasons.map((r) => r.message).join(" · ");
}
