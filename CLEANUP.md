# Cleanup — files safe to remove now that `ios-native/` is the native iOS path

This is a checklist. **Nothing has been deleted yet** — review and approve, then say "do the cleanup" and I'll remove these in one pass.

## 1. Capacitor iOS shell (no longer needed)

- `ios/` — entire folder, including the unrelated `ios/App/App/NutriTrack/` sample that ended up in the project.
- `capacitor.config.ts`
- The `App/output`, `App/Pods`, `DerivedData` ignores in `ios/.gitignore` become irrelevant once `ios/` is gone.

## 2. Capacitor / Cordova node packages (`package.json`)

Remove these dependencies:

- `@capacitor/app`
- `@capacitor/cli`
- `@capacitor/core`
- `@capacitor/geolocation`
- `@capacitor/ios`
- `@capacitor/preferences`
- `@capacitor/share`
- `@ebarooni/capacitor-calendar`
- `@transistorsoft/capacitor-background-geolocation`

After removal: `bun install` (or `npm install`) to refresh the lockfile.

## 3. Web-side platform shims that target Capacitor

These aren't broken, but the native paths inside become dead code once Capacitor is gone:

- `src/platform/native.ts` — strip Capacitor branches; keep web fallbacks.
- Any Capacitor-only branches inside `src/platform/{calendar,location,maps,share,storage,export}.ts`.

## 4. Android Auto stub (not used by iOS path)

- `native/android/InspectorCarAppService.java`
- `native/README.md`
- The empty `native/` folder

## 5. Things to KEEP

- `swift-connector/` — the active Swift package the iOS app depends on.
- `ios-native/` — the new pure-SwiftUI app.
- `docs/native/CARPLAY_CONTRACT.md`, `docs/native/BACKGROUND_LOCATION_SETUP.md` — useful design references for Tier 2.
- All of `src/`, `supabase/`, `public/`, `index.html` — the web app is untouched by the native split.

## 6. Sanity checks after cleanup

- `bun run build` succeeds for the web app.
- The iOS app target in Xcode still builds (it has zero dependencies on `ios/` or Capacitor).
- `swift-connector/` still resolves as a local Swift package.
