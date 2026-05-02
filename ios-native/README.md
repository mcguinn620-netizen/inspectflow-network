# InspectFlow Native iOS (SwiftUI)

This folder contains a drop-in native iOS foundation targeting **Xcode 14** and **iOS 16+**.

## Architecture
- `App`: app lifecycle, tab shell, root auth routing
- `Core`: auth, network, persistence, sync engine, offline mutation queue
- `Features`: route-aligned SwiftUI feature modules
- `Shared`: shared models + reusable UI pieces
- `CarPlay`: CarPlay scaffolding for active trip and schedule-safe controls

## Offline-first strategy
- Launch from Core Data cache first
- Session persisted in Keychain
- `NWPathMonitor` drives online/offline status
- `MutationQueue` stages offline writes for replay when online

## Backend mapping
Supabase table/domain coverage includes:
`profiles`, `user_roles`, `inspectors`, `jobs`, `trips`, `trip_stops`, `trip_location_points`, `vehicles`, `inspection_requests`, `inspection_templates`, `dispatch_assignments`, `organizations`, `organization_users`.

## Next steps
1. Create an Xcode project and add these files/groups as-is.
2. Replace placeholders in `SupabaseConfig.swift`.
3. Implement typed Supabase endpoints in `SupabaseService`.
4. Add Core Data entities mirroring cached app slices.
5. Add background refresh and push-triggered sync.
