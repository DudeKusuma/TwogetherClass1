# Dosman Underground setup

## Included
- Games page entry and `/games/dosman-underground` route.
- Mining prototype: manual hit (500 ms cooldown), automatic mining, random Dirt/Stone/Coal and Small/Medium/Large ore, Rupiah rewards, Power/Speed/Ore upgrades, and demo pickaxe inventory.
- Supplied pixel-art assets retained in `frontend/public/dosman/assets/`, including tightly cropped health-bar frames and individual Power, Speed, and Ore upgrade frames derived from the supplied sprite sheets, plus the supplied Luck tier icons.
- Supabase save table migration.

## Supabase cloud save
Run `supabase/migrations/20261116_dosman_game_saves.sql` in the Supabase SQL Editor.
The game stores one JSON save row per authenticated user. It batches changes and writes after a 20-second quiet period, and attempts a flush when the page becomes hidden or is left. It does not write on every mining hit; currency/upgrade/equipment changes queue a save. If the migration is not installed, the game remains playable in the current session but cloud saving is unavailable.

## Environment
Copy `frontend/.env.example` to `frontend/.env.local` and fill in the existing Supabase project URL and publishable key. The supplied ZIP's local environment file is intentionally not included in the export.

## Run
From `frontend/`:
```bash
npm install
npm run dev
```

## Important prototype notes
- Pickaxes are all available as demo inventory items; acquisition/unlocking is not implemented.
- Gacha, Dungeon, and Store footer tabs are visual placeholders.
- Luck upgrade now increases the chance of a 1.5x ore reward bonus and uses the supplied `dosman-luck-icon-1/2/3.png` tier assets.
- Mining uses the supplied ore PNGs, pickaxe swing sheet, and generated health-bar frame crops. Ore HP is multiplied by 8; Rupiah rewards are unchanged.
- The cloud save table stores the player's game state, but game-economy validation should move server-side before public competitive use.

## Revision notes
- Dosman Underground route now uses a dedicated fullscreen layout and hides the main Twogether Class header/footer only while the game route is active.
- Health bar frames are cropped from `pixel-art-health-bar-sprite-sheet.png` and selected from current ore HP percentage.
- Power, Speed, Ore, and Luck upgrade art changes at levels 1–4, 5–9, and 10+.
- Game footer uses supplied pixel-art item assets instead of Lucide footer icons.
- Settings includes an in-game Back to Mining action.

No new database migration is required for this visual/gameplay revision; the existing `20261116_dosman_game_saves.sql` remains the save-table migration.
