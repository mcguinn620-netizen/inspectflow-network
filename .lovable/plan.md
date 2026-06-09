# Fix Bitrise Build Errors

## Skills used
- `swiftui-engineer` / `xcode14-compatibility-specialist` (Swift API surface, availability-safe code)
- `inspection-app-architecture` (preserve the InspectFlowConnector layering)
- `ios-debugging` (interpreting xcodebuild diagnostics)

## Root cause
`ios-native/Core/InspectFlowConnector/Database/RestClient.swift` was updated to pass `auth: AuthClient` plus a `URLSession` into `QueryBuilder` and to expose `.rpc(...)`. The local `QueryBuilder` in `ios-native/Core/InspectFlowConnector/Database/QueryBuilder.swift` still has the old signature `init(table, config, session: SessionStore, urlSession: URLSession)` and is missing `rpc(...)` and `notIn(...)`. That mismatch produces all 9 archive errors:

- RestClient.swift:18 / :22 — "extra argument 'auth'", "missing argument for parameter 'urlSession'", "URLSession to SessionStore" mismatch.
- RestClient.swift:23 — `QueryBuilder` has no `rpc`.
- SupabaseService.swift:457, 508, 557 — `QueryBuilder` has no `notIn`.

No swift-connector package change is needed — the failing target only compiles the in-tree `ios-native/Core/InspectFlowConnector/...` copy (Bitrise log paths confirm).

## Changes (ios-native only)

### 1. `ios-native/Core/InspectFlowConnector/Database/QueryBuilder.swift`
- Replace `session: SessionStore` storage/init with `auth: AuthClient` + `urlSession: URLSession` to match RestClient's call sites:
  ```swift
  init(table: String, config: InspectFlowConfig, auth: AuthClient, session: URLSession)
  ```
  (Parameter label `session:` is kept so RestClient.swift compiles unchanged.)
- In `raw()`, replace `session.current()?.accessToken` with `auth.currentSession?.accessToken` (already public on AuthClient).
- Add RPC support:
  ```swift
  @discardableResult public func rpc(_ params: [String: Any] = [:]) -> Self {
      method = "POST"; isMutating = true
      body = try? JSONSerialization.data(withJSONObject: params)
      return self
  }
  ```
- Add `notIn` filter (PostgREST `not.in.(...)` syntax):
  ```swift
  @discardableResult public func notIn(_ column: String, _ values: [Any]) -> Self {
      let joined = values.map { "\($0)" }.joined(separator: ",")
      query.append(URLQueryItem(name: column, value: "not.in.(\(joined))"))
      return self
  }
  ```

### 2. No changes to
- `RestClient.swift` (already correct against the new signature)
- `InspectFlowClient.swift` (still constructs `AuthClient` and passes it in)
- `SupabaseService.swift` (the three `.notIn(...)` call sites will resolve once the method exists)
- swift-connector package (unaffected by archive target)

## Verification
- Re-run Bitrise `archive_and_export_app` workflow; all 9 listed errors should clear.
- Locally: `xcodebuild -workspace ios-native/AutoInspectorNetwork.xcworkspace -scheme AutoInspectorNetwork -configuration Release -destination 'generic/platform=iOS' build` should compile.
- Smoke test in app: a `trips` status update that previously called `.notIn("status", terminalTripStatuses)` should round-trip (no 400 from PostgREST), and any RPC call routed through `RestClient.rpc(...)` should return a 2xx.
