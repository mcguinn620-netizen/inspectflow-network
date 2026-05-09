
# Fix: Swift Playgrounds "no version tags" for `InspectFlowConnector`

## Why it's failing

Swift Playgrounds' "Add Package" on iPad only resolves **SemVer tags** — it cannot pick a branch like Xcode 14 can. Your repo `inspectflow-network` has no tags yet, so the resolver returns "no version tags."

Secondary issue: there are **two** `Package.swift` files — one at the repo root and one inside `swift-connector/`. SwiftPM uses the root one when you add the repo URL. Two manifests is fragile; we'll consolidate.

## What I'll change in the codebase

1. **Delete** `swift-connector/Package.swift` (duplicate). Root `Package.swift` stays canonical.
2. **Edit** `ios-native/PLAYGROUNDS.md` — rewrite the "Add Package" step to use the GitHub URL with version rule "Up to Next Major from 0.1.0", plus a troubleshooting note about tags. Keep the offline fallback.
3. **Edit** `swift-connector/README.md` — same install instructions + Releases section.
4. **Edit** `ios-native/README.md` — one-line pointer to tagged release.
5. **Create** `RELEASING.md` at repo root — short checklist for future tag bumps.

## What you'll do on GitHub (copy/paste)

I'll include this exact block in `RELEASING.md` and in the chat reply when I'm done. You run it locally against your clone of `inspectflow-network`:

```bash
# 1. Make sure you're on the latest main
git checkout main
git pull origin main

# 2. Create an annotated SemVer tag
git tag -a v0.1.0 -m "InspectFlowConnector 0.1.0 — Tier 1 (Auth, REST, Realtime, Storage, Functions)"

# 3. Push the tag
git push origin v0.1.0
```

Then on GitHub:
- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new?tag=v0.1.0
- Title: `InspectFlowConnector 0.1.0`
- Notes: "Initial tagged release. Swift 5.7 / iOS 16+. Auth, PostgREST, Realtime, Storage, Edge Functions."
- Click **Publish release**.

Don't have `git` on your machine? Alternative — purely in the GitHub UI:
- Open https://github.com/mcguinn620-netizen/inspectflow-network/releases/new
- In the "Choose a tag" dropdown, type `v0.1.0` → click "Create new tag: v0.1.0 on publish"
- Target: `main`
- Title + notes as above → **Publish release**. (This both creates the tag and the release.)

## After the tag exists

In Swift Playgrounds:
- Project ▸ ⊕ ▸ **Swift Package**
- URL: `https://github.com/mcguinn620-netizen/inspectflow-network.git`
- Version rule: **Up to Next Major Version** → `0.1.0`
- Add → import `InspectFlowConnector`.

## Out of scope

- No connector code changes (already 5.7-compatible).
- No change to Xcode 14 "Add Local" flow.

## Credit estimate

~2 credits (docs + one delete).

Reply **"go"** to execute.
