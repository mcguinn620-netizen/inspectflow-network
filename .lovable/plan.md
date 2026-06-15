## Regenerate AutoInspectorNetwork.xcodeproj from scratch

Build a fresh `project.pbxproj` deterministically from the on-disk `ios-native/` source tree. No incremental repair. Every PBX object is regenerated from a template with stable, content-addressed 24-character uppercase hex UUIDs (SHA-1 of the object's stable key, truncated). All legacy IDs (synthetic, AGWX-prefixed, AAAA/AB-prefixed, etc.) are discarded.

### Source-tree mapping (preserved as today)
```text
ios-native/
  App/                          → AutoInspectorNetwork target
  CarPlay/                      → AutoInspectorNetwork target
  Core/                         → AutoInspectorNetwork target
    (excluding Tests, which stays in Package.swift only)
  Features/                     → AutoInspectorNetwork target
  Shared/                       → AutoInspectorNetwork target (+ ShareExt for shared files)
  Assets.xcassets               → AutoInspectorNetwork resources
  InspectionModel.xcdatamodeld  → AutoInspectorNetwork resources
  Info.plist                    → AutoInspectorNetwork
  AutoInspectorNetwork.entitlements
  InspectFlowShareExtension/    → InspectFlowShareExtension target
    Info.plist, .entitlements, ShareViewController.swift,
    SharedPayloadModel.swift, Base.lproj/MainInterface.storyboard
  AgendaWidgetExtension/        → AgendaWidgetExtension target
    Info.plist, .entitlements, AgendaWidget.swift, AgendaWidgetBundle.swift,
    UpcomingEventLiveActivityWidget.swift
  Shared/Widget/SharedAgendaStore.swift, UpcomingEventLiveActivityAttributes.swift
                                → also compiled into AgendaWidgetExtension
```

### Targets and preserved settings
| Target | Bundle ID | Product type | Deployment | Swift | Entitlements |
|---|---|---|---|---|---|
| AutoInspectorNetwork | com.autoinspectornetwork.ios | application | iOS 16.0 | 5.7 | AutoInspectorNetwork.entitlements |
| InspectFlowShareExtension | com.autoinspectornetwork.ios.InspectFlowShareExtension | app-extension | iOS 16.2 | 5.0 | InspectFlowShareExtension/InspectFlowShareExtension.entitlements |
| AgendaWidgetExtension | com.autoinspectornetwork.ios.AgendaWidgetExtension | app-extension | iOS 16.2 | 5.0 | AgendaWidgetExtension/AgendaWidgetExtension.entitlements |

Shared build settings preserved: `DEVELOPMENT_TEAM = 264U37X2A5`, `CODE_SIGN_STYLE = Automatic`, `MARKETING_VERSION` (0.2.0 app, 1.0 extensions), `CURRENT_PROJECT_VERSION = 1`, `TARGETED_DEVICE_FAMILY = "1,2"`, `GENERATE_INFOPLIST_FILE = NO` (extensions keep YES if currently set), app group `group.com.inspectflow.shared`.

### Build phases per target
- AutoInspectorNetwork: Sources, Frameworks, Resources, Embed Foundation Extensions (both extensions, RemoveHeadersOnCopy).
- InspectFlowShareExtension: Sources, Frameworks, Resources.
- AgendaWidgetExtension: Sources, Frameworks, Resources.

### Schemes (shared)
- `xcshareddata/xcschemes/AutoInspectorNetwork.xcscheme` — builds/runs/archives `AutoInspectorNetwork.app`.
- `xcshareddata/xcschemes/VehicleInspectorsApp.xcscheme` — alias scheme pointing at the same buildable for backward compatibility.

Both use `LastUpgradeVersion="1500"` (Xcode 15+, compatible with Xcode 16/26), `version="1.3"`.

### Project-level metadata
- `objectVersion = 56` (Xcode 14+, accepted by Xcode 16 and 26).
- `compatibilityVersion = "Xcode 14.0"`.
- `LastUpgradeCheck = 1500`, `LastSwiftUpdateCheck = 1500`.
- `BuildIndependentTargetsInParallel = 1`.
- `TargetAttributes` for all three targets with `CreatedOnToolsVersion = 15.0`.

### Swift Package dependencies
The current project has **no** SPM references in `packageReferences`/`packageProductDependencies` (both empty). The local `ios-native/Package.swift` is a separate package consumed only by tests, not by the app — its source files (`Core/InspectFlowConnector/...`) are compiled directly into the app target. The regenerated project will preserve that arrangement: no `XCRemoteSwiftPackageReference` or `XCLocalSwiftPackageReference` entries. `xcodebuild -resolvePackageDependencies` will succeed as a no-op.

### Workspace
`ios-native/AutoInspectorNetwork.xcworkspace` and `…xcodeproj/project.xcworkspace/contents.xcworkspacedata` already point at the single project file. No changes needed.

### Generator (one-shot Python script)
`ios-native/scripts/regenerate_pbxproj.py`:
1. Walk the source tree to discover Swift files per target.
2. Build the PBXGroup tree mirroring on-disk folders (top-level group is `8A23CA811AD5DE2F3F9275D1` for stability).
3. Allocate every UUID as `sha1("pbx:" + stable_key).hexdigest().upper()[:24]`, with collision guard.
4. Emit `PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXVariantGroup` (for `MainInterface.storyboard`), `PBXSourcesBuildPhase`, `PBXResourcesBuildPhase`, `PBXFrameworksBuildPhase`, `PBXCopyFilesBuildPhase` (Embed Foundation Extensions), `PBXContainerItemProxy`, `PBXTargetDependency`, `PBXNativeTarget`, `PBXProject`, `XCBuildConfiguration`, `XCConfigurationList`.
5. Write the file. Run `validate_pbxproj.py` against it.
6. Write both scheme files.

The script is checked in so the regeneration is reproducible.

### Validation in this sandbox
- `python3 ios-native/scripts/validate_pbxproj.py` — must report OK with all references resolving.
- UUID hygiene: every object key matches `^[0-9A-F]{24}$`; no `AGWX`/`AAAA`/`AB1`/`AB2`/`AB3`/`A8A0`/`MILE`/`DBUG`/`EKSVC` prefixes.
- Brace/paren balance.
- Node `xcode` parser cross-check: parses cleanly, lists exactly 3 targets.
- XML well-formedness of both `.xcscheme` files.

### macOS validation (cannot run in this sandbox)
The Bitrise `verify_project` workflow (already wired on `osx-xcode-26.4.x`) covers:
- `xcodebuild -list -project ios-native/AutoInspectorNetwork.xcodeproj`
- `xcodebuild -resolvePackageDependencies -project … -scheme AutoInspectorNetwork`
- `xcodebuild -showBuildSettings -project … -scheme AutoInspectorNetwork`
- `xcodebuild archive -project … -scheme AutoInspectorNetwork -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`

I'll add the `-showBuildSettings` step.

### Returned/replaced files
- `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` (fully regenerated)
- `ios-native/AutoInspectorNetwork.xcodeproj/xcshareddata/xcschemes/AutoInspectorNetwork.xcscheme`
- `ios-native/AutoInspectorNetwork.xcodeproj/xcshareddata/xcschemes/VehicleInspectorsApp.xcscheme`
- `ios-native/scripts/regenerate_pbxproj.py` (new, reproducible generator)
- `bitrise.yml` (add `-showBuildSettings` step)
- Workspace files: unchanged (verified pointing at the regenerated project).

### Risks / honest caveats
- Xcode itself cannot run in this Linux sandbox, so final `xcodebuild` validation must happen on Bitrise/macOS.
- A few build settings in the old pbxproj appear redundant or stale (e.g., per-config warning flags duplicated). The regenerated project will keep a sensible Xcode 15 default warning baseline plus all preserved project-specific settings listed above. If you rely on a non-default flag not visible from the current file, name it and it will be added.

### Open clarifications before I start
1. Should `ios-native/Package.swift` (`InspectFlowConnector` library) be **attached** as a Local Swift Package on the app target, replacing the direct-compile of `Core/InspectFlowConnector/*.swift` into the app? (Today they're compiled directly; cleaner SPM model is opt-in.)
2. Add a Tests target (`AutoInspectorNetworkTests` running `Tests/InspectFlowConnectorTests`) to the Xcode project, or leave tests as `swift test` only?
3. Confirm there are **no** external SPM dependencies to re-add (the current pbxproj has none).

If you answer "no/skip" to all three, I proceed exactly as planned above.