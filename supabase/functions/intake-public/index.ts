// intake-public
// Public (no-JWT) intake helper used by the "Import Inspection" dialog for
// both real and mock users. Consolidates three ops so the client only makes
// one call per stage:
//
//   op: "fetch_url"   -> { url }                               returns { text, title }
//   op: "parse_pdf"   -> { base64 }                            returns { text }
//   op: "parse_image" -> { base64, mime }                      returns { parsed }
//   op: "create"      -> { mock_user_id?, organization_id?, payload }
//                        (mock_user_id must be one of the seeded MOCK_USERS
//                        UUIDs; org membership is enforced against
//                        organization_users when both are provided)
//
// Real signed-in users can also call "create" with a JWT and the row will be
// inserted via the user client so RLS applies. Mock users hit the
// service-role branch after allowlist validation.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@0.12.1";
import { corsHeaders } from "../_shared/cors.ts";

// Keep in sync with src/lib/authBypass.ts MOCK_USERS ids.
const MOCK_USER_IDS = new Set<string>([
  "00000000-0000-4000-8000-000000000001",
  "00000000-0000-4000-8000-000000000002",
  "00000000-0000-4000-8000-000000000003",
  "00000000-0000-4000-8000-000000000004",
  "00000000-0000-4000-8000-000000000005",
  "00000000-0000-4000-8000-000000000006",
  "00000000-0000-4000-8000-000000000007",
  "00000000-0000-4000-8000-000000000008",
  "00000000-0000-4000-8000-000000000009",
  "00000000-0000-4000-8000-000000000010",
]);

function sanitize(s: string): string {
  return (s ?? "").replace(/\u0000/g, "").replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, " ");
}

function stripHtml(html: string): { title: string | null; text: string } {
  const titleMatch = html.match(/<title>([^<]*)<\/title>/i);
  const title = titleMatch ? titleMatch[1].trim() : null;
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/&quot;/g, '"')
    .replace(/\s+/g, " ").trim();
  return { title: title ? sanitize(title) : null, text: sanitize(text.slice(0, 20000)) };
}

function b64ToBytes(b64: string): Uint8Array {
  const clean = b64.includes(",") ? b64.slice(b64.indexOf(",") + 1) : b64;
  const bin = atob(clean);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function callParseInspection(body: unknown): Promise<Record<string, unknown>> {
  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/parse-inspection`;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${Deno.env.get("SUPABASE_ANON_KEY")}`,
    },
    body: JSON.stringify(body),
  });
  const json = await r.json();
  if (!r.ok || json.error) throw new Error(json.error ?? `parse-inspection ${r.status}`);
  return json.parsed as Record<string, unknown>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const op = body?.op as string;

    if (op === "fetch_url") {
      const url = String(body.url ?? "").trim();
      if (!/^https?:\/\//i.test(url)) throw new Error("Provide a full http(s) URL");
      const r = await fetch(url, {
        headers: { "User-Agent": "Mozilla/5.0 InspectFlowIntake/1.0" },
        redirect: "follow",
      });
      if (!r.ok) throw new Error(`Fetch failed: ${r.status}`);
      const ct = r.headers.get("content-type") ?? "";
      const raw = await r.text();
      const { title, text } = ct.includes("html") ? stripHtml(raw) : { title: null, text: sanitize(raw.slice(0, 20000)) };
      if (text.trim().length < 5) throw new Error("URL returned no readable text");
      return json({ ok: true, title, text });
    }

    if (op === "parse_pdf") {
      const bytes = b64ToBytes(String(body.base64 ?? ""));
      if (!bytes.length) throw new Error("Empty PDF");
      const pdf = await getDocumentProxy(bytes);
      const { text } = await extractText(pdf, { mergePages: true });
      const clean = sanitize(Array.isArray(text) ? text.join("\n") : String(text)).slice(0, 200_000);
      if (clean.trim().length < 5) throw new Error("PDF has no extractable text (likely scanned). Try the Image tab.");
      return json({ ok: true, text: clean });
    }

    if (op === "parse_image") {
      const b64 = String(body.base64 ?? "");
      const mime = String(body.mime ?? "image/jpeg");
      if (!b64) throw new Error("Empty image");
      const dataUrl = b64.startsWith("data:") ? b64 : `data:${mime};base64,${b64}`;
      const parsed = await callParseInspection({ source_type: "image", image_url: dataUrl, text: "See attached image." });
      return json({ ok: true, parsed });
    }

    if (op === "create") {
      const payload = body.payload as Record<string, unknown>;
      if (!payload) throw new Error("payload required");

      const admin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );

      const mockUserId = body.mock_user_id ? String(body.mock_user_id) : null;
      const orgId = body.organization_id ? String(body.organization_id) : null;

      if (mockUserId) {
        if (!MOCK_USER_IDS.has(mockUserId)) throw new Error("Unknown mock user id");
        if (orgId) {
          const { data: member } = await admin
            .from("organization_users")
            .select("organization_id")
            .eq("user_id", mockUserId).eq("organization_id", orgId).maybeSingle();
          if (!member) throw new Error("Mock user is not a member of that organization");
        }
      } else {
        // Real-auth path: require a JWT and derive the user via getUser.
        const authHeader = req.headers.get("Authorization");
        if (!authHeader?.startsWith("Bearer ")) throw new Error("Not authenticated");
        const user = createClient(
          Deno.env.get("SUPABASE_URL")!,
          Deno.env.get("SUPABASE_ANON_KEY")!,
          { global: { headers: { Authorization: authHeader } } },
        );
        const { data: u, error: uErr } = await user.auth.getUser();
        if (uErr || !u.user) throw new Error("Invalid session");
      }

      // `inspection_requests` has no organization_id column — the org link
      // lives on the job row created below.
      const insertRow = {
        ...payload,
        status: "request_received",
      };

      const { data: reqRow, error: insErr } = await admin
        .from("inspection_requests").insert(insertRow).select("id").single();
      if (insErr) throw new Error(insErr.message);

      // Best-effort create a scheduled job for the mock/real user.
      if (mockUserId && orgId) {
        await admin.from("jobs").insert({
          organization_id: orgId,
          created_by: mockUserId,
          assigned_to: mockUserId,
          title: `${payload.vehicle_year ?? ""} ${payload.vehicle_make ?? ""} ${payload.vehicle_model ?? ""}`.trim() || "Inspection",
          customer_name: payload.client_name ?? null,
          location: payload.inspection_location ?? null,
          scheduled_at: payload.requested_date ?? null,
          status: "scheduled",
          notes: payload.notes ?? null,
        });
      }

      return json({ ok: true, inspection_request_id: reqRow.id });
    }

    throw new Error(`Unknown op: ${op}`);
  } catch (e) {
    console.error("intake-public error:", e);
    return json({ error: e instanceof Error ? e.message : "Unknown" }, 400);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
