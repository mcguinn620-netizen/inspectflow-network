// DEV-only impersonation helpers. Vite tree-shakes `import.meta.env.DEV` in prod.
import type { AppRole } from "@/hooks/useUserRoles";

export interface DebugUser {
  id: string;
  full_name: string | null;
  email?: string | null;
  organization_id: string;
  organization_name: string | null;
  role: AppRole;
}

const STORAGE_KEY = "debugUserID";
const STORAGE_USER_KEY = "debugUserPayload";

export function isDebugMode(): boolean {
  return Boolean(import.meta.env.DEV);
}

export function loadDebugUser(): DebugUser | null {
  if (!isDebugMode()) return null;
  try {
    const raw = localStorage.getItem(STORAGE_USER_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as DebugUser;
  } catch {
    return null;
  }
}

export function loadDebugUserId(): string | null {
  if (!isDebugMode()) return null;
  return localStorage.getItem(STORAGE_KEY);
}

export function saveDebugUser(user: DebugUser): void {
  if (!isDebugMode()) return;
  localStorage.setItem(STORAGE_KEY, user.id);
  localStorage.setItem(STORAGE_USER_KEY, JSON.stringify(user));
  // Notify same-tab listeners (storage event only fires cross-tab).
  window.dispatchEvent(new Event("debug-user-changed"));
}

export function clearDebugUser(): void {
  localStorage.removeItem(STORAGE_KEY);
  localStorage.removeItem(STORAGE_USER_KEY);
  window.dispatchEvent(new Event("debug-user-changed"));
}

export type RoleGroup = "admin" | "manager" | "dispatcher" | "inspector" | "client";

export function roleGroup(role: AppRole | string): RoleGroup {
  switch (role) {
    case "super_admin":
    case "network_admin":
    case "company_admin":
      return "admin";
    case "repair_shop_manager":
    case "fleet_manager":
      return "manager";
    case "dispatcher":
      return "dispatcher";
    case "client":
      return "client";
    default:
      return "inspector";
  }
}

export function roleBadgeClasses(role: AppRole | string): string {
  switch (roleGroup(role)) {
    case "admin":
      return "bg-red-500/15 text-red-600 dark:text-red-400 border-red-500/30";
    case "manager":
      return "bg-purple-500/15 text-purple-600 dark:text-purple-400 border-purple-500/30";
    case "dispatcher":
      return "bg-blue-500/15 text-blue-600 dark:text-blue-400 border-blue-500/30";
    case "inspector":
      return "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border-emerald-500/30";
    case "client":
      return "bg-slate-500/15 text-slate-600 dark:text-slate-400 border-slate-500/30";
  }
}

export function roleLabel(role: AppRole | string): string {
  return String(role)
    .split("_")
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join(" ");
}
