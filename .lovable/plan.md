# Regenerate User Guide

Refresh `VehicleInspectors_UserGuide.docx` so it matches the app as it stands today, including the latest Drive Mode, schedule conflict detection, map provider preferences, and Capacitor SPM iOS build.

## What the new guide will cover

1. **Getting Started**
   - Sign in / sign up, role-based home redirect (admin → dashboard, others → `/app/inspector/dashboard`)
   - PWA install prompt, theme (light/dark/system)

2. **Inspector Workspace**
   - Dashboard + "Start My Day" flow
   - Schedule: week grid with conflict detection (overlap, blocked dates, outside availability), `AlertTriangle` badges, list view warnings
   - Jobs queue and Trips list with active trip banner
   - **Drive Mode (`/app/inspector/drive`)**: full-screen route map, Wake Lock, voice cues, 75 m geofenced auto-arrive, Arrive button, distance/ETA
   - Tax view

3. **Maps & Navigation**
   - Map provider preference (Auto / Apple / Google / Waze) stored in localStorage
   - Web: opens device map in a new tab; Native: hands off via `App.openUrl`
   - In-app polyline route stays inside the app for navigation

4. **Dispatch / Admin / Ops**
   - Dispatch dashboard, Inspections, Inspectors, Vehicles, Reports, Repair Shop, Client Portal, Marketplace, Settings
   - VIN intelligence, intelligent dispatch, template marketplace, audit log

5. **Mechanic & Dispatcher Workspaces**
   - Role-gated dashboards via `RoleRoute`

6. **Native iOS Build (Phase 7D)**
   - Capacitor SPM (no CocoaPods), `npx cap sync ios`, opening `ios/App/App.xcworkspace`
   - CarPlay scene delegate stub, Android Auto stub
   - Background location setup reference

7. **Troubleshooting & Tips**
   - Wake Lock browser support, geolocation permissions, offline behavior, map deep-link fallbacks

## Technical approach

- Use `docx-js` via a Node script in `/tmp/gen_guide.js`
- US Letter, Arial default, override Heading1–3 styles, `outlineLevel` set for TOC
- Bullet/numbered lists via `numbering.config` (separate references per section to restart counts)
- Use smart quotes only via TextRun strings (no unicode bullets)
- Output → `/mnt/documents/VehicleInspectors_UserGuide_v2.docx` (versioned so prior copy is preserved)
- QA: convert to PDF via headless LibreOffice and rasterize each page with `pdftoppm`, inspect every page, fix and re-run if anything is clipped/blank
- Surface to user with `<lov-artifact>` tag

## Files

- New: `/tmp/gen_guide.js` (ephemeral)
- New artifact: `/mnt/documents/VehicleInspectors_UserGuide_v2.docx`

No project source files will be changed.
