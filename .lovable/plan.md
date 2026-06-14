# Native Schedule Upgrade — Phased Plan

Production upgrade of the existing native Schedule module to an Apple Calendar-class experience. Each phase ends in a buildable state on iOS 16+/iPadOS 16+/macOS 13+ (Xcode 14+, Swift 5.7+). No scaffolds, no TODOs, no placeholders — every file lands fully implemented.

---

## Phase 0 — Project hygiene & shared types (foundation)
Goal: land the cross-cutting types every later phase depends on, with zero behavior change.

- `Core/Calendar/EventIdentity.swift` — value type wrapping `eventIdentifier` + `calendarItemExternalIdentifier`, with helpers to resolve an `EKEvent` from either, plus equality/hash on the strongest available id.
- `Core/Persistence/EventMetadata.swift` (replace existing DTO) — expanded schema: `priority`, `status`, `estimatedDuration`, `travelTime`, `contactName`, `contactPhone`, `attachments`, `customFieldsJSON`, `createdAt`, `updatedAt`, `lastSyncedAt`, `version`, dual identifiers.
- `Core/Persistence/SwiftDataMetadataStore.swift` + `CoreDataMetadataStore.swift` — mirror schemas exactly; Core Data model updated with `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically`; lightweight migration mapping from current model.
- Register all new files in `AutoInspectorNetwork.xcodeproj/project.pbxproj` using the corrected relative-path/`<group>` pattern from the prior fix; extend `switch_to_native_schedule.py` accordingly.

Skills: **core-data-expert**, **swiftdata-pro**, **xcode14-compatibility**.

---

## Phase 1 — Repository layer & ViewModel refactor
Goal: ViewModels stop talking to `EventKitService` directly.

- `Core/Calendar/EventRepository.swift` — load/create/update/delete events, merge metadata, expose `AsyncSequence` of change events (debounced via `EKEventStoreChanged`).
- `Core/Calendar/CalendarRepository.swift` — calendars, sources, colors, visibility persistence.
- `Core/Calendar/EventConflictResolver.swift` — deterministic merge using `updatedAt`/`lastSyncedAt`/`version`; field-level merge where safe, newest-wins otherwise.
- Refactor `ScheduleViewModel` to depend on the two repositories only.
- Trim `EventKitService` to pure EventKit I/O (no calendar listing/visibility logic).

Skills: **swift-concurrency**, **swiftui-view-refactor**.

---

## Phase 2 — Sidebar, filters, recurrence, search
Goal: feature parity with Apple Calendar's chrome.

- `Features/Schedule/CalendarFilterModel.swift` — `Identifiable, Codable` with required fields.
- `Features/Schedule/CalendarSidebarView.swift` — replaces `ScheduleSidebar`; per-calendar color dot, name, source, visibility toggle persisted via `@AppStorage` keyed by `calendarIdentifier` and mirrored into `CalendarRepository`.
- `Features/Schedule/RecurrenceEditorView.swift` + `EventKitService` extensions: `createRecurringEvent`, `updateRecurringEvent`, `removeRecurringEvent` using `EKRecurrenceRule`/`EKRecurrenceEnd` (daily/weekly/monthly/yearly, interval, end date OR occurrence count).
- `Features/Schedule/EventInspectorView.swift` — wire recurrence editor.
- `Core/Calendar/ScheduleSearchService.swift` + `.searchable` on root; merges EKEvent fields with metadata (title, notes, location, category, tags, rich notes); live results.

Skills: **swiftui-ui-patterns**, **swiftui-pro**.

---

## Phase 3 — Drag & drop across Day/Week/Month
Goal: native rescheduling by drag.

- Upgrade `ScheduleDayGrid`, `ScheduleMonthMatrix`, and a new `ScheduleWeekGrid` with `.onDrag` producing an `NSItemProvider` carrying an `EventIdentity` payload.
- Fully implemented `DropDelegate` types per surface: snap to time slot (day/week) or date (month), update `EKEvent` via repository, bump metadata `updatedAt`/`version`, refresh.
- Haptics + visual drop targets; respects read-only calendars.

Skills: **swiftui-ui-patterns**, **swiftui-pro**.

---

## Phase 4 — Multi-window & app entry
- Update `AutoInspectorNetworkApp` with an additional `WindowGroup("EventDetail", for: EventIdentity.self)` and `@Environment(\.openWindow)` plumbing.
- `Features/Schedule/EventDetailWindow.swift` — standalone inspector window; iPad Stage Manager + macOS multi-window verified via availability guards.
- Inspector toolbar gains "Open in New Window" action.

Skills: **swiftui-ui-patterns**.

---

## Phase 5 — Natural language quick-add
- `Core/Calendar/NaturalLanguageSchedulingService.swift` using `NSDataDetector` (.date) + `NaturalLanguage` tagging for title/location extraction; returns an `EKEvent` draft pre-populated on the InspectFlow calendar.
- Quick-add field in `ScheduleRootView` toolbar; Enter creates draft and opens inspector.

Skills: **swift-concurrency**.

---

## Phase 6 — Focus filters, change streaming, caching
- `Core/Calendar/FocusFilterManager.swift` — bridges system Focus state with calendar/category visibility; persists per-Focus presets.
- Replace existing `EKEventStoreChanged` observer with `AsyncSequence` pipeline; debounce (250 ms) and diff visible window only.
- In-memory caches for calendars, metadata, and search index inside repositories with invalidation on change events.

Skills: **swift-concurrency**, **performance-optimization**.

---

## Phase 7 — Widgets & Live Activities
- New target `AgendaWidgetExtension` — `WidgetBundle`, `TimelineProvider`, `Entry`, small/medium/large views: next appointment, today agenda, overdue tasks. Reads via App Group shared store populated by repository.
- `Features/Schedule/UpcomingEventLiveActivity.swift` — `ActivityKit` activity with title/countdown/location; gated by `if #available(iOS 16.1, *)` (Live Activities) and `if #available(iOS 16.2, *)` for Dynamic Island where used.
- pbxproj updates for new extension target, entitlements, App Group, Info.plist.

Skills: **xcode14-compatibility**, **app-store-deployment**.

---

## Verification per phase
- `plutil -lint` on `project.pbxproj` after each phase.
- Run existing `scripts/validate_step_3_4_schedule.py` and extend it to assert presence of new files + group membership.
- Local archive check (Release) gated by the bitrise job that previously failed; no new files may regenerate the doubled-prefix path bug.

## Risks
- Core Data migration from the current `EventMetadata` entity must be lightweight-compatible; if any rename is required, ship a mapping model in Phase 0.
- ActivityKit + WidgetKit add a new extension target — pbxproj edits are the most error-prone step and will be scripted, not hand-edited.
- iOS 16 fallbacks: SwiftData paths must remain `@available(iOS 17, *)`; every new API surface needs an iOS 16 branch.

## Skills checklist
core-data-expert · swiftdata-pro · swiftui-pro · swiftui-ui-patterns · swiftui-view-refactor · swift-concurrency · xcode14-compatibility · performance-optimization · app-store-deployment · inspection-app-architecture (for repo conventions).
