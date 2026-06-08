# Fix "Couldn't load preview" on first open

## What's actually happening

The app renders correctly — I navigated to it in the preview iframe and the Auth page loads and is interactive. The banner is Lovable's preview-render heuristic tripping on two signals during cold boot:

1. **`/manifest.webmanifest` → HTTP 401** inside the preview iframe (Lovable gates static assets behind auth). Browser logs this as a hard resource failure.
2. **Full-screen spinner on every route** until `supabase.auth.getSession()` resolves. While loading, `<ProtectedRoute>` and `<HomeRedirect>` return an empty centered spinner — the heuristic sees no real content for the first paint.

No backend or business logic changes. UI-only.

## Plan

### 1. Skip the PWA manifest in Lovable preview hosts
`index.html` always links `/manifest.webmanifest`. In the preview iframe that asset is 401-gated, so the browser surfaces a hard load error every cold boot. Add a tiny inline script in `<head>` that removes the `<link rel="manifest">` tag when running on a Lovable preview host (`lovableproject.com`, `lovable.app`, `id-preview--*`). Production / installed PWA keeps the manifest exactly as today. This mirrors the existing service-worker guard in `src/main.tsx`.

### 2. Make the cold-boot fallback render real content
Replace the bare full-screen spinner in `ProtectedRoute` and `HomeRedirect` (`src/App.tsx`) with a lightweight branded splash (logo + app name + spinner) so the iframe always has visible DOM on first paint. Same loading semantics, just not a blank screen.

### 3. Silence React Router v7 deprecation warnings (cosmetic)
Add `future={{ v7_startTransition: true, v7_relativeSplatPath: true }}` to `<BrowserRouter>` in `src/App.tsx`. Removes the two console warnings showing during boot — doesn't change routing behavior.

### Out of scope
- No changes to `useAuth`, `useUserRoles`, Supabase client, routes, or any data flow.
- No iOS / Swift changes.
- No service worker changes (already preview-guarded in `src/main.tsx`).

## Verification

1. Reload the preview iframe — banner should not appear; Auth screen paints immediately with branded splash → Auth form.
2. Browser console: no `manifest.webmanifest` 401, no React Router future-flag warnings.
3. Sign-in flow still routes correctly to `/app/inspector/dashboard` (admin → `/`).
4. Production build (`bun run build`) still emits the manifest link in `index.html` and SW registers on non-preview hosts.

## Files touched

- `index.html` — inline guard that strips the manifest link on preview hosts.
- `src/App.tsx` — branded splash component for loading states; add router `future` flags.
