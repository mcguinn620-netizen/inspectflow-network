## Root causes

Three of the four errors are the same legacy `project.pbxproj` hygiene problem we hit before. The fourth is a Swift type-inference bug.

### 1. `Cannot find 'JobCreateView' in scope` — JobsView.swift:62
`ios-native/Features/Jobs/JobCreateView.swift` exists on disk and has a `PBXFileReference` + group entry in `project.pbxproj` (lines 263, 620), but it has **no `PBXBuildFile` entry and is missing from the `AutoInspectorNetwork` Sources build phase**. Its sibling `JobCreateViewModel.swift` is wired in correctly (line 1165). The file never gets compiled, so the symbol doesn't exist for `JobsView` to reference.

### 2 & 4. `Cannot find 'NativeNowIndicator' in scope` — ScheduleDayGrid.swift:164, ScheduleWeekGrid.swift:174
`ios-native/Features/Schedule/NativeNowIndicator.swift` exists on disk but has **zero references in `project.pbxproj`** — no file reference, no build file, no group membership. It's invisible to Xcode.

### 3. `Generic parameter 'ElementOfResult' could not be inferred` — ScheduleMonthMatrix.swift:169
Classic Swift inference failure inside `jobs.compactMap { job in ... }` (lines 169-178). The closure uses `guard let ... else { return nil }` and then returns a `MonthTimelineItem`, but with no explicit return type the compiler can't pick `ElementOfResult` between `MonthTimelineItem` and `MonthTimelineItem?`. Nothing wrong with the project file here — purely a Swift annotation problem.

## Fix plan

### Step 1 — Add the two missing files to the `AutoInspectorNetwork` target in `project.pbxproj`

Surgical edits only, mirroring the pattern already used for `JobCreateViewModel.swift` and other Schedule files:

a. **`JobCreateView.swift`** — add one `PBXBuildFile` entry near line 68 (alongside `JobCreateViewModel.swift in Sources`) and one reference in the main-app Sources build phase near line 1165. The `PBXFileReference` (263) and group entry (620) already exist; do not duplicate them.

b. **`NativeNowIndicator.swift`** — add all four entries:
   - one `PBXBuildFile` (Sources)
   - one `PBXFileReference` (sourcecode.swift, path `NativeNowIndicator.swift`)
   - one entry in the `Features/Schedule` group children, next to `ScheduleDayGrid.swift`/`ScheduleWeekGrid.swift`
   - one entry in the main-app Sources build phase

Only the main `AutoInspectorNetwork` target is touched; the widget extension target is left alone (consistent with last session's fix).

### Step 2 — Fix the compactMap inference in `ScheduleMonthMatrix.swift`

Annotate the closure return type so the compiler resolves `ElementOfResult`:

```swift
// Before (line 169)
let dayJobs = jobs.compactMap { job in
    guard let scheduledAt = job.scheduledAt, ... else { return nil }
    return MonthTimelineItem(...)
}

// After
let dayJobs = jobs.compactMap { job -> MonthTimelineItem? in
    guard let scheduledAt = job.scheduledAt, ... else { return nil }
    return MonthTimelineItem(...)
}
```

One-line change, no behavioral impact.

### Step 3 — Verification

- `rg "JobCreateView\.swift|NativeNowIndicator\.swift" ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` should show both files with `PBXBuildFile`, `PBXFileReference`, group, and Sources-phase entries.
- Confirm `project.yml` already lists `Features/Jobs/**` and `Features/Schedule/**` by glob (it does), so the next XcodeGen run on Bitrise will stay in sync.
- All four reported errors resolve; no source files other than `ScheduleMonthMatrix.swift` are modified.

### Skills used
- **swiftui-pro** — confirmed the `compactMap` closure-typing pattern as the canonical Swift fix.
- Built-in code exploration (`rg`, `code--view`) to map pbxproj membership and locate the inference site.