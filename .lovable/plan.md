## Goal
Resolve all reported Xcode build errors so `AutoInspectorNetwork` + `InspectFlowShareExtension` targets compile and the CalendarKit Schedule view stays wired up.

## Root causes

1. **`InspectFlowShareExtension/Info.plist`** is missing the outer root `</dict>` — there are 4 `<dict>` opens but only 3 closes. XCBUtil error 2 = malformed XML.
2. **`SharedImport` type does not exist.** Both `Shared/Models/SharedPayloadModel.swift` and `InspectFlowShareExtension/SharedPayloadModel.swift` contain only `import Foundation`. `ShareViewController`, `ImportInboxStore`, `ImportInboxView` all reference `SharedImport` and its `kind` enum.
3. **`ImportInboxView` errors** cascade from (2) — once `SharedImport` exists with `id`, `title: String`, and `kind: Kind (rawValue: String)`, the `List`/`Text` bindings resolve. Also: `ImportInboxStore` is `@MainActor`-isolated, so `@StateObject ... = ImportInboxStore()` from a non-isolated `View` init triggers concurrency complaints — drop `@MainActor` from the class (the `@Published` updates still happen on main because the call sites are `@MainActor`).
4. **`AutoInspectorNetworkApp.swift`** chains `.onOpenURL` on `WindowGroup` (Scene), and references `appState.selectedTab = .inbox` which doesn't exist on `AppState`. Move `.onOpenURL` onto `RootView` (a `View`) inside the `WindowGroup`, and instead of mutating a non-existent tab, post a `NotificationCenter` event (or just no-op for now) so the app builds. `MainTabView` can observe later.
5. **`InspectorVehiclesView.swift`** calls `SupabaseService.shared.client` directly (private), uses labeled `eq("col", value:)` (connector uses unlabeled `eq("col", value)`), and reads `.execute().value` (connector returns the decoded value from `execute()` directly, not a `Data.value`). Also `client.auth.session` doesn't exist — pattern in repo is `SupabaseService.shared.currentUserID`.

## Changes

### 1. `ios-native/InspectFlowShareExtension/Info.plist`
Add the missing closing `</dict>` before `</plist>` so the structure is root-`<dict>` → `NSExtension` `<dict>` → `NSExtensionAttributes` `<dict>` → `NSExtensionActivationRule` `<dict>` with matching closes.

### 2. Define `SharedImport` (shared by both targets)
Populate both `ios-native/Shared/Models/SharedPayloadModel.swift` and `ios-native/InspectFlowShareExtension/SharedPayloadModel.swift` with the same struct:

```swift
public struct SharedImport: Identifiable, Codable, Hashable {
    public enum Kind: String, Codable { case webLink = "web_link", pdf = "pdf" }
    public let id: UUID
    public let kind: Kind
    public let title: String
    public let url: String?
    public let localFile: String?
    public let createdAt: Date
}
```

Keep both copies identical (the extension target can't import the app module). The pbxproj already lists both files.

### 3. `ios-native/Shared/ImportInboxStore.swift`
Remove the `@MainActor` annotation on the class. Keep `@Published` properties; SwiftUI delivers updates on main. This fixes the property-wrapper / `Binding` cascade errors in `ImportInboxView`.

### 4. `ios-native/App/AutoInspectorNetworkApp.swift`
Move `.onOpenURL` inside the `WindowGroup` onto `RootView`, and replace the missing tab mutation with a `NotificationCenter.default.post(name: .init("inspectflow.openImports"), object: nil)`. No `AppState` API change required; `MainTabView` can subscribe later when an Imports tab is added.

### 5. `ios-native/Features/Settings/InspectorVehiclesView.swift`
Stop reaching into the private connector. Add four small wrappers to `SupabaseService` (next to other table helpers) and call them from the view-model:

```swift
// SupabaseService.swift
func fetchInspectorVehicles(userId: UUID) async throws -> [InspectorVehicle] {
    try await client.db.from("inspector_vehicles")
        .select()
        .eq("user_id", userId.uuidString)
        .eq("is_archived", false)
        .order("is_default", ascending: false)
        .execute()
}
func archiveInspectorVehicle(id: UUID) async throws {
    _ = try await client.db.from("inspector_vehicles")
        .update(["is_archived": true]).eq("id", id.uuidString).execute()
}
func clearDefaultInspectorVehicle(userId: UUID) async throws {
    _ = try await client.db.from("inspector_vehicles")
        .update(["is_default": false]).eq("user_id", userId.uuidString).execute()
}
func setDefaultInspectorVehicle(id: UUID) async throws {
    _ = try await client.db.from("inspector_vehicles")
        .update(["is_default": true]).eq("id", id.uuidString).execute()
}
func createInspectorVehicle(userId: UUID, nickname: String, year: Int?, make: String, model: String, plate: String) async throws {
    var payload: [String: Any] = [
        "user_id": userId.uuidString,
        "nickname": nickname, "make": make, "model": model,
        "license_plate": plate, "is_default": false, "is_archived": false
    ]
    if let year { payload["year"] = year }
    _ = try await client.db.from("inspector_vehicles").insert(payload).execute()
}
```

Rewrite the view-model + `AddInspectorVehicleView.save()` to call these wrappers and obtain the user via `SupabaseService.shared.currentUserID`. Removes every "client is inaccessible / Data has no value / extraneous label" error.

### 6. CalendarKit Schedule wiring (verify)
No code change expected — `CalendarKitDayView` already gates on `#if canImport(CalendarKit)`, `ScheduleView` consumes it, and `add_calendarkit_schedule.py` registered files + SPM. As part of this fix, re-run a quick read of `ScheduleView.swift` to confirm it instantiates `CalendarKitDayView` (not the fallback) and that the `CalendarKit` package dependency is still in `project.pbxproj`. If missing, re-run `ios-native/scripts/add_calendarkit_schedule.py`.

## Out of scope
No DB migration, no UI redesign, no new files beyond the two `SharedPayloadModel.swift` bodies. No changes to web app.

## Validation
- Build `AutoInspectorNetwork` scheme (Release) — expect 0 errors.
- Build `InspectFlowShareExtension` target — plist parses, `SharedImport` resolves.
- Smoke-test Schedule tab opens the CalendarKit day view (not the fallback "CalendarKit is unavailable" placeholder).
