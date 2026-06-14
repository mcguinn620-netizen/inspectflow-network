## Problem

`xcodebuild -showBuildSettings` on `AutoInspectorNetwork.xcodeproj` fails with:

```
The project 'AutoInspectorNetwork' is damaged and cannot be opened due to a parse error.
```

This is the same surface error as the previous `PRODUCT_NAME` failure. The earlier "GENERATE_INFOPLIST_FILE = YES → NO" change did not fix it because that wasn't the actual cause — `xcodebuild` cannot open the project at all, so no build-setting work happens.

## What I verified in this repo

- `project.pbxproj` parses cleanly with the Node `xcode` library (3 native targets detected).
- Braces, parens, and quotes are balanced; no merge-conflict markers; pure ASCII; no BOM.
- All `AGWX*` widget-target additions look structurally valid.
- Two pre-existing empty sections (`XCRemoteSwiftPackageReference`, `XCSwiftPackageProductDependency`) trip the strict Python `openstep_parser`, but real `xcodebuild` tolerates those — they predate our changes.

So the file is most likely valid OpenStep, but Xcode 26.4's stricter loader is rejecting one of the recent `add_agenda_widget_target.py` additions. The cheapest fix is to remove the widget target entirely and re-introduce it with a known-good, minimal shape that mirrors the working `InspectFlowShareExtension` target byte-for-byte.

## Plan

### 1. Diagnostic pass (read-only)

Add a small Python validator at `ios-native/scripts/validate_pbxproj.py` that:

- Parses `project.pbxproj` with the `openstep_parser`-equivalent algorithm, but with proper comment skipping between dict entries (fixing the empty-section blind spot).
- Walks every `PBXNativeTarget`, asserts each `buildPhases`/`buildConfigurationList`/`productReference` UUID resolves.
- Walks `PBXBuildFile` and asserts every `fileRef` resolves.
- Walks `PBXGroup` children and asserts every UUID resolves.
- Prints the first unresolved UUID or structural anomaly.

Run it locally; report any orphans it finds. This gives a precise failure pointer instead of Xcode's generic "damaged" message.

### 2. Remove the AgendaWidgetExtension target

Add `ios-native/scripts/remove_agenda_widget_target.py` (idempotent, mirrors the add script's UUID list) that strips every `AGWX*`, `AGBN*`, `AGWG*`, `AGLA*`, and the second-membership `AGSS*B2` / `AGAT*B2` `PBXBuildFile` entries, the widget `PBXGroup`, target, configs, configuration list, container proxy, target dependency, embed-phase file entry, and the mainGroup/Products/PBXProject `targets` references.

Run it, then verify the validator passes and `xcodebuild -showBuildSettings` succeeds on the main app target.

### 3. Re-add the widget target with a minimal, share-extension-shaped block

Rewrite `add_agenda_widget_target.py` to:

- Use the InspectFlowShareExtension target as the literal template (same build-setting keys, same ordering, same quoting).
- Drop `MTL_*` keys (they belong to graphics targets, not WidgetKit extensions) and any other settings not present on the share extension.
- Keep `GENERATE_INFOPLIST_FILE = NO` with an explicit `INFOPLIST_FILE`.
- Register the new file references as children of a real `Shared/Widget` `PBXGroup` so `SharedAgendaStore.swift` and `UpcomingEventLiveActivityAttributes.swift` are not orphan references.
- Add a `TargetAttributes` entry under `PBXProject.attributes.TargetAttributes` for the new target (`CreatedOnToolsVersion = 16.0;`), matching what Xcode 26 expects.

Re-run, then re-run the validator and `xcodebuild -showBuildSettings -target AutoInspectorNetwork -configuration Release`. Both must succeed before considering Phase 7 restored.

### 4. Fallback if the rebuild still fails

If the cleanly rebuilt target still fails to open in Xcode 26.4, ship Phase 7 without the WidgetKit extension target:

- Keep `SharedAgendaStore`, `UpcomingEventLiveActivityAttributes`, `LiveActivityController`, and `EventRepository+Snapshot.swift` compiled into the main app only (they are already in its Sources phase).
- Document in `RELEASING.md` that the Agenda widget + Live Activity require the extension target to be added through Xcode's "File → New → Target… → Widget Extension" wizard, then dragging the four widget source files in.
- This unblocks the build today and avoids further hand-edited pbxproj surgery against a moving Xcode 26 parser.

## Technical notes

- `xcodebuild`'s "JSON text did not start with array or object" line is a red herring from its result-bundle writer after the project load already failed; the real failure is the OpenStep load.
- The Node `xcode` parser succeeding does not guarantee Xcode 26 will — Apple's loader checks additional invariants (e.g. every `productReference` UUID being a member of `productRefGroup`, every file reference belonging to a group reachable from `mainGroup`). Step 1's validator targets exactly those invariants.
- `add_agenda_widget_target.py` currently registers `AGSS*F1` / `AGAT*F1` as file references with multi-segment paths (`Shared/Widget/SharedAgendaStore.swift`) but never adds them to any `PBXGroup` — Xcode 26 is the most likely platform to reject this. Step 3 fixes it.
