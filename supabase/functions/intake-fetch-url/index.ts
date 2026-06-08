// intake-fetch-url
// Client-invoked. Fetches a URL server-side, strips HTML to text, inserts an
// intake_item (channel='web_link') for the caller's default org, then triggers parse.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

function sanitize(s: string): string {
  // Postgres text cannot contain NUL bytes (\u0000) or other lone control chars
  return s.replace(/\u0000/g, "").replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");
}

function stripHtml(html: string): { title: string | null; text: string } {
  const titleMatch = html.match(/<title>([^<]*)<\/title>/i);
  const title = titleMatch ? titleMatch[1].trim() : null;
  const noScript = html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
  return { title: title ? sanitize(title) : null, text: sanitize(noScript.slice(0, 20000)) };
}

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const token = authHeader.replace("Bearer ", "");
    const { data: claims, error: claimsErr } = await userClient.auth.getClaims(token);
    if (claimsErr || !claims?.claims?.sub) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const userId = claims.claims.sub;

    const { url, organization_id } = await req.json();
    if (!url || typeof url !== "string") {
      return new Response(JSON.stringify({ error: "url required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    let parsedUrl: URL;
    try { parsedUrl = new URL(url); } catch {
      return new Response(JSON.stringify({ error: "invalid url" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!["http:", "https:"].includes(parsedUrl.protocol)) {
      return new Response(JSON.stringify({ error: "unsupported protocol" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    let orgId = organization_id as string | undefined;
    if (!orgId) {
      const { data: ou } = await admin
        .from("organization_users")
        .select("organization_id, is_default")
        .eq("user_id", userId)
        .order("is_default", { ascending: false })
        .limit(1)
        .maybeSingle();
      orgId = ou?.organization_id;
    }
    if (!orgId) {
      return new Response(JSON.stringify({ error: "no organization" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const res = await fetch(parsedUrl.toString(), {
      headers: { "User-Agent": "InspectFlowIntake/1.0" },
    });
    if (!res.ok) {
      return new Response(JSON.stringify({ error: `fetch failed: ${res.status}` }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const html = await res.text();
    const { title, text } = stripHtml(html);
    const dedupe = await sha256Hex(`web_link:${orgId}:${parsedUrl.toString()}`);

    const { data: item, error: itemErr } = await admin
      .from("intake_items")
      .insert({
        organization_id: orgId,
        channel: "web_link",
        source_ref: parsedUrl.toString(),
        source_address: parsedUrl.host,
        subject: title,
        raw_text: text,
        raw_payload: { url: parsedUrl.toString(), title },
        dedupe_hash: dedupe,
        created_by: userId,
        status: "new",
      })
      .select("id")
      .single();
    if (itemErr) {
      if (itemErr.code === "23505") {
        return new Response(JSON.stringify({ ok: true, duplicate: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      throw itemErr;
    }

    await admin.functions.invoke("intake-parse", { body: { intake_item_id: item.id } });

    return new Response(JSON.stringify({ ok: true, intake_item_id: item.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("intake-fetch-url error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
