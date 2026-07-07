// Lemon Squad AI Agent — orchestrator (skeleton).
//
// STATUS: Draft/skeleton. The three real jobs — headless-browser login,
// scraping open inspection requests, and pre-filling the draft report form —
// require:
//   1) A BROWSERLESS_TOKEN secret (hosted Chromium via Browserless/Browserbase)
//   2) A screenshot of the actual lemonsquad.com inspection form so the first-
//      run AI field-mapper has real labels to map to.
// Until those exist, this function validates auth, loads the user's stored
// credentials, and returns a structured stub so the UI ("Sync now") wires up
// end-to-end and we can iterate quickly.
//
// Actions accepted (body: { action, ... }):
//   - "sync_requests"        pull new Lemon Squad requests into inspection_requests
//   - "start_draft"          begin a draft report for a completed inspection
//   - "resume_after_mfa"     resume a paused run after the iOS WebView solved MFA
//
// All actions run as the calling user (JWT); credentials are looked up via RLS.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js@2/cors";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const BROWSERLESS_TOKEN = Deno.env.get("BROWSERLESS_TOKEN"); // optional until wired

type Action = "sync_requests" | "start_draft" | "resume_after_mfa";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ error: "Missing Authorization" }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userRes, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userRes.user) return json({ error: "Not authenticated" }, 401);
    const userId = userRes.user.id;

    const body = (await req.json().catch(() => ({}))) as { action?: Action };
    const action = body.action ?? "sync_requests";

    // Load credentials (RLS scoped to caller).
    const { data: cred, error: credErr } = await supabase
      .from("external_site_credentials")
      .select("id, username, password_ciphertext, submission_mode, is_active")
      .eq("site", "lemonsquad")
      .maybeSingle();
    if (credErr) return json({ error: credErr.message }, 400);
    if (!cred || !cred.is_active) {
      return json({ error: "Lemon Squad is not connected for this user." }, 400);
    }

    // Load prior session (cookies) if present.
    const { data: session } = await supabase
      .from("lemonsquad_sessions")
      .select("cookies_json, expires_at, pending_challenge_url")
      .eq("user_id", userId)
      .maybeSingle();

    if (!BROWSERLESS_TOKEN) {
      return json({
        ok: false,
        stage: "not_configured",
        message:
          "Agent scaffolding is live but headless browser (BROWSERLESS_TOKEN) " +
          "and a real form mapping are not wired yet. Ask the developer to add " +
          "BROWSERLESS_TOKEN and provide a Lemon Squad form screenshot.",
        action,
        userId,
        hasSession: !!session,
      });
    }

    // TODO: dispatch by action. Left as TODO until browser + form are known.
    // switch (action) {
    //   case "sync_requests":    return await syncRequests(supabase, cred, session);
    //   case "start_draft":      return await startDraft(supabase, cred, session, body);
    //   case "resume_after_mfa": return await resumeAfterMfa(supabase, cred, session);
    // }

    return json({ ok: true, action, message: "Skeleton reached; real logic pending." });
  } catch (e) {
    console.error("lemonsquad-agent error", e);
    return json({ error: e instanceof Error ? e.message : "Unknown error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
