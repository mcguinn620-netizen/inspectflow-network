# Step 3.4 / 3.5 Audit and Corrections

## What I reviewed
- `ios-native/Features/Schedule/ScheduleView.swift`
- `ios-native/Features/Jobs/JobsViewModel.swift`
- `ios-native/Features/Dashboard/{DashboardView,DashboardViewModel,InspectorDashboardHomeView}.swift`
- `ios-native/Features/Dashboard/Components/{StartMyDayCard,NextStopCard,ActiveTripBanner}.swift`
- `ios-native/App/MainTabView.swift`
- `ios-native/scripts/validate_step_3_4_schedule.py` and `validate_step_3_5_inspector_flow.py`

## Findings

### 🔴 Critical — ScheduleView.swift is corrupted and will not compile
Lines 8–212 contain a mid-token splice: the line `@State priv` is interrupted by `import Foundation`, followed by **two complete duplicate copies** of `JobsViewModel` pasted inside the `ScheduleView` struct body, then the original `…ate var draggingJobID: UUID?` resumes on line 212. Net effects:
- Swift parse failure on `@State privimport Foundation`.
- `JobsViewModel` is declared 3× (`Features/Jobs/JobsViewModel.swift` + 2 copies inside Schedule) → duplicate-symbol compile error.
- These duplicate copies also reference `var updatedJob = job; updatedJob.scheduledAt = …` which mutates `Job` — won't compile if `Job` is a `let`-property struct (the canonical `JobsViewModel.swift` correctly rebuilds a new `Job`).

### 🟠 Validator failure — Step 3.4
`validate_step_3_4_schedule.py` greps for the single-line signature `func assign(job: Job, inspectorId: UUID, orgId: UUID?) async` but the real `JobsViewModel.swift` declares it across multiple lines. Same risk for `reschedule(...)`. Either reformat the signatures to one line or relax the validator's match.

### 🟡 Plan gaps in 3.4
- **Drag-to-reschedule** is faked: long-press just sets a flag, then user must open a context menu and tap "Move first job here". Plan called for true long-press + move gesture.
- **Conflict detection** uses a placeholder rule (`> 8 jobs/day`) instead of porting `src/lib/scheduleConflicts.ts` (overlap + blocked-date + availability logic).
- **Dispatcher gating** is fake: `isDispatcher` returns `true` whenever signed-in. Should check the user's effective role via `AppState.effectiveRole` / `useUserRoles` analogue.
- **Intelligent dispatch edge fn** is not called. `DispatcherAssignSheet` only accepts a manually pasted UUID; plan called for the intelligent dispatch edge function to surface recommended inspectors.

### 🟢 Step 3.5 — passes validator, minor notes
- All required files exist (`StartMyDayCard`, `NextStopCard`, `ActiveTripBanner`, `InspectorDashboardHomeView`).
- `MainTabView` correctly switches first tab on `appState.effectiveRole == "inspector"`.
- Voice-cue `@AppStorage("inspector.voice_cues_enabled")` flag wired in `SettingsView` + `DriveView`.
- No corrections required for 3.5 beyond what's listed below.

## Proposed corrections

### 1. Rebuild `ios-native/Features/Schedule/ScheduleView.swift`
Restore the file to a single, clean `ScheduleView` with no embedded `JobsViewModel`. Specifically:
- Remove lines 8–212 entirely; reinstate `@State private var draggingJobID: UUID?` properly.
- Delete both duplicate `JobsViewModel` blocks. Continue importing the canonical one from `Features/Jobs/JobsViewModel.swift`.
- Keep existing dayCell / DispatcherAssignSheet / DayHeader / ScheduleJobPill helpers.

### 2. Reformat `JobsViewModel.swift` signatures to satisfy validator
Collapse multi-line `func assign(...)` and `func reschedule(...)` declarations onto a single line so `validate_step_3_4_schedule.py` passes. (Cheapest fix; alternative is to relax the validator regex.)

### 3. Tighten dispatcher + dispatch flow
- Replace `isDispatcher` with `appState.effectiveRole == "dispatcher" || == "admin"`.
- Extend `DispatcherAssignSheet` to call the existing `intelligent-dispatch` edge function (via `SupabaseService` / `FunctionsClient`) and render recommended inspectors as a tappable list, falling back to manual UUID entry.

### 4. Real drag-to-reschedule
Replace the long-press-then-context-menu hack with `.draggable(job.id.uuidString)` on `ScheduleJobPill` and `.dropDestination(for: String.self)` on each `dayCell`, calling `viewModel.reschedule(job:scheduledAt:orgId:)` on drop.

### 5. Port real conflict detection
Add `ios-native/Core/Schedule/ScheduleConflicts.swift` mirroring `src/lib/scheduleConflicts.ts` (time-window overlap + `inspector_blocked_dates` + `availability_schedules` checks). Replace the `> 8 jobs/day` heuristic in `hasConflicts` with this logic. No new tables.

### 6. Re-run validators
After edits, run both `validate_step_3_4_schedule.py` and `validate_step_3_5_inspector_flow.py` — both should print their `OK:` line.

## Out of scope for this correction pass
- No changes to debug-auth/Tier-3.4-and-3.5 unrelated files.
- No pbxproj changes (Schedule + Dashboard files are already registered).
- No new Supabase migrations.
