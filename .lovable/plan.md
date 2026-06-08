## iOS native fixes (Xcode 14 / iOS 16 / Swift 5.7 compatible)

Four problems, all in `ios-native/` + connector. Each fix is scoped and uses APIs available in iOS 16 (no `ContentUnavailableView`, no iOS 17-only `.onChange` two-arg form).

---

### 1. Intake Review — "Convert" fails with "resource exceeds maximum size"

**Root cause:** `QueryBuilder.select()` hard-overwrites `method = "GET"` (see `swift-connector/Sources/InspectFlowConnector/Database/QueryBuilder.swift:23-25`). When `SupabaseService.convertIntakeItem` calls `.insert(payload).select().execute()` (`ios-native/Core/Network/SupabaseService.swift:265-269`), the chain turns into a bare `GET /inspection_requests` that fetches every row in the table. The response is huge, `URLSession` throws `NSURLErrorDataLengthExceedsMaximum` → "resource exceeds maximum size", and no row is ever inserted.

**Fix:**
- In `QueryBuilder.select()`, only set `method = "GET"` when it's still the default (i.e. when no mutation has been chained). Track an `isMutating` flag set by `insert/update/upsert/delete` and skip the method swap in that case — PostgREST already returns the inserted row when `Prefer: return=representation` is set, and `?select=` works on POST/PATCH/DELETE.
- Also stop appending duplicate `return=representation` in `single()` when a mutation is in flight.
- In `convertIntakeItem`, decode the inserted row from the POST response directly: `.insert(payload).select("*").single().execute()` should round-trip a single `InspectionRequest` after the fix, with no follow-up GET.

### 2. Intake Review — inspector can't "pull to themselves"

Today the Review sheet only has Close / Convert / Dismiss. Inspectors have no way to claim the resulting inspection.

**Fix:**
- Add `claimInspectionRequest(requestId:inspectorId:)` to `SupabaseService` — `PATCH inspection_requests` setting `assigned_inspector_id = auth.uid()` and `status = "assigned"`.
- In `IntakeReviewView`, add a "Convert & assign to me" button next to Convert. It calls `convertIntakeItem` then `claimInspectionRequest` with `appState.currentUserID` in one task, then closes the sheet and refreshes the inbox.
- Gate visibility behind `appState.effectiveRole == "inspector"` (always allow for admin/dispatcher too).

### 3. Schedule screen blank for jobs that exist (IMG_9182 / IMG_9180)

`ScheduleView` shows the week header but every day cell renders empty even though "1 job today" exists. Two causes:
1. The current `LazyVGrid` 7-column layout has nothing for the user to scan vertically — it looks blank and doesn't match Apple Calendar.
2. Jobs whose `scheduledAt` lands on a UTC boundary slip into the wrong column because matching uses `Calendar.current.isDate(_:inSameDayAs:)` on the raw decoded `Date` without normalising to the device timezone first.

**Fix — rebuild as an Apple Calendar-style week view:**
- New `ScheduleWeekView` (in `ios-native/Features/Schedule/Components/ScheduleWeekView.swift`) modelled on iOS Calendar's week tab:

```text
┌────────────────────────────────────────────────────────┐
│  Sun 7  Mon 8  Tue 9  Wed 10  Thu 11  Fri 12  Sat 13   │   ← day header strip, today highlighted
├────────────────────────────────────────────────────────┤
│ 7 AM │                                                  │
│ 8 AM │   ┌──────────┐                                   │
│ 9 AM │   │ Verity   │                                   │
│10 AM │   │ 9:00 AM  │                                   │
│ …    │   └──────────┘                                   │   ← hour rows × 7 day columns
│ 6 PM │                  ┌──────────┐                    │
│ 7 PM │                  │ AAMCO    │                    │
└──────┴──────────────────┴──────────┴────────────────────┘
```

- Hour rail on the left (6 AM – 9 PM), 7 day columns, jobs rendered as positioned blocks computed from `scheduledAt` (hour + minute → vertical offset, 60-min default height).
- Today's column tinted with `accentColor.opacity(0.08)`; current-time line drawn across today only.
- Tapping a block opens the existing `JobDetailView`; long-press keeps the existing context menu (assign, calendar sync, maps).
- Swipe horizontally to change weeks (`DragGesture` updating `selectedWeekStart`).
- Replace day-match logic with `Calendar.current.startOfDay(for:)` comparisons so timezone offsets stop hiding jobs.
- Keep the existing List view available behind a `Picker("View", selection:)` segmented control (List / Week) so users still get the simple list when they want it.

Falls back cleanly on iOS 16: no `TimelineView` requirements, only `GeometryReader` + `ZStack`.

### 4. Vehicles & Inspections — empty list and no way to add

`VehiclesView` and `InspectionsView` currently only show a "No vehicles" / "No inspection requests" placeholder with no `+` action, even though `VehicleEditSheet`, `VehicleEditViewModel`, and `JobCreateView` already exist.

**Fix — Vehicles:**
- Add a trailing `ToolbarItem` with a `+` button that presents `VehicleEditSheet` in create mode.
- After the sheet returns success, call `viewModel.load(orgId:)` to refresh.
- When the list is empty, still show a CTA button ("Add vehicle") in the empty state so a tap from a clean install always works.
- Audit `VehiclesViewModel.load` — confirm it queries `vehicles` filtered by `organization_id` and not by a deleted `vehicle_status` field; surface decode errors into `errorMessage` so the user sees why the list is empty instead of silent emptiness.

**Fix — Inspections:**
- Add a trailing `+` button that pushes `JobCreateView` (already implemented) wrapped to create an inspection request rather than a job, or — simpler — route to a new `InspectionRequestCreateView` that posts to `inspection_requests` with the current org id and defaults (`status = "request_received"`, `template_name = "Standard Inspection"`).
- Empty state mirrors Vehicles: shows a CTA button.
- Verify `InspectionsViewModel.load` filters by `organization_id = appState.activeOrganizationID` and not by `assigned_inspector_id`, which is why an inspector currently sees nothing until a dispatcher routes work to them. For inspector role keep an "Assigned to me" / "All in org" toggle in the toolbar so they can still see unassigned items they're allowed to claim.

---

## Technical notes

- All new views use iOS 16-safe APIs: `NavigationStack`, `Sheet(item:)`, `Picker(.segmented)`, `GeometryReader`. Avoid `ContentUnavailableView`, `Observation`, and the two-parameter `.onChange` closure.
- QueryBuilder change is additive — no other call sites depend on `select()` flipping the method, but I'll grep `swift-connector` + `ios-native` for `.insert(...).select(` and `.update(...).select(` to confirm before shipping.
- Add a unit test in `ios-native/Tests/InspectFlowConnectorTests/` that builds an `.insert(...).select().single()` request and asserts `httpMethod == "POST"` and `Prefer` contains `return=representation`.
- No backend / RLS / migrations needed — `inspection_requests` already allows org-scoped insert and update.

## Files touched

- `swift-connector/Sources/InspectFlowConnector/Database/QueryBuilder.swift` — preserve mutation method when `select()` chained.
- `ios-native/Core/Network/SupabaseService.swift` — fix `convertIntakeItem`, add `claimInspectionRequest`, add `createInspectionRequest`.
- `ios-native/Features/Intake/IntakeReviewView.swift` — "Convert & assign to me" action + error handling.
- `ios-native/Features/Schedule/ScheduleView.swift` + new `Components/ScheduleWeekView.swift` — Apple Calendar-style week view, timezone-correct filtering, List/Week toggle.
- `ios-native/Features/Vehicles/VehiclesView.swift` — toolbar `+`, empty-state CTA, present `VehicleEditSheet`.
- `ios-native/Features/Inspections/InspectionsView.swift` + new `InspectionRequestCreateView.swift` — toolbar `+`, assigned/all toggle, empty-state CTA.
- `ios-native/Tests/InspectFlowConnectorTests/QueryBuilderInsertSelectTests.swift` — regression test for the convert fix.
- `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` — register the new Swift files.

## Verification

- Build succeeds on Xcode 14 toolchain via `xcodebuild -scheme AutoInspectorNetwork -destination 'generic/platform=iOS Simulator'` (sanity only, run locally).
- New unit test passes.
- Manual: intake → Convert no longer errors; "Convert & assign to me" puts the job in the inspector's Jobs tab; Schedule week view shows the AAMCO Verity job on Mon 8 at 6:38 PM; Vehicles and Inspections tabs each show a `+` that opens a working create flow and the new record appears after save.
