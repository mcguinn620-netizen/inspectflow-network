# iOS Native — Tier 3 & Tier 4 Plan

Picks up from completed Tier 1 (auth, navigation, scaffolding) and Tier 2 (offline sync, trips, inspections, realtime, CarPlay, push). Goal: turn the read-mostly list app into a polished, write-capable native experience, then layer revenue + advanced platform features. Each step is sized to be a discrete, approvable unit so credits can be released a step at a time.

## Constraints (carry forward)
- Xcode 14 / iOS 16 / Swift 5.7 / Swift Playgrounds 4 compatible.
- No third-party SDKs. Backend through vendored `InspectFlowConnector`.
- All writes go through `Outbox` → `SyncEngine` (offline-first stays sacred).
- `AuditLogger` on every CUD.
- Must stay schema-compatible with `VehicleInspectorsApp_Commercial_v2`.

---

## Tier 3 — Write-capable UX + revenue + intelligence

Focus: convert read-only lists into editable, actionable surfaces with a real design system, then enable billing and the AI/intake features promised in the web product.

### Step 3.1 — Design system pass (UI/UX foundation)
Establishes the visual language every later step inherits. Cheapest step to do first because it gates the look of everything else.

- `Shared/Brand/AINTheme.swift` — token layer mirroring web (Deep Navy, Electric Blue, Emerald/Amber/Rose, Inter, Roboto Mono for VIN/IDs).
- `Shared/UI/` reusable components:
  - `AINCard`, `AINSectionHeader`, `AINStatusPill` (pass/warn/fail/neutral),
  - `AINEmptyState`, `AINLoadingState`, `AINErrorState`,
  - `AINPrimaryButton`, `AINSecondaryButton`, `AINIconButton`,
  - `AINTextField`, `AINSearchField`, `AINPickerRow`, `AINToggleRow`,
  - `AINBottomSheet`, `AINConfirmDialog`, `AINToast`.
- Tab bar + nav bar restyle to match web Linear/Stripe vibe.
- Skeleton loaders replace spinners on every list.
- Apply to one screen end-to-end (Dashboard) as the reference.

### Step 3.2 — Vehicles read+write
- `VehicleDetailView` with sections: Identity (VIN mono), Specs, Recalls, History.
- `VehicleEditSheet`: VIN scan stub (manual + camera entry), make/model/year picker, nickname.
- VIN intelligence call (existing edge fn) auto-populates specs; recall flag pill.
- Soft-delete with confirm dialog; restore from trash list.
- Outbox writes; realtime refresh.

### Step 3.3 — Jobs / Inspection requests read+write
- `JobDetailView` with customer, vehicle, location (Open in Maps), scheduled time, status timeline.
- `JobEditSheet`: reschedule, reassign (respecting role), add notes.
- Quick actions on row: Start Inspection, Navigate, Call, Mark Complete.
- Status changes flow through lifecycle constraints from `mem://features/inspections`.

### Step 3.4 — Schedule + dispatch surface
- `ScheduleView` rebuilt as week grid (mirrors web `ScheduleWeekGrid`) with drag-to-reschedule (long-press + move).
- Conflict detection inline (uses `scheduleConflicts.ts` logic ported to Swift).
- For dispatcher role: assign-to-inspector sheet using intelligent dispatch edge fn.

### Step 3.5 — Inspector daily flow polish
- `StartMyDayCard`, `NextStopCard`, `ActiveTripBanner` ported as native components.
- Voice-cue toggle for CarPlay-free driving.
- Inspector dashboard becomes the home tab for inspector role.

### Step 3.6 — Stripe billing (Inspector / Company / Enterprise)
- `Settings → Subscription` screen using StoreKit 2 in-app purchase OR web checkout fallback (StoreKit preferred for App Store compliance).
- `subscriptions` table + `entitlements` view consumed via realtime.
- Paywalls on premium features (AI intake, advanced reporting).

### Step 3.7 — AI intake (email/PDF parsing) on device
- `Inbox` tab for inspectors/companies: lists `intake_items`.
- Tap → `IntakeReviewScreen`: parsed fields editable, confirm to create inspection request.
- Forwarding email address shown with copy button.
- Uses existing `parse-inspection` edge function.

### Step 3.8 — Reporting + client portal hand-off
- `Inspection Complete` screen → "Generate Report" button → triggers PDF edge fn → share sheet.
- Client portal magic-link copy/share.
- Repair-estimate conversion entry point on failed items (writes to `repair_estimates`).

Suggested order: 3.1 → 3.2 → 3.3 → 3.4 → 3.5 → 3.6 → 3.7 → 3.8. Each step is independently shippable.

---

## Tier 4 — Platform depth + parity with web

Focus: features that need entitlements, background work, or platform-only APIs. Higher complexity per step; do only after Tier 3 is stable.

### Step 4.1 — Apple Sign In + biometric unlock
- `Sign in with Apple` button on `AuthView` (required by App Store if any social login present).
- Face ID / Touch ID gate on app launch (opt-in in Settings).

### Step 4.2 — Home Screen + Lock Screen widgets
- WidgetKit extension: Today's stops, Active trip mileage, Pending inspections count.
- Small / Medium / Lock-screen rectangular variants.
- Timeline provider hits Core Data cache (no network).

### Step 4.3 — Live Activities for active trip / inspection
- ActivityKit live activity: trip in progress (mileage, ETA), inspection in progress (section x of y).
- Dynamic Island compact + expanded layouts.

### Step 4.4 — Apple Watch companion
- `AIN Watch` target: glance current job, start/stop trip, mark checklist item pass/fail by voice or tap.
- WatchConnectivity bridge to phone outbox.

### Step 4.5 — Tax + Drive parity
- `TaxView` native: federal + state tables (ported from `src/data/`), mileage deduction calc from trips.
- Year-to-date export (CSV) via share sheet.

### Step 4.6 — Template marketplace browser
- Native browser for marketplace templates, install-to-company flow, version pinning.

### Step 4.7 — Polish + App Store submission
- App icons, launch screen, marketing screenshots (6.7", 6.5", 5.5", iPad), privacy nutrition label, App Privacy Report, TestFlight, submission.

Suggested order: 4.1 → 4.7 (4.1 first because App Store gates on it, 4.7 last because it consumes everything else).

---

## Credit-management strategy

- **Approve one step at a time.** Each step above is scoped to land in one plan→approve→build cycle.
- **Step 3.1 first, always.** It's the cheapest step and every later step reuses its components, so later steps shrink.
- **Skip-ahead is fine.** Steps within a tier are mostly independent — e.g. 3.6 (billing) can ship before 3.7 (AI intake) if revenue is the priority.
- **Tier 4 is optional.** Tier 3 alone gives a fully usable, write-capable app. Tier 4 is platform polish.
- **Connector bumps batched.** Any new connector capability (e.g. typed RPC for billing) is bundled into the step that needs it, no standalone connector-only steps.

## Technical notes

- New shared component layer lives in `ios-native/Shared/UI/` and `ios-native/Shared/Brand/` (extends existing `AINBrand.swift`).
- All edit sheets follow the same shape: `@StateObject` view-model, optimistic local update, Outbox enqueue, `AuditLogger.log(...)`, dismiss on success or surface `AINToast` on failure.
- Realtime channels created in `RealtimeSubscriptions.swift` are reused — no per-screen channel proliferation.
- StoreKit 2 requires iOS 15+; we are on iOS 16 so that's fine. Apple Sign In requires `com.apple.developer.applesignin` entitlement.
- Widgets / Live Activities / Watch each require a new Xcode target; pbxproj will be edited via the same vendoring approach used for `InspectFlowConnector`.

## Out of scope (defer past Tier 4)

- Android native parity.
- Offline ML on-device inference.
- Multi-language localization beyond en-US.
