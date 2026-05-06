# InspectFlow Swift Connector

A drop-in Swift client for authenticating users and reading/writing the
InspectFlow backend (Lovable Cloud / Supabase) from any Swift app — iOS,
macOS, server-side Swift, or CLI.

## What's included

```
swift-connector/
├── Package.swift                    # SwiftPM manifest (iOS 15+, macOS 12+)
└── Sources/InspectFlowConnector/
    ├── InspectFlowConfig.swift      # Project URL + anon key
    ├── InspectFlowClient.swift      # High-level entry point
    ├── Auth/
    │   ├── AuthClient.swift         # signUp / signIn / signOut / refresh
    │   ├── SessionStore.swift       # Keychain-backed JWT persistence
    │   └── AuthModels.swift         # Session, User
    ├── Database/
    │   ├── RestClient.swift         # PostgREST wrapper (select/insert/update/delete)
    │   └── QueryBuilder.swift       # Filter / order / limit DSL
    ├── Realtime/
    │   └── RealtimeChannel.swift    # WebSocket subscription helper
    ├── Storage/
    │   └── StorageClient.swift      # Signed URL + upload helpers
    └── Functions/
        └── FunctionsClient.swift    # Invoke edge functions
```

## Quick start

```swift
import InspectFlowConnector

let client = InspectFlowClient(
  url: URL(string: "https://aqtcgybbqdyjasgnuwlh.supabase.co")!,
  anonKey: "<VITE_SUPABASE_PUBLISHABLE_KEY>"
)

// 1. Sign in
let session = try await client.auth.signIn(email: "you@x.com", password: "•••")

// 2. Query a table (RLS automatically scopes to the signed-in user)
let trips: [Trip] = try await client.db
  .from("trips")
  .select()
  .eq("status", "active")
  .order("created_at", ascending: false)
  .execute()

// 3. Insert a row
try await client.db.from("trip_stops").insert([
  "trip_id": tripId.uuidString,
  "label": "Customer site",
  "status": "pending"
]).execute()

// 4. Subscribe to realtime changes
let channel = client.realtime.channel("trip_stops")
channel.onPostgresChange(event: .all, table: "trip_stops") { payload in
  print("change:", payload)
}
try await channel.subscribe()

// 5. Invoke an edge function
let parsed: ParseResult = try await client.functions.invoke(
  "parse-inspection",
  body: ["url": pdfURL.absoluteString]
)
```

## Notes

- The anon key is **publishable** — safe to ship in client apps. Never embed
  the service-role key in a client.
- All requests automatically include `apikey` + `Authorization: Bearer <jwt>`
  headers when a session exists; RLS in the database does the actual access
  control.
- Sessions are persisted in the Keychain (`com.inspectflow.connector` /
  `session`) and refreshed automatically before expiry.
- If you already use the official `supabase-swift` SDK, you can swap that in
  — this connector exists for projects that want zero external deps.
