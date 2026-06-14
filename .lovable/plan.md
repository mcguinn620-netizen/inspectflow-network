## Plan

Repair the iOS project metadata so Xcode 14 can parse it cleanly while keeping the project compatible with newer Xcode versions.

### 1. Normalize `.pbxproj` identifiers that look synthetic
- Replace placeholder-pattern UUIDs such as `AAAA000...`, `AB1000...`, `AB2000...`, `AB3000...`, and `A8A000...` with deterministic valid 24-character uppercase hex identifiers.
- Preserve every object relationship: file references, build files, groups, source phases, target dependencies, and product references.
- Re-run the structural validator to confirm no unresolved references or orphan file references are introduced.

### 2. Fix Xcode 14-sensitive project metadata
- Lower scheme `LastUpgradeVersion` values from Xcode 15-style `1500` to an Xcode 14-compatible value.
- Ensure the `.pbxproj` `LastUpgradeCheck`, `CreatedOnToolsVersion`, `objectVersion`, and `compatibilityVersion` are mutually compatible with Xcode 14.
- Add missing `TargetAttributes` for `AgendaWidgetExtension` so all targets have consistent project metadata.

### 3. Stabilize schemes for parser/build setting lookup
- Keep `AutoInspectorNetwork.xcscheme` and `VehicleInspectorsApp.xcscheme`, but normalize both to a conservative Xcode 14-compatible XML format.
- Confirm their `BlueprintIdentifier`, `BlueprintName`, `BuildableName`, and `ReferencedContainer` point to the main app target and product.
- If necessary, remove newer scheme attributes that older Xcode versions may reject.

### 4. Resolve SPM ambiguity
- Confirm whether `ios-native/Package.swift` should be used by the Xcode project.
- Since the project currently has empty `packageReferences` and `packageProductDependencies`, either:
  - keep SPM detached and ensure Bitrise does not fail when resolving dependencies, or
  - attach the local package as a proper `XCLocalSwiftPackageReference` if the app is intended to depend on it.
- Prefer the minimal fix: make `xcodebuild -resolvePackageDependencies` safe even when no packages are attached.

### 5. Make signing CI-safe without weakening local signing
- Keep target signing settings valid for local Xcode use.
- Update Bitrise verification commands to disable signing consistently during list/resolve/archive where applicable.
- Avoid requiring a provisioning profile for the parser/build-setting phase.

### 6. Validation
- Run the existing project validator.
- Run conflict marker and UUID hygiene scans.
- Run a read-only plist/parser sanity check available in this Linux environment.
- Note that final `xcodebuild -list`, dependency resolution, and archive must still run on Bitrise/macOS because this sandbox cannot execute Xcode.

## Expected changed files
- `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj`
- `ios-native/AutoInspectorNetwork.xcodeproj/xcshareddata/xcschemes/AutoInspectorNetwork.xcscheme`
- `ios-native/AutoInspectorNetwork.xcodeproj/xcshareddata/xcschemes/VehicleInspectorsApp.xcscheme`
- `bitrise.yml` if CI command hardening is needed

## Current findings from read-only audit
- No Git conflict markers remain.
- The custom validator currently parses 399 objects with no unresolved references.
- No `AGWX` tokens remain.
- Placeholder-like but technically hex IDs remain (`AAAA...`, `AB100...`, `AB200...`, `AB300...`, `A8A000...`) and are the likely Xcode 14 parser/build-setting risk.
- Schemes use Xcode 15 `LastUpgradeVersion=1500`, which should be normalized for Xcode 14 compatibility.