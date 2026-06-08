// intake-parse-pdf
// Accepts { storage_path, organization_id, source_address?, subject? }, downloads
// a PDF from the `intake-files` bucket, extracts text with unpdf, creates an
// intake_item with channel='manual_pdf' and the extracted text, then invokes
// intake-parse for LLM parsing + auto-create.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@0.12.1";
import { corsHeaders } from "../_shared/cors.ts";

function sanitize(s: string): string {
  return (s ?? "")
    .replace(/\u0000/g, "")
    // eslint-disable-next-line no-control-regex
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, " ");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const storagePath: string | undefined = body.storage_path;
    const orgId: string | undefined = body.organization_id ?? Deno.env.get("INTAKE_DEFAULT_ORG_ID") ?? undefined;
    const sourceAddress: string | null = body.source_address ?? null;
    const subject: string | null = body.subject ?? null;
    const channel: string = body.channel ?? "manual_pdf";

    if (!storagePath || !orgId) {
      return new Response(JSON.stringify({ error: "storage_path and organization_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Download PDF bytes
    const dl = await admin.storage.from("intake-files").download(storagePath);
    if (dl.error || !dl.data) {
      throw new Error(`storage download failed: ${dl.error?.message ?? "unknown"}`);
    }
    const bytes = new Uint8Array(await dl.data.arrayBuffer());

    // Extract text
    const pdf = await getDocumentProxy(bytes);
    const { text } = await extractText(pdf, { mergePages: true });
    const cleanText = sanitize(Array.isArray(text) ? text.join("\n") : String(text)).slice(0, 200_000);

    if (cleanText.trim().length < 5) {
      throw new Error("PDF contained no extractable text");
    }

    // Insert intake_item
    const dedupe = `pdf:${orgId}:${storagePath}`;
    const { data: item, error } = await admin.from("intake_items").insert({
      organization_id: orgId,
      channel,
      source_ref: storagePath,
      source_address: sourceAddress,
      subject: sanitize(subject ?? storagePath.split("/").pop() ?? "PDF"),
      raw_text: cleanText,
      raw_payload: { storage_path: storagePath, bytes: bytes.length },
      dedupe_hash: dedupe,
      status: "new",
    }).select("id").single();

    if (error && error.code !== "23505") throw error;

    let parseResult: unknown = null;
    if (item?.id) {
      const { data: pr } = await admin.functions.invoke("intake-parse", {
        body: { intake_item_id: item.id },
      });
      parseResult = pr;
    }

    return new Response(JSON.stringify({
      ok: true,
      intake_item_id: item?.id ?? null,
      parse: parseResult,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    console.error("intake-parse-pdf error:", e);
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Unknown" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
