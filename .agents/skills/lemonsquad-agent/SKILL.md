---
name: lemonsquad-agent
description: Pull new Lemon Squad inspection requests into jobs and pre-fill draft reports. Server-side headless via Browserless for login/scrape/draft-fill, on-device iOS WebView for MFA/CAPTCHA and photo uploads. Use when the user mentions lemonsquad.com, Lemon Squad requests, or wiring the Lemon Squad integration.
---

# Lemon Squad AI Agent

Automates the Lemon Squad (lemonsquad.com) inspection workflow end-to-end while keeping the human in the loop for report submission.

## Scope

**In:** Pull new inspection requests into `inspection_requests` + create scheduled jobs. Log into lemonsquad.com, scrape open work, download request PDFs. Fill the draft inspection report (photos, captions, annotations) so a human clicks Submit on their site.

**Out (concept-only, kept as UI stubs):** Auto-submit on completion, review-and-confirm-submit. Do not wire submission logic — the current submission mode is `draft_only`.

**Out (entirely):** Other third-party inspection sites (the schema allows them; only lemonsquad.com is implemented).

## Triggers

- **Inbound email** via `intake-ingest-gmail` / `intake-ingest-outlook`: if the sender/subject matches Lemon Squad, hand off to `lemonsquad-agent` instead of the generic parser.
- **SMS / Telegram** via `intake-telegram-webhook`: same handoff on trigger phrase (`"lemon squad"`).
- **Manual button** ("Sync Lemon Squad") on the Inspector dashboard and iOS `InspectorDashboard`.
- No timed poll.

## Execution model

- **Server-side** (Supabase Edge Function `lemonsquad-agent` + Browserless/Browserbase hosted Chromium): routine path — login with stored creds → scrape open requests → create job/schedule → download request PDFs → pre-fill the draft form using the cached field map.
- **On-device iOS** (`WKWebView` in a presented sheet): anything requiring a human — MFA/CAPTCHA challenges, and the photo/caption/annotation upload step against the actual logged-in browser session. Mirroring real user actions is far more robust than screen-scraping the multipart API.
- Session cookies captured on device sync back to the server via `lemonsquad_sessions` so the next server run reuses them until they expire.

## Credentials

- `external_site_credentials` table: `user_id`, `site='lemonsquad'`, `username`, `password_ciphertext`, `cookies_jsonb`, `expires_at`, `submission_mode`. RLS scoped to `user_id`; GRANTs on `authenticated` + `service_role`.
- Password stored obfuscated (base64) today; upgrade to Supabase Vault (`pgsodium`) before production.
- Settings → Integrations → "Connect Lemon Squad" form saves/updates.
- No public OAuth on Lemon Squad; password login is the initial path with an OAuth hook left in place.

## AI field mapping

- First submission per Lemon Squad form version: server sends form field labels + our inspection JSON to Lovable AI Gateway (`google/gemini-3-flash-preview`) with a structured `Output` schema; result cached in `lemonsquad_field_maps(form_hash, mapping_json)`.
- Subsequent runs read the cache; on schema/hash change, re-infer.
- Current seed: `form_hash='v7-2026-07'` from user-supplied screenshots covering Dashboard, Job Header, Uploads (Images/Video), Vehicle Info, Fluids (15 types), Condition, Warranty, Engine, Road Test, Findings, and Edit Images.

## Report submission

- Implement now: **draft-only**. Agent fills the form and stops; human submits on lemonsquad.com.
- Stubs (concept only, do not wire): `submission_mode` enum with `draft` | `review_confirm` | `auto_on_complete`; UI shows the other two disabled with "Coming soon".

## MFA / CAPTCHA

If the server hits MFA/CAPTCHA/"verify it's you":
1. Persist challenge URL + partial session on `lemonsquad_sessions.pending_challenge_url`.
2. Send an APNs push to the assigned user ("Lemon Squad needs verification").
3. Push deep-links into `LemonSquadChallengeView` (iOS `WKWebView`) that loads the challenge URL with restored cookies.
4. On success, the WebView exports fresh cookies back to `lemonsquad_sessions`.
5. Server resumes the queued run via `action: "resume_after_mfa"`.

## Routing new requests into the schedule

New request → insert into `inspection_requests` with `source='lemonsquad'`, `external_id`, `external_url` → run existing intelligent-dispatch to create a scheduled job / trip stop. Request PDFs go to the `intake-files` bucket.

## Files (already in the project)

- `supabase/functions/lemonsquad-agent/index.ts` — orchestrator skeleton (validates auth, loads creds/session/field map, returns `awaiting_browserless_token` until `BROWSERLESS_TOKEN` is set).
- `supabase/migrations/*_lemonsquad_seed_form_map.sql` — seeded field map v7-2026-07 (~65 fields).
- `src/pages/settings/LemonSquadIntegration.tsx` — connect form + Sync-now button.
- Tables: `external_site_credentials`, `lemonsquad_sessions`, `lemonsquad_field_maps` (RLS scoped to `user_id` / `has_role('admin')`).

## Files to add when wiring the real browser path

- `supabase/functions/_shared/lemonsquadClient.ts` — Playwright-over-Browserless helpers.
- `supabase/functions/_shared/lemonsquadMapper.ts` — AI field-mapping via Lovable AI Gateway.
- `src/components/lemonsquad/SyncButton.tsx` — dashboard trigger.
- `ios-native/Features/Integrations/LemonSquadChallengeView.swift` — WKWebView MFA/upload host.
- `ios-native/Features/Integrations/LemonSquadSyncButton.swift` — dashboard trigger + push handler.

## Secrets required (request via `add_secret` when wiring)

- `BROWSERLESS_TOKEN` — hosted headless Chromium.
- `LEMONSQUAD_APP_APNS_TOPIC` — reuse existing APNs channel if configured.
- `LOVABLE_API_KEY` — already present.

## Actions accepted by `lemonsquad-agent` function

- `sync_requests` — pull new open requests into `inspection_requests`.
- `start_draft` — begin a draft report for a completed inspection (pre-fill only, never submit).
- `resume_after_mfa` — resume a paused run after the iOS WebView solved MFA.

## Not in scope

- Real Supabase auth changes or bypass flag changes.
- Other third-party sites.
- Auto-submit / review-confirm-submit wiring.

## Open follow-ups (do not block progress)

- Confirm APNs is wired for the iOS app (needed for MFA push).
- Provide one real Lemon Squad request email so end-to-end mapping can be validated.
