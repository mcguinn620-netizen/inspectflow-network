## Plan: integrate `InspectFlowConnector` directly into the iOS native app

### Goal
Remove the Swift Package Manager dependency path problem entirely by compiling the connector source files as part of the `AutoInspectorNetwork` iOS app target.

### Changes
1. **Vendor connector sources into `ios-native`**
   - Copy `swift-connector/Sources/InspectFlowConnector/**` into a native-app folder such as `ios-native/Core/InspectFlowConnector/`.
   - Keep the existing connector code intact, but make it local app source instead of an SPM package product.

2. **Remove package imports from app code**
   - Remove `import InspectFlowConnector` from native app files that currently depend on it.
   - Because the connector will compile in the same app module, its public/internal types will be directly available.

3. **Update `AutoInspectorNetwork.xcodeproj`**
   - Add all vendored connector `.swift` files to the app target’s Sources build phase.
   - Remove the `InspectFlowConnector` package product from:
     - target `packageProductDependencies`
     - Frameworks build phase
     - project `packageReferences`
     - `XCLocalSwiftPackageReference` / `XCSwiftPackageProductDependency` sections
   - This prevents Xcode/Bitrise from looking for `Package.swift` at repo root or `ios-native`.

4. **Update Bitrise config**
   - Remove the `Package.swift` validation step.
   - Remove explicit `xcodebuild -resolvePackageDependencies` steps.
   - Keep the workflows pointed at:
     - `ios-native/VehicleInspectorsApp.xcworkspace`
     - scheme `VehicleInspectorsApp`
   - `xcode-build-for-test` and `xcode-archive` should then build without SPM resolution.

5. **Update native docs**
   - Adjust `ios-native/README.md` to say the connector is vendored into the native target and no `Package.swift` is required for Bitrise.
   - Keep the standalone `swift-connector` package in the repo for reuse/release, but it will no longer be required by the native iOS build.

### Expected result
Bitrise no longer runs Swift package dependency resolution for the iOS app, so it cannot fail with `Package.swift doesn't exist` due to local package path differences.