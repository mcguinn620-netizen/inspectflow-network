# Native Schedule Architecture — Replace CalendarKit

Switch the iOS app's Schedule screen from CalendarKit to a pure Apple-native stack: **EventKit** for system calendar I/O, **SwiftData (iOS 17+) with a Core Data fallback (iOS 16)** for app-specific metadata, and **NavigationSplitView** for iPad/Mac multi-pane layout. The existing `Job` / Supabase pipeline stays intact — we layer the system-calendar mirror and local metadata around it.

## Goals

- One Schedule screen that works on iPhone, iPad, and Mac Catalyst.
- Live two-way bridge between Supabase `Job`s and the user's system Calendar (via `EKEventStore`).
- Per-job local metadata (custom category, checklist, rich notes) keyed by `Job.id` + `EKEvent.eventIdentifier`, persisted with SwiftData on iOS 17+ and Core Data on iOS 16.
- Adaptive layout: sidebar / center grid / inspector on regular width; stacked navigation on compact width.
- Remove CalendarKit SPM dependency entirely.

## File plan

New files under `ios-native/`:

```text
Core/
  Calendar/
    EventKitService.swift          // EKEventStore wrapper: auth, fetch, write, change notifications
    CalendarSyncBridge.swift       // Job <-> EKEvent reconciliation (replaces CalendarSyncService)
  Persistence/
    ScheduleMetadata.swift         // Shared protocol + DTO (EventMetadata)
    ScheduleMetadataStore.swift    // Protocol-driven facade; picks SwiftData or Core Data
    SwiftDataMetadataStore.swift   // @available(iOS 17, *) @Model EventMetadataSD
    CoreDataMetadataStore.swift    // iOS 16 fallback, NSPersistentContainer
    ScheduleMetadata.xcdatamodeld  // Core Data model mirroring SwiftData schema
Features/
  Schedule/
    ScheduleRootView.swift         // NavigationSplitView shell, size-class aware
    ScheduleSidebar.swift          // Calendar toggles, category filters, quick tags
    ScheduleContentView.swift      // Day / Week / Month switcher (native grids)
    ScheduleDayGrid.swift          // Hour rail + event blocks (replaces CalendarKitDayView)
    ScheduleWeekGrid.swift         // 7-col week (already partly exists — refactor)
    ScheduleMonthMatrix.swift      // Month grid for iPad/Mac
    EventInspectorView.swift       // Trailing pane: view/edit + metadata notes
    ScheduleViewModel.swift        // @Observable; merges Jobs + EKEvents + metadata
```

Files to remove / retire:

- `Features/Schedule/CalendarKitDayView.swift`
- `scripts/add_calendarkit_schedule.py`
- All `CalendarKit` SPM entries in `AutoInspectorNetwork.xcodeproj/project.pbxproj` (XCRemoteSwiftPackageReference, XCSwiftPackageProductDependency, Frameworks build file `CK00000000000000000000A3`, productDependencies entry).
- CalendarKit reference in `ios-native/Package.swift` if present.

Files to refactor (not rewrite):

- `Features/Schedule/ScheduleView.swift` → becomes thin entry that hosts `ScheduleRootView`.
- `Core/Calendar/CalendarSyncService.swift` → folded into `CalendarSyncBridge` (keep `UserDefaults` event-id mapping during migration, then move it into the metadata store).

## Architecture

```text
                  ┌────────────────────────┐
                  │   ScheduleRootView     │  NavigationSplitView
                  │ (Sidebar | Content | Inspector)
                  └─────────┬──────────────┘
                            │ @State viewModel
                  ┌─────────▼──────────────┐
                  │  ScheduleViewModel     │  @Observable (iOS 17) / ObservableObject (iOS 16)
                  │  - jobs (Supabase)     │
                  │  - ekEvents (EventKit) │
                  │  - metadata (local)    │
                  └───┬─────────┬──────────┘
                      │         │
        ┌─────────────▼──┐   ┌──▼──────────────────────┐
        │ EventKitService│   │ ScheduleMetadataStore   │ protocol
        │ (EKEventStore) │   │  ├─ SwiftDataStore (17+)│
        └────────────────┘   │  └─ CoreDataStore (16)  │
                             └─────────────────────────┘
```

### EventKit layer (`EventKitService`)

- Singleton actor.
- `requestAccess()` — uses `requestFullAccessToEvents` on iOS 17+, falls back to `requestAccess(to:)` on iOS 16 via `if #available`.
- `events(in dateInterval:, calendars:)` — predicate fetch.
- `upsert(job: Job, calendar: EKCalendar)` → returns `eventIdentifier`.
- `delete(eventIdentifier:)`.
- `inspectFlowCalendar()` — preserves existing "InspectFlow Jobs" calendar logic.
- Observes `.EKEventStoreChanged`; exposes an `AsyncStream<Void>` the view model subscribes to.

### Metadata layer (`ScheduleMetadataStore`)

Protocol:

```swift
protocol ScheduleMetadataStore {
    func metadata(for eventID: String) async throws -> EventMetadata?
    func upsert(_ metadata: EventMetadata) async throws
    func delete(eventID: String) async throws
    func allMetadata() async throws -> [EventMetadata]
}
```

DTO `EventMetadata`: `eventID`, `jobID?`, `category`, `tags: [String]`, `checklist: [ChecklistItem]`, `richNotes`, `updatedAt`.

- `SwiftDataMetadataStore` (`@available(iOS 17, *)`): `@Model EventMetadataSD`, container in app group for share-extension parity.
- `CoreDataMetadataStore`: `NSPersistentContainer("ScheduleMetadata")`, identical entity `EventMetadataCD`, background context for writes, mainContext for reads.
- Factory: `ScheduleMetadataStore.make()` — `if #available(iOS 17, *) { SwiftDataMetadataStore() } else { CoreDataMetadataStore() }`.

### View layer

- `ScheduleRootView` uses `NavigationSplitView(columnVisibility:)` with three columns. On compact size class (`horizontalSizeClass == .compact`) it collapses to a `NavigationStack` with sidebar in a sheet and inspector pushed.
- `ScheduleContentView` hosts a segmented picker (Day / Week / Month) bound to `@AppStorage("schedule.viewMode")`.
- `ScheduleDayGrid` reimplements the hour-rail + event blocks UI from `CalendarKitDayView` using pure SwiftUI `GeometryReader` + `ZStack` (the project already has the math from `ScheduleWeekCalendarView`).
- `EventInspectorView` shows EKEvent fields (editable via `EKEventEditViewController` wrapped in `UIViewControllerRepresentable`) plus the metadata form (category picker, checklist, notes).
- Conflict badges and the existing `ScheduleConflictDetector` carry over unchanged.

### ViewModel

`@Observable` (iOS 17) with `@available` split — on iOS 16 expose the same surface as an `ObservableObject`. Single source of truth:

- `load(week:)` → parallel `async let` for `JobsViewModel.fetch`, `EventKitService.events`, `metadataStore.allMetadata`.
- Reconciles by `Job.id ↔ EKEvent.eventIdentifier ↔ metadata.eventID`.
- `subscribeToCalendarChanges()` task listens to `EventKitService` change stream and re-fetches.
- Writes are dual: `EventKitService.upsert` then `metadataStore.upsert`, both awaited; failure on either rolls back the other.

## Migration / cleanup

1. Move existing `UserDefaults` event-id map from `CalendarSyncService` into the metadata store on first launch (one-shot migration in `EventKitService.bootstrap()`).
2. Delete CalendarKit from `project.pbxproj` (reverse of `add_calendarkit_schedule.py`).
3. Strip `CalendarKitDayView` import sites; `ScheduleView` now renders `ScheduleRootView()`.

## Validation

- Build for iPhone (iOS 16 simulator) and iPad (iOS 17 simulator) — confirm both persistence paths compile under their `#available` branches.
- Manual: grant Calendar access → create job → see event in Apple Calendar → edit notes externally → app picks up via `EKEventStoreChanged`.
- Inspector pane appears on iPad regular width, collapses on iPhone.
- No CalendarKit symbols remain (`rg "CalendarKit" ios-native`).

## Out of scope

- Share-extension changes (already addressed).
- macOS-specific window chrome beyond what Catalyst gives for free.
- Push-based calendar sync (still pull via `EKEventStoreChanged`).
