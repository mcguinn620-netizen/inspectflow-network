## Goal

Produce static PNG mockups (iPhone 15 Pro frame, 393×852 @ 2x) showing every tier-2 surface in the native iOS app, saved to `/mnt/documents/` and embedded as artifacts in chat. No iOS simulator is available in this sandbox, so these are HTML/CSS renders of the actual SwiftUI layouts — pixel-faithful to the Swift source, not photographs of a running app.

## What "tier 2" covers (from the codebase)

Based on `ios-native/Features/...` and `ios-native/CarPlay/...`:

**Inspections**
1. `InspectionsView` — list of inspection requests with status + scheduled date, sync chip in nav bar
2. `InspectionDetailView` — sectioned checklist, Pass/Warn/Fail pills (emerald/amber/rose), notes field, camera button, Submit toolbar
3. `PhotoCapture` sheet — camera capture state

**Trips**
4. `TripsView` — empty state + populated list (date, status, miles, start time)
5. `TripsView` with `ActiveTripBar` — live trip chip, total miles monospaced, Pause/End buttons
6. `TripsView` paused state — Resume/End

**CarPlay (rendered in CarPlay-style template, not iPhone frame)**
7. `CarPlayStopListTemplate` — today's stops, "Mark arrived" / "Skip" actions

**Sync / Outbox**
8. `SyncStatusView` — all four states side-by-side (Synced/Syncing/Offline/Sync Failed) on a sample screen

## How

1. Build a single HTML file per screen using Tailwind-equivalent inline styles, matching:
   - `AINBrand.accent` for tint, SF Pro system font stack, iOS-native list/inset-grouped styling
   - Pass=emerald, Warn=amber, Fail=rose (per project memory)
   - Inter for body, system mono for miles/IDs
   - iPhone 15 Pro chrome (Dynamic Island, rounded corners, home indicator)
2. Render each via headless Chrome at 2x DPR → PNG
3. Save to `/mnt/documents/ios-tier2-{screen}.png`
4. QA every PNG by re-opening it (zoom into chips, pills, nav bar) before delivering
5. Reply with one `<presentation-artifact>` tag per PNG

## Out of scope

- No changes to any Swift file, project source, or repo state
- Not running xcodebuild / simulator
- Not building a runnable web prototype — these are static visual mockups only

## Deliverable

~8 PNG files in `/mnt/documents/`, each shown inline as an artifact, plus a one-line summary mapping each PNG to its SwiftUI view.