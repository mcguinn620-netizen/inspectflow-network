# Add `ios-native/project.yml` for XcodeGen

## Goal

Create a single `ios-native/project.yml` that fully describes the existing `AutoInspectorNetwork.xcodeproj` so XcodeGen can regenerate the `project.pbxproj` deterministically. Anyone (Bitrise, local devs) can run `xcodegen generate` from `ios-native/` and get a byte-identical-in-structure project — preventing pbxproj corruption like the bugs we've been chasing.

Out of scope (per answers): editing `bitrise.yml`, adding `.xcodeproj` to `.gitignore`, and adding the local `Package.swift` as a Swift package reference.

## File to create

- `ios-native/project.yml`

No other files change.

## Target inventory (extracted from `AutoInspectorNetwork.xcodeproj/project.pbxproj`)

| Target | Type | Platform | Deployment | Bundle ID |
|---|---|---|---|---|
| AutoInspectorNetwork | application | iOS | 16.2 | ios.AutoInspectorNetwork |
| InspectFlowShareExtension | app-extension | iOS | 16.2 | ios.AutoInspectorNetwork.InspectFlowShareExtension |
| AgendaWidgetExtensionExtension | app-extension (WidgetKit) | iOS | 16.1 | ios.AgendaWidgetExtension |

Shared: `DEVELOPMENT_TEAM = 264U37X2A5`, `CODE_SIGN_STYLE = Automatic`, `SWIFT_VERSION = 5.0`, `TARGETED_DEVICE_FAMILY = 1,2` (widget = 4 plus iOS family — kept as in current pbxproj).

The main app depends on both extensions and embeds them in `Embed Foundation Extensions`. The app links `ActivityKit.framework`; the widget links `WidgetKit.framework` and `SwiftUI.framework`.

## Source layout mapped to XcodeGen `sources`

XcodeGen will pick up files by directory glob, which is robust against future file additions in those folders.

### AutoInspectorNetwork (app)
- `App/`, `Core/`, `Features/`, `Shared/`, `CarPlay/` — all Swift recursively
- `InspectionModel.xcdatamodeld`, `AutoInspectorNetwork.xcdatamodeld` (compiled as sources)
- `AutoInspectorNetwork-Bridging-Header.h` (header)
- `AutoInspectorNetwork/AutoInspectorNetwork.entitlements`, `AutoInspectorNetwork/Info.plist`
- `InspectFlowShareExtension/Base.lproj/MainInterface.storyboard` is in the app's Resources phase in the current pbxproj — preserved.
- Excludes: `Core/InspectFlowConnector/` (lives in Package.swift, not in the app target per pbxproj — wait: actually it IS in the app target per pbxproj. See note below.)

Note on `Core/InspectFlowConnector/`: the current pbxproj includes these files directly in the app target (InspectFlowClient, RestClient, QueryBuilder, etc.) — they are also exposed via `Package.swift` but compiled into the app directly. We will keep them in the app target's source list (matching today's behavior). `Package.swift` stays on disk untouched but is not referenced from `project.yml`.

### InspectFlowShareExtension (appex)
- `InspectFlowShareExtension/ShareViewController.swift`
- `InspectFlowShareExtension/SharedPayloadModel.swift`
- `InspectFlowShareExtension/Base.lproj/MainInterface.storyboard` (Resources)
- `InspectFlowShareExtension/InspectFlowShareExtension-Bridging-Header.h`
- `InspectFlowShareExtension/InspectFlowShareExtension.entitlements`
- `InspectFlowShareExtension/Info.plist`

### AgendaWidgetExtensionExtension (appex)
- `AgendaWidgetExtension/AgendaWidgetExtensionLiveActivity.swift`
- `AgendaWidgetExtension/AgendaWidgetExtensionBundle.swift`
- `AgendaWidgetExtension/AgendaWidget.swift`
- `AgendaWidgetExtension/AgendaWidgetExtension.swift`
- `AgendaWidgetExtension/AgendaWidgetExtension.intentdefinition` (compiled source)
- `AgendaWidgetExtension/Assets.xcassets` (Resources)
- `AgendaWidgetExtension/AgendaWidgetExtensionExtension-Bridging-Header.h`
- `AgendaWidgetExtension/AgendaWidgetExtensionExtensionRelease.entitlements`
- `AgendaWidgetExtension/Info.plist`

## project.yml structure (high-level)

```text
name: AutoInspectorNetwork
options:
  bundleIdPrefix: ios
  deploymentTarget: { iOS: "16.2" }
  developmentLanguage: en
  createIntermediateGroups: true
  generateEmptyDirectories: true
  groupSortPosition: top
settings:
  base:
    SWIFT_VERSION: "5.0"
    DEVELOPMENT_TEAM: 264U37X2A5
    CODE_SIGN_STYLE: Automatic
    ALWAYS_SEARCH_USER_PATHS: NO
    ENABLE_STRICT_OBJC_MSGSEND: YES
    SDKROOT: iphoneos
configs:
  Debug: debug
  Release: release
targets:
  AutoInspectorNetwork: { ...app config, sources, deps, frameworks, embeds }
  InspectFlowShareExtension: { ...appex config }
  AgendaWidgetExtensionExtension: { ...widgetkit appex config }
```

Per-target blocks will set: `type`, `platform: iOS`, `deploymentTarget`, `sources` (with `excludes` where needed), `info.path`, `entitlements.path`, `dependencies` (`target:` references for the embed/depends-on relationships and `sdk:` references for system frameworks), and `settings.base` for bundle IDs, bridging headers, marketing version, plist autogen keys (orientation, scenes), and asset catalog accent/icon names.

The app target gets `dependencies` of both extensions with `embed: true` to reproduce the `Embed Foundation Extensions` copy-files phase.

## Verification steps (for whoever runs CI / locally)

1. `cd ios-native && xcodegen generate`
2. `xcodebuild -list -project AutoInspectorNetwork.xcodeproj` shows all three targets and both configs.
3. `xcodebuild -showBuildSettings -scheme AutoInspectorNetwork -configuration Release` returns the expected bundle IDs/team.
4. `xcodebuild archive ... CODE_SIGNING_ALLOWED=NO` succeeds (same as the existing Bitrise `verify_project` workflow).

## Notes / known quirks preserved verbatim

- Widget target inherits a weird `SDKROOT = watchos` from the current pbxproj. We will **override this to `iphoneos`** in `project.yml` because the widget actually builds against iOS (deployment target 16.1, family `4` is HomeScreen widget on iOS, not watchOS). Flag this in PR description.
- `Embed Foundation Extensions` phase will be regenerated automatically by `dependencies: - target: ... embed: true`.
- Bridging headers are set via `SWIFT_OBJC_BRIDGING_HEADER` in each target's `settings.base`.
- `Package.swift` stays on disk but is not wired into project.yml; the connector files compile into the app target directly as today.

After approval I'll write `ios-native/project.yml` in one pass with the full content.
