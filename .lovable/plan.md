
# Plan: Phase 7C Drive Mode + Schedule Conflict Surfacing

Two scoped deliverables, both ship inside the existing PWA (no native code required).

---

## 1. Phase 7C Finish — Full-screen Drive Mode

### New route
`/app/inspector/drive` — a dedicated, distraction-free driving screen for the active trip. Wired into `App.tsx` under `ProtectedRoute`.

### New file: `src/pages/inspector/InspectorDrive.tsx`
Full-viewport (`h-[100dvh]`) layout consuming `useActiveTrip()`:
- **Top bar (compact):** trip title, exit button (← back to `/app/inspector/trips`), progress chip (`completed / total`).
- **Map (fills remaining space):** reuses `TripMapOverlay` in a new `fullscreen` mode (added prop) that:
  - Drops the Card chrome and forces 100% height.
  - Auto-starts `navigating = true` on mount (GPS following + recenter).
  - Hides the "Navigate" button (always on); shows only Recenter and Exit.
- **Bottom sheet (NextStopCard variant):**
  - Big stop label + address.
  - Distance-to-next (haversine from current GPS to next stop coords) and ETA placeholder (km / avg 50 km/h).
  - Primary action: **Arrive** (marks stop completed via existing trip lifecycle helper, advances to next).
  - Secondary: **Skip**, **Open in Maps** (existing `OpenInMapsButton`).

### Wake Lock
New file `src/hooks/useWakeLock.ts`:
- Calls `navigator.wakeLock?.request('screen')` on mount, releases on unmount.
- Re-acquires on `visibilitychange` when page becomes visible (browsers drop the lock on hide).
- Silent no-op when API is unavailable (Safari < 16.4, etc.).

### Auto-arrive geofencing
Inside Drive page:
- Subscribe to `startTracking` from `@/platform/location`.
- On each position, compute haversine distance to `nextStop` (using lat/lon already in `ActiveStop`).
- When distance < **75 m** for 2 consecutive readings, fire a toast `"Arrived at <stop>"` and prompt: **Mark arrived?** (Sonner action button → calls existing trip-stop completion path).
- Debounce so we don't re-prompt the same stop.

### Voice cues (lightweight, web SpeechSynthesis)
- New util `src/lib/voiceCue.ts` wrapping `window.speechSynthesis.speak(new SpeechSynthesisUtterance(text))`.
- Toggle button in top bar (🔊 / 🔇), persisted to `localStorage` key `drive:voice`.
- Cues fired:
  - On stop advance: "Next stop, <label>".
  - On geofence arrival: "Arriving at <label>".
- Silent fallback when API missing.

### Entry point
- Add a **Drive** button in `src/components/inspector/ActiveTripBanner.tsx` (when active trip exists) linking to `/app/inspector/drive`.
- Add the same button on `InspectorTrips` next to the existing map overlay.

### TripMapOverlay change
Add `fullscreen?: boolean` prop. When true:
- Returns the inner `<div>` (no Card wrapper), height `h-full`.
- Sets `navigating` initial state to `true` and hides the Navigate button.
- All other behavior (OSRM polyline, GPS marker, recenter button) unchanged.

---

## 2. Schedule Conflict Surface in `ScheduleWeekGrid`

Surface availability/blocked-date conflicts already loaded in `InspectorSchedule.load()` but never rendered as warnings.

### New prop on `ScheduleWeekGrid`
`onConflict?: (job, reason) => void` (optional analytics hook). Conflict detection runs internally per cell.

### Conflict rules per day cell
For each job in `dayJobs`:
1. **Blocked-date conflict** — day is in `blockedDates`.
2. **Outside availability window** — day-of-week has availability rows but job's time falls outside any `start_time → end_time` interval, OR `is_available === false` for that DOW.
3. **Overlap** — two jobs whose `[scheduled_at, scheduled_at + estimated_duration_minutes)` intervals intersect (default 60 min when null).

### Visual treatment
- Conflict job buttons get a left border `border-l-2 border-destructive` and a small ⚠ icon (`AlertTriangle` from lucide).
- Day cell shows a count badge `Badge variant="destructive"` like `2 conflicts` in the header when count > 0.
- Tooltip (`title` attr) on the job button states the reason ("Outside hours", "Overlaps with X", "Day off").

### Pass-through from `InspectorSchedule`
Already provides `blockedDates` and `availability`. Need to extend `ScheduleJob` type to include `estimated_duration_minutes` for overlap math (already on the local `Job` interface in `InspectorSchedule`, so we add it to `ScheduleJob` and the SELECT already fetches it).

### List view bonus (small)
In the list-view rendering of `InspectorSchedule`, when a job is in conflict show the same ⚠ icon next to the title. Reuses the same conflict-detection helper, extracted to `src/lib/scheduleConflicts.ts`:
```ts
export function detectConflicts(jobs, availability, blockedDates): Map<jobId, Reason[]>
```

---

## Files to be created
- `src/pages/inspector/InspectorDrive.tsx`
- `src/hooks/useWakeLock.ts`
- `src/lib/voiceCue.ts`
- `src/lib/scheduleConflicts.ts`

## Files to be edited
- `src/App.tsx` — register `/app/inspector/drive` route.
- `src/components/maps/TripMapOverlay.tsx` — add `fullscreen` prop.
- `src/components/inspector/ScheduleWeekGrid.tsx` — render conflicts.
- `src/components/inspector/ActiveTripBanner.tsx` — Drive entry button.
- `src/pages/inspector/InspectorTrips.tsx` — Drive entry button.
- `src/pages/inspector/InspectorSchedule.tsx` — conflict icon in list view, extend `ScheduleJob` import usage.

## Out of scope (kept for follow-ups)
- Route stop-order auto-optimization (item #4).
- 1099 CSV export (item #3).
- CarPlay endpoint (item #5).
- Background-location tracking when app is backgrounded — requires native plugin.

After approval I'll implement, type-check, and report back.
