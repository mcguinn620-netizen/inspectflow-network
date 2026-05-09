# Releasing InspectFlowConnector

Swift Playgrounds (iPad) can only resolve Swift Packages by **SemVer tag** — it cannot select a branch. Every release therefore needs an annotated Git tag pushed to GitHub.

## Cut a new release

```bash
# 1. Sync main
git checkout main
git pull origin main

# 2. Tag (replace version)
git tag -a v0.1.0 -m "InspectFlowConnector 0.1.0 — Tier 1 (Auth, REST, Realtime, Storage, Functions)"

# 3. Push the tag
git push origin v0.1.0
```

Then publish a GitHub Release:
- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new?tag=v0.1.0
- Title: `InspectFlowConnector 0.1.0`
- Notes: Initial tagged release. Swift 5.7 / iOS 16+. Auth, PostgREST, Realtime, Storage, Edge Functions.
- Click **Publish release**.

### No git locally? Tag from the GitHub UI

- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new
- "Choose a tag" dropdown → type `v0.1.0` → click **Create new tag: v0.1.0 on publish**
- Target: `main`
- Title + notes as above → **Publish release**.

## Versioning

- `0.x.y` while pre-1.0. Bump minor for new APIs, patch for fixes.
- After 1.0, follow strict SemVer.
