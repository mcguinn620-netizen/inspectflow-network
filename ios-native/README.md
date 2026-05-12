# Auto Inspector Network — Native iOS

Pure-SwiftUI iOS app for the **Auto Inspector Network** (AIN) platform. Targets **Xcode 14** and **iOS 16+**, with **Swift Playgrounds 4+** (iPad) compatibility.

## Architecture

- `App/` — `@main` entry (`AutoInspectorNetworkApp`), tab shell, root auth routing
- `Core/` — auth/app state, networking facade, Core Data, sync engine, mutation queue
- `Features/` — route-aligned SwiftUI feature modules (Dashboard, Schedule, Jobs, Trips, Drive, Tax, Vehicles, Inspections, Settings, Auth)
- `Shared/` — domain models, brand tokens, reusable UI
- `CarPlay/` — CarPlay scenes (guarded with `#if canImport(CarPlay)`)

## Backend

The app talks to **Lovable Cloud** through the local Swift package at `../swift-connector/` (`InspectFlowConnector`). No third-party SDKs.

- Auth: email/password sign-in & sign-up
- DB: PostgREST (`profiles`, `organization_users`, `trips`, `jobs`, `vehicles`, `inspection_requests`)
- Session is persisted in Keychain by `InspectFlowConnector.SessionStore`

## Setup (Xcode 15+)

A ready-to-build Xcode project is checked in at
`ios-native/AutoInspectorNetwork.xcodeproj`. It already references every
source file under `ios-native/`, the local `InspectFlowConnector` Swift
package at the repo root, the bundled `Info.plist`, `Assets.xcassets`,
and `AutoInspectorNetwork.entitlements`.

1. Open `ios-native/AutoInspectorNetwork.xcodeproj` in Xcode 15 or newer.
2. Select the `AutoInspectorNetwork` target → **Signing & Capabilities** and
   pick your team (the project ships with team `95VG5GW59K` — change it).
3. Capabilities already declared via the entitlements/Info.plist:
   - **Push Notifications** (`aps-environment = development`)
   - **Background Modes**: Location updates, Background fetch,
     Background processing, Remote notifications
   - `BGTaskSchedulerPermittedIdentifiers = ["com.autoinspectornetwork.refresh"]`
   - All required usage strings (Location, Camera, Photo Library)
4. Build & Run on a device (background location and push require a real device).

> CarPlay templates are included as source but the **CarPlay entitlement**
> (`com.apple.developer.carplay-maps` / `carplay-driving-task`) requires
> separate approval from Apple. The app builds and runs without it; CarPlay
> functionality activates once Apple grants the entitlement and you add it
> to `AutoInspectorNetwork.entitlements`.

## Bitrise CI

`bitrise.yml` at the repo root defines two workflows that target this project:

- `build` — runs on every push to `main`. Resolves SPM, then
  `xcode-build-for-test` for the iOS Simulator (no signing required).
- `archive_and_export_app` — runs on PRs into `main`. Installs certs/profiles,
  archives, and exports an IPA using automatic Apple ID signing.

Both workflows use these envs (see `app.envs` in `bitrise.yml`):

```
BITRISE_PROJECT_PATH = ios-native/AutoInspectorNetwork.xcodeproj
BITRISE_SCHEME       = AutoInspectorNetwork
```

No `npm`/Capacitor steps are involved — the web app is independent.

The publishable backend URL and anon key are baked into `Core/Network/SupabaseConfig.swift`.

## Setup (Swift Playgrounds on iPad)

See `PLAYGROUNDS.md`.

## Compatibility notes

- `swift-tools-version:5.7`, no Swift 5.9 macros (no `#Preview`, no `@Observable`).
- `NavigationStack` (iOS 16) is used throughout.
- Networking is `URLSession` + `async/await`.
- All CarPlay code is wrapped in `#if canImport(CarPlay)` so the app builds on simulators and Swift Playgrounds without it.

## Tier 2 scope (this build)

- **Trips:** start / pause / resume / complete with live `CLLocationManager` tracking. Filters and persistence mirror `src/lib/tripTracking.ts` (≤75m accuracy, ≥10m movement, dedupe, >110mph rejection). Active trip survives relaunch via Keychain-backed snapshot.
- **Inspections:** template-driven checklist (pass / warn / fail + notes + photos). Photos upload to the `inspection-photos` bucket under `{org_id}/{request_id}/`. Submit computes a weighted condition score, writes `inspection_scores`, and transitions the request to `awaiting_review`.
- **Offline core:** `Outbox` (JSON-on-disk FIFO) replaces the in-memory mutation queue. `SyncEngine` drains on network restore with exponential backoff. `CoreDataCache` mirrors lists for read-from-cache-then-refresh.
- **Realtime:** per-feature subscriptions to `inspection_requests`, `jobs`, and `trips`.
- **CarPlay:** live trip card sharing the phone's `TripTrackingController`, with `AVSpeechSynthesizer` voice cues.
- **Push + background:** APNs registration writes to `device_tokens`. `BGAppRefreshTask` (`com.autoinspectornetwork.refresh`) drains the outbox hourly. Edge function `notify-inspector` is the dispatch hook.

## Cleanup

See `CLEANUP.md` at the repo root for the list of Capacitor/legacy files that can be removed once you confirm this native app is the path forward.
