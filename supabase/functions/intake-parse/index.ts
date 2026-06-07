// intake-parse
// Invoked after an intake_item is created. Calls parse-inspection, writes
// parsed_data + confidence + status. If VIN is valid and confidence is high,
// auto-creates an inspection_request and marks the item auto_created.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const VIN_RE = /^[A-HJ-NPR-Z0-9]{17}$/;

function scoreParsed(p: Record<string, unknown> | null): number {
  if (!p) return 0;
  const keys = [
    "client_name", "company_name", "vin", "vehicle_year", "vehicle_make",
    "vehicle_model", "inspection_location", "requested_date",
  ];
  const present = keys.filter((k) => p[k] != null && String(p[k]).trim() !== "").length;
  const vinValid = (p as { vin_valid?: boolean }).vin_valid === true ? 0.2 : 0;
  return Math.min(1, present / keys.length * 0.8 + vinValid);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { intake_item_id } = await req.json();
    if (!intake_item_id) {
      return new Response(JSON.stringify({ error: "intake_item_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: item, error: loadErr } = await supabase
      .from("intake_items")
      .select("*")
      .eq("id", intake_item_id)
      .single();
    if (loadErr || !item) throw new Error(loadErr?.message || "intake_item not found");

    await supabase.from("intake_items").update({ status: "parsing" }).eq("id", item.id);

    const sourceType =
      item.channel === "telegram" ? "email" :
      item.channel === "web_link" ? "email" :
      item.channel === "outlook" ? "email" :
      item.channel === "gmail" ? "email" : "email";

    const text = (item.raw_text ?? "").toString();
    if (text.trim().length < 5) {
      await supabase.from("intake_items")
        .update({ status: "error", error: "raw_text empty" })
        .eq("id", item.id);
      return new Response(JSON.stringify({ error: "raw_text empty" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: parseRes, error: parseErr } = await supabase.functions.invoke("parse-inspection", {
      body: { text, source_type: sourceType },
    });
    if (parseErr) throw parseErr;
    if (parseRes?.error) throw new Error(parseRes.error);

    const parsed = parseRes.parsed as Record<string, unknown>;
    const vinValid = typeof parsed.vin === "string" && VIN_RE.test(parsed.vin as string);
    (parsed as { vin_valid: boolean }).vin_valid = vinValid;
    const confidence = scoreParsed(parsed);
    const autoEligible = vinValid && confidence >= 0.85;

    let inspectionRequestId: string | null = null;
    let nextStatus: "auto_created" | "needs_review" = "needs_review";

    if (autoEligible) {
      const { data: ins, error: insErr } = await supabase
        .from("inspection_requests")
        .insert({
          client_name: parsed.client_name ?? null,
          company_name: parsed.company_name ?? null,
          vin: parsed.vin ?? null,
          vehicle_year: parsed.vehicle_year ?? null,
          vehicle_make: parsed.vehicle_make ?? null,
          vehicle_model: parsed.vehicle_model ?? null,
          mileage: parsed.mileage ?? null,
          inspection_location: parsed.inspection_location ?? null,
          requested_date: parsed.requested_date ?? null,
          inspection_type: parsed.inspection_type ?? null,
          template_name: parsed.template_name ?? "Standard Inspection",
          priority: parsed.priority ?? "medium",
          status: "request_received",
          notes: parsed.notes ?? null,
        })
        .select("id")
        .single();
      if (!insErr && ins) {
        inspectionRequestId = ins.id;
        nextStatus = "auto_created";
      }
    }

    await supabase.from("intake_items").update({
      parsed_data: parsed,
      confidence,
      status: nextStatus,
      inspection_request_id: inspectionRequestId,
      error: null,
    }).eq("id", item.id);

    await supabase.from("audit_log").insert({
      action: nextStatus === "auto_created" ? "auto_create_from_intake" : "intake_parsed",
      entity_type: "intake_item",
      entity_id: item.id,
      changes: { confidence, vin_valid: vinValid, inspection_request_id: inspectionRequestId },
    });

    return new Response(JSON.stringify({
      ok: true, status: nextStatus, confidence, inspection_request_id: inspectionRequestId,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    console.error("intake-parse error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
