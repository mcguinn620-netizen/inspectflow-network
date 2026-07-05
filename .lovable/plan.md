# Disable login for now + add a role picker with test users

Goal: temporarily bypass the real Supabase login so anyone hitting the app lands on a **Role Picker** that switches between all 10 app roles. Real auth code stays fully intact so we can flip it back on with a single flag.

## Behavior
- On visit → land on `/pick-role` (new page). Choose a role → app "signs you in" as that role's test user → routed to the right workspace.
- A small floating "Switch role" chip in the corner (dev-only) to jump back to the picker from any page.
- Toggle: `VITE_AUTH_BYPASS` env flag (default **on** for now). When off, everything reverts to real Supabase auth with zero code changes.

## Test users (one per role, all 10)
| Role | Display name | Fake email |
|---|---|---|
| super_admin | Sam Superadmin | super@test.local |
| network_admin | Nina Networkadmin | network@test.local |
| company_admin | Cam Companyadmin | company@test.local |
| repair_shop_manager | Riley Shopmanager | shop@test.local |
| inspector | Ivy Inspector | inspector@test.local |
| technician | Theo Technician | tech@test.local |
| client | Cleo Client | client@test.local |
| fleet_manager | Fran Fleetmanager | fleet@test.local |
| mechanic | Max Mechanic | mechanic@test.local |
| dispatcher | Dana Dispatcher | dispatch@test.local |

Each test user gets a stable fake UUID and a fake org id, stored in a single `MOCK_USERS` table in code.

## Technical plan (kept small, real auth untouched)

1. **New** `src/lib/authBypass.ts`
   - `export const AUTH_BYPASS = import.meta.env.VITE_AUTH_BYPASS !== "false";` (default on)
   - `MOCK_USERS` array (role, id, email, full_name, org_id, org_name)
   - `getMockUser()` / `setMockUser(role)` — persisted in `localStorage` under `mock_auth_role`.

2. **Edit** `src/hooks/useAuth.tsx` — add a bypass branch **at the top** of `AuthProvider`. When `AUTH_BYPASS` is true, skip all Supabase calls and expose a minimal fake `User`/`Session` built from the selected mock user. `signOut()` clears the mock role and returns to picker. Real Supabase branch below stays byte-identical.

3. **Edit** `src/hooks/useUserRoles.ts` — same bypass branch at the top: when on, return `roles`/`memberships`/`activeOrgId`/`isAdmin` derived from the mock user, no Supabase reads.

4. **New** `src/pages/PickRole.tsx` — grid of 10 role cards (title, description, "Enter as …" button). Clicking calls `setMockUser(role)` then navigates:
   - inspector → `/app/inspector/dashboard`
   - mechanic → `/app/mechanic/dashboard`
   - dispatcher → `/app/dispatch/dashboard`
   - super_admin / network_admin / company_admin → `/`
   - repair_shop_manager → `/repair-shop`
   - client → `/client-portal`
   - fleet_manager → `/dispatch`
   - technician → `/app/inspector/dashboard`

5. **New** `src/components/DevRoleSwitcher.tsx` — small fixed bottom-right pill showing current role + "Switch". Mounted globally, only when `AUTH_BYPASS`.

6. **Edit** `src/App.tsx`
   - Add `<Route path="/pick-role" element={<PickRole />} />`
   - When `AUTH_BYPASS` and no mock role selected, `ProtectedRoute` redirects to `/pick-role` instead of `/auth`.
   - Mount `<DevRoleSwitcher />` alongside `<InstallPrompt />`.
   - `HomeRedirect` respects mock role too (admins → `Index`, others → their workspace).

7. **No DB changes.** No Supabase writes. RLS-guarded queries will simply return empty for mock users — pages should already handle empty states. (If a specific page misbehaves with a fake user, we'll patch it in a follow-up.)

## What stays intact (re-enable later by setting `VITE_AUTH_BYPASS=false`)
- `src/pages/Auth.tsx` — unchanged, route `/auth` still mounted.
- All Supabase auth calls in `useAuth` and `useUserRoles` — unchanged, just gated behind the bypass branch.
- All RLS policies and DB triggers — unchanged.

## Out of scope
- Creating real Supabase auth users for each role (mock-only for now).
- Seeding demo data per role.
- Removing or refactoring `Auth.tsx`.
