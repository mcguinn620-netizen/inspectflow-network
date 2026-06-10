# Plan: CalendarKit Schedule, Unified Trips/Drive, and Native Settings/Profile

Three additions to the iOS native app. All web app, Supabase schema, and business logic stay unchanged — this is pure presentation + native integration.

Use all skills available for the following updates. And ensure iOS native app will compile when run in [bitrise.io](http://bitrise.io) or Xcode 14/ swift playgrounds.

## 1. CalendarKit-powered Schedule + EventKit export

Swap the hand-rolled `ScheduleWeekCalendarView` for [CalendarKit](https://github.com/richardtop/CalendarKit) (MIT, iOS 14+), keeping our `Job` data, `ScheduleConflictDetector`, and dispatcher flows as the source of truth. Layer EventKit on top so jobs can optionally appear in the user's personal iPhone Calendar.

### UX

- Picker becomes `Day` (CalendarKit, default) · `Week` (existing custom) · `List`.
- Day view: jobs as colored events using `AINTheme` (status-encoded); conflicted jobs get a red left border + ⚠︎; tap → `JobDetailView`; long-press → dispatcher assign sheet.
- Drag-to-move / resize gated behind a "Reschedule mode" toggle for dispatcher/admin only; calls a new `JobsViewModel.reschedule(job:newStart:durationMinutes:)`.
- All-day row used for blocked dates.
- New toolbar "Calendar Sync" menu: *Export visible week*, *Remove all synced events*. Per-event context menu: *Add to iPhone Calendar* / *Remove*.
- First use triggers `EKEventStore.requestAccess`; denial shows `AINFriendlyError` with "Open Settings".

### Files

- Add CalendarKit via SPM to `AutoInspectorNetwork.xcodeproj` (app target only), `from: "1.1.5"`. Not added to `Package.swift` (connector-only).
- New: `ios-native/Features/Schedule/CalendarKitDayView.swift` — `UIViewControllerRepresentable` wrapping `ScheduleDayViewController: DayViewController`; `JobEvent: Event` round-trips `Job`; overrides `eventsForDate`, `dayViewDidSelectEventView`, `dayViewDidLongPressEventView`, `dayView(_:didUpdate:)`. Styles built from `AINTheme`.
- New: `ios-native/Features/Schedule/ScheduleExportMenu.swift` — SwiftUI `Menu` wrapping `CalendarSyncService` calls with progress + banner messaging.
- Modify `ios-native/Features/Schedule/ScheduleView.swift` — add `"day"` segment (default), `@State selectedDate`, toolbar `ScheduleExportMenu`.
- Modify `ios-native/Features/Jobs/JobsViewModel.swift` — add `reschedule(job:newStart:durationMinutes:)` reusing existing update path.
- Modify `ios-native/Core/Calendar/CalendarSyncService.swift` — add `syncMany`, `removeAll(jobIDs:)`, `isSynced(jobID:)`.
- Modify `ios-native/Info.plist` — ensure `NSCalendarsUsageDescription` and `NSCalendarsWriteOnlyAccessUsageDescription` strings exist.

## 2. Unified Trips + Drive screen (Stride-style)

Today there are two separate tabs (`TripsView`, `DriveView`) and `MoreView` also links to Drive. The user-supplied screenshots show a single mileage/tax surface with a deductions list, a recorded-mileage detail, and a drive summary. Merge into one screen.

### UX

- Replace the `Trips` tab with a new `MileageView` tab (label: "Mileage", icon `car.fill`). Drop the standalone `Drive` link from `MoreView`.
- Top of `MileageView`:
  - Two large stat cells side-by-side: *YTD Deduction* (e.g., `$5,646.49`) and *YTD Miles* (e.g., `7,788.26 mi`). Year is selectable via a chevron menu in the nav title ("2026 Deductions ▾").
  - Segmented `Deductions` / `Income` control.
  - "Active trip" banner (the existing `ActiveTripBar`) shows when `TripTrackingController.shared.snapshot != nil`.
- List below: each row shows `$amount` on the left, `Mileage (x.xx mi)` + day on the right, chevron to push detail. Backed by `viewModel.trips` joined with `earnings_settings` for `$/mi` computation (reuse `src/lib/taxCalculator.ts` logic — port the per-mile rate calc into Swift in `Core/Tax/MileageDeduction.swift`).
- FAB-style center "+" in the tab bar opens a sheet with: `Add Mileage`, `Add Income`, `Add Expense`, `Track Miles` (matches screenshot IMG_9335). `Track Miles` triggers `viewModel.startTrip` (existing). `Add Mileage` opens manual entry sheet (new lightweight form writing to `trips` with manual start/end + miles). `Add Income`/`Add Expense` are stubs that route to existing earnings tables (kept minimal — TODO note for follow-up).
- Trip detail push (`MileageDetailView`) mirrors IMG_9337:
  - Header: Deduction `$x.xx` (green), Total Miles, Drive Time, Job Category, Start time, End time.
  - Map snapshot from `trip_location_points` polyline using `MapKit` `MKMapSnapshotter` with red Start/End pin annotations.
  - Bottom `Delete` button (destructive, confirms via `ConfirmDeleteDialog` equivalent).
  - Edit button in nav opens `MileageEditView` (IMG_9338): Drive Time, Job Category picker, Start/End time pickers — writes back via `SupabaseService.updateTrip`.
  - Save/Note variant (IMG_9339) reachable as `Drive Summary` immediately after a trip ends: shows tax deduction, time, distance, note field, map; persists `note` on the trip row.

### Files

- New tab: `ios-native/Features/Mileage/MileageView.swift` (extracted from `TripsView` + `DriveView`).
- New: `ios-native/Features/Mileage/MileageDetailView.swift`, `MileageEditView.swift`, `MileageSummaryView.swift`, `AddMileageActionSheet.swift`.
- New: `ios-native/Core/Tax/MileageDeduction.swift` — IRS rate + per-trip deduction calc (port of web `taxCalculator.ts`).
- New: `ios-native/Shared/UI/TripMapSnapshot.swift` — reusable `MKMapSnapshotter` SwiftUI view rendering a polyline + Start/End pins.
- Delete: `ios-native/Features/Drive/DriveView.swift` (functionality folded into `MileageDetailView`/active trip banner).
- Modify `ios-native/App/MainTabView.swift` — replace `TripsView` tab with `MileageView`, drop the Drive link from `MoreView`.
- Schema: add nullable `note text` and `job_category text` columns to `trips` if missing (migration step — yes/no will be requested via the migration tool during build).

## 3. Port Profile + Settings from web to native

The web app's `src/pages/Settings.tsx`, profile editing, role/org switching, and related sections aren't fully represented natively. Port them and wire to the same Supabase tables so behavior matches.

### Web → native mapping

- **Profile** (`profiles` table: `full_name`, `email`, avatar, phone):
  - New: `ios-native/Features/Profile/ProfileView.swift` + `ProfileViewModel.swift`. Editable form, avatar upload via `PhotosPicker` → Supabase Storage `avatars/` bucket (already exists for web).
- **Settings sections** (mirroring web tabs):
  - Account (email, password change → `supabase.auth.updateUser`).
  - Organization (membership list from `organization_users`; switch active org → updates `AppState.activeOrganizationID`; invite/leave actions for owners/admins).
  - Availability (read/write `availability_schedules` + `inspector_blocked_dates`; reuse the day-of-week + blocked-date editors from web).
  - Earnings & Tax (read/write `earnings_settings`, `quarterly_tax_overrides`).
  - Vehicles (link to existing `VehiclesView`).
  - Notifications (device tokens table, toggle per-event preferences).
  - Calendar Sync (link to the EventKit menu from §1 — single source of truth).
  - About / Legal / Sign out.
- **Role badge** in the nav uses existing `AINRoleBadge`.

### Files

- New: `ios-native/Features/Profile/ProfileView.swift`, `ProfileViewModel.swift`.
- New: `ios-native/Features/Settings/` files for each section: `AccountSettingsView.swift`, `OrganizationSettingsView.swift`, `AvailabilitySettingsView.swift`, `EarningsSettingsView.swift`, `NotificationSettingsView.swift`, `CalendarSyncSettingsView.swift`, `AboutView.swift`.
- Modify `ios-native/Features/Settings/SettingsView.swift` — restructure into a sectioned `List` with `NavigationLink`s to the new screens; keep `DeveloperToolsSection` under DEBUG.
- Modify `ios-native/App/MainTabView.swift` `MoreView` — add `Profile` link above `Settings`, remove items that are now nested inside Settings (Vehicles, Inspections move under Settings? — kept at top level for quick access, but cross-linked from Settings → Vehicles).
- Modify `ios-native/Core/Network/SupabaseService.swift` — add any missing fetch/update helpers (`fetchProfile`, `updateProfile`, `uploadAvatar`, `fetchAvailability`, `updateAvailability`, `fetchEarningsSettings`, `updateEarningsSettings`). Reuse existing query builder.
- All writes audit-logged via `AuditLogger.log(...)` per the project's audit-system memory.

## Validation

- Manual: Schedule day/week/list switching; drag-reschedule writes to Supabase; calendar export creates "InspectFlow Jobs" calendar in Apple Calendar. Mileage tab shows YTD totals, trip rows match `$/mi` from `earnings_settings`, "Track Miles" starts a live trip, edit/delete round-trips through Supabase. Profile edits persist; org switcher flips `AppState`; availability changes reflect on web.
- Build: `xcodebuild ... archive` (Bitrise pipeline already covers this).
- No new RLS policies needed — all tables already exist with policies; only adds two nullable columns on `trips`.

## Risks / Notes

- CalendarKit is UIKit; SwiftUI bridge is the only integration surface.
- EventKit is strictly additive — graceful degradation if user denies.
- `trips` column additions require an approved migration; surfaced via the migration tool during build.
- Stride-style "+" FAB embedded in a SwiftUI `TabView` requires a custom tab bar overlay; isolated to `MainTabView` to keep blast radius small.