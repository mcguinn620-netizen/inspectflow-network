## Part A — Save the current iOS auth bypass plan

Copy the executed iOS Auth Bypass work into `.lovable/ios-auth-bypass.md` (mirrors the format of `.lovable/auth-bypass-web.md`) so both platforms have a written record we can flip off later. No code moves.

Sections:
- Toggle (`AUTH_BYPASS` in `Info.plist`, default `YES`)
- `AuthBypass.swift` and `MockUsers.swift` (same 10 users as web)
- `DebugUserService` / `AppState` / `RootView` / `DebugUserPickerView` changes
- What stays intact for re-enabling (`AuthView`, `AuthViewModel`, `SupabaseService`, Supabase RLS)

---

## Part B — New plan: "Lemon Squad" AI Agent

Goal: an AI agent that (1) pulls new inspection requests from **lemonsquad.com** into our schedule and (2) fills a **draft** inspection report on their site (photos, captions, annotations) that a human submits. Auto-submit and review-confirm-submit stay as concept-only stubs.

### Triggers
- **Inbound email** into existing `intake-ingest-gmail` / `intake-ingest-outlook` — if sender/subject matches Lemon Squad, hand off to the new agent instead of the generic parser.
- **SMS / Telegram** via existing `intake-telegram-webhook` — same handoff on trigger phrase (`"lemon squad"`).
- **Manual button** "Sync Lemon Squad" on Inspector dashboard + iOS `InspectorDashboard`.
- (No timed poll — user did not select it.)

### Execution model
- **Server-side** (Supabase Edge Function + Browserless/Browserbase hosted Chromium) for the routine path: login with stored creds → scrape open requests → create job/schedule → download request PDFs.
- **On-device** (iOS `WKWebView` in a hidden or presented sheet) for anything that needs a human: MFA/CAPTCHA challenges, and the "upload photos + captions + annotations" step against the actual logged-in browser session, which mirrors user actions and is far more robust than screenscraping the multipart upload API.
- Session cookies captured on device sync back to the server via a new `lemonsquad_sessions` table so the next server run reuses them until they expire.

### Credentials
- Per-user encrypted credentials in a new `external_site_credentials` table (`user_id`, `site='lemonsquad'`, `username`, `password_ciphertext`, `cookies_jsonb`, `expires_at`). Encryption via Supabase Vault (`pgsodium`) — never returned to the client in plaintext.
- Settings → Integrations → "Connect Lemon Squad" form to save/update.
- OAuth-first is aspirational; Lemon Squad has no public OAuth, so password login is the initial path with the hook left in place.

### AI field mapping (first-run + cached)
- First submission per Lemon Squad form version: server sends form field labels + our inspection JSON to Lovable AI Gateway (`google/gemini-3-flash-preview`) with a structured `Output` schema; result cached in `lemonsquad_field_maps(form_hash, mapping_json)`.
- Subsequent runs read the cache; on schema/hash change, re-infer.

### Report submission mode (per user answer)
- **Implement now:** Draft-only. Agent fills the form and stops; human submits on lemonsquad.com.
- **Stubs for later (concept only, do not wire):** `submissionMode` enum in `external_site_credentials` with values `draft` | `review_confirm` | `auto_on_complete`; UI shows the other two as disabled with "Coming soon".

### MFA handling
- If server hits MFA/CAPTCHA/"verify it's you", it stores the challenge URL + partial session on `lemonsquad_sessions.pending_challenge`, sends the assigned user an APNs push ("Lemon Squad needs verification"), deep-linking into a new `LemonSquadChallengeView` (iOS `WKWebView`) that loads the challenge URL with restored cookies. On success, the WebView exports fresh cookies back to `lemonsquad_sessions`, and the server resumes the queued run.

### Data & routing into the schedule
- New request → insert into `inspection_requests` (existing intake path) with `source='lemonsquad'`, `external_id`, `external_url`, then run existing intelligent-dispatch to create a scheduled job/trip stop. Attachments (request PDF) go to `intake-files` bucket.

### Files to add
- `supabase/functions/lemonsquad-agent/index.ts` — orchestrator (Browserless driver, login, list, download, draft-fill).
- `supabase/functions/_shared/lemonsquadClient.ts` — Playwright-over-Browserless helpers.
- `supabase/functions/_shared/lemonsquadMapper.ts` — AI field-mapping (Lovable AI Gateway).
- `supabase/migrations/*` — `external_site_credentials`, `lemonsquad_sessions`, `lemonsquad_field_maps` (RLS scoped to `user_id` / `has_role('admin')`, GRANTs to `authenticated` + `service_role`, vault-encrypted password column).
- `src/pages/settings/LemonSquadIntegration.tsx` — connect form + status + "Sync now".
- `src/components/lemonsquad/SyncButton.tsx` — dashboard trigger.
- `ios-native/Features/Integrations/LemonSquadChallengeView.swift` — `WKWebView` MFA/upload host with cookie import/export.
- `ios-native/Features/Integrations/LemonSquadSyncButton.swift` — dashboard trigger + push notification handler.

### Secrets required (request via `add_secret` when we build)
- `BROWSERLESS_TOKEN` (hosted headless Chromium)
- `LEMONSQUAD_APP_APNS_TOPIC` (push channel — reuse existing if configured)
- `LOVABLE_API_KEY` already present.

### Out of scope (this plan)
- Auto-submit and review-confirm-submit flows (kept as UI stubs only).
- Other third-party sites (design allows adding them under the same tables, but only lemonsquad.com is implemented).
- Any change to real Supabase auth or the bypass flags.

### Open follow-ups (do not block approval)
- Provide one real Lemon Squad request email + one screenshot of their inspection form so first-run mapping can be validated.
- Confirm APNs is already wired for the iOS app (needed for MFA push).
