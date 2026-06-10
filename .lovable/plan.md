# Fix Xcode Archive Build Errors (exit 65)

Three compile errors block the Release archive. All are localized to two files plus the shared `AvailabilityRow` model.

## 1. `ActiveTripBanner` name collision
`ios-native/Features/Mileage/MileageView.swift` declares a `private struct ActiveTripBanner` that conflicts with `ios-native/Features/Dashboard/Components/ActiveTripBanner.swift` (different API: `activeTrip:` / `onPauseTrip:`). Swift resolves the call at line 93 to the public Dashboard version, causing the label/type mismatch errors, and the redeclaration error.

**Fix:** Rename the Mileage-local banner to `MileageActiveTripBanner` (kept `private` to the file). Update the single call site at line 93 to use the new name. No behavior change.

## 2. `AvailabilityRow.isAvailable` is `let`
`AvailabilitySettingsView.swift` line 23 binds `$row.isAvailable` via a `Toggle`, but `AvailabilityRow` in `DomainModels.swift` declares all properties as `let`, so the binding cannot mutate.

**Fix:** Change the mutable user-editable fields on `AvailabilityRow` to `var`: `dayOfWeek`, `startTime`, `endTime`, `isAvailable`. Keep `id` and `inspectorID` as `let`. Codable synthesis and existing decode sites remain compatible (var stored properties still decode correctly).

## Files touched
- `ios-native/Features/Mileage/MileageView.swift` — rename private `ActiveTripBanner` → `MileageActiveTripBanner` (declaration + call site).
- `ios-native/Shared/Models/DomainModels.swift` — convert four `AvailabilityRow` fields from `let` to `var`.

## Verification
- Re-read each edited file to confirm only the intended changes.
- The Bitrise/Xcode archive command should now compile; no project.pbxproj changes required.

## Out of scope
No UI, layout, or business-logic changes. No new files or migrations.
