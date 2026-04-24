// Public read-only iCalendar feed for an inspector's upcoming jobs.
// URL pattern:  /functions/v1/calendar-feed?token=<calendar_feed_token>
// Returns text/calendar (RFC 5545). No JWT — token-gated for calendar subscribers.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const pad = (n: number) => String(n).padStart(2, "0");
const toIcsDate = (d: Date) =>
  d.getUTCFullYear().toString() +
  pad(d.getUTCMonth() + 1) +
  pad(d.getUTCDate()) + "T" +
  pad(d.getUTCHours()) +
  pad(d.getUTCMinutes()) +
  pad(d.getUTCSeconds()) + "Z";

const esc = (s: string) =>
  s.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");

function fold(line: string): string {
  const max = 73;
  if (line.length <= max) return line;
  const parts: string[] = [];
  for (let i = 0; i < line.length; i += max) {
    parts.push((i === 0 ? "" : " ") + line.slice(i, i + max));
  }
  return parts.join("\r\n");
}

interface JobRow {
  id: string;
  title: string;
  customer_name: string | null;
  location: string | null;
  scheduled_at: string;
  estimated_duration_minutes: number | null;
  status: string;
  notes: string | null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);
  const token = url.searchParams.get("token");
  if (!token || token.length < 16) {
    return new Response("Missing or invalid token", { status: 400, headers: corsHeaders });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return new Response("Server not configured", { status: 500, headers: corsHeaders });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Look up the user by token.
  const { data: profile, error: profErr } = await admin
    .from("profiles")
    .select("id, full_name")
    .eq("calendar_feed_token", token)
    .maybeSingle();

  if (profErr || !profile) {
    return new Response("Invalid token", { status: 404, headers: corsHeaders });
  }

  // All upcoming jobs for orgs the user belongs to, where they're assigned (or unassigned).
  const { data: orgs } = await admin
    .from("organization_users")
    .select("organization_id")
    .eq("user_id", profile.id);
  const orgIds = (orgs ?? []).map((o: { organization_id: string }) => o.organization_id);
  if (orgIds.length === 0) {
    return new Response(buildEmpty(profile.full_name ?? "Inspector"), {
      headers: { ...corsHeaders, "Content-Type": "text/calendar; charset=utf-8" },
    });
  }

  const fromIso = new Date(Date.now() - 7 * 86_400_000).toISOString(); // include last week
  const { data: jobs } = await admin
    .from("jobs")
    .select("id,title,customer_name,location,scheduled_at,estimated_duration_minutes,status,notes")
    .in("organization_id", orgIds)
    .is("deleted_at", null)
    .not("scheduled_at", "is", null)
    .gte("scheduled_at", fromIso)
    .neq("status", "canceled")
    .order("scheduled_at", { ascending: true })
    .limit(500);

  const events = (jobs ?? []).map((j: JobRow) => buildVEvent(j));
  const calName = `${profile.full_name ?? "Inspector"} — Jobs`;
  const ics = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Lovable//Inspector//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${esc(calName)}`,
    "REFRESH-INTERVAL;VALUE=DURATION:PT1H",
    "X-PUBLISHED-TTL:PT1H",
    ...events,
    "END:VCALENDAR",
  ].join("\r\n");

  return new Response(ics, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/calendar; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
});

function buildVEvent(j: JobRow): string {
  const start = new Date(j.scheduled_at);
  const dur = Math.max(15, j.estimated_duration_minutes ?? 60);
  const end = new Date(start.getTime() + dur * 60_000);
  const desc = [j.customer_name ? `Customer: ${j.customer_name}` : null, j.notes]
    .filter(Boolean)
    .join("\n");
  const lines = [
    "BEGIN:VEVENT",
    `UID:job-${j.id}@inspector.lovable.app`,
    `DTSTAMP:${toIcsDate(new Date())}`,
    `DTSTART:${toIcsDate(start)}`,
    `DTEND:${toIcsDate(end)}`,
    `SUMMARY:${esc(j.title)}`,
    `STATUS:${j.status === "completed" ? "CONFIRMED" : "TENTATIVE"}`,
  ];
  if (j.location) lines.push(`LOCATION:${esc(j.location)}`);
  if (desc) lines.push(`DESCRIPTION:${esc(desc)}`);
  return lines.map(fold).join("\r\n");
}

function buildEmpty(name: string): string {
  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Lovable//Inspector//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${esc(name + " — Jobs")}`,
    "END:VCALENDAR",
  ].join("\r\n");
}
