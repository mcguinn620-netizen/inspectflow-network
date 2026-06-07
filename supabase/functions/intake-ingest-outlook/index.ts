// intake-ingest-outlook
// Polls Microsoft Outlook inbox for unread messages, inserts intake_items,
// marks read, triggers parsing.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const GATEWAY = "https://connector-gateway.lovable.dev/microsoft_outlook";

async function graph(path: string, init: RequestInit = {}) {
  const headers = {
    Authorization: `Bearer ${Deno.env.get("LOVABLE_API_KEY")}`,
    "X-Connection-Api-Key": Deno.env.get("MICROSOFT_OUTLOOK_API_KEY") ?? "",
    "Content-Type": "application/json",
    ...(init.headers ?? {}),
  };
  const res = await fetch(`${GATEWAY}${path}`, { ...init, headers });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`outlook ${res.status}: ${t}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

function stripHtml(html: string): string {
  return (html ?? "")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!Deno.env.get("MICROSOFT_OUTLOOK_API_KEY")) {
      return new Response(JSON.stringify({ skipped: "outlook not connected" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const orgId = Deno.env.get("INTAKE_DEFAULT_ORG_ID");
    if (!orgId) {
      return new Response(JSON.stringify({ skipped: "INTAKE_DEFAULT_ORG_ID not set" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const list = await graph(
      "/me/mailFolders/inbox/messages?$filter=isRead eq false&$top=10&$select=id,subject,from,body,bodyPreview,receivedDateTime"
    );
    const created: string[] = [];

    for (const m of (list?.value ?? [])) {
      const subject = m.subject ?? null;
      const from = m.from?.emailAddress?.address ?? null;
      const text = m.body?.contentType === "html" ? stripHtml(m.body?.content ?? "") : (m.body?.content ?? m.bodyPreview ?? "");

      const { data: item, error } = await admin.from("intake_items").insert({
        organization_id: orgId,
        channel: "outlook",
        source_ref: m.id,
        source_address: from,
        subject,
        raw_text: text,
        raw_payload: { id: m.id, receivedDateTime: m.receivedDateTime },
        dedupe_hash: `outlook:${orgId}:${m.id}`,
        status: "new",
      }).select("id").single();

      if (!error && item) {
        created.push(item.id);
        await admin.functions.invoke("intake-parse", { body: { intake_item_id: item.id } });
        try {
          await graph(`/me/messages/${m.id}`, {
            method: "PATCH",
            body: JSON.stringify({ isRead: true }),
          });
        } catch (e) { console.warn("mark read failed", e); }
      }
    }

    return new Response(JSON.stringify({ ok: true, ingested: created.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("intake-ingest-outlook error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
