// intake-telegram-webhook
// Public endpoint registered with Telegram via setWebhook. Verifies the
// X-Telegram-Bot-Api-Secret-Token (derived from TELEGRAM_API_KEY), inserts an
// intake_item, and triggers parsing.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

async function deriveSecret(apiKey: string): Promise<string> {
  const data = new TextEncoder().encode(`telegram-webhook:${apiKey}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function safeEq(a: string | null, b: string): boolean {
  if (!a || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  try {
    const tgKey = Deno.env.get("TELEGRAM_API_KEY");
    if (!tgKey) return new Response("Telegram not connected", { status: 503 });

    const expected = await deriveSecret(tgKey);
    if (!safeEq(req.headers.get("X-Telegram-Bot-Api-Secret-Token"), expected)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const orgId = Deno.env.get("INTAKE_DEFAULT_ORG_ID");
    if (!orgId) return new Response(JSON.stringify({ ok: true, skipped: "no default org" }));

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const update = await req.json();
    const msg = update.message ?? update.edited_message ?? update.channel_post;
    if (!msg || typeof update.update_id !== "number") {
      return new Response(JSON.stringify({ ok: true, ignored: true }));
    }

    const text = (msg.text ?? msg.caption ?? "").toString();
    const from = msg.from?.username ?? msg.from?.id?.toString() ?? null;
    const subject = text.split("\n")[0]?.slice(0, 120) ?? null;

    const { data: item, error } = await admin.from("intake_items").insert({
      organization_id: orgId,
      channel: "telegram",
      source_ref: String(update.update_id),
      source_address: from,
      subject,
      raw_text: text,
      raw_payload: update,
      dedupe_hash: `telegram:${orgId}:${update.update_id}`,
      status: "new",
    }).select("id").single();

    if (error && error.code !== "23505") throw error;
    if (item?.id) {
      await admin.functions.invoke("intake-parse", { body: { intake_item_id: item.id } });
    }

    return new Response(JSON.stringify({ ok: true }));
  } catch (e) {
    console.error("intake-telegram-webhook error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
