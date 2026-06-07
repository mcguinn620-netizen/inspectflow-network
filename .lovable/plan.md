
# Step 3.7 — AI Intake: Email, SMS, Web Links, Manual

Goal: turn inbound inspection requests from any channel into reviewed (or auto-created) `inspection_requests`, surfaced in a native iOS **Inbox** tab and the existing web Intake screen.

## Channels at launch
1. **Gmail connector** — workspace-shared intake mailbox (e.g. `intake@yourco`)
2. **Microsoft Outlook connector** — same model, workspace-shared
3. **Telegram bot** — text messages / forwarded images via webhook
4. **Web link paste** — user pastes auction/listing URL; edge fn fetches + parses
5. **Manual paste / file upload** — existing flow, ported to iOS
6. **Per-user Gmail OAuth** — follow-up after workspace flow ships (scaffolded, not wired)

## Data model

New `intake_items` table is the single inbox for every channel.

```text
intake_items
 ├─ id, organization_id, created_at, updated_at
 ├─ channel            ('gmail'|'outlook'|'telegram'|'web_link'|'manual')
 ├─ source_ref         (gmail msg id / outlook id / tg update_id / url / upload path)
 ├─ source_address     (from-email / tg chat handle / url host / uploader user_id)
 ├─ subject            (email subject, tg first-line, page title)
 ├─ raw_text           (cleaned body)
 ├─ raw_payload        jsonb (full provider payload for replay)
 ├─ attachments        jsonb[] (storage paths in intake-files bucket)
 ├─ parsed_data        jsonb (output of parse-inspection)
 ├─ confidence         numeric (0-1, derived from VIN validity + field coverage)
 ├─ status             ('new'|'parsing'|'needs_review'|'auto_created'|'converted'|'dismissed'|'error')
 ├─ inspection_request_id  uuid (set when converted)
 ├─ error              text
 └─ dedupe_hash        text  -- unique per org to prevent re-ingest
```

RLS: org members manage rows (`is_org_member(organization_id)`); service_role full access for edge fns. GRANTs for `authenticated` + `service_role`.

`parsed_documents` stays for legacy uploads; new code writes to `intake_items`.

## Edge functions

| Function | Trigger | Job |
|---|---|---|
| `intake-ingest-gmail` | pg_cron every 5 min | Poll Gmail via connector gateway, dedupe by msg id, insert `intake_items`, enqueue parse |
| `intake-ingest-outlook` | pg_cron every 5 min | Same for Outlook via `microsoft_outlook` gateway |
| `intake-telegram-webhook` | Telegram push (`verify_jwt=false`) | Verify secret-token, insert intake_item, download attachments to `intake-files`, enqueue parse |
| `intake-fetch-url` | invoked by client | Fetch URL server-side, strip HTML to text, insert intake_item, enqueue parse |
| `intake-parse` | DB trigger on insert / cron sweep | Calls existing `parse-inspection` with `text` + channel hint, writes `parsed_data` + `confidence`, sets status |
| `intake-auto-convert` | DB trigger on `status='needs_review'` | If `vin_valid && confidence >= 0.85`, create `inspection_request`, mark `auto_created`, audit-log |
| `parse-inspection` *(existing)* | called by `intake-parse` | Already handles email/PDF/image; extend prompt to add `web_link` + `sms` source types |

Throughput, dedupe, and retries follow the email-queue pattern (visibility timeout + DLQ on 5 failures).

## Connectors required
- `google_mail` (workspace) — scopes: `gmail.readonly`, `gmail.modify` (to mark messages processed)
- `microsoft_outlook` (workspace) — scopes: `Mail.Read`, `Mail.ReadWrite`
- `telegram` — bot for inbound text/photos; register webhook via gateway `setWebhook`
- No new secrets from user; gateway handles auth. Per-user Gmail OAuth deferred (own Google Cloud client + redirect).

## Web surface (minor)
- Existing `ImportInspectionDialog` keeps working but writes to `intake_items` (channel=`manual`) via shared helper.
- New `/intake` page: unified Inbox list (filter by channel/status), reuses `IntakeReviewScreen`.
- "Add URL" tab in the dialog → calls `intake-fetch-url`.

## iOS native surface (Step 3.7 deliverable)

Add an **Inbox** tab (visible to inspector/dispatcher/admin; hidden for client/mechanic):

```
ios-native/Features/Intake/
 ├─ IntakeInboxView.swift          -- list of intake_items, channel chip + StatusPill
 ├─ IntakeInboxViewModel.swift     -- realtime sub on intake_items, filters
 ├─ IntakeReviewView.swift         -- editable parsed fields, Confirm/Dismiss
 ├─ IntakeReviewViewModel.swift    -- writes back to intake_items, converts to inspection_request via Outbox
 ├─ IntakePasteSheet.swift         -- paste text / URL / pick file (PDF, image)
 └─ Components/
     ├─ IntakeChannelChip.swift
     └─ IntakeForwardingAddressCard.swift  -- shows org's intake@ address with copy
```

- Outbox + AuditLogger on every status change.
- Realtime via existing `RealtimeSubscriptions`.
- Reuses `AINCard`, `AINStatusPill`, `AINEmptyState`, `AINPrimaryButton` from 3.1.
- `MainTabView` gains a 5th tab "Inbox" with unread badge from `intake_items` where `status='needs_review'`.

## UX rules
- Auto-created items appear in Inbox with green "Auto-created" pill; tap reveals the source for audit.
- `needs_review` items show parsed fields with confidence < 0.85 highlighted in Amber.
- Dismiss is soft (status only); never deletes the raw payload (audit + replay).
- Forwarding address card explains: "Forward emails to `intake+<org-slug>@…` to ingest automatically."

## Out of scope (deferred)
- Per-user Gmail OAuth (scaffolded but not wired)
- SMS via Twilio (Telegram covers messaging at launch)
- AI confidence ML model — confidence uses deterministic VIN + field-coverage heuristic
- Bulk-convert / merge duplicates

## Build order
1. Migration: `intake_items` + GRANTs + RLS + indexes (`org_id,status`, `dedupe_hash unique per org`).
2. Edge fns: `intake-parse`, `intake-auto-convert`, `intake-fetch-url`.
3. Connector wiring: link Gmail, Outlook, Telegram; deploy `intake-ingest-gmail`, `intake-ingest-outlook`, `intake-telegram-webhook`; register Telegram webhook via gateway.
4. Web: extend `ImportInspectionDialog` to write `intake_items`; add `/intake` unified inbox.
5. iOS: build Intake feature folder + tab; reuse design system; realtime + Outbox.
6. Validator script `validate_step_3_7_intake.py` mirroring 3.4/3.5 style.

Each sub-step is independently shippable; Telegram and Outlook can ship after Gmail.
