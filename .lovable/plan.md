## Tier 2 — Native iOS app, all workstreams in order

Tier 1 (auth + read-only lists) ships. Tier 2 turns the app into a daily-driver field tool. Constraints carry over: **Xcode 14 / iOS 16 / Swift 5.7 / Swift Playgrounds 4 compatible**, no third-party SDKs, all backend access via local `InspectFlowConnector` package.

### Guardrails (reaffirmed)

- No Swift 5.9 features (`#Preview`, `@Observable`, macros). `NavigationStack` only.
- All CarPlay code stays behind `#if canImport(CarPlay)`.
- Soft-delete via `deleted_at`; audit-log all CUD; respect inspection lifecycle states; RLS via `is_org_member` / `has_role`.
- Connector is semver-tagged. Tier 2 ships as `v0.2.0` once new connector capabilities land; docs (`RELEASING.md`, `ios-native/PLAYGROUNDS.md`, `ios-native/README.md`) bumped to "Up to Next Major from 0.2.0".

### Execution order (each step shippable on its own)

**Step 1 — Offline-first sync core** *(unblocks every write flow)*
- Replace stub `Core/Sync/MutationQueue.swift` + `SyncEngine.swift` with Core-Data-backed `Outbox`:
  - New entity `OutboxEntry { id, table, op, payloadJSON, attemptCount, lastError, createdAt }` in `InspectionModel.xcdatamodeld`.
  - `Outbox.enqueue(...)`, FIFO drain on network restore (`NWPathMonitor`), exponential backoff, errors surfaced through existing `SyncStatusView`.
- Add `Core/Sync/CoreDataCache.swift` for local mirrors of `jobs`, `trips`, `vehicles`, `inspection_requests`, `inspection_templates` (read-from-cache-then-refresh pattern).
- New `Core/Audit/AuditLogger.swift` writes to `audit_log` after every successful CUD (action + entity_type + entity_id + JSON changes).

**Step 2 — Trips: write flow + live tracking**
- Extend `TripsViewModel`: `start()`, `pause()`, `resume()`, `complete()` writing through Outbox to `trips` and `trip_stops`.
- New `Core/Location/LocationTracker.swift` wrapping `CLLocationManager` (standard + significant-change, `allowsBackgroundLocationUpdates`, `pausesAutomatically=false`).
- Mirror web filters from `src/lib/tripTracking.ts`: accuracy ≤75m, ≥10m movement, reject >110mph jumps, dedupe <1.5s/3m. Batch-insert `trip_location_points` (size 8 / 6s) and bump `trips.total_miles`.
- Restore active trip on launch from a Keychain-persisted snapshot (mirrors `restoreTripTrackingFromStorage`).
- Info.plist: `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationWhenInUseUsageDescription`, `UIBackgroundModes = location, fetch`.
- New `Features/Trips/TripDetailView.swift` with start/pause/resume/complete + live mileage + tracking status pill.

**Step 3 — Inspections: perform + submit**
- New `Features/Inspections/InspectionDetailView.swift` and `ChecklistView.swift` driven by template snapshot (`inspection_templates` → `template_sections` → `template_checklist_items` + `template_required_photos` + `template_special_instructions`).
- Item states: pass / warning / fail + notes + photo attachments (multi).
- `Features/Inspections/PhotoCapture.swift` using `UIImagePickerController` (Xcode-14 friendly, Playgrounds-safe). Uploads through `InspectFlowConnector.storage` to a new `inspection-photos` bucket; rows tracked locally so capture works offline and uploads drain via Outbox.
- Compute weighted condition score client-side (per `mem://features/scoring-system`); write `inspection_scores` and update `inspection_requests.status` honoring the 7-state lifecycle (`mem://features/inspections`).
- All transitions logged via `AuditLogger`.

**Step 4 — Realtime subscriptions**
- New `Core/Realtime/RealtimeSubscriptions.swift` using `client.realtime`:
  - `inspection_requests` filtered by org → status changes update list.
  - `jobs` filtered by org → assignment + `scheduled_at` changes.
  - `trips` filtered by user → status + `total_miles` updates.
- One channel per feature view, torn down on `onDisappear`. View-models reconcile incoming rows with Core Data cache.

**Step 5 — CarPlay live trip**
- Promote `CarPlayTripService` from stubs to real flow: today's stops → tap → "Start Trip" → live mileage + next-stop card → "Arrived" / "Complete".
- Shares `LocationTracker` and Outbox with phone; CarPlay scene only renders state.
- Voice cues via `AVSpeechSynthesizer` for "Next stop is…" / "You have arrived" (mirrors `voiceCue.ts`).

**Step 6 — Push notifications + background fetch**
- `Core/Notifications/PushRegistrar.swift` registers via `UNUserNotificationCenter`; APNs token written to a new `device_tokens` row.
- Edge function `notify-inspector` sends APNs when a job is assigned or an inspection moves to `awaiting_review` / `repair_needed`.
- `BGAppRefreshTask` (id `com.autoinspectornetwork.refresh`) drains Outbox + refreshes active trip hourly.
- `AppDelegate` wires `didRegisterForRemoteNotificationsWithDeviceToken` and background task scheduling.

### Connector additions (v0.2.0)

Surgical extensions to the existing local package — no breaking changes:

- `StorageClient`: streamed/multipart upload helper for photo attachments with progress callback.
- `RealtimeChannel`: typed `on(_:table:filter:decode:)` returning decoded rows for `INSERT|UPDATE|DELETE`.
- `FunctionsClient`: typed `invoke<T,R>` with retry policy (used by push registration + future repair conversion).
- Tag `v0.2.0`, update `RELEASING.md` + `ios-native/PLAYGROUNDS.md` + `ios-native/README.md` to "Up to Next Major from 0.2.0".

### Database touches

Single migration:

- New table `device_tokens (id, user_id, token, platform, app_version, last_seen, created_at)` with RLS limiting users to rows where `user_id = auth.uid()`.
- New storage bucket `inspection-photos` (private) with RLS allowing org members to read/write under `{organization_id}/{inspection_id}/...`.
- No changes to existing tables — Tier 2 only consumes them.

### File map

```text
ios-native/
  App/
    AppDelegate.swift                        (push + BG tasks)
    Info.plist                               (location/push/BG keys)
  Core/
    Location/LocationTracker.swift           (new)
    Sync/Outbox.swift                        (new — replaces MutationQueue)
    Sync/SyncEngine.swift                    (rewrite)
    Sync/CoreDataCache.swift                 (new)
    Realtime/RealtimeSubscriptions.swift     (new)
    Notifications/PushRegistrar.swift        (new)
    Audit/AuditLogger.swift                  (new)
  Features/
    Trips/TripDetailView.swift               (new)
    Trips/TripsViewModel.swift               (extend)
    Inspections/InspectionDetailView.swift   (new)
    Inspections/ChecklistView.swift          (new)
    Inspections/PhotoCapture.swift           (new)
    Inspections/InspectionsViewModel.swift   (extend)
  CarPlay/
    CarPlayTripService.swift                 (rewrite — real live trip)
    CarPlayStopListTemplate.swift            (extend)
swift-connector/Sources/InspectFlowConnector/
  Storage/StorageClient.swift                (multipart + progress)
  Realtime/RealtimeChannel.swift             (typed handlers)
  Functions/FunctionsClient.swift            (typed invoke + retries)
supabase/
  migrations/<timestamp>_tier2.sql           (device_tokens + bucket + RLS)
  functions/notify-inspector/index.ts        (new)
docs/
  RELEASING.md, ios-native/README.md, ios-native/PLAYGROUNDS.md  (v0.2.0 bump)
```

### Out of scope (Tier 3)

Apple Sign In / Google OAuth in native shell, Stripe billing UI, AI intake / template marketplace screens, Tax + Drive feature parity, Widgets, Live Activities, Apple Watch.

### What I'll deliver per step

Each step ends with: code, a connector tag bump if it touched the package, doc updates, and a one-paragraph "how to test on device + Playgrounds" note. Approve this plan and I'll start at Step 1 (offline core), then proceed straight through Step 6.
