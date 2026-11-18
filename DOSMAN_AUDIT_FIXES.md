# Dosman Underground audit fixes

- Restored `frontend/src/assets/styles/tokens.css` as a real global CSS token file. The supplied ZIP had a full Vue `<script setup>`/`template`/`style` component embedded in that `.css` file, which made the stylesheet invalid and prevented a trustworthy Vite build.
- Promoted the newer Dosman implementation that was embedded in that file into `frontend/src/views/DosmanUndergroundView.vue`.
- Preserved the existing route, Supabase save flow, game assets, and main Twogether Class shell behavior.
- The promoted implementation includes the supplied cropped health frames, level-tier upgrade art, pixel-art footer assets, and fullscreen/safe-area behavior.

- Updated `DOSMAN_SETUP.md` so its Luck/asset notes match the audited source.
