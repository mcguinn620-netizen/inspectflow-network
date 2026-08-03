import { AUTH_BYPASS, MOCK_USERS } from "@/lib/authBypass";

const FUNCTIONS_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mock-read`;
const ANON_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string;

export type MockFilter = { column: string; op: "eq" | "neq" | "in" | "gte" | "lte" | "gt" | "lt" | "is"; value: unknown };

/** True when the app runs in auth-bypass mode with a mock user selected. */
export function isMockUserId(id: string | undefined | null): boolean {
  if (!AUTH_BYPASS || !id) return false;
  return MOCK_USERS.some((u) => u.id === id);
}

async function call(payload: Record<string, unknown>) {
  const res = await fetch(FUNCTIONS_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` },
    body: JSON.stringify(payload),
  });
  const body = await res.json();
  if (!res.ok || body.error) throw new Error(body.error ?? `mock-read failed (${res.status})`);
  return body;
}

/** Service-role read for mock users (RLS-protected tables return nothing without a session). */
export async function mockSelect<T = Record<string, unknown>>(
  mockUserId: string,
  table: string,
  opts: { filters?: MockFilter[]; order?: string; ascending?: boolean; limit?: number } = {},
): Promise<T[]> {
  const body = await call({
    op: "select",
    mock_user_id: mockUserId,
    table,
    filters: opts.filters ?? [],
    order: opts.order,
    ascending: opts.ascending !== false,
    limit: opts.limit ?? 100,
  });
  return (body.rows ?? []) as T[];
}

/** Service-role insert for mock users. `filters` must carry the organization_id scope check. */
export async function mockInsert<T = Record<string, unknown>>(
  mockUserId: string,
  table: string,
  values: Record<string, unknown>,
  filters: MockFilter[] = [],
): Promise<T> {
  const body = await call({ op: "insert", mock_user_id: mockUserId, table, values, filters });
  return body.row as T;
}

/** Service-role update for mock users. `filters` must carry the organization_id scope check. */
export async function mockUpdate<T = Record<string, unknown>>(
  mockUserId: string,
  table: string,
  id: string,
  values: Record<string, unknown>,
  filters: MockFilter[] = [],
): Promise<T> {
  const body = await call({ op: "update", mock_user_id: mockUserId, table, id, values, filters });
  return body.row as T;
}
