# Releasing InspectFlowConnector

Swift Playgrounds (iPad) can only resolve Swift Packages by **SemVer tag** — it cannot select a branch. Every release therefore needs an annotated Git tag pushed to GitHub.

## Current release

**`v0.1.1`** — fixes invalid `.iPadOS` platform entry in `Package.swift` (SwiftPM has no `iPadOS` case; iPad inherits the iOS minimum). Use this tag in Playgrounds and Xcode.

> If you already tagged `v0.1.0` against the broken manifest, leave it in place and just cut `v0.1.1` — Playgrounds users select "Up to Next Major from 0.1.1" and SwiftPM picks the newer tag.

## Cut a new release

```bash
# 1. Sync main
git checkout main
git pull origin main

# 2. Tag (replace version)
git tag -a v0.1.1 -m "InspectFlowConnector 0.1.1 — fix Package.swift platforms"

# 3. Push the tag
git push origin v0.1.1
```

Then publish a GitHub Release:
- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new?tag=v0.1.1
- Title: `InspectFlowConnector 0.1.1`
- Notes: Removed invalid `.iPadOS(.v16)` from `Package.swift`. Swift 5.7 / iOS 16+. Auth, PostgREST, Realtime, Storage, Edge Functions.
- Click **Publish release**.

### No git locally? Tag from the GitHub UI

- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new
- "Choose a tag" dropdown → type `v0.1.1` → click **Create new tag: v0.1.1 on publish**
- Target: `main` (make sure the Package.swift fix is merged first)
- Title + notes as above → **Publish release**.

## Versioning

- `0.x.y` while pre-1.0. Bump minor for new APIs, patch for fixes.
- After 1.0, follow strict SemVer.
