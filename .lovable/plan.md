## Diagnosis

**Build error — duplicate symbols.** Two files declare the same public types (`RealtimeEvent`, `RealtimeClient`, `RealtimeChannel`):

- `ios-native/Core/InspectFlowConnector/Realtime/RealtimeChannel.swift` (canonical — wired into `InspectFlowClient`)
- `ios-native/Core/Realtime/RealtimeChannel.swift` (stray duplicate, byte-identical)

Both are listed in the `AutoInspectorNetwork` Sources build phase of the regenerated `project.pbxproj` (refs `B19E546E…` and `B19E5478…`), so the Swift compiler emits "invalid redeclaration" for every type in the file. This is the parser/compile error blocking the build.

**Realtime "config" issue.** `RealtimeChannel.subscribe()` in the connector sends a `phx_join` to `realtime:<topic>` but:

1. Never includes `access_token` in the join `payload` → Supabase Realtime rejects `postgres_changes` against any RLS-protected table; the channel joins but no row events are ever delivered.
2. No `phx_heartbeat` is sent → Supabase closes the socket after ~30s, and our reconnect path silently swallows the error in `receiveLoop` (`catch { return }`).
3. The join `config.postgres_changes` array is built from `handlers` at call time, but `RealtimeSubscriptions.*` registers the handler then calls `subscribe()` — that ordering is OK, but a second `onPostgresChange` after `subscribe()` would silently never be wired. Worth a guard.

These three together match the reported "realtime config issue in InspectFlow connector and Core/Realtime".

## Changes

1. **Delete** `ios-native/Core/Realtime/RealtimeChannel.swift` (the stray copy). Keep `ios-native/Core/Realtime/RealtimeSubscriptions.swift` — it consumes the public types from the connector file, which compiles into the same target.
2. **Regenerate the pbxproj** by re-running `ios-native/scripts/regenerate_pbxproj.py` so the deleted file is dropped from PBXFileReference / PBXGroup / Sources build phase. Validate with `validate_pbxproj.py`.
3. **Fix `Core/InspectFlowConnector/Realtime/RealtimeChannel.swift`:**
  - On `subscribe()`, read the current access token from `SessionStore` and include it as `payload.access_token` (and `payload.config.broadcast`/`presence` empty objects, matching the Supabase Realtime v2 schema).
  - Start a heartbeat `Task` in `RealtimeClient.connectIfNeeded()` that sends `{topic:"phoenix", event:"phx_heartbeat", payload:{}, ref:…}` every 25s while the task is `.running`; stop it when the socket dies.
  - When `auth.onTokenRefresh` fires (or on next subscribe), send `{event:"access_token", payload:{access_token:…}}` on each joined channel so RLS keeps working.
  - In `receiveLoop`, on `catch` clear `self.task` and tear down the heartbeat so the next `send` triggers a fresh connect instead of using a dead socket.
  - Guard `onPostgresChange` after `subscribe()` by logging (or re-sending join) so silent misconfiguration is visible.
4. **Verify** by re-running the same checks the regen script already uses (`validate_pbxproj.py`, Node `xcode` parser) and `xcodebuild -list` / `-showBuildSettings`.

## Files touched

- delete `ios-native/Core/Realtime/RealtimeChannel.swift`
- edit `ios-native/Core/InspectFlowConnector/Realtime/RealtimeChannel.swift`
- regenerate `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` via existing script

No scheme, entitlement, bundle-ID, or Bitrise changes required.

additionally migrate `Core/Realtime/RealtimeSubscriptions.swift` into the `InspectFlowConnector/Realtime/` folder so all realtime code lives in one place. 