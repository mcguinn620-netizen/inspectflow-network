# DEBUG Auth Bypass + User Impersonation

Parallel DEBUG-only path for both iOS and Web that lets you pick any user and impersonate their org + role without passwords. Production auth is untouched.

## Scope guardrails

- Additive only. No changes to Supabase Auth, sign-in screens, RLS, or `useAuth` semantics in production builds.
- iOS gated by `#if DEBUG`. Web gated by `import.meta.env.DEV` (Vite — production builds set this to `false`, dead-code-eliminated).
- No DB schema changes. Reads from existing `profiles` + `organization_users` + `user_roles`.
- Role badge colors map onto the 8-role system already in `useUserRoles` (Admin = super/network/company admin, Manager = repair_shop_manager/fleet_manager, Dispatcher = dispatcher, Inspector = inspector/technician/mechanic, Client = client).

## Backend

No new tables / edge functions. A "debug user service" on each client just queries:

```
select p.id, p.full_name, ou.organization_id, o.name as organization_name, ou.role
from profiles p
join organization_users ou on ou.user_id = p.id
join organizations o on o.id = ou.organization_id
order by p.full_name;
```

Email comes from `auth.users` indirectly — we'll use `profiles.full_name` + a derived email-ish handle, and on web fall back to `supabase.auth.admin` is not available client-side, so we display `full_name` + org + role only (email left blank if unknown). This avoids needing a service-role edge function.

## iOS deliverables

New files (all wrapped in `#if DEBUG` where they reference debug-only state):

1. `ios-native/Core/Debug/DebugUser.swift` — `struct DebugUser: Identifiable, Codable` with `id, fullName, email?, organizationID, organizationName, role`.
2. `ios-native/Core/Debug/DebugUserService.swift` — `fetchDebugUsers() async throws -> [DebugUser]` using `SupabaseClientProvider.shared.db`.
3. `ios-native/App/DebugUserPickerView.swift` — searchable list (name / email / org), role pill, avatar initials, large rows, "Continue as" CTA.
4. `ios-native/Shared/UI/AINDebugBanner.swift` — slim amber banner "⚠ DEBUG USER MODE — {Name} ({Role})", tap to open picker.
5. `ios-native/Shared/UI/AINRoleBadge.swift` — reusable colored pill (Admin red, Manager purple, Dispatcher blue, Inspector green).

Edits:

6. `ios-native/Core/Auth/AppState.swift` — add `@Published var selectedDebugUser: DebugUser?` and `func debugSignIn(as user: DebugUser)` that sets `authState = .signedIn(syntheticProfile)`, `activeOrganizationID`, `effectiveRole`. No network call.
7. `ios-native/App/RootView.swift` — replace existing `debugLoginBypass` block with: if no `@AppStorage("debugUserID")` value -> `DebugUserPickerView`; else hydrate `AppState` and show `MainTabView`. Production `#else` branch unchanged.
8. `ios-native/App/MainTabView.swift` — overlay `AINDebugBanner` at the top inside `#if DEBUG` so it appears on every tab (Dashboard, Jobs, Schedule, Inspections, Trips, Vehicles).
9. `ios-native/Features/Settings/SettingsView.swift` — add `#if DEBUG` "Developer Tools" section: Current User / Role / Org rows + "Switch User", "Clear User", "Reset Debug Session" buttons.
10. `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` — register the 5 new files.

Persistence: `@AppStorage("debugUserID")` holds the UUID string; on launch `RootView` reads it, calls `DebugUserService.fetchOne(id:)` and hands to `AppState.debugSignIn(as:)`.

## Web deliverables

11. `src/lib/debugAuth.ts` — `isDebugMode()` (returns `import.meta.env.DEV`), `loadDebugUser()`, `saveDebugUser(u)`, `clearDebugUser()` against `localStorage.debugUserID`.
12. `src/hooks/useDebugUser.tsx` — context provider exposing `{ debugUser, setDebugUser, clearDebugUser }`. In dev, wraps `useAuth` and `useUserRoles` consumers so `effectiveRole` / `activeOrgId` come from the debug pick when set.
13. `src/components/debug/DebugUserPicker.tsx` — searchable list mirroring iOS picker; same query as backend section above.
14. `src/components/debug/DebugBanner.tsx` — sticky amber bar at top of `DashboardLayout` rendered only when `isDebugMode() && debugUser`.
15. `src/pages/DebugLogin.tsx` — `/debug` route rendering the picker. Auto-redirects to `/app/inspector/dashboard` after pick.
16. Edits:
    - `src/App.tsx` — wrap with `DebugUserProvider` (no-op in prod) and register `/debug` route.
    - `src/components/DashboardLayout.tsx` — render `<DebugBanner />` above the fixed header.
    - `src/hooks/useUserRoles.ts` — in dev, if a debug user is set, prefer their `role` / `organization_id` over the real Supabase fetch. Read code stays identical in prod.

Production safety: `isDebugMode()` returns `false` in prod, so `DebugBanner`, `/debug` route handler, and provider all short-circuit. Vite strips the dead branches.

## Role badge mapping

| Group      | Roles (AppRole)                                  | Color  |
|------------|--------------------------------------------------|--------|
| Admin      | super_admin, network_admin, company_admin        | Red    |
| Manager    | repair_shop_manager, fleet_manager               | Purple |
| Dispatcher | dispatcher                                       | Blue   |
| Inspector  | inspector, technician, mechanic                  | Green  |
| Client     | client                                           | Slate  |

Single helper `roleGroup(role)` lives in both `AINRoleBadge.swift` and `src/lib/debugAuth.ts` to keep colors consistent.

## Out of scope

- Creating fake users (we only impersonate existing ones).
- Editing RLS — debug picker still respects RLS via the real anon JWT for the actual signed-in dev account on web (so RLS-protected reads work as long as that JWT is present). On iOS, debug mode skips the Supabase session entirely; queries that need org membership will fail unless you keep a real session — acceptable for UI/perm testing.
- Production fallback if `import.meta.env.DEV` is somehow true in prod — Vite guarantees this.

## Steps (one approval at a time recommended)

1. iOS files 1–10 (debug picker + banner + AppState + RootView + Settings).
2. Web files 11–16 (provider + picker + banner + route + role override).
