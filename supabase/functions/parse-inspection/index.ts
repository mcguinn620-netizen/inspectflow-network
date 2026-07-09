import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const { text, source_type, image_url } = await req.json();
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    if (!LOVABLE_API_KEY) throw new Error("LOVABLE_API_KEY is not configured");

    const systemPrompt = `You are an automotive inspection request parser. Extract structured data from unstructured inspection requests (emails, forms, auction sheets, dealer requests, or photos of forms).

Extract these fields:
- client_name: The person or contact requesting the inspection
- company_name: The company or dealership name
- vin: Vehicle Identification Number (17 characters)
- vehicle_year: Year of the vehicle
- vehicle_make: Make/manufacturer
- vehicle_model: Model name
- mileage: Vehicle mileage if mentioned
- inspection_location: Where the inspection should occur
- requested_date: When they want the inspection done
- inspection_type: Type of inspection requested
- notes: Any additional relevant notes

Also determine:
- template_name: Based on keywords:
  - If "Verity" is mentioned → "Verity Checklist"
  - If "APC" is mentioned → "APC Checklist"
  - If "Pre-Purchase" is mentioned → "Pre-Purchase Inspection"
  - If "Lease Return" is mentioned → "Lease Return"
  - If "Fleet" is mentioned → "Fleet Audit"
  - If "Lender" is mentioned → "Lender Inspection"
  - Otherwise → "Standard Inspection"
- priority: "high" if urgent/ASAP/rush mentioned, "low" if flexible/no rush, otherwise "medium"
- vin_valid: true if VIN is exactly 17 alphanumeric characters (no I, O, Q), false otherwise

Return ONLY valid JSON with these exact keys. Use null for fields you cannot determine.`;

    const userContent: unknown = image_url
      ? [
          { type: "text", text: `Parse this ${source_type ?? "image"} inspection request from the attached image. If additional text is provided, treat it as supplementary context:\n\n${text ?? ""}` },
          { type: "image_url", image_url: { url: image_url } },
        ]
      : `Parse this ${source_type ?? "email"} inspection request:\n\n${text ?? ""}`;

    const response = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LOVABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "google/gemini-3-flash-preview",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        tools: [
          {
            type: "function",
            function: {
              name: "extract_inspection_data",
              description: "Extract structured inspection request data",
              parameters: {
                type: "object",
                properties: {
                  client_name: { type: "string", nullable: true },
                  company_name: { type: "string", nullable: true },
                  vin: { type: "string", nullable: true },
                  vehicle_year: { type: "string", nullable: true },
                  vehicle_make: { type: "string", nullable: true },
                  vehicle_model: { type: "string", nullable: true },
                  mileage: { type: "string", nullable: true },
                  inspection_location: { type: "string", nullable: true },
                  requested_date: { type: "string", nullable: true },
                  inspection_type: { type: "string", nullable: true },
                  template_name: { type: "string" },
                  priority: { type: "string", enum: ["low", "medium", "high"] },
                  vin_valid: { type: "boolean" },
                  notes: { type: "string", nullable: true },
                },
                required: ["template_name", "priority", "vin_valid"],
                additionalProperties: false,
              },
            },
          },
        ],
        tool_choice: { type: "function", function: { name: "extract_inspection_data" } },
      }),
    });

    if (!response.ok) {
      if (response.status === 429) {
        return new Response(JSON.stringify({ error: "Rate limit exceeded. Please try again in a moment." }), {
          status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      if (response.status === 402) {
        return new Response(JSON.stringify({ error: "AI credits exhausted. Please add credits." }), {
          status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const t = await response.text();
      console.error("AI gateway error:", response.status, t);
      throw new Error(`AI gateway error: ${response.status}`);
    }

    const data = await response.json();
    const toolCall = data.choices?.[0]?.message?.tool_calls?.[0];
    
    let parsed;
    if (toolCall) {
      parsed = JSON.parse(toolCall.function.arguments);
    } else {
      // Fallback: try to parse from content
      const content = data.choices?.[0]?.message?.content || "";
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        parsed = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error("Could not parse AI response");
      }
    }

    return new Response(JSON.stringify({ parsed }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("parse-inspection error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
