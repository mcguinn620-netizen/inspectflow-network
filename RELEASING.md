# Releasing InspectFlowConnector

Swift Playgrounds (iPad) can only resolve Swift Packages by **SemVer tag** — it cannot select a branch. Every release therefore needs an annotated Git tag pushed to GitHub.

## Current release

**`v0.2.0`** — Tier 2 connector additions (no breaking changes):

- `StorageClient`: photo upload + signed URL helpers used by inspection attachments.
- `RealtimeChannel`: per-feature `postgres_changes` subscriptions for `inspection_requests`, `jobs`, and `trips`.
- `FunctionsClient`: typed invoke for the new `notify-inspector` edge function.

Use this tag in Playgrounds and Xcode (rule: **Up to Next Major from 0.2.0**).

## Previous releases

- `v0.1.1` — fixed invalid `.iPadOS` platform entry in `Package.swift`.
- `v0.1.0` — initial Tier 1 (Auth, PostgREST, Realtime, Storage, Edge Functions). Built against the broken manifest; superseded by `v0.1.1`.

## Cut a new release

```bash
# 1. Sync main
git checkout main
git pull origin main

# 2. Tag (replace version)
git tag -a v0.2.0 -m "InspectFlowConnector 0.2.0 — Tier 2 (storage + realtime + functions)"

# 3. Push the tag
git push origin v0.2.0
```

Then publish a GitHub Release:
- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new?tag=v0.2.0
- Title: `InspectFlowConnector 0.2.0`
- Notes: Tier 2 — typed realtime handlers, photo upload helper, typed function invoke. Swift 5.7 / iOS 16+. No breaking changes vs `0.1.1`.
- Click **Publish release**.

### No git locally? Tag from the GitHub UI

- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new
- "Choose a tag" dropdown → type `v0.2.0` → click **Create new tag: v0.2.0 on publish**
- Target: `main` (make sure all Tier 2 code is merged first)
- Title + notes as above → **Publish release**.

## Versioning

- `0.x.y` while pre-1.0. Bump minor for new APIs, patch for fixes.
- After 1.0, follow strict SemVer.
