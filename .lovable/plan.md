# Fix Bitrise: missing root `Package.swift`

## Root cause

The Xcode project references a local Swift package via `XCLocalSwiftPackageReference` with `relativePath = "../.."` (relative to `ios-native/AutoInspectorNetwork.xcodeproj`, this points at the repo root). Bitrise resolves that to `/Users/[REDACTED]/git/Package.swift` and fails because **no `Package.swift` exists at the repo root**.

The connector sources are present (`swift-connector/Sources/InspectFlowConnector/...`) and `RELEASING.md` documents the manifest as living at the repo root, but the file itself is missing from the codebase. The error reproduces locally too — `find . -name Package.swift` only returns the legacy Capacitor one under `ios/App/CapApp-SPM/`.

## Fix

1. **Create `Package.swift` at the repo root** declaring the `InspectFlowConnector` package, with the target pointing at the existing sources:
   - `swift-tools-version:5.7`
   - Platforms: iOS 16, macOS 12
   - One library product `InspectFlowConnector`
   - Target path: `swift-connector/Sources/InspectFlowConnector`
   - Test target path: `swift-connector/Tests/InspectFlowConnectorTests`
   - No external dependencies (matches the "pure-Swift, zero-dependency" promise in `swift-connector/README.md`).

2. **Verify the Xcode project reference is consistent.** `relativePath = "../.."` from `ios-native/AutoInspectorNetwork.xcodeproj` correctly resolves to the repo root, so no pbxproj changes are needed once the manifest exists.

3. **No `bitrise.yml` change needed.** The `xcodebuild -resolvePackageDependencies` step will succeed once the manifest is in place.

## Technical details

`Package.swift` (repo root):

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "InspectFlowConnector",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "InspectFlowConnector", targets: ["InspectFlowConnector"]),
    ],
    targets: [
        .target(
            name: "InspectFlowConnector",
            path: "swift-connector/Sources/InspectFlowConnector"
        ),
        .testTarget(
            name: "InspectFlowConnectorTests",
            dependencies: ["InspectFlowConnector"],
            path: "swift-connector/Tests/InspectFlowConnectorTests"
        ),
    ]
)
```

## Out of scope

- Re-tagging `v0.2.0` on GitHub (the local package reference doesn't need a tag).
- Changes to the legacy `ios/App/CapApp-SPM/Package.swift` (Capacitor app, untouched).
- Any source changes under `swift-connector/`.
