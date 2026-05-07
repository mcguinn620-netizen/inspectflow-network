# InspectFlowConnector

Pure-Swift, zero-dependency Supabase/Lovable Cloud client used by the Auto Inspector Network iOS app.

- iOS 16+, macOS 12+
- Swift 5.7 (Xcode 14+ and Swift Playgrounds 4+ compatible)
- Auth, REST (PostgREST), Realtime, Storage, Edge Functions
- Session persisted in Keychain via `SessionStore`

## Install (Xcode 14)

File ▸ Add Packages ▸ **Add Local…** ▸ select the `swift-connector/` folder.

## Install (Swift Playgrounds on iPad)

Project ▸ ⊕ ▸ **Swift Package** ▸ paste this repo's Git URL ▸ choose `InspectFlowConnector`.

## Usage

```swift
import InspectFlowConnector

let client = InspectFlowClient(
    url: URL(string: "https://YOUR.supabase.co")!,
    anonKey: "YOUR_PUBLISHABLE_KEY"
)

let session = try await client.auth.signIn(email: "a@b.com", password: "...")
let trips: [Trip] = try await client.db.from("trips")
    .select()
    .eq("user_id", session.user.id.uuidString)
    .order("created_at", ascending: false)
    .limit(50)
    .execute()
```
