# InspectFlowConnector

Pure-Swift, zero-dependency Supabase/Lovable Cloud client used by the Auto Inspector Network iOS app.

- iOS 16+, macOS 12+
- Swift 5.7 (Xcode 14+ and Swift Playgrounds 4+ compatible)
- Auth, REST (PostgREST), Realtime, Storage, Edge Functions
- Session persisted in Keychain via `SessionStore`

## Releases

The canonical `Package.swift` lives at the **repo root**. Releases are SemVer Git tags on `main` (e.g. `v0.1.0`). See `RELEASING.md` at the repo root.

## Install (Xcode 14)

File ▸ Add Packages ▸ paste `https://github.com/mcguinn620-netizen/inspectflow-network.git`, version "Up to Next Major" from `0.1.0`.

Or, for local development: File ▸ Add Packages ▸ **Add Local…** ▸ select the repo root folder.

## Install (Swift Playgrounds on iPad)

Project ▸ ⊕ ▸ **Swift Package**
- URL: `https://github.com/mcguinn620-netizen/inspectflow-network.git`
- Version rule: **Up to Next Major Version** from `0.1.0`

> Playgrounds requires a SemVer tag — branches are not supported. If you see "no version tags," follow `RELEASING.md` to publish `v0.1.0`.

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
