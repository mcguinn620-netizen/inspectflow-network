# Audit Fix Plan — 19 compile errors / 10 files

Saved for future implementation.

---

## Phase 1 — Critical blockers

### 1.1 WidgetBackground.colorset — add explicit light variant
**File:** `ios-native/AgendaWidgetExtension/Assets.xcassets/WidgetBackground.colorset/Contents.json`

Replace the first (universal, no-appearances) entry so both light and dark are explicit:

```json
{
  "colors" : [
    {
      "appearances" : [{ "appearance" : "luminosity", "value" : "light" }],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "red" : "1.000", "green" : "1.000", "blue" : "1.000" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [{ "appearance" : "luminosity", "value" : "dark" }],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "red" : "0.110", "green" : "0.110", "blue" : "0.110" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

### 1.2 Core Data — rename reserved `entityName` attribute
**File:** `ios-native/InspectionModel.xcdatamodeld/InspectionModel.xcdatamodel/contents`

`entityName` collides with `NSManagedObject.entity().name`. Rename to `recordEntityName`:

```xml
<entity name="CachedRecord" representedClassName="CachedRecord" syncable="YES" codeGenerationType="class">
    <attribute name="recordEntityName" optional="YES" attributeType="String"/>
    <attribute name="id" optional="YES" attributeType="String"/>
    <attribute name="payload" optional="YES" attributeType="Binary"/>
    <attribute name="updatedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
</entity>
```

No Swift call sites reference `CachedRecord.entityName`. Add a one-line note to `RELEASING.md` about lightweight migration (set `shouldInferMappingModelAutomatically = true` and `shouldMigrateStoreAutomatically = true` on the `NSPersistentStoreDescription` — already the default in `PersistenceController`).

### 1.3 `#Preview` guard — compiler + availability
**File:** `ios-native/Features/Schedule/RecurrenceEditorView.swift` (lines 126–130)

Replace the existing `#if swift(>=5.9) && os(iOS)` block with a compiler + availability guard so older Xcode toolchains skip the macro entirely:

```swift
#if compiler(>=5.9)
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    RecurrenceEditorView(initial: .none) { _ in }
}
#endif
```

---

## Phase 2 — Access control normalization

### 2.1 CalendarRepository — mark init explicitly internal
**File:** `ios-native/Core/Calendar/CalendarRepository.swift` (line 26)

```swift
internal init(
    service: EventKitService = .shared,
    defaults: UserDefaults = .standard
) {
    self.service = service
    self.defaults = defaults
    self.hiddenCalendarIDs = Self.readHidden(defaults: defaults, key: visibilityKey)
    reload()

    changeTask = Task { [weak self] in
        guard let self else { return }
        for await _ in self.service.changes() {
            self.reload()
        }
    }
}
```

`public static let shared = CalendarRepository()` stays — only the init keyword changes.

### 2.2 EventRepository — mark init explicitly internal
**File:** `ios-native/Core/Calendar/EventRepository.swift` (line 39)

```swift
internal init(
    service: EventKitService = .shared,
    calendars: CalendarRepository = .shared,
    metadata: ScheduleMetadataStore = ScheduleMetadataStoreFactory.make(),
    debounceMilliseconds: Int = 250
) {
    self.service = service
    self.calendars = calendars
    self.metadata = metadata
    self.debounce = .milliseconds(debounceMilliseconds)

    changeTask = Task { [weak self] in
        guard let self else { return }
        for await _ in self.service.changes() {
            self.invalidateCaches()
            self.scheduleDebouncedBroadcast()
        }
    }
}
```

---

## Phase 3 — Architecture

### 3.1 SwiftDataMetadataStore — availability-gate the shared instance
**File:** `ios-native/Core/Persistence/SwiftDataMetadataStore.swift`

Stored static properties of `@available` types must themselves be gated. Replace line 81:

```swift
// Remove:  static let shared = SwiftDataMetadataStore()

// Add at file scope, outside the class:
@available(iOS 17.0, macOS 14.0, *)
private let _swiftDataMetadataStoreShared = SwiftDataMetadataStore()

// Inside the class:
@available(iOS 17.0, macOS 14.0, *)
static var shared: SwiftDataMetadataStore { _swiftDataMetadataStoreShared }
```

Update `ScheduleMetadataStoreFactory` (in `ScheduleMetadataStore.swift`) to call inside an `if #available(iOS 17, *)` block — verify the factory already does this; if not:

```swift
enum ScheduleMetadataStoreFactory {
    static func make() -> ScheduleMetadataStore {
        if #available(iOS 17.0, macOS 14.0, *) {
            return SwiftDataMetadataStore.shared
        } else {
            return CoreDataMetadataStore.shared
        }
    }
}
```

### 3.2 ScheduleViewModel — remove MainActor-isolated default arg
**File:** `ios-native/Features/Schedule/ScheduleViewModel.swift` (lines 46–63)

`CalendarFilterModel()` reads `UserDefaults` and the default-arg expression is evaluated on the MainActor at call sites, which Swift 6 flags. Switch to an optional default and build inside the body:

```swift
init(
    events: EventRepository = .shared,
    calendars: CalendarRepository = .shared,
    filters: CalendarFilterModel? = nil,
    searchService: ScheduleSearchService? = nil
) {
    self.events_repo = events
    self.calendarsRepo = calendars
    self.filters = filters ?? CalendarFilterModel()
    self.searchService = searchService ?? ScheduleSearchService(repository: events)

    changeTask = Task { [weak self] in
        guard let self else { return }
        for await _ in self.events_repo.changes() {
            await self.reloadEvents()
        }
    }
}
```

---

## Phase 4 — Missing `RealtimeSubscription` symbol (CORRECTED)

### Problem discovered during investigation
`InspectFlowConnector` sources under `ios-native/Core/InspectFlowConnector/` are compiled **directly into the main app target** as regular source files, not linked as a SwiftPM package. Therefore `import InspectFlowConnector` is invalid — there is no separate module to import.

The original Phase 4 (adding `import InspectFlowConnector`) is **wrong** and must be reverted.

### Actual root cause
`RealtimeSubscription` is declared in `Core/InspectFlowConnector/Realtime/RealtimeSubscriptions.swift`. That file exists on disk but is **not registered in `project.pbxproj`** (only `RealtimeChannel.swift` is in the Realtime group). Therefore `RealtimeSubscription` never compiles into the app.

### Correct fix

#### 4.1 Remove the invalid imports (revert Phase 4)
In these four files, delete the line `import InspectFlowConnector`:

1. `ios-native/Features/Inspections/InspectionsViewModel.swift`
2. `ios-native/Features/Jobs/JobsViewModel.swift`
3. `ios-native/Features/Mileage/MileageViewModel.swift`
4. `ios-native/Features/Trips/TripsViewModel.swift`

#### 4.2 Add `RealtimeSubscriptions.swift` to the Xcode target
File: `ios-native/Core/InspectFlowConnector/Realtime/RealtimeSubscriptions.swift`

Register it in `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` using two fresh 24-char hex UUIDs (ensure uniqueness; e.g. `B19E53D22FE0C9A6000BC4D0` for fileRef, `B19E54782FE0C9A9000BC4D0` for buildFile).

a. **PBXBuildFile section** — add:
```
B19E54782FE0C9A9000BC4D0 /* RealtimeSubscriptions.swift in Sources */ = {isa = PBXBuildFile; fileRef = B19E53D22FE0C9A6000BC4D0 /* RealtimeSubscriptions.swift */; };
```

b. **PBXFileReference section** — add:
```
B19E53D22FE0C9A6000BC4D0 /* RealtimeSubscriptions.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = RealtimeSubscriptions.swift; sourceTree = "<group>"; };
```

c. **Realtime PBXGroup children** — add:
```
B19E53D22FE0C9A6000BC4D0 /* RealtimeSubscriptions.swift */,
```

d. **Sources build phase** — add:
```
B19E54782FE0C9A9000BC4D0 /* RealtimeSubscriptions.swift in Sources */,
```

After editing, run `python3 ios-native/scripts/validate_pbxproj.py` to check integrity.

---

## Verification

```bash
cd ios-native
xcodebuild -project AutoInspectorNetwork.xcodeproj -list
xcodebuild -project AutoInspectorNetwork.xcodeproj \
           -scheme AutoInspectorNetwork \
           -destination 'generic/platform=iOS' \
           -resolvePackageDependencies
xcodebuild -project AutoInspectorNetwork.xcodeproj \
           -scheme AutoInspectorNetwork \
           -destination 'generic/platform=iOS' \
           clean build CODE_SIGNING_ALLOWED=NO
```

Target: 0 errors.

---

## Files changed on implementation

1. `ios-native/AgendaWidgetExtension/Assets.xcassets/WidgetBackground.colorset/Contents.json`
2. `ios-native/InspectionModel.xcdatamodeld/InspectionModel.xcdatamodel/contents`
3. `ios-native/Features/Schedule/RecurrenceEditorView.swift`
4. `ios-native/Core/Calendar/CalendarRepository.swift`
5. `ios-native/Core/Calendar/EventRepository.swift`
6. `ios-native/Core/Persistence/SwiftDataMetadataStore.swift`
7. `ios-native/Core/Persistence/ScheduleMetadataStore.swift` (factory guard, if missing)
8. `ios-native/Features/Schedule/ScheduleViewModel.swift`
9. `ios-native/Features/Inspections/InspectionsViewModel.swift` (remove import)
10. `ios-native/Features/Jobs/JobsViewModel.swift` (remove import)
11. `ios-native/Features/Mileage/MileageViewModel.swift` (remove import)
12. `ios-native/Features/Trips/TripsViewModel.swift` (remove import)
13. `ios-native/Core/InspectFlowConnector/Realtime/RealtimeSubscriptions.swift` (add to pbxproj)
14. `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` (register RealtimeSubscriptions)
15. `RELEASING.md` — Core Data attribute rename / migration note
16. `.lovable/audit-fix-plan.md` — this plan, saved for future reference