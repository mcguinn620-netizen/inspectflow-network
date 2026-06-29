# AutoInspectorNetwork.swiftpm

Swift Playgrounds 4.4+ / Xcode 15+ App package that wraps the `ios-native/`
sources so the app can be opened and run on iPad without Xcode.

## Open

- **Swift Playgrounds (iPad / macOS):** tap `AutoInspectorNetwork.swiftpm`.
- **Xcode:** `open AutoInspectorNetwork.swiftpm` from the `ios-native/` folder.

## What's included

The `AppHost` executable target compiles the following folders from the
parent `ios-native/` directory:

- `App/` — `@main` entry point, root view, tab shell
- `Core/` — persistence, networking, schedule engine
- `Features/` — Jobs, Schedule, Inspections, Settings, etc.
- `Shared/` — brand, theme, shared models, widget store

The connector library is consumed as a local SwiftPM dependency on the
parent `ios-native/Package.swift` (`InspectFlowConnector` product).

## Intentionally excluded

Swift Playgrounds cannot build extension targets, so these are omitted:

- `CarPlay/`
- `AgendaWidgetExtension/`
- `InspectFlowShareExtension/`
- `Tests/`, `scripts/`, `docs/`, `Preview Content/`

Code paths that touch CarPlay are guarded with `#if canImport(CarPlay)`.

## Troubleshooting

- **Missing Core Data model errors** — confirm `InspectionModel.xcdatamodeld`
  and `AutoInspectorNetwork.xcdatamodeld` are still present at
  `ios-native/`; they are processed as bundle resources.
- **Auth failures** — check `Core/Network/SupabaseConfig.swift`.
- **Package resolution fails on iPad** — Swift Playgrounds requires a
  released SemVer tag for remote SwiftPM packages. The local-path
  dependency used here avoids that, but if you re-point it at the GitHub
  URL, tag a release first (see repo root `RELEASING.md`).
