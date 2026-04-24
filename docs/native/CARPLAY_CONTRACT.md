# CarPlay / Android Auto Data Contract

CarPlay (iOS) and Android Auto cannot render the React web UI. The native
shells in `native/ios/CarPlaySceneDelegate.swift` and
`native/android/InspectorCarAppService.java` are thin projections of the data
the web app already produces. They read from the same Supabase backend.

## Tables consumed (read)

- `trips` where `user_id = auth.uid() AND status IN ('active','planned')`
- `trip_stops` where `trip_id = <active trip>`, ordered by `sort_order`
- `jobs` for `customer_name`, `location` (joined via `trip_stops.job_id`)

## Auth

The native layer reads the JWT persisted by Capacitor Preferences under the
key Supabase uses for storage (default `sb-<project-ref>-auth-token` if you
keep `@supabase/supabase-js` defaults). Use it as the `Authorization: Bearer`
header on REST calls; the project's anon key goes into the `apikey` header.

## Stop projection

Each row rendered in the CarPlay list / Android Auto pane is reduced to:

```json
{
  "id": "uuid",
  "label": "Customer name or stop label",
  "address": "Street address, City, State",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "status": "pending|arrived|completed|skipped",
  "etaMinutes": 12
}
```

`etaMinutes` is computed natively from the device GPS and the route distance —
do not rely on Supabase to provide it.

## Actions written back

| User action in car | HTTP call |
|---|---|
| Tap "Arrived"      | `PATCH /rest/v1/trip_stops?id=eq.<id>` `{ "status": "arrived", "arrived_at": "<iso>" }` |
| Tap "Skip"         | `PATCH /rest/v1/trip_stops?id=eq.<id>` `{ "status": "skipped" }` |
| Tap "Navigate"     | Open Apple Maps / Google Maps universal link (no Supabase write) |

The web app picks these changes up via the realtime subscription in
`src/hooks/useActiveTrip.tsx` — no extra plumbing needed.

## Out of scope for Lovable

- Apple CarPlay entitlement application (developer.apple.com)
- Xcode signing + scene plist wiring
- Google Cars App Library Desktop Head Unit testing
- Background location authorization prompts (must be added in
  `Info.plist` / `AndroidManifest.xml`)
