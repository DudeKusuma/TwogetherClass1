# Dosman Underground — Revision Notes

## Perubahan pada revisi ini
- Ikon Rupiah dipotong dari sprite sheet menjadi `rupiah-icon.png` agar hanya satu lembar uang yang tampil.
- HP Dirt, Stone, dan Coal dinaikkan 8x dari nilai sebelumnya untuk memperlambat progres mining.
- Animasi pickaxe swing memakai `pixel-art-pickaxe-swing-animation-sheet.png` saat manual maupun automatic hit.
- Profile di kiri atas sekarang dapat diklik dan membuka panel statistik pemain.
- Backpack diubah menjadi grid slot inventory pixel-art; pickaxe ditampilkan sebagai item dalam slot.
- Navigasi Summon, Dungeon, dan Store membuka halaman panel masing-masing dengan asset chest, portal, dan mining stall yang sudah tersedia.
- Empat upgrade ditampilkan dalam satu baris: Power, Speed, Ore, Luck. Luck memberi peluang bonus reward.
- Mining otomatis berhenti ketika tab/browser tidak terlihat atau pemain sedang berada di panel lain.

## Catatan verifikasi
- Build belum dapat diverifikasi di lingkungan pengerjaan ini: instalasi npm terhenti karena timeout dan `vite` belum tersedia saat perintah build dijalankan.
- Integrasi Supabase tetap memerlukan migration `supabase/migrations/20261116_dosman_game_saves.sql` dijalankan di project Supabase.
- Panel Summon, Dungeon, dan Store saat ini adalah tampilan awal/placeholder interaktif berbasis asset; sistem summon, expedition, dan transaksi store belum diimplementasikan.
- Inventory saat ini memiliki tab visual kategori dan slot pickaxe; kategori item lain masih menunggu sistem itemnya.


## Audit revision (2026-11-09)
- Reused the supplied project ZIP as the working source; the Twogether Class application, router, Supabase client, existing migrations, and game route were retained.
- Re-cropped the supplied Power, Speed, and Ore upgrade sprite sheets into individual frame PNGs and wired the upgrade HUD to those frames. Luck continues to use the supplied Luck tier images.
- Corrected health-bar frame selection so the highest-HP state uses frame 1 and lower HP selects progressively depleted frames.
- Resized the profile HUD to match the supplied wide panel's natural proportions and aligned it with the top-bar height.
- Changed the footer background to preserve the supplied art's natural height rather than stretching it to the full viewport width.
- Separated the selected-slot indicator from equipped-slot styling: only the selected pickaxe now shows the gold selected indicator, while the inventory slot uses the normal slot background.
- Added explicit Basic/Common/Uncommon rarity text to the pickaxe detail panel. Wooden remains borderless and cannot be unequipped; Stone uses frame 1 and Iron uses frame 2.
- Added `frontend/.env.example` with placeholders for the browser-safe Supabase URL and publishable key; no secrets are included.
- Static checks: all 17 frontend JavaScript files and the Dosman `<script setup>` pass `node --check`; all literal Dosman asset references resolve; the Dosman SFC's template/style tag counts and CSS brace counts are balanced.
- Build status: NOT VERIFIED. `npm ci --no-audit --no-fund` timed out twice in this environment; `npm run build` could not run because Vite was not installed. No build-success claim is made.
