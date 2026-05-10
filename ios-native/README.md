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

## Setup (Xcode 14)

1. Open or create an iOS App project (iOS 16+, SwiftUI lifecycle).
2. **File ▸ Add Packages…** — either paste `https://github.com/mcguinn620-netizen/inspectflow-network.git` (Up to Next Major from `0.2.0`), or use **Add Local…** and select the repo root. Tagging is documented in `RELEASING.md`.
3. Add the contents of `ios-native/` to your app target (drag the `App`, `Core`, `Features`, `Shared`, `CarPlay` folders, "Create groups").
4. Add a Core Data model file named `InspectionModel.xcdatamodeld` (entities can be added later).
5. Capabilities: **Keychain Sharing**, **Push Notifications**, **Background Modes** (Location updates, Background fetch, Background processing, Remote notifications).
6. Info.plist keys required for Tier 2:
   - `NSLocationWhenInUseUsageDescription` — "Auto Inspector Network uses your location to track active trips."
   - `NSLocationAlwaysAndWhenInUseUsageDescription` — "Continues tracking your trip in the background and via CarPlay."
   - `NSCameraUsageDescription` — "Attach photos to inspection items."
   - `NSPhotoLibraryUsageDescription` — "Attach photos from your library to inspection items."
   - `UIBackgroundModes` = `location`, `fetch`, `processing`, `remote-notification`
   - `BGTaskSchedulerPermittedIdentifiers` = `["com.autoinspectornetwork.refresh"]`
7. Build & Run.

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
