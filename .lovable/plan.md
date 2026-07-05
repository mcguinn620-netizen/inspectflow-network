# iOS App Migration Plan

Goal: extract the native iOS app (currently `ios-native/`, plus `AutoInspectorNetwork.swiftpm/` at the repo root and `swift-connector/`) into a standalone Git repository with its own Xcode setup, CI, and release pipeline — fully decoupled from this Lovable web project.

Working repo name: **`auto-inspector-ios`** (final name + org confirmed before Phase 1).

Save location for this plan (on approval, in build mode): `.lovable/ios-app-migration-plan.md`.

---

## Phase 0 — Decisions to confirm before any move

1. **Repo name & GitHub org / visibility** — `auto-inspector-ios`, same org, private?
2. **History strategy** — preserve `ios-native/` git history via `git filter-repo`, or start with a single "initial import" commit?
3. **Swift connector ownership** — the Xcode project depends on both `swift-connector/` (repo root) and a vendored copy at `ios-native/Core/InspectFlowConnector/`. Pick one:
   - a) Move `swift-connector/` into the new iOS repo as the single source of truth (simplest).
   - b) Extract `swift-connector/` into a third repo, consumed as an SPM dependency by both sides (cleanest, more work).
4. **Shared docs** — `docs/native/CARPLAY_CONTRACT.md`, `docs/native/BACKGROUND_LOCATION_SETUP.md`, Supabase types snapshot: copy into iOS repo, or link back to web repo?
5. **Secrets** — `SupabaseConfig.swift` currently hard-codes URL + anon key. Keep as-is, or move to `xcconfig` + Bitrise secrets?
6. **Bundle IDs / App Groups / Keychain groups** — must NOT change (existing installs would lose data). Migration copies them verbatim.

---

## Phase 1 — Inventory (what moves vs. stays)

**Moves to the new repo:**
- `ios-native/` (entire tree — app, extensions, CarPlay, xcodeproj, xcworkspace, xcdatamodels, entitlements, Info.plists, `project.yml`, scripts, docs, `.codex/`)
- `AutoInspectorNetwork.swiftpm/` (root-level Swift Playgrounds package)
- `swift-connector/` (per decision 3a) — becomes the canonical `InspectFlowConnector`
- `docs/native/` (CarPlay + background location design docs)
- iOS-only stanzas from `bitrise.yml`
- iOS subset of `ai-toolkit/` (skills: `swift-*`, `swiftui`, `swiftdata`, `swift-playgrounds`, `xcode14-compatibility`, `core-data`, `ios-debugging`, `app-store-deployment`, `bitrise`; agents: `ios-architect`, `swiftui-engineer`, `swift-playgrounds-specialist`, `xcode14-compatibility-specialist`, `app-store-reviewer`, `testing-engineer`)
- iOS-relevant sections of `RELEASING.md` and `CLEANUP.md`

**Stays in this web repo:**
- `src/`, `public/`, `index.html`, `supabase/`, `vite.config.ts`, `tailwind.config.ts`, `package.json`, `bun.lockb`
- `.lovable/`, Lovable Cloud config
- Web-only Bitrise workflow, README/RELEASING sections, non-iOS ai-toolkit skills

**Deleted from web repo after successful cutover:**
- `ios-native/`, `AutoInspectorNetwork.swiftpm/`, `swift-connector/`, `docs/native/`, iOS Bitrise workflow, iOS-only ai-toolkit content, iOS references in `CLEANUP.md`

---

## Phase 2 — Create the new repository

1. Create empty `auto-inspector-ios` on GitHub (no README, `main` branch).
2. In a scratch clone of this web repo, run `git filter-repo --path ios-native/ --path AutoInspectorNetwork.swiftpm/ --path swift-connector/ --path docs/native/` (or a single "initial import" commit per decision 2) to produce filtered history.
3. Push filtered history to `auto-inspector-ios`.
4. Restructure to a clean root:

```text
auto-inspector-ios/
├── AutoInspectorNetwork.xcodeproj/
├── AutoInspectorNetwork.xcworkspace/
├── AutoInspectorNetwork.swiftpm/          # from repo root
├── App/  Core/  Features/  Shared/  CarPlay/
├── AgendaWidgetExtension/
├── InspectFlowShareExtension/
├── Packages/
│   └── InspectFlowConnector/              # renamed from swift-connector/
├── docs/                                  # docs/native/ + ios-native/docs/
├── scripts/                               # from ios-native/scripts/
├── ai-toolkit/                            # iOS subset only
├── project.yml                            # XcodeGen source of truth
├── Package.swift                          # top-level SPM
├── bitrise.yml
├── README.md
└── RELEASING.md
```

---

## Phase 3 — Rewrite paths & regenerate the Xcode project

1. Update `project.yml` source paths (drop the `ios-native/` prefix).
2. Update `AutoInspectorNetwork.swiftpm/Package.swift`:
   - `path: "ios-native"` → `path: "."`
   - `.package(name: "InspectFlowConnector", path: "ios-native")` → `path: "Packages/InspectFlowConnector"`
3. Migrate `ios-native/Package.swift` → `Packages/InspectFlowConnector/Package.swift`; move sources from `Core/InspectFlowConnector` → `Sources/InspectFlowConnector`.
4. Update `scripts/regenerate_pbxproj.py` and other `scripts/*.py` for the new root.
5. Regenerate `project.pbxproj` with `xcodegen generate` and commit.
6. Update `bitrise.yml` (remove `cd ios-native`); re-run `verify_project` workflow (`xcodebuild -list`, `-resolvePackageDependencies`, unsigned `archive`) on `osx-xcode-26.4.x`.
7. Update `README.md`, `PLAYGROUNDS.md`, `RELEASING.md`, `.codex/` docs to drop the `ios-native/` prefix.

---

## Phase 4 — Wire the new repo's tooling

- **CI**: standalone `bitrise.yml` — workflows `verify_project`, `unit_tests`, `archive_and_export`, triggered on push to `main` and PRs.
- **Signing**: same team ID (`264U37X2A5`), automatic signing for Debug, manual profiles (App Store + Ad Hoc) for Release, stored as Bitrise code-signing files.
- **Secrets**: Supabase URL + anon key remain committed (safe by design); any future service-role keys move to Bitrise env vars.
- **AI toolkit**: copy the iOS-only skills/agents; update `ai-toolkit/lovable-agent-config.json` for the new repo.
- **Repo hygiene**: seed `CODEOWNERS`, issue templates, and a `CONTRIBUTING.md` focused on iOS.

---

## Phase 5 — Cutover in this web repo (only after new repo is green)

1. Delete `ios-native/`, `AutoInspectorNetwork.swiftpm/`, `swift-connector/`, `docs/native/`, iOS-only ai-toolkit content, iOS Bitrise workflow.
2. Trim `README.md` and `RELEASING.md` to web-only; add pointer: "Native iOS app lives at github.com/<org>/auto-inspector-ios".
3. Update or delete `CLEANUP.md` iOS references.
4. Confirm `bun run build` succeeds and the Lovable preview renders.
5. Add a CI guard (or pre-commit hook) in the web repo that fails on any change under the removed paths.

---

## Phase 6 — Post-migration verification

- **New repo**: `xcodegen generate && xcodebuild -list && xcodebuild -resolvePackageDependencies && xcodebuild archive -scheme AutoInspectorNetwork -configuration Release -archivePath build/AIN.xcarchive CODE_SIGNING_ALLOWED=NO` all green on Bitrise.
- **New repo**: `AutoInspectorNetwork.swiftpm` opens in Swift Playgrounds and Xcode without "outside package root" errors.
- **Web repo**: `bun run build` succeeds, Playwright smoke on `/auth` passes, Lovable preview loads.
- **Both repos**: fresh clone → contributor can build without cross-repo dependencies (unless decision 3b was chosen).

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Losing iOS git history | Use `git filter-repo` with the exact path list in Phase 2 |
| Broken pbxproj after path rewrite | Regenerate via XcodeGen from `project.yml`, not hand-edited; Phase 6 CI catches regressions |
| Bitrise triggers colliding | Two Bitrise apps, one per repo, each with its own `bitrise.yml` |
| Contributors still pushing iOS to web repo | Post-cutover CI guard + `CODEOWNERS` in web repo |
| Bundle ID / App Group / Keychain drift breaking installs | Migration copies IDs and entitlements verbatim; explicit checklist item in Phase 6 |
| Duplicate `SharedPayloadModel.swift` between app + share extension | Track as known debt; addressed in a follow-up (extract to shared SPM module in `Packages/`) |

---

## Deliverables checklist

- [ ] Decisions 1–6 confirmed
- [ ] `auto-inspector-ios` repo created with filtered history
- [ ] `project.yml`, `Package.swift` files, and `scripts/regenerate_pbxproj.py` updated for the new root
- [ ] `xcodegen generate` produces a green `xcodebuild archive` on Bitrise
- [ ] `AutoInspectorNetwork.swiftpm` opens cleanly in Playgrounds + Xcode
- [ ] iOS files removed from web repo; `bun run build` still green
- [ ] READMEs on both sides updated with cross-links
- [ ] This plan saved to `.lovable/ios-app-migration-plan.md`
