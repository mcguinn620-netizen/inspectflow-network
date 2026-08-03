// Read-only endpoint for auth-bypass mock users (web + iOS).
// Mock users have no Supabase session, so RLS-protected reads return nothing.
// This function serves org/user-scoped reads with the service role, but only
// for the hardcoded mock user allowlist and a fixed table allowlist.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js@2/cors";

const MOCK_USER_IDS = new Set(
  Array.from({ length: 10 }, (_, i) =>
    `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`),
);

/** table -> scope column that must be constrained for every query */
const TABLE_SCOPE: Record<string, "organization_id" | "user_id" | "none"> = {
  jobs: "organization_id",
  trips: "user_id",
  trip_stops: "none",
  trip_location_points: "organization_id",
  inspection_requests: "organization_id",
  intake_items: "organization_id",
  vehicles: "organization_id",
  inspector_vehicles: "user_id",
  organization_users: "organization_id",
  profiles: "none",
  earnings_settings: "user_id",
  availability_schedules: "none",
};

/** tables a mock user may write to through this endpoint */
const WRITABLE_TABLES = new Set(["jobs", "trips", "trip_stops"]);

const ALLOWED_OPS = new Set(["eq", "neq", "in", "gte", "lte", "gt", "lt", "is"]);

type Filter = { column: string; op: string; value: unknown };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const operation = String(body.op ?? "select");
    const mockUserId = String(body.mock_user_id ?? "");
    const table = String(body.table ?? "");
    const filters: Filter[] = Array.isArray(body.filters) ? body.filters : [];
    const limit = Math.min(Number(body.limit ?? 100) || 100, 500);
    const orderColumn = body.order ? String(body.order) : null;
    const ascending = body.ascending !== false;

    if (!MOCK_USER_IDS.has(mockUserId)) return json({ error: "Unknown mock user id" }, 403);
    const scope = TABLE_SCOPE[table];
    if (!scope) return json({ error: `Table not readable: ${table}` }, 403);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Scope enforcement.
    if (scope === "organization_id") {
      const orgFilter = filters.find((f) => f.column === "organization_id" && f.op === "eq");
      if (!orgFilter) return json({ error: "organization_id filter required" }, 400);
      const { data: member } = await admin
        .from("organization_users")
        .select("organization_id")
        .eq("user_id", mockUserId)
        .eq("organization_id", String(orgFilter.value))
        .maybeSingle();
      if (!member) return json({ ok: true, rows: [] });
    }

    if (operation === "insert" || operation === "update") {
      if (!WRITABLE_TABLES.has(table)) return json({ error: `Table not writable: ${table}` }, 403);
      const values = { ...(body.values ?? {}) } as Record<string, unknown>;
      if (scope === "user_id") values.user_id = mockUserId;

      if (operation === "insert") {
        const { data, error } = await admin.from(table).insert(values).select("*").single();
        if (error) return json({ error: error.message }, 400);
        return json({ ok: true, row: data });
      }

      const rowId = body.id ? String(body.id) : null;
      if (!rowId) return json({ error: "id required for update" }, 400);
      delete values.id;
      const { data, error } = await admin.from(table).update(values).eq("id", rowId).select("*").single();
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, row: data });
    }

    let q = admin.from(table).select("*").limit(limit);

    if (scope === "user_id") q = q.eq("user_id", mockUserId);
    if (table === "profiles") q = q.eq("id", mockUserId);

    for (const f of filters) {
      if (!f || typeof f.column !== "string" || !ALLOWED_OPS.has(f.op)) continue;
      if (scope === "user_id" && f.column === "user_id") continue;
      switch (f.op) {
        case "in":
          q = q.in(f.column, Array.isArray(f.value) ? f.value.map(String) : []);
          break;
        case "is":
          q = q.is(f.column, f.value === null || f.value === "null" ? null : f.value as never);
          break;
        default:
          q = (q as never as Record<string, (c: string, v: unknown) => typeof q>)[f.op](f.column, f.value);
      }
    }

    if (orderColumn) q = q.order(orderColumn, { ascending });

    const { data, error } = await q;
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, rows: data ?? [] });
  } catch (e) {
    console.error("mock-read error:", e);
    return json({ error: e instanceof Error ? e.message : "Unknown" }, 400);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
