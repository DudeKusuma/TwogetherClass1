# Revision Notes — Twogether Class 16

## Changes in this revision

- Adjusted the Dosman Underground bottom navigation so it respects the device safe area and no longer extends below the viewport.
- Changed the Games-page Dosman Underground entry to use an explicit Vue Router navigation action.
- Replaced the four visible daily game tabs with one class-wide daily game selected deterministically from the Bali calendar date.
- Changed the daily game reward to 10 T-Money and enforced one claim per student per Bali calendar day on the server.
- Added admin-only monthly cash color overrides: Auto, Merah, Oranye, Kuning, and Hijau. Auto continues to use approved monthly payment allocations.

## Supabase migration

Run this file in the Supabase SQL Editor after the existing finance and games/rewards migrations:

`supabase/migrations/20261117_daily_game_cash_status_admin.sql`

The migration also replaces `submit_daily_game_answer`, so the one-game-per-day and 10 T-Money rules are enforced server-side, not only in the frontend.

## Verification

All 46 Vue single-file components passed Vue SFC script/template compilation checks. A full Vite production build could not be completed in this environment because the uploaded `node_modules` archive contains the Windows Rolldown native binding, not the Linux binding required by this build environment. Run `npm install` (or `npm ci`) and `npm run build` in your local project environment to perform the full production build.
