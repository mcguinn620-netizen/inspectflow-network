# Name Change Plan — "InspectFlow Network" → "Automotive Inspector Network"

## Locked decisions
1. Web app user-visible name → **change** to "Automotive Inspector Network".
2. iOS `CFBundleDisplayName` → **stays the same**.
3. App Group + Keychain access group identifiers → **stay the same** (protects installed-app data).

---

## Phase 1 — Non-code rename (execute on approval)

### 1. GitHub
- Rename repo `inspectflow-network` → `automotive-inspector-network` (GitHub redirects old URLs).
- Update repo description + topics.
- Local clones: `git remote set-url origin <new-url>`.
- Confirm Lovable ↔ GitHub link still resolves after rename.

### 2. Lovable project
- Rename project to "Automotive Inspector Network".
- Preview/published URLs unchanged unless custom domain is re-pointed.

### 3. Bitrise
- Rename app in Bitrise dashboard; reconnect to renamed repo if it doesn't auto-follow.
- No `bitrise.yml` changes.

### 4. Web app user-visible copy
- `index.html`: `<title>`, `og:title`, `apple-mobile-web-app-title`, meta description.
- `public/manifest.webmanifest`: `name`, `short_name`, `description`.
- Top-level `README.md`, `RELEASING.md`, `CLEANUP.md`: headings + intros.

### 5. App Store / TestFlight
- Update app name, subtitle, marketing/support URLs at next submission.

### 6. Explicitly NOT changing in Phase 1
- iOS `CFBundleDisplayName`, App Group ID, Keychain access group, bundle IDs, file names, type names, Swift module names.

---

## Phase 2 — Inventory only (do NOT change yet)

If the codebase is later aligned to the new name, ~50 files contain `InspectFlow`. Grouped by blast radius:

### A. Swift package & module (highest — breaks every `import`)
- `swift-connector/Sources/InspectFlowConnector/…` (8 files)
- `swift-connector/Tests/InspectFlowConnectorTests/…`
- `swift-connector/Package.swift` — product/target `InspectFlowConnector`
- `ios-native/Package.swift` (local mirror)
- `ios-native/Core/InspectFlowConnector/…` (9 mirrored files)
- `ios-native/Tests/InspectFlowConnectorTests/AuthRefreshTests.swift`
- Every `import InspectFlowConnector` (Core/Network, Core/Sync, Core/Calendar, Core/Auth, AgendaWidgetExtension, ShareExtension, Shared, Features/Settings, Features/Schedule)
- Types: `InspectFlowClient`, `InspectFlowConfig` + references
- Proposed: `AINConnector` / `AINClient` / `AINConfig`

### B. iOS Share Extension
- Directory `ios-native/InspectFlowShareExtension/`
- `InspectFlowShareExtension.entitlements`
- `ShareViewController.swift` + references in `Shared/ImportInboxStore.swift`, `Shared/Models/SharedPayloadModel.swift`, `Shared/UI/AINFriendlyError.swift`
- Xcode target/group in `project.pbxproj`, shared scheme, `ios-native/scripts/regenerate_pbxproj.py`
- Extension bundle ID change → re-provisioning required (recommend keep)

### C. Xcode project (already `AutoInspectorNetwork` — partial cleanup only)
- `ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj` — the `InspectFlow*` extension half changes per (B)
- Schemes under `xcshareddata/xcschemes/`

### D. Supabase edge function
- `supabase/functions/intake-fetch-url/index.ts` — one cosmetic string

### E. Docs
- `README.md`, `RELEASING.md`, `swift-connector/README.md`, `ios-native/README.md`, `ios-native/PLAYGROUNDS.md`

### F. Identifiers locked to keep
- App Group ID, Keychain access group, all bundle IDs, Core Data model `InspectionModel` (already neutral).

---

## Recommended Phase 2 sequencing (when greenlit separately)
1. Rename Swift package + module, fix all `import`s, build green.
2. Rename Share Extension target/folder/class, regenerate `project.pbxproj`, build green.
3. Sweep docs + edge-function string.
4. Leave App Group / Keychain IDs untouched.
