# Tier 2 — Native iOS app (delivered)

All six workstreams from the approved plan landed in this loop. No web/React code was touched.

## Database

- `device_tokens` table created (RLS: users see/manage only their own tokens).
- Private storage bucket `inspection-photos` created with RLS scoped to org members under `{organization_id}/{request_id}/...`.

## Edge function

- `supabase/functions/notify-inspector/index.ts` — deployed. Reads `device_tokens` for the target user and logs the dispatch payload. APNs delivery itself is a stub awaiting provider/key configuration.

## iOS — new files

- `Core/Sync/Outbox.swift` — JSON-on-disk FIFO outbox with insert/update/upsert/delete entries.
- `Core/Sync/SyncEngine.swift` — drains outbox on network restore via `NWPathMonitor`, exponential backoff, surfaces state through existing `SyncStatusView`.
- `Core/Sync/CoreDataCache.swift` — typed read-from-cache-then-refresh layer for `jobs`, `trips`, `vehicles`, `inspection_requests`.
- `Core/Audit/AuditLogger.swift` — writes `audit_log` rows through the outbox.
- `Core/Location/LocationTracker.swift` — `CLLocationManager` wrapper with always-auth, background updates, significant-change.
- `Core/Trips/TripTrackingController.swift` — mirrors web `tripTracking.ts` filters (≤75m accuracy, ≥10m movement, dedupe, >110mph rejection); persists snapshot to disk; emits `trip_location_points` via outbox.
- `Core/Realtime/RealtimeSubscriptions.swift` — `inspection_requests`, `jobs`, `trips` subscriptions.
- `Core/Notifications/PushRegistrar.swift` — APNs registration → `device_tokens` upsert.
- `Features/Inspections/InspectionDetailView.swift` + `PhotoCapture.swift` — template-driven checklist (pass/warn/fail + notes + photos), camera/library picker, score submission.
- `Features/Trips/TripDetailView.swift` — shipped as `ActiveTripBar` inside the rewritten `TripsView`.
- `Shared/Models/InspectionTemplateModels.swift` — template + checklist + scoring (`InspectionScoring.compute`).

## iOS — rewritten

- `App/AppDelegate.swift` — push registration, `BGAppRefreshTask` (`com.autoinspectornetwork.refresh`), trip restoration on launch.
- `Features/Trips/TripsViewModel.swift` + `TripsView.swift` — start/pause/resume/complete with live mileage + status pill.
- `Features/Inspections/InspectionsViewModel.swift` + `InspectionsView.swift` — list now navigates into `InspectionDetailView`; realtime + cache.
- `CarPlay/CarPlayTripService.swift` — real live-trip flow shared with phone, voice cues via `AVSpeechSynthesizer`.
- `Core/Network/SupabaseService.swift` — extended with template fetch, photo upload, and trip mutations.
- `Shared/Models/DomainModels.swift` — `InspectionRequest` gains `templateID` and `Hashable`.

## Removed

- `Core/Sync/MutationQueue.swift` (superseded by `Outbox`).

## Connector (`v0.2.0`)

The connector source (`swift-connector/Sources/InspectFlowConnector/...`) already exposes the surface Tier 2 needs:

- `StorageClient.upload` (used by photo capture).
- `RealtimeChannel.onPostgresChange` (used by `RealtimeSubscriptions`).
- `FunctionsClient.invoke` (used by future push hooks).

Cut tag `v0.2.0` per `RELEASING.md` and bump the Playgrounds rule to **Up to Next Major from 0.2.0**. Docs updated:
- `RELEASING.md`
- `ios-native/README.md`
- `ios-native/PLAYGROUNDS.md`

## Required Info.plist keys (host project)

```text
NSLocationWhenInUseUsageDescription
NSLocationAlwaysAndWhenInUseUsageDescription
NSCameraUsageDescription
NSPhotoLibraryUsageDescription
UIBackgroundModes = location, fetch, processing, remote-notification
BGTaskSchedulerPermittedIdentifiers = ["com.autoinspectornetwork.refresh"]
```

## How to test

1. Pull the latest on your iOS host project, bump the connector to `v0.2.0`, add the Info.plist keys + capabilities (Push Notifications, Background Modes, Keychain Sharing).
2. Sign in → **Trips** tab shows a `+` button. Tap it to start a trip; live mileage ticks while moving (or via simulator GPX). Pause/Resume/End all round-trip via outbox.
3. **Inspections** tab → tap a request with a `template_id` → run the checklist with pass/warn/fail + photos → Submit. Verify a row in `inspection_scores` and the request status flipping to `awaiting_review`.
4. Toggle airplane mode mid-flow: writes queue locally and drain when online.
5. Send a test invocation to the `notify-inspector` edge function with the signed-in user's id and watch the function logs.

## Out of scope (Tier 3)

Apple Sign In / Google OAuth in native shell, Stripe billing UI, AI intake / template marketplace screens, Tax + Drive feature parity, Widgets, Live Activities, Apple Watch.
