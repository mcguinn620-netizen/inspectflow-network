# iOS Native Compile Audit — Findings & Fix Plan

A read-only audit (using `swiftdata-pro` + `bug-hunt-swarm` skills, parallel subagent) ran across all 158 Swift files, the `project.pbxproj`, and `project.yml`. Headline result: **no confirmed P0 build breaks today** — `JobCreateView.swift` and `NativeNowIndicator.swift` are already registered after the last fix. The real risks are **shadow/orphan files that will explode the next time XcodeGen regenerates the pbxproj**.

---

## P0 — Build-breaking right now

None confirmed.

## P1 — Will break on next XcodeGen run

`project.yml` includes `Core/**` and `Features/**` recursively. Two stub files duplicate types already declared in their canonical sibling — currently safe only because pbxproj excludes them by path.

| # | File | Duplicates | Action |
|---|------|-----------|--------|
| P1-1 | `ios-native/Core/Calendar/NativeCalendarLayoutEngine.swift` (76-line stub) | `enum NativeCalendarLayoutEngine`, `struct NativeCalendarEventLayout` already in `Features/Schedule/NativeCalendarLayoutEngine.swift` (252 lines, real impl) | **Delete** the Core/Calendar stub |
| P1-2 | `ios-native/Features/Schedule/NativeCalendarMetrics.swift` (24 lines) | `enum NativeCalendarMetrics` already in `Core/Calendar/NativeCalendarMetrics.swift` (32 lines, canonical) | **Delete** the Features/Schedule shadow |
| P1-3 | `ios-native/Shared/Widget/SharedAgendaStore.swift` is in **main app target only**; widget extension may need it | `AgendaWidgetExtension/AgendaWidget.swift` | **Inspect** `AgendaWidget.swift` — if it references the `SharedAgendaStore` Swift type directly, add the file to the widget target's Sources build phase in `project.pbxproj` + `project.yml`. If it only reads App Group JSON, leave alone. |

## P2 — Dead code / future risk

| # | File | Issue | Action |
|---|------|-------|--------|
| P2-1 | `ios-native/Persistence.swift` | Xcode template leftover, references nonexistent `Item` entity, declares a second `PersistenceController` (struct) that collides with the real `final class PersistenceController` in `Core/Persistence/PersistenceController.swift` | Delete |
| P2-2 | `ios-native/Core/Calendar/File.swift` | Empty placeholder (`import Foundation` only) | Delete |
| P2-3 | `Shared/Models/SharedPayloadModel.swift` ↔ `InspectFlowShareExtension/SharedPayloadModel.swift` | Hand-synchronized copies; silent drift = runtime JSON decode failure | Add a round-trip unit test, or extract to a shared SPM module (follow-up) |

## Confirmed healthy (previously suspected)

- `SwiftDataMetadataStore.swift` — all four "missing" types (`ScheduleMetadataStore`, `EventMetadata`, `EventPriority`, `EventStatus`) are declared in `Core/Persistence/ScheduleMetadataStore.swift` (lines 108, 45, 19, 24). File is properly gated with `#if canImport(SwiftData) && swift(>=5.9)` + `@available(iOS 17, *)`. Protocol conformance complete.
- `JobCreateView.swift`, `NativeNowIndicator.swift` — wired into pbxproj at lines 1170–1171.
- `JobCreateViewModel.swift` — `@MainActor` isolation correct; `async` calls properly awaited; optional bridging on `SupabaseService.createJob` arguments compiles cleanly.
- All recently-touched Schedule files have correct `SwiftUI` + `EventKit` imports.
- Extension target membership (CarPlay, AgendaWidget, ShareExtension) correct.

---

## Proposed Build-Mode Steps

1. **Delete 4 orphan/stub files** (one `rm` each):
   - `ios-native/Core/Calendar/NativeCalendarLayoutEngine.swift`
   - `ios-native/Features/Schedule/NativeCalendarMetrics.swift`
   - `ios-native/Persistence.swift`
   - `ios-native/Core/Calendar/File.swift`
2. **Read `AgendaWidgetExtension/AgendaWidget.swift`** to decide P1-3. If it imports/uses `SharedAgendaStore` as a Swift type, add a `PBXBuildFile` entry for `SharedAgendaStore.swift` in the `AgendaWidgetExtensionExtension` target's Sources phase (`project.pbxproj`) — pattern matches the JobCreateView/NativeNowIndicator additions already made.
3. **Skip P2-3** unless you want the test scaffold this turn.

No source code logic changes required — this is purely cleanup of dead/duplicate files plus one conditional target-membership fix. None of the deletions touch any file currently in a build phase.

**Skills used:** `bug-hunt-swarm` (parallel read-only investigation), `swiftdata-pro` (verified SwiftData store gating + protocol conformance).
