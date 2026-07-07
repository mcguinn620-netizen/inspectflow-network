# iOS auth bypass (parallel to `auth-bypass-web.md`)

Goal: iOS build opens straight into a test-user picker matching the web's 10 mock users, with real Supabase auth code kept intact so we can flip it back on.

## Toggle
- `AuthBypass.isEnabled` reads `AUTH_BYPASS` from `Info.plist` (accepts `YES`/`NO`, `true`/`false`, `1`/`0`, `on`/`off`).
- Default: **ON**. Both `ios-native/Info.plist` and `ios-native/AutoInspectorNetwork/Info.plist` ship `AUTH_BYPASS = YES`.
- Flip to `NO` (no code change) to restore real Supabase auth.

## Files added
- `ios-native/Core/Auth/AuthBypass.swift` — the flag.
- `ios-native/Core/Debug/MockUsers.swift` — hardcoded 10-user array; UUIDs, emails, names, org ids, roles identical to web `src/lib/authBypass.ts` so a mock account behaves the same across platforms.

## Files changed (drop `#if DEBUG`, respect bypass)
- `ios-native/Core/Debug/DebugUser.swift` — `DebugUser` struct available in Release; `DebugRoleGroup` enum.
- `ios-native/Core/Debug/DebugUserService.swift` — `fetchDebugUsers()` / `fetchOne(id:)` return `MockUsers.all` when bypass is on; Supabase query kept as fallback behind `#if DEBUG`.
- `ios-native/Core/Auth/AppState.swift` — `bootstrap()` loads stored mock user from `UserDefaults` when bypass is on; skips `SupabaseService.restoreAndValidateSession()`. `signOut()` under bypass returns to picker instead of calling Supabase.
- `ios-native/App/RootView.swift` — `.signedOut` always routes to `DebugUserPickerView` under bypass; `AuthView` fallback kept for real-auth mode behind `#if DEBUG`.
- `ios-native/App/DebugUserPickerView.swift` — no longer `#if DEBUG`-gated; banner + title switch copy based on bypass.
- `ios-native/Info.plist`, `ios-native/AutoInspectorNetwork/Info.plist` — `AUTH_BYPASS = YES`.

## Test users (source of truth in `MockUsers.swift`, mirrors web)
super_admin, network_admin, company_admin, repair_shop_manager, inspector, technician, client, fleet_manager, mechanic, dispatcher — same UUIDs / emails / org ids as web.

## Stays intact (re-enable by setting `AUTH_BYPASS=NO`)
- `Core/Auth/AuthView.swift`, `AuthViewModel.swift`, `SupabaseService.swift`.
- Supabase RLS, edge functions, CarPlay / Widget / Share-Extension targets.
- `DebugUserService.fetchFromSupabase()` (organization_users ⋈ profiles ⋈ organizations).

## Out of scope
- Real Supabase test-user seeding.
- Per-role demo data.
- Removing `AuthView`.
