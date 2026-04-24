

# Inspector Workspace: Gap Assessment vs. Mobile-First / CarPlay-Ready Build

## Honest scorecard (where you stand today)

| Area | Status | Notes |
|---|---|---|
| Mobile-first shell | **Strong** | Bottom tab bar, PWA manifest, service worker, sticky active-trip banner, install prompt |
| Trip lifecycle | **Strong** | Idempotent transitions, realtime active trip, next-stop card, progress |
| Jobs ↔ Trips loop | **Strong** | Auto-link, in-trip badges, one-tap arrive/start/complete |
| Scheduling | **Partial** | Internal scheduler only — list + reschedule. No device calendar sync, no day/week view, no recurring/blocked-time logic on the schedule page |
| Tax estimator | **Partial** | Federal/state/SE rates + filing status + state code stored, but state rates are manually entered. No real state tax tables, no quarterly estimates, no 1099 export |
| In-app navigation | **Weak** | Only handoff to Apple/Google Maps via `OpenInMapsButton`. Map overlay is read-only Leaflet — no turn-by-turn, no route order optimization, no in-app driving mode |
| CarPlay / Android Auto | **Not started** | Web stack only. Requires Capacitor + native CarPlay/AA scenes (templated UI, not React) |
| Platform abstraction | **Started** | `src/platform/` exists for maps/export/share/location — good foundation for Capacitor |

---

## What I'd add (phased, no redesign)

### Phase 7A — Scheduling: device calendar sync + week view

**Goal:** make the Schedule page a real calendar that flows into trips and out to the phone.

1. **Week / day calendar view** on `InspectorSchedule.tsx`
   - Add a `view` toggle: List (current) · Day · Week
   - Day = vertical time-block list with drag-to-reschedule
   - Week = 7-column grid; tap a slot to create a job pre-filled with date/time
2. **Device calendar sync** via standards (works in PWA today, native later)
   - **Per-job .ics download**: button on each job → generates `BEGIN:VEVENT` with title (job title), location (job.location), start (`scheduled_at`), duration (`estimated_duration_minutes`), notes, and a stable UID = `job-{id}@inspector.app`. iOS/Android open it in the system calendar.
   - **Trip .ics export**: full day as a single `.ics` with one VEVENT per stop.
   - **Subscribed feed (read-only mirror)**: edge function `calendar-feed/:userToken.ics` returns all upcoming jobs as a live calendar URL the user adds once to Apple/Google Calendar. Token stored on profile; revocable.
   - All routed through `src/platform/calendar.ts` (new module) so Capacitor can later swap in `@capacitor-community/calendar` for true two-way sync.
3. **Recurring + blocked time** surfaced on the schedule
   - Use existing `availability_schedules` and `inspector_blocked_dates` tables (already in schema, unused on this page) to gray out unavailable slots and warn on conflicts.

**Schema:** add `profiles.calendar_feed_token text` (nullable, unique).

---

### Phase 7B — Tax estimator: real US state tables + quarterly + 1099

**Goal:** turn the current flat-rate estimator into something an inspector can trust at quarterly-payment time.

1. **State tax data**
   - Add `src/data/stateTaxTables.ts` — JSON of 2025 brackets for all 50 states + DC (flat-rate states marked, no-income-tax states zeroed). Sourced from state revenue dept tables.
   - Replace the manual `state_tax_rate` slider with **auto-computed effective rate** based on: state_code + filing_status + projected annual gross. Manual override remains.
2. **Federal brackets + standard deduction**
   - Add `src/data/federalTaxTables.ts` (2025 brackets, standard deduction by filing status).
   - Compute effective federal rate the same way (project YTD → annual, apply brackets, derive effective %).
3. **SE tax** — keep 15.3% on 92.35% of net SE income (the standard formula), already close.
4. **Quarterly estimated payment card** on `InspectorTax.tsx`
   - Show next quarter due date (Apr 15, Jun 15, Sep 15, Jan 15).
   - "Set aside this quarter: $X" — based on YTD earnings extrapolated with the new tables.
   - "Save for taxes" running balance suggestion.
5. **1099-ready export** — CSV per organization, per year, with totals per client/customer (uses existing `customer_name` on jobs).

**Schema:** no new tables. Optional: `earnings_settings.quarterly_safe_harbor_method text` ('110_percent_prior_year' | 'current_year_90').

---

### Phase 7C — In-app navigation (driving mode, no CarPlay yet)

**Goal:** an in-app "driving mode" that doesn't require leaving the app for the next stop. Real turn-by-turn requires native + paid SDKs, so this stays handoff-augmented.

1. **Driving Mode screen** at `/app/inspector/drive`
   - Full-screen, large-tap, glanceable: next stop name, ETA, distance remaining, big buttons (Arrived · Start Job · Skip).
   - Auto-launches when a trip is `active` and user is on mobile (opt-in toggle).
   - Wake-lock via `navigator.wakeLock` (Screen Wake Lock API) to keep screen on.
   - Voice cue on arrival (Web Speech `speechSynthesis`): "Arriving at next stop."
2. **Live route preview** in `TripMapOverlay`
   - Add OSRM (free) or OpenRouteService (free tier) route polyline between stops — replaces the straight-line polyline. Cached per trip.
   - Re-order suggestion: "Optimize stop order" button → calls OSRM `/trip` endpoint, previews new order, user accepts.
3. **Geolocation + auto-arrive**
   - Watch position via `src/platform/location.ts`; when within ~150m of next stop's lat/lng, prompt "Arrived?" — one-tap confirms (doesn't auto-fire to avoid false positives).
4. **Platform module updates**
   - `platform/location.ts`: implement web `geolocation.watchPosition`; native swap point ready for Capacitor `@capacitor/geolocation`.
   - `platform/navigation.ts` (new): wraps OSRM calls behind a stable interface.

**Schema:** no changes. Optional cache table `route_cache(trip_id, geometry, computed_at)` for offline access.

---

### Phase 7D — Capacitor + CarPlay / Android Auto (the real native step)

**Important reality:** CarPlay and Android Auto **do not run React/web UIs**. Apple and Google require apps to use their native templated UIs (CPListTemplate, CPMapTemplate / CarAppService templates). The Lovable web app cannot ship to a car directly. The path is:

1. **Wrap with Capacitor** (already documented in the project — `appId: app.lovable.c4a81c228a3d4381bec7340e222a48cb`).
2. **Native plugin (custom)** in `ios/App/App/CarPlay/` and `android/app/src/main/java/.../car/` exposing a minimal CarPlay/AA surface backed by data the web app already produces:
   - **List template:** today's stops (label, address, ETA).
   - **Map template:** current trip route polyline + next stop pin.
   - **Action buttons:** Arrived · Skip · Call customer.
3. **Data bridge:** the native layer reads from the same Supabase tables (`trips`, `trip_stops`, `jobs`) using a stored session token, so the phone screen and the car screen are always in sync. State changes from CarPlay (e.g. "Arrived") write back to Supabase → web/PWA reflects them via realtime.
4. **Voice & navigation:** CarPlay/AA route the user to Apple Maps / Google Maps via system intents — same handoff your `platformMaps.open()` does, just from native templates.
5. **What stays in Lovable:** all data, scheduling, tax, settings. CarPlay/AA is a thin native projection of the active trip.

**Out of scope for Lovable's web sandbox:** the actual Xcode/Android Studio CarPlay project, Apple's CarPlay entitlement (requires Apple approval), and Google Cars App Library testing. Lovable will produce the Capacitor scaffolding and the JSON contract the native layer consumes; the native projects are built by you locally after `npx cap add ios/android`.

---

## Recommended order

1. **7A Scheduling + calendar sync** — biggest day-to-day win, pure web, ships fast.
2. **7B Tax tables + quarterly** — high trust value, pure data work.
3. **7C Driving mode + wake-lock + auto-arrive** — makes the PWA feel in-car-ready.
4. **7D Capacitor + CarPlay/AA scaffolding** — only after 7A–C land, since CarPlay surfaces *project* the data those phases produce.

---

## Technical notes

- **No redesign**, no new product areas. Reuses `DashboardLayout`, `Card`, `Tabs`, `Sheet`, bottom tab bar, `useActiveTrip`, `tripLifecycle.ts`, `OpenInMapsButton`, `TripMapOverlay`, `src/platform/*`.
- **New files**: `src/platform/calendar.ts`, `src/platform/navigation.ts`, `src/data/stateTaxTables.ts`, `src/data/federalTaxTables.ts`, `src/pages/inspector/InspectorDrive.tsx`, `supabase/functions/calendar-feed/index.ts`, `supabase/functions/ics-export/index.ts`.
- **Schema**: only `profiles.calendar_feed_token` is required. Everything else fits the current model.
- **Capacitor readiness**: every new capability lands in `src/platform/` first so Phase 7D replaces implementations without touching UI.

## Confirm before I build

Tell me which phase to start with (7A is my recommendation), or approve the whole sequence and I'll implement 7A first.

