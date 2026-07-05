import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { AUTH_BYPASS, getMockUser, MOCK_USERS } from "@/lib/authBypass";


export type AppRole =
  | "super_admin"
  | "network_admin"
  | "company_admin"
  | "repair_shop_manager"
  | "inspector"
  | "technician"
  | "client"
  | "fleet_manager"
  | "mechanic"
  | "dispatcher";

export interface OrgMembership {
  organization_id: string;
  role: AppRole;
  is_default: boolean;
  organization_name?: string;
}

export function useUserRoles() {
  const { user } = useAuth();
  const [roles, setRoles] = useState<AppRole[]>([]);
  const [memberships, setMemberships] = useState<OrgMembership[]>([]);
  const [activeOrgId, setActiveOrgId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (AUTH_BYPASS) {
      const m = getMockUser();
      if (!m) {
        setRoles([]);
        setMemberships([]);
        setActiveOrgId(null);
        setLoading(false);
        return;
      }
      setRoles([m.role]);
      setMemberships([
        { organization_id: m.org_id, role: m.role, is_default: true, organization_name: m.org_name },
      ]);
      setActiveOrgId(m.org_id);
      setLoading(false);
      return;
    }
    if (!user) {
      setRoles([]);
      setMemberships([]);
      setActiveOrgId(null);
      setLoading(false);
      return;
    }

    let cancelled = false;
    (async () => {
      setLoading(true);
      const { data: orgUsers } = await supabase
        .from("organization_users")
        .select("organization_id, role, is_default, organizations(name)")
        .eq("user_id", user.id);

      const { data: extra } = await supabase
        .from("user_roles")
        .select("role")
        .eq("user_id", user.id);

      if (cancelled) return;
      const mapped: OrgMembership[] = (orgUsers ?? []).map((m: any) => ({
        organization_id: m.organization_id,
        role: m.role,
        is_default: m.is_default,
        organization_name: m.organizations?.name,
      }));
      setMemberships(mapped);
      const allRoles = new Set<AppRole>([
        ...mapped.map((m) => m.role),
        ...((extra ?? []).map((r: any) => r.role) as AppRole[]),
      ]);
      setRoles(Array.from(allRoles));
      const def = mapped.find((m) => m.is_default) ?? mapped[0];
      setActiveOrgId(def?.organization_id ?? null);
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [user]);

  const hasRole = (r: AppRole) => roles.includes(r);
  const isAdmin =
    hasRole("super_admin") || hasRole("network_admin") || hasRole("company_admin");

  return { roles, memberships, activeOrgId, hasRole, isAdmin, loading };
}
