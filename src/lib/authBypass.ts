import type { AppRole } from "@/hooks/useUserRoles";

export const AUTH_BYPASS = import.meta.env.VITE_AUTH_BYPASS !== "false";

export interface MockUser {
  role: AppRole;
  id: string;
  email: string;
  full_name: string;
  org_id: string;
  org_name: string;
  landing: string;
  description: string;
}

export const MOCK_USERS: MockUser[] = [
  {
    role: "super_admin",
    id: "00000000-0000-4000-8000-000000000001",
    email: "super@test.local",
    full_name: "Sam Superadmin",
    org_id: "00000000-0000-4000-9000-000000000001",
    org_name: "Platform HQ",
    landing: "/",
    description: "Full platform access across every organization.",
  },
  {
    role: "network_admin",
    id: "00000000-0000-4000-8000-000000000002",
    email: "network@test.local",
    full_name: "Nina Networkadmin",
    org_id: "00000000-0000-4000-9000-000000000002",
    org_name: "Regional Network",
    landing: "/",
    description: "Manages a network of companies and inspectors.",
  },
  {
    role: "company_admin",
    id: "00000000-0000-4000-8000-000000000003",
    email: "company@test.local",
    full_name: "Cam Companyadmin",
    org_id: "00000000-0000-4000-9000-000000000003",
    org_name: "Acme Inspections",
    landing: "/",
    description: "Runs a single company: staff, templates, billing.",
  },
  {
    role: "repair_shop_manager",
    id: "00000000-0000-4000-8000-000000000004",
    email: "shop@test.local",
    full_name: "Riley Shopmanager",
    org_id: "00000000-0000-4000-9000-000000000004",
    org_name: "Riley's Auto Body",
    landing: "/repair-shop",
    description: "Manages a repair shop and incoming work orders.",
  },
  {
    role: "inspector",
    id: "00000000-0000-4000-8000-000000000005",
    email: "inspector@test.local",
    full_name: "Ivy Inspector",
    org_id: "00000000-0000-4000-9000-000000000005",
    org_name: "Ivy's Workspace",
    landing: "/app/inspector/dashboard",
    description: "Field inspector: jobs, trips, drive mode, tax.",
  },
  {
    role: "technician",
    id: "00000000-0000-4000-8000-000000000006",
    email: "tech@test.local",
    full_name: "Theo Technician",
    org_id: "00000000-0000-4000-9000-000000000006",
    org_name: "Acme Inspections",
    landing: "/app/inspector/dashboard",
    description: "Shop technician performing assigned inspections.",
  },
  {
    role: "client",
    id: "00000000-0000-4000-8000-000000000007",
    email: "client@test.local",
    full_name: "Cleo Client",
    org_id: "00000000-0000-4000-9000-000000000007",
    org_name: "Cleo (Client)",
    landing: "/client-portal",
    description: "End customer tracking their inspection and repairs.",
  },
  {
    role: "fleet_manager",
    id: "00000000-0000-4000-8000-000000000008",
    email: "fleet@test.local",
    full_name: "Fran Fleetmanager",
    org_id: "00000000-0000-4000-9000-000000000008",
    org_name: "BlueLine Fleet",
    landing: "/dispatch",
    description: "Manages a fleet of vehicles and dispatches jobs.",
  },
  {
    role: "mechanic",
    id: "00000000-0000-4000-8000-000000000009",
    email: "mechanic@test.local",
    full_name: "Max Mechanic",
    org_id: "00000000-0000-4000-9000-000000000009",
    org_name: "Max's Garage",
    landing: "/app/mechanic/dashboard",
    description: "Mechanic reviewing failed items and estimates.",
  },
  {
    role: "dispatcher",
    id: "00000000-0000-4000-8000-000000000010",
    email: "dispatch@test.local",
    full_name: "Dana Dispatcher",
    org_id: "00000000-0000-4000-9000-000000000010",
    org_name: "Acme Dispatch",
    landing: "/app/dispatch/dashboard",
    description: "Assigns and routes inspection jobs.",
  },
];

const STORAGE_KEY = "mock_auth_role";

export function getMockUser(): MockUser | null {
  if (typeof window === "undefined") return null;
  const role = window.localStorage.getItem(STORAGE_KEY) as AppRole | null;
  if (!role) return null;
  return MOCK_USERS.find((u) => u.role === role) ?? null;
}

export function setMockUser(role: AppRole) {
  window.localStorage.setItem(STORAGE_KEY, role);
  window.dispatchEvent(new Event("mock-auth-change"));
}

export function clearMockUser() {
  window.localStorage.removeItem(STORAGE_KEY);
  window.dispatchEvent(new Event("mock-auth-change"));
}
