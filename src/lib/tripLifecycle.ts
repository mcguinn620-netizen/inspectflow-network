import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

/**
 * Phase 6 — idempotent trip + stop lifecycle helpers.
 *
 * These helpers centralize all state transitions for trips and trip_stops so
 * every surface (banner, next-stop card, trips page, schedule) follows the
 * same rules and cannot accidentally re-complete a record.
 *
 * Two layers of protection:
 *   1. Client-side guards via `can*` predicates → drive button visibility.
 *   2. Query-side guards via `.not("status", "eq", "completed")` (or similar)
 *      so even a stale UI / realtime race / double-tap cannot overwrite a
 *      finalized record. We then check `data?.length` to detect "already
 *      done" and surface a calm toast.
 */

export const TERMINAL_TRIP_STATUSES = ["completed", "canceled"] as const;
export const TERMINAL_STOP_STATUSES = ["completed", "skipped"] as const;
export const TERMINAL_JOB_STATUSES = ["completed", "canceled"] as const;

export const isTripTerminal = (status?: string | null) =>
  !!status && (TERMINAL_TRIP_STATUSES as readonly string[]).includes(status);
export const isStopTerminal = (status?: string | null) =>
  !!status && (TERMINAL_STOP_STATUSES as readonly string[]).includes(status);
export const isJobTerminal = (status?: string | null) =>
  !!status && (TERMINAL_JOB_STATUSES as readonly string[]).includes(status);

// ---------- Trip transition predicates ----------
export const canStartTrip = (status?: string | null) =>
  status === "draft" || status === "planned" || status === "paused";
export const canPauseTrip = (status?: string | null) => status === "active";
export const canResumeTrip = (status?: string | null) => status === "paused";
export const canCompleteTrip = (status?: string | null) =>
  status === "active" || status === "paused" || status === "draft" || status === "planned";

// ---------- Stop transition predicates ----------
export const canArriveStop = (status?: string | null) => status === "pending";
export const canCompleteStop = (status?: string | null) =>
  status === "pending" || status === "arrived";
export const canSkipStop = (status?: string | null) => status === "pending";

// ---------- Job transition predicates ----------
export const canStartJob = (status?: string | null) => status === "scheduled";
export const canCompleteJob = (status?: string | null) => status === "in_progress";
export const canCancelJob = (status?: string | null) =>
  status === "scheduled" || status === "in_progress";

// ============================================================================
// TRIPS
// ============================================================================
export interface TripLike {
  id: string;
  status: string;
  started_at?: string | null;
}

/**
 * Update a trip's status. Query is guarded against terminal states so a
 * second tap (or stale client) cannot overwrite completed_at.
 *
 * Returns true if a row was actually changed.
 */
export async function setTripStatus(
  trip: TripLike,
  status: "active" | "paused" | "completed" | "canceled" | "draft" | "planned",
): Promise<boolean> {
  // Client-side guard — friendly handling for already-done state.
  if (isTripTerminal(trip.status)) {
    toast.info(`This trip is already ${trip.status}.`);
    return false;
  }
  if (status === "completed" && !canCompleteTrip(trip.status)) {
    toast.info("This trip can no longer be completed.");
    return false;
  }

  const updates: Record<string, unknown> = { status };
  const now = new Date().toISOString();
  if (status === "active" && !trip.started_at) updates.started_at = now;
  if (status === "paused") updates.paused_at = now;
  if (status === "completed") updates.completed_at = now;

  // Query-side guard — never re-write a terminal trip.
  const { data, error } = await supabase
    .from("trips")
    .update(updates)
    .eq("id", trip.id)
    .not("status", "in", `(${TERMINAL_TRIP_STATUSES.join(",")})`)
    .select("id");

  if (error) {
    toast.error(error.message);
    return false;
  }
  if (!data || data.length === 0) {
    toast.info("This trip is already completed.");
    return false;
  }
  toast.success(`Trip ${status}`);
  return true;
}

// ============================================================================
// STOPS
// ============================================================================
export interface StopLike {
  id: string;
  status: string;
  job_id?: string | null;
  arrived_at?: string | null;
  departed_at?: string | null;
  completed_at?: string | null;
}

interface SetStopOpts {
  /** Mirror to the linked job — start it (in_progress). */
  startJob?: boolean;
  /** Mirror to the linked job — complete it. */
  completeJob?: boolean;
  /** Suppress success toast (used inside compound flows). */
  silent?: boolean;
}

/**
 * Update a stop's status with a query guard against terminal states.
 *
 * arrived_at / departed_at are written only on the transition itself — a
 * second tap cannot overwrite them because the WHERE clause excludes
 * terminal stops, and arrival is also gated client-side.
 */
export async function setStopStatus(
  stop: StopLike,
  status: "arrived" | "completed" | "skipped",
  opts: SetStopOpts = {},
): Promise<boolean> {
  if (isStopTerminal(stop.status)) {
    if (!opts.silent) toast.info(`This stop is already ${stop.status}.`);
    return false;
  }
  if (status === "arrived" && !canArriveStop(stop.status)) {
    if (!opts.silent) toast.info("Stop already arrived.");
    return false;
  }
  if (status === "completed" && !canCompleteStop(stop.status)) {
    if (!opts.silent) toast.info("This stop can no longer be completed.");
    return false;
  }

  const now = new Date().toISOString();
  const updates: Record<string, unknown> = { status };
  // Never overwrite arrived_at if it already exists.
  if (status === "arrived" && !stop.arrived_at) updates.arrived_at = now;
  if (status === "completed") {
    if (!stop.completed_at) updates.completed_at = now;
    if (!stop.departed_at) updates.departed_at = now;
    // Backfill arrival if user jumped straight to complete.
    if (!stop.arrived_at) updates.arrived_at = now;
  }
  if (status === "skipped" && !stop.departed_at) updates.departed_at = now;

  const { data, error } = await supabase
    .from("trip_stops")
    .update(updates)
    .eq("id", stop.id)
    .not("status", "in", `(${TERMINAL_STOP_STATUSES.join(",")})`)
    .select("id");

  if (error) {
    toast.error(error.message);
    return false;
  }
  if (!data || data.length === 0) {
    if (!opts.silent) toast.info("This stop is already completed.");
    return false;
  }

  // Mirror to job idempotently
  if (stop.job_id && (opts.startJob || opts.completeJob)) {
    if (opts.startJob) await startJobById(stop.job_id, { silent: true });
    if (opts.completeJob) await completeJobById(stop.job_id, { silent: true });
  }

  if (!opts.silent && status === "completed") toast.success("Stop completed");
  return true;
}

// ============================================================================
// JOBS
// ============================================================================
export interface JobLike {
  id: string;
  status: string;
  actual_start_time?: string | null;
  actual_end_time?: string | null;
}

interface JobOpts { silent?: boolean }

async function startJobById(id: string, opts: JobOpts = {}): Promise<boolean> {
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("jobs")
    .update({ status: "in_progress", actual_start_time: now })
    .eq("id", id)
    .eq("status", "scheduled") // only valid forward transition
    .is("actual_start_time", null) // never overwrite a real start time
    .select("id");
  if (error) {
    if (!opts.silent) toast.error(error.message);
    return false;
  }
  if (!data || data.length === 0) {
    // Probably already started or completed — fine, silent.
    return false;
  }
  return true;
}

async function completeJobById(id: string, opts: JobOpts = {}): Promise<boolean> {
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("jobs")
    .update({ status: "completed", actual_end_time: now })
    .eq("id", id)
    .not("status", "in", `(${TERMINAL_JOB_STATUSES.join(",")})`)
    .is("actual_end_time", null) // never overwrite final completion timestamp
    .select("id");
  if (error) {
    if (!opts.silent) toast.error(error.message);
    return false;
  }
  if (!data || data.length === 0) return false;
  return true;
}

/**
 * Public job state setter used by Jobs / Schedule pages.
 * Enforces valid transitions and is idempotent.
 */
export async function setJobStatus(
  job: JobLike,
  status: "in_progress" | "completed" | "canceled" | "scheduled",
): Promise<boolean> {
  if (isJobTerminal(job.status)) {
    toast.info(`This job is already ${job.status}.`);
    return false;
  }

  if (status === "in_progress") {
    if (!canStartJob(job.status)) {
      toast.info("This job cannot be started from its current state.");
      return false;
    }
    const ok = await startJobById(job.id);
    if (ok) toast.success("Job started");
    else toast.info("This job is already in progress.");
    return ok;
  }
  if (status === "completed") {
    if (!canCompleteJob(job.status)) {
      toast.info("Start the job before completing it.");
      return false;
    }
    const ok = await completeJobById(job.id);
    if (ok) toast.success("Job completed");
    else toast.info("This job is already completed.");
    return ok;
  }
  if (status === "canceled") {
    if (!canCancelJob(job.status)) {
      toast.info("This job cannot be canceled.");
      return false;
    }
    const { data, error } = await supabase
      .from("jobs")
      .update({ status: "canceled" })
      .eq("id", job.id)
      .not("status", "in", `(${TERMINAL_JOB_STATUSES.join(",")})`)
      .select("id");
    if (error) { toast.error(error.message); return false; }
    if (!data?.length) { toast.info("This job is already finalized."); return false; }
    toast.success("Job canceled");
    return true;
  }
  // scheduled — soft revert (rare; only used by edit forms)
  const { error } = await supabase.from("jobs").update({ status }).eq("id", job.id);
  if (error) { toast.error(error.message); return false; }
  return true;
}
