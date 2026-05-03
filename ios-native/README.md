# InspectFlow Native iOS (SwiftUI)

This folder now contains a buildable native iOS foundation for **Xcode 14** and **iOS 16+**.

## Architecture
- `App`: app lifecycle, tab shell, root auth routing
- `Core`: auth, network, persistence, sync engine, offline mutation queue
- `Features`: route-aligned SwiftUI feature modules
- `Shared`: shared models + reusable UI pieces
- `CarPlay`: CarPlay scaffolding for active trip and schedule-safe controls

## Project setup
- Open `ios-native/InspectFlowNative.xcodeproj` in Xcode 14+.
- `Resources/Info.plist` is wired to build settings.
- `Resources/Assets.xcassets` contains placeholder AppIcon + AccentColor.
- Core Data model exists at `Core/Persistence/InspectionModel.xcdatamodeld`.

## Supabase configuration
1. Copy `ios-native/Config/Secrets.xcconfig.example` to `ios-native/Config/Secrets.xcconfig`.
2. Set:
   - `SUPABASE_URL = https://<your-project>.supabase.co/rest/v1/`
   - `SUPABASE_ANON_KEY = <your-anon-key>`
3. Keep `Secrets.xcconfig` local/private; do not commit real secrets.

At runtime, `SupabaseConfig` reads these values from `Info.plist` (via build settings).

## Placeholder state intentionally included
- `AuthViewModel.signIn()` is a compile-safe placeholder with TODOs for Supabase auth.
- `CarPlayTripService` returns DEBUG-only mock trip/stops so CarPlay templates can render in development.
- Core Data model is minimal and safe for launch.

## Next steps
1. Wire Supabase Swift Auth and persist session in `KeychainStore`.
2. Expand Core Data entities and add repository layer.
3. Replace mock CarPlay data with live trip feed.
4. Add background refresh and push-triggered sync.
