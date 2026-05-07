
# Tier 1 Plan — Finish `ios-native/` as "Auto Inspector Network"

Goal: take the existing `ios-native/` scaffold to a real, runnable, pure-SwiftUI app that authenticates against Lovable Cloud, lists live data from a few core tables, and compiles cleanly in **Xcode 14 (iOS 16+)** and **Swift Playgrounds 4+ on iPad**. No Capacitor, no third-party SDKs.

---

## 1. Compatibility constraints (applied to every file)

- `swift-tools-version:5.7` in `swift-connector/Package.swift` (currently 5.9-style).
- iOS deployment target: **16.0**.
- No `#Preview` macro, no Swift 5.9 macros, no `Observation` framework. Use `PreviewProvider` + `ObservableObject`/`@Published`.
- No `NavigationStack` features that require iOS 17. `NavigationStack` itself is iOS 16 — OK.
- Networking: `URLSession` + `async/await` only (already the case).
- No SwiftData. Core Data only (already the case).
- Swift Playgrounds: keep the connector as a single SwiftPM package with **zero external deps** so `.swiftpm` projects can `Add Package` from a local path or Git URL.

---

## 2. Rebrand to "Auto Inspector Network"

Scope: native iOS only. Web app naming is left alone.

Changes:
- Rename folder `ios-native/` → `ios-native-ain/` *(optional; keeping `ios-native/` is fine — confirm in build mode)*.
- App display name: **Auto Inspector Network**, short name: **AIN**.
- Bundle ID suggestion: `com.autoinspectornetwork.ios` (placeholder until you set your team).
- Rename Swift types/files:
  - `InspectionApp.swift` → `AutoInspectorNetworkApp.swift`, `struct InspectionApp` → `struct AutoInspectorNetworkApp`.
  - Keychain service in `KeychainStore`: `com.autoinspectornetwork.ios.session`.
- Update `ios-native/README.md` title, intro, and "Next steps" to AIN branding.
- Update `swift-connector/InspectFlowConfig.swift` default `keychainService` → `com.autoinspectornetwork.connector` (kept overridable).
- Add an `AINBrand.swift` with display name, tagline, primary color tokens (Deep Navy / Electric Blue per project memory) so views reference one source.

No SQL or web changes required for the rebrand.

---

## 3. Wire `ios-native/` to the real backend via `swift-connector`

### 3a. Add the connector as a local SwiftPM dependency
- Document in README how to add `swift-connector/` as a local package in Xcode 14 (File ▸ Add Packages ▸ Add Local).
- For Swift Playgrounds: same package, added as a Git URL once pushed, or via "Add Package" on iPad.

### 3b. Replace placeholder `SupabaseConfig.swift`
Wire to the real values already in `.env`:
- `baseURL` = `https://aqtcgybbqdyjasgnuwlh.supabase.co`
- `anonKey` = current publishable key

Keep them in a `SupabaseConfig` enum (compile-time constants) — anon key is publishable, safe to commit.

### 3c. Rewrite `SupabaseService.swift`
Replace the placeholder with a thin wrapper around `InspectFlowClient`:
- Single shared `InspectFlowClient` instance built from `SupabaseConfig`.
- `signIn(email:password:)`, `signUp(email:password:fullName:)`, `signOut()`.
- `fetchMyProfile(userId:)` → `client.db.from("profiles").select().eq("id", userId).single()`.
- `fetchTrips(userId:)` → `client.db.from("trips").select().eq("user_id", userId).order("created_at", desc: true).limit(50)`.
- `fetchTodayJobs(orgId:)` → `client.db.from("jobs").select().eq("organization_id", orgId).is("deleted_at", nil)`.
- `fetchInspectionRequests(orgId:)`, `fetchVehicles(orgId:)` — read-only Tier 1.

### 3d. AppState bootstrap
- On launch: read session from `KeychainStore` (already exists) — but switch its writes to be driven by `AuthClient` callbacks via a small `SessionBridge` so we don't double-store.
- If session present: fetch profile, then `signedIn`. Otherwise `signedOut`.

### 3e. Real `AuthView` + `AuthViewModel`
- Email/password sign-in form (already stubbed).
- Add toggle for Sign Up (full name + email + password).
- Show inline error label, loading spinner.
- On success → `AppState.authState = .signedIn(profile)`.
- "Sign out" button in `SettingsView`.

### 3f. Live `TripsView`
- Replace placeholder list with `@StateObject TripsViewModel` that calls `SupabaseService.fetchTrips`.
- Pull-to-refresh + empty state + error state.
- Each row: date, status badge, miles, started_at time.

### 3g. Light wiring for the other tabs (read-only, minimum viable)
Just enough to prove the connector works end-to-end:
- `DashboardView`: today's job count + trip status summary (one query each).
- `JobsView`: list jobs for active org.
- `VehiclesView`: list vehicles.
- `InspectionsView`: list inspection_requests with status.
- `ScheduleView`, `DriveView`, `TaxView`: keep placeholders with a "Coming in Tier 2" card. Marked clearly in code.

### 3h. SyncEngine / MutationQueue
- Keep current scaffolding but mark `// TODO: Tier 2` for write replay. Tier 1 stays read-only to keep credit cost predictable.

---

## 4. Swift Playgrounds compatibility

- Add `ios-native/PLAYGROUNDS.md` with steps:
  1. Open Swift Playgrounds → New App.
  2. Add Package → paste the Git URL of `swift-connector/` (or copy the `Sources/InspectFlowConnector` folder into the Playground's `Modules` if offline).
  3. Drag the contents of `ios-native/App`, `Core`, `Features`, `Shared` into the Playground.
  4. Set capabilities: Keychain Sharing, Background Modes (Location) — optional for Tier 1.
- Avoid any file that imports `CarPlay` from being part of the Playgrounds target. Move `ios-native/CarPlay/*` behind `#if canImport(CarPlay)` guards (most of it already is, will verify and add where missing).
- Avoid `UIApplicationDelegateAdaptor` issues by keeping `AppDelegate` minimal and `#if canImport(UIKit)`-guarded where needed.

---

## 5. Capacitor / unneeded files — what to remove

You currently have **two** native trees that are not needed once `ios-native/` is the path forward:

**Safe to delete (Capacitor):**
- `ios/` (entire folder — Capacitor Xcode workspace, including the unrelated NutriTrack sample under `ios/App/App/NutriTrack/`)
- `capacitor.config.ts`
- `native/android/InspectorCarAppService.java` and `native/README.md` (Android Auto stub, not used by iOS path)
- `package.json` deps (only when you're ready): `@capacitor/*`, `@ebarooni/capacitor-calendar`, `@transistorsoft/capacitor-background-geolocation`
- `src/platform/native.ts` Capacitor branches (keep web fallbacks)

**Keep:**
- `swift-connector/` (this is what we're depending on)
- `ios-native/` (the new app)
- `docs/native/CARPLAY_CONTRACT.md`, `docs/native/BACKGROUND_LOCATION_SETUP.md` — useful reference
- All `src/`, `supabase/`, web app stays untouched

I will **not** delete these in Tier 1. I'll generate a single PR-style commit at the end with a `CLEANUP.md` listing exact paths to remove, and you approve before I run the deletions in a follow-up. Reason: deleting Capacitor changes the build of the existing web→native pipeline; want your sign-off first.

---

## 6. File-by-file change list

New:
- `ios-native/App/AutoInspectorNetworkApp.swift` (replaces `InspectionApp.swift`)
- `ios-native/Shared/Brand/AINBrand.swift`
- `ios-native/Core/Network/SupabaseClientProvider.swift` (singleton `InspectFlowClient`)
- `ios-native/Core/Auth/SessionBridge.swift`
- `ios-native/Features/Trips/TripsViewModel.swift`
- `ios-native/Features/Auth/AuthViewModel.swift` *(replaces inline VM in AuthView)*
- `ios-native/Features/Dashboard/DashboardViewModel.swift`
- `ios-native/Features/Jobs/JobsViewModel.swift`
- `ios-native/Features/Vehicles/VehiclesViewModel.swift`
- `ios-native/Features/Inspections/InspectionsViewModel.swift`
- `ios-native/PLAYGROUNDS.md`
- `ios-native/CLEANUP.md` (your approval doc for removing Capacitor)

Edited:
- `swift-connector/Package.swift` — `swift-tools-version:5.7`
- `ios-native/Core/Network/SupabaseConfig.swift` — real URL + anon key
- `ios-native/Core/Network/SupabaseService.swift` — real implementation
- `ios-native/Core/Auth/AppState.swift` — uses real auth flow
- `ios-native/Features/Auth/AuthView.swift` — real form + sign-up toggle
- `ios-native/Features/Trips/TripsView.swift` — live data
- `ios-native/Features/{Dashboard,Jobs,Vehicles,Inspections}/*View.swift` — live data
- `ios-native/Features/Settings/SettingsView.swift` — adds Sign Out
- `ios-native/Shared/Models/DomainModels.swift` — align Codable keys to DB columns (snake_case via `CodingKeys`)
- `ios-native/README.md` — AIN branding + Xcode 14 + Playgrounds instructions
- Any CarPlay file missing a `#if canImport(CarPlay)` guard — add it

Deleted: **none in Tier 1.** Cleanup happens after your approval of `CLEANUP.md`.

---

## 7. Risks / things you should know

- The `swift-connector` `QueryBuilder`, `AuthClient`, `RealtimeChannel` etc. were scaffolds — I'll likely need small fixes (header handling, decode helpers) when wiring real calls. Budgeted in the estimate.
- `InspectFlowClient` exposes Realtime, Storage, Functions but Tier 1 only exercises Auth + DB. Realtime smoke test is included as one Trips subscription so we know it compiles + connects.
- Domain models in `DomainModels.swift` are currently simplified. I'll extend the ones we actually query (Trip, Job, Vehicle, Profile, InspectionRequest) to match the DB schema; the rest stay as-is.

---

## 8. Credit estimate for Tier 1

~**18–24 credits** to implement everything above:
- Connector polish + Package.swift bump: 2
- Auth wiring (Service + AppState + AuthView/VM + Sign Out): 4
- 5 feature view-models + view rewrites (Trips, Dashboard, Jobs, Vehicles, Inspections): 8–10
- Branding rename + README + PLAYGROUNDS.md + CLEANUP.md: 3
- Compatibility guards (CarPlay #if, swift-tools-version, model CodingKeys): 2
- Buffer for connector bugs surfaced once we make real HTTP calls: 2–3

Capacitor cleanup (after your approval) is a separate ~2–3 credits.

---

## 9. What I will NOT do in Tier 1 (Tier 2 candidates)

- Offline write replay via `MutationQueue`
- CarPlay live trip integration
- Background location (`NWPathMonitor` already present, but no real BG task wiring)
- Push notifications
- Photo capture / Storage uploads
- Full Inspection runner UI

---

Reply **"go"** to switch to build mode and execute Tier 1, or tell me what to trim/add (e.g. "skip Inspections + Vehicles", "add CarPlay", "do the Capacitor cleanup in the same pass").
