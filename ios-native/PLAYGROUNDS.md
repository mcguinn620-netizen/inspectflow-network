# Auto Inspector Network in Swift Playgrounds (iPad)

The app builds inside Swift Playgrounds 4+ on iPad with no external dependencies beyond `InspectFlowConnector`.

## Steps

1. **Swift Playgrounds → New App**.
2. **Project ▸ ⊕ ▸ Swift Package**
   - URL: `https://github.com/mcguinn620-netizen/inspectflow-network.git`
   - Version rule: **Up to Next Major Version** from `0.2.0`
   - Add → choose product **InspectFlowConnector**.
3. Drag the contents of `ios-native/App`, `Core`, `Features`, and `Shared` into the Playground.
   - **Skip** `ios-native/CarPlay/` — Playgrounds doesn't support CarPlay scenes; the rest of the code still compiles thanks to `#if canImport(CarPlay)` guards.
4. Add a Core Data model: **File ▸ New ▸ Data Model**, name it `InspectionModel`. (Empty model is fine for Tier 1.)
5. Tap **Run**.

## Troubleshooting

- **"no version tags" when adding the package** — the repo needs a SemVer tag (e.g. `v0.1.0`) before Playgrounds can resolve it. See `RELEASING.md` at the repo root for the one-time tag steps. Xcode 14 can use a branch instead, but Playgrounds cannot.
- **"Cannot find type X"** — make sure `InspectFlowConnector` is added as a package and `import InspectFlowConnector` resolves.
- **Auth errors** — check `Core/Network/SupabaseConfig.swift`.
- **Empty lists** — confirm the signed-in user has organization membership and rows in the corresponding tables.

## Offline / no-network fallback

If you can't fetch the package, copy `swift-connector/Sources/InspectFlowConnector` into the Playground's `Modules` group instead of adding the Swift Package. Everything else is the same.

## Limitations on Playgrounds

- No CarPlay, no widget extensions, no background location.
- Keychain works inside the Playgrounds app sandbox.
- Sign in/up, fetch profile, and live data lists all work end-to-end.
