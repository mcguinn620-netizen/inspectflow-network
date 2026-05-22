# Step 3.5 proposal — minimal native scope

This proposal keeps Step 3.5 intentionally small and consistent with the existing Tier 3 validation style.

## Goal mapping to `.lovable/plan.md`

Required outputs:
1. Native `StartMyDayCard`, `NextStopCard`, `ActiveTripBanner` components.
2. Voice-cue toggle for non-CarPlay driving.
3. Inspector dashboard becomes home tab for inspector role.

## Minimal code changes

### 1) Add Inspector dashboard composition surface

- Add `ios-native/Features/Dashboard/InspectorDashboardHomeView.swift`.
- Compose cards in this order:
  - `ActiveTripBanner`
  - `NextStopCard`
  - `StartMyDayCard`
  - existing `todayCard`/quick stats from `DashboardView` if needed
- Reuse `DashboardViewModel` data (`todayJobCount`, `activeTrip`) to avoid new API calls.

Why minimal: this avoids a full Dashboard rewrite and just adds an inspector-focused variant.

### 2) Add three native card/banner components

Create new files under `ios-native/Features/Dashboard/Components/`:

- `StartMyDayCard.swift`
  - Inputs: `hasJobsToday`, `todayJobCount`, `activeTripStatus`, `onStartTrip`, `onOpenSchedule`.
  - Mirrors web branching (active trip hidden; paused/draft resume; jobs today start route; empty state).

- `NextStopCard.swift`
  - Inputs: `trip`, `nextStop`, `progress`, callbacks for `arrive`, `complete`, `navigate`.
  - Keeps lifecycle calls in one place (existing trip lifecycle helpers/services).

- `ActiveTripBanner.swift`
  - Sticky top banner in dashboard scroll.
  - Shows progress + quick actions (pause/resume/open trips/drive).

Why minimal: isolate new UI as leaf components, minimizing risk to existing screens.

### 3) Voice-cue toggle (inspector driving aid)

- Add a persisted setting in `ios-native/Core/Auth/AppState.swift` (or a small settings store):
  - `@AppStorage("inspector.voice_cues_enabled") var voiceCuesEnabled = true`
- Expose toggle in `ios-native/Features/Settings/SettingsView.swift` under new section:
  - `Toggle("Voice cues while driving", isOn: ...)`
- Read flag from drive/trip UI entry points (`DriveView` and/or `TripTrackingController`) before playing spoken cues.

Why minimal: AppStorage-backed boolean gives immediate persistence without schema/migration work.

### 4) Inspector role gets dashboard as default home tab

- Update `ios-native/App/MainTabView.swift` to be role-aware:
  - If inspector role, first tab is `InspectorDashboardHomeView` (label can remain “Dashboard”).
  - Non-inspector roles keep existing `DashboardView` first-tab path.
- If role is not currently present on `UserProfile`, add role retrieval from membership in bootstrap and expose a resolved `effectiveRole` on `AppState`.

Why minimal: role switch only affects first-tab view selection, not global navigation.

## Suggested implementation notes (smallest viable)

- Keep all new components purely presentational at first; pass actions down from container.
- Prefer existing `AINCard`, `AINStatusPill`, `AINButton` primitives for visual consistency.
- Do not introduce a new networking layer or new outbox event types in 3.5.

## Validation script pattern (aligned with 3.3/3.4)

Add script:

- `ios-native/scripts/validate_step_3_5_inspector_flow.py`

Pattern: same static token checks used in step 3.3/3.4 scripts.

Recommended checks:

1. `Features/Dashboard/Components/StartMyDayCard.swift`
   - `struct StartMyDayCard`
   - `Start my day`
   - `Resume trip`

2. `Features/Dashboard/Components/NextStopCard.swift`
   - `struct NextStopCard`
   - `Next stop`
   - `Complete stop`

3. `Features/Dashboard/Components/ActiveTripBanner.swift`
   - `struct ActiveTripBanner`
   - `Open trips`
   - `Pause`

4. `Features/Settings/SettingsView.swift`
   - `Voice cues while driving`

5. `App/MainTabView.swift`
   - `InspectorDashboardHomeView`
   - `role`

Expected output string:

`OK: Step 3.5 inspector daily flow scaffolding is present.`

This keeps CI cost low and is consistent with existing step validators.
