// intake-ingest-gmail
// Polls the workspace Gmail inbox (Gmail connector) for unread messages,
// inserts intake_items, marks the source message as read, and triggers parsing.
// Targets every organization whose owner has a default org; for simplicity, this
// poller writes into a single org passed via INTAKE_DEFAULT_ORG_ID, or all orgs
// owned by the same user when not set. Tweak as multi-tenant rules evolve.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const GATEWAY = "https://connector-gateway.lovable.dev/google_mail/gmail/v1";

async function gmail(path: string, init: RequestInit = {}) {
  const headers = {
    Authorization: `Bearer ${Deno.env.get("LOVABLE_API_KEY")}`,
    "X-Connection-Api-Key": Deno.env.get("GOOGLE_MAIL_API_KEY") ?? "",
    "Content-Type": "application/json",
    ...(init.headers ?? {}),
  };
  const res = await fetch(`${GATEWAY}${path}`, { ...init, headers });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`gmail ${res.status}: ${t}`);
  }
  return res.json();
}

function decodeB64Url(s: string): string {
  const norm = s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "=");
  try { return new TextDecoder().decode(Uint8Array.from(atob(norm), (c) => c.charCodeAt(0))); }
  catch { return ""; }
}

function extractBody(payload: any): string {
  if (!payload) return "";
  if (payload.body?.data) return decodeB64Url(payload.body.data);
  if (Array.isArray(payload.parts)) {
    const text = payload.parts.find((p: any) => p.mimeType === "text/plain");
    if (text?.body?.data) return decodeB64Url(text.body.data);
    for (const part of payload.parts) {
      const r = extractBody(part);
      if (r) return r;
    }
  }
  return "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!Deno.env.get("GOOGLE_MAIL_API_KEY")) {
      return new Response(JSON.stringify({ skipped: "gmail not connected" }), {
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

    const list = await gmail("/users/me/messages?q=is:unread&maxResults=10");
    const messages = list.messages ?? [];
    const created: string[] = [];

    for (const m of messages) {
      const msg = await gmail(`/users/me/messages/${m.id}?format=full`);
      const headers = msg.payload?.headers ?? [];
      const subject = headers.find((h: any) => h.name === "Subject")?.value ?? null;
      const from = headers.find((h: any) => h.name === "From")?.value ?? null;
      const body = extractBody(msg.payload) || msg.snippet || "";

      const { data: item, error } = await admin.from("intake_items").insert({
        organization_id: orgId,
        channel: "gmail",
        source_ref: m.id,
        source_address: from,
        subject,
        raw_text: body,
        raw_payload: { id: m.id, threadId: msg.threadId, snippet: msg.snippet },
        dedupe_hash: `gmail:${orgId}:${m.id}`,
        status: "new",
      }).select("id").single();

      if (!error && item) {
        created.push(item.id);
        await admin.functions.invoke("intake-parse", { body: { intake_item_id: item.id } });
        try {
          await gmail(`/users/me/messages/${m.id}/modify`, {
            method: "POST",
            body: JSON.stringify({ removeLabelIds: ["UNREAD"] }),
          });
        } catch (e) { console.warn("mark read failed", e); }
      }
    }

    return new Response(JSON.stringify({ ok: true, ingested: created.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("intake-ingest-gmail error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
