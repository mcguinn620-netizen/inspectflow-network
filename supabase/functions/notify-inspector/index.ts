import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface Payload {
  user_id?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const body: Payload = await req.json();
    if (!body.user_id || !body.title) {
      return new Response(JSON.stringify({ error: "user_id and title required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(url, key);

    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("token, platform")
      .eq("user_id", body.user_id);

    if (error) throw error;

    // APNs delivery is intentionally out of scope for this stub —
    // wire to APNs (or a provider like OneSignal) when keys are configured.
    // We log the dispatch so the round-trip is observable in edge function logs.
    console.log("[notify-inspector] would deliver to", tokens?.length ?? 0, "devices", {
      title: body.title,
      body: body.body,
      data: body.data,
    });

    return new Response(
      JSON.stringify({ delivered: 0, queued: tokens?.length ?? 0 }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[notify-inspector] error", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
