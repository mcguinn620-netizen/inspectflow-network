import { supabase } from "@/integrations/supabase/client";

export async function logAudit(
  entityType: string,
  entityId: string,
  action: "create" | "update" | "delete",
  changes?: Record<string, { before: any; after: any }>,
  userId?: string
) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    await supabase.from("audit_log").insert({
      entity_type: entityType,
      entity_id: entityId,
      action,
      changes: changes as any,
      user_id: userId || user?.id || null,
    });
  } catch (e) {
    console.error("Audit log failed:", e);
  }
}
