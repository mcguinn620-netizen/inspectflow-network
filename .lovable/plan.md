
## 1. Fix "Review Parsed Inspection" showing raw PDF binary

`ImportInspectionDialog` reads the PDF with `file.text()`, dumping `%PDF-1.3 …` bytes into the left pane. We already have an `intake-parse-pdf` edge function that extracts real text via `unpdf`.

Changes to `src/components/intake/ImportInspectionDialog.tsx`:
- On PDF drop: upload to the existing `intake-files` bucket → call `intake-parse-pdf` with `{ storage_path, organization_id }`.
- Feed the returned `raw_text` into `parse-inspection` so the review screen shows readable text on the left and parsed fields on the right.
- Remove the `file.text()` fallback.
- Add `DialogDescription` / wrap title with `VisuallyHidden` where needed to clear the current a11y console warnings.

## 2. Add a URL / Link tab

New tab next to Email / PDF / Image with a URL input + Parse button that calls the existing `intake-fetch-url` edge function (already used by `IntakeInbox`), then routes text through `parse-inspection` into the same review screen. No new backend.

## 3. Image OCR

Images currently just toast "paste the text". Replace with:
- Upload the image to `intake-files`, sign a URL, and call `parse-inspection` with a multimodal Gemini message (`{type:"image_url", image_url:{url: signedUrl}}`).
- Small branch in `parse-inspection/index.ts`: when `source_type === "image"` and an `image_url` is passed, send it as a vision request instead of text-only.

## 4. Make Import + Jobs work for the inspector role

Two issues:

a. Inspector role has no entry point — the "Import Inspection" button lives only on `src/pages/Index.tsx`. Mount `<ImportInspectionDialog />` in the header of `src/pages/inspector/InspectorJobs.tsx` so `inspector` and `technician` mock users can import.

b. Import + new-job creation fails under mock auth. `MockAuthProvider` fakes a `User` but never establishes a Supabase session, so RLS (`is_org_member(auth.uid())`) rejects inserts into `inspection_requests` / `jobs`. Fix with a new edge function `intake-create-request` (service-role) that:
- accepts the parsed payload + mock `user_id` + `organization_id`;
- validates the org belongs to that user via `organization_users`;
- inserts into `inspection_requests` and creates the matching `jobs` row.

The client picks this path based on `AUTH_BYPASS`; real-auth users continue writing directly through RLS.

## 5. iOS mock-user audit + fix

Same root cause as web: `AuthBypass.isEnabled` skips Supabase, so every screen reading via `InspectFlowClient` gets nothing because there is no session token. Plan:

- Add `MockSession.swift` under `ios-native/Core/Auth/` that flips `InspectFlowClient` into a "mock read" mode (adds the mock user id + org id to a request header instead of a JWT).
- Add one edge function `mock-read` that accepts `{ user_id, org_id, resource: "jobs"|"trips"|"schedule", filters }`, verifies the pair against `organization_users`, and returns rows using the service role — only usable when the caller sends a known mock user id.
- On selection in `DebugUserPickerView`, warm this path so Jobs / Schedule aren't empty on first open.

If a screen is still empty after the shim, we'll seed richer per-role mock data in a follow-up (not in this plan).

## 6. Save the previous "Lemon Squad AI Agent" plan as a Lovable AI agent

Convert the existing `.lovable/plan.md` Part B ("Lemon Squad AI Agent") into a first-class Lovable AI agent so future runs pick it up automatically.

- Draft it under `.agents/skills/lemonsquad-agent/SKILL.md` with frontmatter:
  - `name: lemonsquad-agent`
  - `description: Pull new Lemon Squad inspection requests into jobs and pre-fill draft reports; server-side via Browserless, on-device iOS WebView for MFA/CAPTCHA/uploads.`
- Body captures: triggers (email / SMS / manual), execution model (server + iOS WebView), credential storage, AI first-run field mapping + cache, draft-only submission (review/auto as stubs), MFA push flow, files/tables already created, and open follow-ups.
- Call `skills--apply_draft .agents/skills/lemonsquad-agent` so it becomes active.

## 7. Housekeeping

Fix the `DialogContent` missing-`DialogTitle`/`Description` warnings in `ImportInspectionDialog` and `IntakeReviewScreen`.

## Technical section

Files to touch / add:
- `src/components/intake/ImportInspectionDialog.tsx` — real PDF flow, URL tab, image OCR path, a11y fixes.
- `supabase/functions/parse-inspection/index.ts` — accept optional `image_url`; multimodal request.
- `supabase/functions/intake-create-request/index.ts` — NEW: service-role insert into `inspection_requests` + `jobs` with org-membership check.
- `supabase/functions/mock-read/index.ts` — NEW: org-scoped reads for mock users.
- `src/pages/inspector/InspectorJobs.tsx` — mount `<ImportInspectionDialog />`.
- `ios-native/Core/Auth/MockSession.swift` + `InspectFlowClient` config — mock read path.
- `.agents/skills/lemonsquad-agent/SKILL.md` — packaged Lemon Squad agent.

Not changed: `parse-inspection` LLM prompt, RLS on `inspection_requests` / `jobs`, `intake-files` bucket policies, real Supabase auth flow.

Out of scope: OCR-based mapping to PDF form fields for Lemon Squad, per-role seeded demo data, auto-submit / review-confirm-submit flows.
