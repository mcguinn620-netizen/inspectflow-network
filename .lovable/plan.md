## Scope

Five tracks, all iOS-app + Lovable-Cloud focused. No web-app UI changes unless noted. Skills used: `ios-debugging`, `swiftui`, `swift-concurrency`, `supabase`, `bug-hunt-swarm` (diagnosis of JWT issue), `inspection-app-architecture`.

---

## 1. Fix "JWT expired" on Schedule / Inspections / Vehicles / Drive

**Diagnosis (bug-hunt-swarm):** All four screenshots show `HTTP 401 {code: PGRST303, message: JWT expired}` bleeding into the UI. The connector already has refresh-on-401 retry (`QueryBuilder.raw()` → `shouldRetryAfterRefreshing`), but it's failing because:

- a. `validAccessToken()` only refreshes when `expiresAt - now < 60s`. If the device clock or the stored `expiresAt` is stale (we resumed from background after >1h), the cached token is sent, server returns 401, retry fires once — but if the **refresh token itself** rotated on a prior call and wasn't persisted on the failing path, retry also 401s and the raw body is shown to the user.
- b. `JobsViewModel`/`InspectionsViewModel`/`VehiclesViewModel`/`InspectorDrive` surface `error.localizedDescription` verbatim (the full HTTP body) as the empty-state subtitle.
- c. App start does not call `restoreAndValidateSession()` before the first tab loads, so the first request always races with an expired token.

**Fixes (Swift / connector):**

1. `AuthClient.validAccessToken()` — widen skew window to 120s and, on `refresh()` failure with `invalid_grant`/`refresh_token_not_found`, clear session and throw `.notAuthenticated` (so UI can route to Auth instead of showing a 401 body).
2. `AuthClient.refresh()` — serialize concurrent refreshes through an actor/`Task` cache so parallel tab loads don't burn the single-use refresh token.
3. `QueryBuilder.raw()` (and matching `StorageClient` / `FunctionsClient` paths) — on the *retry* 401, throw `.notAuthenticated` instead of `.http`, so callers can react.
4. `RootView` / `AppDelegate` — `await SupabaseService.shared.restoreAndValidateSession()` before showing `MainTabView`; on `.notAuthenticated`, sign out and present `AuthView`.
5. View models (`JobsViewModel`, `InspectionsViewModel`, `VehiclesViewModel`, `TripsViewModel`, `InspectorDrive` banner) — map `InspectFlowError.http` / `.notAuthenticated` to friendly messages ("Session expired — please sign in again" with a sign-in button), never raw JSON.

---

## 2. Schedule screen shows nothing + two-way sync

**Current state:** `ScheduleView` reuses `JobsViewModel.load()` which queries `jobs` filtered by `organization_id` with `scheduled_at` ordering. Empty result + the 401 above = "No jobs this week". Fix in §1 unblocks read. Then:

**Read side:**

- `JobsViewModel.loadForWeek(start, end, orgId)` adds `.gte("scheduled_at", start).lt("scheduled_at", end+7d)` so the week grid actually scopes correctly (today many jobs are filtered out client-side after limit=50).
- `ScheduleView` calls `loadForWeek` whenever `selectedWeekStart` changes (currently it only calls `load` in `.task`).

**Two-way sync:**

- **Server → device:** subscribe to `jobs` via `RealtimeClient` filtered by `organization_id`; on INSERT/UPDATE/DELETE, patch `viewModel.jobs` and call `CalendarSyncService.shared.sync(job:)`.
- **Device → server:** `CalendarSyncService` already writes EventKit when we mutate jobs. Add the reverse path: a new `CalendarSyncService.observeChanges()` using `EKEventStoreChangedNotification`. When a synced event's `startDate`/`title`/`notes` change, look up the linked `job_id` (stored in `event.notes` as a marker), call `SupabaseService.updateJobSchedule` / `updateJobStatus`. Conflict policy: last-write-wins with a 5-second debounce; the realtime echo is filtered by an in-flight set to avoid loops.
- Add `Job.updatedAt` to the model and use it as the tie-breaker.

---

## 3. Add `/intake` to the iOS app with PDF email parsing

**iOS:**

- New tab/section in `MainTabView` "More" menu → `IntakeInboxView` (already created in Step 3.7). Promote to a top-level entry behind a feature flag for inspector / `dispatcher`/`company_owner` roles.
- Add `IntakeReviewView` actions: Approve → call `SupabaseService.convertIntakeItem`; Dismiss → PATCH status; Re-parse → call `intake-parse` again.
- **PDF intake from device:** add a "+" button → `UIDocumentPickerViewController` (PDF) and Mail share-extension target (out of scope this round — open ticket). For now the picker uploads the PDF to the existing `intake-files` storage bucket and POSTs `{ storage_path, channel: 'manual_pdf' }` to a new edge function `intake-parse-pdf`.
- Sort + filter controls in `IntakeInboxView` (see §4).

**Edge function `intake-parse-pdf` (new):**

- Input: `{ storage_path, organization_id }`.
- Download PDF from `intake-files` bucket using service role.
- Extract text via `unpdf` (`npm:unpdf`) — pure-JS, works in Deno.
- Sanitize NULs (reuse sanitize() helper from `intake-fetch-url`).
- Insert `intake_items` row with `channel='manual_pdf'`, then invoke `intake-parse` for LLM extraction + auto-create.

**Email PDF attachments:**

- Extend `intake-ingest-gmail` and `intake-ingest-outlook`: when a message has a PDF attachment, download via the respective gateway, store in `intake-files`, then call `intake-parse-pdf` instead of `intake-parse` (or merge body text + PDF text before LLM call).

---

## 4. Sort function on every list-view screen

**Add a reusable `AINSortMenu<Key: ListSortable>` SwiftUI component** in `Shared/UI/`:

- Renders as a toolbar `Menu` with `Picker` for sort key + asc/desc toggle.
- Persists per-screen choice in `@AppStorage("sort.<screen>")`.

**Wire into:**


| Screen                             | Sort keys                                              |
| ---------------------------------- | ------------------------------------------------------ |
| `JobsView`                         | scheduled_at, title, status, customer_name, updated_at |
| `InspectionsView`                  | created_at, status, vehicle vin, completion            |
| `VehiclesView`                     | created_at, year, make, model, vin                     |
| `TripsView`                        | started_at, status, distance                           |
| `IntakeInboxView`                  | created_at, status, confidence, channel                |
| `ScheduleView` (week column lists) | scheduled_at, priority                                 |
| `DispatcherAssignSheet` inspectors | name, role, active_jobs                                |


Sorting is applied client-side after fetch (lists are bounded by `limit`), with the chosen `order` also passed to the Supabase query when the key is server-indexed.

---

## 5. Wire cron + Telegram webhook for Gmail / Outlook / Telegram

**Connectors:** all three already linked — verify with `standard_connectors--list_connections` before running.

**Cron (pg_cron + pg_net) via `supabase--insert**` (not `migration`, per knowledge — contains anon key):

```sql
select cron.schedule('intake-ingest-gmail-5m','*/5 * * * *', $$
  select net.http_post(
    url:='https://aqtcgybbqdyjasgnuwlh.supabase.co/functions/v1/intake-ingest-gmail',
    headers:='{"Content-Type":"application/json","apikey":"<ANON>"}'::jsonb,
    body:='{}'::jsonb);
$$);
-- same for intake-ingest-outlook
```

Enable `pg_cron` + `pg_net` extensions first if not already on.

**Telegram webhook:**

1. Verify `telegram-webhook` function is deployed and has `verify_jwt = false`.
2. Function already SHA-256-derives a secret from `TELEGRAM_API_KEY`; reuse it.
3. From the sandbox, call:
  ```
   POST https://connector-gateway.lovable.dev/telegram/setWebhook
     Authorization: Bearer $LOVABLE_API_KEY
     X-Connection-Api-Key: $TELEGRAM_API_KEY
     body: { url: "https://<ref>.supabase.co/functions/v1/intake-telegram-webhook",
             secret_token: <sha256-base64url>,
             allowed_updates: ["message","edited_message","channel_post"] }
  ```
4. Verify with `getWebhookInfo`.
5. Ensure `INTAKE_DEFAULT_ORG_ID` secret is set (already required by `intake-parse`); if missing, prompt user before scheduling.

---

## Files I'll touch (in build mode)

```text
ios-native/Core/InspectFlowConnector/Auth/AuthClient.swift          (§1)
ios-native/Core/InspectFlowConnector/Database/QueryBuilder.swift    (§1)
ios-native/Core/InspectFlowConnector/Realtime/RealtimeClient.swift  (§2)
ios-native/App/RootView.swift                                       (§1)
ios-native/Features/Jobs/JobsViewModel.swift                        (§1,§2,§4)
ios-native/Features/Schedule/ScheduleView.swift                     (§2,§4)
ios-native/Features/Inspections/InspectionsViewModel.swift          (§1,§4)
ios-native/Features/Vehicles/* / Trips/* / Drive/*                  (§1,§4)
ios-native/Features/Intake/IntakeInboxView.swift + ReviewView       (§3,§4)
ios-native/Shared/UI/AINSortMenu.swift                              (§4 new)
ios-native/Core/Services/CalendarSyncService.swift                  (§2)
ios-native/Core/Network/SupabaseService.swift                       (§2,§3)
ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj           (register new files)

supabase/functions/intake-parse-pdf/index.ts                        (§3 new)
supabase/functions/intake-ingest-gmail/index.ts                     (§3 attachments)
supabase/functions/intake-ingest-outlook/index.ts                   (§3 attachments)
supabase/config.toml                                                (register new function)
```

No DB migrations required (intake tables exist). Cron rows added via `supabase--insert`. Edge functions deployed via `supabase--deploy_edge_functions`.

## Verification checklist

- Schedule, Inspections, Vehicles, Drive load real data on a stale session without 401 text.
- Drag-rescheduling a job in `ScheduleView` updates EventKit + Supabase; editing the event in iOS Calendar pushes back to Supabase within 5s.
- Realtime INSERT into `jobs` from web appears on iOS without pull-to-refresh.
- Each list screen has a working Sort menu, choice persisted.
- Telegram message → bot triggers `intake-telegram-webhook` → row appears in iOS Intake Inbox; auto-creates request when VIN valid + confidence ≥ 0.85.
- Gmail/Outlook inbox is polled every 5 min; PDF attachment in a forwarded email shows up in inbox with parsed VIN.
- Manual PDF picker in iOS Intake → row created via `intake-parse-pdf`.

Approve and I'll execute in this order: §1 (unblocks everything) → §2 → §4 (cheap and parallel) → §3 → §5.