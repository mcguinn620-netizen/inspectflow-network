# DEBUG Auth Bypass + User Impersonation

Parallel DEBUG-only path for both iOS and Web that lets you pick any user and impersonate their org + role without passwords. Production auth is untouched.

## Scope guardrails

- Additive only. No changes to Supabase Auth, sign-in screens, RLS, or production code paths.
- iOS gated by `#if DEBUG`. Web gated by `import.meta.env.DEV` (Vite strips dead branches in prod).
- No DB schema changes. Reads from existing `profiles`, `organization_users`, `organizations`.
- Role badge colors map onto the existing 8-role system in `useUserRoles`.

## Backend

No new tables or edge functions. Both clients query:

```text
profiles  ⋈  organization_users  ⋈  organizations
order by full_name
```

Email is unavailable client-side without service role, so the picker shows full_name + org + role (email optional/blank).

## iOS deliverables

New files:
1. `Core/Debug/DebugUser.swift` — model
2. `Core/Debug/DebugUserService.swift` — `fetchDebugUsers()` / `fetchOne(id:)`
3. `App/DebugUserPickerView.swift` — searchable list, avatar initials, role pill, large rows
4. `Shared/UI/AINDebugBanner.swift` — slim amber banner, tap to re-pick
5. `Shared/UI/AINRoleBadge.swift` — colored role pill

Edits:
6. `Core/Auth/AppState.swift` — `selectedDebugUser`, `debugSignIn(as:)`, `clearDebugUser()`
7. `App/RootView.swift` — DEBUG branch: no user → picker, user → MainTabView. Production branch unchanged.
8. `App/MainTabView.swift` — overlay `AINDebugBanner` in `#if DEBUG`
9. `Features/Settings/SettingsView.swift` — `#if DEBUG` "Developer Tools" section (current user/role/org + Switch / Clear / Reset)
10. `AutoInspectorNetwork.xcodeproj/project.pbxproj` — register 5 new files

Persistence: `@AppStorage("debugUserID")`. On launch, RootView hydrates and calls `debugSignIn`.

## Web deliverables

11. `src/lib/debugAuth.ts` — `isDebugMode()`, load/save/clear `localStorage.debugUserID`, role-group helper
12. `src/hooks/useDebugUser.tsx` — context provider; in dev overrides `effectiveRole` / `activeOrgId`
13. `src/components/debug/DebugUserPicker.tsx` — searchable list (name / email / org)
14. `src/components/debug/DebugBanner.tsx` — sticky amber bar above DashboardLayout header
15. `src/pages/DebugLogin.tsx` — `/debug` route
16. Edits to `src/App.tsx`, `src/components/DashboardLayout.tsx`, `src/hooks/useUserRoles.ts`

## Role badge mapping

| Group      | Roles                                            | Color  |
|------------|--------------------------------------------------|--------|
| Admin      | super_admin, network_admin, company_admin        | Red    |
| Manager    | repair_shop_manager, fleet_manager               | Purple |
| Dispatcher | dispatcher                                       | Blue   |
| Inspector  | inspector, technician, mechanic                  | Green  |
| Client     | client                                           | Slate  |

## Out of scope

- Creating fake users (impersonate existing only)
- RLS changes — iOS debug mode skips Supabase session; reads requiring org membership need a real JWT. Acceptable for UI/perm testing.

## Suggested rollout

1. iOS files 1–10
2. Web files 11–16

Approve one step at a time to control credit spend.
