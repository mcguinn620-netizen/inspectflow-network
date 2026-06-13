## Problem

The Xcode archive fails with "Build input files cannot be found" for 9 Swift files, all resolving to a doubled path like `/Users/.../ios-native/ios-native/Features/Schedule/ScheduleViewModel.swift`.

The doubling comes from `project.pbxproj`. The 9 new `PBXFileReference` entries added by `scripts/switch_to_native_schedule.py` were written with:

```
path = ios-native/Features/Schedule/ScheduleViewModel.swift; sourceTree = SOURCE_ROOT;
```

But `SOURCE_ROOT` already resolves to `ios-native/` (the directory containing `AutoInspectorNetwork.xcodeproj`). Every other Swift entry in the project uses paths relative to that root, e.g. `path = Core/Calendar/CalendarSyncService.swift; sourceTree = "<group>"`. The extra `ios-native/` prefix is what produces the `ios-native/ios-native/...` lookup.

## Fix

### 1. Patch `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` (lines 295–303)

For each of the 9 references, strip the leading `ios-native/` from `path` and switch `sourceTree` to `"<group>"` to match the convention used by every other source file in the project:

| File ref | New path |
|---|---|
| EventKitService.swift | `Core/Calendar/EventKitService.swift` |
| ScheduleMetadataStore.swift | `Core/Persistence/ScheduleMetadataStore.swift` |
| SwiftDataMetadataStore.swift | `Core/Persistence/SwiftDataMetadataStore.swift` |
| ScheduleDayGrid.swift | `Features/Schedule/ScheduleDayGrid.swift` |
| ScheduleMonthMatrix.swift | `Features/Schedule/ScheduleMonthMatrix.swift` |
| ScheduleRootView.swift | `Features/Schedule/ScheduleRootView.swift` |
| ScheduleSidebar.swift | `Features/Schedule/ScheduleSidebar.swift` |
| EventInspectorView.swift | `Features/Schedule/EventInspectorView.swift` |
| ScheduleViewModel.swift | `Features/Schedule/ScheduleViewModel.swift` |

All 9 entries change `sourceTree = SOURCE_ROOT` → `sourceTree = "<group>"`.

### 2. Patch `ios-native/scripts/switch_to_native_schedule.py`

Update the file-registration helper so future re-runs emit the correct relative paths (`path = Features/Schedule/...`, `sourceTree = "<group>"`) instead of `ios-native/...` + `SOURCE_ROOT`. Prevents the bug from reappearing if the script is re-applied.

### 3. Verification

- `plutil -lint ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` to confirm the file still parses.
- Re-grep to confirm none of the 9 file paths contain `ios-native/` anymore.

No source-code changes — the Swift files themselves are correct and in place.
