## Goal
Finish wiring the CalendarKit Swift Package into `AutoInspectorNetwork.xcodeproj` so `import CalendarKit` resolves and `CalendarKitDayView` renders (not the fallback placeholder).

## Current state (verified)
- Source files `CalendarKitDayView.swift` + `ScheduleExportMenu.swift` are registered correctly (PBXBuildFile, PBXFileReference, Schedule group, Sources phase) — OK.
- `packageReferences` array on PBXProject exists but is **empty** (line 882).
- `packageProductDependencies` on the `AutoInspectorNetwork` target exists but is **empty** (line 832).
- Frameworks build phase has `CK00000000000000000000A3 /* (null) in Frameworks */` with **no `productRef`** — malformed entry, renders as `(null)`.
- No `XCRemoteSwiftPackageReference` section and no `XCSwiftPackageProductDependency` section exist anywhere in the file.

The previous `add_calendarkit_schedule.py` run only succeeded on the source-file edits; the four package-related regex substitutions silently no-oped because they didn't match the actual pbxproj layout (empty `( )` blocks with no anchor line, and `\Z` matching whitespace at EOF).

## Changes

### 1. `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj`
Direct surgical edits (no script needed — five small `line_replace` calls):

a. **Fix the malformed Frameworks build-file** (line 102):
```
CK00000000000000000000A3 /* CalendarKit in Frameworks */ = {isa = PBXBuildFile; productRef = CK00000000000000000000A2 /* CalendarKit */; };
```

b. **Populate `packageProductDependencies`** on the `AutoInspectorNetwork` target (lines 832-833):
```
packageProductDependencies = (
    CK00000000000000000000A2 /* CalendarKit */,
);
```

c. **Populate `packageReferences`** on the PBXProject (lines 882-883):
```
packageReferences = (
    CK00000000000000000000A1 /* XCRemoteSwiftPackageReference "CalendarKit" */,
);
```

d. **Append the two missing SPM sections** immediately before the final `};\n}` rootObject closer:
```
/* Begin XCRemoteSwiftPackageReference section */
    CK00000000000000000000A1 /* XCRemoteSwiftPackageReference "CalendarKit" */ = {
        isa = XCRemoteSwiftPackageReference;
        repositoryURL = "https://github.com/richardtop/CalendarKit.git";
        requirement = {
            kind = upToNextMajorVersion;
            minimumVersion = 1.1.5;
        };
    };
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
    CK00000000000000000000A2 /* CalendarKit */ = {
        isa = XCSwiftPackageProductDependency;
        package = CK00000000000000000000A1 /* XCRemoteSwiftPackageReference "CalendarKit" */;
        productName = CalendarKit;
    };
/* End XCSwiftPackageProductDependency section */
```

### 2. `ios-native/scripts/add_calendarkit_schedule.py` (optional hardening)
Update the idempotency guard and the failing regexes so future re-runs are safe:
- Match empty `packageReferences = ( )` / `packageProductDependencies = ( )` blocks (not just a non-existent anchor line).
- Replace `\Z` anchor with a search for the last `}\n}` pair.
- Detect "partial application" (source files present but package missing) and only inject the missing pieces.

This is documentation-only insurance; the pbxproj edits in step 1 are what actually fix the build.

## Out of scope
- No changes to Swift source, Info.plist, or the share extension.
- No CalendarKit version bump.
- No workspace/xcconfig edits — Xcode will resolve the package on next open / `xcodebuild -resolvePackageDependencies`.

## Validation
- Open the project (or run `xcodebuild -resolvePackageDependencies -workspace AutoInspectorNetwork.xcworkspace -scheme AutoInspectorNetwork`) — CalendarKit downloads to `~/Library/Developer/Xcode/DerivedData/.../SourcePackages`.
- Archive: `xcodebuild archive -workspace … -scheme AutoInspectorNetwork -configuration Release` — expect 0 errors and no `(null) in Frameworks` warning.
- Launch Schedule tab — verify the CalendarKit `DayView` renders (timeline with hour ruler), not the "CalendarKit is unavailable" fallback.
