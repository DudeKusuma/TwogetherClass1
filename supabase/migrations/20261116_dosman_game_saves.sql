-- Dosman Underground: one compact save row per authenticated player.
-- Run this migration in Supabase SQL Editor before enabling cloud saves.

create table if not exists public.dosman_game_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  save_data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint dosman_save_data_is_object check (jsonb_typeof(save_data) = 'object')
);

alter table public.dosman_game_saves enable row level security;

drop policy if exists "Players can read their own Dosman save" on public.dosman_game_saves;
create policy "Players can read their own Dosman save"
  on public.dosman_game_saves for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Players can insert their own Dosman save" on public.dosman_game_saves;
create policy "Players can insert their own Dosman save"
  on public.dosman_game_saves for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Players can update their own Dosman save" on public.dosman_game_saves;
create policy "Players can update their own Dosman save"
  on public.dosman_game_saves for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.dosman_game_saves to authenticated;
