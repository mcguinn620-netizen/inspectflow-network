## Fix Package.swift platform list

**Root cause:** SwiftPM's `SupportedPlatform` enum has no `iPadOS` case. iPad is covered by `.iOS`. The bogus entry also breaks `.v16` resolution, which cascades into the "Mach-O couldn't be generated" manifest evaluation failure.

**Change (one file):**

`Package.swift` — replace the platforms line:

```swift
platforms: [.iOS(.v16), .macOS(.v12)],
```

(drop `.iPadOS(.v16)`; iPad already inherits the iOS 16 minimum)

**Then re-tag:**

Since `v0.1.0` was cut against the broken manifest, after pushing the fix run:

```bash
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
git tag -a v0.1.0 -m "InspectFlowConnector 0.1.0 — Tier 1"
git push origin v0.1.0
```

Or bump to `v0.1.1` instead (cleaner — no force-retag) and use "Up to Next Major from 0.1.1" in Playgrounds.

**Docs touch-up:** update `RELEASING.md` and `ios-native/PLAYGROUNDS.md` only if we go with `v0.1.1`.

**Out of scope:** no connector source changes. Still Swift 5.7 / iOS 16 / Xcode 14 compatible.

**Credits:** ~1.

Reply **"go with v0.1.1"** (recommended) or **"go and retag v0.1.0"**.
