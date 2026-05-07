# Auto Inspector Network in Swift Playgrounds (iPad)

The app is designed to build inside Swift Playgrounds 4+ on iPad with no external dependencies beyond `InspectFlowConnector`.

## Steps

1. **Swift Playgrounds → New App**.
2. **Project ▸ ⊕ ▸ Swift Package** — paste this repo's Git URL, choose `InspectFlowConnector` (Swift 5.7, iOS 16+).
   - Offline alternative: copy the `swift-connector/Sources/InspectFlowConnector` folder into the Playground's `Modules` group.
3. Drag the contents of `ios-native/App`, `Core`, `Features`, and `Shared` into the Playground.
   - **Skip** `ios-native/CarPlay/` — Playgrounds doesn't support CarPlay scenes; the rest of the code still compiles thanks to `#if canImport(CarPlay)` guards.
4. Add a Core Data model: **File ▸ New ▸ Data Model**, name it `InspectionModel`. (Empty model is fine for Tier 1.)
5. Tap **Run**.

## Limitations on Playgrounds

- No CarPlay, no widget extensions, no background location.
- Keychain works inside the Playgrounds app sandbox.
- Sign in/up, fetch profile, and live data lists all work end-to-end.

## Troubleshooting

- "Cannot find type X" — ensure `InspectFlowConnector` is added as a package and `import InspectFlowConnector` resolves.
- Auth errors — check the values in `Core/Network/SupabaseConfig.swift`.
- Empty lists — confirm the signed-in user has organization membership and rows in the corresponding tables.
