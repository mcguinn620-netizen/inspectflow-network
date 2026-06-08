# Fix: `extra argument 'auth'` in InspectFlowClient.swift

## Root cause

`ios-native/Core/InspectFlowConnector/InspectFlowClient.swift` line 31 calls
`StorageClient(config: config, auth: auth)`.

There are **two** `StorageClient.swift` files in the repo:

- `ios-native/Core/InspectFlowConnector/Storage/StorageClient.swift` — `init(config:, auth:)` ✅ matches the call site
- `swift-connector/Sources/InspectFlowConnector/Storage/StorageClient.swift` — `init(config:, session:)` ❌

The Xcode project (`AutoInspectorNetwork.xcodeproj/project.pbxproj`) currently points its `Storage` group at the **wrong** file. Group `B14C6A632FBBBA64006C431B` has:

```
path = "../../../swift-connector/Sources/InspectFlowConnector/Storage";
```

So Xcode compiles the `session:`-based `StorageClient`, and the call with `auth:` fails to type-check. The local Storage folder under `Core/InspectFlowConnector/Storage/` (which has the correct, Xcode 14 / Swift 5.7 compatible implementation) is not in the build.

All other Connector clients (`AuthClient`, `RestClient`, `FunctionsClient`, `RealtimeClient`) already resolve to the correct local copies under `Core/InspectFlowConnector/`, so this is the only mismatch.

## Fix

Edit `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj`, group `B14C6A632FBBBA64006C431B /* Storage */`:

```text
B14C6A632FBBBA64006C431B /* Storage */ = {
    isa = PBXGroup;
    children = (
        B14CF43D2FCBE865002ED72E /* StorageClient.swift */,
    );
    path = Storage;          // was: "../../../swift-connector/.../Storage"
    sourceTree = "<group>";
};
```

This makes the existing file reference (`path = StorageClient.swift`, `sourceTree = <group>`) resolve relative to its parent group `Core/InspectFlowConnector/`, i.e. to `Core/InspectFlowConnector/Storage/StorageClient.swift` — the local, `auth:`-based implementation.

No Swift source changes needed; the call sites in `InspectFlowClient.swift` already match the local file's signature.

## Other issues swept while investigating

- `Package.swift` (SPM) at `ios-native/Package.swift` points to `Core/InspectFlowConnector` and is self-consistent (all local files use `auth:`). After the pbxproj fix the Xcode target matches SPM.
- Local `Core/InspectFlowConnector/Storage/StorageClient.swift`, `RestClient.swift`, `FunctionsClient.swift`, and `AuthClient.swift` are Swift 5.7 / iOS 16-safe: only `async`/`await`, `URLSession.data(for:)` (iOS 15+), `NSLock`, no iOS 17-only APIs, no result builders requiring newer toolchains. No availability guards required.
- The duplicate connector tree under `swift-connector/Sources/InspectFlowConnector/` should remain decoupled from the app target (it is its own SPM package, used by external consumers). No changes there.

## Verification

1. Clean build folder in Xcode.
2. Build the `AutoInspectorNetwork` scheme (Xcode 14, iOS 16 simulator).
3. Confirm `InspectFlowClient.swift:31` compiles and the file shown in the Project Navigator under `InspectFlowConnector ▸ Storage ▸ StorageClient.swift` opens the local `Core/InspectFlowConnector/Storage/StorageClient.swift` (path inspector should show that location, not `swift-connector/...`).
4. Run `InspectFlowConnectorTests` (`AuthRefreshTests`) to make sure auth wiring still passes.
